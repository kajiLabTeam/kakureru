import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';

import 'fixtures/ait_building14_scans.dart';

/// 物理AP[ap]が出している[ssid]番目のSSIDのBSSID。同じ[ap]なら末尾1文字
/// だけが違う(愛工大のAPと同じ形)。
String bssid(int ap, [int ssid = 0]) =>
    '02:00:00:00:${ap.toRadixString(16).padLeft(2, '0')}:'
    '0${ssid.toRadixString(16)}';

/// 屋外想定のシミュレーション: 全APを一律[attenuationDb]だけ弱め、
/// 端末の検出限界(-92dBm)を下回ったものはスキャンに出ないものとして落とす。
/// 9章の評価と同じ条件。
Map<String, int> simulateOutdoor(
  Map<String, int> scan, {
  int attenuationDb = 22,
}) => {
  for (final e in scan.entries)
    if (e.value - attenuationDb >= -92) e.key: e.value - attenuationDb,
};

void main() {
  group('groupByPhysicalAp', () {
    test('末尾1文字だけ違うBSSIDは同じ物理APにまとめ、RSSIは最大値を取る', () {
      final grouped = groupByPhysicalAp({
        bssid(1): -60, // eduroam
        bssid(1, 1): -55, // ait-wnet1x
        bssid(1, 2): -70, // ait-jimu
        bssid(2): -65,
      });

      expect(grouped.length, 2);
      expect(grouped.values.toList()..sort(), [-65, -55]);
    });

    test('別の物理APはまとめない', () {
      final grouped = groupByPhysicalAp({
        bssid(1): -60,
        bssid(2): -60,
        bssid(3): -60,
      });
      expect(grouped.length, 3);
    });

    test('どちらの端末がどのSSIDを拾ったかが違っても、同じAPとして突き合わせられる', () {
      // 自分はeduroamだけ、相手はait-wnet1xだけを拾ったスキャン。
      // BSSIDのままだと共通APは0件になる。
      final self = {bssid(1): -50, bssid(2): -55, bssid(3): -60};
      final target = {bssid(1, 1): -51, bssid(2, 1): -57, bssid(3, 1): -58};

      expect(self.keys.toSet().intersection(target.keys.toSet()), isEmpty);
      expect(calculateProximity(self, target), ProximityLevel.close);
    });
  });

  group('filterWeakSignals / prepareForProximity', () {
    test('-90dBm未満のAPを除外する(-90ちょうどは残す)', () {
      final filtered = filterWeakSignals({
        'strong': -50,
        'borderline': -90,
        'weak': -91,
      });
      expect(filtered.keys, unorderedEquals(['strong', 'borderline']));
    });

    test('集約してから足切りするので、1つでも強いSSIDがあるAPは残る', () {
      final prepared = prepareForProximity({
        bssid(1): -95, // 単独なら足切りされる
        bssid(1, 1): -85,
      });
      expect(prepared.values.toList(), [-85]);
    });
  });

  group('calculateMedianRssiDiff', () {
    test('共通APのRSSI差(絶対値)の中央値を返す(奇数件)', () {
      final diff = calculateMedianRssiDiff(
        {'a': -50, 'b': -60, 'c': -70},
        {'a': -52, 'b': -50, 'c': -75}, // 差: 2, 10, 5
      );
      expect(diff, 5);
    });

    test('偶数件なら中央2件の平均', () {
      final diff = calculateMedianRssiDiff(
        {'a': -50, 'b': -60, 'c': -70, 'd': -80},
        {'a': -51, 'b': -63, 'c': -75, 'd': -90}, // 差: 1, 3, 5, 10
      );
      expect(diff, 4);
    });

    test('大きな差も外れ値として捨てない(離れている証拠のため)', () {
      final diff = calculateMedianRssiDiff(
        {'a': -40, 'b': -45, 'c': -50},
        {'a': -70, 'b': -72, 'c': -52}, // 差: 30, 27, 2
      );
      expect(diff, 27);
    });

    test('共通APが無ければnull', () {
      expect(calculateMedianRssiDiff({'a': -50}, {'b': -50}), isNull);
    });
  });

  group('calculateTopOverlap', () {
    test('双方の上位5件のうち、両方に入っているAPの割合', () {
      final a = {for (var i = 0; i < 8; i++) 'ap$i': -40 - i}; // 上位: ap0..4
      final b = {
        'ap0': -40, 'ap1': -41, 'ap2': -42, // 共通の上位
        'x1': -30, 'x2': -31, // 自分側には無い強いAP
        'ap3': -60, 'ap4': -61,
      };
      expect(calculateTopOverlap(a, b), closeTo(3 / 5, 1e-9));
    });

    test('どちらかが5件未満なら、少ない方の件数で比べる', () {
      final a = {'ap0': -40, 'ap1': -41, 'ap2': -42};
      final b = {for (var i = 0; i < 10; i++) 'ap$i': -40 - i};
      expect(calculateTopOverlap(a, b), closeTo(1, 1e-9));
    });

    test('どちらかが空なら0', () {
      expect(calculateTopOverlap({}, {'a': -50}), 0);
    });
  });

  group('classifyProximity 境界値', () {
    test('共通AP数が3未満なら、他の指標がどうであれ検知なし', () {
      expect(
        classifyProximity(
          commonApCount: 2,
          medianRssiDiffDbm: 0,
          topOverlap: 1,
        ),
        ProximityLevel.notDetected,
      );
    });

    test('共通AP数がちょうど3なら判定対象になる', () {
      expect(
        classifyProximity(
          commonApCount: 3,
          medianRssiDiffDbm: 1,
          topOverlap: 1,
        ),
        ProximityLevel.close,
      );
    });

    test('RSSI差の中央値は7dBちょうどまで「近い」、それを超えたら「遠い」', () {
      expect(
        classifyProximity(
          commonApCount: 5,
          medianRssiDiffDbm: 7,
          topOverlap: 1,
        ),
        ProximityLevel.close,
      );
      expect(
        classifyProximity(
          commonApCount: 5,
          medianRssiDiffDbm: 7.5,
          topOverlap: 1,
        ),
        ProximityLevel.far,
      );
    });

    test('上位AP一致率は0.6ちょうどまで「近い」、それ未満は「遠い」', () {
      expect(
        classifyProximity(
          commonApCount: 5,
          medianRssiDiffDbm: 2,
          topOverlap: 0.6,
        ),
        ProximityLevel.close,
      );
      expect(
        classifyProximity(
          commonApCount: 5,
          medianRssiDiffDbm: 2,
          topOverlap: 0.4,
        ),
        ProximityLevel.far,
      );
    });

    test('RSSI差が計算不能(null)なら近いにはならない', () {
      expect(
        classifyProximity(
          commonApCount: 5,
          medianRssiDiffDbm: null,
          topOverlap: 1,
        ),
        ProximityLevel.far,
      );
    });
  });

  group('calculateProximity', () {
    test('APを挟んで対称な位置にいてRSSI差が小さく見えても、'
        '最寄りのAPが違えば「近い」にしない', () {
      // 共通APのRSSIはほぼ同じだが、それぞれの最寄り(上位)のAPが別物。
      final self = {
        bssid(1): -40,
        bssid(2): -42,
        bssid(3): -44,
        bssid(4): -46,
        bssid(10): -70,
        bssid(11): -72,
        bssid(12): -74,
      };
      final target = {
        bssid(5): -40,
        bssid(6): -42,
        bssid(7): -44,
        bssid(8): -46,
        bssid(10): -71,
        bssid(11): -72,
        bssid(12): -73,
      };
      expect(calculateMedianRssiDiff(self, target), lessThanOrEqualTo(1));
      expect(calculateProximity(self, target), ProximityLevel.far);
    });

    test('-90dBmより弱いAPしか共通していなければ検知なし', () {
      final self = {bssid(1): -91, bssid(2): -93, bssid(3): -95};
      final target = {bssid(1): -92, bssid(2): -94, bssid(3): -91};
      expect(calculateProximity(self, target), ProximityLevel.notDetected);
    });
  });

  group('愛工大14号館の実測データ(9章)', () {
    test('距離0mは「近い」(旧判定ではJaccard係数が足りず「遠い」だった)', () {
      expect(
        calculateProximity(
          building14Distance0mSelf,
          building14Distance0mTarget,
        ),
        ProximityLevel.close,
      );
    });

    test('同じ階で30m離れていれば「遠い」', () {
      expect(
        calculateProximity(
          building14Distance30mSelf,
          building14Distance30mTarget,
        ),
        ProximityLevel.far,
      );
    });

    test('階が違えば共通APが足りず「検知なし」', () {
      expect(
        calculateProximity(
          building14DifferentFloorsSelf,
          building14DifferentFloorsTarget,
        ),
        ProximityLevel.notDetected,
      );
    });

    test('屋外想定(全体を22dB弱める)でも、距離0mは「近い」のまま', () {
      expect(
        calculateProximity(
          simulateOutdoor(building14Distance0mSelf),
          simulateOutdoor(building14Distance0mTarget),
        ),
        ProximityLevel.close,
      );
    });

    test('屋外想定(全体を22dB弱める)でも、30m離れていれば「近い」にならない', () {
      expect(
        calculateProximity(
          simulateOutdoor(building14Distance30mSelf),
          simulateOutdoor(building14Distance30mTarget),
        ),
        isNot(ProximityLevel.close),
      );
    });
  });

  group('selectTopCommonAccessPoints', () {
    test('自分と相手のRSSI平均が強い順に上位3件を選ぶ', () {
      final self = {'weak': -70, 'mid': -60, 'strong': -50, 'strongest': -45};
      final target = {'weak': -75, 'mid': -62, 'strong': -55, 'strongest': -48};

      final top = selectTopCommonAccessPoints(self, target);

      expect(top.map((c) => c.bssid).toList(), ['strongest', 'strong', 'mid']);
    });

    test('-90dBmより弱いAPは候補から除外される', () {
      final self = {'ok': -85, 'tooWeak': -91};
      final target = {'ok': -88, 'tooWeak': -80};

      final top = selectTopCommonAccessPoints(self, target);

      expect(top.map((c) => c.bssid).toList(), ['ok']);
    });
  });

  group('selectTopAccessPoints', () {
    test('RSSIが強い順に上位count件を選ぶ', () {
      final bssidRssi = {
        'weakest': -90,
        'strong': -50,
        'mid': -65,
        'weak': -80,
        'strongest': -45,
      };

      final top = selectTopAccessPoints(bssidRssi, count: 3);

      expect(top.keys.toList(), ['strongest', 'strong', 'mid']);
    });

    test('同じRSSIならキーの辞書順で選ぶ(結果が実行ごとに変わらない)', () {
      final top = selectTopAccessPoints({
        'c': -50,
        'a': -50,
        'b': -50,
      }, count: 2);
      expect(top.keys.toList(), ['a', 'b']);
    });

    test('件数がcount以下ならそのまま全件返す', () {
      final bssidRssi = {'a': -50, 'b': -60};

      final top = selectTopAccessPoints(bssidRssi, count: 20);

      expect(top, bssidRssi);
    });

    test('デフォルトは上位40件', () {
      final bssidRssi = {
        for (var i = 0; i < 45; i++) 'ap$i': -30 - i, // ap0が最強
      };

      final top = selectTopAccessPoints(bssidRssi);

      expect(top.length, 40);
      expect(top.containsKey('ap0'), isTrue);
      expect(top.containsKey('ap39'), isTrue);
      expect(top.containsKey('ap40'), isFalse);
    });
  });

  group('applyProximityHysteresis', () {
    final baseTime = DateTime(2026, 1, 1, 12, 30);

    test('直前がclose/farで猶予時間内なら、その判定を保持する', () {
      final result = applyProximityHysteresis(
        lastDisplayedLevel: ProximityLevel.close,
        lastGoodAt: baseTime,
        now: baseTime.add(const Duration(seconds: 30)),
      );
      expect(result, ProximityLevel.close);
    });

    test('猶予時間を過ぎたらnotDetectedになる', () {
      final result = applyProximityHysteresis(
        lastDisplayedLevel: ProximityLevel.close,
        lastGoodAt: baseTime,
        now: baseTime.add(const Duration(minutes: 1)),
      );
      expect(result, ProximityLevel.notDetected);
    });

    test('直前の判定が無ければnotDetectedのまま', () {
      final result = applyProximityHysteresis(
        lastDisplayedLevel: null,
        lastGoodAt: null,
        now: baseTime,
      );
      expect(result, ProximityLevel.notDetected);
    });

    test('直前の判定自体がnotDetectedなら保持しない', () {
      final result = applyProximityHysteresis(
        lastDisplayedLevel: ProximityLevel.notDetected,
        lastGoodAt: baseTime,
        now: baseTime.add(const Duration(seconds: 1)),
      );
      expect(result, ProximityLevel.notDetected);
    });
  });

  group('applyNearestUidHysteresis', () {
    final baseTime = DateTime(2026, 1, 1, 12, 30);

    test('猶予時間内なら直前のuidを保持する', () {
      final result = applyNearestUidHysteresis(
        lastUid: 'oni1',
        lastFoundAt: baseTime,
        now: baseTime.add(const Duration(seconds: 30)),
      );
      expect(result, 'oni1');
    });

    test('猶予時間を過ぎたらnullになる', () {
      final result = applyNearestUidHysteresis(
        lastUid: 'oni1',
        lastFoundAt: baseTime,
        now: baseTime.add(const Duration(minutes: 1)),
      );
      expect(result, isNull);
    });

    test('一度も見つかっていなければnull', () {
      final result = applyNearestUidHysteresis(
        lastUid: null,
        lastFoundAt: null,
        now: baseTime,
      );
      expect(result, isNull);
    });
  });

  group('findNearestUid', () {
    final self = {bssid(1): -50, bssid(2): -55, bssid(3): -60};

    test('複数の鬼候補から、共通APのRSSI差の中央値が最小の1人を選ぶ', () {
      final candidates = {
        // 差: 2, 3, 1 → 中央値2 -> 最も近い
        'oni1': {bssid(1): -52, bssid(2): -58, bssid(3): -59},
        // 差: 10, 10, 10 → 中央値10
        'oni2': {bssid(1): -60, bssid(2): -65, bssid(3): -70},
      };

      expect(findNearestUid(self, candidates), 'oni1');
    });

    test('同じ物理APの別SSIDでも共通APとして数える', () {
      final candidates = {
        'oni1': {bssid(1, 1): -50, bssid(2, 2): -55, bssid(3, 3): -60},
      };
      expect(findNearestUid(self, candidates), 'oni1');
    });

    test('共通APが3個未満の候補は除外される', () {
      final candidates = {
        // 共通APは2個しかない(除外対象)。もし含まれれば差0で最も近くなるはず
        'oniFewCommon': {bssid(1): -50, bssid(2): -55},
        'oniEnoughCommon': {bssid(1): -60, bssid(2): -65, bssid(3): -70},
      };

      expect(findNearestUid(self, candidates), 'oniEnoughCommon');
    });

    test('全ての候補が除外対象なら検知なし(null)', () {
      final candidates = {
        'oni1': {bssid(1): -50, bssid(2): -55},
      };

      expect(findNearestUid(self, candidates), isNull);
    });

    test('候補が空ならnull', () {
      expect(findNearestUid(self, {}), isNull);
    });
  });
}
