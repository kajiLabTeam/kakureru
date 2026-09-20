import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view/game/opponent_detail_card.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';

/// [OpponentDetailCard](issue #76で作り直した「手がかり」カード)のテスト。
///
/// GamePage全体はFirebase・センサー系のproviderを丸ごと差し替えないと
/// 立ち上がらないため、カードだけをproviderに依存しない形で直接テストする。
void main() {
  const opponent = RoomUser(
    id: 'u0',
    displayName: 'ゆい',
    role: UserRole.fugitive,
  );

  const ready = PressureState(
    sensorAvailability: PressureSensorAvailability.available,
  );

  const comparisons = [
    WifiApComparison(bssid: 'ap1', selfRssi: -55, targetRssi: -70),
    WifiApComparison(bssid: 'ap2', selfRssi: -60, targetRssi: -62),
    WifiApComparison(bssid: 'ap3', selfRssi: -80, targetRssi: -45),
  ];

  Future<void> pumpCard(
    WidgetTester tester, {
    RoomUser? user = opponent,
    PressureState pressureState = ready,
    bool isCalibrated = true,
    RelativeVerticalPosition? verticalPosition,
    ProximityLevel? wifiLevel = ProximityLevel.close,
    List<WifiApComparison> comparisons = comparisons,
    Size size = const Size(360, 640),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            // GamePageと同じ左右16dpの余白の中に置く。
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OpponentDetailCard(
              user: user,
              pressureState: pressureState,
              isCalibrated: isCalibrated,
              verticalPosition: verticalPosition,
              wifiLevel: wifiLevel,
              comparisons: comparisons,
            ),
          ),
        ),
      ),
    );
  }

  group('上下', () {
    testWidgets('相手が上なら、上向きの矢印と「上にいるかも」と気圧差を出す', (tester) async {
      await pumpCard(
        tester,
        verticalPosition: const RelativeVerticalPosition(
          uid: 'u0',
          deltaMeters: 2.905, // 0.35hPa 相当
        ),
      );

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('上にいるかも'), findsOneWidget);
      // 相手が上 = 相手の気圧の方が低い。
      expect(find.text('ゆいの気圧は 0.35 hPa 低い'), findsOneWidget);
    });

    testWidgets('相手が下なら、下向きの矢印と「下にいるかも」で、気圧は高い', (tester) async {
      await pumpCard(
        tester,
        verticalPosition: const RelativeVerticalPosition(
          uid: 'u0',
          deltaMeters: -2.905,
        ),
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.text('下にいるかも'), findsOneWidget);
      expect(find.text('ゆいの気圧は 0.35 hPa 高い'), findsOneWidget);
    });

    testWidgets('差が小さければ「同じ高さかも」で、数値は出さない', (tester) async {
      await pumpCard(
        tester,
        verticalPosition: const RelativeVerticalPosition(
          uid: 'u0',
          deltaMeters: 0.5,
        ),
      );

      expect(find.text('同じ高さかも'), findsOneWidget);
      expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
      // 誤差の範囲を有効数字2桁で出すと、動いていないのに数字が動いて見える。
      expect(find.text('ゆいの気圧は ほぼ同じ'), findsOneWidget);
      expect(find.textContaining('hPa'), findsNothing);
    });

    testWidgets('センサー非対応・確認中・未実施・検知なしは、理由だけを出す', (tester) async {
      final cases = <String, Future<void> Function()>{
        '非対応': () => pumpCard(
          tester,
          pressureState: const PressureState(
            sensorAvailability: PressureSensorAvailability.unavailable,
          ),
          verticalPosition: const RelativeVerticalPosition(
            uid: 'u0',
            deltaMeters: 8,
          ),
        ),
        '確認中': () => pumpCard(
          tester,
          pressureState: const PressureState(),
          verticalPosition: const RelativeVerticalPosition(
            uid: 'u0',
            deltaMeters: 8,
          ),
        ),
        '未実施': () => pumpCard(
          tester,
          isCalibrated: false,
          verticalPosition: const RelativeVerticalPosition(
            uid: 'u0',
            deltaMeters: 8,
          ),
        ),
        '検知なし': () => pumpCard(tester),
      };

      for (final entry in cases.entries) {
        await entry.value();

        expect(find.text(entry.key), findsOneWidget, reason: entry.key);
        // 出せないのに矢印や数値を出さない(空欄との区別が付かなくなる)。
        expect(find.byIcon(Icons.arrow_upward), findsNothing);
        expect(find.textContaining('hPa'), findsNothing);
        expect(find.textContaining('いるかも'), findsNothing);
      }
    });
  });

  group('距離感', () {
    testWidgets('共通AP1つにつきトラックを1本出し、色の使い方をキャプションで示す', (tester) async {
      await pumpCard(tester);

      expect(find.text('近いかも'), findsOneWidget);
      // 逃走者(緑)を追っている鬼の視点。自分は青のまま。
      expect(find.text('青を緑に近づけよう'), findsOneWidget);

      for (final comparison in comparisons) {
        expect(
          find.byKey(ValueKey('wifiTrack:${comparison.bssid}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('自分の点と相手の点は、RSSIの強さの順に左右へ置かれる', (tester) async {
      await pumpCard(tester);

      // ap1は自分(-55)の方が強い=自分が右。ap3は相手(-45)の方が強い=相手が左。
      // 2つの点の間隔が「そのAPから見てどれだけ離れているか」になる、という
      // 読み方の前提なので、向きを取り違えていないことを固定する。
      final ap1 = tester.getRect(find.byKey(const ValueKey('wifiTrack:ap1')));
      final ap3 = tester.getRect(find.byKey(const ValueKey('wifiTrack:ap3')));
      expect(ap1.width, greaterThan(0));
      expect(ap3.width, closeTo(ap1.width, 0.01));

      Rect dotOf(String bssid, Color color) {
        return tester.getRect(
          find.descendant(
            of: find.byKey(ValueKey('wifiTrack:$bssid')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  (w.decoration! as BoxDecoration).color == color,
            ),
          ),
        );
      }

      const green = Color(0xFF4A9C5D);
      expect(
        dotOf('ap1', selfColor).left,
        greaterThan(dotOf('ap1', green).left),
      );
      expect(dotOf('ap3', selfColor).left, lessThan(dotOf('ap3', green).left));
    });

    testWidgets('鬼を追う逃走者視点なら、近づける先は赤になる', (tester) async {
      await pumpCard(
        tester,
        user: const RoomUser(
          id: 'u1',
          displayName: 'たくみ',
          role: UserRole.demon,
        ),
      );

      expect(find.text('青を赤に近づけよう'), findsOneWidget);
    });

    testWidgets('共通APが無ければ、トラックもキャプションも出さない', (tester) async {
      await pumpCard(
        tester,
        wifiLevel: ProximityLevel.notDetected,
        comparisons: const [],
      );

      expect(find.text('検知なし'), findsWidgets);
      expect(find.textContaining('近づけよう'), findsNothing);
    });

    testWidgets('「近い」のときだけ強調色にする', (tester) async {
      await pumpCard(tester);
      final close = tester.widget<Text>(find.text('近いかも'));

      await pumpCard(tester, wifiLevel: ProximityLevel.far);
      final far = tester.widget<Text>(find.text('遠いかも'));

      expect(close.style!.color, isNot(far.style!.color));
    });
  });

  group('カード全体', () {
    testWidgets('タイトルと、自分/相手の色の凡例を出す', (tester) async {
      await pumpCard(tester);

      expect(find.text('ゆい の手がかり'), findsOneWidget);
      expect(find.text('自分'), findsOneWidget);
      // 凡例側にも相手の名前を出すので、名前は2箇所に出る。
      expect(find.text('ゆい'), findsOneWidget);
    });

    testWidgets('相手が選ばれていなければ「検知なし」だけを出す', (tester) async {
      await pumpCard(tester, user: null);

      expect(find.text('検知なし'), findsOneWidget);
      expect(find.textContaining('手がかり'), findsNothing);
    });

    testWidgets('小さい画面・長い名前でも溢れない', (tester) async {
      // 実機で溢れていた小さい画面(issue #69のレビュー指摘)で確認する。
      await pumpCard(
        tester,
        user: const RoomUser(
          id: 'u0',
          displayName: 'とてもながいなまえのプレイヤー',
          role: UserRole.fugitive,
        ),
        verticalPosition: const RelativeVerticalPosition(
          uid: 'u0',
          deltaMeters: 8,
        ),
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('pressureDiffText', () {
    test('符号で「低い」「高い」を出し分ける', () {
      // 表示だけの関数だが、上下の取り違えは実機で気づきにくいので固定する。
      expect(
        pressureDiffText(
          displayName: 'ゆい',
          deltaMeters: metersPerHectoPascal,
        ),
        'ゆいの気圧は 1.00 hPa 低い',
      );
      expect(
        pressureDiffText(
          displayName: 'ゆい',
          deltaMeters: -metersPerHectoPascal,
        ),
        'ゆいの気圧は 1.00 hPa 高い',
      );
    });

    test('差が小さければ数値を出さない', () {
      expect(
        pressureDiffText(displayName: 'ゆい', deltaMeters: 0),
        'ゆいの気圧は ほぼ同じ',
      );
    });
  });

  group('colorNameForRole', () {
    test('配色ルール(赤=鬼/緑=逃走者)と一致する', () {
      // キャプションの色名と、実際に描くドットの色がずれないようにする。
      expect(colorNameForRole(UserRole.demon), '赤');
      expect(colorNameForRole(UserRole.fugitive), '緑');
      expect(colorForRole(UserRole.demon), const Color(0xFFE5484D));
      expect(colorForRole(UserRole.fugitive), const Color(0xFF4A9C5D));
    });
  });
}
