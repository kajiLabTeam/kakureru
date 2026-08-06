import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/view_model/room_home_page.dart';

void main() {
  testWidgets('RoomHomePage shows create/join room controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );

    expect(find.text('かくれんぼ'), findsOneWidget);
    expect(find.text('ルームを作る'), findsOneWidget);
    expect(find.text('ルームに参加'), findsOneWidget);
  });
}
