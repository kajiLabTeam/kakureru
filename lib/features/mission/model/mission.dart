import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';

part 'mission.freezed.dart';
part 'mission.g.dart';

/// ミッションの種類。RTDBの `missions/{id}/type` に書く文字列を持つ。
@JsonEnum(valueField: 'raw')
enum MissionType {
  /// 地図上の地点(半径15m)へ行く。先着1名で特典を引ける。
  accessPoint(raw: 'access_point', timeLimit: Duration(seconds: 180)),

  /// Wi-Fiの判定を「反応なし」から「反応あり」に変える。全員が挑める。
  /// 報酬はまだ決めていないので、達成の表示までにする。
  approachDemon(raw: 'approach_demon', timeLimit: Duration(seconds: 120));

  const MissionType({required this.raw, required this.timeLimit});

  /// RTDBに書く文字列。
  final String raw;

  /// 制限時間(`expiresAt = createdAt + timeLimit`)。
  final Duration timeLimit;
}

/// RTDB `rooms/{roomId}/missions/{missionId}` 1件ぶん。
///
/// サーバーが無いので**ホストの端末が書く**(`MissionScheduler`)。同時に
/// 出すのは1件だけ。先着1名の取り合いは `claimedBy` へのトランザクションで
/// 決める(`MissionRepository.claimMission`)。
@freezed
abstract class Mission with _$Mission {
  const factory Mission({
    required String id,
    required MissionType type,

    /// 書いた時刻(ServerValue.timestamp)。
    required int createdAt,

    /// 期限(サーバー時刻のミリ秒)。この時刻ちょうどから取れない。
    required int expiresAt,

    /// 地点(access_pointのみ)。
    double? lat,
    double? lng,

    /// 判定の半径(m。access_pointのみ)。
    double? radiusM,

    /// 先に取った人のuid。未取得はnull。
    String? claimedBy,

    /// 取った時刻(サーバー時刻のミリ秒)。
    int? claimedAt,

    /// 取った人が引いた特典。引く前・知らない値はnull。
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    RewardType? reward,
  }) = _Mission;

  factory Mission.fromJson(Map<String, dynamic> json) =>
      _$MissionFromJson(json);

  /// `missions/{missionId}` は id がパスのキーであり値の中には無いため、
  /// 呼び出し側から id を別途渡して合成する(RoomCatch.fromMapと同じ形)。
  factory Mission.fromMap(String id, Map<dynamic, dynamic> raw) =>
      Mission.fromJson({...rtdbMapToJson(raw), 'id': id});
}
