import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/outside_area_alert.dart';

/// エリア外アラート(issue #61 / UI改修モック2a-07)のテスト。
///
/// 出す/出さないの分岐も配置も`outsideAreaAlertOf`と[OutsideAreaAlertMap]
/// (GamePageが使うのと同じもの)の中にあるので、テストからは
/// `buildGameMapAreaForTest`で本番と同じ配線を組んで確認する。以前は
/// テスト側で`if (result != null)`を書き直しており、配線が壊れても
/// 気づけなかった。
void main() {
  // 北緯35度・東経135度付近の矩形。判定の詳細はarea_alert_test.dart側。
  const area = [
    LatLng(lat: 35, lng: 135),
    LatLng(lat: 35, lng: 135.002),
    LatLng(lat: 35.002, lng: 135.002),
    LatLng(lat: 35.002, lng: 135),
  ];
  const myUid = 'me';
  const users = [RoomUser(id: myUid, displayName: 'わたし')];
  const nowMillis = 1800000000000;

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// 自分の位置から、GamePageと同じ順路(観測→猶予判定→アラート)で
  /// アラートの中身を作る。[isWarning]は猶予判定の結果に相当する。
  OutsideAreaAlert? alertFor({
    required double lat,
    required double lng,
    bool isWarning = true,
    double? accuracy,
  }) {
    final observation = observeOutsideArea(
      area: area,
      location: UserLocation(
        uid: myUid,
        latitude: lat,
        longitude: lng,
        accuracy: accuracy,
        updatedAt: nowMillis,
      ),
      nowMillis: nowMillis,
    );
    final state = applyOutsideAreaHysteresis(
      observation: observation,
      previous: (
        isWarning: isWarning,
        outsideSince: null,
        outsideSinceUpdatedAt: 0,
        lastKnownAt: null,
      ),
      now: DateTime.utc(2026, 9, 20, 12),
    );
    return outsideAreaAlertOf(
      isWarning: state.isWarning,
      observation: observation,
    );
  }

  /// 地図領域(地図+アラート)をGamePageと同じ配線で立ち上げる。
  Future<void> pumpMapArea(
    WidgetTester tester, {
    required OutsideAreaAlert? alert,
    Size size = const Size(360, 640),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      host(
        buildGameMapAreaForTest(
          alert: alert,
          myUid: myUid,
          users: users,
          gameArea: area,
          locations: const [
            UserLocation(
              uid: myUid,
              latitude: 35.003,
              longitude: 135.001,
              updatedAt: nowMillis,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('赤帯に「プレイエリアの外です」と、振動が続く旨が出る', (tester) async {
    await tester.pumpWidget(host(const Center(child: OutsideAreaBanner())));

    expect(find.text('🚨'), findsOneWidget);
    expect(find.text('プレイエリアの外です'), findsOneWidget);
    expect(find.text(outsideAreaBannerSubtitle), findsOneWidget);

    final decoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(OutsideAreaBanner),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.color, outsideAreaAlertColor);
  });

  testWidgets('補足行は「続くのは画面を開いている間」と分かる文言で、モックと同じ不透明度で出す', (
    tester,
  ) async {
    await tester.pumpWidget(host(const Center(child: OutsideAreaBanner())));

    // 「戻るまでずっと」とだけ言うと、画面を消している間も続く約束に
    // なってしまう(判定はGamePageの再描画で回っている)。
    expect(outsideAreaBannerSubtitle, contains('アプリを開いている間'));

    final subtitle = tester.widget<Text>(find.text(outsideAreaBannerSubtitle));
    // モック2a-07の opacity:.85。Colors.white70 だとこの赤の上で
    // コントラスト比が足りない(約2.8:1)。
    expect(subtitle.style!.color!.a, closeTo(0.85, 0.01));
  });

  testWidgets('赤帯は鬼のヘッダーと同じ赤なので、区切り線で見分けが付くようにする', (tester) async {
    await tester.pumpWidget(host(const Center(child: OutsideAreaBanner())));

    final decoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(OutsideAreaBanner),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    final border = decoration.border!;
    expect(border.top.width, greaterThan(0));
    expect(border.bottom.width, greaterThan(0));
    expect(border.top.color, isNot(outsideAreaAlertColor));
  });

  testWidgets('カードに「エリアまで約◯m ・ ◯へ戻ってください」が出る', (tester) async {
    await tester.pumpWidget(
      host(
        const Center(child: ReturnToAreaCard(meters: 40, bearingDegrees: 315)),
      ),
    );

    expect(find.text('エリアまで約 40m ・ 北西へ戻ってください'), findsOneWidget);
  });

  testWidgets('地図オーバーレイは赤の半透明を敷き、方位ぶん矢印を回す', (tester) async {
    await tester.pumpWidget(
      host(
        const Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: OutsideAreaMapOverlay(bearingDegrees: 90),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(OutsideAreaMapOverlay),
        matching: find.byType(Container),
      ),
    );
    expect(container.color, outsideAreaAlertColor.withValues(alpha: 0.16));

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    final rotated = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(OutsideAreaMapOverlay),
            matching: find.byType(Transform),
          )
          .first,
    );
    // 東(90度)なら、上向きの矢印を時計回りに90度回した行列になる。
    // Matrix4の回転成分は [0][0]=cos, [1][0]=sin。
    expect(rotated.transform.storage[0], closeTo(0, 1e-9));
    expect(rotated.transform.storage[1], closeTo(1, 1e-9));

    // 地図のパン・ズームを邪魔しないこと。
    expect(
      find.descendant(
        of: find.byType(OutsideAreaMapOverlay),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('位置が古くて方位が出せないときは、矢印とカードを出さない', (tester) async {
    await pumpMapArea(
      tester,
      alert: const (meters: null, bearingDegrees: null),
    );

    expect(find.byType(OutsideAreaBanner), findsOneWidget);
    expect(find.byType(OutsideAreaMapOverlay), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byType(ReturnToAreaCard), findsNothing);
  });

  testWidgets('エリアの内側なら、配線を通してもアラートは何も出ない', (tester) async {
    final alert = alertFor(lat: 35.001, lng: 135.001);
    expect(alert, isNull);

    await pumpMapArea(tester, alert: alert);

    expect(find.byType(OutsideAreaBanner), findsNothing);
    expect(find.byType(OutsideAreaMapOverlay), findsNothing);
    expect(find.byType(ReturnToAreaCard), findsNothing);
    expect(find.textContaining('プレイエリアの外です'), findsNothing);
    expect(find.textContaining('戻ってください'), findsNothing);
  });

  testWidgets('エリアの外なら、配線を通して赤帯・赤かぶせ・カードが揃って出る', (tester) async {
    // 北へ約111mはみ出した位置。南へ戻る。
    final alert = alertFor(lat: 35.003, lng: 135.001, accuracy: 5);
    await pumpMapArea(tester, alert: alert);

    expect(find.byType(OutsideAreaBanner), findsOneWidget);
    expect(find.byType(OutsideAreaMapOverlay), findsOneWidget);
    expect(find.textContaining('南へ戻ってください'), findsOneWidget);
    expect(find.textContaining('エリアまで約 111m'), findsOneWidget);
  });

  testWidgets('アラートを出しても、地図と下のカードのレイアウトが動かない', (tester) async {
    // 実機で溢れていた小さい画面(issue #69のレビュー指摘)で確認する。
    const size = Size(320, 480);

    Future<Rect> pumpColumn({required bool withAlert}) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          Column(
            children: [
              Expanded(
                child: buildGameMapAreaForTest(
                  alert: withAlert
                      ? const (meters: 111, bearingDegrees: 180)
                      : null,
                  myUid: myUid,
                  users: users,
                  gameArea: area,
                ),
              ),
              // 地図の下に並ぶカード類の代わり。押し出されたらここが動く。
              const SizedBox(key: ValueKey('below'), height: 120),
            ],
          ),
        ),
      );
      return tester.getRect(find.byKey(const ValueKey('below')));
    }

    final withoutAlert = await pumpColumn(withAlert: false);
    final withAlert = await pumpColumn(withAlert: true);

    expect(withAlert, withoutAlert);
    expect(tester.takeException(), isNull);
    // アラートを出している状態でも、地図の上の表示が画面内に収まっている。
    expect(find.byType(ReturnToAreaCard), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('戻り方カードは地図の帰属表示(OSM/CARTO)のボタンを覆わない', (tester) async {
    await pumpMapArea(
      tester,
      alert: const (meters: 111, bearingDegrees: 180),
    );

    final card = tester.getRect(find.byType(ReturnToAreaCard));
    // 帰属表示の常設ボタン(タップでOSMとCARTOのクレジットが開く)。
    final attributionButton = tester.getRect(
      find.byIcon(Icons.info_outlined),
    );
    expect(card.overlaps(attributionButton), isFalse);
  });
}
