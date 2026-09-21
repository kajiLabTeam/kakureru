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
/// (`ref()` / `get()` / `set()`)だけを実装する。未実装のメンバを呼んだ
/// 場合はNoSuchMethodErrorで落ちるので、テストが黙って通ることはない。
class _FakeDatabase implements FirebaseDatabase {
  _FakeDatabase(this.root);

  /// RTDBのツリーをネストしたMapで持つ。
  final Map<String, Object?> root;

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
  Future<DataSnapshot> get() async => _FakeSnapshot(_db.read(_path));

  @override
  Future<void> set(Object? value) async => _db.write(_path, value);

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

/// コード`1234`が`room-1`を指し、そのstatusが[status]のRTDBを作る。
/// [status]がnullなら`meta/status`自体が無い状態(書き込み途中など)。
Map<String, Object?> _rtdbWith({String? status = 'WAITING'}) => {
  'roomCodes': {
    '1234': {'roomId': 'room-1'},
  },
  'rooms': {
    'room-1': {
      'meta': {
        'roomCode': '1234',
        'hostUserId': 'host',
        'status': ?status,
      },
    },
  },
};

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

    test('statusが未設定のルームは待機中とみなして参加できる', () async {
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
