import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiScanRepository {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  Timer? _scanTimer;
  StreamSubscription<List<WiFiAccessPoint>>? _resultsSub;

  WifiScanRepository({FirebaseDatabase? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseDatabase.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// 20〜30秒間隔。Androidのスキャンスロットリング(2分に4回)に対して
  /// 十分な余裕を持たせている。位置情報・気圧とは別のタイマーで動く。
  static const _scanInterval = Duration(seconds: 25);

  /// 同室メンバーのスキャン結果の購読は不要——wifiScanは
  /// UserLocationのフィールドなので、既存の LocationRepository.watchLocations
  /// (rooms/{roomId}/locations 購読)経由で他人の分も一緒に流れてくる。
  ///
  /// ここでは自分のスキャンの実行とRTDBへの書き込みだけを行う。
  void startScanning(String roomId) {
    stopScanning();

    _resultsSub = WiFiScan.instance.onScannedResultsAvailable.listen((results) {
      final bssidRssi = <String, int>{};
      for (final ap in results) {
        bssidRssi[ap.bssid] = ap.level;
      }
      _db.ref('rooms/$roomId/locations/$_uid/wifiScan').set({
        'bssidRssi': bssidRssi,
        'scannedAt': ServerValue.timestamp,
      });
    });

    _triggerScan();
    _scanTimer = Timer.periodic(_scanInterval, (_) => _triggerScan());
  }

  Future<void> _triggerScan() async {
    final can = await WiFiScan.instance.canStartScan();
    if (can != CanStartScan.yes) return;
    await WiFiScan.instance.startScan();
  }

  /// ゲーム画面を離れる時に呼ぶこと。
  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _resultsSub?.cancel();
    _resultsSub = null;
  }
}
