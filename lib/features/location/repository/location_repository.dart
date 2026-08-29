import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_task_handler.dart';

class LocationRepository {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  DataCallback? _taskDataCallback;

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
      // lat/lngが欠けたデータをRTDBへ書くと、他の参加者のwatchLocationsが
      // UserLocation.fromMapの型キャストで例外を出し続けるため、ここで弾く。
      if (lat is! num || lng is! num) return;
      // set()だとlocations/{uid}配下に別タイマーが書き込んだwifiScan/pressureを
      // 丸ごと上書きして消してしまう(docs/rtdb-schema.md「設計の意図」参照)ため、
      // update()で自分が持つキーだけを部分更新する。
      _db.ref('rooms/$roomId/locations/$_uid').update({
        'lat': lat,
        'lng': lng,
        'altitude': data['altitude'],
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
