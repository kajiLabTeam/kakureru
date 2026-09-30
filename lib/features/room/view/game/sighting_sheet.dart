import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/model/sighting.dart';
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/sighting_rules.dart';
import 'package:kakureru/features/room/view/game/downloaded_photo_image.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 他人の写真の枠(モックの#D2CCC0)。
const _otherPhotoBorder = Color(0xFFD2CCC0);

/// 写真の読み込み中の地(モックの#DED9CF)。
const _photoPlaceholder = Color(0xFFDED9CF);

/// シートの取っ手(モックの#D6D2C8)。
const _sheetHandle = Color(0xFFD6D2C8);

/// 送信に失敗したときの文字色(鬼の濃い赤)。
const _errorInk = Color(0xFFC0343A);

/// 1枚ぶんの写真の大きさ。モック(200x118)より縦を足している
/// (撮る写真は縦長が多く、118だと鬼が切れやすいため)。
const double sightingPhotoWidth = 200;

/// [sightingPhotoWidth]と対の高さ。
const double sightingPhotoHeight = 150;

/// 目撃写真のシート(ミッション企画のモック6)を開く。
///
/// 地図の右下のボタンの`onPressed`から呼ぶ。`useEffect`の中から呼ばない
/// (ビルド中にNavigatorを触ると`!_debugLocked`で落ちた経緯があるため)。
/// 閉じたら完了する。
Future<void> showSightingSheet(
  BuildContext context, {
  required String roomId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: SightingSheet(roomId: roomId),
    ),
  );
}

/// 撮った写真を送り、失敗したときだけ画面に出す1文を返す(成功ならnull)。
///
/// 画像本体を[upload]でR2へ上げてから、[record]で`sightings/{photoId}`を
/// 書く(順序が逆だと、送れなかった写真が一覧に出てしまうため。足元の写真と
/// 同じ)。例外は投げずに文言へ変換する(シートを閉じた後に終わることが
/// あり、受け取る画面が無いことがあるため)。
Future<String?> sendSightingPhoto({
  required Future<void> Function() upload,
  required Future<void> Function() record,
}) async {
  try {
    await upload();
  } on PhotoTooLargeException {
    return '画像サイズが大きすぎます。もう一度撮影してください';
  } on Object catch (e) {
    debugPrint('[SightingSheet] アップロードに失敗: $e');
    return '写真を送れませんでした。もう一度撮ってください';
  }
  try {
    await record();
  } on Object catch (e) {
    debugPrint('[SightingSheet] sightingsの書き込みに失敗: $e');
    return '写真を送れませんでした。もう一度撮ってください';
  }
  return null;
}

/// [showSightingSheet]の中身。RTDBを読んで[SightingSheetView]に渡し、
/// 撮影と送信を受け持つ。
class SightingSheet extends HookConsumerWidget {
  /// [roomId]のルームの目撃写真を出す。
  const SightingSheet({required this.roomId, super.key});

  /// ルームID。
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomStreamProvider(roomId)).value;
    final users = room?.users ?? const <RoomUser>[];
    final myUid = ref.watch(myUidProvider);
    final sightings = sightingsOfCurrentGame(
      ref.watch(sightingsStreamProvider(roomId)).value ?? const [],
      startedAt: room?.startedAt,
    );

    // カメラを開いている・送っている最中か、と失敗の文言。シートを閉じたら
    // 一緒に消えてよい一時状態なのでhooksで持つ(AGENTS.md規約)。
    final isBusy = useState(false);
    final errorMessage = useState<String?>(null);

    Future<void> takeAndSend() async {
      if (isBusy.value) return;
      isBusy.value = true;
      errorMessage.value = null;

      final Uint8List? bytes;
      try {
        // 圧縮(長辺1080px・画質80から)は足元の写真・捕まえた瞬間の写真と
        // 同じ共通の関数を使う。
        bytes = await pickCameraPhotoWithinLimit();
      } on CameraPhotoTooLargeException catch (e) {
        if (!context.mounted) return;
        isBusy.value = false;
        errorMessage.value = '$e';
        return;
      }
      if (bytes == null) {
        // カメラを閉じた(撮らなかった)。何も出さない。
        if (context.mounted) isBusy.value = false;
        return;
      }
      if (!context.mounted) return;

      // 送信中にシートが閉じられても結果を知らせられるよう、アプリ全体の
      // ScaffoldMessengerとリポジトリを先に取っておく。
      final messenger = ScaffoldMessenger.of(context);
      final roomRepository = ref.read(roomRepositoryProvider);
      // 撮るたびに新しいIDにする。写真APIは同じIDへの2回目のPUTを409で
      // 断るため(docs/photo-storage.md)。
      final photoId = FirebaseDatabase.instance.ref().push().key!;
      final failure = await sendSightingPhoto(
        upload: () => PhotoRepository().upload(
          roomId: roomId,
          photoId: photoId,
          bytes: bytes!,
        ),
        record: () => roomRepository.addSighting(roomId, photoId),
      );
      if (context.mounted) {
        isBusy.value = false;
        errorMessage.value = failure;
      } else if (failure != null) {
        messenger.showSnackBar(SnackBar(content: Text(failure)));
      }
    }

    return SightingSheetView(
      roomId: roomId,
      sightings: sightings,
      users: users,
      myUid: myUid,
      viewerRole: roleOf(users, myUid),
      canTakePhoto: isPhotoFeatureConfigured,
      isBusy: isBusy.value,
      errorMessage: errorMessage.value,
      onTakePhoto: () => unawaited(takeAndSend()),
      onClose: () => Navigator.of(context).pop(),
    );
  }
}

/// 目撃写真のシートの見た目(ミッション企画のモック6)。
///
/// 時系列のチャット風に、古いものを上・新しいものを下に並べ、他人の写真を
/// 左・自分の写真を右に置く。一番下に「鬼の写真を撮る」を固定する。
/// 撮れるのは逃走者だけで、見るのは鬼も含めた全員。
class SightingSheetView extends StatelessWidget {
  /// 値はすべて呼び出し側([SightingSheet])が解決して渡す。
  const SightingSheetView({
    required this.roomId,
    required this.sightings,
    required this.users,
    required this.myUid,
    required this.viewerRole,
    required this.canTakePhoto,
    required this.isBusy,
    required this.errorMessage,
    required this.onTakePhoto,
    required this.onClose,
    super.key,
  });

  /// ルームID(写真本体のダウンロードに使う)。
  final String roomId;

  /// 並べる写真。`sightingsOfCurrentGame`で今のゲームに絞り、古い順に
  /// 並べたもの。
  final List<Sighting> sightings;

  /// 名前を引くための参加者一覧。
  final List<RoomUser> users;

  /// 自分のuid。
  final String? myUid;

  /// 見ている人の役割。逃走者のときだけ「鬼の写真を撮る」を出す。
  final UserRole? viewerRole;

  /// 写真機能が使える環境か(`PHOTO_API_BASE_URL`が設定されているか)。
  final bool canTakePhoto;

  /// カメラを開いている・送っている最中か。
  final bool isBusy;

  /// 撮影・送信に失敗したときの文言。
  final String? errorMessage;

  /// 「鬼の写真を撮る」。
  final VoidCallback onTakePhoto;

  /// 閉じるボタン。
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final canTake = viewerRole == UserRole.fugitive;
    final error = errorMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          height: 24,
          child: Center(
            child: SizedBox(
              width: 42,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _sheetHandle,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '見つけた鬼の写真',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: gameInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canTake
                          ? '鬼を見つけたら撮ってね。ルームの全員がすぐ見られる'
                          : '逃走者が見つけた鬼の写真。ルームの全員が見られる',
                      style: const TextStyle(fontSize: 12, color: gameMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '閉じる',
                onPressed: onClose,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                style: IconButton.styleFrom(backgroundColor: gameBackground),
                icon: const Icon(Icons.close, color: gameMuted, size: 20),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: gameBorder),
        Expanded(
          child: sightings.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'まだありません',
                      style: TextStyle(fontSize: 13, color: gameFaint),
                    ),
                  ),
                )
              // 新しいものを下に置き、開いたときに一番新しい写真が見えるよう
              // reverseで下から積む(チャットと同じ)。
              : ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  itemCount: sightings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final sighting = sightings[sightings.length - 1 - index];
                    final isMine = sighting.uid == myUid;
                    final name = findUser(users, sighting.uid)?.displayName;
                    return SightingBubble(
                      key: ValueKey('sighting-${sighting.id}'),
                      roomId: roomId,
                      sighting: sighting,
                      isMine: isMine,
                      authorName: name == null || name.isEmpty ? '???' : name,
                    );
                  },
                ),
        ),
        if (canTake)
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: gameBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Text(
                        error,
                        style: const TextStyle(fontSize: 12, color: _errorInk),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _TakeSightingButton(
                      enabled: canTakePhoto && !isBusy,
                      isBusy: isBusy,
                      onPressed: onTakePhoto,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// シートの下に固定する「鬼の写真を撮る」(56px)。
class _TakeSightingButton extends StatelessWidget {
  const _TakeSightingButton({
    required this.enabled,
    required this.isBusy,
    required this.onPressed,
  });

  final bool enabled;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          // 白文字を載せるので、自分の色(#2F5FC4)の面にする(モック6)。
          backgroundColor: selfColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: gameSelected,
          disabledForegroundColor: gameMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: gameMuted,
                ),
              )
            else
              const Icon(Icons.photo_camera_outlined, size: 22),
            const SizedBox(width: 9),
            Text(
              isBusy ? '送っています' : '鬼の写真を撮る',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// 目撃写真1枚ぶん。他人の写真は左、自分の写真は右に寄せ、写真の上に
/// 「名前 ・ 時刻 ・ 場所」を小さく出す。タップで大きく見られる。
class SightingBubble extends StatelessWidget {
  /// 名前は呼び出し側で引いて渡す。
  const SightingBubble({
    required this.roomId,
    required this.sighting,
    required this.isMine,
    required this.authorName,
    super.key,
  });

  /// ルームID。
  final String roomId;

  /// 写真のメタデータ。
  final Sighting sighting;

  /// 自分が撮った写真か。
  final bool isMine;

  /// 撮った人の名前。
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final caption = sightingCaption(
      authorName: authorName,
      isMine: isMine,
      takenAt: sighting.takenAt,
      place: sighting.place,
    );
    // 自分は青、他人は逃走者の色(撮れるのは逃走者だけ)。白文字を載せる
    // ので逃走者は濃い方の色にする。
    final avatarColor = isMine
        ? selfColor
        : roleThemeOf(UserRole.fugitive).surfaceColor;
    final avatar = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
      child: Text(
        isMine ? '自' : avatarInitial(authorName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final body = Flexible(
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: gameMuted),
          ),
          const SizedBox(height: 4),
          _SightingPhoto(roomId: roomId, sighting: sighting, isMine: isMine),
        ],
      ),
    );

    return Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isMine
          ? [body, const SizedBox(width: 8), avatar]
          : [avatar, const SizedBox(width: 8), body],
    );
  }
}

class _SightingPhoto extends StatelessWidget {
  const _SightingPhoto({
    required this.roomId,
    required this.sighting,
    required this.isMine,
  });

  final String roomId;
  final Sighting sighting;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return SizedBox(
      key: ValueKey('sighting-photo-${sighting.id}'),
      width: sightingPhotoWidth,
      height: sightingPhotoHeight,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: isMine
              ? Border.all(color: selfColor, width: 2)
              : Border.all(color: _otherPhotoBorder),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: _photoPlaceholder,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _SightingPhotoViewerPage(
                    roomId: roomId,
                    sighting: sighting,
                  ),
                ),
              ),
              child: DownloadedPhotoImage(roomId: roomId, photoId: sighting.id),
            ),
          ),
        ),
      ),
    );
  }
}

/// 目撃写真を1枚だけ全画面で見る画面(拡大できるだけの簡素なもの)。
///
/// 足元の写真のビューア(`PhotoViewerPage`)は撮影スロットに、捕まえた瞬間の
/// ビューア(`CatchPhotoViewerPage`)は`CatchPhoto`に結びついているため
/// 使い回さない。
class _SightingPhotoViewerPage extends StatelessWidget {
  const _SightingPhotoViewerPage({
    required this.roomId,
    required this.sighting,
  });

  final String roomId;
  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '見つけた鬼の写真 ${formatClockTime(sighting.takenAt)}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: InteractiveViewer(
        child: Center(
          child: DownloadedPhotoImage(
            roomId: roomId,
            photoId: sighting.id,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
