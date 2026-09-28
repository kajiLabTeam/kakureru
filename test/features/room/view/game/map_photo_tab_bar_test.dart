import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/game/map_photo_tab_bar.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int selectedIndex,
    required ValueChanged<int> onSelect,
    bool hasNewPhotos = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapPhotoTabBar(
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            hasNewPhotos: hasNewPhotos,
          ),
        ),
      ),
    );
  }

  testWidgets('地図と写真の両方のラベルを表示する', (tester) async {
    await pump(tester, selectedIndex: 0, onSelect: (_) {});

    expect(find.text('地図'), findsOneWidget);
    expect(find.text('写真'), findsOneWidget);
  });

  testWidgets('写真をタップすると1を通知する', (tester) async {
    var selected = -1;
    await pump(
      tester,
      selectedIndex: 0,
      onSelect: (index) => selected = index,
    );

    await tester.tap(find.text('写真'));
    await tester.pump();

    expect(selected, 1);
  });

  testWidgets('地図をタップすると0を通知する', (tester) async {
    var selected = -1;
    await pump(
      tester,
      selectedIndex: 1,
      onSelect: (index) => selected = index,
    );

    await tester.tap(find.text('地図'));
    await tester.pump();

    expect(selected, 0);
  });

  testWidgets('新しい写真があるときだけ赤い点を出す', (tester) async {
    await pump(tester, selectedIndex: 0, onSelect: (_) {});
    expect(find.byKey(const ValueKey('newPhotoBadge')), findsNothing);

    await pump(tester, selectedIndex: 0, onSelect: (_) {}, hasNewPhotos: true);
    expect(find.byKey(const ValueKey('newPhotoBadge')), findsOneWidget);
  });

  testWidgets('タブのタップ領域は高さ44dp以上ある', (tester) async {
    await pump(tester, selectedIndex: 0, onSelect: (_) {});

    final tapArea = find.ancestor(
      of: find.text('写真'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(tapArea.first).height, greaterThanOrEqualTo(44));
  });
}
