import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/wifi/model/clue_meter_sample.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

/// 手がかりカードのメーター・電波の一致・傾向の計算のテスト。
void main() {
  group('clueMeterFromMetrics', () {
    test('RSSI差2dBなら距離スコアは満点(一致率1で100)', () {
      expect(
        clueMeterFromMetrics(medianRssiDiffDbm: 2, topOverlap: 1),
        closeTo(100, 1e-9),
      );
    });

    test('RSSI差2dB・一致率0なら距離の重みぶん(70)だけ', () {
      expect(
        clueMeterFromMetrics(medianRssiDiffDbm: 2, topOverlap: 0),
        closeTo(70, 1e-9),
      );
    });

    test('RSSI差14dBなら距離スコアは0(一致率の重みぶんだけ残る)', () {
      expect(
        clueMeterFromMetrics(medianRssiDiffDbm: 14, topOverlap: 1),
        closeTo(30, 1e-9),
      );
      expect(
        clueMeterFromMetrics(medianRssiDiffDbm: 14, topOverlap: 0),
        closeTo(0, 1e-9),
      );
    });

    test('RSSI差が14dBを超えても距離スコアは0で止まる(負にならない)', () {
      expect(
        clueMeterFromMetrics(medianRssiDiffDbm: 30, topOverlap: 0.4),
        closeTo(12, 1e-9),
      );
    });

    test('RSSI差が2dB未満でも距離スコアは1で止まる', () {
      expect(
        clueMeterFromMetrics(medianRssiDiffDbm: 0, topOverlap: 0),
        closeTo(70, 1e-9),
      );
    });

    test('中間: RSSI差8dB・一致率0.6は (0.7×0.5 + 0.3×0.6)×100 = 53', () {
      expect(
        clueMeterFromMetrics(medianRssiDiffDbm: 8, topOverlap: 0.6),
        closeTo(53, 1e-9),
      );
    });
  });

  group('calculateClueMeter', () {
    test('共通APが無ければnull', () {
      expect(
        calculateClueMeter(
          {'aa:aa:aa:aa:aa:01': -50},
          {'bb:bb:bb:bb:bb:01': -50},
        ),
        isNull,
      );
    });

    test('同じスキャン結果同士なら100', () {
      const scan = {
        'aa:aa:aa:aa:aa:10': -45,
        'bb:bb:bb:bb:bb:10': -55,
        'cc:cc:cc:cc:cc:10': -65,
      };
      expect(calculateClueMeter(scan, scan), closeTo(100, 1e-9));
    });

    test('-90dBmより弱いAPは計算に使わない(判定と同じ前処理)', () {
      expect(
        calculateClueMeter(
          {'aa:aa:aa:aa:aa:10': -95},
          {'aa:aa:aa:aa:aa:10': -95},
        ),
        isNull,
      );
    });
  });

  group('countMatchingSignals', () {
    WifiApComparison ap(int self, int target) =>
        WifiApComparison(bssid: '$self/$target', selfRssi: self, targetRssi: target);

    test('RSSI差7dB以下のAPだけを数える', () {
      expect(
        countMatchingSignals([ap(-50, -57), ap(-60, -68), ap(-70, -65)]),
        2,
      );
    });

    test('差の向き(自分が強い/相手が強い)は問わない', () {
      expect(countMatchingSignals([ap(-50, -43), ap(-43, -50)]), 2);
    });

    test('上位3件より後ろは数えない', () {
      expect(
        countMatchingSignals([
          ap(-50, -70),
          ap(-55, -75),
          ap(-60, -80),
          ap(-65, -65),
        ]),
        0,
      );
    });

    test('共通APが無ければ0', () {
      expect(countMatchingSignals(const []), 0);
    });
  });

  group('clueTrendOf', () {
    final t0 = DateTime(2026, 9, 28, 12);
    ClueMeterSample at(int seconds, double meter) =>
        ClueMeterSample(at: t0.add(Duration(seconds: seconds)), meter: meter);

    test('履歴が無ければ変わらない', () {
      expect(clueTrendOf(const []), ClueTrend.unchanged);
    });

    test('1件だけ(比べる値が無い)なら変わらない', () {
      expect(clueTrendOf([at(0, 40)]), ClueTrend.unchanged);
    });

    test('6秒以上前より5以上上がったら近づいた', () {
      expect(clueTrendOf([at(0, 40), at(10, 45)]), ClueTrend.closer);
    });

    test('6秒以上前より5以上下がったら離れた', () {
      expect(clueTrendOf([at(0, 40), at(10, 35)]), ClueTrend.farther);
    });

    test('変化が5未満なら変わらない', () {
      expect(clueTrendOf([at(0, 40), at(10, 44.9)]), ClueTrend.unchanged);
      expect(clueTrendOf([at(0, 40), at(10, 35.1)]), ClueTrend.unchanged);
    });

    test('6秒未満前の値とは比べない(比べる値が無ければ変わらない)', () {
      expect(clueTrendOf([at(0, 40), at(5, 60)]), ClueTrend.unchanged);
    });

    test('ちょうど6秒前の値は基準に使う', () {
      expect(clueTrendOf([at(0, 40), at(6, 60)]), ClueTrend.closer);
    });

    test('6秒以上前の値のうち最も新しいものと比べる', () {
      // 基準はt=4(=10-6)以前で最も新しいt=3の50。60-50=10で近づいた。
      // (t=0の70と比べると離れたになってしまう)
      expect(
        clueTrendOf([at(0, 70), at(3, 50), at(8, 55), at(10, 60)]),
        ClueTrend.closer,
      );
    });
  });

  group('appendClueSample', () {
    final t0 = DateTime(2026, 9, 28, 12);
    ClueMeterSample at(int seconds, double meter) =>
        ClueMeterSample(at: t0.add(Duration(seconds: seconds)), meter: meter);

    test('末尾に足す', () {
      expect(appendClueSample([at(0, 1)], at(10, 2)), [at(0, 1), at(10, 2)]);
    });

    test('保持期間より古いものは捨てるが、基準用に直前の1件は残す', () {
      final result = appendClueSample(
        [at(0, 1), at(10, 2), at(20, 3)],
        at(100, 4),
      );
      expect(result, [at(20, 3), at(100, 4)]);
    });

    test('保持期間内のものはすべて残す', () {
      final result = appendClueSample([at(50, 1), at(60, 2)], at(100, 3));
      expect(result, [at(50, 1), at(60, 2), at(100, 3)]);
    });
  });
}
