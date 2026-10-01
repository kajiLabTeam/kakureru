import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_notice.dart';
import 'package:kakureru/features/mission/model/mission_progress.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/effect_band.dart';
import 'package:kakureru/features/mission/view/mission_card.dart';
import 'package:kakureru/features/mission/view/mission_notice_banner.dart';
import 'package:kakureru/features/mission/view/reward_page.dart';
import 'package:kakureru/features/room/model/room_user.dart';

const _accessPoint = Mission(
  id: 'm1',
  round: 1,
  createdAt: 0,
  expiresAt: 300000,
  spots: [
    MissionSpot(id: 's0', lat: 35, lng: 137, radiusM: 15),
    MissionSpot(id: 's1', lat: 35.01, lng: 137, radiusM: 15),
  ],
);

/// [_accessPoint]の地点[spotId]を[claimedBy]が取った状態にする。
Mission _claimed(
  String spotId,
  String claimedBy, {
  RewardType? reward,
  Mission mission = _accessPoint,
}) => mission.copyWith(
  spots: [
    for (final spot in mission.spots)
      spot.id == spotId
          ? spot.copyWith(claimedBy: claimedBy, claimedAt: 1, reward: reward)
          : spot,
  ],
);

const _arrived = MissionProgress(
  missionId: 'm1',
  spotId: 's0',
  arrival: (streak: 2, lastSampleAt: 2, arrived: true),
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
      targetSpotId: 's0',
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
        status(fix: AccessPointFix.inside, progress: _arrived),
        MissionCardStatus.arrived,
      );
    });

    test('到着した後に範囲の外へ出たら「範囲の外に出た」で、引けない', () {
      expect(status(progress: _arrived), MissionCardStatus.leftRange);
    });

    test('到着した後にGPSが弱くなっただけなら、引ける', () {
      expect(
        status(fix: AccessPointFix.weakGps, progress: _arrived),
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

    test('別の地点への到着は、いまいちばん近い地点には使わない', () {
      expect(
        status(
          fix: AccessPointFix.inside,
          progress: _arrived.copyWith(spotId: 's1'),
        ),
        MissionCardStatus.approaching,
      );
    });

    test('地点がすべて取られていれば、権限や位置より先に「取られた」を出す', () {
      expect(
        status(
          mission: _claimed('s1', 'b', mission: _claimed('s0', 'a')),
          failure: LocationFailure.locationPermission,
        ),
        MissionCardStatus.takenByOther,
      );
      expect(
        status(mission: _accessPoint.copyWith(finishedAt: 1)),
        MissionCardStatus.takenByOther,
      );
    });

    test('1つでも空いていれば、ほかの地点が取られても向かえる', () {
      expect(
        status(mission: _claimed('s1', 'other')),
        MissionCardStatus.approaching,
      );
    });

    test('自分が取った地点があれば「引いた」', () {
      expect(
        status(
          mission: _claimed('s1', 'me', reward: RewardType.blockClues),
        ),
        MissionCardStatus.claimedByMe,
      );
    });

    test('自分が取ったのにごほうびが書かれていなければ、受け取り直せる状態にする', () {
      expect(
        status(mission: _claimed('s0', 'me')),
        MissionCardStatus.claimedWithoutReward,
      );
    });
  });

  group('MissionCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      MissionCardStatus status, {
      Mission mission = _accessPoint,
      AccessPointReading? reading,
      RewardType? myReward,
    }) => tester.pumpWidget(
      _wrap(
        MissionCard(
          mission: mission,
          status: status,
          reading: reading ?? _reading(AccessPointFix.outside),
          remainingMillis: 134000,
          myReward: myReward,
        ),
      ),
    );

    testWidgets('向かっている間は「のこり N m」と「GPS ±N m」を出す', (tester) async {
      await pumpCard(tester, MissionCardStatus.approaching);
      expect(find.text('アクセスポイントへ行こう'), findsOneWidget);
      expect(find.text('近いのは のこり 62m'), findsOneWidget);
      expect(find.text('GPS '), findsOneWidget);
      expect(find.text('±8m'), findsOneWidget);
      // 地点の数だけ先着で取れる。
      expect(find.text('先着2人'), findsOneWidget);
      expect(find.text('02:14'), findsOneWidget);
    });

    testWidgets('GPSが弱いときは、その理由と距離・精度を出す', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.weakGps,
        reading: _reading(AccessPointFix.weakGps, distance: 9, accuracy: 42),
      );
      expect(find.text('GPSの電波が弱い'), findsOneWidget);
      expect(find.text('近いのは のこり 9m'), findsOneWidget);
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

    testWidgets('すべて取られたら「ほかの人に取られた」', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.takenByOther,
        mission: _claimed('s1', 'b', mission: _claimed('s0', 'a')),
      );
      expect(find.text('ほかの人に取られた'), findsOneWidget);
    });

    testWidgets('自分が取ったらごほうびと「自分がトクする」を出す', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.claimedByMe,
        mission: _claimed('s0', 'me', reward: RewardType.skipFootPhoto),
        myReward: RewardType.skipFootPhoto,
      );
      expect(find.text('足元写真を1回まぬがれる'), findsOneWidget);
      expect(find.text('自分がトクする'), findsOneWidget);
    });

    testWidgets('鬼に効くごほうびには「鬼をジャマする」を添える', (tester) async {
      await pumpCard(
        tester,
        MissionCardStatus.claimedByMe,
        myReward: RewardType.blockClues,
      );
      expect(find.text('鬼をジャマする'), findsOneWidget);
    });

    testWidgets('絵文字を使わない', (tester) async {
      await pumpCard(tester, MissionCardStatus.arrived);
      final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(emoji.hasMatch(text.data ?? ''), isFalse, reason: text.data);
      }
    });
  });

  testWidgets('「ごほうびガチャを引く」は44px以上で、押すと呼ばれる', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(MissionClaimButton(isClaiming: false, onPressed: () => pressed++)),
    );
    final button = find.widgetWithText(FilledButton, 'ごほうびガチャを引く');
    final size = tester.getSize(button);
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
    await tester.tap(button);
    expect(pressed, 1);
  });

  testWidgets('受け取り直すときは「ごほうびを受け取る」と出す', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MissionClaimButton(
          label: 'ごほうびを受け取る',
          isClaiming: false,
          onPressed: () {},
        ),
      ),
    );
    expect(find.text('ごほうびを受け取る'), findsOneWidget);
  });

  testWidgets('送信中の「ごほうびガチャを引く」は押せない', (tester) async {
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

    test('鬼には誰に止められているかは分からない言い方にする', () {
      expect(
        effectBandText(RewardType.blockClues, viewerRole: UserRole.demon),
        '逃走者のごほうびで止められている',
      );
    });

    testWidgets('drawerNameがあれば「(名前) のごほうび：…」を出す(逃走者視点)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EffectBand(
            type: RewardType.blockClues,
            viewerRole: UserRole.fugitive,
            remainingMillis: 18000,
            drawerName: 'みお',
          ),
        ),
      );
      expect(find.text('みお のごほうび：鬼の手がかりを止めている'), findsOneWidget);
    });

    testWidgets('drawerNameが無ければ名前を出さない(鬼視点ではnullを渡す想定)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EffectBand(
            type: RewardType.blockClues,
            viewerRole: UserRole.demon,
            remainingMillis: 18000,
          ),
        ),
      );
      expect(find.text('逃走者のごほうびで止められている'), findsOneWidget);
    });
  });

  testWidgets('ごほうびの画面は引いたごほうびと「鬼をジャマする」、ほかのごほうびを出す', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RewardPage(reward: RewardType.blockClues)),
    );
    expect(find.text('ごほうびをひいた！'), findsOneWidget);
    expect(find.text('鬼の手がかりを止める'), findsOneWidget);
    expect(find.text('30秒'), findsOneWidget);
    expect(find.text('鬼のアイコンを大きくする'), findsOneWidget);
    expect(find.text('足元写真を1回まぬがれる'), findsOneWidget);
    // 引いたごほうびとほかの鬼に効くごほうびで2つ、自分に効くもので1つ。
    expect(find.text('鬼をジャマする'), findsNWidgets(2));
    expect(find.text('自分がトクする'), findsOneWidget);
    expect(find.text('地図にもどる'), findsOneWidget);
  });

  group('デバッグ用の「着いたことにする」', () {
    test('DEBUG_MISSIONを付けずに起動したら出さない(テストも付けていない)', () {
      expect(debugMissionArrivalEnabled, isFalse);
    });

    testWidgets('既定のままでは何も描かない', (tester) async {
      await tester.pumpWidget(
        _wrap(MissionDebugArrivalButton(onPressed: () {})),
      );
      expect(find.text('着いたことにする'), findsNothing);
    });

    testWidgets('有効なら44px以上で出て、押すと呼ばれる', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _wrap(
          MissionDebugArrivalButton(enabled: true, onPressed: () => pressed++),
        ),
      );
      final button = find.text('着いたことにする');
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(button);
      expect(pressed, 1);
    });
  });

  group('お知らせのバナー', () {
    testWidgets('文言を出し、44px以上で、押すと呼ばれる', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          MissionNoticeBanner(
            notice: const MissionNotice(
              kind: MissionNoticeKind.created,
              missionId: 'm1',
              message: 'アクセスポイントへ行こう',
            ),
            onTap: () => tapped++,
          ),
        ),
      );
      expect(find.text('アクセスポイントへ行こう'), findsOneWidget);
      expect(
        tester.getSize(find.byType(MissionNoticeBanner)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byType(MissionNoticeBanner));
      expect(tapped, 1);
    });
  });
}
