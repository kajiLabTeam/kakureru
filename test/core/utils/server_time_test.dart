import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/server_time.dart';

/// `.info/serverTimeOffset`の購読だけを差し替えるfake。
///
/// FirebaseDatabaseはコンストラクタが非公開でテストダブルを渡せないため、
/// `implements` + `noSuchMethod`で`ref()`と`onValue`だけを実装する。
class _FakeDatabase implements FirebaseDatabase {
  _FakeDatabase(this.controller);

  final StreamController<DatabaseEvent> controller;
  final requestedPaths = <String>[];

  @override
  DatabaseReference ref([String? path]) {
    requestedPaths.add(path ?? '');
    return _FakeReference(controller.stream);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReference implements DatabaseReference {
  _FakeReference(this._stream);

  final Stream<DatabaseEvent> _stream;

  @override
  Stream<DatabaseEvent> get onValue => _stream;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('fetchServerTimeOffset', () {
    test('届いたオフセットを返し、購読を解除する', () async {
      var cancelled = false;
      final controller = StreamController<DatabaseEvent>(
        onCancel: () => cancelled = true,
      );
      addTearDown(controller.close);
      final db = _FakeDatabase(controller);

      final future = fetchServerTimeOffset(db);
      controller.add(_FakeEvent(_FakeSnapshot(1500)));

      expect(await future, 1500);
      expect(db.requestedPaths, ['.info/serverTimeOffset']);
      expect(cancelled, isTrue);
    });

    test('届かなければオフセット0にフォールバックし、購読を解除する', () async {
      // 取得できないときに参加そのものを止めてしまわないための経路。
      // 購読を解除しないと`.info`の購読が宙に浮いたままになる。
      var cancelled = false;
      final controller = StreamController<DatabaseEvent>(
        onCancel: () => cancelled = true,
      );
      addTearDown(controller.close);

      final offset = await fetchServerTimeOffset(
        _FakeDatabase(controller),
        timeout: const Duration(milliseconds: 20),
      );

      expect(offset, 0);
      expect(cancelled, isTrue);
    });
  });
}
