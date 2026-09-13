import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_grid.freezed.dart';

/// 緯度・経度が属するグリッドセルの範囲(緯度経度の矩形)。
@freezed
abstract class GridCellBounds with _$GridCellBounds {
  const factory GridCellBounds({
    /// セル南端の緯度。
    required double south,

    /// セル北端の緯度。
    required double north,

    /// セル西端の経度。
    required double west,

    /// セル東端の経度。
    required double east,
  }) = _GridCellBounds;

  const GridCellBounds._();

  /// セル中心の緯度。
  double get centerLat => (south + north) / 2;

  /// セル中心の経度。
  double get centerLng => (west + east) / 2;
}

/// 赤道1度あたりのおおよその距離(メートル)。
const _metersPerDegreeLat = 111320.0;

/// 座標をグリッドセルへ丸め込む純粋関数(issue #39)。
///
/// 鬼から見た逃走者のGPS位置が「ピンポイントで分かりすぎる」課題への対応。
/// 円だと中心が推測できてしまうため、矩形のグリッドセルへ丸める方式にする。
///
/// 原点は赤道・グリニッジ子午線(緯度0・経度0)に固定する。プレイエリアの
/// 頂点など相対的な基準を使うと、参加者の端末ごとに基準がずれて同じ物理
/// 位置が異なるセルに丸められてしまう恐れがあるため、全端末が同じ結果に
/// なる絶対原点を使う。
///
/// 経度方向は、緯度が上がるほど経度1度が表す実距離が短くなる(cos補正)ため、
/// セルの南端緯度でのcos補正を掛けたセル幅を使う。[latitude] そのもの
/// (丸める前の連続値)を使うと、同じセルに入るはずのわずかに異なる緯度の
/// 座標同士でセル幅が微妙にずれ、西端/東端が一致しなくなる恐れがあるため、
/// 緯度をセル単位に丸めた後の値を補正の基準にする。
GridCellBounds gridCellFor({
  required double latitude,
  required double longitude,
  required int gridSizeMeters,
}) {
  final latStepDeg = gridSizeMeters / _metersPerDegreeLat;
  final latIndex = (latitude / latStepDeg).floor();
  final cellSouthLat = latIndex * latStepDeg;

  final metersPerDegreeLng =
      _metersPerDegreeLat * math.cos(cellSouthLat * math.pi / 180);
  final lngStepDeg = gridSizeMeters / metersPerDegreeLng;
  final lngIndex = (longitude / lngStepDeg).floor();

  return GridCellBounds(
    south: cellSouthLat,
    north: (latIndex + 1) * latStepDeg,
    west: lngIndex * lngStepDeg,
    east: (lngIndex + 1) * lngStepDeg,
  );
}
