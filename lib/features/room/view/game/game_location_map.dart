import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/game_map_options.dart';
import 'package:kakureru/features/room/location_grid.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// [GameLocationMap] をwidgetテストから必須引数を省いて組み立てる入口。
///
/// 「グリッド矩形を鬼にだけ描く」「resolveMarkerPositionへ
/// viewerRole/targetRoleを正しい順で渡す」といった配線は純粋関数の
/// テストでは一切押さえられない(取り違えても純粋関数のテストは全て通る)。
/// GamePage全体を立ち上げるにはFirebase・センサー系のproviderを丸ごと
/// 差し替える必要があり割に合わないため、地図だけをテストから直接組む。
@visibleForTesting
Widget buildLocationMapForTest({
  required List<UserLocation> locations,
  required List<RoomUser> users,
  required String? myUid,
  List<LatLng> gameArea = const [],
}) {
  return GameLocationMap(
    locations: locations,
    users: users,
    myUid: myUid,
    cachedPosition: null,
    gameArea: gameArea,
  );
}

/// 鬼視点で逃走者GPSをグリッド曖昧化する際のグリッドサイズ(issue #39)。
/// 以前は20m/50m/100mから選べたが、100m固定にした。
const gridSizeMeters = 100;

/// ゲーム中の地図。参加者のGPSピン、プレイエリアの境界と外側のマスク、
/// 鬼視点で逃走者を曖昧化するグリッドセルを描く。
///
/// 表示するかどうか(役割による可視性)の判断はGamePage側で済ませてある
/// 前提で、ここに渡された[locations]はそのまま全部描く。
class GameLocationMap extends HookWidget {
  /// すべての引数はGamePageが計算して渡す(このウィジェットはproviderを
  /// 一切読まない)。
  const GameLocationMap({
    super.key,
    required this.locations,
    required this.users,
    required this.myUid,
    required this.cachedPosition,
    required this.gameArea,
  });

  /// 地図に出す位置。自分から見えていい相手の分だけが渡ってくる。
  final List<UserLocation> locations;

  /// ピンのラベル(名前)と役割色を引くための参加者一覧。
  final List<RoomUser> users;

  /// 自分のuid。自分のピンだけ青で「自分」と表示する。
  final String? myUid;

  /// 端末にキャッシュされた直近の位置。実測が返る前の初期表示にだけ使う。
  final Position? cachedPosition;

  /// ルーム設定で指定されたプレイエリア。未設定なら空。
  final List<LatLng> gameArea;

  @override
  Widget build(BuildContext context) {
    final selfLocation = _findLocation(locations, myUid);
    final myRole = myUid == null ? null : findUser(users, myUid!)?.role;

    // プレイエリアが設定されていれば、地図はその範囲だけを映す。
    // 初期表示をエリアにフィットさせ、地図の中心がエリアから出ないよう制限し、
    // エリア外は影で覆う。未設定のルームでは従来どおり自分中心の地図にする。
    final areaBounds = gameAreaBounds(gameArea);
    // マスクと境界線の両方が使うので、毎秒のリビルドのたびに変換し直さない
    // よう一度だけ変換する。
    final areaPoints = useMemoized(
      () => areaBounds == null ? null : toLatLngPoints(gameArea),
      [gameArea],
    );

    // 自分の位置の情報源には優先度がある: 実測(GPS) > 端末キャッシュ > 何も無い。
    // 精度の低いソースから高いソースへ切り替わったタイミングだけ地図を
    // 動かす(常時追従させると自由にパン・ズームできなくなるため)。
    final positionTier = selfLocation != null
        ? 2
        : cachedPosition != null
        ? 1
        : 0;
    final currentCenter = selfLocation != null
        ? latlong.LatLng(selfLocation.latitude, selfLocation.longitude)
        : cachedPosition != null
        ? latlong.LatLng(cachedPosition!.latitude, cachedPosition!.longitude)
        : _initialFallbackCenter();

    final mapController = useMemoized(MapController.new);
    final bestTierShown = useRef(0);

    // GamePageは残り時間の更新で毎秒リビルドされる。CameraFitは同値でも
    // 別インスタンスだと「変わった」と判定されFlutterMap側の再設定が
    // 毎秒走るため、エリアが変わらない限り同じMapOptionsを使い回す。
    final mapOptions = useMemoized(
      () => buildGameMapOptions(
        areaBounds: areaBounds,
        fallbackCenter: currentCenter,
      ),
      [areaBounds],
    );

    useEffect(() {
      // エリア指定がある場合はエリア全体を映したままにする(自分の位置が
      // 取れるたびに寄せ直すと、せっかくのエリア表示が崩れるため)。
      if (areaBounds == null && positionTier > bestTierShown.value) {
        bestTierShown.value = positionTier;
        // MapControllerがまだレイアウト前だと move() が失敗しうるため、
        // フレーム確定後に呼ぶ。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            mapController.move(currentCenter, mapController.camera.zoom);
          } on Object {
            // 画面遷移直後などでmapがまだ存在しない場合は無視する。
          }
        });
      }
      return null;
    }, [positionTier, currentCenter.latitude, currentCenter.longitude]);

    // マーカー(アイコン+ラベル)と、鬼視点で逃走者に対してのみ描く
    // グリッドセル矩形(issue #39)を、位置ごとにまとめて組み立てる。
    final locationVisuals = locations
        .map(
          (location) => _buildLocationVisual(
            location,
            myRole,
            gridSizeMeters,
          ),
        )
        .toList();
    final gridPolygons = [
      for (final visual in locationVisuals)
        if (visual.gridPolygon != null) visual.gridPolygon!,
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: mapOptions,
          children: [
            // Phase 1では手軽さを優先し、追加設定・課金設定が不要な
            // CARTO Voyagerのラスタタイル(データ自体はOSM由来)をそのまま
            // 使う(flutter_map採用)。Google Mapsだと google_maps_flutter
            // 用のAPIキー発行と課金設定が要るため、開発初期の身内テスト
            // 用途には過剰。公開規模が大きくなったら自前タイルサーバや
            // 商用プロバイダへの切り替えを検討すること(無料タイルの
            // 利用ポリシー上、本番の常用には推奨されない)。
            buildMapTileLayer(context),
            if (areaPoints != null)
              PolygonLayer(
                polygons: [
                  _outsideMaskPolygon(areaPoints),
                  _areaBorderPolygon(areaPoints),
                ],
              ),
            if (gridPolygons.isNotEmpty) PolygonLayer(polygons: gridPolygons),
            MarkerLayer(
              markers: [for (final visual in locationVisuals) visual.marker],
            ),
            buildMapAttribution(),
          ],
        ),
        if (positionTier == 0)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('現在地を取得中...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// プレイエリアの外側を覆う影。外周を世界全体(緯度±90度・経度±180度)
  /// まで広げた矩形を塗り、エリアの形を穴として抜くことで「範囲の外」
  /// だけを暗くする。
  ///
  /// 外周をエリアの周りに小さく取る(エリア+一定マージンの矩形)方式だと、
  /// カメラ中心はエリア内に制限されていてもズームだけは制限しておらず
  /// (`buildGameMapOptions` は `minZoom` を設定していない)、ズームアウト
  /// すればマージンの外側にすぐ地の地図が見えてしまう。外周を世界全体に
  /// すれば、どれだけズームアウトしても常に画面全体を覆える。
  Polygon<Object> _outsideMaskPolygon(List<latlong.LatLng> areaPoints) {
    return Polygon(
      points: const [
        latlong.LatLng(-90, -180),
        latlong.LatLng(-90, 180),
        latlong.LatLng(90, 180),
        latlong.LatLng(90, -180),
      ],
      holePointsList: [areaPoints],
      color: Colors.black.withValues(alpha: 0.35),
    );
  }

  /// プレイエリアの境界線。ルーム設定画面と同じ青い破線で揃えている。
  Polygon<Object> _areaBorderPolygon(List<latlong.LatLng> areaPoints) {
    return Polygon(
      points: areaPoints,
      borderStrokeWidth: 2,
      borderColor: selfColor,
      pattern: StrokePattern.dashed(segments: const [8, 4]),
    );
  }

  /// 自分の位置(実測・キャッシュとも)がまだ無い間の初期センター。
  /// ルーム内の他の参加者が既にいればその位置、いなければ固定の暫定座標。
  latlong.LatLng _initialFallbackCenter() {
    if (locations.isNotEmpty) {
      final other = locations.first;
      return latlong.LatLng(other.latitude, other.longitude);
    }
    return fallbackMapCenter;
  }

  /// マーカー本体(アイコン+ラベル)と、鬼視点で逃走者に対してだけ追加される
  /// グリッドセルの矩形(issue #39)を組み立てる。
  ///
  /// アイコン・ラベルの役割表記はissue #42対応(色だけでなく形・表記でも
  /// 鬼/逃走者を見分けられるようにする)。
  ({Marker marker, Polygon<Object>? gridPolygon}) _buildLocationVisual(
    UserLocation location,
    UserRole? myRole,
    int gridSizeMeters,
  ) {
    final isSelf = location.uid == myUid;
    final user = findUser(users, location.uid);
    final targetRole = user?.role;
    // 自分のピンは自分の役割、他人のピンはそのuserの役割(見つからなければ
    // null=未知)を表示に使う。usersはroom.users全体だが、locations自体が
    // 呼び出し元(GamePage)でisVisibleToMeによって既に絞り込まれているため、
    // ここに現れるlocationの役割をそのまま出しても可視性ルールを迂回する
    // ことにはならない。
    final displayRole = isSelf ? myRole : targetRole;
    final color = isSelf ? selfColor : colorForRole(targetRole);
    // 役割が分かっていればroleThemeのアイコン(対称な形)を使う。役割が
    // 未知(user がroom.usersにまだ見つからない等)の間だけ、従来どおりの
    // location_pin(下端に尖った先端がある非対称な形)にフォールバックする。
    final usesRoleIcon = displayRole != null;
    final icon = usesRoleIcon
        ? roleThemeOf(displayRole).icon
        : Icons.location_pin;
    final label = markerLabelFor(
      uid: location.uid,
      myUid: myUid,
      displayName: user?.displayName,
      role: displayRole,
    );

    // 鬼視点で逃走者の位置だけ、正確な点ではなくグリッドセルに丸める
    // (issue #39)。丸め判定と描画点の計算自体はテスト可能な純粋関数
    // (resolveMarkerPosition)に切り出している。
    final resolved = resolveMarkerPosition(
      latitude: location.latitude,
      longitude: location.longitude,
      isSelf: isSelf,
      viewerRole: myRole,
      targetRole: targetRole,
      gridSizeMeters: gridSizeMeters,
    );
    final point = resolved.point;
    final cellBounds = resolved.cellBounds;

    final marker = Marker(
      point: point,
      // ラベル表示のため横幅を拡張(名前が長い場合は省略表示)。
      // 縦はアイコン(白フチ込みで40) + ラベル(~15) で余裕を持たせる。
      width: markerWidth,
      height: markerHeight,
      // 役割アイコン(local_fire_department/directions_run)はlocation_pinと
      // 異なり下端に尖った先端が無い対称な形なので、アイコンの中心を実座標に
      // 合わせる。location_pinへのフォールバック時は旧実装同様、先端を座標に
      // 合わせるためtopCenterのままにする。
      alignment: usesRoleIcon ? markerIconCenterAlignment : Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MarkerIcon(icon: icon, color: color),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );

    final gridPolygon = cellBounds == null
        ? null
        : Polygon<Object>(
            points: [
              latlong.LatLng(cellBounds.south, cellBounds.west),
              latlong.LatLng(cellBounds.south, cellBounds.east),
              latlong.LatLng(cellBounds.north, cellBounds.east),
              latlong.LatLng(cellBounds.north, cellBounds.west),
            ],
            color: color.withValues(alpha: 0.25),
            borderStrokeWidth: 2,
            borderColor: color,
          );

    return (marker: marker, gridPolygon: gridPolygon);
  }

  UserLocation? _findLocation(List<UserLocation> locations, String? uid) {
    if (uid == null) return null;
    for (final location in locations) {
      if (location.uid == uid) return location;
    }
    return null;
  }
}

/// GPSマーカーの幅。ラベル(名前)が入る幅。
const markerWidth = 72.0;

/// GPSマーカーの高さ。アイコン+ラベル分。
const markerHeight = 56.0;

/// マーカーのアイコン(白フチ込み)の一辺。[MarkerIcon] のSizedBoxと合わせる。
const markerIconSize = 40.0;

/// アイコンの中心を実座標に合わせるためのalignment。
///
/// flutter_mapのMarker.alignmentは「マーカーwidget全体」の中のどの点を
/// 実座標に合わせるかの指定で、`Alignment.center` はwidget全体
/// ([markerWidth]×[markerHeight])の中心、つまりアイコンとラベルを
/// 合わせた中心を座標に置く。マーカーの子はColumn[アイコン, ラベル]で
/// 上詰めに並ぶため、アイコンの中心はwidget上端から
/// [markerIconSize]/2 の位置にあり、`Alignment.center`のままだと
/// アイコンは実座標より約8論理px北へずれる。
/// alignment.y は widget中心を0・下端を1とする比なので、
/// (アイコン中心 - widget中心) / (widget高さ/2) を指定して一致させる。
const markerIconCenterAlignment = Alignment(
  0,
  (markerIconSize / 2 - markerHeight / 2) / (markerHeight / 2),
);

/// GPSピンの描画位置を決める純粋関数(issue #39)。
///
/// 鬼視点で逃走者の位置を見るとき(isSelfがfalseかつviewerRoleが鬼、
/// targetRoleが逃走者のとき)だけ、正確な座標ではなくグリッドセル
/// (gridCellFor)の中心を返す(このときcellBoundsも併せて返すので、
/// 呼び出し側はそのままセルの矩形描画に使える)。それ以外(自分・同ロール・
/// 逃走者視点で見る鬼)は常に正確な座標をそのまま返し、cellBoundsはnull。
///
/// 円だと中心が推測できてしまうため矩形のグリッドセルへ丸める方式にしている
/// (issue #39の背景)。マーカーの描画点自体をセル中心に置き換えるのは、
/// 実座標のままセルの矩形だけ追加しても、ピンの位置で真の座標が
/// 分かってしまい曖昧化にならないため。
@visibleForTesting
({latlong.LatLng point, GridCellBounds? cellBounds}) resolveMarkerPosition({
  required double latitude,
  required double longitude,
  required bool isSelf,
  required UserRole? viewerRole,
  required UserRole? targetRole,
  required int gridSizeMeters,
}) {
  final isGridObfuscated =
      !isSelf &&
      viewerRole == UserRole.demon &&
      targetRole == UserRole.fugitive;
  if (!isGridObfuscated) {
    return (point: latlong.LatLng(latitude, longitude), cellBounds: null);
  }

  final cellBounds = gridCellFor(
    latitude: latitude,
    longitude: longitude,
    gridSizeMeters: gridSizeMeters,
  );
  return (
    point: latlong.LatLng(cellBounds.centerLat, cellBounds.centerLng),
    cellBounds: cellBounds,
  );
}

/// GPSピンに表示するラベルテキストを返す(issue #13、役割表記はissue #42)。
///
/// 自分のピンは「自分」と表示して一目で分かるようにする。
/// 他のプレイヤーは displayName を表示する。displayName が空(参加直後で
/// まだ届いていない等)のときは「?」をフォールバックにする。
///
/// [role] には「見えていい役割」だけを渡すこと(呼び出し側で
/// role_visibility.dart による絞り込み後の値を渡す想定)。role が
/// null(未知、または見せるべきでない)なら役割表記は付けない。
@visibleForTesting
String markerLabelFor({
  required String uid,
  required String? myUid,
  required String? displayName,
  required UserRole? role,
}) {
  final suffix = switch (role) {
    UserRole.demon => '（鬼）',
    UserRole.fugitive => '（逃走者）',
    null => '',
  };
  if (uid == myUid) return '自分$suffix';
  final name = displayName ?? '';
  return name.isEmpty ? '?$suffix' : '$name$suffix';
}

/// 役割アイコンの視認性向上(issue #42「地図タイルの上でもピンの輪郭が
/// 視認できる」)のため、白い縁取りを重ねて描く。アイコンフォント自体には
/// 縁取り指定が無いため、同じアイコンを白・大きめで下に敷き、その上に
/// 本来の色・サイズで重ねることでフチのように見せている。
class MarkerIcon extends StatelessWidget {
  /// [icon]を[color]で描き、その下に白い縁取りを敷く。
  const MarkerIcon({super.key, required this.icon, required this.color});

  /// 役割に対応するアイコン(role_theme.dart参照)。
  final IconData icon;

  /// アイコン本体の色。縁取りは常に白。
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: markerIconSize,
      height: markerIconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: markerIconSize, color: Colors.white),
          Icon(icon, size: 34, color: color),
        ],
      ),
    );
  }
}
