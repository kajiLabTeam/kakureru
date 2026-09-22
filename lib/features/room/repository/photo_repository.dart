import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/photo_upload_decision.dart';

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
  PhotoRepository({
    http.Client? client,
    Future<String?> Function(bool forceRefresh)? getIdToken,
  }) : _clientOverride = client,
       _getIdTokenOverride = getIdToken;

  final http.Client? _clientOverride;
  final Future<String?> Function(bool forceRefresh)? _getIdTokenOverride;

  late final http.Client _client = _clientOverride ?? http.Client();
  late final Future<String?> Function(bool forceRefresh) _getIdToken =
      _getIdTokenOverride ?? _defaultGetIdToken;

  static Future<String?> _defaultGetIdToken(bool forceRefresh) {
    return FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh) ??
        Future.value(null);
  }

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
}
