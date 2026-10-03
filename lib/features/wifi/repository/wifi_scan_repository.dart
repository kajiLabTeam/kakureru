import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/core/utils/rtdb_write.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiScanRepository {
  Timer? _scanTimer;
  StreamSubscription<List<WiFiAccessPoint>>? _resultsSub;

  /// 引数を省略すると実際のFirebase(`FirebaseDatabase.instance` /
  /// `FirebaseAuth.instance`)を使う。テストからのみ差し替える。
  ///
  /// [readConnectedBssid]は接続中のWi-FiのBSSIDを返す関数(既定は
  /// `network_info_plus`)。これもテストからのみ差し替える。
  WifiScanRepository({
    FirebaseDatabase? db,
    FirebaseAuth? auth,
    Future<String?> Function()? readConnectedBssid,
  }) : _dbOverride = db,
       _authOverride = auth,
       _readConnectedBssid =
           readConnectedBssid ?? (() => NetworkInfo().getWifiBSSID());

  final FirebaseDatabase? _dbOverride;
  final FirebaseAuth? _authOverride;
  final Future<String?> Function() _readConnectedBssid;

  /// [startScanning]/[stopScanning]のたびに増える番号。[sendScan]の途中で
  /// 画面を離れたかどうかの判定に使う。
  int _session = 0;

  /// 直近に読めた自分の`users/{uid}/usesTethering`(待機画面の自己申告。
  /// issue #142)。値の持ち主はRTDBで、ここは読めなかったときの代わりに
  /// 覚えておくだけ。
  bool _lastUsesTethering = defaultUsesTethering;

  /// 直近に取れた自分のホットスポットのBSSID。1回取れなかっただけ(一瞬の
  /// 切断・構内Wi-Fiへのつなぎ替え等)で自分のホットスポットが`bssidRssi`に
  /// 戻らないよう、次に取れるまではこれを送る。
  String? _lastHotspotBssid;

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
  ///
  /// テザリングを自己申告している間は、接続中のWi-Fi(=自分のホットスポット)の
  /// BSSIDを`hotspotBssid`として一緒に送り、`bssidRssi`からは除く(issue #142)。
  void startScanning(String roomId) {
    stopScanning();

    _resultsSub = WiFiScan.instance.onScannedResultsAvailable.listen((
      results,
    ) {
      final bssidRssi = <String, int>{};
      for (final ap in results) {
        bssidRssi[ap.bssid] = ap.level;
      }
      unawaited(sendScan(roomId, bssidRssi));
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

  /// 1回分のスキャン結果をRTDBへ書く。
  ///
  /// 自己申告(`usesTethering`)は**スキャンのたびに読み直す**。購読して
  /// 覚えておく形だと、ゲーム開始直後の最初のスキャンが最初の値より先に
  /// 届いたときに、自分のホットスポット入りのまま送ってしまうため。
  ///
  /// 読み取りを待っている間に[stopScanning]が呼ばれた(ゲーム画面を離れた)
  /// ら書かない。書くと、退出した人のスキャンが新しい`scannedAt`付きで
  /// 残り続ける。
  Future<void> sendScan(String roomId, Map<String, int> bssidRssi) async {
    final session = _session;
    final hotspotBssid = await _currentHotspotBssid(roomId, session);
    if (session != _session) return;
    await writeOrLogFailure(
      () => _db.ref('rooms/$roomId/locations/$_uid/wifiScan').set({
        'bssidRssi': accessPointsToSend(
          bssidRssi,
          hotspotBssid: hotspotBssid,
          count: _maxApCount,
        ),
        'hotspotBssid': hotspotBssid,
        'scannedAt': ServerValue.timestamp,
      }),
      tag: 'WifiScanRepository',
      field: 'wifiScan',
    );
  }

  /// いま送るべき自分のホットスポットのBSSID。自己申告がOFFならnull。
  ///
  /// 直前の値の覚え直し(`_lastUsesTethering`/`_lastHotspotBssid`)は、
  /// [session]が今のものであるときだけ行う。止める前に始まった読み取りが
  /// 後から終わって書き換えると、入り直した後のスキャンで一瞬取れなかった
  /// ときに、止める前のホットスポットを送ってしまうため。
  Future<String?> _currentHotspotBssid(String roomId, int session) async {
    final usesTethering = await _readUsesTethering(roomId, session);
    if (session != _session) return null;
    if (!usesTethering) {
      _lastHotspotBssid = null;
      return null;
    }
    final bssid = await readHotspotBssid();
    if (session != _session) return null;
    if (bssid != null) _lastHotspotBssid = bssid;
    return _lastHotspotBssid;
  }

  /// 自分の`usesTethering`を読む。読めなければ(オフライン等)直前の値。
  Future<bool> _readUsesTethering(String roomId, int session) async {
    try {
      final snapshot = await _db
          .ref('rooms/$roomId/users/$_uid/usesTethering')
          .get()
          .timeout(_usesTetheringReadTimeout);
      final value = snapshot.value;
      final usesTethering = value is bool ? value : defaultUsesTethering;
      if (session == _session) _lastUsesTethering = usesTethering;
      return usesTethering;
    } on Object catch (e) {
      debugPrint('[WifiScanRepository] usesTetheringを読めない: $e');
      // [session]が古くても直前の値をそのまま返してよい。呼び出し側
      // ([_currentHotspotBssid])が直後に`session != _session`で捨てるため。
      return _lastUsesTethering;
    }
  }

  /// `usesTethering`の読み取りを待つ上限。スキャン間隔(10秒)より十分短く
  /// して、電波が悪いときに送信が詰まらないようにする。
  static const _usesTetheringReadTimeout = Duration(seconds: 3);

  /// 接続中のWi-FiのBSSID(小文字)。未接続・取得できないときはnull。
  ///
  /// テザリングの子機として使っているなら、これが自分のホットスポット。
  /// 位置情報の権限が無い・位置情報がOFFのときは、プラグインが例外を投げる
  /// のではなく[normalizeConnectedBssid]で弾く値が返ることがある。
  ///
  /// ランダムMAC([isLocallyAdministeredBssid])でなければnull。自己申告が
  /// ONのままテザリングが切れて構内Wi-Fiにつなぎ直った、わざとONにした、
  /// といった場合に、固定APを「ホットスポット」として全員の計算から消して
  /// しまわないため。スマホのホットスポットはAndroid(10以降)もiPhoneも
  /// ランダムMACを使う。
  Future<String?> readHotspotBssid() async {
    final String? bssid;
    try {
      bssid = normalizeConnectedBssid(await _readConnectedBssid());
    } on Object catch (e) {
      debugPrint('[WifiScanRepository] 接続中のBSSIDを取得できない: $e');
      return null;
    }
    if (bssid == null) return null;
    if (!isLocallyAdministeredBssid(bssid)) {
      debugPrint('[WifiScanRepository] 接続先が固定APのため共有しない: $bssid');
      return null;
    }
    return bssid;
  }

  /// ゲーム画面を離れる時に呼ぶこと。
  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _session++;
    _lastUsesTethering = defaultUsesTethering;
    _lastHotspotBssid = null;
    unawaited(_resultsSub?.cancel());
    _resultsSub = null;
  }
}

/// Androidが「BSSIDを渡せない」ときに返すダミーのMACアドレス
/// (位置情報の権限が無い・位置情報がOFFのとき等)。
const _redactedBssid = '02:00:00:00:00:00';

/// 接続中のBSSIDとしてプラグインから返った値を、共有してよい形(小文字)に
/// そろえる。未接続・ダミー値・空文字はnull。
String? normalizeConnectedBssid(String? raw) {
  final bssid = raw?.trim().toLowerCase();
  if (bssid == null || bssid.isEmpty || bssid == _redactedBssid) return null;
  return bssid;
}

/// ローカル管理ビット(先頭オクテットの下から2ビット目)が立った、ランダム
/// MACのBSSIDか。スマホのホットスポットはこれで、メーカーが割り当てた
/// 固定APのMACは通常立っていない。
bool isLocallyAdministeredBssid(String bssid) {
  final firstOctet = int.tryParse(bssid.split(':').first, radix: 16);
  return firstOctet != null && firstOctet & 0x02 != 0;
}

/// RTDBへ送るAP。自分のホットスポット([hotspotBssid])を除いたうえで、
/// RSSIの強い上位[count]件に絞る。
///
/// 除外を先にするのは、端末のすぐ横にある自分のホットスポットが常に最強の
/// APになり、上位の枠を1つ奪ってしまうため。
Map<String, int> accessPointsToSend(
  Map<String, int> bssidRssi, {
  required String? hotspotBssid,
  required int count,
}) => selectTopAccessPoints(
  excludeAccessPoints(bssidRssi, {?hotspotBssid}),
  count: count,
);
