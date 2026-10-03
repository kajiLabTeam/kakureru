import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';

void main() {
  test('確率の合計は100%', () {
    final total = RewardType.values.fold<double>(
      0,
      (sum, type) => sum + type.oddsPercent,
    );
    expect(total, closeTo(100, 1e-9));
  });

  test('ハズレは1種類だけで、何も起きない(時間は0)', () {
    final misses = RewardType.values.where((t) => t.isMiss).toList();
    expect(misses, [RewardType.miss]);
    expect(RewardType.miss.duration, Duration.zero);
    expect(RewardType.miss.oddsPercent, rewardMissOddsPercent);
  });

  test('自分のアイコンを大きくするは当たりで、2分30秒効く', () {
    expect(RewardType.enlargeSelfIcon.isMiss, isFalse);
    expect(
      RewardType.enlargeSelfIcon.duration,
      const Duration(minutes: 2, seconds: 30),
    );
  });

  test('durationLabelは秒・分秒・回数で出し、ハズレは出さない', () {
    expect(RewardType.blockClues.durationLabel, '30秒');
    expect(RewardType.enlargeSelfIcon.durationLabel, '2分30秒');
    expect(RewardType.skipFootPhoto.durationLabel, '1回');
    expect(RewardType.miss.durationLabel, isNull);
  });

  test('古い版の big_demon_icon は知らない値として読まない', () {
    expect(RewardType.fromRaw('big_demon_icon'), isNull);
    expect(RewardType.fromRaw('miss'), RewardType.miss);
  });
}
