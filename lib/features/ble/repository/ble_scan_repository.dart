import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_proximity_calculator.dart';

/// BLEでの近接検知を担うリポジトリ。
///
/// Wi-Fi(既存インフラのAPの見え方を比較する方式)と違い、参加者同士が
/// 直接advertise(自分のuidを広告)/scan(相手の広告を受信)し合うP2P方式に
/// している。3m程度という至近距離の判定には、間接的な比較よりも相手を
/// 直接検知してRSSIから距離を推定する方が素直なため。
class BleScanRepository {
  BleScanRepository({FlutterBlePeripheral? peripheral})
    : _peripheral = peripheral ?? FlutterBlePeripheral();

  final FlutterBlePeripheral _peripheral;
  StreamSubscription<List<ScanResult>>? _scanSub;
  final _detectionController = StreamController<BleDetection>.broadcast();

  /// 検知結果のストリーム。同じ相手からでも受信のたびに流れるため、
  /// 受け手側(ViewModel)で短縮uidをキーに最新値を保持すること。
  Stream<BleDetection> get detections => _detectionController.stream;

  /// 自分のuidを広告し始める。ゲーム画面滞在中だけ行う。
  Future<void> startAdvertising(String uid) async {
    await _peripheral.start(
      advertiseData: AdvertiseData(
        manufacturerId: BleProximityThresholds.manufacturerId,
        manufacturerData: Uint8List.fromList(encodeAdvertisePayload(uid)),
      ),
    );
  }

  Future<void> stopAdvertising() async {
    await _peripheral.stop();
  }

  /// 他の参加者の広告のスキャンを始める。
  void startScanning() {
    stopScanning();

    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final result in results) {
        final payload = result
            .advertisementData
            .manufacturerData[BleProximityThresholds.manufacturerId];
        final shortUid = decodeAdvertisePayload(payload);
        if (shortUid == null) continue;
        _detectionController.add(
          BleDetection(
            shortUid: shortUid,
            rssiDbm: result.rssi,
            detectedAtMillis: now,
          ),
        );
      }
    });

    FlutterBluePlus.startScan(
      continuousUpdates: true,
      withMsd: [MsdFilter(BleProximityThresholds.manufacturerId)],
    );
  }

  /// ゲーム画面を離れる時に呼ぶこと。
  void stopScanning() {
    _scanSub?.cancel();
    _scanSub = null;
    unawaited(FlutterBluePlus.stopScan());
  }

  void dispose() {
    stopScanning();
    unawaited(stopAdvertising());
    unawaited(_detectionController.close());
  }
}
