import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/features/mission/mission_rules.dart';

part 'mission_progress.freezed.dart';

/// いま受けているミッションに対する、この端末の進み具合。
///
/// RTDBには書かない。画面が消えていても判定を続けたいので(ポケットに
/// 入れたまま遊ぶ)、`MissionController`(Riverpod)が1秒ごとに更新する。
/// ミッションか、向かっている地点([spotId])が変わったら最初からやり直す。
@freezed
abstract class MissionProgress with _$MissionProgress {
  const factory MissionProgress({
    /// どのミッションの進み具合か。ミッションが無ければnull。
    String? missionId,

    /// どの地点への到着判定か(いちばん近い、空いている地点)。
    String? spotId,

    /// アクセスポイントの到着判定。
    @Default(initialArrival) ArrivalProgress arrival,
  }) = _MissionProgress;
}
