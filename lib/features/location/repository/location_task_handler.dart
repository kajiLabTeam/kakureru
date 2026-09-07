import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

/// Foreground Service側で別isolateとして動く TaskHandler。
///
/// このisolateではFirebaseを呼ばない。Firebaseプラグインをバックグラウンド
/// isolateで初期化・使用するのは前例が少なく壊れやすいため、位置情報の取得と
/// RTDBへの書き込みの責務を分離している。ここでは位置を取得して
/// [FlutterForegroundTask.sendDataToMain] でメインisolate
/// (`LocationRepository`)へ渡すだけにし、実際のFirebase書き込みは
/// 従来通り動作確認済みのメインisolate側で行う。
///
/// 位置取得とログ出力はコンストラクタで差し替えられるようにしてある
/// (テストでは実機のGPSを使わずに、連続失敗回数の数え方だけを検証するため。
/// BlePermissionService・LocationPermissionServiceと同じ注入の形に揃えた)。
class LocationTaskHandler extends TaskHandler {
  /// 引数を省略すると実際のプラグイン(geolocator)と [debugPrint] を使う。
  /// テストからのみ差し替える。
  LocationTaskHandler({
    Future<Position> Function()? getCurrentPosition,
    void Function(String message)? log,
  }) : _getCurrentPosition = getCurrentPosition ?? _getWithGeolocator,
       _log = log ?? _logWithDebugPrint;

  final Future<Position> Function() _getCurrentPosition;
  final void Function(String message) _log;

  static Future<Position> _getWithGeolocator() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  static void _logWithDebugPrint(String message) => debugPrint(message);

  /// 直近で連続して失敗した回数。1回ごとの失敗は電波状況等で普通に起き
  /// うるため騒がず、連続失敗が積み上がったときだけログで検知できるように
  /// する。取得できた時点で0に戻す。
  int _consecutiveFailures = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 1回失敗しても次の周期で再試行するだけなので完了は待たない
    // (待つと取得にかかった時間だけ送信間隔が伸びてしまう)。
    unawaited(sendCurrentPosition());
  }

  /// 位置を1回取得してメインisolateへ渡す。取得に失敗しても例外は投げ返さず、
  /// 連続失敗回数を添えてログに残すだけにする(次の [onRepeatEvent] で再試行)。
  ///
  /// [onRepeatEvent] は完了を待たないため、失敗の数え方をテストから検証
  /// できるようこのメソッドを公開している(テスト専用の入口)。
  @visibleForTesting
  Future<void> sendCurrentPosition() async {
    try {
      final position = await _getCurrentPosition();
      _consecutiveFailures = 0;
      FlutterForegroundTask.sendDataToMain({
        'lat': position.latitude,
        'lng': position.longitude,
        'altitude': position.altitude,
      });
    } on Object catch (e) {
      _consecutiveFailures++;
      // 取得失敗時は今回はスキップし、次のonRepeatEventで再試行する。
      // ログだけは残し、連続失敗が続いていることを追えるようにする。
      _log('[LocationTaskHandler] 位置取得に失敗($_consecutiveFailures回連続): $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Foreground Service起動時に呼ばれるトップレベル関数。
/// PluginUtilities.getCallbackHandle の制約上、トップレベル関数(またはstatic)
/// である必要があり、@pragma('vm:entry-point') も必須。
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}
