import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';

class RoomRepository {
  /// 離脱後、同じ端末(同じuid)なら復帰できる猶予時間。
  static const rejoinWindow = Duration(minutes: 5);

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  final _random = Random();

  RoomRepository({FirebaseDatabase? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseDatabase.instance,
      _auth = auth ?? FirebaseAuth.instance;

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
        'status': 'WAITING',
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
      'status': 'FINISHED',
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
      'status': 'PLAYING',
      'releasedAt': startedAt + setting.releaseWaitSec * 1000,
      'endsAt': startedAt + setting.gameDurationSec * 1000,
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
  Future<void> acceptDemonNomination(String roomId, String uid) async {
    await _db.ref('rooms/$roomId/users/$uid/role').set('DEMON');
    await _db.ref('rooms/$roomId/meta/pendingDemonUid').set(null);
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
  /// 同じuid(同じ端末)で、[rejoinWindow]以内に離脱した記録が残っていれば、
  /// role等の状態を維持したまま復帰させる(leftAtを消すだけ)。それ以外
  /// (初参加、猶予切れ、別端末)は通常の新規参加として上書きする。
  Future<String> joinRoom({
    required String code,
    required String displayName,
    required String deviceId,
  }) async {
    final snapshot = await _db.ref('roomCodes/$code').get();
    if (!snapshot.exists) throw Exception('ルームが見つかりません');

    final roomId = (snapshot.value as Map)['roomId'] as String;

    final userRef = _db.ref('rooms/$roomId/users/$_uid');
    final existingSnapshot = await userRef.get();
    if (existingSnapshot.exists) {
      final existing = RoomUser.fromMap(
        _uid,
        existingSnapshot.value as Map<dynamic, dynamic>,
      );
      final leftAt = existing.leftAt;
      if (leftAt != null) {
        final elapsed = Duration(
          milliseconds: DateTime.now().millisecondsSinceEpoch - leftAt,
        );
        if (elapsed <= rejoinWindow) {
          await userRef.child('leftAt').remove();
          return roomId;
        }
      }
    }

    await userRef.set({
      'displayName': displayName,
      'deviceId': deviceId,
      'isHost': false,
      'role': 'FUGITIVE',
      'joinedAt': ServerValue.timestamp,
    });

    return roomId;
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
  /// users/{uid} は削除せず、leftAtを立てるだけの「ソフト離脱」にする
  /// ([rejoinWindow]以内に同じuidで再度joinRoomすれば、role等を維持した
  /// まま復帰できるようにするため)。位置情報(locations/{uid})は復帰まで
  /// 更新が止まる古い座標を地図に残さないよう、退出時点で消す
  /// (docs/rtdb-schema.md上、locations/{uid} は本人のみ書き込み可)。
  ///
  /// **既知の制約**: 戻る操作による明示的な離脱しか検知できない。アプリの
  /// 強制終了・クラッシュ・OSによるプロセスkillではこのメソッドが呼ばれず、
  /// leftAtが立たないまま(復帰扱いのまま)になる。厳密に検知するには
  /// RTDBのonDisconnect()(presence機構)への移行が必要だが、Phase 1では
  /// スコープ外としている。また、leftAt設定の後にlocations削除を行う2段階の
  /// 処理のため、ネットワーク瞬断等で後者だけ失敗すると、離脱通知(leftAt基準)
  /// は正しく出る一方で地図上の位置ピンだけ残る可能性がある。
  /// [rejoinWindow]を過ぎても、users/{uid}は自動では削除されない
  /// (次にjoinRoomされた時点で通常の新規参加として上書きされるか、
  /// ルーム自体がfinishするまでそのまま残る)。
  Future<void> leaveRoom(String roomId) async {
    await _db.ref('rooms/$roomId/users/$_uid/leftAt').set(ServerValue.timestamp);
    await _db.ref('rooms/$roomId/locations/$_uid').remove();
  }
}
