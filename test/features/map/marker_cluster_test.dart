import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/map/repository/marker_cluster.dart';

ClusterInput p(String uid, double x, double y, {bool demon = false}) =>
    (uid: uid, x: x, y: y, isDemon: demon);

List<List<String>> uids(List<MarkerCluster> cs) => [
  for (final c in cs) [for (final m in c.members) m.uid],
];

void main() {
  group('clusterMarkers', () {
    test('しきい値ちょうど(60px)は同じクラスタに入る', () {
      final cs = clusterMarkers([p('a', 0, 0), p('b', 60, 0)], kClusterPx);
      expect(uids(cs), [
        ['a', 'b'],
      ]);
    });

    test('61px離れていたら別のクラスタになる', () {
      final cs = clusterMarkers([p('a', 0, 0), p('b', 61, 0)], kClusterPx);
      expect(uids(cs), [
        ['a'],
        ['b'],
      ]);
    });

    test('全員が同じ点にいれば1つにまとまる', () {
      final cs = clusterMarkers([
        p('a', 10, 10),
        p('b', 10, 10),
        p('c', 10, 10),
      ], kClusterPx);
      expect(cs, hasLength(1));
      expect(cs.single.members, hasLength(3));
    });

    test('離れた2グループは2つのクラスタになる', () {
      final cs = clusterMarkers([
        p('a', 0, 0),
        p('b', 20, 0),
        p('c', 500, 500),
        p('d', 520, 500),
      ], kClusterPx);
      expect(uids(cs), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('入力の順番を変えても結果は同じ(uid順に固定される)', () {
      final inputs = [
        p('c', 30, 0),
        p('a', 0, 0),
        p('d', 300, 0),
        p('b', 15, 0),
      ];
      final a = clusterMarkers(inputs, kClusterPx);
      final b = clusterMarkers(inputs.reversed.toList(), kClusterPx);
      expect(a, b);
      expect(uids(a), [
        ['a', 'b', 'c'],
        ['d'],
      ]);
    });

    test('1人のクラスタは単独マーカーとして返る', () {
      final cs = clusterMarkers([p('a', 5, 7, demon: true)], kClusterPx);
      expect(cs, hasLength(1));
      expect(cs.single.isSingle, isTrue);
      expect(cs.single.x, 5);
      expect(cs.single.y, 7);
    });

    test('入力が空なら空', () {
      expect(clusterMarkers([], kClusterPx), isEmpty);
    });

    test('重心はメンバーの画面座標の平均', () {
      final cs = clusterMarkers([
        p('a', 0, 0),
        p('b', 30, 0),
        p('c', 0, 30),
      ], kClusterPx);
      expect(cs.single.x, closeTo(10, 1e-9));
      expect(cs.single.y, closeTo(10, 1e-9));
    });

    test('鬼と逃走者の人数を数える', () {
      final c = clusterMarkers([
        p('a', 0, 0, demon: true),
        p('b', 1, 0),
        p('c', 2, 0),
      ], kClusterPx).single;
      expect(c.demonCount, 1);
      expect(c.fugitiveCount, 2);
    });
  });

  group('clusterBreakdownLabel', () {
    test('鬼がいれば「鬼 1 ・ 逃走者 2」', () {
      expect(clusterBreakdownLabel(demons: 1, fugitives: 2), '鬼 1 ・ 逃走者 2');
    });

    test('鬼が0人なら「逃走者 3」だけ', () {
      expect(clusterBreakdownLabel(demons: 0, fugitives: 3), '逃走者 3');
    });

    test('逃走者が0人なら「鬼 2」だけ', () {
      expect(clusterBreakdownLabel(demons: 2, fugitives: 0), '鬼 2');
    });
  });

  group('labelShiftIntoView', () {
    test('収まるなら動かさない', () {
      expect(
        labelShiftIntoView(centerX: 200, labelWidth: 100, screenWidth: 400),
        0,
      );
    });

    test('左端で切れるなら右へ寄せる', () {
      expect(
        labelShiftIntoView(centerX: 10, labelWidth: 100, screenWidth: 400),
        44,
      );
    });

    test('右端で切れるなら左へ寄せる', () {
      expect(
        labelShiftIntoView(centerX: 390, labelWidth: 100, screenWidth: 400),
        -44,
      );
    });
  });
}
