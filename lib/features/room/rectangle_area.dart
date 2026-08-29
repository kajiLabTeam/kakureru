import 'dart:math';

import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// ドラッグの開始点・終了点から、矩形の四隅をLatLngのListとして返す。
///
/// 開始点・終了点がどちらが左上/右下でも(逆方向にドラッグしても)常に
/// 正しい矩形になるよう、緯度・経度それぞれの最小値/最大値から組み立てる。
/// 頂点は左下→右下→右上→左上の順(反時計回り)。
///
/// `RoomSetting.gameArea` は3点以上のポリゴンを想定したスキーマになって
/// いるため、矩形も「頂点4つのポリゴン」として保存する(スキーマ変更不要)。
List<LatLng> calculateRectangleCorners(LatLng start, LatLng end) {
  final minLat = min(start.lat, end.lat);
  final maxLat = max(start.lat, end.lat);
  final minLng = min(start.lng, end.lng);
  final maxLng = max(start.lng, end.lng);

  return [
    LatLng(lat: minLat, lng: minLng),
    LatLng(lat: minLat, lng: maxLng),
    LatLng(lat: maxLat, lng: maxLng),
    LatLng(lat: maxLat, lng: minLng),
  ];
}

/// `RoomSetting.gameArea`(独自のLatLng)をflutter_map/latlong2が使う
/// `latlong.LatLng` へ変換する。地図描画のたびに複数箇所で必要になる
/// 変換なのでここに集約する。
List<latlong.LatLng> toLatLngPoints(List<LatLng> points) =>
    points.map((p) => latlong.LatLng(p.lat, p.lng)).toList();
