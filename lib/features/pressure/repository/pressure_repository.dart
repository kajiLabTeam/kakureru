import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:sensors_plus/sensors_plus.dart';

class PressureRepository {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  StreamSubscription<BarometerEvent>? _sensorSub;
  StreamController<double>? _smoothedController;
  MovingAverage? _movingAverage;
  double? _latestSmoothed;
  Timer? _writeTimer;

  PressureRepository({FirebaseDatabase? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseDatabase.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// 気圧センサーが使えるか判定する。
  ///
  /// sensors_plus に搭載有無を直接返すAPIが無いため、実際にイベントを
  /// 待ってみて、タイムアウト以内に1件でも来れば「使える」とみなす。
  Future<bool> checkSensorAvailable({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      await barometerEventStream().first.timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  }

  /// 自分の気圧(直近5件の移動平均で平滑化した値)を購読する。
  Stream<double> watchMyPressure() {
    final existing = _smoothedController;
    if (existing != null && !existing.isClosed) return existing.stream;

    final controller = StreamController<double>.broadcast();
    _smoothedController = controller;
    _movingAverage = MovingAverage(windowSize: 5);

    _sensorSub = barometerEventStream().listen((event) {
      final avg = _movingAverage!.add(event.pressure);
      _latestSmoothed = avg;
      controller.add(avg);
    });

    return controller.stream;
  }

  /// 直近の平滑化済み気圧(まだ取得できていなければnull)。
  double? get latestPressure => _latestSmoothed;

  /// rooms/{roomId}/locations/{uid}/pressure への定期送信を開始する。
  void startSendingToRoom(String roomId) {
    stopSendingToRoom();
    _writeTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final value = _latestSmoothed;
      if (value == null) return;
      try {
        await _db.ref('rooms/$roomId/locations/$_uid/pressure').set(value);
      } on Object catch (e) {
        debugPrint('[PressureRepository] pressureの書き込みに失敗: $e');
      }
    });
  }

  /// RTDBへの定期送信を止める。センサー自体の購読は続ける
  void stopSendingToRoom() {
    _writeTimer?.cancel();
    _writeTimer = null;
  }

  /// センサー購読を完全に止める。ルーム全体から離れる時に呼ぶこと。
  void disposeSensor() {
    stopSendingToRoom();
    _sensorSub?.cancel();
    _sensorSub = null;
    _smoothedController?.close();
    _smoothedController = null;
    _movingAverage = null;
    _latestSmoothed = null;
  }

  /// 気圧センサーの有無を、ホスト・参加者を把握できるようRTDBに記録する。
  /// 未搭載の端末はキャリブレーション不要であることを他の参加者にも
  /// 伝えるための情報で、必須では無いため失敗しても無視してよい。
  Future<void> reportSensorAvailability(
    String roomId, {
    required bool available,
  }) async {
    try {
      await _db
          .ref('rooms/$roomId/users/$_uid/pressureSensorAvailable')
          .set(available);
    } on Object {
      // 待機画面の表示が多少不正確になるだけで、キャリブレーション自体は
      // 可能なため致命的ではない。
    }
  }

  /// ホストが自分の気圧を基準値として書き込む。
  Future<void> calibrateAsHost(String roomId, double myPressureHPa) async {
    await _db.ref('rooms/$roomId/meta/basePressure').set(myPressureHPa);
  }

  /// 参加者が「自分の気圧 - 基準値」をoffsetとして書き込む。
  Future<void> calibrateAsParticipant(
    String roomId,
    double myPressureHPa,
    double basePressureHPa,
  ) async {
    await _db
        .ref('rooms/$roomId/users/$_uid/pressureOffset')
        .set(myPressureHPa - basePressureHPa);
  }
}
