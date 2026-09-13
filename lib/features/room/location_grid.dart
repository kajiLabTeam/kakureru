import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_grid.freezed.dart';

/// 鬼視点で逃走者の位置を曖昧化するためのグリッドサイズ(メートル)の選択肢。
/// UIでの切り替え候補と既定値(50m)はここに集約する(issue #39)。
const gridSizeOptionsMeters = [20, 50, 100];

/// グリッドサイズの既定値(50m)。切り替えUIの初期値、およびセッションを
/// またいだ永続化はしない(issue #39のスコープ外)ため、画面を開き直す
/// たびにここへ戻る。
const defaultGridSizeMeters = 50;

/// 緯度1度あたりのおおよその距離(メートル)。地球を球とみなした近似値
/// (2πR/360, R=6371km)。ゲームで使うグリッドサイズ(20〜100m程度)に対して
/// 十分な精度がある。
const _metersPerDegreeLatitude = 111320.0;

/// 座標がスナップされたグリッドセルの範囲(緯度経度の矩形)。
///
/// [south]/[west] がセルの南西角、[north]/[east] が北東角。
@freezed
abstract class GridCell with _$GridCell {
  /// [south]/[west] がセルの南西角、[north]/[east] が北東角。
  const factory GridCell({
    required double south,
    required double north,
    required double west,
    required double east,
  }) = _GridCell;

  const GridCell._();

  /// セルの中心緯度(矩形の代表点としてラベル表示等に使う)。
  double get centerLatitude => (south + north) / 2;

  /// セルの中心経度(矩形の代表点としてラベル表示等に使う)。
  double get centerLongitude => (west + east) / 2;
}

/// 緯度経度をグリッドセルへスナップする。
///
/// 赤道(緯度0)・グリニッジ子午線(経度0)を原点とした絶対座標を基準に
/// 丸めるため、どの端末で計算しても同じ物理位置なら同じセルになる
/// (ゲームエリア等、ルームごとに変わる相対原点を使うと、鬼の端末ごとに
/// セル境界がずれてしまう恐れがあるため採用しない)。
///
/// 経度方向は緯度が高くなるほど1度あたりの実距離が短くなる
/// (cos(緯度)に比例)ため、[latitude] に応じて経度方向のステップ幅を
/// 補正する。
GridCell snapToGridCell({
  required double latitude,
  required double longitude,
  required int gridSizeMeters,
}) {
  final latStepDeg = gridSizeMeters / _metersPerDegreeLatitude;
  final south = (latitude / latStepDeg).floor() * latStepDeg;

  // 経度方向のステップ幅は、入力の生の緯度ではなくスナップ後の緯度(south)
  // から計算する。生の緯度をそのまま使うと、同じセルの範囲内にある
  // (GPSの誤差程度でごくわずかに緯度が異なる)2つの座標が、cos補正の
  // 端数のずれによって別のセル境界を計算してしまうことがある。south を
  // 基準にすれば、同じ緯度の行に属する座標は常に同じステップ幅になる。
  final cosLat = cos(south * pi / 180).abs();
  final lngStepDeg = gridSizeMeters / (_metersPerDegreeLatitude * cosLat);
  final west = (longitude / lngStepDeg).floor() * lngStepDeg;

  return GridCell(
    south: south,
    north: south + latStepDeg,
    west: west,
    east: west + lngStepDeg,
  );
}
