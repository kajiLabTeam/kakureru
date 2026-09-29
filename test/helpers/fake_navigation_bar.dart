import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 画面下にシステムのナビゲーションバー(高さ[height]論理px)がある状態を
/// 作る(issue #136)。
///
/// Android 15以降は画面がバーの下まで広がり、その高さが
/// `MediaQuery.padding.bottom` として渡ってくる。テストの既定では0なので、
/// 下端の余白を取り忘れても気づけない。
void fakeNavigationBar(WidgetTester tester, {double height = 48}) {
  final padding = FakeViewPadding(
    bottom: height * tester.view.devicePixelRatio,
  );
  tester.view
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}

/// [finder]の下端が、画面(Scaffold)の下端から[height]以上上にあるか。
void expectAboveNavigationBar(
  WidgetTester tester,
  Finder finder, {
  double height = 48,
}) {
  final screenBottom = tester.getRect(find.byType(Scaffold).first).bottom;
  expect(
    tester.getRect(finder).bottom,
    lessThanOrEqualTo(screenBottom - height),
    reason: '最下部の要素がナビゲーションバーに重なっている',
  );
}
