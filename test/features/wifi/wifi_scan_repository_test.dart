import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:kakureru/features/wifi/repository/wifi_scan_repository.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../../helpers/fake_rtdb.dart';

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

  group('normalizeConnectedBssid(issue #142)', () {
    test('小文字にそろえる', () {
      expect(normalizeConnectedBssid('6A:11:22:33:44:50'), '6a:11:22:33:44:50');
    });

    test('未接続・空文字・Androidのダミー値はnull', () {
      expect(normalizeConnectedBssid(null), isNull);
      expect(normalizeConnectedBssid(''), isNull);
      expect(normalizeConnectedBssid('02:00:00:00:00:00'), isNull);
    });
  });

  group('accessPointsToSend(issue #142)', () {
    test('自分のホットスポットを除いてから上位を選ぶ', () {
      final sent = accessPointsToSend(
        {'6a:11:22:33:44:50': -25, 'ap1': -60, 'ap2': -65, 'ap3': -70},
        hotspotBssid: '6a:11:22:33:44:50',
        count: 2,
      );

      // 最強のホットスポットに枠を取られず、固定APの上位2件が残る。
      expect(sent, {'ap1': -60, 'ap2': -65});
    });

    test('ホットスポットが無ければ上位を選ぶだけ', () {
      final sent = accessPointsToSend(
        {'ap1': -60, 'ap2': -65, 'ap3': -70},
        hotspotBssid: null,
        count: 2,
      );

      expect(sent, {'ap1': -60, 'ap2': -65});
    });
  });

  group('WifiScanRepository.readHotspotBssid(issue #142)', () {
    test('接続中のBSSIDを小文字にして返す', () async {
      final repo = WifiScanRepository(
        readConnectedBssid: () async => '6A:11:22:33:44:50',
      );

      expect(await repo.readHotspotBssid(), '6a:11:22:33:44:50');
    });

    test('ランダムMACでない(固定APの)BSSIDは共有しない', () async {
      // 自己申告がONのままテザリングが切れて構内Wi-Fiにつなぎ直ったとき。
      final repo = WifiScanRepository(
        readConnectedBssid: () async => '00:1a:2b:3c:4d:5e',
      );

      expect(await repo.readHotspotBssid(), isNull);
    });

    test('ダミー値ならnull', () async {
      final repo = WifiScanRepository(
        readConnectedBssid: () async => '02:00:00:00:00:00',
      );

      expect(await repo.readHotspotBssid(), isNull);
    });

    test('プラグインが例外を投げてもnullを返し、スキャンの送信は止めない', () async {
      final repo = WifiScanRepository(
        readConnectedBssid: () async => throw PlatformException(code: 'x'),
      );

      expect(await repo.readHotspotBssid(), isNull);
    });
  });

  group('isLocallyAdministeredBssid(issue #142)', () {
    test('先頭オクテットの下から2ビット目が立っていればランダムMAC', () {
      expect(isLocallyAdministeredBssid('6a:11:22:33:44:50'), isTrue);
      expect(isLocallyAdministeredBssid('02:00:00:00:00:01'), isTrue);
    });

    test('メーカーが割り当てたMACはランダムMACではない', () {
      expect(isLocallyAdministeredBssid('00:1a:2b:3c:4d:5e'), isFalse);
      expect(isLocallyAdministeredBssid('f8:4f:ad:00:00:00'), isFalse);
    });

    test('読めない値はランダムMAC扱いにしない', () {
      expect(isLocallyAdministeredBssid(''), isFalse);
      expect(isLocallyAdministeredBssid('zz:00:00:00:00:00'), isFalse);
    });
  });

  group('WifiScanRepository.sendScan(issue #142)', () {
    const roomId = 'room-1';
    const hotspot = '6a:11:22:33:44:50';
    const scan = {hotspot: -25, 'ap1': -60, 'ap2': -65};
    const wifiScanPath = 'rooms/room-1/locations/me/wifiScan';

    FakeRtdb rtdbWith({bool? usesTethering}) => FakeRtdb({
      'rooms': {
        roomId: {
          'users': {
            'me': {'usesTethering': ?usesTethering},
          },
        },
      },
    });

    Map<Object?, Object?> sent(FakeRtdb db) =>
        db.read(wifiScanPath)! as Map<Object?, Object?>;

    test('自己申告がONなら、ホットスポットを除いて送り、hotspotBssidで共有する', () async {
      final db = rtdbWith(usesTethering: true);
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () async => hotspot,
      );

      await repo.sendScan(roomId, scan);

      expect(sent(db)['bssidRssi'], {'ap1': -60, 'ap2': -65});
      expect(sent(db)['hotspotBssid'], hotspot);
    });

    test('自己申告がOFFなら、接続先を読まずにそのまま送る', () async {
      final db = rtdbWith(usesTethering: false);
      var reads = 0;
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () async {
          reads++;
          return hotspot;
        },
      );

      await repo.sendScan(roomId, scan);

      expect(sent(db)['bssidRssi'], scan);
      expect(sent(db)['hotspotBssid'], isNull);
      expect(reads, 0);
    });

    test('自己申告が未設定ならON扱い(テザリング前提の人が多いため)', () async {
      final db = rtdbWith();
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () async => hotspot,
      );

      await repo.sendScan(roomId, scan);

      expect(sent(db)['hotspotBssid'], hotspot);
      expect(sent(db)['bssidRssi'], {'ap1': -60, 'ap2': -65});
    });

    test('未設定のままでも、構内Wi-Fi(固定AP)につないでいれば何も共有しない', () async {
      final db = rtdbWith();
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () async => '00:1a:2b:3c:4d:5e',
      );

      await repo.sendScan(roomId, scan);

      expect(sent(db)['hotspotBssid'], isNull);
      expect(sent(db)['bssidRssi'], scan);
    });

    test('スキャンのたびに自己申告を読み直す(最初のスキャンから効く)', () async {
      final db = rtdbWith(usesTethering: false);
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () async => hotspot,
      );
      await repo.sendScan(roomId, scan);

      db.write('rooms/room-1/users/me/usesTethering', true);
      await repo.sendScan(roomId, scan);

      expect(sent(db)['hotspotBssid'], hotspot);
    });

    test('1回取れなかっただけなら、直前に取れたホットスポットを使い続ける', () async {
      final db = rtdbWith(usesTethering: true);
      String? connected = hotspot;
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () async => connected,
      );
      await repo.sendScan(roomId, scan);

      // 一瞬切れた・構内Wi-Fi(固定AP)につなぎ直った。
      connected = '00:1a:2b:3c:4d:5e';
      await repo.sendScan(roomId, scan);

      expect(sent(db)['bssidRssi'], {'ap1': -60, 'ap2': -65});
      expect(sent(db)['hotspotBssid'], hotspot);
    });

    test('OFFにしたら、直前のホットスポットも送らない', () async {
      final db = rtdbWith(usesTethering: true);
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () async => hotspot,
      );
      await repo.sendScan(roomId, scan);

      db.write('rooms/room-1/users/me/usesTethering', false);
      await repo.sendScan(roomId, scan);

      expect(sent(db)['hotspotBssid'], isNull);
      expect(sent(db)['bssidRssi'], scan);
    });

    test('接続先の読み取り中にスキャンを止めたら、書かない', () async {
      final db = rtdbWith(usesTethering: true);
      final connected = Completer<String?>();
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () => connected.future,
      );

      final sending = repo.sendScan(roomId, scan);
      await Future<void>.delayed(Duration.zero);
      // ゲーム画面を離れた。
      repo.stopScanning();
      connected.complete(hotspot);
      await sending;

      expect(db.read(wifiScanPath), isNull);
    });

    test('止める前の読み取りが後から終わっても、次のスキャンの値を書き換えない', () async {
      // 古いスキャンの読み取り中に止めて(ゲーム画面を離れて)入り直し、
      // 新しいスキャンではBSSIDが一瞬取れなかった、という順番。
      final db = rtdbWith(usesTethering: true);
      final held = Completer<String?>();
      var calls = 0;
      final repo = WifiScanRepository(
        db: db,
        auth: FakeAuth(),
        readConnectedBssid: () {
          calls++;
          return calls == 1 ? held.future : Future.value();
        },
      );

      final stale = repo.sendScan(roomId, scan);
      await Future<void>.delayed(Duration.zero);
      repo.stopScanning();
      held.complete(hotspot);
      await stale;
      await repo.sendScan(roomId, scan);

      // 止める前のホットスポットを「直前に取れた値」として使い回さない。
      expect(sent(db)['hotspotBssid'], isNull);
      expect(sent(db)['bssidRssi'], scan);
    });
  });
}
