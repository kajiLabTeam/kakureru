import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';

void main() {
  group('classifyProximity (7/22実測値)', () {
    test('Jaccard 0.679 / RSSI差 3.2dBm → 近い', () {
      final result = classifyProximity(
        commonApCount: 10,
        jaccardIndex: 0.679,
        averageRssiDiffDbm: 3.2,
      );
      expect(result, ProximityLevel.close);
    });

    test('Jaccard 0.370 / RSSI差 8.7dBm → 遠い', () {
      final result = classifyProximity(
        commonApCount: 8,
        jaccardIndex: 0.370,
        averageRssiDiffDbm: 8.7,
      );
      expect(result, ProximityLevel.far);
    });

    test('Jaccard 0.211 → 検知なし', () {
      final result = classifyProximity(
        commonApCount: 5,
        jaccardIndex: 0.211,
        averageRssiDiffDbm: 2,
      );
      expect(result, ProximityLevel.notDetected);
    });
  });

  group('classifyProximity 境界値', () {
    test('共通AP数が3未満なら、他の指標がどうであれ検知なし', () {
      final result = classifyProximity(
        commonApCount: 2,
        jaccardIndex: 0.9,
        averageRssiDiffDbm: 1,
      );
      expect(result, ProximityLevel.notDetected);
    });

    test('共通AP数がちょうど3なら判定対象になる', () {
      final result = classifyProximity(
        commonApCount: 3,
        jaccardIndex: 0.5,
        averageRssiDiffDbm: 1,
      );
      expect(result, ProximityLevel.close);
    });

    test('RSSI差が計算不能(null)なら近いにはならない', () {
      final result = classifyProximity(
        commonApCount: 5,
        jaccardIndex: 0.8,
        averageRssiDiffDbm: null,
      );
      expect(result, ProximityLevel.far);
    });
  });

  group('filterWeakSignals', () {
    test('-80dBm未満のAPを除外する', () {
      final filtered = filterWeakSignals({
        'strong': -50,
        'borderline': -80,
        'weak': -81,
        'veryWeak': -95,
      });
      expect(filtered.keys, containsAll(['strong', 'borderline']));
      expect(filtered.containsKey('weak'), isFalse);
      expect(filtered.containsKey('veryWeak'), isFalse);
    });

    test('calculateProximityの判定にも足切りが反映される', () {
      // 共通APは3個(強いもの)だが、弱いAPを足しても共通AP数は増えない扱いになる
      final self = {'ap1': -50, 'ap2': -55, 'ap3': -60, 'apWeak': -85};
      final target = {'ap1': -52, 'ap2': -57, 'ap3': -62, 'apWeak': -88};

      // 弱いAPを除いても共通3個なのでnotDetectedにはならない
      final result = calculateProximity(self, target);
      expect(result, isNot(ProximityLevel.notDetected));

      // 弱いAPしか無い場合は足切り後に共通0個でnotDetected
      final onlyWeakSelf = {'apWeak': -85};
      final onlyWeakTarget = {'apWeak': -88};
      expect(calculateProximity(onlyWeakSelf, onlyWeakTarget), ProximityLevel.notDetected);
    });
  });

  group('calculateAverageRssiDiff', () {
    test('20dBmを超える差は外れ値として除外される', () {
      final diff = calculateAverageRssiDiff(
        {'a': -50, 'b': -60, 'outlier': -40},
        {'a': -52, 'b': -61, 'outlier': -85}, // outlierは差45dBm
      );
      // outlierを除いた a,b の差(2, 1)の平均になっているはず
      expect(diff, closeTo(1.5, 1e-9));
    });
  });

  group('selectTopCommonAccessPoints', () {
    test('自分と相手のRSSI平均が強い順に上位3件を選ぶ', () {
      final self = {'weak': -70, 'mid': -60, 'strong': -50, 'strongest': -45};
      final target = {'weak': -75, 'mid': -62, 'strong': -55, 'strongest': -48};

      final top = selectTopCommonAccessPoints(self, target, count: 3);

      expect(top.map((c) => c.bssid).toList(), ['strongest', 'strong', 'mid']);
    });

    test('弱いAPは候補から除外される', () {
      final self = {'ok': -60, 'tooWeak': -85};
      final target = {'ok': -62, 'tooWeak': -90};

      final top = selectTopCommonAccessPoints(self, target, count: 3);

      expect(top.length, 1);
      expect(top.first.bssid, 'ok');
    });
  });

  group('findNearestUid', () {
    test('複数の鬼候補から、共通APのRSSI差平均が最小の1人を選ぶ', () {
      final self = {'a': -50, 'b': -55, 'c': -60};
      final candidates = {
        // 差平均: (2+3+1)/3 = 2.0 -> 最も近い
        'oni1': {'a': -52, 'b': -58, 'c': -59},
        // 差平均: (10+10+10)/3 = 10.0
        'oni2': {'a': -60, 'b': -65, 'c': -70},
      };

      expect(findNearestUid(self, candidates), 'oni1');
    });

    test('共通APが3個未満の候補は除外される', () {
      final self = {'a': -50, 'b': -55, 'c': -60};
      final candidates = {
        // 共通APは2個しかない(除外対象)。もし含まれれば差平均0で最も近くなるはず
        'oniFewCommon': {'a': -50, 'b': -55},
        'oniEnoughCommon': {'a': -60, 'b': -65, 'c': -70},
      };

      expect(findNearestUid(self, candidates), 'oniEnoughCommon');
    });

    test('全ての候補が除外対象なら検知なし(null)', () {
      final self = {'a': -50, 'b': -55, 'c': -60};
      final candidates = {
        'oni1': {'a': -50, 'b': -55},
      };

      expect(findNearestUid(self, candidates), isNull);
    });

    test('候補が空ならnull', () {
      expect(findNearestUid({'a': -50}, {}), isNull);
    });
  });
}
