import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart' show BuildContext, EdgeInsets;
import 'package:flutter_map/flutter_map.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// 自分の位置が全く分からない間の暫定センター(東京駅)。
/// あくまで「世界地図の原点が出るよりまし」という仮の値。
/// GamePage・RoomSettingPageの両方で使うのでここに集約する。
const fallbackMapCenter = latlong.LatLng(35.681236, 139.767125);

/// CARTOのAPIキー。2026年8月末以降、キー無しのリクエストは透かし入りの
/// タイルが返るようになったため必須(READMEの「地図タイルのAPIキー」参照)。
/// ソースコードに直書きせず、`--dart-define-from-file=dart_defines.json`
/// (またはCIでは未設定のまま)で `String.fromEnvironment` から読む。
const cartoApiKey = String.fromEnvironment('CARTO_API_KEY');

/// 地図タイルのURL(CARTO Voyagerスタイル)。地図データ自体はOSM由来だが、
/// レンダリングはCARTOのラスタタイルを使う。GamePage・RoomSettingPageの
/// 両方で使うのでここに集約する(定義を1か所にまとめ、見た目のずれを防ぐ)。
const mapTileUrlTemplate =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}'
    '{r}.png?key=$cartoApiKey';

/// [mapTileUrlTemplate] の `{s}` に使うサブドメイン。
const mapTileSubdomains = ['a', 'b', 'c', 'd'];

/// タイルサーバーへのリクエストで送るアプリ識別子。
const mapTileUserAgentPackageName = 'me.nenex.kakureru';

/// [cartoApiKey] 未設定の警告を1回だけ出すためのフラグ。
bool _cartoApiKeyWarned = false;

/// GamePage・RoomSettingPageで共通の地図タイルレイヤー。
///
/// `{r}` (高解像度タイル)は端末の画素密度に応じて[RetinaMode.isHighDensity]
/// で自動判定する。
TileLayer buildMapTileLayer(BuildContext context) {
  if (cartoApiKey.isEmpty && kDebugMode && !_cartoApiKeyWarned) {
    _cartoApiKeyWarned = true;
    debugPrint(
      'CARTO_API_KEY が未設定です。地図タイルに透かしが表示されます。'
      ' READMEの「地図タイルのAPIキー」を参照してください。',
    );
  }
  return TileLayer(
    urlTemplate: mapTileUrlTemplate,
    subdomains: mapTileSubdomains,
    retinaMode: RetinaMode.isHighDensity(context),
    userAgentPackageName: mapTileUserAgentPackageName,
  );
}

/// 地図タイルの著作権表記。CARTO Voyagerの利用条件上、OSMとCARTO両方の
/// クレジット表示が必須のため、GamePage・RoomSettingPageの両方に載せる。
/// url_launcherは依存に無いため、タップでのリンク開きはしない。
RichAttributionWidget buildMapAttribution() {
  return const RichAttributionWidget(
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      TextSourceAttribution('CARTO'),
    ],
  );
}

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
    return MapOptions(
      initialCenter: fallbackCenter,
      initialZoom: _defaultZoom,
      interactionOptions: gameMapInteractionOptions,
    );
  }

  return MapOptions(
    interactionOptions: gameMapInteractionOptions,
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

/// ゲーム中の地図で許す操作。既定(`InteractiveFlag.all`)から回転だけを外す。
///
/// 回転を許すと、2本指でひねった分だけ地図が回り、エリア外アラートの矢印
/// (絶対方位で描いている)が実際の方向とずれる。このアプリには方位を北に
/// 戻すUIが無く、一度回すと戻せないため、回転自体を切る方を選んだ。
/// パン・ピンチズーム・ダブルタップズームなど他の操作はそのまま使える。
const gameMapInteractionOptions = InteractionOptions(
  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
);

const _defaultZoom = 17.0;

/// エリアへのフィットで許す最大ズーム。OpenStreetMapのタイルは19までしか
/// 実データが無いため、それ以上寄っても情報は増えない。
const _maxFitZoom = 19.0;
