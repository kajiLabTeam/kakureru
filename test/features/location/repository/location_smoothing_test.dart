import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/repository/location_smoothing.dart';

void main() {
  /// 強制更新(フォールバック)が絡まない、素の判定を見るためのヘルパー。
  /// 連続棄却0回・経過0秒なので、既定の閾値ではフォールバックは発動しない。
  LocationUpdateDecision evaluateWithoutFallback({
    required double latitude,
    required double longitude,
    required double? accuracy,
    required double? previousLatitude,
    required double? previousLongitude,
    double? deadbandDistanceM,
  }) {
    return evaluateLocationUpdate(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      previousLatitude: previousLatitude,
      previousLongitude: previousLongitude,
      consecutiveRejectionCount: 0,
      elapsedSinceLastAccepted: Duration.zero,
      deadbandDistanceM:
          deadbandDistanceM ?? LocationFilterThresholds.deadbandDistanceM,
    );
  }

  group('evaluateLocationUpdate(基本の判定)', () {
    test('直前の採用位置が無い(初回)なら、accuracyが良ければ採用する', () {
      final result = evaluateWithoutFallback(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, LocationUpdateDecision.accepted);
      expect(result.isAccepted, isTrue);
    });

    test('accuracyが閾値を超える(=精度が悪い)測位は初回でも棄却', () {
      final result = evaluateWithoutFallback(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM + 0.1,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, LocationUpdateDecision.rejectedLowAccuracy);
      expect(result.isAccepted, isFalse);
    });

    test('accuracyがちょうど閾値なら採用する(境界値)', () {
      final result = evaluateWithoutFallback(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, LocationUpdateDecision.accepted);
    });

    test('accuracyが0.0(端末が精度を報告できない)なら最良として採用する', () {
      // geolocatorのPosition.accuracyは非nullのdoubleで、取得できない端末では
      // 0.0が入る。実装上は「最も精度が良い」扱いになり足切りを素通りする
      // ——この挙動を仕様として固定しておく(nullでの分岐は正常系では通らない)。
      final result = evaluateWithoutFallback(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 0,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, LocationUpdateDecision.accepted);
    });

    test('accuracyが0.0でもデッドバンド判定は通常どおり効く', () {
      final result = evaluateWithoutFallback(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 0,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, LocationUpdateDecision.rejectedDeadband);
    });

    test('accuracyがnull(キー自体が欠けている)なら、accuracyによる足切りは行わない', () {
      final result = evaluateWithoutFallback(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: null,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, LocationUpdateDecision.accepted);
    });

    test('直前の採用位置と全く同じ(移動0m)なら棄却(デッドバンド)', () {
      final result = evaluateWithoutFallback(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, LocationUpdateDecision.rejectedDeadband);
    });

    test('移動距離がデッドバンド未満なら棄却(GPSノイズによる飛び回りを抑える)', () {
      // 緯度方向に約0.00005度(≒5.5m)離れた点。デッドバンド(8m)未満。
      final result = evaluateWithoutFallback(
        latitude: 35.68125,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, LocationUpdateDecision.rejectedDeadband);
    });

    test('移動距離がちょうどデッドバンドなら採用する(境界値)', () {
      const previousLat = 35.6812;
      const previousLng = 139.7671;
      const currentLat = 35.68125;
      const currentLng = 139.7671;
      final movedM = Geolocator.distanceBetween(
        previousLat,
        previousLng,
        currentLat,
        currentLng,
      );

      final result = evaluateWithoutFallback(
        latitude: currentLat,
        longitude: currentLng,
        accuracy: 5,
        previousLatitude: previousLat,
        previousLongitude: previousLng,
        deadbandDistanceM: movedM,
      );
      expect(result, LocationUpdateDecision.accepted);
    });

    test('移動距離がデッドバンド以上なら採用する(実際に移動したとみなす)', () {
      // 緯度方向に約0.0002度(≒22m)離れた点。デッドバンド(8m)を超える。
      final result = evaluateWithoutFallback(
        latitude: 35.6814,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, LocationUpdateDecision.accepted);
    });

    test('accuracyが悪ければ、移動距離が十分でも棄却(足切りが優先)', () {
      final result = evaluateWithoutFallback(
        latitude: 35.6814,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM + 10,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, LocationUpdateDecision.rejectedLowAccuracy);
    });

    test('閾値はデフォルト値を上書きできる', () {
      final result = evaluateWithoutFallback(
        latitude: 35.68125,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        deadbandDistanceM: 1,
      );
      expect(result, LocationUpdateDecision.accepted);
    });
  });

  group('evaluateLocationUpdate(ゆっくりした実移動)', () {
    test('デッドバンド未満の移動を繰り返しても、積み上がれば最終的に採用される', () {
      // 基準点(previousLat/Lng)は採用したときだけ更新する、という呼び出し側の
      // 契約が守られていれば、1回あたり2m強の移動でも累積8mを超えた時点で
      // 採用される——このPRのデッドバンド設計が依存している最重要の性質。
      const baseLat = 35.6812;
      const lng = 139.7671;
      // 緯度0.00002度 ≒ 2.2m。
      const stepLat = 0.00002;

      final decisions = <LocationUpdateDecision>[];
      var rejections = 0;
      for (var i = 1; i <= 4; i++) {
        final decision = evaluateLocationUpdate(
          latitude: baseLat + stepLat * i,
          longitude: lng,
          accuracy: 5,
          // 採用されていないので基準点は初回のまま動かさない。
          previousLatitude: baseLat,
          previousLongitude: lng,
          consecutiveRejectionCount: rejections,
          elapsedSinceLastAccepted: Duration.zero,
        );
        decisions.add(decision);
        if (!decision.isAccepted) rejections++;
      }

      expect(
        decisions.sublist(0, 3),
        everyElement(LocationUpdateDecision.rejectedDeadband),
      );
      // 強制更新ではなく、累積移動がデッドバンドを超えたことによる通常の採用。
      expect(decisions[3], LocationUpdateDecision.accepted);
    });
  });

  group('evaluateLocationUpdate(強制更新のフォールバック)', () {
    test('accuracyが常に悪くても、連続棄却が上限に達したら採用する', () {
      // 屋内でaccuracyが恒常的に30mを超える状況。フォールバックが無いと
      // lat/lngが一度もRTDBに書かれず、その人の気圧・Wi-Fi情報まで他の
      // 参加者から見えなくなる。
      const badAccuracy = LocationFilterThresholds.maxAcceptableAccuracyM + 70;
      const limit = LocationFilterThresholds.forceAcceptAfterRejections;
      final decisions = <LocationUpdateDecision>[];
      var rejections = 0;
      for (var i = 0; i < limit; i++) {
        final decision = evaluateLocationUpdate(
          latitude: 35.6812,
          longitude: 139.7671,
          accuracy: badAccuracy,
          previousLatitude: null,
          previousLongitude: null,
          consecutiveRejectionCount: rejections,
          elapsedSinceLastAccepted: Duration.zero,
        );
        decisions.add(decision);
        if (!decision.isAccepted) rejections++;
      }

      expect(
        decisions.sublist(0, limit - 1),
        everyElement(LocationUpdateDecision.rejectedLowAccuracy),
      );
      expect(decisions.last, LocationUpdateDecision.acceptedByFallback);
      expect(decisions.last.isAccepted, isTrue);
    });

    test('静止したままでも、連続棄却が上限に達したら採用する(updatedAtが止まらない)', () {
      final decision = evaluateLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        consecutiveRejectionCount:
            LocationFilterThresholds.forceAcceptAfterRejections - 1,
        elapsedSinceLastAccepted: Duration.zero,
      );
      expect(decision, LocationUpdateDecision.acceptedByFallback);
    });

    test('連続棄却が上限に1回足りなければ、まだ棄却する(境界値)', () {
      final decision = evaluateLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        consecutiveRejectionCount:
            LocationFilterThresholds.forceAcceptAfterRejections - 2,
        elapsedSinceLastAccepted: Duration.zero,
      );
      expect(decision, LocationUpdateDecision.rejectedDeadband);
    });

    test('連続棄却が少なくても、最終採用からの経過時間が上限に達したら採用する', () {
      final decision = evaluateLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM + 50,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        consecutiveRejectionCount: 0,
        elapsedSinceLastAccepted:
            LocationFilterThresholds.forceAcceptAfterElapsed,
      );
      expect(decision, LocationUpdateDecision.acceptedByFallback);
    });

    test('経過時間が上限未満なら、まだ棄却する(境界値)', () {
      final decision = evaluateLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM + 50,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        consecutiveRejectionCount: 0,
        elapsedSinceLastAccepted:
            LocationFilterThresholds.forceAcceptAfterElapsed -
            const Duration(milliseconds: 1),
      );
      expect(decision, LocationUpdateDecision.rejectedLowAccuracy);
    });

    test('採用できる測位はフォールバック条件下でも通常の採用として返す', () {
      final decision = evaluateLocationUpdate(
        latitude: 35.6814,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        consecutiveRejectionCount: 99,
        elapsedSinceLastAccepted: const Duration(hours: 1),
      );
      expect(decision, LocationUpdateDecision.accepted);
    });

    test('フォールバックの閾値もデフォルト値を上書きできる', () {
      final decision = evaluateLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        consecutiveRejectionCount: 0,
        elapsedSinceLastAccepted: Duration.zero,
        forceAcceptAfterRejections: 1,
      );
      expect(decision, LocationUpdateDecision.acceptedByFallback);
    });
  });
}
