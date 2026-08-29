import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:flutter_map/flutter_map.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// 自分の位置が全く分からない間の暫定センター(東京駅)。
/// あくまで「世界地図の原点が出るよりまし」という仮の値。
/// GamePage・RoomSettingPageの両方で使うのでここに集約する。
const fallbackMapCenter = latlong.LatLng(35.681236, 139.767125);

/// プレイエリアとして許すサイズ(対角線の距離、メートル)の下限。
///
/// これを設けないと、タップに近いごく短いドラッグでも矩形として保存でき、
/// 南西端と北東端がほぼ同座標のエリアが出来てしまう。ゲーム中の地図は
/// `CameraConstraint.containCenter` でカメラ中心をエリア内に縛るため、
/// そのエリアが1点に潰れているとカメラが完全に固定され地図を一切
/// 動かせなくなる。
const gameAreaMinDiagonalMeters = 10.0;

/// プレイエリアとして許すサイズ(対角線の距離、メートル)の上限。
///
/// [buildGameMapOptions] は初期カメラをエリアの中心(`LatLngBounds.
/// simpleCenter`)に置くが、対角線が極端に長い(=経度方向に大きく広がった)
/// エリアではこの中心付近でも計算誤差が無視できなくなりうる。「歩いて
/// 遊ぶかくれんぼ」の範囲としても20kmは十分に広く、そうした極端なケースを
/// 実運用から締め出すための上限として設定している。
const gameAreaMaxDiagonalMeters = 20000.0;

/// [diagonalMeters] がプレイエリアとして許容範囲内かを確認し、範囲外なら
/// ユーザーに見せる理由を返す。範囲内ならnull。
String? describeGameAreaSizeError(double diagonalMeters) {
  if (diagonalMeters < gameAreaMinDiagonalMeters) {
    return 'エリアが小さすぎます。もう少し大きくドラッグしてください';
  }
  if (diagonalMeters > gameAreaMaxDiagonalMeters) {
    final maxKm = (gameAreaMaxDiagonalMeters / 1000).round();
    return 'エリアが大きすぎます(対角線${maxKm}km以内にしてください)';
  }
  return null;
}

/// プレイエリアを囲む矩形。エリア未設定(頂点3未満)ならnull。
LatLngBounds? gameAreaBounds(List<LatLng> gameArea) {
  if (gameArea.length < 3) return null;
  return LatLngBounds.fromPoints(toLatLngPoints(gameArea));
}

/// ゲーム中の地図のカメラ設定を組み立てる。
///
/// [areaBounds] があれば、その範囲だけを映す地図にする。無ければ
/// [fallbackCenter] を中心にした従来どおりの地図。
///
/// **不変条件**: 出来上がった [MapOptions] の初期カメラは、必ず
/// `cameraConstraint` を満たしていなければならない。満たしていないと
/// FlutterMapが内部のassertでビルド時に例外を投げ続け、画面が固まる
/// (MapControllerImpl.options のassert)。`initialCameraFit` は
/// レイアウト確定後にしか適用されず、それまでのカメラは `initialCenter` で
/// 決まるため、エリア指定時は `initialCenter` にエリアの中心を必ず渡す。
/// この不変条件は game_map_options_test.dart で検証している。
MapOptions buildGameMapOptions({
  required LatLngBounds? areaBounds,
  required latlong.LatLng fallbackCenter,
}) {
  if (areaBounds == null) {
    return MapOptions(initialCenter: fallbackCenter, initialZoom: _defaultZoom);
  }

  return MapOptions(
    // 制限(cameraConstraint)の内側から始めるための初期位置。
    // initialCameraFitが効くまでの間はこの値がカメラ位置になる。
    //
    // `center`(大圏中心)ではなく`simpleCenter`(緯度経度それぞれの単純な
    // 中点)を使う。大圏中心は経度方向に大きく広がったエリアだと緯度が
    // bounds の外側へ飛び出すことがあり(例: 緯度45°・経度200°スパンの
    // 矩形で中心緯度が80°まで飛ぶ)、そうなると初期カメラが
    // `cameraConstraint` を満たせず上記の不変条件が破れて画面が固まる。
    // `simpleCenter` は定義上常にbounds内に収まるためこの問題が起きない。
    initialCenter: areaBounds.simpleCenter,
    initialZoom: _defaultZoom,
    initialCameraFit: CameraFit.bounds(
      bounds: areaBounds,
      padding: const EdgeInsets.all(16),
      // 面積がごく小さいエリアだと、フィットに必要な倍率が発散して
      // ズーム値が無限大になりうる。地図タイルの実解像度も超えるので、
      // ここで上限を切っておく。
      maxZoom: _maxFitZoom,
    ),
    // 端まで見せたいので中心の制限(containCenter)にとどめる。カメラの縁で
    // 制限(contain)すると、エリアより広くは映せない=エリア全体を一度に
    // 見られないうえ、初期カメラが必ず制限違反になり上記のassertを踏む。
    cameraConstraint: CameraConstraint.containCenter(bounds: areaBounds),
  );
}

const _defaultZoom = 17.0;

/// エリアへのフィットで許す最大ズーム。OpenStreetMapのタイルは19までしか
/// 実データが無いため、それ以上寄っても情報は増えない。
const _maxFitZoom = 19.0;
