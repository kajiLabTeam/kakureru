import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  ///
  /// rooms/{roomId} 自体には .write が無いため、一括 set はできない
  /// (docs/rtdb-schema.md の「一括書き込みが使えない理由」参照)。
  /// meta / setting / users を個別に書き込む。roomCodes のホスト限定ルールが
  /// meta/hostUserId を参照するため、meta を最初に書いて確定させる。
  Future<String> createRoom({
    required String displayName,
    required String deviceId,
    RoomSetting setting = const RoomSetting(),
  }) async {
    final roomId = _db.ref('rooms').push().key!;
    final code = await _reserveRoomCode(roomId);

    try {
      await _db.ref('rooms/$roomId/meta').set({
        'status': 'WAITING',
        'hostUserId': _uid,
        'roomCode': code,
        'createdAt': ServerValue.timestamp,
      });
      await _db.ref('rooms/$roomId/setting').set(setting.toMap());
      await _db.ref('rooms/$roomId/users/$_uid').set({
        'displayName': displayName,
        'deviceId': deviceId,
        'isHost': true,
        'role': 'FUGITIVE',
        'joinedAt': ServerValue.timestamp,
      });
    } catch (e) {
      await _rollbackRoom(roomId, code);
      rethrow;
    }

    return roomId;
  }

  /// createRoom 失敗時に、途中まで書き込んだ内容を可能な範囲で取り消す。
  ///
  /// roomCodes/{code} の削除はホスト限定ルール(meta/hostUserId 参照)に
  /// 依存するため、meta を消す前に行う。meta の書き込み自体が失敗していた
  /// 場合は hostUserId が存在せず、roomCodes の削除も権限エラーになり
  /// コードが孤立したまま残りうる(既知の限界。docs/rtdb-schema.md 参照)。
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
      final result = await _db.ref('roomCodes/$code').runTransaction((current) {
        if (current != null) return Transaction.abort();
        return Transaction.success({'roomId': roomId});
      });
      if (result.committed) return code;
    }
    throw Exception('ルームコードの発行に失敗しました');
  }

  /// ルームを終了状態にする(解散)。
  ///
  /// ホストに他ユーザーの users/{uid} への書き込み権限を与えると
  /// role や pressureOffset を書き換えられる穴になるため、ルールは変更しない。
  /// そのため実データ(users/setting/meta/roomCodes)の削除はここでは行わず、
  /// meta/status を "FINISHED" にするだけにとどめる。実データの削除は
  /// Phase 2 の finishGame Function に任せる想定
  /// (docs/rtdb-schema.md の「ルーム終了は Phase 1 ではステータス変更のみ」参照)。
  Future<void> finishRoom(String roomId) async {
    await _db.ref('rooms/$roomId/meta/status').set('FINISHED');
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
  ///
  /// rooms/{roomId} 自体は読み取り不可(meta/setting/users個別にしか
  /// .read が無い)ため、3つを個別に購読して Room に合成する。
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
