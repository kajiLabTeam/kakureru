import 'package:freezed_annotation/freezed_annotation.dart';

part 'marker_cluster.freezed.dart';

/// この画面距離(論理px)以内にいる人を1つのクラスタにまとめる。
const double kClusterPx = 60;

/// クラスタの四角の一辺(論理px)。
const double kClusterBoxSize = 64;

/// 単独アイコン(白フチ込み)の一辺(論理px)。
const double kIconSize = 40;

/// クラスタにまとめる入力1人ぶん。x/yは画面座標。
typedef ClusterInput = ({String uid, double x, double y, bool isDemon});

/// 近い人をまとめた1グループ。[x]/[y]はメンバーの画面座標の重心。
///
/// メンバーが1人だけなら単独マーカーとして扱う([isSingle])。
@freezed
abstract class MarkerCluster with _$MarkerCluster {
  /// クラスタを作る。
  const factory MarkerCluster({
    required List<ClusterInput> members,
    required double x,
    required double y,
  }) = _MarkerCluster;

  const MarkerCluster._();

  /// 1人だけのクラスタか(アイコン+名前で出す)。
  bool get isSingle => members.length == 1;

  /// 鬼の人数。
  int get demonCount => members.where((m) => m.isDemon).length;

  /// 逃走者の人数。
  int get fugitiveCount => members.length - demonCount;
}

/// 画面座標の近い人をまとめる。
///
/// 1. uid昇順に並べる(並び順を固定しないと、位置の更新のたびに
///    まとまり方が変わってチラつく)
/// 2. 先頭から、まだどこにも入っていない人を起点にする
/// 3. 起点から[thresholdPx]以内の未割り当ての人を同じクラスタに入れる
/// 4. 表示位置はメンバーの重心
///
/// 起点との距離だけで判定する(数珠つなぎにはしない)ので、クラスタの
/// 大きさは最大でも[thresholdPx]の2倍に収まる。人数は多くても10人程度
/// なので総当たり(O(n^2))で足りる。
List<MarkerCluster> clusterMarkers(
  List<ClusterInput> inputs,
  double thresholdPx,
) {
  final sorted = [...inputs]..sort((a, b) => a.uid.compareTo(b.uid));
  final assigned = List<bool>.filled(sorted.length, false);
  final limit = thresholdPx * thresholdPx;
  final clusters = <MarkerCluster>[];

  for (var i = 0; i < sorted.length; i++) {
    if (assigned[i]) continue;
    assigned[i] = true;
    final seed = sorted[i];
    final members = [seed];
    for (var j = i + 1; j < sorted.length; j++) {
      if (assigned[j]) continue;
      final dx = sorted[j].x - seed.x;
      final dy = sorted[j].y - seed.y;
      if (dx * dx + dy * dy <= limit) {
        assigned[j] = true;
        members.add(sorted[j]);
      }
    }
    final x = members.fold<double>(0, (sum, m) => sum + m.x) / members.length;
    final y = members.fold<double>(0, (sum, m) => sum + m.y) / members.length;
    clusters.add(MarkerCluster(members: members, x: x, y: y));
  }
  return clusters;
}

/// クラスタの内訳ラベル。「鬼 1 ・ 逃走者 2」。鬼が0人なら「逃走者 3」、
/// 逃走者が0人なら「鬼 2」だけにする。
String clusterBreakdownLabel({required int demons, required int fugitives}) {
  return [
    if (demons > 0) '鬼 $demons',
    if (fugitives > 0) '逃走者 $fugitives',
  ].join(' ・ ');
}

/// 幅[labelWidth]のラベルを、中心が[centerX]にあるまま置くと画面
/// (幅[screenWidth])の端で切れるとき、内側へ寄せる量(論理px)を返す。
/// 収まるなら0。ラベルが画面より広い場合は左端に合わせる。
double labelShiftIntoView({
  required double centerX,
  required double labelWidth,
  required double screenWidth,
  double margin = 4,
}) {
  final left = centerX - labelWidth / 2;
  final right = centerX + labelWidth / 2;
  if (left < margin) return margin - left;
  if (right > screenWidth - margin) {
    final shift = screenWidth - margin - right;
    // 右へ寄せすぎて左が切れる(画面より広い)ときは左端優先。
    return left + shift < margin ? margin - left : shift;
  }
  return 0;
}
