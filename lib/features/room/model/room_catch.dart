import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'room_catch.freezed.dart';
part 'room_catch.g.dart';

/// RTDB `rooms/{roomId}/catches/{catchId}` 1件ぶん。
///
/// 鬼が「捕まえた」ボタンで書く(issue #140)。以前は逃走者の自己申告で
/// `demonUserId`がnullだったが、今は捕まえた鬼が書くので必ず入る。
/// 古いルームのデータを読んでも落ちないよう、型としてはnullを許す。
@freezed
abstract class RoomCatch with _$RoomCatch {
  const factory RoomCatch({
    required String id,
    String? demonUserId,
    required String fugitiveUserId,
    required int caughtAt,

    /// 捕まえた瞬間の写真のID(`catchPhotos/{photoId}`)。撮らなかった・
    /// まだ送っていないときは省略される。
    String? catchPhotoId,
  }) = _RoomCatch;

  factory RoomCatch.fromJson(Map<String, dynamic> json) =>
      _$RoomCatchFromJson(json);

  /// `catches/{catchId}` は catchId がパスのキーであり値の中には無いため、
  /// 呼び出し側から id を別途渡して合成する(RoomPhoto.fromMapと同じ形)。
  factory RoomCatch.fromMap(String id, Map<dynamic, dynamic> raw) =>
      RoomCatch.fromJson({...rtdbMapToJson(raw), 'id': id});
}
