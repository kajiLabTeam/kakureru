import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';

part 'mission.freezed.dart';
part 'mission.g.dart';

/// RTDB `rooms/{roomId}/missions/{missionId}` 1件ぶん(アクセスポイント)。
///
/// サーバーが無いので**ホストの端末が書く**(`MissionController`)。同時に
/// 出すのは1件だけ。地点([spots])の数は回で変わり(`missionSpotCount`)、1地点に1人まで・
/// 先着。取り合いは `missions/{missionId}` へのトランザクションで決める
/// (`MissionRepository.claimMission`)。
@freezed
abstract class Mission with _$Mission {
  const factory Mission({
    required String id,

    /// 何回目のミッションか(1始まり。`missionDueDelays`参照)。
    required int round,

    /// 書いた時刻(ServerValue.timestamp)。
    required int createdAt,

    /// 期限(サーバー時刻のミリ秒)。この時刻ちょうどから取れない。
    required int expiresAt,

    /// 地点がすべて取られて終わった時刻。期限切れでは書かない。
    int? finishedAt,

    /// 地点。id順に並べる。
    @Default(<MissionSpot>[]) List<MissionSpot> spots,
  }) = _Mission;

  factory Mission.fromJson(Map<String, dynamic> json) =>
      _$MissionFromJson(json);

  /// `missions/{missionId}` は id がパスのキーであり値の中には無いため、
  /// 呼び出し側から id を別途渡して合成する(RoomCatch.fromMapと同じ形)。
  ///
  /// `spots` はRTDBではキー付きのマップなので、id順のリストへ直す。
  factory Mission.fromMap(String id, Map<dynamic, dynamic> raw) {
    final json = rtdbMapToJson(raw);
    final rawSpots = raw['spots'];
    final spots = <Map<String, dynamic>>[
      if (rawSpots is Map)
        for (final entry in rawSpots.entries)
          if (entry.value is Map)
            MissionSpot.fromMap(
              entry.key.toString(),
              entry.value as Map<dynamic, dynamic>,
            ).toJson(),
    ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return Mission.fromJson({...json, 'id': id, 'spots': spots});
  }
}

/// RTDB `missions/{missionId}/spots/{spotId}` 1件ぶん。1地点に1人まで。
@freezed
abstract class MissionSpot with _$MissionSpot {
  const factory MissionSpot({
    required String id,
    required double lat,
    required double lng,

    /// 判定の半径(m)。
    required double radiusM,

    /// 先に取った人のuid。未取得はnull。
    String? claimedBy,

    /// 取った時刻(サーバー時刻のミリ秒)。
    int? claimedAt,

    /// 取った人が引いたごほうび。引く前・知らない値はnull。
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    RewardType? reward,
  }) = _MissionSpot;

  factory MissionSpot.fromJson(Map<String, dynamic> json) =>
      _$MissionSpotFromJson(json);

  /// id はパスのキーなので別途渡す。
  factory MissionSpot.fromMap(String id, Map<dynamic, dynamic> raw) =>
      MissionSpot.fromJson({...rtdbMapToJson(raw), 'id': id});
}
