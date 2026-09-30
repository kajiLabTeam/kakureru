import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_progress.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/effect_band.dart';
import 'package:kakureru/features/mission/view/mission_card.dart';
import 'package:kakureru/features/mission/view/reward_page.dart';
import 'package:kakureru/features/room/model/room_user.dart';

const _accessPoint = Mission(
  id: 'm1',
  type: MissionType.accessPoint,
  createdAt: 0,
  expiresAt: 180000,
  lat: 35,
  lng: 137,
  radiusM: 15,
);

const _approach = Mission(
  id: 'a1',
  type: MissionType.approachDemon,
  createdAt: 0,
  expiresAt: 120000,
);

AccessPointReading _reading(
  AccessPointFix fix, {
  double? distance = 62,
  double? accuracy = 8,
}) => (fix: fix, distanceM: distance, accuracyM: accuracy, sampleAt: 1);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(12), child: child),
  ),
);

void main() {
  group('missionCardStatusOf', () {
    MissionCardStatus status({
      Mission mission = _accessPoint,
      LocationFailure failure = LocationFailure.none,
      AccessPointFix fix = AccessPointFix.outside,
      MissionProgress progress = const MissionProgress(missionId: 'm1'),
    }) => missionCardStatusOf(
      mission: mission,
      myUid: 'me',
      locationFailure: failure,
      reading: _reading(fix),
      progress: progress,
    );

    test('位置情報の権限が無ければ「許可が必要」に差し替える', () {
      expect(
        status(failure: LocationFailure.locationPermission),
        MissionCardStatus.needsLocationPermission,
      );
    });

    test('GPSが弱ければweakGps、範囲外ならapproaching', () {
      expect(status(fix: AccessPointFix.weakGps), MissionCardStatus.weakGps);
      expect(status(), MissionCardStatus.approaching);
    });

    test('範囲内が1回だけではまだ到着にしない(2回続くまで)', () {
      expect(status(fix: AccessPointFix.inside), MissionCardStatus.approaching);
      expect(
        status(
          progress: const MissionProgress(
            missionId: 'm1',
            arrival: (streak: 2, lastSampleAt: 2, arrived: true),
          ),
        ),
        MissionCardStatus.arrived,
      );
    });

    test('別のミッションの到着は引き継がない', () {
      expect(
        status(
          progress: const MissionProgress(
            missionId: 'old',
            arrival: (streak: 2, lastSampleAt: 2, arrived: true),
          ),
        ),
        MissionCardStatus.approaching,
      );
    });

    test('取られていれば、権限や位置より先に「取られた」を出す', () {
      expect(
        status(
          mission: _accessPoint.copyWith(claimedBy: 'other', claimedAt: 1),
          failure: LocationFailure.locationPermission,
        ),
        MissionCardStatus.takenByOther,
      );
      expect(
        status(mission: _accessPoint.copyWith(claimedBy: 'me', claimedAt: 1)),
        MissionCardStatus.claimedByMe,
      );
    });

    test('「鬼に近づけ」は達成したかどうかだけ', () {
      expect(status(mission: _approach), MissionCardStatus.approachInProgress);
      expect(
        status(
          mission: _approach,
          progress: const MissionProgress(
            missionId: 'a1',
            approach: (sawNoReaction: true, achieved: true),
          ),
        ),
        MissionCardStatus.approachAchieved,
      );
    });
  });

  group('MissionCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      MissionCardStatus status, {
      Mission mission = _accessPoint,
      AccessPointReading? reading,
      String? claimedByName,
    }) => tester.pumpWidget(
      _wrap(
        MissionCard(
          mission: mission,
          status: status,
          reading: reading ?? _reading(AccessPointFix.outside),
          remainingMillis: 134000,
          claimedByName: claimedByName,
        ),
      ),
    );

    testWidgets('向かっている間は「のこり N m」と「GPS ±N m」を出す', (tester) async {
      await pumpCard(tester, MissionCardStatus.approaching);
      expect(find.text('アクセスポイントへ行こう'), findsOneWidget);
      expect(find.text('のこり 62m'), findsOneWidget);
      expect(find.text('±8m'), findsOneWidget);
      expect(find.text('先着1名'), findsOneWidget);
      expect(find.text('02:14'), findsOneWidget);
    });

    testWidgets('GPSが弱いときは、その理由と距離・精度を出す', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.weakGps,
        reading: _reading(AccessPointFix.weakGps, distance: 9, accuracy: 42),
      );
      expect(find.textContaining('GPSの電波が弱い'), findsOneWidget);
      expect(find.text('のこり 9m'), findsOneWidget);
      expect(find.text('±42m'), findsOneWidget);
    });

    testWidgets('権限が無いときは「位置情報の許可が必要」', (tester) async {
      await pumpCard(tester, MissionCardStatus.needsLocationPermission);
      expect(find.text('位置情報の許可が必要'), findsOneWidget);
    });

    testWidgets('到着したら「まだ誰も取っていない」を出す', (tester) async {
      await pumpCard(tester, MissionCardStatus.arrived);
      expect(find.text('アクセスポイントに着いた'), findsOneWidget);
      expect(find.text('まだ誰も取っていない'), findsOneWidget);
    });

    testWidgets('取られたら「ほかの人に取られた」と取った人の名前', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.takenByOther,
        mission: _accessPoint.copyWith(claimedBy: 'x', claimedAt: 1),
        claimedByName: 'あやな',
      );
      expect(find.text('ほかの人に取られた'), findsOneWidget);
      expect(find.textContaining('あやな'), findsOneWidget);
    });

    testWidgets('自分が取ったら特典と「鬼に効く／自分に効く」を出す', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.claimedByMe,
        mission: _accessPoint.copyWith(
          claimedBy: 'me',
          claimedAt: 1,
          reward: RewardType.skipFootPhoto,
        ),
      );
      expect(find.text('足元写真を1回まぬがれる'), findsOneWidget);
      expect(find.text('自分に効く'), findsOneWidget);
    });

    testWidgets('「鬼に近づけ」は なし → あり と、捕まらない距離の注意を出す', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.approachInProgress,
        mission: _approach,
      );
      expect(find.text('鬼に近づけ'), findsOneWidget);
      expect(find.text('全員が挑める'), findsOneWidget);
      expect(find.text('なし'), findsOneWidget);
      expect(find.text('あり'), findsOneWidget);
      expect(find.text('捕まらない距離で。BLEが届くと捕まる'), findsOneWidget);
    });

    testWidgets('「鬼に近づけ」を達成したら「達成した」だけを出す(報酬は無し)', (
      tester,
    ) async {
      await pumpCard(
        tester,
        MissionCardStatus.approachAchieved,
        mission: _approach,
      );
      expect(find.text('達成した'), findsOneWidget);
      expect(find.textContaining('特典'), findsNothing);
    });
  });

  testWidgets('「特典を引く」は44px以上で、押すと呼ばれる', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(MissionClaimButton(isClaiming: false, onPressed: () => pressed++)),
    );
    final button = find.widgetWithText(FilledButton, '特典を引く');
    final size = tester.getSize(button);
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
    await tester.tap(button);
    expect(pressed, 1);
  });

  testWidgets('送信中の「特典を引く」は押せない', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(MissionClaimButton(isClaiming: true, onPressed: () => pressed++)),
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(pressed, 0);
  });

  group('効果の帯', () {
    test('残り時間は秒を切り上げて m:ss', () {
      expect(formatEffectRemaining(18000), '0:18');
      expect(formatEffectRemaining(17001), '0:18');
      expect(formatEffectRemaining(30000), '0:30');
      expect(formatEffectRemaining(0), '0:00');
      expect(formatEffectRemaining(-5), '0:00');
    });

    testWidgets('逃走者には「鬼の手がかりを止めている のこり 0:18」', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EffectBand(
            type: RewardType.blockClues,
            viewerRole: UserRole.fugitive,
            remainingMillis: 18000,
          ),
        ),
      );
      expect(find.text('鬼の手がかりを止めている'), findsOneWidget);
      expect(find.text('のこり 0:18'), findsOneWidget);
    });

    test('鬼には誰に止められているかが分かる言い方にする', () {
      expect(
        effectBandText(RewardType.blockClues, viewerRole: UserRole.demon),
        '逃走者に手がかりを止められている',
      );
    });
  });

  testWidgets('特典の画面は引いた特典と「鬼に効く」、ほかの特典を出す', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RewardPage(reward: RewardType.blockClues)),
    );
    expect(find.text('特典をひいた！'), findsOneWidget);
    expect(find.text('鬼の手がかりを止める'), findsOneWidget);
    expect(find.text('30秒'), findsOneWidget);
    expect(find.text('鬼のアイコンを大きくする'), findsOneWidget);
    expect(find.text('足元写真を1回まぬがれる'), findsOneWidget);
    // 引いた特典とほかの鬼に効く特典で2つ、自分に効くもので1つ。
    expect(find.text('鬼に効く'), findsNWidgets(2));
    expect(find.text('自分に効く'), findsOneWidget);
    expect(find.text('地図にもどる'), findsOneWidget);
  });
}
