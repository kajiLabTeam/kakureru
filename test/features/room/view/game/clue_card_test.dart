import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/clue_card.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

/// [ClueCard]のテスト。ゲーム画面モックのC1〜C5の5状態を1つずつ確かめる。
void main() {
  Widget target({
    ClueVerdict verdict = ClueVerdict.close,
    double? meter = 79,
    int matchCount = 2,
    ClueTrend trend = ClueTrend.closer,
    ClueHeightStatus heightStatus = ClueHeightStatus.ready,
    double? opponentLowerHPa = 0.4,
    VoidCallback? onHelp,
    VoidCallback? onCalibrate,
    bool isCalibrating = false,
    UserRole viewerRole = UserRole.demon,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 328,
          child: ClueCard(
            name: 'たろう',
            // 鬼は逃走者を、逃走者は鬼を見る。
            role: viewerRole == UserRole.demon
                ? UserRole.fugitive
                : UserRole.demon,
            viewerRole: viewerRole,
            verdict: verdict,
            meter: meter,
            matchCount: matchCount,
            trend: trend,
            heightStatus: heightStatus,
            opponentLowerHPa: opponentLowerHPa,
            onHelp: onHelp ?? () {},
            onCalibrate: onCalibrate,
            isCalibrating: isCalibrating,
          ),
        ),
      ),
    );
  }

  group('C1 近い・近づいた・高さあり', () {
    testWidgets('判定・傾向・メーター・電波の一致・階数を出す', (tester) async {
      await tester.pumpWidget(target());

      expect(find.text('たろう の手がかり'), findsOneWidget);
      expect(find.text('近いかも'), findsOneWidget);
      expect(find.text('このあたりを探してみよう'), findsOneWidget);
      expect(find.text('近づいた'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('clueMeterFill')), findsOneWidget);
      // 0.4hPa低い=1階ぶん上。
      expect(find.text('1階ぶんくらい 上かも'), findsOneWidget);
      expect(find.text('階段をのぼってみよう'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('メーターの塗りは値の割合だけ伸びる', (tester) async {
      await tester.pumpWidget(target(meter: 50));

      final fill = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('clueMeterFill')),
      );
      expect(fill.widthFactor, closeTo(0.5, 1e-9));
    });

    testWidgets('「?」は44dp以上で、押すとonHelpを呼ぶ', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(target(onHelp: () => tapped++));

      final help = find.byKey(const ValueKey('clueHelpButton'));
      final size = tester.getSize(help);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await tester.tap(help);
      expect(tapped, 1);
    });
  });

  group('C2 遠い', () {
    testWidgets('傾向に応じて次の一歩を出す', (tester) async {
      await tester.pumpWidget(
        target(verdict: ClueVerdict.far, trend: ClueTrend.farther),
      );

      expect(find.text('遠いかも'), findsOneWidget);
      expect(find.text('離れた'), findsOneWidget);
      expect(find.text('反対方向へ行ってみよう'), findsOneWidget);
    });
  });

  group('C3 同じWi-Fiが無い', () {
    testWidgets('メーターと傾向の代わりに、次の行動を出す', (tester) async {
      await tester.pumpWidget(
        target(
          verdict: ClueVerdict.unknown,
          meter: null,
          matchCount: 0,
          trend: ClueTrend.unchanged,
        ),
      );

      expect(find.text('まだ分からない'), findsOneWidget);
      expect(find.text('同じWi-Fiが届いていません'), findsOneWidget);
      expect(find.byKey(const ValueKey('clueMeterFill')), findsNothing);
      expect(find.byKey(const ValueKey('clueTrendTag')), findsNothing);
      expect(find.textContaining('まずは地図のピンを目指してください'), findsOneWidget);
      // 高さは出し続ける。
      expect(find.byKey(const ValueKey('clueHeightBar')), findsOneWidget);
    });
  });

  group('C4 高さ合わせをしていない', () {
    testWidgets('理由と「いま合わせる」を出し、押すとonCalibrateを呼ぶ', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        target(
          heightStatus: ClueHeightStatus.notCalibrated,
          onCalibrate: () => tapped++,
        ),
      );

      expect(find.text('高さはまだ分かりません'), findsOneWidget);
      expect(find.text('開始前の高さ合わせをしていません'), findsOneWidget);
      expect(find.byKey(const ValueKey('clueHeightBar')), findsNothing);

      final button = find.widgetWithText(FilledButton, 'いま合わせる');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      expect(tapped, 1);
    });

    testWidgets('合わせている間はスピナーを出して押せなくする', (tester) async {
      await tester.pumpWidget(
        target(
          heightStatus: ClueHeightStatus.notCalibrated,
          onCalibrate: () {},
          isCalibrating: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('C5 気圧センサーが無い', () {
    testWidgets('高さが分からないことと、メーターで追えることを出す', (tester) async {
      await tester.pumpWidget(
        target(heightStatus: ClueHeightStatus.unsupported),
      );

      expect(find.text('この端末では高さが分かりません'), findsOneWidget);
      expect(find.text('上のメーターだけで追えます'), findsOneWidget);
      expect(find.byKey(const ValueKey('clueHeightBar')), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      // 近さのほうはそのまま出る。
      expect(find.text('近いかも'), findsOneWidget);
    });

    testWidgets('確認中・相手待ちも同じ形で理由を出す', (tester) async {
      await tester.pumpWidget(target(heightStatus: ClueHeightStatus.checking));
      expect(find.text('高さを確認しています'), findsOneWidget);

      await tester.pumpWidget(target(heightStatus: ClueHeightStatus.waiting));
      expect(find.text('相手の高さがまだ届いていません'), findsOneWidget);
    });
  });

  group('clueVerdictOf', () {
    test('メーターが出せなければ判定によらず「まだ分からない」', () {
      expect(
        clueVerdictOf(level: ProximityLevel.close, meter: null),
        ClueVerdict.unknown,
      );
    });

    test('メーターがあれば3段階判定に従う', () {
      expect(
        clueVerdictOf(level: ProximityLevel.close, meter: 80),
        ClueVerdict.close,
      );
      expect(
        clueVerdictOf(level: ProximityLevel.far, meter: 20),
        ClueVerdict.far,
      );
      expect(
        clueVerdictOf(level: ProximityLevel.notDetected, meter: 20),
        ClueVerdict.unknown,
      );
      expect(clueVerdictOf(level: null, meter: 20), ClueVerdict.unknown);
    });
  });

  group('逃走者から見たとき (issue #135)', () {
    const fugitive = UserRole.fugitive;

    testWidgets('探す・追うではなく、鬼がどこにいるかを出す', (tester) async {
      await tester.pumpWidget(target(viewerRole: fugitive));

      expect(find.text('鬼がこのあたりにいるかも'), findsOneWidget);
      expect(find.text('鬼は上の階にいるかも'), findsOneWidget);
      // 見出しと傾向チップは役割によらず同じ。
      expect(find.text('近いかも'), findsOneWidget);
      expect(find.text('1階ぶんくらい 上かも'), findsOneWidget);
      expect(find.text('近づいた'), findsOneWidget);
      expect(find.textContaining('探して'), findsNothing);
    });

    testWidgets('手がかりがまだ無いときは、地図で鬼の位置を確かめるよう出す', (tester) async {
      await tester.pumpWidget(
        target(
          viewerRole: fugitive,
          verdict: ClueVerdict.unknown,
          meter: null,
          matchCount: 0,
          trend: ClueTrend.unchanged,
        ),
      );

      expect(find.text('同じWi-Fiが届いていません'), findsOneWidget);
      expect(find.textContaining('地図のピンで鬼の位置を確かめて'), findsOneWidget);
      expect(find.textContaining('目指して'), findsNothing);
    });

    testWidgets('高さが出せないときは「追えます」と言わない', (tester) async {
      await tester.pumpWidget(
        target(
          viewerRole: fugitive,
          heightStatus: ClueHeightStatus.unsupported,
        ),
      );
      expect(find.text('上のメーターだけで距離が分かります'), findsOneWidget);

      await tester.pumpWidget(
        target(viewerRole: fugitive, heightStatus: ClueHeightStatus.waiting),
      );
      expect(find.text('届くまでは上のメーターで距離が分かります'), findsOneWidget);
      expect(find.textContaining('追えます'), findsNothing);
    });

    test('一言は状況だけで、どう動くかは書かない', () {
      String hint(ClueVerdict verdict, ClueTrend trend) =>
          clueVerdictHint(verdict, trend, viewerRole: fugitive);

      expect(hint(ClueVerdict.close, ClueTrend.closer), '鬼がこのあたりにいるかも');
      expect(hint(ClueVerdict.far, ClueTrend.closer), '鬼が近づいてきている');
      expect(hint(ClueVerdict.far, ClueTrend.farther), '鬼は離れていった');
      expect(hint(ClueVerdict.far, ClueTrend.unchanged), '鬼との距離は変わらない');
      expect(hint(ClueVerdict.unknown, ClueTrend.closer), '同じWi-Fiが届いていません');
    });
  });

  group('clueVerdictHint', () {
    test('役割が分からないときは鬼と同じ文言にする', () {
      expect(
        clueVerdictHint(ClueVerdict.close, ClueTrend.closer, viewerRole: null),
        'このあたりを探してみよう',
      );
    });

    test('遠いときは傾向ごとに一言を変える', () {
      expect(
        clueVerdictHint(
          ClueVerdict.far,
          ClueTrend.closer,
          viewerRole: UserRole.demon,
        ),
        '方向は合っている。このまま進もう',
      );
      expect(
        clueVerdictHint(
          ClueVerdict.far,
          ClueTrend.farther,
          viewerRole: UserRole.demon,
        ),
        '反対方向へ行ってみよう',
      );
      expect(
        clueVerdictHint(
          ClueVerdict.far,
          ClueTrend.unchanged,
          viewerRole: UserRole.demon,
        ),
        '歩いて、近づくか確かめよう',
      );
    });
  });

  group('clueHeightStatusOf', () {
    test('センサーが無ければ、他の条件によらずunsupported', () {
      expect(
        clueHeightStatusOf(
          availability: PressureSensorAvailability.unavailable,
          isCalibrated: true,
          hasOpponentHeight: true,
        ),
        ClueHeightStatus.unsupported,
      );
    });

    test('確認中ならchecking', () {
      expect(
        clueHeightStatusOf(
          availability: PressureSensorAvailability.checking,
          isCalibrated: false,
          hasOpponentHeight: false,
        ),
        ClueHeightStatus.checking,
      );
    });

    test('センサーはあるが未キャリブレーションならnotCalibrated', () {
      expect(
        clueHeightStatusOf(
          availability: PressureSensorAvailability.available,
          isCalibrated: false,
          hasOpponentHeight: true,
        ),
        ClueHeightStatus.notCalibrated,
      );
    });

    test('相手の高さが無ければwaiting、揃えばready', () {
      expect(
        clueHeightStatusOf(
          availability: PressureSensorAvailability.available,
          isCalibrated: true,
          hasOpponentHeight: false,
        ),
        ClueHeightStatus.waiting,
      );
      expect(
        clueHeightStatusOf(
          availability: PressureSensorAvailability.available,
          isCalibrated: true,
          hasOpponentHeight: true,
        ),
        ClueHeightStatus.ready,
      );
    });
  });
}
