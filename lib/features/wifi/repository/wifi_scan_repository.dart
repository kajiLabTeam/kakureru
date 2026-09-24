import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/core/utils/rtdb_write.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiScanRepository {
  Timer? _scanTimer;
  StreamSubscription<List<WiFiAccessPoint>>? _resultsSub;

  /// 引数を省略すると実際のFirebase(`FirebaseDatabase.instance` /
  /// `FirebaseAuth.instance`)を使う。テストからのみ差し替える。
  WifiScanRepository({FirebaseDatabase? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  final FirebaseDatabase? _dbOverride;
  final FirebaseAuth? _authOverride;

  // `.instance` の解決を遅延させる理由は RoomRepository・PressureRepository
  // と同じ(メソッドを丸ごとoverrideするテスト用のサブクラスが、暗黙の
  // `super()` を通るだけでFirebase未初期化の例外を踏まないようにするため)。
  // 詳しい経緯は room_repository.dart のコメントを参照。
  late final FirebaseDatabase _db = _dbOverride ?? FirebaseDatabase.instance;
  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;

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

    unawaited(triggerScan());
    _scanTimer = Timer.periodic(_scanInterval, (_) => unawaited(triggerScan()));
  }

  /// スキャンを1回要求し、その結果を[WifiScanStatus]で返す。
  ///
  /// 戻り値は待機画面の「Wi-Fiスキャン: 〜」表示にも使う(issue #98)。
  /// スロットリングは`canStartScan()`では分からない(`yes`のまま
  /// `startScan()`だけが失敗する)ため、実際に要求してみるところまでやって
  /// 初めて判定できる。待機画面から呼ぶとスロットルの回数(2分に4回)を1回
  /// 消費するが、解除し忘れを遊ぶ前に気づけることの方が大きい。
  Future<WifiScanStatus> triggerScan() async {
    final can = await WiFiScan.instance.canStartScan();
    if (can != CanStartScan.yes) {
      // 位置情報OFF・権限無し等でスキャンできない場合、ここで黙って
      // スキップされるとwifiScanが古いまま更新されなくなる原因が
      // 実機ログからしか追えない。切り分けられるよう、スキップしたこと
      // だけは残す(issue #45調査)。
      debugPrint('[WifiScanRepository] scan skipped: canStartScan=$can');
      return wifiScanStatusFromCanStartScan(can);
    }
    final started = await WiFiScan.instance.startScan();
    if (!started) {
      // 要求は通るのに実行されない主因はAndroidのスキャンスロットリング
      // (2分に4回)。開発者オプションでの解除漏れがここに出る。
      debugPrint('[WifiScanRepository] startScan failed (throttled?)');
      return WifiScanStatus.throttled;
    }
    return WifiScanStatus.ok;
  }

  /// ゲーム画面を離れる時に呼ぶこと。
  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _resultsSub?.cancel();
    _resultsSub = null;
  }
}
