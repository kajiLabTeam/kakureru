import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view/game/catch_target_sheet.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _captureSubInk = Color(0xFFFFE0E0);

/// 鬼が相手と場所を選んだ後の、捕獲を確定する写真の撮影画面(issue #140)。
///
/// **写真を撮って送った時点で捕獲が確定する**([onCatch]で`catches`を書く)。
/// 撮らずに端末の「戻る」で閉じたときは何も書かず、`false`を返す
/// (呼び出し側は屋内/屋外の選択からやり直させる)。送ったら`true`で閉じる。
/// 時間切れで勝手にゲーム画面へ戻すことはしない(撮る前に閉じてしまうため)。
/// 撮った写真は確認画面を挟まずにそのまま全員へ送る(送る・送らない・
/// 撮り直すを選ばせると、捕まえた直後の手間が増えるため)。
class CatchCapturePage extends HookConsumerWidget {
  /// [onCatch]は捕獲を書いてそのIDを返す(`reportCatch`)。
  ///
  /// [pickPhoto]・[sendPhoto]・[canTakePhoto]はテストで差し替えるためのもの。
  /// 省略時は実カメラ・写真API・[isPhotoFeatureConfigured]を使う。
  const CatchCapturePage({
    super.key,
    required this.roomId,
    required this.fugitiveUid,
    required this.fugitiveName,
    required this.onCatch,
    this.pickPhoto = pickCameraPhotoWithinLimit,
    this.sendPhoto,
    this.canTakePhoto,
  });

  /// ルームID。
  final String roomId;

  /// 捕まえた相手のuid。
  final String fugitiveUid;

  /// 捕まえた相手の名前。
  final String fugitiveName;

  /// 捕獲を書き、そのcatchIdを返す。写真を撮れたときだけ呼ぶ。
  final Future<String> Function() onCatch;

  /// カメラで1枚撮る。撮らずに戻ったらnull。
  final Future<Uint8List?> Function() pickPhoto;

  /// 写真を上げて捕獲に付け、SnackBarに出す1文を返す。省略時は
  /// [sendCatchPhoto]で写真APIへ送る。
  final Future<String> Function({
    required String catchId,
    required Uint8List bytes,
  })?
  sendPhoto;

  /// 写真機能が使える環境か。省略時は[isPhotoFeatureConfigured]。
  final bool? canTakePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users =
        ref.watch(roomStreamProvider(roomId)).value?.users ?? const [];
    // 捕まえた相手の端末が役割を書き換えるまでは逃走者のまま見えるので、
    // その人を除いて数える。
    final remaining = users
        .where((u) => u.role == UserRole.fugitive && u.id != fugitiveUid)
        .length;

    // 画面内で完結する一時状態なのでhooksで持つ(AGENTS.md規約)。
    // カメラを開いている間と、捕獲を書いている間の両方で立てる。
    final isBusy = useState(false);

    // 撮れたら捕獲を書き(=ここで捕まえたことになる)、画面を閉じてから
    // 写真を裏で送る([sendCatchPhoto]の説明参照)。
    Future<void> takeAndSend() async {
      isBusy.value = true;
      try {
        final Uint8List? picked;
        try {
          picked = await pickPhoto();
        } on CameraPhotoTooLargeException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
          return;
        }
        // 撮らずにカメラを閉じたときは捕獲を書かず、この画面に留まる。
        if (picked == null || !context.mounted) return;
        final bytes = picked;
        final String catchId;
        try {
          catchId = await onCatch();
        } on Object catch (e) {
          debugPrint('[CatchCapture] 捕獲の送信に失敗: $e');
          if (!context.mounted) return;
          // 捕獲は書けていないので、閉じずに撮り直せるようにする。
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '「捕まえた」の送信に失敗しました。'
                '${userFacingErrorMessage(e)}',
              ),
            ),
          );
          return;
        }
        if (!context.mounted) return;
        // 閉じた後に結果を出すため、ゲーム画面にも出せるアプリ全体の
        // ScaffoldMessengerとリポジトリを、閉じる前に取っておく。
        final messenger = ScaffoldMessenger.of(context);
        final roomRepository = ref.read(roomRepositoryProvider);
        final send =
            sendPhoto ??
            ({required String catchId, required Uint8List bytes}) {
              // 撮り直して送るたびに新しいIDにする。写真APIは同じIDへの
              // 2回目のPUTを409で断るため(docs/photo-storage.md)。
              final photoId = FirebaseDatabase.instance.ref().push().key!;
              return sendCatchPhoto(
                upload: () => PhotoRepository().upload(
                  roomId: roomId,
                  photoId: photoId,
                  bytes: bytes,
                ),
                attach: () => roomRepository.attachCatchPhoto(
                  roomId,
                  catchId: catchId,
                  photoId: photoId,
                  fugitiveUid: fugitiveUid,
                ),
              );
            };
        unawaited(
          send(catchId: catchId, bytes: bytes).then(
            (message) =>
                messenger.showSnackBar(SnackBar(content: Text(message))),
          ),
        );
        Navigator.of(context).pop(true);
      } finally {
        if (context.mounted) isBusy.value = false;
      }
    }

    return CatchCaptureView(
      fugitiveName: fugitiveName,
      remainingFugitives: remaining,
      isPicking: isBusy.value,
      canTakePhoto: canTakePhoto ?? isPhotoFeatureConfigured,
      onTakePhoto: () => unawaited(takeAndSend()),
    );
  }
}

/// 「相手と場所を選ぶ→撮影画面」を、写真を送るまで繰り返す。
///
/// 撮影画面を撮らずに閉じたら([capture]が`false`)、選択からやり直させる
/// (屋内/屋外を選び直せるように)。選択シートを閉じたら(`null`)やめる。
/// 写真を送って捕獲が確定したら`true`、やめたら`false`を返す。
Future<bool> runCatchFlow({
  required Future<CatchTargetChoice?> Function() chooseTarget,
  required Future<bool> Function(CatchTargetChoice choice) capture,
}) async {
  while (true) {
    final choice = await chooseTarget();
    if (choice == null) return false;
    if (await capture(choice)) return true;
  }
}

/// 捕まえた瞬間の写真を送り、結果としてSnackBarに出す1文を返す。
///
/// 撮影画面を閉じた後に裏で呼ぶ(ゲーム中の鬼を送信完了まで待たせないため)。
/// そのため**時間制限は付けない**: [attach]のトランザクションは圏外だと
/// つながるまで終わらないが、端末に積まれてつながった時点で送られるので、
/// 途中で打ち切って「送れませんでした」と出すと、実際には後で届くのに
/// 失敗と伝えることになる。例外は投げずに文言へ変換する(裏で呼ぶので
/// 受け取る画面が無い)。
Future<String> sendCatchPhoto({
  required Future<void> Function() upload,
  required Future<void> Function() attach,
}) async {
  try {
    await upload();
    await attach();
    return '写真をみんなに送りました';
  } on CatchAlreadyUndoneException catch (e) {
    return '$e';
  } on Object catch (e) {
    debugPrint('[CatchCapture] 送信に失敗: $e');
    return '捕まえた瞬間の写真を送れませんでした';
  }
}

/// 撮影画面(モック03)。見た目だけの部品。
class CatchCaptureView extends StatelessWidget {
  /// 撮影画面を作る。
  const CatchCaptureView({
    super.key,
    required this.fugitiveName,
    required this.remainingFugitives,
    required this.isPicking,
    required this.canTakePhoto,
    required this.onTakePhoto,
  });

  /// 捕まえた相手の名前。
  final String fugitiveName;

  /// 残っている逃走者の人数。
  final int remainingFugitives;

  /// カメラを開いている最中か。
  final bool isPicking;

  /// 写真機能が使える環境か。
  final bool canTakePhoto;

  /// 「写真を撮る」。
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final busy = isPicking;
    return Scaffold(
      backgroundColor: catchSurfaceColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '逃走者 のこり $remainingFugitives人',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$fugitiveName を\n捕まえた！',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '写真を撮って送ると、捕まえたことになります',
                style: TextStyle(color: _captureSubInk, fontSize: 14),
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: Material(
                        color: canTakePhoto ? Colors.white : Colors.white54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: canTakePhoto && !busy ? onTakePhoto : null,
                          child: busy
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: catchSurfaceColor,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera,
                                  color: catchSurfaceColor,
                                  size: 44,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '写真を撮る',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
