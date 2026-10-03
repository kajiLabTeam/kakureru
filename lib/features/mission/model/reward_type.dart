import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/features/mission/mission_timing.dart';

/// ごほうびが誰に効くか。カードには必ずこれを書く(鬼をジャマするもの・
/// 自分がトクするもの・ハズレが混ざるため)。
enum RewardTarget {
  /// 鬼をジャマする。効果はルーム全員の端末で同じ見え方にする。
  demon,

  /// 引いた本人がトクする。
  self,

  /// ハズレ(何も起きない)。
  selfMiss,
}

/// 当たり3種(合計)の確率(%)。残りはハズれ([rewardMissOddsPercent])。
const rewardWinningOddsPercent = 80.0;

/// ハズレ([RewardType.miss])の確率(%)。
const rewardMissOddsPercent = 20.0;

/// 当たり1種あたりの確率(%)。当たり3種で均等に分ける。
const rewardWinningOddsPercentEach = rewardWinningOddsPercent / 3;

/// ミッションのごほうび。RTDBの `missions/{id}/spots/{spotId}/reward` と
/// `effects/{effectId}/type` に書く文字列を持つ。
///
/// ハズレ([miss]。何も起きない)も1種類ある。確率は[oddsPercent]を参照
/// (抽選は[drawReward]で行う)。
@JsonEnum(valueField: 'raw')
enum RewardType {
  /// 30秒、鬼の端末で Wi-Fi と気圧の手がかりを隠す。
  blockClues(
    raw: 'block_clues',
    title: '鬼の手がかりを止める',
    description: '30秒のあいだ、鬼は Wi-Fi と気圧を見られなくなる',
    target: RewardTarget.demon,
    duration: rewardEffectDuration,
    oddsPercent: rewardWinningOddsPercentEach,
  ),

  /// 2分30秒、全員の地図で引いた本人のピンを2倍にする。
  enlargeSelfIcon(
    raw: 'enlarge_self_icon',
    title: '自分のアイコンを大きくする',
    description: '2分30秒のあいだ、みんなの地図で自分のアイコンが大きくなる',
    target: RewardTarget.self,
    duration: enlargeSelfIconDuration,
    oddsPercent: rewardWinningOddsPercentEach,
  ),

  /// 引いた本人の次の撮影タイムを1回飛ばす(回数ものなので時間は0)。
  skipFootPhoto(
    raw: 'skip_foot_photo',
    title: '足元写真を1回まぬがれる',
    description: '次の撮影タイムを飛ばせる',
    target: RewardTarget.self,
    duration: Duration.zero,
    oddsPercent: rewardWinningOddsPercentEach,
  ),

  /// ハズレ。何も起きない(時間で効かないので時間は0)。
  miss(
    raw: 'miss',
    title: 'ハズレ',
    description: 'なにも起きない',
    target: RewardTarget.selfMiss,
    duration: Duration.zero,
    oddsPercent: rewardMissOddsPercent,
  );

  const RewardType({
    required this.raw,
    required this.title,
    required this.description,
    required this.target,
    required this.duration,
    required this.oddsPercent,
  });

  /// RTDBに書く文字列。
  final String raw;

  /// カードの見出し。
  final String title;

  /// カードの説明文。
  final String description;

  /// 誰に効くか。
  final RewardTarget target;

  /// 効いている時間。回数もの([skipFootPhoto])とハズレ([miss])は0。
  final Duration duration;

  /// 抽選で引かれる確率(%)。全[values]の合計は100になる。
  final double oddsPercent;

  /// ハズレかどうか。
  bool get isMiss => target == RewardTarget.selfMiss;

  /// カードのタグに出す長さ(「30秒」「2分30秒」「1回」)。ハズレは何も
  /// 起きないので出さない(null)。
  String? get durationLabel {
    if (isMiss) return null;
    final total = duration.inSeconds;
    if (total == 0) return '1回';
    final minutes = total ~/ 60;
    final seconds = total % 60;
    if (minutes == 0) return '$seconds秒';
    return seconds == 0 ? '$minutes分' : '$minutes分$seconds秒';
  }

  /// [raw]から引く。知らない値ならnull(新しい版の端末が書いたごほうびなど)。
  static RewardType? fromRaw(String? raw) {
    for (final type in values) {
      if (type.raw == raw) return type;
    }
    return null;
  }
}
