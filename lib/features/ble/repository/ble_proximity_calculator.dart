import 'dart:convert';
import 'dart:math' as math;

/// BLE近接判定に使う閾値・変換パラメータ。
///
/// Wi-Fi版(ProximityThresholds)と同じく、実測値や副作用を伴う処理と分離して
/// 単体テストしやすくするため、定数と純粋関数だけをこのファイルに集約する。
class BleProximityThresholds {
  const BleProximityThresholds._();

  /// 鬼の「捕まえた」を押せるようにする距離のしきい値(m)。issue #16・#140。
  static const catchRangeMeters = 3.0;

  /// 1mの距離で観測される基準RSSI(dBm)。BLEチップ・端末機種・持ち方で
  /// 変動するため、実機測定(issue #16 検証上の制約)の後に調整が要る暫定値。
  static const referenceRssiAt1mDbm = -59;

  /// 環境減衰係数(自由空間なら2、遮蔽物が多い屋外・ポケットの中などでは
  /// より大きくなる)。屋外での鬼ごっこ利用を想定した暫定値。
  static const pathLossExponent = 3.0;

  /// この時間(ms)より古い検知結果は「今は近くにいない」とみなす。広告・
  /// スキャン間隔の揺らぎを吸収しつつ、相手が離れたら程なくボタンが
  /// 消えるようにするため。
  static const staleAfterMillis = 5000;

  /// 広告データに載せるuidの先頭文字数。BLEアドバタイズパケットの容量制限
  /// (Androidで最大31バイト、flagsやmanufacturer IDのヘッダと共有)に収める
  /// ため全長(28文字)は使わない。1部屋あたりの人数を考えれば衝突は
  /// 現実的に起きない。
  static const shortUidLength = 16;

  /// 広告データを識別するためのManufacturer ID。Bluetooth SIGの
  /// Assigned Numbersでテスト用途に予約されている値を使う(このアプリ内だけで
  /// 通じる私的な識別子のため、正式な企業ID登録は行わない)。
  static const manufacturerId = 0xffff;
}

/// uidの先頭を広告データに載せられる長さに切り詰める。
String shortenUid(String uid) {
  const length = BleProximityThresholds.shortUidLength;
  return uid.length <= length ? uid : uid.substring(0, length);
}

/// 広告データ(manufacturerData)に載せるバイト列を作る。
List<int> encodeAdvertisePayload(String uid) => utf8.encode(shortenUid(uid));

/// 受信したmanufacturerDataのバイト列から短縮uidを取り出す。不正なデータならnull。
String? decodeAdvertisePayload(List<int>? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

/// RSSI(dBm)から距離(m)を推定する(対数距離経路損失モデル)。
double estimateDistanceMeters(
  int rssiDbm, {
  int referenceRssiAt1mDbm = BleProximityThresholds.referenceRssiAt1mDbm,
  double pathLossExponent = BleProximityThresholds.pathLossExponent,
}) {
  final exponent = (referenceRssiAt1mDbm - rssiDbm) / (10 * pathLossExponent);
  return math.pow(10, exponent).toDouble();
}

/// 「捕まえた」ボタンを押せる距離(3m以内)かどうか(issue #140)。
bool isWithinCatchRange(double distanceMeters) =>
    distanceMeters <= BleProximityThresholds.catchRangeMeters;

/// 検知結果がまだ新しい(古すぎない)かどうか。
bool isDetectionFresh({required int detectedAtMillis, required int nowMillis}) {
  return nowMillis - detectedAtMillis <=
      BleProximityThresholds.staleAfterMillis;
}
