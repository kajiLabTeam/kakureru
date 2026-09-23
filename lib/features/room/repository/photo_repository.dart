import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/photo_download_decision.dart';
import 'package:kakureru/features/room/photo_upload_decision.dart';
import 'package:path_provider/path_provider.dart';

/// 写真アップロードが413(サイズ超過)で失敗したことを表す。
///
/// 再試行しても直る見込みが薄いため、呼び出し側([PhotoRepository]の外、
/// 撮影のview_model)はこれを検知したら指数バックオフの再試行をせずに
/// 終了させる。
class PhotoTooLargeException implements Exception {
  @override
  String toString() => 'PhotoTooLargeException';
}

/// 413以外の理由でアップロードに失敗したことを表す
/// (401を強制更新して再送した後も失敗した場合を含む)。
///
/// ネットワーク瞬断や5xxを想定しており、呼び出し側は指数バックオフで
/// 再試行してよい。
class PhotoUploadFailedException implements Exception {
  PhotoUploadFailedException(this.message);

  final String message;

  @override
  String toString() => 'PhotoUploadFailedException: $message';
}

/// 写真ダウンロードに失敗したことを表す
/// (401を強制更新して再送した後も失敗した場合を含む)。
///
/// 呼び出し側(一覧画面)はこれを検知したら再読み込みボタン付きの
/// プレースホルダーを表示する。
class PhotoDownloadFailedException implements Exception {
  PhotoDownloadFailedException(this.message);

  final String message;

  @override
  String toString() => 'PhotoDownloadFailedException: $message';
}

/// 写真をCloudflare Workers経由のR2へアップロードするリポジトリ
/// (`kakureru-photo-api`, docs/photo-storage.md参照)。
///
/// RTDBへのメタデータ(`rooms/{roomId}/photos/{photoId}`等)の書き込みは
/// ここでは行わない。アップロード成功後にRTDBへ書くという順序は撮影の
/// view_model側の責務とし、このリポジトリはHTTP通信だけに専念する。
class PhotoRepository {
  /// [client]・[getIdToken]を省略すると実際の`http.Client`/`FirebaseAuth`を
  /// 使う。テストからのみ差し替える。
  ///
  /// `FirebaseAuth`/`User`はコンストラクタが非公開でテストダブルを作れない
  /// ため、「IDトークンを取る」という振る舞いだけを関数として注入できる形に
  /// している(401時の強制更新→再送のテストを、Firebase本体なしで書くため。
  /// `room_repository.dart`の`late final`遅延解決と同じ考え方)。
  /// [cacheDirectory]はダウンロードしたJPEGの保存先を差し替えるためのもの
  /// (テストから一時ディレクトリを注入する。本番は`getTemporaryDirectory()`
  /// 配下の`photo_cache`を使う)。
  PhotoRepository({
    http.Client? client,
    Future<String?> Function(bool forceRefresh)? getIdToken,
    Future<Directory> Function()? cacheDirectory,
  }) : _clientOverride = client,
       _getIdTokenOverride = getIdToken,
       _cacheDirectoryOverride = cacheDirectory;

  final http.Client? _clientOverride;
  final Future<String?> Function(bool forceRefresh)? _getIdTokenOverride;
  final Future<Directory> Function()? _cacheDirectoryOverride;

  late final http.Client _client = _clientOverride ?? http.Client();
  late final Future<String?> Function(bool forceRefresh) _getIdToken =
      _getIdTokenOverride ?? _defaultGetIdToken;
  late final Future<Directory> Function() _getCacheRootDirectory =
      _cacheDirectoryOverride ?? _defaultCacheDirectory;

  static Future<String?> _defaultGetIdToken(bool forceRefresh) {
    return FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh) ??
        Future.value(null);
  }

  static Future<Directory> _defaultCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/photo_cache');
  }

  /// キャッシュディレクトリの上限(約200MB)。超えたら古いものから削除する。
  static const int _maxCacheBytes = 200 * 1024 * 1024;

  /// `rooms/{roomId}/photos/{photoId}` へ画像を1枚アップロードする。
  ///
  /// 204/409は成功として扱う(冪等な再送。[judgePhotoUploadStatusCode]参照)。
  /// 401はIDトークンを強制更新して1回だけ再送し、それでも失敗なら
  /// [PhotoUploadFailedException]を投げる。413は再送せず
  /// [PhotoTooLargeException]を投げる。
  Future<void> upload({
    required String roomId,
    required String photoId,
    required Uint8List bytes,
  }) async {
    debugPrint(
      '[PhotoRepository.upload] start roomId=$roomId photoId=$photoId '
      'bytes=${bytes.length}',
    );

    final token = await _getIdToken(false);
    final firstResponse = await _put(
      roomId: roomId,
      photoId: photoId,
      bytes: bytes,
      token: token,
    );
    final firstOutcome = judgePhotoUploadStatusCode(firstResponse.statusCode);

    switch (firstOutcome) {
      case PhotoUploadOutcome.success:
        debugPrint(
          '[PhotoRepository.upload] 成功 status=${firstResponse.statusCode}',
        );
        return;
      case PhotoUploadOutcome.tooLarge:
        throw PhotoTooLargeException();
      case PhotoUploadOutcome.otherFailure:
        throw PhotoUploadFailedException('status=${firstResponse.statusCode}');
      case PhotoUploadOutcome.unauthorized:
        break; // 下で1回だけ再送する。
    }

    debugPrint('[PhotoRepository.upload] 401のためトークンを強制更新して再送');
    final refreshedToken = await _getIdToken(true);
    final retryResponse = await _put(
      roomId: roomId,
      photoId: photoId,
      bytes: bytes,
      token: refreshedToken,
    );
    final retryOutcome = judgePhotoUploadStatusCode(retryResponse.statusCode);

    switch (retryOutcome) {
      case PhotoUploadOutcome.success:
        debugPrint(
          '[PhotoRepository.upload] 再送で成功 status=${retryResponse.statusCode}',
        );
        return;
      case PhotoUploadOutcome.tooLarge:
        throw PhotoTooLargeException();
      case PhotoUploadOutcome.unauthorized:
      case PhotoUploadOutcome.otherFailure:
        throw PhotoUploadFailedException(
          '再送後も失敗 status=${retryResponse.statusCode}',
        );
    }
  }

  Future<http.Response> _put({
    required String roomId,
    required String photoId,
    required Uint8List bytes,
    required String? token,
  }) {
    final uri = Uri.parse('$photoApiBaseUrl/rooms/$roomId/photos/$photoId');
    return _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer ${token ?? ''}',
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    );
  }

  /// `rooms/{roomId}/photos/{photoId}` の画像本体を1枚取得する。
  ///
  /// 端末に保存済みなら(保存オブジェクトは不変なので)ネットワークへ行かず
  /// キャッシュから返す。未保存なら取得してキャッシュに保存する。401は
  /// IDトークンを強制更新して1回だけ再送し、それでも失敗なら
  /// [PhotoDownloadFailedException]を投げる。
  ///
  /// 呼び出し側は「見られる」と判定した写真だけをこのメソッドに渡すこと
  /// (このメソッド自体は可視性を判定しない)。
  Future<Uint8List> download({
    required String roomId,
    required String photoId,
  }) async {
    final file = await _cacheFile(roomId: roomId, photoId: photoId);
    if (await file.exists()) {
      debugPrint(
        '[PhotoRepository.download] キャッシュ命中 roomId=$roomId photoId=$photoId',
      );
      return file.readAsBytes();
    }

    debugPrint(
      '[PhotoRepository.download] start roomId=$roomId photoId=$photoId',
    );

    final token = await _getIdToken(false);
    final firstResponse = await _get(
      roomId: roomId,
      photoId: photoId,
      token: token,
    );
    final firstOutcome = judgePhotoDownloadStatusCode(
      firstResponse.statusCode,
    );

    switch (firstOutcome) {
      case PhotoDownloadOutcome.success:
        return _saveToCache(file, firstResponse.bodyBytes);
      case PhotoDownloadOutcome.otherFailure:
        throw PhotoDownloadFailedException(
          'status=${firstResponse.statusCode}',
        );
      case PhotoDownloadOutcome.unauthorized:
        break; // 下で1回だけ再送する。
    }

    debugPrint('[PhotoRepository.download] 401のためトークンを強制更新して再送');
    final refreshedToken = await _getIdToken(true);
    final retryResponse = await _get(
      roomId: roomId,
      photoId: photoId,
      token: refreshedToken,
    );
    final retryOutcome = judgePhotoDownloadStatusCode(
      retryResponse.statusCode,
    );

    switch (retryOutcome) {
      case PhotoDownloadOutcome.success:
        return _saveToCache(file, retryResponse.bodyBytes);
      case PhotoDownloadOutcome.unauthorized:
      case PhotoDownloadOutcome.otherFailure:
        throw PhotoDownloadFailedException(
          '再送後も失敗 status=${retryResponse.statusCode}',
        );
    }
  }

  Future<http.Response> _get({
    required String roomId,
    required String photoId,
    required String? token,
  }) {
    final uri = Uri.parse('$photoApiBaseUrl/rooms/$roomId/photos/$photoId');
    return _client.get(uri, headers: {'Authorization': 'Bearer ${token ?? ''}'});
  }

  Future<Directory> _cacheDirectory() async {
    final dir = await _getCacheRootDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _cacheFile({
    required String roomId,
    required String photoId,
  }) async {
    final dir = await _cacheDirectory();
    return File('${dir.path}/${roomId}_$photoId.jpg');
  }

  Future<Uint8List> _saveToCache(File file, Uint8List bytes) async {
    await file.writeAsBytes(bytes, flush: true);
    await _evictIfOverBudget();
    return bytes;
  }

  /// キャッシュ全体が[_maxCacheBytes]を超えたら、更新日時が古いものから
  /// 削除して収める。
  Future<void> _evictIfOverBudget() async {
    final dir = await _cacheDirectory();
    final entries = <MapEntry<File, FileStat>>[];
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      entries.add(MapEntry(entity, stat));
      total += stat.size;
    }
    if (total <= _maxCacheBytes) return;

    entries.sort((a, b) => a.value.modified.compareTo(b.value.modified));
    for (final entry in entries) {
      if (total <= _maxCacheBytes) break;
      total -= entry.value.size;
      await entry.key.delete();
    }
  }

  /// ルーム終了時に、そのルームぶんのキャッシュだけを削除する。
  Future<void> clearCacheForRoom(String roomId) async {
    final dir = await _cacheDirectory();
    if (!await dir.exists()) return;
    final prefix = '${roomId}_';
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final fileName = entity.uri.pathSegments.last;
      if (fileName.startsWith(prefix)) {
        await entity.delete();
      }
    }
  }
}
