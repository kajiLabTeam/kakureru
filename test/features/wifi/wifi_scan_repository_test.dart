import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:kakureru/features/wifi/repository/wifi_scan_repository.dart';
import 'package:wifi_scan/wifi_scan.dart';

/// `wifi_scan` プラグインのMethodChannel。
const _channel = MethodChannel('wifi_scan');

/// プラットフォーム側が `canStartScan` で返す数値
/// (プラグインの `_deserializeCanStartScan` が読み替えている値)。
const _canYes = 1;
const _canLocationServiceDisabled = 5;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 端末の代わりに、可否コードと `startScan()` の成否をテストから決める。
  void mockPlugin({required int canCode, bool startScanResult = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'canStartScan':
              return canCode;
            case 'startScan':
              return startScanResult;
            default:
              return null;
          }
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('WifiScanRepository.triggerScan', () {
    test('スキャンを要求できて実行もされればok', () async {
      mockPlugin(canCode: _canYes);

      expect(await WifiScanRepository().triggerScan(), WifiScanStatus.ok);
    });

    test('要求は通るのに実行されない(スロットリング)とthrottled', () async {
      // canStartScan()はyesのままstartScan()だけがfalseを返す、という
      // Androidのスキャンスロットリング(2分に4回)の出方を再現する。
      mockPlugin(canCode: _canYes, startScanResult: false);

      expect(
        await WifiScanRepository().triggerScan(),
        WifiScanStatus.throttled,
      );
    });

    test('そもそも要求できない理由は、そのまま状態になる', () async {
      mockPlugin(canCode: _canLocationServiceDisabled);

      expect(
        await WifiScanRepository().triggerScan(),
        wifiScanStatusFromCanStartScan(CanStartScan.noLocationServiceDisabled),
      );
    });
  });
}
