import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/opponent_selector_chips.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// [OpponentSelectorChips]のテスト。
///
/// GamePage全体は位置情報・Wi-Fi・気圧・BLEなど多数のproviderに依存して
/// いてwidgetテストを組みにくいため、become_demon_button_test.dartと同じく
/// チップ一覧だけをproviderに依存しない形で直接テストする。
///
/// 以前(issue #67 / PR #68)は「収まるときは均等割り、溢れたら横スクロール」
/// で、そのふるまいをここで仕様として固定していた。issue #76で**常に固定幅の
/// 横スクロール**へ変えたので、テストも人数で見た目が変わらないことを
/// 確かめる方へ置き換えている。
void main() {
  /// 横幅360dpの端末で、GamePageが左右に16dpずつ余白を取った残り。
  const availableWidth = 328.0;

  /// Materialのタップ領域の推奨最小サイズ。
  const minTapTargetWidth = 48.0;

  // 役割は RoomUser の既定値(逃走者)のまま。鬼視点で逃走者のチップを
  // 並べる、という本番と同じ組み合わせになる。
  List<RoomUser> rosterOf(int count) => [
    for (var i = 0; i < count; i++) RoomUser(id: 'u$i', displayName: '逃走者$i'),
  ];

  Widget target(
    List<RoomUser> roster, {
    double width = availableWidth,
    ValueChanged<String>? onSelect,
    List<RelativeVerticalPosition> verticalPositions = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: OpponentSelectorChips(
              roster: roster,
              entries: [
                for (final user in roster)
                  WifiProximityEntry(uid: user.id, level: ProximityLevel.close),
              ],
              verticalPositions: verticalPositions,
              selectedUid: roster.isEmpty ? null : roster.first.id,
              onSelect: onSelect ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  /// チップ1つ1つの実際の幅。チップの本体はGestureDetector
  /// (タップ領域そのもの)なので、その描画サイズを測る。
  Finder chipFinder() => find.descendant(
    of: find.byType(OpponentSelectorChips),
    matching: find.byType(GestureDetector),
  );

  List<double> chipWidths(WidgetTester tester) {
    final finder = chipFinder();
    return [
      for (var i = 0; i < finder.evaluate().length; i++)
        tester.getSize(finder.at(i)).width,
    ];
  }

  group('レイアウト', () {
    testWidgets('2人以上なら常に横スクロールで、2枚目が右端で見切れる', (tester) async {
      await tester.pumpWidget(target(rosterOf(2)));

      expect(find.byType(SingleChildScrollView), findsOneWidget);

      final host = tester.getRect(find.byType(OpponentSelectorChips));
      final second = tester.getRect(chipFinder().at(1));
      // 2枚目の左側は見えていて、右側ははみ出している
      // =「まだ続きがある」と分かる状態。
      expect(second.left, lessThan(host.right));
      expect(second.right, greaterThan(host.right));
    });

    testWidgets('チップ幅は人数によらず(横幅-隙間)/1.8で一定', (tester) async {
      final expected =
          (availableWidth - opponentChipSpacing) / opponentChipsVisibleCount;

      for (final count in [2, 4, 6, 10]) {
        await tester.pumpWidget(target(rosterOf(count)));

        final widths = chipWidths(tester);
        expect(widths.length, count);
        for (final width in widths) {
          expect(width, closeTo(expected, 0.01));
          expect(width, greaterThanOrEqualTo(minTapTargetWidth));
        }
      }
    });

    testWidgets('相手が1人のときだけ全幅にする(送る先が無いので見切れさせない)', (tester) async {
      await tester.pumpWidget(target(rosterOf(1)));

      final widths = chipWidths(tester);
      expect(widths, [availableWidth]);

      final host = tester.getRect(find.byType(OpponentSelectorChips));
      expect(
        tester.getRect(chipFinder().first).right,
        closeTo(host.right, 0.01),
      );
    });

    testWidgets('横幅が広くても均等割りへは戻さない', (tester) async {
      // テスト画面の既定サイズ(800x600)に収まる幅を使う。これを超えると
      // SizedBoxごと切り詰められて、測っているのが別の値になる。
      const wide = 600.0;
      await tester.pumpWidget(target(rosterOf(10), width: wide));

      final expected = (wide - opponentChipSpacing) / opponentChipsVisibleCount;
      for (final width in chipWidths(tester)) {
        expect(width, closeTo(expected, 0.01));
      }
      // 10人ぶんはどう見ても収まらない=横スクロールのまま。
      expect(expected * 10, greaterThan(wide));
    });

    testWidgets('横スクロールでもタップで選択できる', (tester) async {
      String? selected;
      await tester.pumpWidget(
        target(rosterOf(10), onSelect: (uid) => selected = uid),
      );

      await tester.tap(find.text('逃走者0'));
      expect(selected, 'u0');
    });

    testWidgets('相手が0人ならチップを1つも出さない', (tester) async {
      await tester.pumpWidget(target(rosterOf(0)));

      expect(chipFinder(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('opponentChipWidthFor', () {
    test('横幅が測れないときはフォールバック幅を使う', () {
      // 親が横方向に無制限だと maxWidth が infinity で来る。そのまま割ると
      // 幅がinfinityのSizedBoxになって描画ごと落ちる。
      expect(
        opponentChipWidthFor(availableWidth: double.infinity, count: 5),
        opponentChipFallbackWidth,
      );
    });

    test('0人でも例外にならない', () {
      expect(
        opponentChipWidthFor(availableWidth: availableWidth, count: 0),
        availableWidth,
      );
    });
  });

  group('opponentChipSummary', () {
    test('Wi-Fiと上下を「・」でつなぐ', () {
      expect(
        opponentChipSummary(
          level: ProximityLevel.close,
          verticalPosition: const RelativeVerticalPosition(
            uid: 'u0',
            deltaMeters: 8,
          ),
        ),
        '近い・上かも',
      );
      expect(
        opponentChipSummary(
          level: ProximityLevel.far,
          verticalPosition: const RelativeVerticalPosition(
            uid: 'u0',
            deltaMeters: 0,
          ),
        ),
        '遠い・同じ高さ',
      );
      expect(
        opponentChipSummary(
          level: ProximityLevel.far,
          verticalPosition: const RelativeVerticalPosition(
            uid: 'u0',
            deltaMeters: -8,
          ),
        ),
        '遠い・下かも',
      );
    });

    test('上下が出せないときはWi-Fi側だけを返す', () {
      // 気圧センサー非対応・未キャリブレーションのときGamePageが渡す
      // verticalPositionsは空になるので、ここがnullで来る。
      expect(
        opponentChipSummary(
          level: ProximityLevel.close,
          verticalPosition: null,
        ),
        '近い',
      );
    });

    test('Wi-Fiが検知できていなければ「検知なし」', () {
      expect(
        opponentChipSummary(level: null, verticalPosition: null),
        '検知なし',
      );
      expect(
        opponentChipSummary(
          level: ProximityLevel.notDetected,
          verticalPosition: null,
        ),
        '検知なし',
      );
    });
  });

  group('チップの中身', () {
    testWidgets('名前と要約を出す(アバターは出さない)', (tester) async {
      await tester.pumpWidget(
        target(
          rosterOf(3),
          verticalPositions: const [
            RelativeVerticalPosition(uid: 'u0', deltaMeters: 8),
          ],
        ),
      );

      expect(find.text('逃走者0'), findsOneWidget);
      expect(find.text('近い・上かも'), findsOneWidget);
      // 上下が届いていない相手はWi-Fi側だけ。
      expect(find.text('近い'), findsNWidgets(2));
      // 頭文字を出す丸(CircleAvatar)はもう使わない。
      expect(find.byType(CircleAvatar), findsNothing);
    });
  });
}
