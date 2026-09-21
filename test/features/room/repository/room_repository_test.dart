import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/room_join_error.dart';

/// RTDBの代わりに、パス→値のツリーをメモリ上に持つだけのfake。
///
/// FirebaseDatabase/FirebaseAuthはコンストラクタが非公開でテストダブルを
/// 渡せないため、`implements` + `noSuchMethod`で必要なAPI
/// (`ref()` / `get()` / `set()` / `onValue`)だけを実装する。未実装のメンバを
/// 呼んだ場合はNoSuchMethodErrorで落ちるので、テストが黙って通ることはない。
class _FakeDatabase implements FirebaseDatabase {
  _FakeDatabase(this.root);

  /// RTDBのツリーをネストしたMapで持つ。
  final Map<String, Object?> root;

  /// リポジトリが`get()`で読んだパス。「そもそも読みにいかない」ことを
  /// 検証するために記録する(テスト側から直接[read]した分は含めない)。
  final readPaths = <String>[];

  @override
  DatabaseReference ref([String? path]) => _FakeReference(this, path ?? '');

  Object? read(String path) {
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
    return _FakeSnapshot(_db.read(_path));
  }

  @override
  Future<void> set(Object? value) async => _db.write(_path, value);

  @override
  Stream<DatabaseEvent> get onValue =>
      Stream.value(_FakeEvent(_FakeSnapshot(_db.read(_path))));

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
  _FakeSnapshot(this.value);

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

/// コード`1234`が`room-1`を指し、そのstatusが[status]のRTDBを作る。
///
/// [status]がnullなら`meta/status`自体が無い状態(書き込み途中など)。
/// [endsAt]はゲームの終了時刻(未設定なら待機中でまだ始まっていない)。
/// [serverTimeOffset]は端末時計とサーバー時刻のズレ。
Map<String, Object?> _rtdbWith({
  String? status = 'WAITING',
  int? endsAt,
  int serverTimeOffset = 0,
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
        deviceId: 'device-1',
      );

      expect(roomId, 'room-1');
      final me = _usersOf(db)!['me']! as Map<String, Object?>;
      expect(me['displayName'], 'たろう');
      expect(me['deviceId'], 'device-1');
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
          deviceId: 'device-1',
        ),
        throwsA(RoomJoinError.finished),
      );

      // 参加者として残ってしまうと、他の端末の一覧にも出てしまう。
      expect(_usersOf(db), isNull);
    });

    test('存在しないコードはnotFoundになり、ルームを読みにいかない', () async {
      final db = _FakeDatabase(_rtdbWith());
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      await expectLater(
        repo.joinRoom(
          code: '9999',
          displayName: 'たろう',
          deviceId: 'device-1',
        ),
        throwsA(RoomJoinError.notFound),
      );

      expect(_usersOf(db), isNull);
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
          deviceId: 'device-1',
        ),
        throwsA(RoomJoinError.notFound),
      );

      expect(_usersOf(db), isNull);
    });

    test('進行中のルームには従来どおり途中参加できる', () async {
      final db = _FakeDatabase(_rtdbWith(status: 'PLAYING'));
      final repo = RoomRepository(db: db, auth: _FakeAuth());

      expect(
        await repo.joinRoom(
          code: '1234',
          displayName: 'たろう',
          deviceId: 'device-1',
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
          deviceId: 'device-1',
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
            deviceId: 'device-1',
          ),
        ),
        throwsA(RoomJoinError.finished),
      );

      expect(_usersOf(db), isNull);
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
            deviceId: 'device-1',
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
            deviceId: 'device-1',
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
            deviceId: 'device-1',
          ),
        ),
        'room-1',
      );
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
