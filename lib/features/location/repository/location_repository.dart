import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_smoothing.dart';
import 'package:kakureru/features/location/repository/location_task_handler.dart';

class LocationRepository {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  DataCallback? _taskDataCallback;

  /// 直近でRTDBへ採用・書き込んだ位置(デッドバンド判定の基準)。
  /// [startSendingLocation]のたびにリセットする。
  double? _lastAcceptedLat;
  double? _lastAcceptedLng;

  /// 直近で連続して棄却した回数と、最後に採用した時刻(強制更新の判定用)。
  /// [startSendingLocation]のたびにリセットする。まだ一度も採用していない
  /// 間は送信開始時刻を起点にすることで、「初回からずっとaccuracyが悪くて
  /// 一度も書き込まれない」ケースでも時間による強制更新が効く。
  int _consecutiveRejections = 0;
  DateTime _lastAcceptedAt = DateTime.now();

  LocationRepository({FirebaseDatabase? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseDatabase.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// 自分の位置を rooms/{roomId}/locations/{uid} へ継続送信する。
  ///
  /// ポケットに入れたまま遊ぶ運用のため、アプリがバックグラウンドでも
  /// 位置取得が止まらないよう Foreground Service(flutter_foreground_task)を使う。
  /// 実際の位置取得は [LocationTaskHandler] が別isolateで行い、取得した値を
  /// sendDataToMain 経由でここ(メインisolate)が受け取ってRTDBへ書き込む
  /// (Firebase呼び出しは既存の動作確認済みのメインisolate側に集約している)。
  /// 1秒間隔だと転送量が跳ねるため、更新間隔(onRepeatEvent)は4秒にしている。
  Future<void> startSendingLocation(String roomId) async {
    await stopSendingLocation();
    _lastAcceptedLat = null;
    _lastAcceptedLng = null;
    _consecutiveRejections = 0;
    _lastAcceptedAt = DateTime.now();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kakureru_location',
        channelName: '位置情報の送信',
        channelDescription: 'ゲーム中、自分の位置を他の参加者へ送信しています',
      ),
      // iOS非対応のプロジェクトだが init() が必須引数として要求するため、
      // 使われないダミー値として渡している。
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(4000),
      ),
    );

    _taskDataCallback = (data) {
      if (data is! Map) return;
      final lat = data['lat'];
      final lng = data['lng'];
      final accuracy = data['accuracy'];
      // lat/lngが欠けたデータをRTDBへ書くと、他の参加者のwatchLocationsが
      // UserLocation.fromMapの型キャストで例外を出し続けるため、ここで弾く。
      if (lat is! num || lng is! num) return;
      if (accuracy != null && accuracy is! num) return;

      // GPSノイズで実際には静止しているのにピンが飛び回るのを防ぐため、
      // accuracyが悪い測位・デッドバンド未満の移動はRTDBへ書き込まない
      // (issue #46)。判定ロジック自体はlocation_smoothing.dartにテスト
      // 可能な純粋関数として切り出してある。
      // ただし棄却が続いたまま何も書かないと、屋内で精度が慢性的に悪い人の
      // lat/lngがRTDBに一度も現れず、その人の気圧・Wi-Fi情報まで他の参加者
      // から見えなくなる(lat/lngを欠いたノードはUserLocation.fromMapで例外に
      // なり、watchLocationsがエントリごとスキップするため)。一定回数/一定
      // 時間で強制的に1件採用するフォールバックを入れてこれを防いでいる。
      final accuracyM = (accuracy as num?)?.toDouble();
      final now = DateTime.now();
      final decision = evaluateLocationUpdate(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        accuracy: accuracyM,
        previousLatitude: _lastAcceptedLat,
        previousLongitude: _lastAcceptedLng,
        consecutiveRejectionCount: _consecutiveRejections,
        elapsedSinceLastAccepted: now.difference(_lastAcceptedAt),
      );
      if (!decision.isAccepted) {
        _consecutiveRejections++;
        // 黙って捨てると現地で原因を追えないため、理由と値を残す。
        debugPrint(
          '[LocationRepository] 測位を棄却(${decision.name}): '
          'accuracy=$accuracyM lat=$lat lng=$lng '
          '連続棄却=$_consecutiveRejections回 '
          '最終採用からの経過=${now.difference(_lastAcceptedAt).inSeconds}秒',
        );
        return;
      }
      if (decision == LocationUpdateDecision.acceptedByFallback) {
        debugPrint(
          '[LocationRepository] 棄却が続いたため強制採用: '
          'accuracy=$accuracyM 連続棄却=$_consecutiveRejections回 '
          '最終採用からの経過=${now.difference(_lastAcceptedAt).inSeconds}秒',
        );
      }
      _lastAcceptedLat = lat.toDouble();
      _lastAcceptedLng = lng.toDouble();
      _consecutiveRejections = 0;
      _lastAcceptedAt = now;

      // set()だとlocations/{uid}ノード全体を置き換えてしまい、同じノードの
      // 子であるpressure(PressureRepository)・wifiScan(WifiScanRepository)を
      // 4秒ごとに消してしまう(issue #8)。update()にして自分が持つキーだけを
      // 書き換え、他リポジトリが書いた兄弟キーには触れないようにする。
      _db.ref('rooms/$roomId/locations/$_uid').update({
        'lat': lat,
        'lng': lng,
        'altitude': data['altitude'],
        'accuracy': accuracy,
        'updatedAt': ServerValue.timestamp,
      });
    };
    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback!);

    final result = await FlutterForegroundTask.startService(
      serviceId: 1000,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'かくれんぼ',
      notificationText: '位置情報を送信しています',
      callback: startLocationTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      debugPrint('[LocationRepository] startService失敗: ${result.error}');
    }
  }

  /// 位置送信を止める。ゲーム画面を離れる時に呼ぶこと。
  Future<void> stopSendingLocation() async {
    if (_taskDataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_taskDataCallback!);
      _taskDataCallback = null;
    }
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// 同じルームの全員の位置(自分を含む)を購読する。
  ///
  /// lat/lngが欠けた不正なエントリ(書き込み途中や過去の不具合の残骸)が
  /// 1件でもあると、そこで例外になり他の参加者の位置更新まで止まって
  /// しまうため、パースに失敗したエントリは1件ずつスキップする。
  Stream<List<UserLocation>> watchLocations(String roomId) {
    return _db.ref('rooms/$roomId/locations').onValue.map((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      return value.entries
          .map((e) {
            try {
              return UserLocation.fromMap(
                e.key.toString(),
                e.value as Map<dynamic, dynamic>,
              );
            } on Object {
              return null;
            }
          })
          .whereType<UserLocation>()
          .toList();
    });
  }
}
