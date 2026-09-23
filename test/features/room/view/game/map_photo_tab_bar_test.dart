import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/game/map_photo_tab_bar.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapPhotoTabBar(
            selectedIndex: selectedIndex,
            onSelect: onSelect,
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
}
