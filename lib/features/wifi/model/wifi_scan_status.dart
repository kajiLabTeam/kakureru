import 'package:wifi_scan/wifi_scan.dart';

/// Wi-Fiスキャンがいま実行できているかどうか。
///
/// 端末側の事情(権限・位置情報・Androidのスキャンスロットリング)でスキャンが
/// 空振りしていても、以前はログにしか出ていなかったため、本人も相手も
/// 「Wi-Fiでの距離感だけが古い」ことに気づけなかった(issue #98)。待機画面で
/// この状態を出して、遊び始める前に直せるようにする。
enum WifiScanStatus {
  /// まだ確認していない・確認中。
  checking,

  /// スキャンできている。
  ok,

  /// スキャンの要求自体は通るが、実行が拒否されている。
  ///
  /// Android 9以降の `startScan()` は2分に4回までに制限されており、超過すると
  /// `canStartScan()` は `yes` のまま `startScan()` だけがfalseを返す。
  /// このアプリは開発者オプションでスロットルを解除して遊ぶ前提(AGENTS.md)
  /// なので、解除し忘れがこの状態として出る。
  throttled,

  /// この端末はWi-Fiスキャンに対応していない。
  notSupported,

  /// 位置情報の権限がまだ許可されていない(アプリから要求できる)。
  permissionRequired,

  /// 位置情報の権限が拒否されている(端末の設定から許可し直す必要がある)。
  permissionDenied,

  /// 位置情報の権限が「おおよその位置」のままで、精度が足りない。
  permissionAccuracy,

  /// 端末の位置情報(GPS)がOFFになっている。
  locationServiceDisabled,

  /// 上記以外の理由で確認・実行に失敗した。
  failed,
}

/// `WiFiScan.canStartScan()` の結果を[WifiScanStatus]へ読み替える。
///
/// [CanStartScan.yes]は「スキャンを要求してよい」だけで、実際に実行された
/// かどうか(=スロットリング)までは分からないため、ここでは[WifiScanStatus.ok]
/// を返さず、`startScan()` の結果と突き合わせる呼び出し側に委ねる
/// (`WifiScanRepository.triggerScan`)。
WifiScanStatus wifiScanStatusFromCanStartScan(CanStartScan can) {
  switch (can) {
    case CanStartScan.yes:
      return WifiScanStatus.ok;
    case CanStartScan.notSupported:
      return WifiScanStatus.notSupported;
    case CanStartScan.noLocationPermissionRequired:
      return WifiScanStatus.permissionRequired;
    case CanStartScan.noLocationPermissionDenied:
      return WifiScanStatus.permissionDenied;
    case CanStartScan.noLocationPermissionUpgradeAccuracy:
      return WifiScanStatus.permissionAccuracy;
    case CanStartScan.noLocationServiceDisabled:
      return WifiScanStatus.locationServiceDisabled;
    case CanStartScan.failed:
      return WifiScanStatus.failed;
  }
}

/// 一目で分かる短いラベル(「Wi-Fiスキャン: 〜」の〜の部分)。
String wifiScanStatusLabel(WifiScanStatus status) {
  switch (status) {
    case WifiScanStatus.checking:
      return '確認中...';
    case WifiScanStatus.ok:
      return 'OK';
    case WifiScanStatus.throttled:
      return 'スロットル中';
    case WifiScanStatus.notSupported:
      return '非対応';
    case WifiScanStatus.permissionRequired:
      return '権限なし';
    case WifiScanStatus.permissionDenied:
      return '権限が拒否されています';
    case WifiScanStatus.permissionAccuracy:
      return '権限の精度が不足';
    case WifiScanStatus.locationServiceDisabled:
      return '位置情報OFF';
    case WifiScanStatus.failed:
      return '確認できません';
  }
}

/// 「何をすれば直るか」を1行で返す。直す必要が無い状態ではnull。
String? wifiScanStatusHint(WifiScanStatus status) {
  switch (status) {
    case WifiScanStatus.checking:
    case WifiScanStatus.ok:
      return null;
    case WifiScanStatus.throttled:
      return '開発者オプションの「Wi-Fiスキャンのスロットル」をOFFにしてください';
    case WifiScanStatus.notSupported:
      return 'この端末ではWi-Fiでの距離感は使えません(GPS・気圧だけで遊べます)';
    case WifiScanStatus.permissionRequired:
      return '位置情報の権限を許可してください';
    case WifiScanStatus.permissionDenied:
      return '端末の設定 > アプリ > 権限 から位置情報を許可してください';
    case WifiScanStatus.permissionAccuracy:
      return '位置情報の権限を「正確な位置」に変更してください';
    case WifiScanStatus.locationServiceDisabled:
      return '端末の位置情報(GPS)をONにしてください';
    case WifiScanStatus.failed:
      return 'Wi-FiがONになっているか確認して、もう一度お試しください';
  }
}

/// このままでは相手との距離感がWi-Fiで測れない状態かどうか(表示の色分け用)。
bool isWifiScanProblem(WifiScanStatus status) =>
    status != WifiScanStatus.checking && status != WifiScanStatus.ok;
