import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'room_photo.freezed.dart';
part 'room_photo.g.dart';

/// RTDB `rooms/{roomId}/photos/{photoId}` 1件ぶんのメタデータ。
///
/// 画像本体はここには無く、Cloudflare Workers側のR2に保存されている
/// (docs/photo-storage.md)。ここで扱うのは撮影者(uid)と撮影時刻のみ。
@freezed
abstract class RoomPhoto with _$RoomPhoto {
  const factory RoomPhoto({
    required String id,
    required String uid,
    required int takenAt,
  }) = _RoomPhoto;

  factory RoomPhoto.fromJson(Map<String, dynamic> json) =>
      _$RoomPhotoFromJson(json);

  /// `photos/{photoId}` は photoId がパスのキーであり値の中には無いため、
  /// 呼び出し側から id を別途渡して合成する(RoomUser.fromMapと同じ形)。
  factory RoomPhoto.fromMap(String id, Map<dynamic, dynamic> raw) =>
      RoomPhoto.fromJson({...rtdbMapToJson(raw), 'id': id});
}
