import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';

/// ダウンロード・キャッシュ込みで写真本体を表示する。取得中はスピナー、
/// 失敗時は再読み込みボタンを出す。
///
/// [PhotoTile]と[PhotoViewerPage]の両方が使うため独立したウィジェットに
/// している(「見られる」と判定された写真にだけ使うこと。可視性の判定は
/// ここでは行わない)。
class DownloadedPhotoImage extends HookWidget {
  const DownloadedPhotoImage({
    super.key,
    required this.roomId,
    required this.photoId,
    this.fit = BoxFit.cover,
  });

  final String roomId;
  final String photoId;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final retryCount = useState(0);
    final repository = useMemoized(PhotoRepository.new, const []);
    final future = useMemoized(
      () => repository.download(roomId: roomId, photoId: photoId),
      [roomId, photoId, retryCount.value],
    );
    final snapshot = useFuture(future);

    if (snapshot.connectionState != ConnectionState.done) {
      return const ColoredBox(
        color: Color(0xFFE5E7EB),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final bytes = snapshot.data;
    if (snapshot.hasError || bytes == null) {
      return ColoredBox(
        color: const Color(0xFFE5E7EB),
        child: Center(
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: () => retryCount.value++,
          ),
        ),
      );
    }

    return Image.memory(bytes, fit: fit);
  }
}
