import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/view/game/game_header_bar.dart';

/// [GameHeaderBar]のテスト。
///
/// GamePage本体はproviderだらけでwidgetテストを組めないため、ヘッダーを
/// 切り出してここで確認する(issue #76)。
void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    RoleTheme? roleTheme,
    int? countdownSec,
    List<Widget> actions = const [],
  }) {
    return tester.pumpWidget(
      MaterialApp(
        // 本番と同じテーマを敷く。AppBarThemeが backgroundColor: 白 /
        // titleTextStyle: appInk を持っていることが、下の文字色の分岐の
        // 前提そのものなので、既定テーマで試すと意味が無い。
        theme: buildAppTheme(),
        home: Scaffold(
          appBar: GameHeaderBar(
            roleTheme: roleTheme,
            countdownSec: countdownSec,
            actions: actions,
          ),
        ),
      ),
    );
  }

  /// 画面に実際に描かれる文字色(DefaultTextStyleとマージした後の値)。
  Color? renderedColorOf(WidgetTester tester, String text) {
    return tester
        .renderObject<RenderParagraph>(find.text(text))
        .text
        .style
        ?.color;
  }

  testWidgets('役割ラベルと残り時間を、実機で読める大きさで出す', (tester) async {
    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.demon),
      countdownSec: 125,
    );

    final label = tester.widget<Text>(find.text('あなたは 鬼'));
    final timer = tester.widget<Text>(find.text('2:05'));

    // モック2a-03の13px/17px(280px枠)を実機幅へスケールした値。以前は
    // モックの数値をそのまま15px/19pxで実装していて小さすぎた。
    expect(label.style!.fontSize, gameHeaderLabelFontSize);
    expect(timer.style!.fontSize, gameHeaderTimerFontSize);
    expect(gameHeaderLabelFontSize, greaterThan(15));
    expect(gameHeaderTimerFontSize, greaterThan(19));
    // 残り時間は桁が変わっても幅が揺れないよう等幅で出す。
    expect(timer.style!.fontFamily, 'monospace');
  });

  testWidgets('役割が決まっていれば、役割の色を背景に敷いて文字を白にする', (tester) async {
    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.fugitive),
      countdownSec: 0,
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, roleThemeOf(UserRole.fugitive).color);
    // AppBarThemeのtitleTextStyleが非nullだとforegroundColorは混ざらない
    // (Flutterの仕様)ので、ここは明示的に白を指定する必要がある。
    expect(renderedColorOf(tester, 'あなたは 逃走者'), Colors.white);
    expect(renderedColorOf(tester, '0:00'), Colors.white);
  });

  testWidgets('役割が未確定なら、白地に白で消えないようテーマの文字色を継承する', (tester) async {
    await pumpHeader(tester, roleTheme: null, countdownSec: 125);

    // 背景はAppBarThemeの白になる。ここで白を指定すると文字が消える。
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, isNull);
    expect(
      Theme.of(tester.element(find.byType(AppBar))).appBarTheme.backgroundColor,
      Colors.white,
    );

    expect(renderedColorOf(tester, 'ゲーム中'), isNot(Colors.white));
    expect(renderedColorOf(tester, 'ゲーム中'), appInk);
  });

  testWidgets('残り時間がまだ計算できていなければ --:-- と出す', (tester) async {
    await pumpHeader(tester, roleTheme: roleThemeOf(UserRole.demon));

    expect(find.text('--:--'), findsOneWidget);
  });

  testWidgets('役割が未確定なら「ゲーム中」だけを出し、残り時間は出さない', (tester) async {
    // 放出前かどうかで残り時間の意味が変わるため、役割が決まるまでは出さない。
    await pumpHeader(tester, roleTheme: null, countdownSec: 125);

    expect(find.text('ゲーム中'), findsOneWidget);
    expect(find.text('2:05'), findsNothing);
    expect(find.text('--:--'), findsNothing);
  });

  testWidgets('渡されたactionsを右端に出す', (tester) async {
    // GamePageはデバッグビルド限定の偽プレイヤートグルをここへ渡す。
    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.demon),
      countdownSec: 60,
      actions: const [Icon(Icons.bug_report)],
    );

    expect(find.byIcon(Icons.bug_report), findsOneWidget);
  });

  testWidgets('小さい画面でも溢れない', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.fugitive),
      countdownSec: 3599,
      actions: const [Icon(Icons.bug_report)],
    );

    expect(tester.takeException(), isNull);
  });
}
