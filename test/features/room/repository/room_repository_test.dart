import 'dart:async';

import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_catch.dart';
import 'package:kakureru/features/room/model/sighting.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/room_create_error.dart';
import 'package:kakureru/features/room/room_join_error.dart';

/// RTDBの代わりに、パス→値のツリーをメモリ上に持つだけのfake。
///
/// FirebaseDatabase/FirebaseAuthはコンストラクタが非公開でテストダブルを
/// 渡せないため、`implements` + `noSuchMethod`で必要なAPI
/// (`ref()` / `get()` / `set()` / `onValue`)だけを実装する。未実装のメンバを
/// 呼んだ場合はNoSuchMethodErrorで落ちるので、テストが黙って通ることはない。
class _FakeDatabase implements FirebaseDatabase {
  _FakeDatabase(
    this.root, {
    this.allRoomCodesTaken = false,
    this.serverTimeUnavailable = false,
    this.transactionCacheEmpty = false,
  });

  /// RTDBのツリーをネストしたMapで持つ。
  final Map<String, Object?> root;

  /// trueにすると、どの4桁コードを引いても既に使われている状態になる
  /// (コードが枯渇したときの[RoomCreateError]の検証に使う)。
  final bool allRoomCodesTaken;

  /// trueにすると`.info/serverTimeOffset`の購読がエラーになる(オフライン等)。
  /// タイムアウト待ちをせずに「サーバー時刻が取れない」状態を作れる。
  final bool serverTimeUnavailable;

  /// trueにすると、実機で手元にキャッシュが無いときと同じく、
  /// `runTransaction`のハンドラを最初にnullで呼ぶ。abortされればそこで
  /// 終わり(committed=false)、値を返せばサーバーの値で呼び直す。
  final bool transactionCacheEmpty;

  /// `set`/`update`の完了(サーバーの応答)を止めておく。書き込み自体は
  /// 実機の「手元への即時反映」と同じくすぐ[root]に反映する。nullなら止めない。
  Completer<void>? holdWrites;

  /// リポジトリが`get()`で読んだパス。「そもそも読みにいかない」ことを
  /// 検証するために記録する(テスト側から直接[read]した分は含めない)。
  final readPaths = <String>[];

  /// リポジトリが`get()`で読んだ直後に呼ばれる。読み取りと次の書き込みの
  /// 間に、別の端末の書き込みが割り込む状況を作るために使う。
  void Function(String path)? afterGet;

  @override
  DatabaseReference ref([String? path]) => _FakeReference(this, path ?? '');

  Object? read(String path) {
    if (allRoomCodesTaken && path.startsWith('roomCodes/')) {
      return <String, Object?>{'roomId': 'someone-else'};
    }
    Object? node = root;
    for (final segment in _segments(path)) {
      if (node is! Map) return null;
      node = node[segment];
    }
    return node;
  }

  void write(String path, Object? value) {
    final segments = _segments(path);
    var node = root;
    for (final segment in segments.take(segments.length - 1)) {
      // 途中のノードは、Mapリテラルの型推論(Map<String, String>等)に
      // 左右されないよう、書き込み可能な型へ写し替えながら降りる。
      final child = node[segment];
      final next = child is Map
          ? Map<String, Object?>.from(child)
          : <String, Object?>{};
      node[segment] = next;
      node = next;
    }
    node[segments.last] = value;
  }

  void remove(String path) {
    final segments = _segments(path);
    Object? node = root;
    for (final segment in segments.take(segments.length - 1)) {
      if (node is! Map) return;
      node = node[segment];
    }
    if (node is Map) node.remove(segments.last);
  }

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReference implements DatabaseReference {
  _FakeReference(this._db, this._path);

  final _FakeDatabase _db;
  final String _path;

  @override
  Future<DataSnapshot> get() async {
    _db.readPaths.add(_path);
    final snapshot = _FakeSnapshot(_db.read(_path));
    _db.afterGet?.call(_path);
    return snapshot;
  }

  @override
  Future<void> set(Object? value) async {
    _db.write(_path, value);
    await _db.holdWrites?.future;
  }

  /// RTDBの`update`と同じく、渡した子だけを書き換え、他の子は残す。
  /// 値が`null`の子は消す。
  @override
  Future<void> update(Map<String, Object?> value) async {
    for (final entry in value.entries) {
      final childPath = '$_path/${entry.key}';
      if (entry.value == null) {
        _db.remove(childPath);
      } else {
        _db.write(childPath, entry.value);
      }
    }
    await _db.holdWrites?.future;
  }

  /// `push()`は新しい子への参照を返すだけなので、キーが毎回変わることだけ
  /// 再現できればよい。
  @override
  DatabaseReference push() => _FakeReference(_db, '$_path/${_pushCounter++}');

  @override
  String? get key => _path.split('/').last;

  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler handler, {
    bool applyLocally = true,
  }) async {
    if (_db.transactionCacheEmpty) {
      final guess = handler(null);
      if (guess.aborted) return _FakeTransactionResult(committed: false);
    }
    final result = handler(_db.read(_path));
    if (result.aborted) return _FakeTransactionResult(committed: false);
    _db.write(_path, result.value);
    return _FakeTransactionResult(
      committed: true,
      snapshot: _FakeSnapshot(result.value),
    );
  }

  @override
  Stream<DatabaseEvent> get onValue {
    if (_db.serverTimeUnavailable && _path == '.info/serverTimeOffset') {
      return Stream<DatabaseEvent>.error(Exception('offline'));
    }
    return Stream.value(_FakeEvent(_FakeSnapshot(_db.read(_path))));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `push()`が返すキーの連番。値そのものに意味は無い。
int _pushCounter = 0;

class _FakeTransactionResult implements TransactionResult {
  _FakeTransactionResult({
    required this.committed,
    this.snapshot = const _FakeSnapshot(null),
  });

  @override
  final bool committed;

  @override
  final DataSnapshot snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEvent implements DatabaseEvent {
  _FakeEvent(this.snapshot);

  @override
  final DataSnapshot snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSnapshot implements DataSnapshot {
  const _FakeSnapshot(this.value);

  @override
  final Object? value;

  @override
  bool get exists => value != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  String get uid => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// テストの「現在時刻」。端末時計をこの時刻に固定して使う。
const _nowMillis = 1000000;

/// ホスト(鬼)と逃走者が1人ずついる、ゲームが成立している参加者。
///
/// [hasFugitive]をfalseにすると全員が鬼、つまり逃走者が全員捕まって
/// 決着した後の状態になる。
Map<String, Object?> _usersWith({bool hasFugitive = true}) => <String, Object?>{
  'host': <String, Object?>{'displayName': 'ホスト', 'role': 'DEMON'},
  'other': <String, Object?>{
    'displayName': 'ほか',
    'role': hasFugitive ? 'FUGITIVE' : 'DEMON',
  },
};

/// コード`1234`が`room-1`を指し、そのstatusが[status]のRTDBを作る。
///
/// [status]がnullなら`meta/status`自体が無い状態(書き込み途中など)。
/// [endsAt]はゲームの終了時刻(未設定なら待機中でまだ始まっていない)。
/// [serverTimeOffset]は端末時計とサーバー時刻のズレ。
/// [users]を省略すると[_usersWith]の既定(逃走者あり)になる。
Map<String, Object?> _rtdbWith({
  String? status = 'WAITING',
  int? endsAt,
  int serverTimeOffset = 0,
  Map<String, Object?>? users,
}) => <String, Object?>{
  '.info': <String, Object?>{'serverTimeOffset': serverTimeOffset},
  'roomCodes': <String, Object?>{
    '1234': <String, Object?>{'roomId': 'room-1'},
  },
  'rooms': <String, Object?>{
    'room-1': <String, Object?>{
      'meta': <String, Object?>{
        'roomCode': '1234',
        'hostUserId': 'host',
        'status': ?status,
        'endsAt': ?endsAt,
      },
      'users': users ?? _usersWith(),
    },
  },
};

/// 端末時計を[_nowMillis]に固定して[body]を動かす。
Future<T> _atFixedNow<T>(Future<T> Function() body) => withClock(
  Clock.fixed(DateTime.fromMillisecondsSinceEpoch(_nowMillis)),
  body,
);

Map<String, Object?>? _usersOf(_FakeDatabase db) =>
    db.read('rooms/room-1/users') as Map<String, Object?>?;

void main() {
  group('RoomRepository.joinRoom', () {
    test('待機中のルームには参加でき、自分のusersが書き込まれる', () async {
      final db = _FakeDatabase(_rtdbWith());
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      final roomId = await repo.joinRoom(
        code: '1234',
        displayName: 'たろう',
      );

      expect(roomId, 'room-1');
      final me = _usersOf(db)!['me']! as Map<String, Object?>;
      expect(me['displayName'], 'たろう');
      expect(me['isHost'], false);
      expect(me['role'], 'FUGITIVE');
    });

    test('終了したルームには参加せず、usersを書き込まない', () async {
      final db = _FakeDatabase(_rtdbWith(status: 'FINISHED'));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.joinRoom(
          code: '1234',
          displayName: 'たろう',
        ),
        throwsA(RoomJoinError.finished),
      );

      // 参加者として残ってしまうと、他の端末の一覧にも出てしまう。
      expect(_usersOf(db), isNot(contains('me')));
    });

    test('サーバー時刻を取得できないときは参加せず、usersを書き込まない', () async {
      // オフセットが取れないまま端末時計で判定すると、時計が遅れている
      // 端末が`endsAt`を過ぎたルームに入れてしまう(PR #103のレビュー指摘)。
      final db = _FakeDatabase(
        _rtdbWith(status: 'PLAYING', endsAt: _nowMillis + 60000),
        serverTimeUnavailable: true,
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        withClock(
          Clock.fixed(DateTime.fromMillisecondsSinceEpoch(_nowMillis)),
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        throwsA(RoomJoinError.serverTimeUnavailable),
      );

      expect(_usersOf(db), isNot(contains('me')));
    });

    test('4桁の数字でないコードはinvalidCodeになり、RTDBを読みにいかない', () async {
      // 画面とViewModelでも弾いているが、このメソッドを直接呼ばれても
      // `roomCodes/`の読み取り(権限エラー)まで進ませない。
      final db = _FakeDatabase(_rtdbWith());
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.joinRoom(code: '', displayName: 'たろう'),
        throwsA(RoomJoinError.invalidCode),
      );
      await expectLater(
        repo.joinRoom(code: '12a4', displayName: 'たろう'),
        throwsA(RoomJoinError.invalidCode),
      );

      expect(db.readPaths, isEmpty);
      expect(_usersOf(db), isNot(contains('me')));
    });

    test('存在しないコードはnotFoundになり、ルームを読みにいかない', () async {
      final db = _FakeDatabase(_rtdbWith());
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.joinRoom(
          code: '9999',
          displayName: 'たろう',
        ),
        throwsA(RoomJoinError.notFound),
      );

      expect(_usersOf(db), isNot(contains('me')));
      expect(db.readPaths, isNot(contains(startsWith('rooms/'))));
    });

    test('コードだけ残ってルーム本体が消えている場合もnotFound', () async {
      // ルームをコンソールで手動削除した後や、createRoomがmetaの書き込み
      // 前に失敗してroomCodesを消せなかった後に起きる。参加できてしまうと
      // 待機画面で「ルームが存在しません」の生の例外文が出る。
      final rtdb = _rtdbWith()..remove('rooms');
      final db = _FakeDatabase(rtdb);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.joinRoom(
          code: '1234',
          displayName: 'たろう',
        ),
        throwsA(RoomJoinError.notFound),
      );

      expect(_usersOf(db), isNull);
    });

    test('待機中のルームでは参加者を読みにいかない', () async {
      // 逃走者が居るかどうかはPLAYING中しか効かないので、待機中に
      // usersまで読むのは無駄なラウンドトリップになる。
      final db = _FakeDatabase(_rtdbWith());
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.joinRoom(
        code: '1234',
        displayName: 'たろう',
      );

      expect(db.readPaths, isNot(contains('rooms/room-1/users')));
    });

    test('進行中のルームには従来どおり途中参加できる', () async {
      // 逃走者がまだ残っている(=まだ決着していない)ルーム。
      final db = _FakeDatabase(_rtdbWith(status: 'PLAYING'));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      expect(
        await repo.joinRoom(
          code: '1234',
          displayName: 'たろう',
        ),
        'room-1',
      );
    });

    test('metaはあるがstatusだけ無いルームは待機中とみなして参加できる', () async {
      final db = _FakeDatabase(_rtdbWith(status: null));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      expect(
        await repo.joinRoom(
          code: '1234',
          displayName: 'たろう',
        ),
        'room-1',
      );
    });
  });

  group('RoomRepository.joinRoom 終了時刻の判定', () {
    // statusをFINISHEDにするfinishRoomはまだどこからも呼ばれておらず、
    // 遊び終えたルームはPLAYINGのままendsAtだけが過去になる。「先週の
    // コードで終わった部屋に入れてしまう」のはこの状態なので、ここが
    // 実際のガードになる。
    test('終了時刻を過ぎたルームには、statusがPLAYINGでも参加しない', () async {
      final db = _FakeDatabase(
        _rtdbWith(status: 'PLAYING', endsAt: _nowMillis - 1),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        _atFixedNow(
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        throwsA(RoomJoinError.finished),
      );

      expect(_usersOf(db), isNot(contains('me')));
    });

    test('終了時刻の前なら途中参加できる', () async {
      final db = _FakeDatabase(
        _rtdbWith(status: 'PLAYING', endsAt: _nowMillis + 60000),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      expect(
        await _atFixedNow(
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        'room-1',
      );
    });

    test('端末時計ではなくサーバー時刻(オフセット込み)で判定する', () async {
      // 端末時計ではまだ終了前だが、サーバー時刻では過ぎている。
      final db = _FakeDatabase(
        _rtdbWith(
          status: 'PLAYING',
          endsAt: _nowMillis + 1000,
          serverTimeOffset: 5000,
        ),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        _atFixedNow(
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        throwsA(RoomJoinError.finished),
      );
    });

    test('「もう一回」で待機中に巻き戻ったルーム(endsAtなし)には参加できる', () async {
      final db = _FakeDatabase(_rtdbWith());
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      expect(
        await _atFixedNow(
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        'room-1',
      );
    });
  });

  group('RoomRepository.joinRoom 逃走者0人の判定', () {
    // 全員が捕まって決着したルームは、statusがPLAYINGのままendsAtも未来。
    // ここで弾かないと、参加者はrole=FUGITIVEで書き込まれるため、既に
    // 結果画面を見ている全員の勝敗が「逃げ切り1人」に反転する。
    test('全員が捕まったルームには、終了時刻の前でも参加しない', () async {
      final db = _FakeDatabase(
        _rtdbWith(
          status: 'PLAYING',
          endsAt: _nowMillis + 60000,
          users: _usersWith(hasFugitive: false),
        ),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        _atFixedNow(
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        throwsA(RoomJoinError.finished),
      );

      expect(_usersOf(db), isNot(contains('me')));
    });

    test('誰も残っていない進行中のルームにも参加しない', () async {
      final rtdb = _rtdbWith(status: 'PLAYING', endsAt: _nowMillis + 60000);
      ((rtdb['rooms']! as Map)['room-1']! as Map).remove('users');
      final db = _FakeDatabase(rtdb);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        _atFixedNow(
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        throwsA(RoomJoinError.finished),
      );
    });

    test('roleが未設定の参加者は逃走者として扱い、参加できる', () async {
      // RoomUserの既定(役割不明ならFUGITIVE)と揃える。書き込み途中の
      // 参加者が居るだけで「全員捕まった」と誤判定しないため。
      final db = _FakeDatabase(
        _rtdbWith(
          status: 'PLAYING',
          endsAt: _nowMillis + 60000,
          users: <String, Object?>{
            'host': <String, Object?>{'displayName': 'ホスト', 'role': 'DEMON'},
            'other': <String, Object?>{'displayName': 'ほか'},
          },
        ),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      expect(
        await _atFixedNow(
          () => repo.joinRoom(
            code: '1234',
            displayName: 'たろう',
          ),
        ),
        'room-1',
      );
    });
  });

  group('RoomRepository.leaveRoom', () {
    test('退出してもusers/{uid}とlocations/{uid}は消さず、退出の印だけ付ける', () async {
      // プレイテスト(roomCode 5189)で、結果画面から帰った参加者のusers・
      // locationsが消え、eventsのuidから誰だったか辿れなくなった。
      final rtdb = _rtdbWith(
        status: 'PLAYING',
        users: {
          ..._usersWith(),
          'me': <String, Object?>{
            'displayName': 'たろう',
            'role': 'DEMON',
            'joinedAt': 1,
            'pressureSensorAvailable': true,
            'pressureOffset': 0.4,
          },
        },
      );
      (rtdb['rooms']! as Map<String, Object?>)['room-1'] = {
        ...((rtdb['rooms']! as Map<String, Object?>)['room-1']!
            as Map<String, Object?>),
        'locations': <String, Object?>{
          'me': <String, Object?>{'latitude': 35.1, 'longitude': 136.9},
        },
      };
      final db = _FakeDatabase(rtdb);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.leaveRoom('room-1');

      final me = _usersOf(db)!['me']! as Map<String, Object?>;
      expect(me['displayName'], 'たろう');
      expect(me['role'], 'DEMON');
      expect(me['joinedAt'], 1);
      expect(me['pressureSensorAvailable'], true);
      expect(me['pressureOffset'], 0.4);
      expect(me['online'], false);
      expect(me, contains('leftAt'));
      expect(db.read('rooms/room-1/locations/me'), isNotNull);
    });
  });

  group('RoomRepository.joinRoom 既存のusers/{uid}', () {
    test('先に書かれた他のフィールドを消さずに書き込む', () async {
      // 気圧センサーの有無(pressureSensorAvailable)やキャリブレーション値は
      // 別の書き込みで入る。setでノードごと置き換えるとそれが消える。
      final db = _FakeDatabase(
        _rtdbWith(
          users: {
            ..._usersWith(),
            'me': <String, Object?>{
              'pressureSensorAvailable': true,
              'pressureOffset': 0.4,
              'online': false,
              'leftAt': 5,
            },
          },
        ),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.joinRoom(code: '1234', displayName: 'たろう');

      final me = _usersOf(db)!['me']! as Map<String, Object?>;
      expect(me['displayName'], 'たろう');
      expect(me['role'], 'FUGITIVE');
      expect(me['pressureSensorAvailable'], true);
      expect(me['pressureOffset'], 0.4);
      // 入り直したので退出の印は戻す。
      expect(me['online'], true);
      expect(me, isNot(contains('leftAt')));
    });

    test('退出済みの逃走者は、逃走者が残っている判定に数えない', () async {
      final db = _FakeDatabase(
        _rtdbWith(
          status: 'PLAYING',
          endsAt: _nowMillis + 60000,
          users: {
            'host': <String, Object?>{'displayName': 'ホスト', 'role': 'DEMON'},
            'gone': <String, Object?>{
              'displayName': 'かえった',
              'role': 'FUGITIVE',
              'online': false,
            },
          },
        ),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        _atFixedNow(() => repo.joinRoom(code: '1234', displayName: 'たろう')),
        throwsA(RoomJoinError.finished),
      );
    });
  });

  group('RoomRepository.setUsesTethering(issue #142)', () {
    test('自分のusesTetheringだけを書き、他のフィールドは消さない', () async {
      final db = _FakeDatabase(
        _rtdbWith(
          users: {
            ..._usersWith(),
            'me': <String, Object?>{
              'displayName': 'たろう',
              'pressureOffset': 0.4,
            },
          },
        ),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.setUsesTethering('room-1', value: true);

      final me = _usersOf(db)!['me']! as Map<String, Object?>;
      expect(me['usesTethering'], true);
      expect(me['displayName'], 'たろう');
      expect(me['pressureOffset'], 0.4);
    });

    test('OFFに戻すとfalseを書く', () async {
      final db = _FakeDatabase(
        _rtdbWith(
          users: {
            ..._usersWith(),
            'me': <String, Object?>{'usesTethering': true},
          },
        ),
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.setUsesTethering('room-1', value: false);

      final me = _usersOf(db)!['me']! as Map<String, Object?>;
      expect(me['usesTethering'], false);
    });
  });

  group('Room.fromMap', () {
    test('退出済み(online: false)の人は参加者に含めない', () {
      final room = Room.fromMap('room-1', {
        'meta': <String, Object?>{'status': 'PLAYING'},
        'users': <String, Object?>{
          'a': <String, Object?>{'displayName': 'A'},
          'b': <String, Object?>{'displayName': 'B', 'online': true},
          'c': <String, Object?>{'displayName': 'C', 'online': false},
        },
      });

      expect(room.users.map((u) => u.id), unorderedEquals(['a', 'b']));
    });
  });

  group('RoomRepository.createRoom', () {
    test('コードが全部埋まっているとcodeExhaustedになる', () async {
      // 遊び終えたルームのroomCodesは消されない運用なので、いつか必ず
      // 起きる(docs/rtdb-schema.md「Phase 1の限界」)。生の例外文ではなく
      // 画面で日本語に変換できる理由を投げる。
      final db = _FakeDatabase(<String, Object?>{}, allRoomCodesTaken: true);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.createRoom(displayName: 'たろう'),
        throwsA(RoomCreateError.codeExhausted),
      );
    });
  });

  group('RoomRepository 捕まえた・取り消し(issue #140)', () {
    // 自分(me)が捕まった逃走者。鬼のdemonが_nowMillis - [agoMillis]に捕まえ、
    // 自分の端末はacceptCaughtで既に鬼になっている状態を作る。
    ({_FakeDatabase db, RoomCatch roomCatch}) caughtState({
      required int agoMillis,
      String? photoId,
    }) {
      final roomCatch = RoomCatch(
        id: 'c1',
        demonUserId: 'demon',
        fugitiveUserId: 'me',
        caughtAt: _nowMillis - agoMillis,
        catchPhotoId: photoId,
      );
      final db =
          _FakeDatabase(
            _rtdbWith(
              status: 'PLAYING',
              users: <String, Object?>{
                'demon': <String, Object?>{'displayName': '鬼', 'role': 'DEMON'},
                'me': <String, Object?>{
                  'displayName': 'わたし',
                  'role': 'DEMON',
                  'becameDemonAt': roomCatch.caughtAt,
                },
              },
            ),
          )..write('rooms/room-1/catches/c1', <String, Object?>{
            'demonUserId': 'demon',
            'fugitiveUserId': 'me',
            'caughtAt': roomCatch.caughtAt,
            'catchPhotoId': ?photoId,
          });
      if (photoId != null) {
        db.write('rooms/room-1/catchPhotos/$photoId', <String, Object?>{
          'catchId': 'c1',
          'demonUid': 'demon',
          'fugitiveUid': 'me',
          'takenAt': roomCatch.caughtAt,
        });
      }
      return (db: db, roomCatch: roomCatch);
    }

    test('reportCatchは捕まえた鬼(自分)のuidを入れて捕獲を書く', () async {
      final db = _FakeDatabase(_rtdbWith(status: 'PLAYING'));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      final catchId = await repo.reportCatch('room-1', fugitiveUid: 'other');

      final written =
          db.read('rooms/room-1/catches/$catchId')! as Map<String, Object?>;
      expect(written['demonUserId'], 'me');
      expect(written['fugitiveUserId'], 'other');
      // 逃走者の役割は本人しか書けないので、ここでは書き換えない。
      expect(db.read('rooms/room-1/users/other/role'), 'FUGITIVE');
    });

    test('10秒以内なら取り消せ、捕獲と役割の両方が戻る', () async {
      final (:db, :roomCatch) = caughtState(agoMillis: 9999, photoId: 'p1');
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await _atFixedNow(() => repo.undoCatch('room-1', roomCatch));

      expect(db.read('rooms/room-1/catches/c1'), isNull);
      expect(db.read('rooms/room-1/catchPhotos/p1'), isNull);
      expect(db.read('rooms/room-1/users/me/role'), 'FUGITIVE');
      expect(db.read('rooms/room-1/users/me/becameDemonAt'), isNull);
    });

    test('取り消しは捕獲の削除の応答を待たずに役割の書き戻しまで出す', () async {
      // 捕獲を消した後に通信が切れても「捕獲は無いのに鬼」で取り残されない
      // よう、3つの書き込みがすべて手元に積まれていること。
      final (:db, :roomCatch) = caughtState(agoMillis: 0, photoId: 'p1');
      final repo = RoomRepository(db: db, auth: _FakeAuth());
      final hold = db.holdWrites = Completer<void>();

      final undo = _atFixedNow(() => repo.undoCatch('room-1', roomCatch));
      await pumpEventQueue();

      expect(db.read('rooms/room-1/catches/c1'), isNull);
      expect(db.read('rooms/room-1/catchPhotos/p1'), isNull);
      expect(db.read('rooms/room-1/users/me/role'), 'FUGITIVE');
      hold.complete();
      await undo;
    });

    test('写真IDを読んだ後に写真が付いても、取り消し後にその写真は残らない', () async {
      // issue #145: undoCatchがcatchPhotoIdを読んでから捕獲を消すまでの間に
      // 鬼のattachCatchPhotoが確定したケース。
      final (:db, :roomCatch) = caughtState(agoMillis: 0);
      db.afterGet = (path) {
        if (!path.endsWith('/catchPhotoId')) return;
        db
          ..write('rooms/room-1/catchPhotos/p2', <String, Object?>{
            'catchId': 'c1',
            'demonUid': 'demon',
            'fugitiveUid': 'me',
            'takenAt': roomCatch.caughtAt,
          })
          ..write('rooms/room-1/catches/c1/catchPhotoId', 'p2');
      };
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await _atFixedNow(() => repo.undoCatch('room-1', roomCatch));

      expect(db.read('rooms/room-1/catches/c1'), isNull);
      expect(db.read('rooms/room-1/catchPhotos/p2'), isNull);
    });

    test('取り消しは別の捕獲の写真を消さない', () async {
      final (:db, :roomCatch) = caughtState(agoMillis: 0, photoId: 'p1');
      db.write('rooms/room-1/catchPhotos/other', <String, Object?>{
        'catchId': 'c-other',
        'demonUid': 'demon',
        'fugitiveUid': 'me',
        'takenAt': roomCatch.caughtAt,
      });
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await _atFixedNow(() => repo.undoCatch('room-1', roomCatch));

      expect(db.read('rooms/room-1/catchPhotos/p1'), isNull);
      expect(db.read('rooms/room-1/catchPhotos/other'), isNotNull);
    });

    test('10秒を過ぎたら取り消せず、何も書き換えない', () async {
      final (:db, :roomCatch) = caughtState(agoMillis: 10000);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        _atFixedNow(() => repo.undoCatch('room-1', roomCatch)),
        throwsA(isA<CatchUndoExpiredException>()),
      );

      expect(db.read('rooms/room-1/catches/c1'), isNotNull);
      expect(db.read('rooms/room-1/users/me/role'), 'DEMON');
    });

    test('サーバー時刻が取れなければ取り消さない', () async {
      final (db: base, :roomCatch) = caughtState(agoMillis: 0);
      final db = _FakeDatabase(base.root, serverTimeUnavailable: true);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        _atFixedNow(() => repo.undoCatch('room-1', roomCatch)),
        throwsA(isA<CatchUndoUnavailableException>()),
      );
      expect(db.read('rooms/room-1/catches/c1'), isNotNull);
    });

    test('attachCatchPhotoは写真のメタデータを書き、捕獲に写真IDを付ける', () async {
      final (:db, roomCatch: _) = caughtState(agoMillis: 0);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.attachCatchPhoto(
        'room-1',
        catchId: 'c1',
        photoId: 'p9',
        fugitiveUid: 'other',
      );

      expect(db.read('rooms/room-1/catches/c1/catchPhotoId'), 'p9');
      expect(db.read('rooms/room-1/catches/c1/fugitiveUserId'), 'me');
      expect(db.read('rooms/room-1/catchPhotos/p9/catchId'), 'c1');
      expect(db.read('rooms/room-1/catchPhotos/p9/demonUid'), 'me');
    });

    test('手元にキャッシュが無くても、捕獲があれば写真を付けられる', () async {
      final (db: base, roomCatch: _) = caughtState(agoMillis: 0);
      final db = _FakeDatabase(base.root, transactionCacheEmpty: true);
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.attachCatchPhoto(
        'room-1',
        catchId: 'c1',
        photoId: 'p9',
        fugitiveUid: 'other',
      );

      expect(db.read('rooms/room-1/catches/c1/catchPhotoId'), 'p9');
      expect(db.read('rooms/room-1/catchPhotos/p9/catchId'), 'c1');
    });

    test('手元にキャッシュが無く、捕獲も無ければ取り消し済みとして扱う', () async {
      final db = _FakeDatabase(
        _rtdbWith(status: 'PLAYING'),
        transactionCacheEmpty: true,
      );
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.attachCatchPhoto(
          'room-1',
          catchId: 'gone',
          photoId: 'p9',
          fugitiveUid: 'other',
        ),
        throwsA(isA<CatchAlreadyUndoneException>()),
      );
      expect(db.read('rooms/room-1/catches/gone'), isNull);
      expect(db.read('rooms/room-1/catchPhotos/p9'), isNull);
    });

    test('取り消し済みの捕獲には写真を付けず、メタデータも残さない', () async {
      final db = _FakeDatabase(_rtdbWith(status: 'PLAYING'));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.attachCatchPhoto(
          'room-1',
          catchId: 'gone',
          photoId: 'p9',
          fugitiveUid: 'other',
        ),
        throwsA(isA<CatchAlreadyUndoneException>()),
      );
      expect(db.read('rooms/room-1/catches/gone'), isNull);
      expect(db.read('rooms/room-1/catchPhotos/p9'), isNull);
    });
  });

  group('RoomRepository 目撃写真(sightings)', () {
    test('addSightingは自分のuidとサーバー時刻を書き、placeは書かない', () async {
      final db = _FakeDatabase(_rtdbWith(status: 'PLAYING'));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await repo.addSighting('room-1', 'p1');

      expect(db.read('rooms/room-1/sightings/p1'), <String, Object?>{
        'uid': 'me',
        'takenAt': ServerValue.timestamp,
      });
    });

    test('watchSightingsは子を一覧にし、読めない子は飛ばす', () async {
      final db = _FakeDatabase(_rtdbWith(status: 'PLAYING'))
        ..write('rooms/room-1/sightings/p1', <String, Object?>{
          'uid': 'alice',
          'takenAt': 100,
          'place': '中庭',
        })
        ..write('rooms/room-1/sightings/p2', <String, Object?>{'uid': 'bob'});
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      final sightings = await repo.watchSightings('room-1').first;

      expect(sightings, const [
        Sighting(id: 'p1', uid: 'alice', takenAt: 100, place: '中庭'),
      ]);
    });

    test('watchSightingsは写真が無ければ空の一覧を流す', () async {
      final db = _FakeDatabase(_rtdbWith(status: 'PLAYING'));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      expect(await repo.watchSightings('room-1').first, isEmpty);
    });
  });

  group('RoomStatus', () {
    test('rawはRTDBに書かれている文字列と一致する', () {
      expect(RoomStatus.waiting.raw, 'WAITING');
      expect(RoomStatus.playing.raw, 'PLAYING');
      expect(RoomStatus.finished.raw, 'FINISHED');
    });

    test('未知の値・未設定は待機中として扱う', () {
      expect(RoomStatus.fromRaw('FINISHED'), RoomStatus.finished);
      expect(RoomStatus.fromRaw('UNKNOWN'), RoomStatus.waiting);
      expect(RoomStatus.fromRaw(null), RoomStatus.waiting);
    });
  });
}
