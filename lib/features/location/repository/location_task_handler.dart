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
/// ## 取得方式(issue #117)
///
/// 以前は4秒ごとに `Geolocator.getCurrentPosition` で単発取得していた。
/// Androidの実装は、呼ぶたびにFusedLocationProviderへ新規リクエストを出し、
/// **最初に返ってきた1件**を返して止める。最初の1件はWi-Fi/基地局由来の
/// 粗い位置や端末キャッシュであることが多く、GNSSが安定追尾に入る前の
/// 値を毎回拾うため、同じ場所でも位置が前後にばらついていた。さらに
/// 完了を待たずに次の取得を始めていたため、取得が4秒を超えると並走し、
/// 完了順が入れ替わって古い位置が後から書かれることもあった。
///
/// そこで、サービス開始時に位置ストリームを購読してGNSSを連続追尾させ、
/// [onRepeatEvent](4秒)では**その時点で最新の測位を送るだけ**にした。
/// メインisolateへの送信間隔(=RTDBへの書き込み頻度)は変わらない。
///
/// 位置ストリーム・メインisolateへの送信・ログ出力はコンストラクタで
/// 差し替えられるようにしてある(テストでは実機のGPSを使わずに検証するため。
/// BlePermissionService・LocationPermissionServiceと同じ注入の形に揃えた)。
class LocationTaskHandler extends TaskHandler {
  /// 引数を省略すると実際のプラグイン(geolocator・flutter_foreground_task)と
  /// [debugPrint] を使う。テストからのみ差し替える。
  LocationTaskHandler({
    Stream<Position> Function()? positionStream,
    void Function(Map<String, Object?> data)? sendData,
    void Function(String message)? log,
  }) : _positionStream = positionStream ?? _streamWithGeolocator,
       _sendData = sendData ?? FlutterForegroundTask.sendDataToMain,
       _log = log ?? _logWithDebugPrint;

  final Stream<Position> Function() _positionStream;
  final void Function(Map<String, Object?> data) _sendData;
  final void Function(String message) _log;

  /// 位置ストリームに求める更新間隔。送信間隔(4秒)より短くして、
  /// 送信のたびに新しい測位が1件以上そろっているようにする。
  static const updateInterval = Duration(seconds: 2);

  static Stream<Position> _streamWithGeolocator() {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        // distanceFilterは既定の0のまま、距離による間引きはしない(静止中の
        // ノイズ抑制はメインisolate側のデッドバンドで行う。ここで間引くと
        // 更新が止まり、強制更新の判定材料も届かなくなる)。
        intervalDuration: updateInterval,
      ),
    );
  }

  static void _logWithDebugPrint(String message) => debugPrint(message);

  StreamSubscription<Position>? _subscription;

  /// ストリームから受け取った最新の測位。まだ1件も来ていなければnull。
  Position? _latest;

  /// 最後にメインisolateへ送った測位の時刻。同じ測位を二重に送らないため。
  DateTime? _lastSentTimestamp;

  /// 直近で連続して失敗した回数。1回ごとの失敗は電波状況等で普通に起き
  /// うるため騒がず、連続失敗が積み上がったときだけログで検知できるように
  /// する。測位が届いた時点で0に戻す。
  int _consecutiveFailures = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    startListening();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // ストリームがエラーや終了で止まっていたら、ここで張り直す。
    startListening();
    sendLatestPosition();
  }

  /// 位置ストリームの購読を始める。すでに購読中なら何もしない。
  @visibleForTesting
  void startListening() {
    if (_subscription != null) return;
    try {
      _subscription = _positionStream().listen(
        (position) {
          _consecutiveFailures = 0;
          _latest = position;
        },
        onError: _onError,
        onDone: () => _subscription = null,
      );
    } on Object catch (e) {
      _onError(e);
    }
  }

  void _onError(Object error) {
    _consecutiveFailures++;
    // 購読を捨てて、次のonRepeatEventで張り直す。ログは残し、連続失敗が
    // 続いていることを追えるようにする。
    unawaited(_subscription?.cancel());
    _subscription = null;
    _log('[LocationTaskHandler] 位置取得に失敗($_consecutiveFailures回連続): $error');
  }

  /// 最新の測位をメインisolateへ渡す。まだ測位が無い、または前回送った
  /// ものから新しい測位が来ていなければ何もしない。
  @visibleForTesting
  void sendLatestPosition() {
    final position = _latest;
    if (position == null) return;
    if (position.timestamp == _lastSentTimestamp) return;
    _lastSentTimestamp = position.timestamp;
    _sendData({
      'lat': position.latitude,
      'lng': position.longitude,
      'altitude': position.altitude,
      'accuracy': position.accuracy,
      // 取得順の逆転をメインisolate側で検出するための測位時刻。
      // RTDBには書かない。
      'timestamp': position.timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

/// Foreground Service起動時に呼ばれるトップレベル関数。
/// PluginUtilities.getCallbackHandle の制約上、トップレベル関数(またはstatic)
/// である必要があり、@pragma('vm:entry-point') も必須。
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}
