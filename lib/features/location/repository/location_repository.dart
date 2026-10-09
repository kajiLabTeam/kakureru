import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kakureru/features/location/model/location_sample.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_smoothing.dart';
import 'package:kakureru/features/location/repository/location_task_handler.dart';
import 'package:kakureru/features/map/repository/grid_snap.dart';

class LocationRepository {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  DataCallback? _taskDataCallback;

  /// 採用判定(accuracy足切り・デッドバンド・強制更新・古い測位の破棄)の
  /// 状態。[startSendingLocation]のたびに作り直し、前のゲームの基準を
  /// 持ち越さない。
  LocationUpdateFilter _filter = LocationUpdateFilter(
    startedAt: DateTime.now(),
  );

  /// 自分が他人に見せているマス。境目のちらつき対策(stableGridCell)の
  /// 「前回のマス」で、自分の分だけ持つ。[startSendingLocation]で捨てる。
  GridCell? _shownCell;

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
  ///
  /// Foreground Serviceを起動できたかどうかを返す。起動に失敗しても例外は
  /// 投げないが、ここでfalseを握りつぶすと「送信中と表示されたまま1件も
  /// 送られない」無音の失敗になる(issue #66)ため、呼び出し側は必ず戻り値を
  /// 見て画面へ反映すること。
  Future<bool> startSendingLocation(String roomId) async {
    await stopSendingLocation();
    _filter = LocationUpdateFilter(startedAt: DateTime.now());
    _shownCell = null;

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
      final altitude = data['altitude'];
      final timestamp = data['timestamp'];
      // lat/lngが欠けたデータをRTDBへ書くと、他の参加者のwatchLocationsが
      // UserLocation.fromMapの型キャストで例外を出し続けるため、ここで弾く。
      if (lat is! num || lng is! num) return;
      if (accuracy != null && accuracy is! num) return;

      // GPSノイズで実際には静止しているのにピンが飛び回るのを防ぐため、
      // accuracyが悪い測位・デッドバンド未満の移動はRTDBへ書き込まない
      // (issue #46)。取得順が入れ替わった古い測位も捨てる(issue #117)。
      // 判定と状態の持ち方はlocation_smoothing.dartのLocationUpdateFilter
      // にテスト可能な形で切り出してある。
      // 棄却が続いたまま何も書かないと、屋内で精度が慢性的に悪い人の
      // lat/lngがRTDBに一度も現れず、その人の気圧・Wi-Fi情報まで他の参加者
      // から見えなくなるため、一定回数/一定時間で強制的に1件採用する。
      // そのとき書くのは棄却していた間で最も精度の良い測位(issue #117)。
      final sample = LocationSample(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        altitude: altitude is num ? altitude.toDouble() : null,
        accuracy: (accuracy as num?)?.toDouble(),
        timestampMs: timestamp is int ? timestamp : null,
      );
      // 屋内外の誤差の違いを後で見るための記録。表示には使わない。RTDBには
      // 書かず(Spark枠)、棄却される測位も含めて毎回ログに残す。
      debugPrint(
        '[LocationRepository] 測位 accuracy=${sample.accuracy}m',
      );
      final now = DateTime.now();
      final rejectionsBefore = _filter.consecutiveRejections;
      final elapsedBefore = now.difference(_filter.lastAcceptedAt).inSeconds;
      final result = _filter.offer(sample, now: now);
      final toWrite = result.toWrite;
      if (toWrite == null) {
        // 黙って捨てると現地で原因を追えないため、理由と値を残す。
        debugPrint(
          '[LocationRepository] 測位を棄却(${result.decision.name}): '
          'accuracy=${sample.accuracy} lat=$lat lng=$lng '
          '連続棄却=${_filter.consecutiveRejections}回 '
          '最終採用からの経過=$elapsedBefore秒',
        );
        return;
      }
      if (result.decision == LocationUpdateDecision.acceptedByFallback) {
        debugPrint(
          '[LocationRepository] 棄却が続いたため強制採用: '
          '今回accuracy=${sample.accuracy} '
          '採用したaccuracy=${toWrite.accuracy} '
          '連続棄却=$rejectionsBefore回 '
          '最終採用からの経過=$elapsedBefore秒',
        );
      }

      // 他人に見せる位置は、採用した測位のときだけ丸め直す(マーカーを
      // 組み立てるたびには計算しない)。前回のマスを渡して境目のちらつきを
      // 止める。生のlat/lngは判定に使うのでそのまま書く。
      final cell = stableGridCell(
        lat: toWrite.latitude,
        lng: toWrite.longitude,
        previous: _shownCell,
      );
      _shownCell = cell;
      final center = gridCenterOf(cell.x, cell.y);

      // set()だとlocations/{uid}ノード全体を置き換えてしまい、同じノードの
      // 子であるpressure(PressureRepository)・wifiScan(WifiScanRepository)を
      // 4秒ごとに消してしまう(issue #8)。update()にして自分が持つキーだけを
      // 書き換え、他リポジトリが書いた兄弟キーには触れないようにする。
      // 4秒ごとのコールバックなので書き込みの完了は待たない。
      unawaited(
        _db.ref('rooms/$roomId/locations/$_uid').update({
          'lat': toWrite.latitude,
          'lng': toWrite.longitude,
          'altitude': toWrite.altitude,
          'accuracy': toWrite.accuracy,
          'snapLat': center.lat,
          'snapLng': center.lng,
          'updatedAt': ServerValue.timestamp,
        }),
      );
    };
    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback!);

    final result = await FlutterForegroundTask.startService(
      serviceId: 1000,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'kakureru',
      notificationText: '位置情報を送信しています',
      callback: startLocationTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      debugPrint('[LocationRepository] startService失敗: ${result.error}');
      // 起動できていないのでコールバックだけ残しても届くデータは無い。
      // 次のstartSendingLocation()で重複登録されないよう外しておく。
      FlutterForegroundTask.removeTaskDataCallback(_taskDataCallback!);
      _taskDataCallback = null;
      return false;
    }
    return true;
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
