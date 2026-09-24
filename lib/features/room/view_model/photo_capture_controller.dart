import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/features/room/model/photo_capture_state.dart';
import 'package:kakureru/features/room/repository/event_log_repository.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';

/// これを超える画像は送らない(Worker側の上限、docs/photo-storage.md参照)。
const _maxPhotoBytes = 2 * 1024 * 1024;

const _initialImageQuality = 80;
const _imageQualityStep = 20;
const _minImageQuality = 20;

const _maxUploadAttempts = 3;
const _retryBaseDelay = Duration(seconds: 1);

/// 撮影バナーを操作するための入り口。[usePhotoCaptureController]が返す。
class PhotoCaptureController {
  PhotoCaptureController({
    required this.state,
    required this.capture,
    required this.resend,
  });

  final PhotoCaptureState state;

  /// カメラを起動して撮影〜アップロードまで行う。キャンセル時は何もしない。
  final Future<void> Function() capture;

  /// アップロードに失敗して保持している[PhotoCaptureState.pendingBytes]を
  /// 撮り直しなしで送り直す。保持している画像が無ければ何もしない。
  final Future<void> Function() resend;
}

/// ゲーム画面に常駐する撮影プロンプトのタイマーとアップロードを扱うフック。
///
/// [roomId]・[intervalSec]（`RoomSetting.photoIntervalSec`）・[lastPhotoAt]
/// （自分の`RoomUser.lastPhotoAt`。アプリ再起動をまたいで間隔を復元するため）
/// を渡す。バックグラウンドでの自動撮影は行わず、間隔が来たら
/// [PhotoCaptureState.isDue]をtrueにしてバナー表示を促すだけ(Phase 1)。
///
/// このタイマー/アップロード状態はGamePageが消えたら一緒に消えてよい
/// (次に入った時はlastPhotoAtから間隔を復元できる)ため、AGENTS.mdの
/// 判断基準に従いRiverpodではなくhooksで持つ(useGameSessionが束ねる
/// 各種Riverpod NotifierとGameAlertsは共有状態なので対象外、こちらは
/// この画面だけのローカル状態)。
PhotoCaptureController usePhotoCaptureController(
  BuildContext context, {
  required String roomId,
  required String? myUid,
  required int intervalSec,
  required int? lastPhotoAt,
}) {
  final stateHook = useState(const PhotoCaptureState());
  final repository = useMemoized(PhotoRepository.new, const []);
  final dueTimerRef = useRef<Timer?>(null);

  void scheduleDueTimer(int nextDueAtMillis) {
    dueTimerRef.value?.cancel();
    final delayMillis = nextDueAtMillis - DateTime.now().millisecondsSinceEpoch;
    dueTimerRef.value = Timer(
      Duration(milliseconds: delayMillis < 0 ? 0 : delayMillis),
      () {
        if (!context.mounted) return;
        stateHook.value = stateHook.value.copyWith(isDue: true);
        // バナーは他のタブを見ている・バックグラウンド中だと気づかれない
        // ため、通知でも知らせる(役割は問わない。鬼は撮影ボタン自体が
        // 出ないだけで、通知が来ても実害は無い)。
        unawaited(showPhotoCaptureDueNotification());
      },
    );
  }

  useEffect(() {
    final baseMillis = lastPhotoAt ?? DateTime.now().millisecondsSinceEpoch;
    final nextDueAtMillis = baseMillis + intervalSec * 1000;

    if (nextDueAtMillis <= DateTime.now().millisecondsSinceEpoch) {
      // 既に間隔を過ぎている(再起動直後 等)。useEffect内で同期的に
      // state.value = ... を書くとビルド中のNavigator操作の
      // 「!_debugLocked」アサーション失敗と同種の事故につながった経緯が
      // あるため(game_alerts.dart参照)、フレーム確定後に回す。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        stateHook.value = stateHook.value.copyWith(isDue: true);
        unawaited(showPhotoCaptureDueNotification());
      });
    } else {
      scheduleDueTimer(nextDueAtMillis);
    }

    return () => dueTimerRef.value?.cancel();
    // scheduleDueTimer/stateHookはeffect内でのみ参照するクロージャの再生成
    // 元であり、依存に加えるとタイマーが無限に張り直されてしまうため除外する。
    // ignore: exhaustive_keys
  }, [roomId, intervalSec, lastPhotoAt]);

  Future<void> uploadWithRetry(Uint8List bytes) async {
    final uid = myUid;
    if (uid == null) return;

    stateHook.value = stateHook.value.copyWith(
      isUploading: true,
      lastErrorMessage: null,
    );

    // photoIdはRTDBのpush keyで生成する(使い捨ての一意なキーが要るだけで、
    // 順序性等の意味は無いため。新規にUUID系パッケージを増やさない)。
    final photoId = FirebaseDatabase.instance.ref().push().key;
    if (photoId == null) {
      if (!context.mounted) return;
      stateHook.value = stateHook.value.copyWith(
        isUploading: false,
        lastErrorMessage: 'photoIdの生成に失敗しました',
      );
      return;
    }

    var delay = _retryBaseDelay;
    for (var attempt = 1; attempt <= _maxUploadAttempts; attempt++) {
      try {
        await repository.upload(roomId: roomId, photoId: photoId, bytes: bytes);

        // RTDBへの書き込みはアップロード成功後に限る(順序が逆だと、送信に
        // 失敗した写真が「撮影済み」として扱われてしまう)。photos/{photoId}
        // とusers/{uid}/lastPhotoAtは別ノードで個別にセキュリティルールが
        // 掛かっているため、rooms/{roomId}をまとめて書くことはできず
        // 2回に分けて書く(docs/rtdb-schema.md、room_repository.dartと同じ
        // 制約)。
        await FirebaseDatabase.instance
            .ref('rooms/$roomId/photos/$photoId')
            .set({'uid': uid, 'takenAt': ServerValue.timestamp});
        await FirebaseDatabase.instance
            .ref('rooms/$roomId/users/$uid/lastPhotoAt')
            .set(ServerValue.timestamp);
        unawaited(
          EventLogRepository().log(
            roomId,
            type: GameEventType.photoTaken,
            uid: uid,
          ),
        );

        debugPrint(
          '[usePhotoCaptureController] アップロード成功 bytes=${bytes.length}',
        );

        if (!context.mounted) return;
        scheduleDueTimer(
          DateTime.now().millisecondsSinceEpoch + intervalSec * 1000,
        );
        stateHook.value = stateHook.value.copyWith(
          isUploading: false,
          isDue: false,
          pendingBytes: null,
          lastErrorMessage: null,
        );
        return;
      } on PhotoTooLargeException {
        if (!context.mounted) return;
        stateHook.value = stateHook.value.copyWith(
          isUploading: false,
          pendingBytes: null,
          lastErrorMessage: '画像サイズが大きすぎます',
        );
        return;
      } on Object catch (e) {
        debugPrint(
          '[usePhotoCaptureController] アップロード失敗($attempt回目/$_maxUploadAttempts): $e',
        );
        if (attempt == _maxUploadAttempts) break;
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }

    if (!context.mounted) return;
    stateHook.value = stateHook.value.copyWith(
      isUploading: false,
      pendingBytes: bytes,
      lastErrorMessage: 'アップロードに失敗しました。もう一度お試しください',
    );
  }

  Future<void> doCapture() async {
    if (stateHook.value.isUploading) return;

    var quality = _initialImageQuality;
    while (true) {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: quality,
      );
      if (file == null) return; // キャンセル。何もしない。

      final bytes = await file.readAsBytes();
      debugPrint(
        '[usePhotoCaptureController] quality=$quality bytes=${bytes.length}'
        '(目標 約200KB)',
      );

      if (bytes.length <= _maxPhotoBytes) {
        await uploadWithRetry(bytes);
        return;
      }

      quality -= _imageQualityStep;
      if (quality < _minImageQuality) {
        if (!context.mounted) return;
        stateHook.value = stateHook.value.copyWith(
          lastErrorMessage: '画像サイズが大きすぎます。もう一度撮影してください',
        );
        return;
      }
      // 画質を下げて撮り直す(image_picker以外の圧縮パッケージは追加しない
      // 方針のため、撮影時のimageQualityを下げる以外に手段が無い)。
    }
  }

  Future<void> doResend() async {
    final bytes = stateHook.value.pendingBytes;
    if (bytes == null) return;
    await uploadWithRetry(bytes);
  }

  return PhotoCaptureController(
    state: stateHook.value,
    capture: doCapture,
    resend: doResend,
  );
}
