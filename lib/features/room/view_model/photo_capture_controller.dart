import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/features/room/model/photo_capture_state.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';
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
/// 撮影を促すタイミングはギャラリーと同じ「スロット」(`photo_slot.dart`)に
/// 揃える: 鬼の放出([releasedAt] = `meta/releasedAt`)から[intervalSec]
/// (`RoomSetting.photoIntervalSec`)たった時点を1回目とし
/// ([photoScheduleStartMillis])、以後[intervalSec]ごとに区切って、今のスロットでまだ撮って
/// いなければ[PhotoCaptureState.isDue]をtrueにしてバナー表示を促す。
/// 撮影済みかどうかは[lastPhotoAt](自分の`RoomUser.lastPhotoAt`。アプリ
/// 再起動をまたいでも復元できる)で判定する。バックグラウンドでの自動撮影は
/// 行わない(Phase 1)。
///
/// 以前は「前回の撮影(未撮影なら画面を開いた時刻)+間隔」で判定していた
/// ため、スロットの区切りとずれて、最初のスロットの通知がスロットの終わりに
/// しか来ない・終わり際に撮ると次のスロットの通知がほぼ1スロット分遅れる、
/// という取りこぼしがあった。また基準をゲーム開始(`meta/startedAt`)に
/// していたため、鬼の放出待ちの間にすぐ通知が来ていた。
///
/// releasedAt/lastPhotoAtはサーバー時刻なので、[serverTimeOffsetMillis]
/// (`.info/serverTimeOffset`)で端末時計を補正して比べる。
///
/// [notifyWhenDue]がfalseなら、間隔が来ても端末通知は出さない(鬼は撮影
/// しないため。issue #120)。途中で鬼になることがあるので、タイマーが
/// 発火した時点の値を使う。通知は1スロットにつき1回まで。
///
/// このタイマー/アップロード状態はGamePageが消えたら一緒に消えてよい
/// (次に入った時はlastPhotoAtから復元できる)ため、AGENTS.mdの
/// 判断基準に従いRiverpodではなくhooksで持つ(useGameSessionが束ねる
/// 各種Riverpod NotifierとGameAlertsは共有状態なので対象外、こちらは
/// この画面だけのローカル状態)。
PhotoCaptureController usePhotoCaptureController(
  BuildContext context, {
  required String roomId,
  required String? myUid,
  required int intervalSec,
  required int? releasedAt,
  required int? lastPhotoAt,
  required int serverTimeOffsetMillis,
  required bool notifyWhenDue,
}) {
  final stateHook = useState(const PhotoCaptureState());
  // タイマーのコールバックやアップロード完了時の処理は作った時点の引数を
  // 閉じ込めるので、最新の値を参照できるようにrefへ入れておく。
  final notifyWhenDueRef = useRef(notifyWhenDue)..value = notifyWhenDue;
  final intervalSecRef = useRef(intervalSec)..value = intervalSec;
  final releasedAtRef = useRef(releasedAt)..value = releasedAt;
  final lastPhotoAtRef = useRef(lastPhotoAt)..value = lastPhotoAt;
  final offsetRef = useRef(serverTimeOffsetMillis)
    ..value = serverTimeOffsetMillis;
  // アップロード成功からRTDBのlastPhotoAtが届くまでの間に判定し直しても
  // 「まだ撮っていない」とならないよう、手元でも撮影時刻を持っておく。
  final uploadedAtRef = useRef<int?>(null);
  // 同じスロットで通知を重ねないため、最後に通知したスロット番号。
  final notifiedSlotRef = useRef<int?>(null);

  final repository = useMemoized(PhotoRepository.new, const []);
  final dueTimerRef = useRef<Timer?>(null);

  int serverNow() => clock.now().millisecondsSinceEpoch + offsetRef.value;

  /// [nowMillis]時点で撮影を促すべきかを判定して反映し、次のスロットの
  /// 区切りで判定し直すタイマーを張る。
  void evaluate(int nowMillis) {
    dueTimerRef.value?.cancel();
    dueTimerRef.value = null;
    final interval = intervalSecRef.value;
    final start = photoScheduleStartMillis(
      releasedAt: releasedAtRef.value,
      intervalSec: interval,
    );
    if (start == null) return;

    final photoAt = lastPhotoAtRef.value;
    final uploadedAt = uploadedAtRef.value;
    final takenAt = photoAt == null
        ? uploadedAt
        : uploadedAt == null
        ? photoAt
        : math.max(photoAt, uploadedAt);

    final due = isPhotoCaptureDue(
      startedAt: start,
      lastPhotoAt: takenAt,
      nowMillis: nowMillis,
      intervalSec: interval,
    );
    if (due != stateHook.value.isDue) {
      stateHook.value = stateHook.value.copyWith(isDue: due);
    }
    if (due) {
      final slot = currentPhotoSlotIndex(
        startedAt: start,
        nowMillis: nowMillis,
        intervalSec: interval,
      );
      // バナーは他のタブを見ている・バックグラウンド中だと気づかれない
      // ため、通知でも知らせる(鬼には出さない)。
      if (notifiedSlotRef.value != slot) {
        notifiedSlotRef.value = slot;
        if (notifyWhenDueRef.value) {
          unawaited(showPhotoCaptureDueNotification());
        }
      }
    }

    final nextBoundary = nextPhotoSlotBoundaryMillis(
      startedAt: start,
      nowMillis: nowMillis,
      intervalSec: interval,
    );
    final delayMillis = nextBoundary - serverNow();
    dueTimerRef.value = Timer(
      Duration(milliseconds: delayMillis < 0 ? 0 : delayMillis),
      () {
        if (!context.mounted) return;
        // 区切りの時刻そのもので判定する(端末時計がタイマーより僅かに
        // 遅れていても前のスロットと判定しないため)。スリープ等で発火が
        // 遅れた場合は実際の時刻で判定する。
        evaluate(math.max(nextBoundary, serverNow()));
      },
    );
  }

  useEffect(() {
    // useEffect内で同期的にstate.value = ... を書くとビルド中の
    // Navigator操作の「!_debugLocked」アサーション失敗と同種の事故に
    // つながった経緯があるため(game_alerts.dart参照)、フレーム確定後に回す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      evaluate(serverNow());
    });
    return () => dueTimerRef.value?.cancel();
    // evaluate/stateHookはeffect内でのみ参照するクロージャの再生成元であり、
    // 依存に加えるとタイマーが無限に張り直されてしまうため除外する
    // (最新の値はrefから読む)。
    // ignore: exhaustive_keys
  }, [roomId, intervalSec, releasedAt, lastPhotoAt, serverTimeOffsetMillis]);

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
        uploadedAtRef.value = serverNow();
        stateHook.value = stateHook.value.copyWith(
          isUploading: false,
          pendingBytes: null,
          lastErrorMessage: null,
        );
        // isDueを下ろし、次のスロットの区切りで判定し直すタイマーを張る。
        evaluate(serverNow());
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
