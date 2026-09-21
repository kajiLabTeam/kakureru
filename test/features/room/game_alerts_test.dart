import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/game_alerts.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// [GameAlerts](issue #71)のテスト。
///
/// **このクラスの存在理由は「画面が消えていても判定が進むこと」**なので、
/// ウィジェットを一切使わずに`ProviderContainer`だけで回す。以前はこの3つの
/// 判定がGamePageのフックにあり、時間を進めるのに`tester.pump`が要った——
/// つまり**フレームが無いと判定が進まないことがテストの形にも表れていた**。
///
/// **振動は検証しない。** テストではプラグインの登録が走らず、`Vibration`
/// のプラットフォーム実装に届かないため(既存のテストも同じ理由で通知だけを
/// 見ていた)。振動は通知と同じ経路の隣り合った行で打っているので、通知が
/// 出ていることで分岐は担保できる。実際に振動するかは実機で確認する。
///
/// 時間は`fakeAsync`で進める。`Timer.periodic`は`elapse`で発火するが
/// `Stopwatch`は進まないため、猶予時間の計測に使う単調増加の時計は
/// [GameAlerts]のコンストラクタから差し替える。
void main() {
  // testWidgetsではなくtestで回すので、バインディングは自分で用意する
  // (通知・振動のメソッドチャネルを差し替えるのに要る)。
  TestWidgetsFlutterBinding.ensureInitialized();

  const roomId = 'room1';
  const myUid = 'me';

  // サーバー時刻の基準。判定は大小関係しか見ないので値自体に意味は無い。
  const t0 = 1800000000000;

  // 通知プラグインのメソッドチャネル。実機では出ているはずの通知を、
  // テストでは呼び出しの記録として受け取る。
  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  late List<String> notificationCalls;

  setUp(() {
    notificationCalls = [];
    // 端末が無いテストではプラグインの登録が走らないため、Android実装を
    // 自分で登録してからチャネルを差し替える。
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notificationChannel, (call) async {
      notificationCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notificationChannel, null);
  });

  /// 北緯35度・東経135度付近の矩形。判定の詳細はarea_alert_test.dart側。
  const area = [
    LatLng(lat: 35, lng: 135),
    LatLng(lat: 35, lng: 135.002),
    LatLng(lat: 35.002, lng: 135.002),
    LatLng(lat: 35.002, lng: 135),
  ];

  Room roomWith({
    int? releasedAt,
    int? endsAt,
    RoomStatus status = RoomStatus.playing,
    List<LatLng> gameArea = const [],
    bool hasFugitive = true,
  }) {
    return Room(
      id: roomId,
      roomCode: '1234',
      hostUserId: myUid,
      createdAt: t0,
      status: status,
      releasedAt: releasedAt,
      endsAt: endsAt,
      setting: RoomSetting(gameArea: gameArea),
      users: [
        const RoomUser(id: myUid, displayName: 'わたし', role: UserRole.demon),
        if (hasFugitive) const RoomUser(id: 'u1', displayName: 'ゆい'),
      ],
    );
  }

  /// エリアの中心から少し離れた位置。`outside`を真にすると北へ大きく外す
  /// (猶予距離15mを確実に超える)。
  ///
  /// `updatedAt`は**読むたびに今のサーバー時刻**にする。位置送信は4秒ごとに
  /// 動き続けているので実機ではこれが自然な姿だし、`applyOutsideAreaHysteresis`
  /// は「猶予を始めた測位より新しいものが届いているか」も条件にしている
  /// (GPSが固まった端末で警告を出し続けないため)ので、止めると永久に警告に
  /// ならない。
  UserLocation locationAt({required bool outside}) {
    return UserLocation(
      uid: myUid,
      latitude: outside ? 35.004 : 35.001,
      longitude: 135.001,
      accuracy: 5,
      updatedAt: clock.now().millisecondsSinceEpoch,
    );
  }

  /// テスト用の器。[elapsedMillis]で単調増加の時計を差し替える。
  ProviderContainer containerWith({
    required Room? room,
    required UserLocation? Function() location,
    required int Function() elapsedMillis,
    Stream<int>? offset,
  }) {
    final container = ProviderContainer(
      overrides: [
        myUidProvider.overrideWithValue(myUid),
        serverTimeOffsetProvider.overrideWith(
          (ref) => offset ?? Stream.value(0),
        ),
        roomStreamProvider(roomId).overrideWith(
          (ref) =>
              room == null ? const Stream<Room>.empty() : Stream.value(room),
        ),
        locationViewModelProvider.overrideWith(
          () => _StubLocationViewModel(location),
        ),
        gameAlertsProvider.overrideWith(
          () => GameAlerts(elapsedMillis: elapsedMillis),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 端末時刻を基準にしたサーバー時刻との差。
  /// `serverNowMillis(0)` は `DateTime.now()` なので、テストの「過ぎた/
  /// まだ」は現在時刻からの相対で作る。
  int msFromNow(Duration d) =>
      DateTime.now().millisecondsSinceEpoch + d.inMilliseconds;

  group('鬼放出', () {
    test('放出の時刻を過ぎたら、画面が無くても振動と通知が出る', () {
      fakeAsync((async) {
        final container = containerWith(
          // 3秒後に放出。
          room: roomWith(releasedAt: msFromNow(const Duration(seconds: 3))),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);
        async.flushMicrotasks();

        // まだ放出前。
        async.elapse(const Duration(seconds: 1));
        expect(notificationCalls, isEmpty);

        // 1秒ごとのタイマーだけで判定が進む(pumpもフレームも無い)。
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(notificationCalls, contains('show'));
      });
    });

    test('放出後に何秒経っても、通知は一度きり', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(releasedAt: msFromNow(const Duration(seconds: -1))),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);
        async
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();

        expect(notificationCalls.where((c) => c == 'show'), hasLength(1));
      });
    });
  });

  group('ゲーム終了', () {
    test('終了の時刻を過ぎたら通知が出て、isGameOverが立つ', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(endsAt: msFromNow(const Duration(seconds: 3))),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);
        async.flushMicrotasks();
        expect(container.read(gameAlertsProvider).isGameOver, isFalse);

        async
          ..elapse(const Duration(seconds: 5))
          ..flushMicrotasks();

        expect(container.read(gameAlertsProvider).isGameOver, isTrue);
        expect(notificationCalls, contains('show'));
      });
    });

    test('終了後も通知は一度きり', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(status: RoomStatus.finished),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);
        async
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();

        expect(notificationCalls.where((c) => c == 'show'), hasLength(1));
      });
    });
  });

  group('エリア外', () {
    test('猶予時間が経つと警告に切り替わり、振動と通知が始まる', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(gameArea: area),
          location: () => locationAt(outside: true),
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);

        // 猶予時間(10秒)の手前ではまだ警告しない。
        async
          ..elapse(const Duration(seconds: 5))
          ..flushMicrotasks();
        expect(
          container.read(gameAlertsProvider).isOutsideAreaWarning,
          isFalse,
        );

        async
          ..elapse(const Duration(seconds: 8))
          ..flushMicrotasks();
        expect(container.read(gameAlertsProvider).isOutsideAreaWarning, isTrue);
        expect(notificationCalls, contains('show'));
      });
    });

    test('警告中も、振動の間隔ごとに通知を出し直す', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(gameArea: area),
          location: () => locationAt(outside: true),
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);
        async
          ..elapse(const Duration(seconds: 13))
          ..flushMicrotasks();
        final afterFirst = notificationCalls.where((c) => c == 'show').length;

        // Android 14以降はongoingの通知もスワイプで消せるので、消されたまま
        // 振動だけが続かないよう出し直す。
        async
          ..elapse(outsideAreaVibrationInterval * 2)
          ..flushMicrotasks();

        expect(
          notificationCalls.where((c) => c == 'show').length,
          greaterThan(afterFirst),
        );
      });
    });

    test('エリア内に戻ると、警告が解除されて通知も消える', () {
      fakeAsync((async) {
        // 途中でエリア内へ戻す。
        var isOutside = true;
        final container = containerWith(
          room: roomWith(gameArea: area),
          location: () => locationAt(outside: isOutside),
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );

        container.read(gameAlertsProvider.notifier).start(roomId);
        async
          ..elapse(const Duration(seconds: 13))
          ..flushMicrotasks();
        expect(container.read(gameAlertsProvider).isOutsideAreaWarning, isTrue);

        // 画面を消したままエリア内へ戻る。以前はここで解除されず、振動だけが
        // 続いていた(issue #71)。
        isOutside = false;
        notificationCalls.clear();
        async
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();

        expect(
          container.read(gameAlertsProvider).isOutsideAreaWarning,
          isFalse,
        );
        expect(notificationCalls, contains('cancel'));
      });
    });

    test('エリア未設定のルームでは、いつまで経っても警告しない', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(),
          location: () => locationAt(outside: true),
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);
        async
          ..elapse(const Duration(minutes: 2))
          ..flushMicrotasks();

        expect(
          container.read(gameAlertsProvider).isOutsideAreaWarning,
          isFalse,
        );
      });
    });
  });

  group('サーバー時刻のオフセット', () {
    test('オフセットが届くまでは、時刻で発火する判定を保留する', () {
      fakeAsync((async) {
        // 端末の時計が5分進んでいて、サーバー時刻では放出が3分後、という状況。
        // 放出時刻は「端末時刻の2分前」に置く(サーバー時刻の3分後 =
        // 端末時刻 - 5分 + 3分)。オフセットを0とみなして端末時刻で判定する
        // 旧実装だと、これを「もう過ぎた」と誤認して即座に鳴らしてしまう
        // (+3分にしていた頃は旧実装でも鳴らず、テストが何も見ていなかった。
        // PR #91のレビュー指摘)。しかも一度きりの通知はフラグで畳むので、
        // 正しいオフセットが届いても取り返せない。
        final controller = StreamController<int>();
        addTearDown(controller.close);
        final container = containerWith(
          room: roomWith(releasedAt: msFromNow(const Duration(minutes: -2))),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
          offset: controller.stream,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);

        // オフセットが無い間は、時刻を見る判定を一切しない。
        async
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();
        expect(notificationCalls, isEmpty);

        // 正しいオフセット(端末が5分進んでいる= -5分)が届く。サーバー時刻では
        // 放出はまだ約3分先なので、ここでも鳴らない。
        controller.add(-const Duration(minutes: 5).inMilliseconds);
        async
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();
        expect(notificationCalls, isEmpty);

        // 3分経つと、サーバー時刻で放出時刻を過ぎるので鳴る。
        // 「保留しているだけで、届いた後は時刻どおりに動く」まで見る。
        async
          ..elapse(const Duration(minutes: 3))
          ..flushMicrotasks();
        expect(notificationCalls, contains('show'));
      });
    });

    test('オフセットが届いた後は、通常どおり判定する', () {
      fakeAsync((async) {
        final controller = StreamController<int>();
        addTearDown(controller.close);
        final container = containerWith(
          room: roomWith(releasedAt: msFromNow(const Duration(seconds: 3))),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
          offset: controller.stream,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);

        controller.add(0);
        async
          ..elapse(const Duration(seconds: 5))
          ..flushMicrotasks();

        expect(notificationCalls, contains('show'));
      });
    });
  });

  group('ゲームが終わった後', () {
    test('エリア外の振動と通知が止まる(画面が消えていてもポケットで鳴り続けない)', () {
      fakeAsync((async) {
        // エリアの外にいる状態で、20秒後にゲームが終わる部屋。猶予(10秒)を
        // 過ぎて警告に入ったあと、終了時刻をまたぐ流れをそのまま再現する。
        final container = containerWith(
          room: roomWith(
            gameArea: area,
            endsAt: msFromNow(const Duration(seconds: 20)),
          ),
          location: () => locationAt(outside: true),
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);

        // まずエリア外の警告に入る。
        async
          ..elapse(const Duration(seconds: 13))
          ..flushMicrotasks();
        expect(container.read(gameAlertsProvider).isOutsideAreaWarning, isTrue);

        // ここでゲームが終わる。画面が消えていると結果画面への遷移が起きず、
        // 遷移に紐づく stop() も走らないので、ここで止められないと振動と
        // 通知がポケットの中で鳴り続ける(PR #91のレビュー指摘)。
        notificationCalls.clear();
        async
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        expect(container.read(gameAlertsProvider).isGameOver, isTrue);
        expect(
          container.read(gameAlertsProvider).isOutsideAreaWarning,
          isFalse,
        );
        expect(notificationCalls, contains('cancel'));

        // 以後は何分経っても鳴らない(判定のタイマーごと畳んでいる)。
        notificationCalls.clear();
        async
          ..elapse(const Duration(minutes: 1))
          ..flushMicrotasks();
        expect(notificationCalls, isEmpty);
      });
    });

    test('終了後に入り直しても、鬼放出の通知は鳴らさない', () {
      fakeAsync((async) {
        // 終わった部屋に入り直したとき、過ぎた放出時刻を見て「鬼が放出され
        // ました」と鳴らすのは嘘になる。終了の判定を先に済ませて打ち切る。
        final container = containerWith(
          room: roomWith(
            status: RoomStatus.finished,
            releasedAt: msFromNow(const Duration(seconds: -60)),
          ),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        container.read(gameAlertsProvider.notifier).start(roomId);
        async
          ..elapse(const Duration(seconds: 5))
          ..flushMicrotasks();

        // 出るのは終了の通知1件だけ。
        expect(notificationCalls.where((c) => c == 'show'), hasLength(1));
        expect(container.read(gameAlertsProvider).isGameOver, isTrue);
      });
    });
  });

  group('ウィジェットのライフサイクルから呼んでも安全', () {
    testWidgets('ビルド中にstart/stopしても「ビルド中にproviderを変更した」にならない', (
      tester,
    ) async {
      // [start]を呼ぶ`useGameSession`のuseEffectは**ビルド中に同期実行される**。
      // そこで`state`を書くとRiverpodが
      // 「Tried to modify a provider while the widget tree was building」を
      // 投げ、ゲーム画面がまったく開けなくなる(実機で発生)。
      //
      // 既に終了している部屋を渡して、初回の判定で必ず`state`が変わる状況に
      // する。逃がし忘れるとここで落ちる。
      // ProviderScopeは本番(main.dart)と同じく出しっぱなしにして、中身だけを
      // 差し替える。スコープごと外すと、後始末の`ref.read`が
      // 「widgetがunmountされる最中にrefを使った」で別の例外になってしまう。
      Widget scopeWith(Widget child) => ProviderScope(
        overrides: [
          myUidProvider.overrideWithValue(myUid),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          roomStreamProvider(roomId).overrideWith(
            (ref) => Stream.value(roomWith(status: RoomStatus.finished)),
          ),
          locationViewModelProvider.overrideWith(
            () => _StubLocationViewModel(() => null),
          ),
        ],
        child: MaterialApp(home: child),
      );

      await tester.pumpWidget(scopeWith(const _StartsGameAlerts()));
      expect(tester.takeException(), isNull);

      // 初回の判定(ビルドの外へ逃がしたぶん)が走る。
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('終了'), findsOneWidget);

      // 離脱(useEffectの後始末)も同じライフサイクルの中で起きる。
      await tester.pumpWidget(scopeWith(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('開始と停止', () {
    test('start→stop→start が同じ部屋で連続しても、古い遅延処理が状態を壊さない', () {
      fakeAsync((async) {
        // ビルドの外へ逃がした処理は、予約した順に後から実行される。
        // 1回目のstart()の遅延処理が「同じ部屋だから」とガードを通過して
        // 終了を検知し、続く2回目のstart()の遅延処理がstateを初期値へ戻すと、
        // _notifiedGameOverは立ったまま isGameOver だけ false に固まって、
        // 結果画面へ遷移できなくなる(PR #91のレビュー指摘)。
        final container = containerWith(
          room: roomWith(status: RoomStatus.finished),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        final notifier = container.read(gameAlertsProvider.notifier)
          ..start(roomId)
          ..stop()
          ..start(roomId);
        async
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();

        expect(container.read(gameAlertsProvider).isGameOver, isTrue);
        // 通知も1回だけ。
        expect(notificationCalls.where((c) => c == 'show'), hasLength(1));

        // 念のため、いま生きているstart()の世代で止めれば畳める。
        notifier.stop();
        async.elapse(Duration.zero);
        expect(container.read(gameAlertsProvider), initialGameAlertsState);
      });
    });

    test('stop()で判定も振動も止まり、通知を消す', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(gameArea: area),
          location: () => locationAt(outside: true),
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        final notifier = container.read(gameAlertsProvider.notifier)
          ..start(roomId);
        async
          ..elapse(const Duration(seconds: 13))
          ..flushMicrotasks();
        expect(container.read(gameAlertsProvider).isOutsideAreaWarning, isTrue);

        notifier.stop();
        // 通知の取り消しはすぐ出るが、**状態のリセットは1回ぶん遅れる**。
        // 離脱はウィジェットのライフサイクル(useEffectの後始末)の中で起きる
        // ため、ビルド中にproviderを書き換えないようビルドの外へ逃がして
        // いる(Riverpodが例外を投げる)。
        async.flushMicrotasks();
        expect(notificationCalls, contains('cancel'));

        async.elapse(Duration.zero);
        expect(container.read(gameAlertsProvider), initialGameAlertsState);

        // 以後は何秒経っても何も起きない(タイマーが残っていない)。
        notificationCalls.clear();
        async
          ..elapse(const Duration(minutes: 1))
          ..flushMicrotasks();
        expect(notificationCalls, isEmpty);
      });
    });

    test('部屋を変えて開始し直すと、前の試合の「通知済み」を持ち越さない', () {
      fakeAsync((async) {
        final container = containerWith(
          room: roomWith(releasedAt: msFromNow(const Duration(seconds: -1))),
          location: () => null,
          elapsedMillis: () => async.elapsed.inMilliseconds,
        );
        final notifier = container.read(gameAlertsProvider.notifier)
          ..start(roomId);
        async
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();
        expect(notificationCalls.where((c) => c == 'show'), hasLength(1));

        // 同じ部屋でもう一度始める(「同じメンバーでもう一回」の巻き戻し)。
        notificationCalls.clear();
        notifier.start(roomId);
        async
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();

        expect(notificationCalls.where((c) => c == 'show'), hasLength(1));
      });
    });
  });
}

/// 位置情報のproviderを差し替えるスタブ。
///
/// 本物は`start()`でFirebaseとForeground Serviceに触るので、テストからは
/// 状態だけを持つものに差し替える。
///
/// **1秒ごとに状態を流し直す**のがポイント。実機では位置送信が4秒ごとに
/// 動いていて`updatedAt`が進み続けるが、テストで固定値を1回返すだけだと
/// `applyOutsideAreaHysteresis`の「猶予を始めた測位より新しいものが届いて
/// いるか」(GPSが固まった端末で警告を出し続けないための条件)が永久に
/// 満たされず、猶予時間をいくら進めても警告にならない。
class _StubLocationViewModel extends LocationViewModel {
  _StubLocationViewModel(this._read);

  /// 「いまの測位」を返す。テスト側が中身を差し替えられるよう遅延評価。
  final UserLocation? Function() _read;

  @override
  LocationState build() {
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = _current(),
    );
    ref.onDispose(timer.cancel);
    return _current();
  }

  LocationState _current() {
    final location = _read();
    return LocationState(locations: location == null ? const [] : [location]);
  }
}

/// GamePage(`useGameSession`)と同じ形で[GameAlerts]を開始・停止し、結果を
/// `ref.watch`するだけのウィジェット。
class _StartsGameAlerts extends HookConsumerWidget {
  const _StartsGameAlerts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      // 後始末で`ref.read`を呼ばない。widgetのunmount中にrefへ触るのは
      // hooks_riverpodでは不正(「Using "ref" when a widget is about to or
      // has been unmounted is unsafe」)なので、生きているうちに掴んでおく。
      final alerts = ref.read(gameAlertsProvider.notifier);
      alerts.start('room1');
      return alerts.stop;
    }, const []);
    final alerts = ref.watch(gameAlertsProvider);
    return Text(alerts.isGameOver ? '終了' : '進行中');
  }
}
