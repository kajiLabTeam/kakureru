import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/wifi/wifi_math.dart';

/// 距離感トラック(相手詳細カードの横バー)へRSSIを置く計算のテスト。
void main() {
  group('rssiTrackFraction', () {
    test('レンジの下端は左端(0.0)', () {
      expect(rssiTrackFraction(rssiTrackMinDbm), closeTo(0, 1e-9));
    });

    test('レンジの上端は右端(1.0)', () {
      expect(rssiTrackFraction(rssiTrackMaxDbm), closeTo(1, 1e-9));
    });

    test('レンジの中央は0.5', () {
      // -90 と -40 の中点は -65。
      expect(rssiTrackFraction(-65), closeTo(0.5, 1e-9));
    });

    test('レンジ外は端へ丸める(トラックからドットをはみ出させない)', () {
      expect(rssiTrackFraction(-120), 0);
      expect(rssiTrackFraction(-10), 1);
    });

    test('電波が強いほど右へ行く(単調増加)', () {
      // 「自分のドットが相手より右 = 自分の方がそのAPに近い」と読めることが
      // この表示の前提なので、向きを取り違えていないことを固定する。
      var previous = rssiTrackFraction(rssiTrackMinDbm);
      for (var rssi = rssiTrackMinDbm + 1; rssi <= rssiTrackMaxDbm; rssi++) {
        final current = rssiTrackFraction(rssi);
        expect(current, greaterThan(previous));
        previous = current;
      }
    });
  });
}
