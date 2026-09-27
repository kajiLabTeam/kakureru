import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/location_sample.dart';
import 'package:kakureru/features/location/repository/location_smoothing.dart';

/// 緯度0.0001度 ≒ 11m。デッドバンド(8m)を超える移動を作るのに使う。
const _step = 0.0001;

final _start = DateTime.utc(2026);

LocationSample _sample({
  double latitude = 35.0,
  double? accuracy = 5,
  int? timestampMs,
}) => LocationSample(
  latitude: latitude,
  longitude: 139,
  accuracy: accuracy,
  timestampMs: timestampMs,
);

void main() {
  group('LocationUpdateFilter(古い測位の破棄)', () {
    test('すでに受け取った測位より古い時刻の測位は捨てる', () {
      final filter = LocationUpdateFilter(startedAt: _start);
      final first = filter.offer(
        _sample(timestampMs: 2000),
        now: _start,
      );
      expect(first.decision, LocationUpdateDecision.accepted);

      final older = filter.offer(
        _sample(latitude: 35.0 + _step * 5, timestampMs: 1000),
        now: _start.add(const Duration(seconds: 4)),
      );
      expect(older.decision, LocationUpdateDecision.rejectedStale);
      expect(older.toWrite, isNull);
    });

    test('同じ時刻の測位も捨てる(境界値)', () {
      final filter = LocationUpdateFilter(startedAt: _start)
        ..offer(_sample(timestampMs: 2000), now: _start);
      final same = filter.offer(
        _sample(latitude: 35.0 + _step * 5, timestampMs: 2000),
        now: _start,
      );
      expect(same.decision, LocationUpdateDecision.rejectedStale);
    });

    test('古い測位の破棄も連続棄却回数に数える', () {
      final filter = LocationUpdateFilter(startedAt: _start)
        ..offer(_sample(timestampMs: 2000), now: _start)
        ..offer(_sample(timestampMs: 1000), now: _start);
      expect(filter.consecutiveRejections, 1);
    });

    test('未来の時刻の測位が1件来ても、強制更新で抜け出して更新が続く', () {
      final filter = LocationUpdateFilter(startedAt: _start)
        // 端末の時計のずれなどで、1時間先の時刻が付いた測位。
        ..offer(_sample(timestampMs: 3600 * 1000), now: _start);
      const limit = LocationFilterThresholds.forceAcceptAfterRejections;

      // 以後の正しい時刻の測位は、しばらく古い扱いで捨てられる。
      for (var i = 1; i < limit; i++) {
        final result = filter.offer(
          _sample(latitude: 35.0 + _step * i, timestampMs: i * 1000),
          now: _start,
        );
        expect(result.decision, LocationUpdateDecision.rejectedStale);
      }

      // 連続棄却が上限に達したら強制採用し、時刻の基準も戻る。
      final forced = filter.offer(
        _sample(latitude: 35.0 + _step * limit, timestampMs: limit * 1000),
        now: _start,
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);

      // 基準が戻ったので、次の正しい時刻の測位は通常どおり採用される。
      final next = filter.offer(
        _sample(
          latitude: 35.0 + _step * (limit + 2),
          timestampMs: (limit + 1) * 1000,
        ),
        now: _start,
      );
      expect(next.decision, LocationUpdateDecision.accepted);
    });

    test('時刻が無い測位は順序を判定できないので、時刻による破棄はしない', () {
      final filter = LocationUpdateFilter(startedAt: _start)
        ..offer(_sample(timestampMs: 2000), now: _start);
      final result = filter.offer(
        _sample(latitude: 35.0 + _step * 5),
        now: _start,
      );
      expect(result.decision, LocationUpdateDecision.accepted);
    });
    test('古い測位の強制採用で最良の候補を書いても、時刻の基準は今回の測位に戻す', () {
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 10;
      final best = _sample(latitude: 35.0 + _step, timestampMs: 1000);
      final filter = LocationUpdateFilter(startedAt: _start)
        // 未来の時刻が付いた、精度の悪い測位(基準だけが未来へ進む)。
        ..offer(
          _sample(accuracy: bad + 100, timestampMs: 3600 * 1000),
          now: _start,
        )
        // 以後は古い扱い。1件目は精度が良く、強制更新の候補になる。
        ..offer(best, now: _start)
        ..offer(_sample(accuracy: bad, timestampMs: 2000), now: _start)
        ..offer(_sample(accuracy: bad, timestampMs: 3000), now: _start);

      final forced = filter.offer(
        _sample(latitude: 36, accuracy: bad, timestampMs: 4000),
        now: _start,
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);
      // 書くのは精度の良い候補。
      expect(forced.toWrite, best);

      // 基準は書いた候補(1000)ではなく今回の測位(4000)に戻っている。
      // その間の時刻の測位は、今回より古いので捨てる。
      final between = filter.offer(
        _sample(latitude: 37, timestampMs: 3500),
        now: _start,
      );
      expect(between.decision, LocationUpdateDecision.rejectedStale);

      // 今回より新しい測位は通常どおり判定される。
      final next = filter.offer(
        _sample(latitude: 37, timestampMs: 5000),
        now: _start,
      );
      expect(next.decision, LocationUpdateDecision.accepted);
    });
  });

  group('LocationUpdateFilter(強制更新で最良の測位を書く)', () {
    test('強制更新では、棄却していた間で最も精度の良い測位を書く', () {
      final filter = LocationUpdateFilter(startedAt: _start);
      const limit = LocationFilterThresholds.forceAcceptAfterRejections;
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 10;

      // 1件目だけ少しましな(それでも足切りを超える)測位にする。
      for (var i = 0; i < limit - 1; i++) {
        final result = filter.offer(
          _sample(
            latitude: 35.0 + _step * i,
            accuracy: i == 1 ? bad : bad + 100,
            timestampMs: i,
          ),
          now: _start,
        );
        expect(result.decision, LocationUpdateDecision.rejectedLowAccuracy);
      }

      final forced = filter.offer(
        _sample(latitude: 36, accuracy: bad + 200, timestampMs: limit),
        now: _start,
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);
      expect(forced.toWrite?.accuracy, bad);
      expect(forced.toWrite?.latitude, 35.0 + _step);
    });

    test('強制更新の回の測位が最良なら、それを書く', () {
      final filter = LocationUpdateFilter(startedAt: _start);
      const limit = LocationFilterThresholds.forceAcceptAfterRejections;
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 100;
      for (var i = 0; i < limit - 1; i++) {
        filter.offer(_sample(accuracy: bad), now: _start);
      }
      final forced = filter.offer(
        _sample(latitude: 36, accuracy: bad - 50),
        now: _start,
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);
      expect(forced.toWrite?.latitude, 36.0);
    });

    /// 送信開始から30秒弱たった時点(=時間による強制更新の直前)で、
    /// 1件棄却済みのフィルタを作る。
    LocationUpdateFilter nearTimeLimit(double accuracy) {
      return LocationUpdateFilter(
        startedAt: _start.subtract(
          LocationFilterThresholds.forceAcceptAfterElapsed,
        ),
      )..offer(
        _sample(accuracy: accuracy),
        now: _start.subtract(const Duration(seconds: 4)),
      );
    }

    test('時間による強制更新でも最良の測位を書く', () {
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 10;
      final filter = nearTimeLimit(bad);
      final forced = filter.offer(
        _sample(latitude: 36, accuracy: bad + 100),
        now: _start,
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);
      expect(forced.toWrite?.latitude, 35.0);
    });

    test('強制更新で書いた位置が、次のデッドバンド判定の基準になる', () {
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 10;
      final filter = nearTimeLimit(bad)
        ..offer(_sample(latitude: 36, accuracy: bad + 100), now: _start);
      // 強制更新で書いたのは35.0の測位なので、その近くはデッドバンドで棄却。
      final near = filter.offer(
        _sample(),
        now: _start.add(const Duration(seconds: 4)),
      );
      expect(near.decision, LocationUpdateDecision.rejectedDeadband);
    });

    test('古くなった候補は精度が良くても使わず、今回の測位を書く', () {
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 10;
      // 30秒前に受け取った、今回より精度の良い測位。
      final filter = LocationUpdateFilter(startedAt: _start)
        ..offer(_sample(accuracy: bad), now: _start);
      final forced = filter.offer(
        _sample(latitude: 36, accuracy: bad + 20),
        now: _start.add(LocationFilterThresholds.forceAcceptAfterElapsed),
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);
      expect(forced.toWrite?.latitude, 36.0);
    });

    test('古くなった候補は、精度が悪くても新しい測位で置き換える', () {
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 10;
      const limit = LocationFilterThresholds.forceAcceptAfterElapsed;
      const beforeLimit = Duration(seconds: 4);
      // 前提: 4秒前に来た候補は古くなっておらず、最初の候補は古くなっている。
      expect(
        beforeLimit,
        lessThan(LocationFilterThresholds.fallbackCandidateMaxAge),
      );
      expect(
        limit - beforeLimit,
        greaterThan(LocationFilterThresholds.fallbackCandidateMaxAge),
      );
      final filter = LocationUpdateFilter(startedAt: _start)
        ..offer(_sample(accuracy: bad), now: _start)
        // 最初の候補が古くなった後に来た、それより精度の悪い測位。
        ..offer(
          _sample(latitude: 36, accuracy: bad + 50),
          now: _start.add(limit - beforeLimit),
        );
      // 強制更新では、置き換わった新しい候補(36.0)が今回(37.0)より良いので
      // それを書く。置き換えずに最初の候補を持ち続けると、古くて使えず
      // 今回の測位が書かれてしまう。
      final forced = filter.offer(
        _sample(latitude: 37, accuracy: bad + 100),
        now: _start.add(limit),
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);
      expect(forced.toWrite?.latitude, 36.0);
    });

    test('採用したら最良候補は捨て、次の強制更新に持ち越さない', () {
      final filter = LocationUpdateFilter(startedAt: _start);
      const limit = LocationFilterThresholds.forceAcceptAfterRejections;
      const bad = LocationFilterThresholds.maxAcceptableAccuracyM + 10;
      filter
        // 以前の窓の、とても精度が良い(が古い)候補になりうる値。
        ..offer(_sample(accuracy: bad), now: _start)
        // 通常採用で窓がリセットされる。
        ..offer(_sample(latitude: 35.01), now: _start);
      for (var i = 0; i < limit - 1; i++) {
        filter.offer(_sample(latitude: 37, accuracy: bad + 50), now: _start);
      }
      final forced = filter.offer(
        _sample(latitude: 37, accuracy: bad + 50),
        now: _start,
      );
      expect(forced.decision, LocationUpdateDecision.acceptedByFallback);
      expect(forced.toWrite?.latitude, 37.0);
    });
  });

  group('moreAccurateSample', () {
    test('accuracyが小さい方を返す', () {
      final good = _sample();
      final bad = _sample(latitude: 36, accuracy: 50);
      expect(moreAccurateSample(bad, good), good);
      expect(moreAccurateSample(good, bad), good);
    });

    test('同じaccuracyなら新しく渡された方を返す', () {
      final older = _sample();
      final newer = _sample(latitude: 36);
      expect(moreAccurateSample(older, newer), newer);
    });

    test('accuracyがnullの測位は最も悪い扱い', () {
      final unknown = _sample(accuracy: null);
      final known = _sample(latitude: 36, accuracy: 500);
      expect(moreAccurateSample(unknown, known), known);
      expect(moreAccurateSample(known, unknown), known);
    });

    test('比べる相手が無ければ渡された測位をそのまま返す', () {
      final sample = _sample();
      expect(moreAccurateSample(null, sample), sample);
    });
  });
}
