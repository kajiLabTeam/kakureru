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
    VoidCallback? onHelp,
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
            onHelp: onHelp,
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
    final timer = tester.widget<Text>(find.text('02:05'));

    // ゲーム画面モック(393dp幅)の17px/20px。以前は280px枠のモックの数値を
    // そのまま15px/19pxで実装していて小さすぎた(issue #76)。
    expect(label.style!.fontSize, gameHeaderLabelFontSize);
    expect(timer.style!.fontSize, gameHeaderTimerFontSize);
    expect(gameHeaderLabelFontSize, greaterThan(15));
    expect(gameHeaderTimerFontSize, greaterThan(19));
    // 残り時間は桁が変わっても幅が揺れないよう等幅で出す。
    expect(timer.style!.fontFamily, 'monospace');
  });

  testWidgets('役割が決まっていれば、濃い役割色を背景に敷いて文字を白にする', (tester) async {
    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.fugitive),
      countdownSec: 0,
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    // ピン色(#4A9C5D)ではなく、白文字が読める濃い方(#3A7F4A)。
    expect(appBar.backgroundColor, const Color(0xFF3A7F4A));
    // AppBarThemeのtitleTextStyleが非nullだとforegroundColorは混ざらない
    // (Flutterの仕様)ので、ここは明示的に白を指定する必要がある。
    expect(renderedColorOf(tester, 'あなたは 逃走者'), Colors.white);
    expect(renderedColorOf(tester, '00:00'), Colors.white);
  });

  testWidgets('役割が未確定なら、白地に白で消えないようテーマの文字色を継承する', (tester) async {
    await pumpHeader(tester, countdownSec: 125);

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
    await pumpHeader(tester, countdownSec: 125);

    expect(find.text('ゲーム中'), findsOneWidget);
    expect(find.text('02:05'), findsNothing);
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

  testWidgets('「?」は44dp四方で、押すとonHelpを呼ぶ', (tester) async {
    var tapped = 0;
    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.demon),
      countdownSec: 60,
      onHelp: () => tapped++,
    );

    final help = find.byTooltip('遊び方と使ってよい場所');
    expect(tester.getSize(help).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(help).height, greaterThanOrEqualTo(44));
    await tester.tap(help);
    expect(tapped, 1);
  });

  testWidgets('onHelpが無ければ「?」を出さない', (tester) async {
    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.demon),
      countdownSec: 60,
    );

    expect(find.byIcon(Icons.help_outline), findsNothing);
  });

  testWidgets('小さい画面でも溢れない', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpHeader(
      tester,
      roleTheme: roleThemeOf(UserRole.fugitive),
      countdownSec: 3599,
      onHelp: () {},
      actions: const [Icon(Icons.bug_report)],
    );

    expect(tester.takeException(), isNull);
  });
}
