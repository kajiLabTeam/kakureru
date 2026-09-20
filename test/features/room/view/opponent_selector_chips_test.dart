import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/opponent_selector_chips.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// [OpponentSelectorChips]の人数対応(issue #67)のテスト。
///
/// GamePage全体は位置情報・Wi-Fi・気圧・BLEなど多数のproviderに依存して
/// いてwidgetテストを組みにくいため、become_demon_button_test.dartと同じく
/// チップ一覧だけをproviderに依存しない形で直接テストする。
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
  List<double> chipWidths(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(OpponentSelectorChips),
      matching: find.byType(GestureDetector),
    );
    return [
      for (var i = 0; i < finder.evaluate().length; i++)
        tester.getSize(finder.at(i)).width,
    ];
  }

  testWidgets('2人なら横幅を均等に分け合う(従来どおりの見た目)', (tester) async {
    await tester.pumpWidget(target(rosterOf(2)));

    expect(find.byType(SingleChildScrollView), findsNothing);

    final widths = chipWidths(tester);
    expect(widths.length, 2);
    expect(widths[0], widths[1]);
    // 均等割りなので、2つ分+隙間で横幅を使い切る。
    expect(widths[0] + opponentChipSpacing + widths[1], availableWidth);
    expect(widths[0], greaterThanOrEqualTo(minTapTargetWidth));
  });

  testWidgets('10人でも各チップは48dp以上を保ち、横スクロールになる', (tester) async {
    await tester.pumpWidget(target(rosterOf(10)));

    expect(find.byType(SingleChildScrollView), findsOneWidget);

    final widths = chipWidths(tester);
    expect(widths.length, 10);
    for (final width in widths) {
      expect(width, greaterThanOrEqualTo(minTapTargetWidth));
      expect(width, opponentChipMinWidth);
    }
    // 画面幅より広い=スクロールしないと全員には届かない、という状態。
    expect(opponentChipsRequiredWidth(10), greaterThan(availableWidth));
  });

  testWidgets('切り替えの境目: 328dpなら4人までは均等割り、5人から横スクロール', (tester) async {
    await tester.pumpWidget(target(rosterOf(4)));
    expect(find.byType(SingleChildScrollView), findsNothing);
    for (final width in chipWidths(tester)) {
      expect(width, greaterThanOrEqualTo(minTapTargetWidth));
    }

    await tester.pumpWidget(target(rosterOf(5)));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    for (final width in chipWidths(tester)) {
      expect(width, greaterThanOrEqualTo(minTapTargetWidth));
    }
  });

  testWidgets('横スクロールに切り替わってもタップで選択できる', (tester) async {
    String? selected;
    await tester.pumpWidget(
      target(rosterOf(10), onSelect: (uid) => selected = uid),
    );

    await tester.tap(find.text('逃走者0'));
    expect(selected, 'u0');
  });

  testWidgets('横幅が広ければ10人でも均等割りのまま', (tester) async {
    await tester.pumpWidget(target(rosterOf(10), width: 1000));

    expect(find.byType(SingleChildScrollView), findsNothing);
    for (final width in chipWidths(tester)) {
      expect(width, greaterThan(opponentChipMinWidth));
    }
  });
}
