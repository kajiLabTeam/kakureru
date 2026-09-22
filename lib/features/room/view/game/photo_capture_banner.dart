import 'package:flutter/material.dart';
import 'package:kakureru/features/room/model/photo_capture_state.dart';

/// 撮影間隔(`setting/photoIntervalSec`)が来たら出す「撮影する」バナー。
///
/// バックグラウンド自動撮影は行わない(Phase 1)。アップロードに失敗して
/// 画像を保持している間は、撮り直しなしで送り直せる「再送する」ボタンに
/// 差し替える。[PreReleaseBanner]と同じ、宣言的なContainer/Rowだけで
/// 組んだバナー(ダイアログ・SnackBar等の命令的な呼び出しはしない。
/// game_alerts.dartが対処しているビルド中のNavigator操作の事故を
/// そもそも起こしようが無い作りにしている)。
class PhotoCaptureBanner extends StatelessWidget {
  const PhotoCaptureBanner({
    super.key,
    required this.state,
    required this.onCapture,
    required this.onResend,
  });

  final PhotoCaptureState state;
  final VoidCallback onCapture;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final hasPending = state.pendingBytes != null;
    final label = state.isUploading
        ? 'アップロード中...'
        : hasPending
        ? '再送する'
        : '撮影する';
    final onPressed = state.isUploading
        ? null
        : hasPending
        ? onResend
        : onCapture;

    return Container(
      width: double.infinity,
      color: const Color(0xFFEFF7ED),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('📷', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.lastErrorMessage ?? '撮影のタイミングです',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF2E6B3E)),
            ),
          ),
          TextButton(onPressed: onPressed, child: Text(label)),
        ],
      ),
    );
  }
}
