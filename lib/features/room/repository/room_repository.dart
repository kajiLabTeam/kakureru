import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/catch_rules.dart';
import 'package:kakureru/features/room/model/catch_photo.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_catch.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/repository/event_log_repository.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/room_code_validation.dart';
import 'package:kakureru/features/room/room_create_error.dart';
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

  /// 分析用のイベントログ(fire-and-forget。失敗してもここへは投げ返さない)。
  late final EventLogRepository _eventLog = EventLogRepository(db: _dbOverride);

  final _random = Random();

  String get _uid => _auth.currentUser!.uid;

  /// ルームを作成して roomId を返す
  Future<String> createRoom({
    required String displayName,
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
      // setだとノード全体の置き換えになり、先に届いた他のフィールド
      // (気圧センサーの有無など)を消してしまうため、updateで書く。
      await _db.ref('rooms/$roomId/users/$_uid').update({
        'displayName': displayName,
        'isHost': true,
        'role': 'FUGITIVE',
        'joinedAt': ServerValue.timestamp,
        'online': true,
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
    throw RoomCreateError.codeExhausted;
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

    final schedule = computeGameSchedule(
      startedAt: startedAt,
      setting: setting,
    );
    await _db.ref('rooms/$roomId/meta').update({
      'status': RoomStatus.playing.raw,
      'releasedAt': schedule.releasedAt,
      'endsAt': schedule.endsAt,
    });
    unawaited(
      _eventLog.log(roomId, type: GameEventType.gameStarted, uid: _uid),
    );
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

  /// 待機画面の「テザリングで接続している」の自己申告を書く(issue #142)。
  ///
  /// ONの間、ゲーム中のWi-Fiスキャンが接続中のWi-Fi(=自分のホットスポット)の
  /// BSSIDを共有し、全員の手がかりの計算から除かれる。`restartRoom`は
  /// `users/`を書き換えないので、再戦しても値は残る。
  Future<void> setUsesTethering(String roomId, {required bool value}) async {
    await _db.ref('rooms/$roomId/users/$_uid').update({'usesTethering': value});
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
    unawaited(
      _eventLog.log(roomId, type: GameEventType.becameDemon, uid: uid),
    );
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

  /// 鬼が「捕まえた」を確定する(issue #140)。書いた catchId を返す。
  ///
  /// 捕まった逃走者の役割はここでは書き換えない(書けない)。`users/{uid}`は
  /// 本人しか書けないため、捕まった本人の端末が`catches`を見て
  /// [acceptCaught]で自分の役割を書き換える。
  Future<String> reportCatch(
    String roomId, {
    required String fugitiveUid,
  }) async {
    final catchId = _db.ref('rooms/$roomId/catches').push().key!;
    await _db.ref('rooms/$roomId/catches/$catchId').set({
      'demonUserId': _uid,
      'fugitiveUserId': fugitiveUid,
      'caughtAt': ServerValue.timestamp,
    });
    return catchId;
  }

  /// 捕まった本人が、自分の役割をDEMONに書き換える。
  ///
  /// 取り消しの期限([catchUndoWindow])を待たずにすぐ鬼にする。期限内に
  /// [undoCatch]されたら逃走者に戻す。
  Future<void> acceptCaught(String roomId) async {
    await _db.ref('rooms/$roomId/users/$_uid').update({
      'role': 'DEMON',
      'becameDemonAt': ServerValue.timestamp,
    });
  }

  /// 捕まった本人が、期限内に捕獲を取り消す。
  ///
  /// 期限の判定はサーバー時刻で行い、過ぎていれば[CatchUndoExpiredException]、
  /// サーバー時刻が取れなければ[CatchUndoUnavailableException]を投げて
  /// 何も書かない。画面側でも期限切れのボタンは押せなくしているが、
  /// ボタンを押してから書き込むまでの間に期限を越えることがあるため、
  /// ここでもう一度確かめる。
  ///
  /// **捕獲を先に消し、役割を後で戻す**。逆の順にすると、役割がFUGITIVEに
  /// 戻った瞬間にまだ残っている捕獲を本人の端末が見つけて、また鬼に
  /// なってしまう([catchToAcceptAsCaught])。
  ///
  /// 3つの書き込みは**サーバーの応答を待たずに続けて出す**。1つずつ待つと、
  /// 捕獲を消した後に通信が切れたりアプリが落ちたりしたとき、役割の書き戻しが
  /// 出されないまま「捕獲は無いのに鬼」で取り残される(`catchToAcceptAsCaught`
  /// は逃走者のときしか動かないので自動では戻らない)。続けて出せば3つとも
  /// 端末の書き込み待ち行列(オフライン永続化で保存される)に積まれ、出した順に
  /// 手元へ反映・サーバーへ送られるので、上の順序も保たれる。
  Future<void> undoCatch(String roomId, RoomCatch roomCatch) async {
    final now = await _serverNowMillis();
    if (now == null) throw const CatchUndoUnavailableException();
    if (!isCatchUndoable(caughtAt: roomCatch.caughtAt, nowMillis: now)) {
      throw const CatchUndoExpiredException();
    }
    final catchRef = _db.ref('rooms/$roomId/catches/${roomCatch.id}');
    // 鬼が写真を送った直後かもしれないので、手元の値ではなく最新を読む。
    final photoIdSnapshot = await _db
        .ref('rooms/$roomId/catches/${roomCatch.id}/catchPhotoId')
        .get();
    final photoId = photoIdSnapshot.value as String?;
    await Future.wait([
      catchRef.set(null),
      if (photoId != null)
        _db.ref('rooms/$roomId/catchPhotos/$photoId').set(null),
      _db.ref('rooms/$roomId/users/$_uid').update({
        'role': 'FUGITIVE',
        'becameDemonAt': null,
      }),
    ]);
    await _removeOrphanedCatchPhotos(roomId, roomCatch.id);
    unawaited(
      _eventLog.log(
        roomId,
        type: GameEventType.catchUndone,
        uid: _uid,
        targetUid: roomCatch.demonUserId,
      ),
    );
  }

  /// 取り消した捕獲[catchId]を指す`catchPhotos`を探して消す(issue #145)。
  ///
  /// [undoCatch]が`catchPhotoId`を読んでから捕獲を消すまでの間に
  /// [attachCatchPhoto]が確定すると、そこで書かれた写真は削除の対象に入らず
  /// 取り残される。捕獲の削除がサーバーに届いた後なら、それより前に確定した
  /// 写真は必ず読めるし、後から来た[attachCatchPhoto]は捕獲が無いのを見て
  /// 自分で写真を消す。なので、ここで一度探し直せば取りこぼしは無い。
  ///
  /// 取り消し自体は済んでいるので、失敗しても投げない(残るのは画面に出ない
  /// 小さなレコードだけで、画像本体はR2で7日後に消える)。ルールで消せるのは
  /// 自分が当事者の写真だけなので、`fugitiveUid`が自分のものに絞る。
  Future<void> _removeOrphanedCatchPhotos(String roomId, String catchId) async {
    try {
      final snapshot = await _db.ref('rooms/$roomId/catchPhotos').get();
      final photos = snapshot.value as Map<dynamic, dynamic>? ?? const {};
      await Future.wait([
        for (final entry in photos.entries)
          if (entry.value case {
            'catchId': final String id,
            'fugitiveUid': final String fugitiveUid,
          } when id == catchId && fugitiveUid == _uid)
            _db.ref('rooms/$roomId/catchPhotos/${entry.key}').set(null),
      ]);
    } on Object catch (e, st) {
      debugPrint('取り消した捕獲の写真を片付けられませんでした: $e\n$st');
    }
  }

  /// 捕まえた瞬間の写真のメタデータを書き、捕獲に写真IDを結びつける。
  ///
  /// 画像本体は先に`PhotoRepository.upload`でR2へ上げておくこと。
  /// 捕獲が既に取り消されていたら写真のメタデータも消して
  /// [CatchAlreadyUndoneException]を投げる。`catches/{catchId}/catchPhotoId`
  /// だけを書くと、取り消し後に`fugitiveUserId`も`caughtAt`も無い壊れた
  /// 捕獲ができてしまうため、存在を確かめながら書けるトランザクションを使う。
  Future<void> attachCatchPhoto(
    String roomId, {
    required String catchId,
    required String photoId,
    required String fugitiveUid,
  }) async {
    final photoRef = _db.ref('rooms/$roomId/catchPhotos/$photoId');
    await photoRef.set({
      'catchId': catchId,
      'demonUid': _uid,
      'fugitiveUid': fugitiveUid,
      'takenAt': ServerValue.timestamp,
    });
    final result = await _db
        .ref('rooms/$roomId/catches/$catchId')
        .runTransaction((current) {
          // 手元にキャッシュが無いと、最初はサーバーの値に関係なくnullで
          // 呼ばれる。ここでabortするとサーバーの値で再実行されずに終わり、
          // 取り消されていない捕獲を「取り消し済み」と誤判定してしまう。
          // nullのまま成功を返せば、サーバーに捕獲があれば実際の値で呼び直され、
          // 本当に無ければnullのまま確定する(下で存在を確かめる)。
          if (current == null) return Transaction.success(null);
          if (current is! Map) return Transaction.abort();
          return Transaction.success({...current, 'catchPhotoId': photoId});
        });
    if (!result.committed || result.snapshot.value == null) {
      await photoRef.set(null);
      throw const CatchAlreadyUndoneException();
    }
  }

  /// コードからルームに参加する。
  ///
  /// 終了したルームもその`roomCodes/{code}`も削除されない運用のため、
  /// コードが引けただけでは参加させず、次の2つを確認する
  /// (終了済みのルームに入ると待機画面や結果画面で行き止まりになるため)。
  ///
  /// 1. `meta`が存在すること。`rooms`だけをコンソールで削除した後や、
  ///    [createRoom]が`meta`の書き込み前に失敗して[_rollbackRoom]でも
  ///    `roomCodes/{code}`を消せなかった(ルール上、`meta/hostUserId`が
  ///    無いと消せない)後には、行き先の無いコードだけが残る
  /// 2. そのルームがまだ終わっていないこと。判定は画面側と同じ[isGameOver]
  ///    に任せる(終了条件をここで書き直すと、片方だけ条件が増えたときに
  ///    「画面では終わっているのに参加できる」ズレが生まれるため)
  ///
  /// 実際に効くのは`status`が`FINISHED`になる経路ではなく、残りの2つ。
  /// `status`を`FINISHED`にする[finishRoom]はまだ呼ばれておらず、遊び
  /// 終えたルームは`PLAYING`のまま`endsAt`が過去になるか、全員が捕まって
  /// 逃走者0人になるかのどちらかで終わる。
  ///
  /// まだ終わっていない進行中([RoomStatus.playing])のルームへの途中参加は
  /// 従来どおり許可する。失敗理由は[RoomJoinError]で投げる(画面側で日本語に
  /// 変換する)。
  ///
  /// 分かっている限界が2つある。
  /// - 読み取りと`users/{uid}`の書き込みの間に最後の逃走者が捕まると、
  ///   終了したルームに入れてしまう。`rooms/{roomId}`をまたぐ原子的な
  ///   読み書きはルール上できない(docs/rtdb-schema.md参照)ため、窓を
  ///   狭めることしかできない
  /// - サーバー時刻を取得できないときは、終わっているかを判定できないので
  ///   参加自体を止める([RoomJoinError.serverTimeUnavailable])。端末時計で
  ///   代用すると、時計が遅れている端末が終了済みルームに入れてしまう
  /// - デバッグ用の偽プレイヤー(`showDebugMockPlayersProvider`)を出して
  ///   1台で始めたルームは、RTDB上の逃走者が0人なので途中参加できない
  ///   (ゲーム画面側は偽プレイヤーを逃走者ありに倒しているが、参加時は
  ///   相手の端末の設定を知りようがないため)
  Future<String> joinRoom({
    required String code,
    required String displayName,
  }) async {
    // 画面(参加ボタンの活性)とViewModelでも弾いているが、このメソッドは
    // 公開APIなので、別の入口から直接呼ばれても`roomCodes/`の読み取り
    // (ルール上ここは読めず、生の権限エラーになる)まで進ませない。
    final normalizedCode = normalizeRoomCode(code);
    if (validateRoomCode(normalizedCode) != null) {
      throw RoomJoinError.invalidCode;
    }

    final snapshot = await _db.ref('roomCodes/$normalizedCode').get();
    if (!snapshot.exists) throw RoomJoinError.notFound;

    final roomId = (snapshot.value as Map)['roomId'] as String;

    final metaSnapshot = await _db.ref('rooms/$roomId/meta').get();
    final meta = metaSnapshot.value as Map<dynamic, dynamic>?;
    if (meta == null) throw RoomJoinError.notFound;

    final status = RoomStatus.fromRaw(meta['status']?.toString());
    // 逃走者の有無が終了判定に効くのはPLAYING中だけ([isGameOver]参照)なので、
    // そのときだけ`users`を追加で読む(待機中のルームでは無駄読みしない)。
    final hasFugitives =
        status != RoomStatus.playing || await _hasFugitives(roomId);

    // サーバー時刻が取れないまま端末時計で判定すると、時計が遅れている
    // 端末が`endsAt`を過ぎたルームに入れてしまう。判定できないときは
    // 参加させない(画面側で理由を出す)。
    final nowMillis = await _serverNowMillis();
    if (nowMillis == null) throw RoomJoinError.serverTimeUnavailable;

    if (isGameOver(
      status: status,
      endsAt: (meta['endsAt'] as num?)?.toInt(),
      nowMillis: nowMillis,
      hasFugitives: hasFugitives,
    )) {
      throw RoomJoinError.finished;
    }

    // 同じルームへ入り直したときに、前回のキャリブレーション値
    // (`pressureOffset`)や先に届いた`pressureSensorAvailable`を消さないよう、
    // setではなくupdateで書く。退出の印(`online: false`/`leftAt`)は戻す。
    await _db.ref('rooms/$roomId/users/$_uid').update({
      'displayName': displayName,
      'isHost': false,
      'role': 'FUGITIVE',
      'becameDemonAt': null,
      'joinedAt': ServerValue.timestamp,
      'online': true,
      'leftAt': null,
    });

    return roomId;
  }

  /// ルームに逃走者が1人でも残っているか。
  ///
  /// 全員が捕まって決着したルームは`status`が`PLAYING`のままで`endsAt`も
  /// まだ未来なので、この判定が無いと参加できてしまう。参加者は
  /// `role: FUGITIVE`で書き込まれるため、入れてしまうと全員の結果画面が
  /// 「逃げ切り1人」に反転する。
  ///
  /// 役割の読み取りは[RoomUser]に任せる(未設定や未知の値をFUGITIVE扱い
  /// にする既定を画面側と揃えるため)。誰も居ないルームは逃走者0人として
  /// 扱う。
  Future<bool> _hasFugitives(String roomId) async {
    final snapshot = await _db.ref('rooms/$roomId/users').get();
    final users = snapshot.value as Map<dynamic, dynamic>?;
    if (users == null) return false;
    for (final entry in users.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final user = RoomUser.fromMap(entry.key.toString(), raw);
      // 退出済みの人は数えない(以前は退出でノードごと消えていたため、
      // 数えないのが従来どおりの判定になる)。
      if (user.hasLeft) continue;
      if (user.role == UserRole.fugitive) return true;
    }
    return false;
  }

  /// 現在のサーバー時刻(エポックミリ秒)。
  /// サーバー時刻(エポックミリ秒)。オフセットを取得できなければnull。
  ///
  /// 端末時計へフォールバックしないのは[fetchServerTimeOffset]のdoc参照。
  Future<int?> _serverNowMillis() async {
    final offset = await fetchServerTimeOffset(_db);
    return offset == null ? null : serverNowMillis(offset);
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

  /// 写真一覧をリアルタイムで監視する(一覧画面用)。
  ///
  /// `watchRoom`と違い監視対象は`photos`サブツリー1つだけなので、
  /// 複数subtreeを揃えてから初回emitする仕組みは不要(単一のonValueで足りる)。
  /// 更新頻度・寿命がroomの他の情報と異なるため、あえて別の購読にしている。
  Stream<List<RoomPhoto>> watchPhotos(String roomId) {
    final controller = StreamController<List<RoomPhoto>>.broadcast();

    final sub = _db.ref('rooms/$roomId/photos').onValue.listen((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;
      if (value == null) {
        controller.add(const []);
        return;
      }
      controller.add([
        for (final entry in value.entries)
          RoomPhoto.fromMap(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          ),
      ]);
    });

    controller.onCancel = sub.cancel;

    return controller.stream;
  }

  /// 捕獲一覧をリアルタイムで監視する。
  Stream<List<RoomCatch>> watchCatches(String roomId) => _watchList(
    'rooms/$roomId/catches',
    RoomCatch.fromMap,
  );

  /// 捕まえた瞬間の写真のメタデータ一覧をリアルタイムで監視する。
  Stream<List<CatchPhoto>> watchCatchPhotos(String roomId) => _watchList(
    'rooms/$roomId/catchPhotos',
    CatchPhoto.fromMap,
  );

  /// `path`直下の子を[parse]で読み、一覧として流す([watchPhotos]と同じ形)。
  ///
  /// 読めない子(取り消しと写真の添付が行き違って一部だけ残ったもの等)は
  /// 飛ばす。1件壊れているだけで一覧全体が出なくなるのを避けるため。
  Stream<List<T>> _watchList<T>(
    String path,
    T Function(String id, Map<dynamic, dynamic> raw) parse,
  ) {
    final controller = StreamController<List<T>>.broadcast();
    final sub = _db.ref(path).onValue.listen((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;
      final items = <T>[];
      for (final entry in (value ?? const {}).entries) {
        try {
          items.add(
            parse(entry.key.toString(), entry.value as Map<dynamic, dynamic>),
          );
        } on Object catch (e) {
          debugPrint('[RoomRepository] $path/${entry.key}を読めません: $e');
        }
      }
      controller.add(items);
    }, onError: controller.addError);
    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  /// ルームから退出する。待機画面の破棄・結果画面の「ホームに戻る」/破棄・
  /// 購読エラー画面の「ホームに戻る」から呼ばれる。
  ///
  /// **`users/{uid}`・`locations/{uid}`は消さない**。以前はここで両方を
  /// `remove()`していたため、結果画面から帰った参加者のデータがRTDBから
  /// 消え、プレイテスト後の集計で「eventsには居るのにusersに居ない」
  /// 参加者が出た(roomCode 5189)。退出は`online: false`と`leftAt`で
  /// 印を付けるだけにし、画面側では[RoomUser.hasLeft]の人を参加者から
  /// 外す([Room.fromMap]参照)ことで、離脱通知や人数の数え方は従来どおりに
  /// 保つ。部屋の掃除はルーム単位で行う方針(docs/rtdb-schema.md参照)。
  ///
  /// `update`で書くので、ノードが無い(作成途中で失敗した等)ときに
  /// 呼んでも`online`/`leftAt`だけのノードができるが、[Room.fromMap]は
  /// 退出済みとして除外するため画面には出ない。
  ///
  /// **既知の制約**: 戻る操作による明示的な離脱しか検知できない。アプリの
  /// 強制終了・クラッシュ・OSによるプロセスkillではこのメソッドが呼ばれず、
  /// `online`は`true`のまま残る。
  Future<void> leaveRoom(String roomId) async {
    await _db.ref('rooms/$roomId/users/$_uid').update({
      'online': false,
      'leftAt': ServerValue.timestamp,
    });
  }
}

/// ゲーム開始時刻 [startedAt] と設定から、鬼放出と終了の時刻を決める。
///
/// 設定の「鬼ごっこの時間」(`gameDurationSec`)は**鬼放出後から**数える
/// (issue #119)。以前は開始から数えていたため、30分・放出待ち5分の設定だと
/// 放出後のカウントダウンが25分から始まり、「30分なのに25分しかない」と
/// 受け取られた。
({int releasedAt, int endsAt}) computeGameSchedule({
  required int startedAt,
  required RoomSetting setting,
}) {
  final releasedAt = startedAt + setting.releaseWaitSec * 1000;
  return (
    releasedAt: releasedAt,
    endsAt: releasedAt + setting.gameDurationSec * 1000,
  );
}

/// 取り消しの期限([catchUndoWindow])を過ぎていて、取り消せなかった。
class CatchUndoExpiredException implements Exception {
  /// 例外を作る。
  const CatchUndoExpiredException();

  @override
  String toString() => '取り消せる時間が過ぎました';
}

/// サーバー時刻が取れず、期限内かどうかを確かめられなかった。
class CatchUndoUnavailableException implements Exception {
  /// 例外を作る。
  const CatchUndoUnavailableException();

  @override
  String toString() => '通信できないため取り消せませんでした';
}

/// 写真を送ろうとした捕獲が、既に取り消されていた。
class CatchAlreadyUndoneException implements Exception {
  /// 例外を作る。
  const CatchAlreadyUndoneException();

  @override
  String toString() => '捕獲が取り消されたため、写真は送りませんでした';
}
