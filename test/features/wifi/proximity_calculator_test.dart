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

  group('送信前の上位N件絞り込みがproximity判定に与える影響(issue #45)', () {
    // 自分・相手が実際には同じ60個のAPを見えている(=本来ならJaccard係数1.0で
    // 「近い」はず)状況を再現する。可視APを60件にしてあるのは、上位40件への
    // 絞り込みでも実際に20件が切り捨てられる(=切り捨てが起きないトートロジー
    // にならない)ようにするため。RSSIは-21〜-80dBmに収まっており、
    // filterWeakSignalsの-80dBm足切りでは1件も落ちない。
    //
    // 注意: targetはap10..19とap20..29のブロックまるごと10dBm入れ替えて
    // あり、これは「境界付近のAPが端末ごとに別々に切り捨てられる」機構を
    // 最小の例で見せるための**極端に単純化した**構成であって、実測された
    // RSSI揺らぎそのものではない。実測(モンテカルロ)では、σ=3dB程度の
    // 独立な揺らぎだけなら上位20件の入れ替わりはk≒5件にとどまり、
    // 判定はfarには落ちてもnotDetectedまでは落ちない。notDetectedまで
    // 悪化するのは、ここで再現しているような大きな順位逆転が起きる場合か、
    // 後段の「対称top-Mクランプ」グループで扱う集合サイズの非対称が
    // ある場合である。
    final self = {
      for (var i = 0; i < 60; i++) 'ap$i': -21 - i, // ap0: -21 〜 ap59: -80
    };
    final target = {
      for (var i = 0; i < 10; i++) 'ap$i': -21 - i, // ap0..9: selfと同じ
      // ap10..19とap20..29の強さがまるごと入れ替わっている(差は10dBm)
      for (var i = 10; i < 20; i++) 'ap$i': -21 - (i + 10),
      for (var i = 20; i < 30; i++) 'ap$i': -21 - (i - 10),
      for (var i = 30; i < 60; i++) 'ap$i': -21 - i, // ap30..59: selfと同じ
    };

    test('絞り込み前ならcommonApCount=60・Jaccard=1.0で「近い」と判定できる', () {
      expect(calculateJaccardIndex(self, target), closeTo(1, 1e-9));
      expect(calculateProximity(self, target), ProximityLevel.close);
    });

    test('上位20件に絞り込むと、本来同じはずのAPの一部が非対称に落ち、'
        ' 「近い」はずが検知なし相当まで悪化する(修正前の挙動の再現)', () {
      final selfTop20 = selectTopAccessPoints(self, count: 20);
      final targetTop20 = selectTopAccessPoints(target, count: 20);

      // self側はap0..19、target側はap0..9 + ap20..29が残るため、
      // 共通して残るのはap0..9の10件だけ(和集合は30件 → Jaccard 0.33)
      expect(
        selfTop20.keys.toSet().intersection(targetTop20.keys.toSet()).length,
        10,
      );

      final result = calculateProximity(selfTop20, targetTop20);
      expect(result, ProximityLevel.notDetected);
    });

    test('上位40件(現在の_maxApCount相当、かつデフォルト値)に増やせば'
        '入れ替わったAPが両者とも上位40件に収まり「近い」と判定できる', () {
      final selfTop40 = selectTopAccessPoints(self);
      final targetTop40 = selectTopAccessPoints(target);

      // 60件中20件が実際に切り捨てられている(切り捨てが起きないデータでの
      // トートロジーにならないことの確認)
      expect(self.length, 60);
      expect(selfTop40.length, 40);
      expect(targetTop40.length, 40);
      expect(selfTop40.length, lessThan(self.length));

      // 入れ替わったap10..29は両者とも上位40件の内側に収まるので、
      // 絞り込み後のBSSID集合は完全に一致する
      expect(selfTop40.keys.toSet(), targetTop40.keys.toSet());

      final result = calculateProximity(selfTop40, targetTop40);
      expect(result, ProximityLevel.close);
    });
  });

  group('判定時の対称top-Mクランプ(issue #45 / |A| != |B|)', () {
    // 同じ場所にいるがアンテナ利得やポケット/手持ちの差でB側が一律に弱く
    // 見えており、-80dBmの絶対足切りの後にA=40件・B=14件と集合サイズが
    // 非対称になっている状況。Bの14件はすべてAにも含まれている(=本来は
    // 「近い」と判定されるべき)。
    final a = {
      for (var i = 0; i < 40; i++) 'ap$i': -30 - i, // ap0: -30 〜 ap39: -69
    };
    final b = {
      for (var i = 0; i < 14; i++) 'ap$i': -31 - i, // ap0: -31 〜 ap13: -44
    };

    test('クランプ無しだと和集合だけが膨らみ Jaccard=0.35 で「近い」にならない', () {
      // 共通14件 / 和集合40件 = 0.35。notDetected閾値(0.35)は下回らないが
      // close閾値(0.50)には届かないのでfar止まりになる。
      expect(calculateJaccardIndex(a, b), closeTo(0.35, 1e-9));
      expect(
        classifyProximity(
          commonApCount: 14,
          jaccardIndex: calculateJaccardIndex(a, b),
          averageRssiDiffDbm: calculateAverageRssiDiff(a, b),
        ),
        ProximityLevel.far,
      );
    });

    test('クランプ有りなら M=14 に揃って Jaccard=1.0 となり「近い」と判定できる', () {
      final aClamped = clampToSymmetricTop(a, otherLength: b.length);
      final bClamped = clampToSymmetricTop(b, otherLength: a.length);

      expect(aClamped.length, 14);
      expect(bClamped.length, 14);
      expect(aClamped.keys.toSet(), bClamped.keys.toSet());
      expect(calculateJaccardIndex(aClamped, bClamped), closeTo(1, 1e-9));

      // calculateProximityにも組み込まれているので、素のマップを渡すだけで
      // 「近い」になる(この期待値はクランプを外すとfarになって落ちる)
      expect(calculateProximity(a, b), ProximityLevel.close);
    });

    test('件数が同じならクランプは何もしない(no-op)', () {
      final other = {for (var i = 0; i < 40; i++) 'ap$i': -32 - i};

      expect(clampToSymmetricTop(a, otherLength: other.length), a);
      expect(clampToSymmetricTop(other, otherLength: a.length), other);
    });

    test('端末ごとの一律な利得オフセットに対して不変', () {
      // b全体をさらに6dBm弱くしても、順位が変わらないので選ばれるBSSIDは
      // 同じ(足切りで落ちない範囲での話)
      final weakerB = {for (final e in b.entries) e.key: e.value - 6};

      expect(
        clampToSymmetricTop(weakerB, otherLength: a.length).keys.toSet(),
        clampToSymmetricTop(b, otherLength: a.length).keys.toSet(),
      );
      expect(calculateProximity(a, weakerB), ProximityLevel.close);
    });

    test('離れている場合は対称クランプを入れても「近い」にはならない', () {
      // 共通APが1件しかない(=実際に離れている)ケース。Mを揃えても
      // 共通AP数が[minCommonApCount]に届かず検知なしのまま。
      final far = {
        'ap0': -60,
        'other1': -55,
        'other2': -58,
        'other3': -61,
        'other4': -64,
      };

      expect(calculateProximity(a, far), ProximityLevel.notDetected);
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
