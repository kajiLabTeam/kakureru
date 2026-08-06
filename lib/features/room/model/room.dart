import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';

part 'room.freezed.dart';

enum RoomStatus { waiting, playing, finished }

// Room は RTDB 上で meta/setting/users の3ノードに分かれており
// (docs/rtdb-schema.md の「一括書き込み・一括読み取りが使えない理由」参照)、
// 1つの Map として読めることもない。fromMap では
// - meta の中身を Room のトップレベルフィールドへ展開
// - users ({uid: {...}} という Map) を、uid を id として注入した List<RoomUser> へ変換
// という2つの整形を行っており、json_serializable の fromJson が前提とする
// 「JSON構造とクラス構造が対応している」形になっていない。そのため Room だけは
// fromJson/toJson を生成せず、fromMap を手書きにしている
// (RoomSetting・RoomUser 側は形が対応しているので生成コードに任せている)。
@freezed
abstract class Room with _$Room {
  const factory Room({
    required String id,
    required String roomCode,
    required String hostUserId,
    required RoomStatus status,
    double? basePressure,
    required int createdAt,
    int? startedAt,
    int? releasedAt,
    int? endsAt,
    int? endedAt,
    required RoomSetting setting,
    required List<RoomUser> users,
  }) = _Room;

  factory Room.fromMap(String id, Map<dynamic, dynamic> map) {
    final meta = rtdbMapToJson(map['meta'] as Map<dynamic, dynamic>? ?? {});
    final settingRaw = map['setting'] as Map<dynamic, dynamic>? ?? {};
    final usersRaw = map['users'] as Map<dynamic, dynamic>? ?? {};

    return Room(
      id: id,
      roomCode: meta['roomCode']?.toString() ?? '',
      hostUserId: meta['hostUserId'] as String? ?? '',
      status: _parseStatus(meta['status'] as String?),
      basePressure: (meta['basePressure'] as num?)?.toDouble(),
      createdAt: meta['createdAt'] as int? ?? 0,
      startedAt: meta['startedAt'] as int?,
      releasedAt: meta['releasedAt'] as int?,
      endsAt: meta['endsAt'] as int?,
      endedAt: meta['endedAt'] as int?,
      setting: RoomSetting.fromMap(settingRaw),
      users: usersRaw.entries
          .map((e) => RoomUser.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  static RoomStatus _parseStatus(String? value) {
    switch (value) {
      case 'PLAYING':
        return RoomStatus.playing;
      case 'FINISHED':
        return RoomStatus.finished;
      default:
        return RoomStatus.waiting;
    }
  }
}
