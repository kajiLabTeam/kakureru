import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'catch_photo.freezed.dart';
part 'catch_photo.g.dart';

/// RTDB `rooms/{roomId}/catchPhotos/{photoId}` 1件ぶん。捕まえた瞬間の写真。
///
/// 画像本体は足元の写真と同じR2のパス(`/rooms/{roomId}/photos/{photoId}`)
/// に置く。足元の写真(`photos/`)と区別するのはこのメタデータの置き場所
/// だけで、R2側では区別しない。足元の写真と違い、ルームの全員が見られる。
@freezed
abstract class CatchPhoto with _$CatchPhoto {
  const factory CatchPhoto({
    required String id,
    required String catchId,
    required String demonUid,
    required String fugitiveUid,
    required int takenAt,
  }) = _CatchPhoto;

  factory CatchPhoto.fromJson(Map<String, dynamic> json) =>
      _$CatchPhotoFromJson(json);

  factory CatchPhoto.fromMap(String id, Map<dynamic, dynamic> raw) =>
      CatchPhoto.fromJson({...rtdbMapToJson(raw), 'id': id});
}
