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

  /// ホストがゲームを開始する。
  ///
  /// ServerValue.timestamp はサーバー側でしか解決されないため、書き込んだ
  /// その場では startedAt の実値を知り得ず、クライアントで
  /// `startedAt + N` を計算することはできない。ここでは
  /// 1) startedAt を ServerValue.timestamp で確定させて書き込み、
  /// 2) 実際に書き込まれた値を読み戻し、
  /// 3) その実値をもとに releasedAt/endsAt を計算して status と同時に書き込む
  /// という手順にしている(案A)。
  ///
  /// 案B(releasedAt/endsAtを保存せず、画面側で毎回
  /// startedAt + setting から計算する)も検討したが、
  /// docs/rtdb-schema.md が releasedAt/endsAt を meta の実フィールドとして
  /// 既に定義しており、Phase 2 の Cloud Functions 側もこれを直接参照する
  /// 想定であるため、スキーマ通りRTDBに実値を持たせる案Aを採用した。
  ///
  /// status・releasedAt・endsAt は1回の update() にまとめている
  /// (meta ノード自体に .write があるため一括更新できる。rooms/{roomId}
  /// 自体には .write が無く一括書き込みができないのとは別の話 —
  /// 「一括書き込みが使えない理由」参照)。これにより、他クライアントが
  /// status=PLAYING を観測した時点では releasedAt/endsAt も必ず揃っている。
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
