import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// RTDBの代わりに、パス→値のツリーをメモリ上に持つだけの最小のfake。
///
/// `ref()` / `get()` / `set()` / `update()` / `push()` だけを実装する。
/// 未実装のメンバを呼ぶとNoSuchMethodErrorで落ちるので、テストが黙って
/// 通ることはない(room_repository_test.dartのfakeと同じ方針)。
class FakeRtdb implements FirebaseDatabase {
  FakeRtdb([Map<String, Object?>? root]) : root = root ?? {};

  final Map<String, Object?> root;

  int _pushCounter = 0;

  @override
  DatabaseReference ref([String? path]) => _FakeRef(this, path ?? '');

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
      final child = node[segment];
      final next = child is Map
          ? Map<String, Object?>.from(child)
          : <String, Object?>{};
      node[segment] = next;
      node = next;
    }
    if (value == null) {
      node.remove(segments.last);
    } else {
      node[segments.last] = value;
    }
  }

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRef implements DatabaseReference {
  _FakeRef(this._db, this._path);

  final FakeRtdb _db;
  final String _path;

  @override
  Future<DataSnapshot> get() async => _FakeSnapshot(_db.read(_path));

  @override
  Future<void> set(Object? value) async => _db.write(_path, value);

  @override
  Future<void> update(Map<String, Object?> value) async {
    for (final entry in value.entries) {
      _db.write('$_path/${entry.key}', entry.value);
    }
  }

  @override
  DatabaseReference push() => _FakeRef(_db, '$_path/${_db._pushCounter++}');

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
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `currentUser.uid`が[uid]になるだけのfake。
class FakeAuth implements FirebaseAuth {
  FakeAuth([this.uid = 'me']);

  final String uid;

  @override
  User? get currentUser => _FakeUser(uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
