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

  /// 短縮uidごとに、最後に流した検知の受信時刻。[freshDetections]が
  /// 同じ受信を二度流さないために使う。スキャンを張り直しても消さない
  /// (時刻は絶対値なので、前のスキャンの結果が流れ込んでも弾ける)。
  final Map<String, int> _lastEmittedAtMillis = {};

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
      final detections = freshDetections(
        [
          for (final result in results)
            (
              payload: result
                  .advertisementData
                  .manufacturerData[BleProximityThresholds.manufacturerId],
              rssi: result.rssi,
              receivedAtMillis: result.timeStamp.millisecondsSinceEpoch,
            ),
        ],
        lastEmittedAtMillis: _lastEmittedAtMillis,
      );
      detections.forEach(_detectionController.add);
    });

    unawaited(
      FlutterBluePlus.startScan(
        continuousUpdates: true,
        withMsd: [MsdFilter(BleProximityThresholds.manufacturerId)],
      ),
    );
  }

  /// ゲーム画面を離れる時に呼ぶこと。
  void stopScanning() {
    unawaited(_scanSub?.cancel());
    _scanSub = null;
    unawaited(FlutterBluePlus.stopScan());
  }

  void dispose() {
    stopScanning();
    unawaited(stopAdvertising());
    unawaited(_detectionController.close());
  }
}

/// スキャン結果1件ぶん(プラグインの型から、判定に要る値だけを抜いたもの)。
typedef BleScanSample = ({
  /// 広告のmanufacturerData(自分たちのmanufacturerIdのもの)。無ければnull。
  List<int>? payload,
  int rssi,

  /// その広告を実際に受信した時刻(端末の時計)。
  int receivedAtMillis,
});

/// スキャン結果の一覧から、流すべき検知を作る(純粋な計算)。
///
/// flutter_blue_plusの`onScanResults`は、スキャンを始めてから見えた相手
/// **全員の累積リスト**を、誰かの広告を受け取るたびに流す。以前はリストの
/// 全員に「いま」の時刻を付けていたため、圏外に出た相手も、ほかの端末の
/// 広告が届くたびに「いま近くにいる」扱いになり、その場にいない相手に
/// 「捕まえた」が押せてしまった。
///
/// - 時刻は、その相手の広告を実際に受信した時刻(`ScanResult.timeStamp`)を使う
/// - 前に流したときから受信時刻が進んでいない相手は流さない(同じ受信を
///   何度も流すと、RSSIの中央値が古い値に引っぱられるため)
/// - 自分たちの広告でない・読めないものは捨てる
///
/// [lastEmittedAtMillis]は流した時刻で書き換える。
List<BleDetection> freshDetections(
  List<BleScanSample> samples, {
  required Map<String, int> lastEmittedAtMillis,
}) {
  final detections = <BleDetection>[];
  for (final sample in samples) {
    final shortUid = decodeAdvertisePayload(sample.payload);
    if (shortUid == null) continue;
    final last = lastEmittedAtMillis[shortUid];
    if (last != null && sample.receivedAtMillis <= last) continue;
    lastEmittedAtMillis[shortUid] = sample.receivedAtMillis;
    detections.add(
      BleDetection(
        shortUid: shortUid,
        rssiDbm: sample.rssi,
        detectedAtMillis: sample.receivedAtMillis,
      ),
    );
  }
  return detections;
}
