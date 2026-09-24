import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  test('204で成功する(再送しない)', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      expect(request.method, 'PUT');
      expect(request.headers['Authorization'], 'Bearer token1');
      expect(request.headers['Content-Type'], 'image/jpeg');
      return http.Response('', 204);
    });

    final repository = PhotoRepository(
      client: client,
      getIdToken: (forceRefresh) async {
        expect(forceRefresh, isFalse);
        return 'token1';
      },
    );

    await repository.upload(roomId: 'room1', photoId: 'photo1', bytes: bytes);

    expect(callCount, 1);
  });

  test('409は成功として扱う(冪等な再送)', () async {
    final client = MockClient((request) async => http.Response('', 409));

    final repository = PhotoRepository(
      client: client,
      getIdToken: (forceRefresh) async => 'token1',
    );

    await repository.upload(roomId: 'room1', photoId: 'photo1', bytes: bytes);
  });

  test('413は再送せずPhotoTooLargeExceptionを投げる', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response('', 413);
    });

    final repository = PhotoRepository(
      client: client,
      getIdToken: (forceRefresh) async => 'token1',
    );

    await expectLater(
      () => repository.upload(roomId: 'room1', photoId: 'photo1', bytes: bytes),
      throwsA(isA<PhotoTooLargeException>()),
    );
    expect(callCount, 1);
  });

  test('500はPhotoUploadFailedExceptionを投げる(再送しない)', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response('', 500);
    });

    final repository = PhotoRepository(
      client: client,
      getIdToken: (forceRefresh) async => 'token1',
    );

    await expectLater(
      () => repository.upload(roomId: 'room1', photoId: 'photo1', bytes: bytes),
      throwsA(isA<PhotoUploadFailedException>()),
    );
    expect(callCount, 1);
  });

  test('401はトークンを強制更新して1回だけ再送し、成功すれば成功扱い', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      if (callCount == 1) {
        expect(request.headers['Authorization'], 'Bearer token1');
        return http.Response('', 401);
      }
      expect(request.headers['Authorization'], 'Bearer token2');
      return http.Response('', 204);
    });

    final forceRefreshCalls = <bool>[];
    final repository = PhotoRepository(
      client: client,
      getIdToken: (forceRefresh) async {
        forceRefreshCalls.add(forceRefresh);
        return forceRefresh ? 'token2' : 'token1';
      },
    );

    await repository.upload(roomId: 'room1', photoId: 'photo1', bytes: bytes);

    expect(callCount, 2);
    expect(forceRefreshCalls, [false, true]);
  });

  test('401が再送後も401なら失敗し、再送は1回だけ', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response('', 401);
    });

    final repository = PhotoRepository(
      client: client,
      getIdToken: (forceRefresh) async => 'token',
    );

    await expectLater(
      () => repository.upload(roomId: 'room1', photoId: 'photo1', bytes: bytes),
      throwsA(isA<PhotoUploadFailedException>()),
    );
    expect(callCount, 2);
  });

  group('download', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('photo_repository_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('200で取得し、2回目はキャッシュを使いネットワークへ行かない', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer token1');
        return http.Response.bytes(bytes, 200);
      });

      final repository = PhotoRepository(
        client: client,
        getIdToken: (forceRefresh) async => 'token1',
        cacheDirectory: () async => tempDir,
      );

      final first = await repository.download(
        roomId: 'room1',
        photoId: 'photo1',
      );
      expect(first, bytes);
      expect(callCount, 1);

      final second = await repository.download(
        roomId: 'room1',
        photoId: 'photo1',
      );
      expect(second, bytes);
      expect(callCount, 1); // ネットワークへ再度行っていない。
    });

    test('401はトークンを強制更新して1回だけ再送し、成功すれば取得できる', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          expect(request.headers['Authorization'], 'Bearer token1');
          return http.Response('', 401);
        }
        expect(request.headers['Authorization'], 'Bearer token2');
        return http.Response.bytes(bytes, 200);
      });

      final forceRefreshCalls = <bool>[];
      final repository = PhotoRepository(
        client: client,
        getIdToken: (forceRefresh) async {
          forceRefreshCalls.add(forceRefresh);
          return forceRefresh ? 'token2' : 'token1';
        },
        cacheDirectory: () async => tempDir,
      );

      final result = await repository.download(
        roomId: 'room1',
        photoId: 'photo1',
      );

      expect(result, bytes);
      expect(callCount, 2);
      expect(forceRefreshCalls, [false, true]);
    });

    test('401が再送後も401ならPhotoDownloadFailedExceptionを投げる', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('', 401);
      });

      final repository = PhotoRepository(
        client: client,
        getIdToken: (forceRefresh) async => 'token',
        cacheDirectory: () async => tempDir,
      );

      await expectLater(
        () => repository.download(roomId: 'room1', photoId: 'photo1'),
        throwsA(isA<PhotoDownloadFailedException>()),
      );
      expect(callCount, 2);
    });

    test('404はPhotoDownloadFailedExceptionを投げる(再送しない)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('', 404);
      });

      final repository = PhotoRepository(
        client: client,
        getIdToken: (forceRefresh) async => 'token',
        cacheDirectory: () async => tempDir,
      );

      await expectLater(
        () => repository.download(roomId: 'room1', photoId: 'photo1'),
        throwsA(isA<PhotoDownloadFailedException>()),
      );
      expect(callCount, 1);
    });

    test('clearCacheForRoomは指定したroomのキャッシュだけ削除する', () async {
      final client = MockClient(
        (request) async => http.Response.bytes(bytes, 200),
      );

      final repository = PhotoRepository(
        client: client,
        getIdToken: (forceRefresh) async => 'token',
        cacheDirectory: () async => tempDir,
      );

      await repository.download(roomId: 'room1', photoId: 'photo1');
      await repository.download(roomId: 'room2', photoId: 'photo1');

      await repository.clearCacheForRoom('room1');

      final remaining = await tempDir
          .list()
          .map((e) => e.uri.pathSegments.last)
          .toList();
      expect(remaining, ['room2_photo1.jpg']);
    });
  });
}
