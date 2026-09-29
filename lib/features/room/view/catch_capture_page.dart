import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 撮影画面が何もしなければゲーム画面へ戻るまでの時間(モックの12秒)。
const catchCaptureAutoCloseAfter = Duration(seconds: 12);

const _confirmBackground = Color(0xFF141413);
const _confirmButton = Color(0xFF26251F);
const _confirmSubInk = Color(0xFFA8A69E);
const _captureSubInk = Color(0xFFFFE0E0);

/// 鬼が「捕まえた」を確定した直後の、記念写真の撮影→確認画面(issue #140)。
///
/// 撮らなくてもゲームは進む。何もしなければ[catchCaptureAutoCloseAfter]で
/// ゲーム画面へ戻る(カメラを開いたらカウントダウンは止める)。
/// 撮った写真は「みんなに送る」を押したときだけ送る。
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
    final bytes = useState<Uint8List?>(null);
    final countdownStopped = useState(false);
    final isPicking = useState(false);
    final isSending = useState(false);
    final takenAt = useState<DateTime?>(null);
    final photoId = useRef<String?>(null);

    final stopwatch = useMemoized(Stopwatch.new);
    final tick = useState(0);
    useEffect(() {
      stopwatch.start();
      final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (countdownStopped.value) return;
        if (stopwatch.elapsed >= catchCaptureAutoCloseAfter) {
          countdownStopped.value = true;
          if (context.mounted) Navigator.of(context).pop();
          return;
        }
        tick.value++;
      });
      return timer.cancel;
    }, const []);

    Future<void> takePhoto() async {
      countdownStopped.value = true;
      isPicking.value = true;
      try {
        final picked = await pickCameraPhotoWithinLimit();
        if (!context.mounted) return;
        if (picked != null) {
          bytes.value = picked;
          takenAt.value = DateTime.now();
        }
      } on CameraPhotoTooLargeException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      } finally {
        if (context.mounted) isPicking.value = false;
      }
    }

    Future<void> send(Uint8List data) async {
      isSending.value = true;
      try {
        final id = photoId.value ??= FirebaseDatabase.instance
            .ref()
            .push()
            .key!;
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
        if (context.mounted) Navigator.of(context).pop();
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
          const SnackBar(content: Text('写真を送れませんでした。もう一度お試しください')),
        );
      } finally {
        if (context.mounted) isSending.value = false;
      }
    }

    final picked = bytes.value;
    return PopScope(
      canPop: !isSending.value,
      child: picked == null
          ? CatchCaptureView(
              fugitiveName: fugitiveName,
              remainingFugitives: remaining,
              progress: countdownStopped.value
                  ? null
                  : 1 -
                        stopwatch.elapsedMilliseconds /
                            catchCaptureAutoCloseAfter.inMilliseconds,
              remainingSeconds:
                  (catchCaptureAutoCloseAfter - stopwatch.elapsed).inSeconds +
                  1,
              isPicking: isPicking.value,
              canTakePhoto: isPhotoFeatureConfigured,
              onTakePhoto: () => unawaited(takePhoto()),
              onSkip: () => Navigator.of(context).pop(),
            )
          : CatchConfirmView(
              fugitiveName: fugitiveName,
              takenAt: takenAt.value ?? DateTime.now(),
              photo: Image.memory(picked, fit: BoxFit.cover),
              isSending: isSending.value,
              onSend: () => unawaited(send(picked)),
              onRetake: () => unawaited(takePhoto()),
              onDiscard: () => Navigator.of(context).pop(),
            ),
    );
  }
}

/// 撮影画面(モック03)。見た目だけの部品。
class CatchCaptureView extends StatelessWidget {
  /// [progress]がnullならカウントダウンを止めている(カメラを開いた後)。
  const CatchCaptureView({
    super.key,
    required this.fugitiveName,
    required this.remainingFugitives,
    required this.progress,
    required this.remainingSeconds,
    required this.isPicking,
    required this.canTakePhoto,
    required this.onTakePhoto,
    required this.onSkip,
  });

  /// 捕まえた相手の名前。
  final String fugitiveName;

  /// 残っている逃走者の人数。
  final int remainingFugitives;

  /// 自動で戻るまでの残り(1→0)。止めていればnull。
  final double? progress;

  /// 自動で戻るまでの残り秒数。
  final int remainingSeconds;

  /// カメラを開いている最中か。
  final bool isPicking;

  /// 写真機能が使える環境か。
  final bool canTakePhoto;

  /// 「写真を撮る」。
  final VoidCallback onTakePhoto;

  /// 「撮らずに続ける」。
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
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
                '記念に1枚どうぞ',
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
                          onTap: canTakePhoto && !isPicking
                              ? onTakePhoto
                              : null,
                          child: isPicking
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
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '撮らずに続ける',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (progress case final value?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: value.clamp(0, 1),
                    minHeight: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$remainingSeconds秒後にゲーム画面へもどります',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _captureSubInk, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 撮った写真の確認画面(モック04)。見た目だけの部品。
class CatchConfirmView extends StatelessWidget {
  /// [photo]は撮った写真を表示するウィジェット。
  const CatchConfirmView({
    super.key,
    required this.fugitiveName,
    required this.takenAt,
    required this.photo,
    required this.isSending,
    required this.onSend,
    required this.onRetake,
    required this.onDiscard,
  });

  /// 捕まえた相手の名前。
  final String fugitiveName;

  /// 撮った時刻。
  final DateTime takenAt;

  /// 写真。
  final Widget photo;

  /// 送信中か。
  final bool isSending;

  /// 「みんなに送る」。
  final VoidCallback onSend;

  /// 「撮り直す」。
  final VoidCallback onRetake;

  /// 「送らない」。
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: _confirmButton,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    return Scaffold(
      backgroundColor: _confirmBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_camera,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$fugitiveName を捕まえた',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatClockTime(takenAt.millisecondsSinceEpoch),
                    style: const TextStyle(color: _confirmSubInk, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 458),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox.expand(child: photo),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: isSending ? null : onSend,
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: const Text(
                    'みんなに送る',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: catchSurfaceColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: catchSurfaceColor.withValues(
                      alpha: 0.5,
                    ),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ルームの全員がすぐ見られます',
                textAlign: TextAlign.center,
                style: TextStyle(color: _confirmSubInk, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: isSending ? null : onRetake,
                        icon: const Icon(Icons.refresh),
                        label: const Text('撮り直す'),
                        style: buttonStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: isSending ? null : onDiscard,
                        style: buttonStyle,
                        child: const Text('送らない'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
