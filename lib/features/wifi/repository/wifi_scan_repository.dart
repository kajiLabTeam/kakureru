import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/core/utils/rtdb_write.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';
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

  /// 10秒間隔。Androidのスキャンスロットリング(2分に4回)を超えるが、
  /// 参加者は開発者オプションでスロットルを解除して遊ぶ前提のため許容する
  /// (AGENTS.md参照)。スキャン自体の所要時間(概ね1〜4秒)より短くしすぎると
  /// 前回のスキャン中に次のリクエストがスキップされるだけになるため、
  /// この間隔より大きく縮めても新鮮さは頭打ちになる(issue #8 追加調査:
  /// 「Wi-Fiデータが最大25秒遅れる」を短縮)。バッテリー消費とのトレードオフ
  /// でもあるため、実機で問題があれば長くすることを検討する。
  static const _scanInterval = Duration(seconds: 10);

  /// RTDBへ送るAP数の上限。都心部などAPが多い環境で書き込みサイズが
  /// 際限なく膨らむのを防ぐ。
  ///
  /// 以前は20件だったが、可視APが20件を超える環境では自分と相手それぞれが
  /// 独立にRSSI上位20件へ絞り込むため、実際にはほぼ同じ場所にいて元の
  /// BSSID集合がほぼ一致していても、境界付近(RSSI順位20位前後)のAPが
  /// 端末ごとのRSSI揺らぎで別々に足切りされ、Jaccard係数・共通AP数が
  /// 見かけ上大きく下がることがある(「近いのに遠い/検知なし」の一因。
  /// issue #45調査)。40件に増やして境界付近の食い違いの影響を抑える。
  static const _maxApCount = 40;

  /// 自分のスキャンの実行とRTDBへの書き込みだけを行う
  void startScanning(String roomId) {
    stopScanning();

    _resultsSub = WiFiScan.instance.onScannedResultsAvailable.listen((
      results,
    ) async {
      final bssidRssi = <String, int>{};
      for (final ap in results) {
        bssidRssi[ap.bssid] = ap.level;
      }
      final topBssidRssi = selectTopAccessPoints(bssidRssi, count: _maxApCount);
      await writeOrLogFailure(
        () => _db.ref('rooms/$roomId/locations/$_uid/wifiScan').set({
          'bssidRssi': topBssidRssi,
          'scannedAt': ServerValue.timestamp,
        }),
        tag: 'WifiScanRepository',
        field: 'wifiScan',
      );
    });

    _triggerScan();
    _scanTimer = Timer.periodic(_scanInterval, (_) => _triggerScan());
  }

  Future<void> _triggerScan() async {
    final can = await WiFiScan.instance.canStartScan();
    if (can != CanStartScan.yes) {
      // Androidのスキャンスロットリング(2分に4回)等でスキャンできない場合、
      // ここで黙ってスキップされるとwifiScanが古いまま更新されなくなる原因が
      // 実機ログからしか追えない。開発者オプションでのスロットル解除漏れを
      // 切り分けられるよう、スキップしたことだけは残す(issue #45調査)。
      debugPrint('[WifiScanRepository] scan skipped: canStartScan=$can');
      return;
    }
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
