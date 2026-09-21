import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:wifi_scan/wifi_scan.dart';

void main() {
  group('wifiScanStatusFromCanStartScan', () {
    test('yesはok(実際に実行できたかは呼び出し側が判断する)', () {
      expect(
        wifiScanStatusFromCanStartScan(CanStartScan.yes),
        WifiScanStatus.ok,
      );
    });

    test('位置情報サービスOFFはlocationServiceDisabled', () {
      expect(
        wifiScanStatusFromCanStartScan(CanStartScan.noLocationServiceDisabled),
        WifiScanStatus.locationServiceDisabled,
      );
    });

    test('権限の3種類はそれぞれ別の状態になる(直し方が違うため)', () {
      expect(
        wifiScanStatusFromCanStartScan(
          CanStartScan.noLocationPermissionRequired,
        ),
        WifiScanStatus.permissionRequired,
      );
      expect(
        wifiScanStatusFromCanStartScan(CanStartScan.noLocationPermissionDenied),
        WifiScanStatus.permissionDenied,
      );
      expect(
        wifiScanStatusFromCanStartScan(
          CanStartScan.noLocationPermissionUpgradeAccuracy,
        ),
        WifiScanStatus.permissionAccuracy,
      );
    });

    test('notSupported / failed もそのまま対応する', () {
      expect(
        wifiScanStatusFromCanStartScan(CanStartScan.notSupported),
        WifiScanStatus.notSupported,
      );
      expect(
        wifiScanStatusFromCanStartScan(CanStartScan.failed),
        WifiScanStatus.failed,
      );
    });

    test('CanStartScanの全ての値に対応が存在する(値が増えたら落ちる)', () {
      for (final can in CanStartScan.values) {
        expect(() => wifiScanStatusFromCanStartScan(can), returnsNormally);
      }
    });
  });

  group('wifiScanStatusLabel', () {
    test('主な状態の文言', () {
      expect(wifiScanStatusLabel(WifiScanStatus.ok), 'OK');
      expect(wifiScanStatusLabel(WifiScanStatus.throttled), 'スロットル中');
      expect(
        wifiScanStatusLabel(WifiScanStatus.locationServiceDisabled),
        '位置情報OFF',
      );
      expect(wifiScanStatusLabel(WifiScanStatus.permissionRequired), '権限なし');
      expect(wifiScanStatusLabel(WifiScanStatus.checking), '確認中...');
    });

    test('全ての状態に空でないラベルがある', () {
      for (final status in WifiScanStatus.values) {
        expect(wifiScanStatusLabel(status), isNotEmpty, reason: '$status');
      }
    });
  });

  group('wifiScanStatusHint', () {
    test('OK・確認中は直し方を出さない', () {
      expect(wifiScanStatusHint(WifiScanStatus.ok), isNull);
      expect(wifiScanStatusHint(WifiScanStatus.checking), isNull);
    });

    test('スロットル中は開発者オプションの解除を案内する', () {
      expect(
        wifiScanStatusHint(WifiScanStatus.throttled),
        contains('開発者オプション'),
      );
    });

    test('位置情報OFFは位置情報をONにするよう案内する', () {
      expect(
        wifiScanStatusHint(WifiScanStatus.locationServiceDisabled),
        contains('位置情報'),
      );
    });

    test('OK・確認中以外は必ず直し方が1行ある', () {
      for (final status in WifiScanStatus.values) {
        if (status == WifiScanStatus.ok || status == WifiScanStatus.checking) {
          continue;
        }
        final hint = wifiScanStatusHint(status);
        expect(hint, isNotNull, reason: '$status');
        expect(hint, isNot(contains('\n')), reason: '$status は1行で出す');
      }
    });
  });

  group('isWifiScanFixable', () {
    test('非対応は問題ではあるが、直せないので対象外(再確認を出さない)', () {
      expect(isWifiScanProblem(WifiScanStatus.notSupported), isTrue);
      expect(isWifiScanFixable(WifiScanStatus.notSupported), isFalse);
    });

    test('設定で直せる状態は対象', () {
      expect(isWifiScanFixable(WifiScanStatus.locationServiceDisabled), isTrue);
      expect(isWifiScanFixable(WifiScanStatus.permissionDenied), isTrue);
      expect(isWifiScanFixable(WifiScanStatus.throttled), isTrue);
      expect(isWifiScanFixable(WifiScanStatus.failed), isTrue);
    });

    test('ok・確認中は対象外', () {
      expect(isWifiScanFixable(WifiScanStatus.ok), isFalse);
      expect(isWifiScanFixable(WifiScanStatus.checking), isFalse);
    });
  });

  group('isWifiScanProblem', () {
    test('ok・checkingは問題扱いにしない', () {
      expect(isWifiScanProblem(WifiScanStatus.ok), isFalse);
      expect(isWifiScanProblem(WifiScanStatus.checking), isFalse);
    });

    test('それ以外は問題扱い', () {
      expect(isWifiScanProblem(WifiScanStatus.throttled), isTrue);
      expect(isWifiScanProblem(WifiScanStatus.notSupported), isTrue);
      expect(isWifiScanProblem(WifiScanStatus.failed), isTrue);
    });
  });
}
