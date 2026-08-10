import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';

class RoomRepository {
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
        final result = await _db.ref('roomCodes/$code').runTransaction((current) {
          if (current != null) return Transaction.abort();
          return Transaction.success({'roomId': roomId});
        });
        debugPrint('[_reserveRoomCode] roomCodes/$code committed=${result.committed}');
        if (result.committed) return code;
      } on FirebaseException catch (e) {
        debugPrint('[_reserveRoomCode] roomCodes/$code 失敗: code=${e.code} message=${e.message}');
        rethrow;
      }
    }
    throw Exception('ルームコードの発行に失敗しました');
  }

  /// ルームを終了状態にする(解散)。
  Future<void> finishRoom(String roomId) async {
    await _db.ref('rooms/$roomId/meta/status').set('FINISHED');
  }

  /// ホストがゲームを開始する。
  Future<void> startGame(String roomId) async {
    await _db.ref('rooms/$roomId/meta/startedAt').set(ServerValue.timestamp);

    final startedAtSnapshot = await _db.ref('rooms/$roomId/meta/startedAt').get();
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

  /// ホストが鬼にする人を指名する(meta/pendingDemonUid経由の自己申告方式。
  Future<void> nominateDemon(String roomId, String uid) async {
    await _db.ref('rooms/$roomId/meta/pendingDemonUid').set(uid);
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
    await _db.ref('rooms/$roomId/users/$uid/becameDemonAt').set(ServerValue.timestamp);

    final catchId = _db.ref('rooms/$roomId/catches').push().key!;
    await _db.ref('rooms/$roomId/catches/$catchId').set({
      'demonUserId': null,
      'fugitiveUserId': uid,
      'caughtAt': ServerValue.timestamp,
    });
  }

  /// コードからルームに参加する
  Future<String> joinRoom({
    required String code,
    required String displayName,
    required String deviceId,
  }) async {
    final snapshot = await _db.ref('roomCodes/$code').get();
    if (!snapshot.exists) throw Exception('ルームが見つかりません');

    final roomId = (snapshot.value as Map)['roomId'] as String;

    await _db.ref('rooms/$roomId/users/$_uid').set({
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

  /// ルームから退出する
  Future<void> leaveRoom(String roomId) async {
    await _db.ref('rooms/$roomId/users/$_uid').remove();
  }
}
