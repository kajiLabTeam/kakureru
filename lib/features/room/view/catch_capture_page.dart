import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _captureSubInk = Color(0xFFFFE0E0);

/// 鬼が「捕まえた」を確定した直後の、記念写真の撮影画面(issue #140)。
///
/// 撮らなくてもゲームは進む(端末の「戻る」で戻る)。時間切れで
/// 勝手にゲーム画面へ戻すことはしない(撮る前に閉じてしまうため)。
/// 撮った写真は確認画面を挟まずにそのまま全員へ送る(送る・送らない・
/// 撮り直すを選ばせると、捕まえた直後の手間が増えるため)。
class CatchCapturePage extends HookConsumerWidget {
  /// [catchId]は`reportCatch`が返した捕獲のID。
  const CatchCapturePage({
    super.key,
    required this.roomId,
    required this.catchId,
    required this.fugitiveUid,
    required this.fugitiveName,
  });

  /// ルームID。
  final String roomId;

  /// 写真を結びつける捕獲のID。
  final String catchId;

  /// 捕まえた相手のuid。
  final String fugitiveUid;

  /// 捕まえた相手の名前。
  final String fugitiveName;

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
    final isPicking = useState(false);
    final isSending = useState(false);

    Future<void> send(Uint8List data) async {
      isSending.value = true;
      try {
        // 撮り直して送るたびに新しいIDにする。写真APIは同じIDへの
        // 2回目のPUTを409で断るため、R2へ上げた後にRTDBへの書き込みだけが
        // 失敗した場合、同じIDでは二度と送れなくなる(docs/photo-storage.md)。
        final id = FirebaseDatabase.instance.ref().push().key!;
        await PhotoRepository().upload(
          roomId: roomId,
          photoId: id,
          bytes: data,
        );
        await ref
            .read(roomRepositoryProvider)
            .attachCatchPhoto(
              roomId,
              catchId: catchId,
              photoId: id,
              fugitiveUid: fugitiveUid,
            );
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('写真をみんなに送りました')));
        Navigator.of(context).pop();
      } on CatchAlreadyUndoneException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        Navigator.of(context).pop();
      } on Object catch (e) {
        debugPrint('[CatchCapture] 送信に失敗: $e');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真を送れませんでした。もう一度撮ってください')),
        );
      } finally {
        if (context.mounted) isSending.value = false;
      }
    }

    // 撮ったら確認画面を挟まずにそのまま送る。
    Future<void> takeAndSend() async {
      isPicking.value = true;
      Uint8List? picked;
      try {
        picked = await pickCameraPhotoWithinLimit();
      } on CameraPhotoTooLargeException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      } finally {
        if (context.mounted) isPicking.value = false;
      }
      if (picked == null || !context.mounted) return;
      await send(picked);
    }

    return PopScope(
      canPop: !isSending.value,
      child: CatchCaptureView(
        fugitiveName: fugitiveName,
        remainingFugitives: remaining,
        isPicking: isPicking.value,
        isSending: isSending.value,
        canTakePhoto: isPhotoFeatureConfigured,
        onTakePhoto: () => unawaited(takeAndSend()),
      ),
    );
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
    required this.isSending,
    required this.canTakePhoto,
    required this.onTakePhoto,
  });

  /// 捕まえた相手の名前。
  final String fugitiveName;

  /// 残っている逃走者の人数。
  final int remainingFugitives;

  /// カメラを開いている最中か。
  final bool isPicking;

  /// 撮った写真を送っている最中か。
  final bool isSending;

  /// 写真機能が使える環境か。
  final bool canTakePhoto;

  /// 「写真を撮る」。
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final busy = isPicking || isSending;
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
                '記念に1枚どうぞ。撮るとそのまま全員に送ります',
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
                    Text(
                      isSending ? '送信中…' : '写真を撮る',
                      style: const TextStyle(
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
