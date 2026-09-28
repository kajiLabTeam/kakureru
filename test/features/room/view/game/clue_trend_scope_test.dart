import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/game/clue_trend_scope.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

/// [ClueTrendScope]のテスト。メーターの変化から傾向が出ることを確かめる。
void main() {
  var now = DateTime(2026, 9, 28, 12);
  ClueTrend? seen;

  Widget target(String uid, double? meter) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClueTrendScope(
        uid: uid,
        meter: meter,
        clock: () => now,
        builder: (context, trend) {
          seen = trend;
          return const SizedBox();
        },
      ),
    );
  }

  setUp(() {
    now = DateTime(2026, 9, 28, 12);
    seen = null;
  });

  testWidgets('最初の1件だけでは「変わらない」', (tester) async {
    await tester.pumpWidget(target('a', 40));
    expect(seen, ClueTrend.unchanged);
  });

  testWidgets('6秒以上前より5以上上がれば「近づいた」', (tester) async {
    await tester.pumpWidget(target('a', 40));
    now = now.add(const Duration(seconds: 7));
    await tester.pumpWidget(target('a', 50));
    expect(seen, ClueTrend.closer);
  });

  testWidgets('下がれば「離れた」', (tester) async {
    await tester.pumpWidget(target('a', 40));
    now = now.add(const Duration(seconds: 7));
    await tester.pumpWidget(target('a', 30));
    expect(seen, ClueTrend.farther);
  });

  testWidgets('同じ値での再描画は記録しない(基準の時刻がずれない)', (tester) async {
    await tester.pumpWidget(target('a', 40));
    // 1秒ごとの再描画を模す。値が同じなら足さない。
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pumpWidget(target('a', 40));
    }
    now = now.add(const Duration(seconds: 2));
    await tester.pumpWidget(target('a', 50));
    // 最初の40(7秒前)と比べられる。
    expect(seen, ClueTrend.closer);
  });

  testWidgets('相手を選び直すと、その相手の履歴で判定する', (tester) async {
    await tester.pumpWidget(target('a', 40));
    now = now.add(const Duration(seconds: 7));
    await tester.pumpWidget(target('b', 80));
    // bはまだ1件しかない。
    expect(seen, ClueTrend.unchanged);
    await tester.pumpWidget(target('a', 60));
    // aの履歴は残っている。
    expect(seen, ClueTrend.closer);
  });

  testWidgets('メーターが出せない間は「変わらない」', (tester) async {
    await tester.pumpWidget(target('a', 40));
    now = now.add(const Duration(seconds: 7));
    await tester.pumpWidget(target('a', null));
    expect(seen, ClueTrend.unchanged);
  });
}
