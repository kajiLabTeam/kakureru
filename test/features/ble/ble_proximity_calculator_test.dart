import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/ble/repository/ble_proximity_calculator.dart';

void main() {
  group('shortenUid', () {
    test('しきい値以下のuidはそのまま返す', () {
      expect(shortenUid('abc'), 'abc');
    });

    test('しきい値を超えるuidは先頭で切り詰める', () {
      final uid = 'a' * 28;
      final result = shortenUid(uid);
      expect(result.length, BleProximityThresholds.shortUidLength);
      expect(uid.startsWith(result), isTrue);
    });

    test('先頭が同じ2つのuidは同じshortUidになる(既知の制約)', () {
      // shortUidLength文字までしか広告データに載せられないため、先頭が
      // 一致する別人のuidを区別できないのは設計上の既知の制約
      // (ble_proximity_calculator.dartのコメント参照)。1部屋あたりの人数を
      // 考えれば衝突は現実的に起きないと判断している。
      final uidA = '${'a' * BleProximityThresholds.shortUidLength}-user-a';
      final uidB = '${'a' * BleProximityThresholds.shortUidLength}-user-b';
      expect(shortenUid(uidA), shortenUid(uidB));
    });
  });

  group('encodeAdvertisePayload / decodeAdvertisePayload', () {
    test('往復させると短縮uidが復元できる', () {
      const uid = 'user-123-abc';
      final decoded = decodeAdvertisePayload(encodeAdvertisePayload(uid));
      expect(decoded, shortenUid(uid));
    });

    test('nullは復元できない', () {
      expect(decodeAdvertisePayload(null), isNull);
    });

    test('空のバイト列は復元できない', () {
      expect(decodeAdvertisePayload(const []), isNull);
    });

    test('不正なUTF-8バイト列は復元できない', () {
      // 0xFFはUTF-8のどの先頭バイトパターンにも該当しない不正な値。
      // ゲームと無関係な他アプリの広告がたまたま同じmanufacturerIdを
      // 使っていた場合等に、デコード時の例外で落ちないことを確認する。
      expect(decodeAdvertisePayload(const [0xff, 0xfe]), isNull);
    });
  });

  group('estimateDistanceMeters', () {
    test('基準RSSIちょうどなら1m', () {
      final distance = estimateDistanceMeters(
        BleProximityThresholds.referenceRssiAt1mDbm,
      );
      expect(distance, closeTo(1, 0.0001));
    });

    test('RSSIが弱いほど推定距離は大きくなる', () {
      final near = estimateDistanceMeters(-59);
      final far = estimateDistanceMeters(-80);
      expect(far, greaterThan(near));
    });
  });

  group('isWithinCatchRange 境界値', () {
    test('しきい値ちょうどなら範囲内', () {
      expect(
        isWithinCatchRange(BleProximityThresholds.catchRangeMeters),
        isTrue,
      );
    });

    test('しきい値を少し超えたら範囲外', () {
      expect(
        isWithinCatchRange(
          BleProximityThresholds.catchRangeMeters + 0.01,
        ),
        isFalse,
      );
    });
  });

  group('isDetectionFresh 境界値', () {
    test('しきい値ちょうどの経過時間はまだ新しい', () {
      expect(
        isDetectionFresh(
          detectedAtMillis: 0,
          nowMillis: BleProximityThresholds.staleAfterMillis,
        ),
        isTrue,
      );
    });

    test('しきい値を超えたら古い', () {
      expect(
        isDetectionFresh(
          detectedAtMillis: 0,
          nowMillis: BleProximityThresholds.staleAfterMillis + 1,
        ),
        isFalse,
      );
    });
  });
}
