import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/room_waiting_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room1';
const _myUid = 'host';

/// RTDBを叩かずに、鬼指名の完了タイミングだけをテストから制御する
/// RoomRepositoryの差し替え。
///
/// `RoomRepository`のFirebaseハンドルは遅延初期化なので、このサブクラスが
/// 暗黙の`super()`を通っても`.instance`は解決されない(Firebase未初期化でも
/// インスタンス化できる)。
class _FakeRoomRepository extends RoomRepository {
  /// 直近の`nominateDemon`/`cancelDemonNomination`の完了を制御するCompleter。
  Completer<void>? pendingAction;
  final List<String> nominatedUids = [];
  int cancelCalls = 0;
  int leaveRoomCalls = 0;

  @override
  Future<void> nominateDemon(String roomId, String uid) {
    nominatedUids.add(uid);
    final completer = Completer<void>();
    pendingAction = completer;
    return completer.future;
  }

  @override
  Future<void> cancelDemonNomination(String roomId) {
    cancelCalls++;
    final completer = Completer<void>();
    pendingAction = completer;
    return completer.future;
  }

  @override
  Future<void> acceptDemonNomination(String roomId, String uid) async {}

  // 待機画面はdispose時に必ずleaveRoomを呼ぶので、ここで吸収する。
  @override
  Future<void> leaveRoom(String roomId) async {
    leaveRoomCalls++;
  }
}

/// センサーとRTDBを触らずに、キャリブレーション中の状態だけを再現する
/// PressureViewModelの差し替え。
class _FakePressureViewModel extends PressureViewModel {
  _FakePressureViewModel({this.initialState = const PressureState()});

  final PressureState initialState;

  /// キャリブレーションの完了を制御するCompleter(呼ばれるまでnull)。
  Completer<void>? pendingCalibration;

  @override
  PressureState build() => initialState;

  // 本物はセンサーの有無を実機に問い合わせるので何もしない。
  @override
  Future<void> init(String roomId) async {}

  @override
  Future<void> calibrateAsHost(String roomId) async {
    final completer = Completer<void>();
    pendingCalibration = completer;
    state = state.copyWith(isCalibrating: true);
    try {
      await completer.future;
    } finally {
      state = state.copyWith(isCalibrating: false);
    }
  }
}

/// 気圧を取得済み・キャリブレーション未実施のホスト1人だけのルーム。
Room _room({String? pendingDemonUid, int createdAt = 0}) => Room(
  id: _roomId,
  roomCode: '1234',
  hostUserId: _myUid,
  status: RoomStatus.waiting,
  createdAt: createdAt,
  pendingDemonUid: pendingDemonUid,
  setting: const RoomSetting(),
  users: const [
    RoomUser(
      id: _myUid,
      displayName: 'ホスト',
      isHost: true,
      pressureSensorAvailable: true,
    ),
  ],
);

/// 待機画面を開いて、最初のルームのスナップショットを流すところまで行う。
Future<StreamController<Room>> _pumpWaitingPage(
  WidgetTester tester, {
  required _FakeRoomRepository roomRepo,
  required _FakePressureViewModel pressureViewModel,
  Room? initialRoom,
}) async {
  // 既定の800x600では下部のボタンが画面外に出てタップできない。
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = StreamController<Room>.broadcast();
  addTearDown(controller.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myUidProvider.overrideWithValue(_myUid),
        roomRepositoryProvider.overrideWithValue(roomRepo),
        pressureViewModelProvider.overrideWith(() => pressureViewModel),
        roomStreamProvider(_roomId).overrideWith((ref) => controller.stream),
      ],
      child: const MaterialApp(home: RoomWaitingPage(roomId: _roomId)),
    ),
  );
  await tester.pump();
  controller.add(initialRoom ?? _room());
  await tester.pump();
  return controller;
}

ActionChip _chipWithText(WidgetTester tester, String label) =>
    tester.widget<ActionChip>(find.widgetWithText(ActionChip, label));

void main() {
  group('鬼指名(「鬼にする」「取り消す」)', () {
    testWidgets('送信中はチップがスピナーになり、押せなくなる', (tester) async {
      final roomRepo = _FakeRoomRepository();
      await _pumpWaitingPage(
        tester,
        roomRepo: roomRepo,
        pressureViewModel: _FakePressureViewModel(),
      );

      expect(_chipWithText(tester, '鬼にする').onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ActionChip, '鬼にする'));
      await tester.pump();

      expect(roomRepo.nominatedUids, [_myUid]);
      // ラベルがスピナーに差し替わるのでテキストは消える。
      expect(find.widgetWithText(ActionChip, '鬼にする'), findsNothing);
      final chip = tester.widget<ActionChip>(find.byType(ActionChip));
      expect(chip.label, isA<SizedBox>());
      expect(
        find.descendant(
          of: find.byType(ActionChip),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(chip.onPressed, isNull);
    });

    testWidgets('送信が失敗したらエラーを表示し、チップは押せる状態に戻る', (tester) async {
      final roomRepo = _FakeRoomRepository();
      await _pumpWaitingPage(
        tester,
        roomRepo: roomRepo,
        pressureViewModel: _FakePressureViewModel(),
      );

      await tester.tap(find.widgetWithText(ActionChip, '鬼にする'));
      await tester.pump();

      roomRepo.pendingAction!.completeError(Exception('指名の失敗を模擬'));
      await tester.pump();

      expect(find.textContaining('指名の失敗を模擬'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ActionChip),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(_chipWithText(tester, '鬼にする').onPressed, isNotNull);
    });

    testWidgets('送信中の連打は無視され、リクエストは1回しか飛ばない', (tester) async {
      final roomRepo = _FakeRoomRepository();
      await _pumpWaitingPage(
        tester,
        roomRepo: roomRepo,
        pressureViewModel: _FakePressureViewModel(),
      );

      await tester.tap(find.widgetWithText(ActionChip, '鬼にする'));
      await tester.pump();
      // 無効化されたチップを押しても何も起きない(warnIfMissedは不要)。
      await tester.tap(find.byType(ActionChip));
      await tester.pump();

      expect(roomRepo.nominatedUids, hasLength(1));
    });

    testWidgets('「取り消す」も送信中はスピナーになり、押せなくなる', (tester) async {
      final roomRepo = _FakeRoomRepository();
      await _pumpWaitingPage(
        tester,
        roomRepo: roomRepo,
        pressureViewModel: _FakePressureViewModel(),
        initialRoom: _room(pendingDemonUid: _myUid),
      );

      expect(_chipWithText(tester, '取り消す').onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ActionChip, '取り消す'));
      await tester.pump();

      expect(roomRepo.cancelCalls, 1);
      expect(find.widgetWithText(ActionChip, '取り消す'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ActionChip),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<ActionChip>(find.byType(ActionChip)).onPressed,
        isNull,
      );
    });
  });

  testWidgets('画面が破棄されたらルームから退出する', (tester) async {
    // 破棄時のleaveRoomは、以前はdispose中にref.readしていたため
    // StateErrorで呼ばれないままになっていた(build時に取得した
    // roomRepoを使う形に修正済み)。その再発防止。
    final roomRepo = _FakeRoomRepository();
    await _pumpWaitingPage(
      tester,
      roomRepo: roomRepo,
      pressureViewModel: _FakePressureViewModel(),
    );
    expect(roomRepo.leaveRoomCalls, 0);

    // 別の画面に差し替えて待機画面をunmountさせる。
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(roomRepo.leaveRoomCalls, 1);
  });

  group('キャリブレーションボタン', () {
    testWidgets('押すとスピナーとキャリブレーション中の表示に変わり、押せなくなる', (tester) async {
      final pressureViewModel = _FakePressureViewModel(
        initialState: const PressureState(
          sensorAvailability: PressureSensorAvailability.available,
          myPressureHPa: 1013,
        ),
      );
      await _pumpWaitingPage(
        tester,
        roomRepo: _FakeRoomRepository(),
        pressureViewModel: pressureViewModel,
      );

      final button = find.widgetWithText(
        FilledButton,
        'キャリブレーションする(未実施)',
      );
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.pump();

      expect(find.text('キャリブレーション中...'), findsOneWidget);
      final calibratingButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'キャリブレーション中...'),
      );
      expect(
        find.descendant(
          of: find.widgetWithText(FilledButton, 'キャリブレーション中...'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(calibratingButton.onPressed, isNull);

      pressureViewModel.pendingCalibration!.complete();
      await tester.pump();

      expect(find.text('キャリブレーション中...'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'キャリブレーションする(未実施)'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('気圧をまだ取得できていない間は押せず、取得中と伝える', (tester) async {
      await _pumpWaitingPage(
        tester,
        roomRepo: _FakeRoomRepository(),
        pressureViewModel: _FakePressureViewModel(
          initialState: const PressureState(
            sensorAvailability: PressureSensorAvailability.available,
          ),
        ),
      );

      expect(find.text('気圧を取得中...'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'キャリブレーションする(未実施)'),
            )
            .onPressed,
        isNull,
      );
    });
  });
}
