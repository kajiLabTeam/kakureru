import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/view/game/outside_area_alert.dart';

/// エリア外アラートの3部品(issue #61 / UI改修モック2a-07)のテスト。
///
/// GamePage全体は位置情報・Wi-Fi・気圧・BLEなど多数のproviderに依存して
/// おりFirebase初期化なしではwidgetテストを組みにくいため、
/// become_demon_button_test.dartと同じく部品だけを直接組んで確認する。
void main() {
  // 北緯35度・東経135度付近の矩形。判定の詳細はarea_alert_test.dart側。
  const area = [
    LatLng(lat: 35, lng: 135),
    LatLng(lat: 35, lng: 135.002),
    LatLng(lat: 35.002, lng: 135.002),
    LatLng(lat: 35.002, lng: 135),
  ];

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('赤帯に「プレイエリアの外です」と、振動が続く旨が出る', (tester) async {
    await tester.pumpWidget(host(const OutsideAreaBanner()));

    expect(find.text('🚨'), findsOneWidget);
    expect(find.text('プレイエリアの外です'), findsOneWidget);
    expect(find.text('戻るまで振動と通知が続きます'), findsOneWidget);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(OutsideAreaBanner),
        matching: find.byType(Container),
      ),
    );
    expect(container.color, outsideAreaAlertColor);
  });

  testWidgets('カードに「エリアまで約◯m ・ ◯へ戻ってください」が出る', (tester) async {
    await tester.pumpWidget(
      host(const ReturnToAreaCard(meters: 40, bearingDegrees: 315)),
    );

    expect(find.text('エリアまで約 40m ・ 北西へ戻ってください'), findsOneWidget);
  });

  testWidgets('カードの距離と方位は渡された値から作られる', (tester) async {
    final result = describeReturnToArea(
      area: area,
      // 北へはみ出した位置。南へ約111m戻る。
      point: const LatLng(lat: 35.003, lng: 135.001),
    )!;
    await tester.pumpWidget(
      host(
        ReturnToAreaCard(
          meters: result.meters,
          bearingDegrees: result.bearingDegrees,
        ),
      ),
    );

    expect(find.textContaining('南へ戻ってください'), findsOneWidget);
    expect(find.textContaining('エリアまで約 111m'), findsOneWidget);
  });

  testWidgets('地図オーバーレイは赤の半透明を敷き、方位ぶん矢印を回す', (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 300,
          height: 300,
          child: OutsideAreaMapOverlay(bearingDegrees: 90),
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

  testWidgets('エリアの内側なら判定がnullになり、アラートは何も出ない', (tester) async {
    final result = describeReturnToArea(
      area: area,
      point: const LatLng(lat: 35.001, lng: 135.001),
    );
    expect(result, isNull);

    // GamePage側の配線と同じく、判定がnullなら3部品とも組み立てない。
    await tester.pumpWidget(
      host(
        Column(
          children: [
            if (result != null) const OutsideAreaBanner(),
            if (result != null)
              ReturnToAreaCard(
                meters: result.meters,
                bearingDegrees: result.bearingDegrees,
              ),
          ],
        ),
      ),
    );

    expect(find.byType(OutsideAreaBanner), findsNothing);
    expect(find.byType(ReturnToAreaCard), findsNothing);
    expect(find.textContaining('プレイエリアの外です'), findsNothing);
    expect(find.textContaining('戻ってください'), findsNothing);
  });

  testWidgets('エリア未設定のルームでは判定がnullになり、アラートは何も出ない', (tester) async {
    final result = describeReturnToArea(
      area: const [],
      // エリアが設定されていれば確実に外側になる、遠く離れた位置。
      point: const LatLng(lat: 0, lng: 0),
    );
    expect(result, isNull);

    await tester.pumpWidget(
      host(
        result == null ? const SizedBox.shrink() : const OutsideAreaBanner(),
      ),
    );
    expect(find.byType(OutsideAreaBanner), findsNothing);
  });
}
