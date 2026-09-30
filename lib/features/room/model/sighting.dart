import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'sighting.freezed.dart';
part 'sighting.g.dart';

/// RTDB `rooms/{roomId}/sightings/{photoId}` 1件ぶん。逃走者が撮った
/// 「見つけた鬼の写真」(目撃写真)のメタデータ。
///
/// 画像本体は足元の写真と同じR2のパス(`/rooms/{roomId}/photos/{photoId}`)
/// に置く。足元の写真(`photos/`)・捕まえた瞬間の写真(`catchPhotos/`)と
/// 区別するのはこのメタデータの置き場所だけで、R2側では区別しない。
/// 足元の写真と違い、撮ったかどうかに関係なくルームの全員が見られる。
///
/// `id` は photoId(`sightings/{photoId}`のキー。R2の画像本体と同じID)。
/// RTDBからは[Sighting.fromMap]で読む。
@freezed
abstract class Sighting with _$Sighting {
  const factory Sighting({
    required String id,

    /// 撮った人のuid。
    required String uid,

    /// 撮った時刻(ServerValue.timestamp)。
    required int takenAt,

    /// 撮った場所の説明(「1号館の前」など)。作る仕組みはまだ無く、
    /// 書かれていれば表示するだけ。
    String? place,
  }) = _Sighting;

  factory Sighting.fromJson(Map<String, dynamic> json) =>
      _$SightingFromJson(json);

  /// `sightings/{photoId}`はphotoIdがパスのキーで値の中には無いため、
  /// 呼び出し側からidを別途渡して合成する(RoomPhoto.fromMapと同じ形)。
  factory Sighting.fromMap(String id, Map<dynamic, dynamic> raw) =>
      Sighting.fromJson({...rtdbMapToJson(raw), 'id': id});
}
