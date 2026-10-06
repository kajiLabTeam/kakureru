import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/map/repository/marker_cluster.dart';
import 'package:kakureru/features/room/view/game/cluster_marker.dart';

const _cluster = MarkerCluster(
  members: [
    (uid: 'a', x: 0, y: 0, isDemon: false),
    (uid: 'b', x: 1, y: 1, isDemon: false),
    (uid: 'c', x: 2, y: 2, isDemon: false),
  ],
  x: 1,
  y: 1,
);

void main() {
  testWidgets('内訳ラベルの黒帯は文字幅に収まり、マーカー幅いっぱいに広がらない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: kClusterMarkerWidth,
            child: ClusterMarkerView(cluster: _cluster, onTap: () {}),
          ),
        ),
      ),
    );

    final band = find.ancestor(
      of: find.text('逃走者 3'),
      matching: find.byType(Container),
    );
    final width = tester.getSize(band.first).width;
    expect(width, lessThan(kClusterMarkerWidth));
    // 見積もりとも大きくずれない(画面端の寄せ量の計算がこれに依存する)。
    expect(width, closeTo(clusterLabelWidthEstimate('逃走者 3'), 24));
  });

  testWidgets('タップするとonTapが呼ばれる', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ClusterMarkerView(cluster: _cluster, onTap: () => taps++),
        ),
      ),
    );
    await tester.tap(find.text('3'));
    expect(taps, 1);
  });

  testWidgets('選べない人をタップしても、シートは閉じず何も返さない', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showClusterSheet(
                context,
                members: const [
                  (uid: 'a', name: 'アリス', isDemon: false, selectable: false),
                  (uid: 'b', name: 'ボブ', isDemon: true, selectable: true),
                ],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('アリス'));
    await tester.pumpAndSettle();
    expect(find.byType(ClusterSheet), findsOneWidget);

    await tester.tap(find.text('ボブ'));
    await tester.pumpAndSettle();
    expect(find.byType(ClusterSheet), findsNothing);
    expect(picked, 'b');
  });
}
