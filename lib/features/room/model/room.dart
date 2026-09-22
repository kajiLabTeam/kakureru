import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';

part 'room.freezed.dart';

/// ルームの進行状態。[raw]はRTDBの`rooms/{roomId}/meta/status`に入る文字列。
/// 読み書きの両方でこの定数を使い、生の文字列をコード中に散らさない。
enum RoomStatus {
  waiting('WAITING'),
  playing('PLAYING'),
  finished('FINISHED');

  const RoomStatus(this.raw);

  /// RTDBに保存される文字列表現。
  final String raw;

  /// RTDBの文字列から変換する。未設定・未知の値は[waiting]として扱う
  /// (古いルームや書き込み途中のルームで画面が壊れないようにするため)。
  static RoomStatus fromRaw(String? value) {
    for (final status in RoomStatus.values) {
      if (status.raw == value) return status;
    }
    return RoomStatus.waiting;
  }
}

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
    String? pendingDemonUid,
    String? demonRevokeUid,
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
      status: RoomStatus.fromRaw(meta['status'] as String?),
      basePressure: (meta['basePressure'] as num?)?.toDouble(),
      createdAt: meta['createdAt'] as int? ?? 0,
      startedAt: meta['startedAt'] as int?,
      releasedAt: meta['releasedAt'] as int?,
      endsAt: meta['endsAt'] as int?,
      endedAt: meta['endedAt'] as int?,
      pendingDemonUid: meta['pendingDemonUid'] as String?,
      demonRevokeUid: meta['demonRevokeUid'] as String?,
      setting: RoomSetting.fromMap(settingRaw),
      users: usersRaw.entries
          .map(
            (e) => RoomUser.fromMap(
              e.key.toString(),
              e.value as Map<dynamic, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
