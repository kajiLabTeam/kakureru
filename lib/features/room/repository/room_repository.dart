import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/room_join_error.dart';

/// ルームの作成・参加・監視といったRTDB操作をまとめたリポジトリ。
class RoomRepository {
  /// 引数を省略すると実際のFirebase(`FirebaseDatabase.instance` /
  /// `FirebaseAuth.instance`)を使う。テストからのみ差し替える。
  RoomRepository({FirebaseDatabase? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  final FirebaseDatabase? _dbOverride;
  final FirebaseAuth? _authOverride;

  // `.instance` の解決を初期化子リストではなくlateの遅延初期化にしている
  // のは、メソッドを丸ごとoverrideするテスト用のサブクラスが、暗黙の
  // `super()` を通るだけでFirebase未初期化の例外(`[core/no-app]`)を
  // 踏まないようにするため(FirebaseDatabase/FirebaseAuthはコンストラクタ
  // が非公開でテストダブルを渡せないので、サブクラスで差し替えるしかない)。
  // 引数を渡さなければ`.instance`を使う、という外から見た振る舞いは
  // 解決のタイミングが遅くなるだけで変わらない。
  late final FirebaseDatabase _db = _dbOverride ?? FirebaseDatabase.instance;
  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;

  final _random = Random();

  String get _uid => _auth.currentUser!.uid;

  /// ルームを作成して roomId を返す
  Future<String> createRoom({
    required String displayName,
    required String deviceId,
    RoomSetting setting = const RoomSetting(),
  }) async {
    final roomId = _db.ref('rooms').push().key!;
    debugPrint('[createRoom] start roomId=$roomId uid=$_uid');

    debugPrint('[createRoom] step1 roomCodes予約 開始');
    final code = await _reserveRoomCode(roomId);
    debugPrint('[createRoom] step1 roomCodes予約 完了 code=$code');

    try {
      debugPrint('[createRoom] step2 rooms/$roomId/meta set 開始');
      await _db.ref('rooms/$roomId/meta').set({
        'status': RoomStatus.waiting.raw,
        'hostUserId': _uid,
        'roomCode': code,
        'createdAt': ServerValue.timestamp,
      });
      debugPrint('[createRoom] step2 meta set 完了');

      debugPrint('[createRoom] step3 rooms/$roomId/setting set 開始');
      await _db.ref('rooms/$roomId/setting').set(setting.toMap());
      debugPrint('[createRoom] step3 setting set 完了');

      debugPrint('[createRoom] step4 rooms/$roomId/users/$_uid set 開始');
      await _db.ref('rooms/$roomId/users/$_uid').set({
        'displayName': displayName,
        'deviceId': deviceId,
        'isHost': true,
        'role': 'FUGITIVE',
        'joinedAt': ServerValue.timestamp,
      });
      debugPrint('[createRoom] step4 users set 完了');
    } catch (e) {
      if (e is FirebaseException) {
        debugPrint('[createRoom] 失敗: code=${e.code} message=${e.message}');
      } else {
        debugPrint('[createRoom] 失敗(非FirebaseException): $e');
      }
      await _rollbackRoom(roomId, code);
      rethrow;
    }

    debugPrint('[createRoom] 全ステップ成功 roomId=$roomId');
    return roomId;
  }

  /// createRoom 失敗時に、途中まで書き込んだ内容を可能な範囲で取り消す。
  Future<void> _rollbackRoom(String roomId, String code) async {
    try {
      await _db.ref('roomCodes/$code').remove();
    } on FirebaseException catch (_) {}
    try {
      await _db.ref('rooms/$roomId/users/$_uid').remove();
    } on FirebaseException catch (_) {}
    try {
      await _db.ref('rooms/$roomId/setting').remove();
    } on FirebaseException catch (_) {}
    try {
      await _db.ref('rooms/$roomId/meta').remove();
    } on FirebaseException catch (_) {}
  }

  /// 未使用の4桁コードをトランザクションで予約する
  Future<String> _reserveRoomCode(String roomId) async {
    for (var i = 0; i < 10; i++) {
      final code = (1000 + _random.nextInt(9000)).toString();
      debugPrint('[_reserveRoomCode] roomCodes/$code へrunTransaction試行 ($i回目)');
      try {
        final result = await _db.ref('roomCodes/$code').runTransaction((
          current,
        ) {
          if (current != null) return Transaction.abort();
          return Transaction.success({'roomId': roomId});
        });
        debugPrint(
          '[_reserveRoomCode] roomCodes/$code committed=${result.committed}',
        );
        if (result.committed) return code;
      } on FirebaseException catch (e) {
        debugPrint(
          '[_reserveRoomCode] roomCodes/$code 失敗: code=${e.code} message=${e.message}',
        );
        rethrow;
      }
    }
    throw Exception('ルームコードの発行に失敗しました');
  }

  /// ルームを終了状態にする(解散)。
  Future<void> finishRoom(String roomId) async {
    await _db.ref('rooms/$roomId/meta').update({
      'status': RoomStatus.finished.raw,
      'endedAt': ServerValue.timestamp,
    });
  }

  /// ホストがゲームを開始する。
  Future<void> startGame(String roomId) async {
    await _db.ref('rooms/$roomId/meta/startedAt').set(ServerValue.timestamp);

    final startedAtSnapshot = await _db
        .ref('rooms/$roomId/meta/startedAt')
        .get();
    final startedAt = startedAtSnapshot.value as int;

    final settingSnapshot = await _db.ref('rooms/$roomId/setting').get();
    final setting = RoomSetting.fromMap(
      settingSnapshot.value as Map<dynamic, dynamic>? ?? {},
    );

    await _db.ref('rooms/$roomId/meta').update({
      'status': RoomStatus.playing.raw,
      'releasedAt': startedAt + setting.releaseWaitSec * 1000,
      'endsAt': startedAt + setting.gameDurationSec * 1000,
    });
  }

  /// 「同じメンバーでもう一回」でルームを待機状態に巻き戻す(issue #44)。
  /// ゲーム進行に関するmetaフィールドをまとめてクリアしてstatusを
  /// WAITINGへ戻す。プレイエリア設定(`setting`)・各参加者の気圧
  /// キャリブレーション値(`pressureOffset`/`pressureSensorAvailable`)・
  /// 参加者そのものは書き換えない(保持する)。
  ///
  /// `rooms/{roomId}` 直下でmetaとusersをまたいで一括更新することは
  /// できない(docs/rtdb-schema.md「一括書き込み・一括読み取りが使えない
  /// 理由」参照)ため、ここでは単一のref(`meta`)への1回の`update`で
  /// 原子的に書く(`startGame`と同じ書き方)。各参加者のroleを
  /// FUGITIVEに戻す処理は[resetOwnRoleForRestart]を参照。
  Future<void> restartRoom(String roomId) async {
    await _db.ref('rooms/$roomId/meta').update({
      'status': RoomStatus.waiting.raw,
      'startedAt': null,
      'releasedAt': null,
      'endsAt': null,
      'endedAt': null,
      'pendingDemonUid': null,
      'demonRevokeUid': null,
    });
  }

  /// [restartRoom]による巻き戻し後、自分自身の役割を逃走者に戻す。
  ///
  /// `users/{uid}` は本人(`auth.uid === $uid`)以外は書き込めないルールの
  /// ため、ホストが他の参加者のroleをまとめて書き換えることはできない
  /// (鬼の決定が`meta/pendingDemonUid`経由の自己申告方式になっているのと
  /// 同じ制約)。そのため、巻き戻り(status==WAITINGへの変化)を検知した
  /// 各端末が、自分が鬼だった場合にだけこれを呼ぶ形にしている。
  Future<void> resetOwnRoleForRestart(String roomId) async {
    await _db.ref('rooms/$roomId/users/$_uid').update({
      'role': 'FUGITIVE',
      'becameDemonAt': null,
    });
  }

  /// ルーム設定画面から呼ばれる。ルール上は誰でも書ける状態のままなので
  /// (docs/rtdb-schema.md「ルーム設定画面」参照)、host以外が呼ばないよう
  /// 画面側(RoomWaitingPage/RoomSettingPage)でホスト限定のガードをかけている。
  Future<void> updateSetting(String roomId, RoomSetting setting) async {
    await _db.ref('rooms/$roomId/setting').set(setting.toMap());
  }

  /// ホストが鬼にする人を指名する(meta/pendingDemonUid経由の自己申告方式。
  Future<void> nominateDemon(String roomId, String uid) async {
    await _db.ref('rooms/$roomId/meta/pendingDemonUid').set(uid);
  }

  /// 指名を取り消す。対象者がまだ受諾(自己申告)していない間だけ意味を持つ
  /// (対象者側が既に受諾済みならroleが変わっているため、これは無効化にしかならない)。
  Future<void> cancelDemonNomination(String roomId) async {
    await _db.ref('rooms/$roomId/meta/pendingDemonUid').set(null);
  }

  /// 指名された本人が、指名を受諾して自分のroleをDEMONに更新する。
  ///
  /// `pendingDemonUid`の確認とroleの書き込みが素の読み取り→書き込みだと、
  /// ホストの[cancelDemonNomination](同じく素の`set(null)`)とレースする:
  /// 本人がここに入った直後にホストが取り消すと、取り消しは反映されても
  /// roleがDEMONのまま取り残されてしまう。`meta/pendingDemonUid`への
  /// [DatabaseReference.runTransaction]で「読んだ時点の値が依然`uid`のとき
  /// だけ`null`に書き換える」を原子的に行い、それが成立したとき(=取り消しに
  /// 割り込まれていない)だけroleを書くことでこれを防ぐ。
  Future<void> acceptDemonNomination(String roomId, String uid) async {
    final result = await _db
        .ref('rooms/$roomId/meta/pendingDemonUid')
        .runTransaction((currentData) {
          if (currentData == uid) {
            return Transaction.success(null);
          }
          return Transaction.abort();
        });
    if (!result.committed) {
      // ホストが取り消した、または別の人を指名し直した後だったため、
      // 受諾を反映しない。
      return;
    }
    await _db.ref('rooms/$roomId/users/$uid/role').set('DEMON');
  }

  /// ホストが、既に鬼になっている人を逃走者に戻す(指名の取り消し)。
  /// `users/{uid}` は本人以外書き込み不可のため、鬼の決定と同じ自己申告
  /// 方式(meta/demonRevokeUidに対象uidを書き、本人が[acceptDemonRevoke]で
  /// 自分のroleを書き戻す)を使う。
  Future<void> revokeDemon(String roomId, String uid) async {
    await _db.ref('rooms/$roomId/meta/demonRevokeUid').set(uid);
  }

  /// 鬼の取り消しを本人が受諾し、自分のroleをFUGITIVEに書き戻す。
  Future<void> acceptDemonRevoke(String roomId, String uid) async {
    await _db.ref('rooms/$roomId/users/$uid').update({
      'role': 'FUGITIVE',
      'becameDemonAt': null,
    });
    await _db.ref('rooms/$roomId/meta/demonRevokeUid').set(null);
  }

  /// 逃走者が「捕まった」ことを自己申告する。
  Future<void> reportCaught(String roomId) async {
    final uid = _uid;
    await _db.ref('rooms/$roomId/users/$uid/role').set('DEMON');
    await _db
        .ref('rooms/$roomId/users/$uid/becameDemonAt')
        .set(ServerValue.timestamp);

    final catchId = _db.ref('rooms/$roomId/catches').push().key!;
    await _db.ref('rooms/$roomId/catches/$catchId').set({
      'demonUserId': null,
      'fugitiveUserId': uid,
      'caughtAt': ServerValue.timestamp,
    });
  }

  /// コードからルームに参加する。
  ///
  /// 終了したルームもその`roomCodes/{code}`も削除されない運用のため、
  /// コードが引けただけでは参加させず、`meta`を読んで次の3つを確認する
  /// (終了済みのルームに入ると待機画面や結果画面で行き止まりになるため)。
  ///
  /// 1. `meta`が存在すること。`rooms`だけをコンソールで削除した後や、
  ///    [createRoom]が`meta`の書き込み前に失敗して[_rollbackRoom]でも
  ///    `roomCodes/{code}`を消せなかった(ルール上、`meta/hostUserId`が
  ///    無いと消せない)後には、行き先の無いコードだけが残る
  /// 2. `status`が[RoomStatus.finished]でないこと
  /// 3. `endsAt`(ゲーム終了時刻)を過ぎていないこと。**現状こちらが本命**で、
  ///    `status`を`FINISHED`にする[finishRoom]はまだ呼ばれておらず、遊び
  ///    終えたルームは`PLAYING`のまま`endsAt`だけが過去になる。「先週の
  ///    コードを打つと終わった部屋に入ってしまう」のはこの状態
  ///
  /// まだ終わっていない進行中([RoomStatus.playing])のルームへの途中参加は
  /// 従来どおり許可する。失敗理由は[RoomJoinError]で投げる(画面側で日本語に
  /// 変換する)。
  Future<String> joinRoom({
    required String code,
    required String displayName,
    required String deviceId,
  }) async {
    final snapshot = await _db.ref('roomCodes/$code').get();
    if (!snapshot.exists) throw RoomJoinError.notFound;

    final roomId = (snapshot.value as Map)['roomId'] as String;

    final metaSnapshot = await _db.ref('rooms/$roomId/meta').get();
    final meta = metaSnapshot.value as Map<dynamic, dynamic>?;
    if (meta == null) throw RoomJoinError.notFound;

    if (RoomStatus.fromRaw(meta['status']?.toString()) == RoomStatus.finished) {
      throw RoomJoinError.finished;
    }

    final endsAt = (meta['endsAt'] as num?)?.toInt();
    if (endsAt != null && await _serverNowMillis() >= endsAt) {
      throw RoomJoinError.finished;
    }

    await _db.ref('rooms/$roomId/users/$_uid').set({
      'displayName': displayName,
      'deviceId': deviceId,
      'isHost': false,
      'role': 'FUGITIVE',
      'joinedAt': ServerValue.timestamp,
    });

    return roomId;
  }

  /// 現在のサーバー時刻(エポックミリ秒)。
  ///
  /// `.info/serverTimeOffset`はSDKがローカルに持つ値なので、購読すれば
  /// すぐに届く。それでも届かない場合に参加そのものを止めてしまわないよう、
  /// 短いタイムアウトでオフセット0(=端末時計)にフォールバックする。
  Future<int> _serverNowMillis() async {
    final offset = await _db
        .ref('.info/serverTimeOffset')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0)
        .first
        .timeout(const Duration(seconds: 3), onTimeout: () => 0);
    return serverNowMillis(offset);
  }

  /// ルームの状態をリアルタイムで監視する
  Stream<Room> watchRoom(String roomId) {
    final controller = StreamController<Room>.broadcast();

    Map<dynamic, dynamic>? metaValue;
    Map<dynamic, dynamic>? settingValue;
    Map<dynamic, dynamic>? usersValue;
    var hasMeta = false;
    var hasSetting = false;
    var hasUsers = false;

    void emitIfReady() {
      if (!hasMeta || !hasSetting || !hasUsers) return;
      if (metaValue == null) {
        controller.addError(Exception('ルームが存在しません'));
        return;
      }
      controller.add(
        Room.fromMap(roomId, {
          'meta': metaValue,
          'setting': settingValue,
          'users': usersValue,
        }),
      );
    }

    final metaSub = _db.ref('rooms/$roomId/meta').onValue.listen((event) {
      metaValue = event.snapshot.value as Map<dynamic, dynamic>?;
      hasMeta = true;
      emitIfReady();
    });
    final settingSub = _db.ref('rooms/$roomId/setting').onValue.listen((event) {
      settingValue = event.snapshot.value as Map<dynamic, dynamic>?;
      hasSetting = true;
      emitIfReady();
    });
    final usersSub = _db.ref('rooms/$roomId/users').onValue.listen((event) {
      usersValue = event.snapshot.value as Map<dynamic, dynamic>?;
      hasUsers = true;
      emitIfReady();
    });

    controller.onCancel = () async {
      await metaSub.cancel();
      await settingSub.cancel();
      await usersSub.cancel();
    };

    return controller.stream;
  }

  /// ルームから退出する。RoomWaitingPage/GamePageの`PopScope`から、
  /// 戻る操作(ハードウェア/AppBarの戻るボタン)で画面を離れたときに呼ばれる。
  ///
  /// users/{uid} を消すだけでは locations/{uid} が残り、他の参加者の
  /// 地図に離脱後もピンが残り続けてしまうため、自分の位置情報も合わせて
  /// 消す(docs/rtdb-schema.md上、locations/{uid} は本人のみ書き込み可)。
  ///
  /// **既知の制約**: 戻る操作による明示的な離脱しか検知できない。アプリの
  /// 強制終了・クラッシュ・OSによるプロセスkillではこのメソッドが呼ばれず、
  /// users/{uid}・locations/{uid}はRTDB上に残り続ける。厳密に検知するには
  /// RTDBのonDisconnect()(presence機構)への移行が必要だが、Phase 1では
  /// スコープ外としている。また、users削除の後にlocations削除を行う2段階の
  /// 処理のため、ネットワーク瞬断等で後者だけ失敗すると、離脱通知(users基準)
  /// は正しく出る一方で地図上の位置ピンだけ残る可能性がある。
  Future<void> leaveRoom(String roomId) async {
    await _db.ref('rooms/$roomId/users/$_uid').remove();
    await _db.ref('rooms/$roomId/locations/$_uid').remove();
  }
}
