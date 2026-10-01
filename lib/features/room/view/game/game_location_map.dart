import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/room/game_map_options.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// [GameLocationMap] をwidgetテストから必須引数を省いて組み立てる入口。
///
/// 「どの役割から見ても実座標にピンを置く」「重なったピンをずらす」と
/// いった配線は純粋関数のテストでは押さえられない。
/// GamePage全体を立ち上げるにはFirebase・センサー系のproviderを丸ごと
/// 差し替える必要があり割に合わないため、地図だけをテストから直接組む。
@visibleForTesting
Widget buildLocationMapForTest({
  required List<UserLocation> locations,
  required List<RoomUser> users,
  required String? myUid,
  List<LatLng> gameArea = const [],
  List<MissionMapPoint> missionPoints = const [],
  bool enlargeDemonIcon = false,
  Set<String> enlargedUserUids = const {},
}) {
  return GameLocationMap(
    locations: locations,
    users: users,
    myUid: myUid,
    cachedPosition: null,
    gameArea: gameArea,
    missionPoints: missionPoints,
    enlargeDemonIcon: enlargeDemonIcon,
    enlargedUserUids: enlargedUserUids,
  );
}

/// 地図に出すミッションの地点(アクセスポイント)と判定の半径(m)。
typedef MissionMapPoint = ({double lat, double lng, double radiusM});

/// `big_demon_icon` が効いているあいだの、鬼のピンの倍率。
const enlargedDemonIconScale = 2.0;

/// ゲーム中の地図。参加者のGPSピン、プレイエリアの境界と外側のマスクを描く。
///
/// 以前は鬼から見た逃走者の位置を100mのマス目に丸めていた(issue #39)が、
/// プレイテストを経て廃止した(issue #118)。同じマスにいる逃走者のピンが
/// 全員まったく同じ点に重なり、1人しか見えない原因にもなっていた
/// (issue #123)。
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
    this.missionPoints = const [],
    this.enlargeDemonIcon = false,
    this.enlargedUserUids = const {},
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

  /// いま受けているミッションの、空いているアクセスポイント。それぞれに
  /// 点と判定範囲の円を描く。無ければ空。
  final List<MissionMapPoint> missionPoints;

  /// 鬼のピンを[enlargedDemonIconScale]倍にするか(ごほうび `big_demon_icon`)。
  /// 自分のピンは大きくしない。
  final bool enlargeDemonIcon;

  /// ハズレ `enlarge_self_icon` を引いていて、鬼の地図でピンを
  /// [enlargedDemonIconScale]倍にする対象の逃走者uid。鬼側の画面にだけ
  /// 渡される想定(逃走者には自分のピンを拡大して見せない)。
  final Set<String> enlargedUserUids;

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

    // 判定範囲の円は地点が変わらない限り同じなので、毎秒の再描画で
    // 作り直さない(円周の36点を測地線で計算するため)。
    final missionRanges = useMemoized(
      () => [for (final point in missionPoints) _missionRangePolygon(point)],
      [
        for (final point in missionPoints) ...[
          point.lat,
          point.lng,
          point.radiusM,
        ],
      ],
    );

    // マーカー(アイコン+ラベル)を位置ごとに組み立てる。
    final locationVisuals = locations
        .map((location) => _buildLocationVisual(location, myRole))
        .toList();

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
            if (missionPoints.isNotEmpty) ...[
              PolygonLayer(polygons: missionRanges),
              MarkerLayer(
                markers: [
                  for (final point in missionPoints) _missionMarker(point),
                ],
              ),
            ],
            AnimatedMarkerLayer(
              markers: [
                for (final visual in locationVisuals)
                  (id: visual.id, marker: visual.marker),
              ],
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

  /// アクセスポイントの判定範囲(半径 `radiusM`)の破線の円。
  /// flutter_mapのCircleMarkerは破線にできないため、円周を多角形で描く。
  Polygon<Object> _missionRangePolygon(MissionMapPoint point) {
    const distance = latlong.Distance();
    final center = latlong.LatLng(point.lat, point.lng);
    return Polygon(
      points: [
        for (var deg = 0; deg < 360; deg += 10)
          distance.offset(center, point.radiusM, deg),
      ],
      color: missionRangeFill,
      borderStrokeWidth: 2,
      borderColor: missionAccent,
      pattern: StrokePattern.dashed(segments: const [6, 4]),
    );
  }

  /// アクセスポイントの点とラベル。
  Marker _missionMarker(MissionMapPoint point) {
    return Marker(
      point: latlong.LatLng(point.lat, point.lng),
      width: 110,
      height: 58,
      alignment: const Alignment(0, (58 / 2 - 34 / 2) / (58 / 2)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: missionAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x4D1B1B19), blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.flag, size: 16, color: Colors.white),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: missionDeep,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'アクセスポイント',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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

  /// マーカー本体(アイコン+ラベル)を組み立てる。どの役割から見ても
  /// 実座標に置く(issue #118でマス目への丸めを廃止)。
  ///
  /// アイコン・ラベルの役割表記はissue #42対応(色だけでなく形・表記でも
  /// 鬼/逃走者を見分けられるようにする)。
  ({String id, Marker marker}) _buildLocationVisual(
    UserLocation location,
    UserRole? myRole,
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

    // ごほうび `big_demon_icon` の間は、鬼のピンをアイコンの中心を起点に拡大する。
    // ハズレ `enlarge_self_icon` を引いた逃走者がいれば、鬼の地図でその
    // 人のピンも同じように拡大する。Transformはレイアウトを変えないので、
    // 重なりの判定や座標合わせは元の大きさのまま動く。
    final enlarged =
        (enlargeDemonIcon && !isSelf && targetRole == UserRole.demon) ||
        enlargedUserUids.contains(location.uid);
    final marker = Marker(
      // どの役割から見ても実座標に置く(issue #118でグリッドを廃止)。
      point: latlong.LatLng(location.latitude, location.longitude),
      // ラベル表示のため横幅を拡張(名前が長い場合は省略表示)。
      // 縦はアイコン(白フチ込みで40) + ラベル(~15) で余裕を持たせる。
      width: markerWidth,
      height: markerHeight,
      // 役割アイコン(local_fire_department/directions_run)はlocation_pinと
      // 異なり下端に尖った先端が無い対称な形なので、アイコンの中心を実座標に
      // 合わせる。location_pinへのフォールバック時は、下端の先端を座標に
      // 合わせる。
      alignment: usesRoleIcon
          ? markerIconCenterAlignment
          : markerIconTipAlignment,
      child: Transform.scale(
        scale: enlarged ? enlargedDemonIconScale : 1,
        alignment: enlargedMarkerScaleAlignment,
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
      ),
    );

    return (id: location.uid, marker: marker);
  }

  UserLocation? _findLocation(List<UserLocation> locations, String? uid) {
    if (uid == null) return null;
    for (final location in locations) {
      if (location.uid == uid) return location;
    }
    return null;
  }
}

/// 鬼のピンを拡大するときの起点(アイコンの中心)。
///
/// `Transform.scale`の`alignment`は、子(幅[markerWidth]×高さ[markerHeight])の
/// 中で動かない点を指す。アイコンは上詰めなので、中心は上端から
/// [markerIconSize]/2 にある。ここを起点にしないと、拡大したアイコンが
/// 実際の位置からずれて描かれる。
const enlargedMarkerScaleAlignment = Alignment(
  0,
  (markerIconSize / 2) / markerHeight * 2 - 1,
);

/// GPSマーカーの幅。ラベル(名前)が入る幅。
const markerWidth = 72.0;

/// GPSマーカーの高さ。アイコン+ラベル分。
const markerHeight = 56.0;

/// マーカーのアイコン(白フチ込み)の一辺。[MarkerIcon] のSizedBoxと合わせる。
const markerIconSize = 40.0;

/// アイコンの中心を実座標に合わせるためのalignment。
///
/// flutter_map(v6以降)のMarker.alignmentは「実座標から見てマーカー
/// widget全体をどちら側に置くか」の指定で、widget内のどの点を座標に
/// 合わせるかとは**向きが逆**になる。`Alignment.topCenter` はwidget全体を
/// 座標の上に置き(=widgetの下端中央が座標に来る)、`Alignment(0, y)` なら
/// widget内で上端から `(1 - y) / 2 × 高さ` の点が座標に来る。
///
/// マーカーの子はColumn[アイコン, ラベル]で上詰めに並ぶため、アイコンの
/// 中心はwidget上端から [markerIconSize]/2 の位置にある。これを座標に
/// 合わせるには y = (widget中心 - アイコン中心) / (widget高さ/2) を指定する。
/// 以前は符号が逆で、アイコンが実座標より16論理px北に描かれていた。
const markerIconCenterAlignment = Alignment(
  0,
  (markerHeight / 2 - markerIconSize / 2) / (markerHeight / 2),
);

/// location_pin(下端が尖った先端)の先端を実座標に合わせるためのalignment。
/// 考え方は [markerIconCenterAlignment] と同じで、アイコンの下端
/// (widget上端から [markerIconSize])を座標に合わせる。
const markerIconTipAlignment = Alignment(
  0,
  (markerHeight / 2 - markerIconSize) / (markerHeight / 2),
);

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

/// マーカーが旧位置から新位置へ動くのにかける時間(issue #117)。
///
/// 位置の送信は4秒ごとなので、それより十分短くして、次の更新が来る前に
/// 動き終わるようにする。
const markerMoveDuration = Duration(milliseconds: 1000);

/// [from] から [to] へ、進み具合 [t](0〜1)の位置を返す(直線補間)。
///
/// 数m〜数十mの移動しか扱わないので、大円ではなく緯度経度の直線補間で
/// 十分。[t] は範囲外でも0〜1にクランプする。
latlong.LatLng lerpLatLng(latlong.LatLng from, latlong.LatLng to, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return latlong.LatLng(
    from.latitude + (to.latitude - from.latitude) * clamped,
    from.longitude + (to.longitude - from.longitude) * clamped,
  );
}

/// 位置が変わったマーカーを、瞬間移動させず [markerMoveDuration] かけて
/// 動かす [MarkerLayer](issue #117)。
///
/// 位置は4秒ごとにしか更新されないため、補間しないと走っている人の
/// ピンが1回で10〜20m跳ぶ。補間するのは描画位置だけで、渡される
/// [Marker.point] (実座標)そのものは変えない。重なったピンをずらす
/// ときも同じで、見た目をずらすだけにしている(issue #123)。ずらした
/// ピンには、本当の位置の点とそこへの線を添える。
///
/// 補間の途中経過はこのウィジェットが消えたら一緒に消えてよい一時状態
/// なので、hooksで持つ(AGENTS.mdの規約)。
class AnimatedMarkerLayer extends HookWidget {
  /// [markers] の順序はそのまま描画順になる。`id` は同じ人のマーカーを
  /// 更新前後で対応づけるためのキー(uid)。
  const AnimatedMarkerLayer({super.key, required this.markers});

  /// 描くマーカー。`marker.point` は移動先(最新の位置)。
  final List<({String id, Marker marker})> markers;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: markerMoveDuration,
      initialValue: 1,
    );
    final t = useAnimation(controller);
    final from = useRef(<String, latlong.LatLng>{});
    final to = useRef(<String, latlong.LatLng>{});

    latlong.LatLng displayed(String id, latlong.LatLng target, double t) {
      final start = from.value[id];
      final end = to.value[id];
      if (start == null || end == null) return target;
      return lerpLatLng(start, end, t);
    }

    // 移動先が変わったら、その時点の表示位置から新しい移動先へ動かし直す。
    //
    // flutter_hooksのuseEffectはbuildの中で同期的に走る。ここで移動元・
    // 移動先を書き換えると、このbuildが上で読んだ古い進み具合(t)のまま
    // 新しい移動先で描かれ、最初の1フレームだけマーカーが移動先へ飛んで
    // しまう。controllerの再始動もリスナー経由の再描画要求をbuild中に
    // 出すことになる。そのため、書き換えと再始動はフレームの描画後に行う。
    // それまでのフレームは古い移動先(=今表示している位置)のまま描かれる。
    final targetKeys = [
      for (final entry in markers) ...[entry.id, entry.marker.point],
    ];
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 描画を待つ間にウィジェットが破棄されていたら、破棄済みの
        // controllerに触れない。
        if (!context.mounted) return;
        final progress = controller.value;
        from.value = {
          for (final entry in markers)
            entry.id: displayed(entry.id, entry.marker.point, progress),
        };
        to.value = {
          for (final entry in markers) entry.id: entry.marker.point,
        };
        unawaited(controller.forward(from: 0));
      });
      return null;
    }, targetKeys);

    final points = [
      for (final entry in markers) displayed(entry.id, entry.marker.point, t),
    ];

    // 同じ場所にいる人のピンは重なり、一番上の1人しか見えない
    // (issue #123)。画面上で近すぎるピンは、座標は変えずに見た目だけ
    // 少しずつずらして全員が見えるようにする。画面座標で判定するので、
    // ズームを変えると重なりの判定もやり直される(MapCameraの変化で
    // このウィジェットが再描画されるため)。
    final camera = MapCamera.maybeOf(context);
    final shifts = camera == null
        ? List<Offset>.filled(points.length, Offset.zero)
        : spreadOverlappingMarkers([
            for (final point in points) camera.latLngToScreenOffset(point),
          ]);

    // ずらし幅は画面ピクセルで固定なので、エリア全体を映すくらい引いた
    // 地図では100m前後になり、誰のピンも本当の位置に無い状態になる。
    // ずらしたピンには本当の位置に点を打ち、ピンからそこへ線を引いて、
    // どこにいるのかを読み違えないようにする。地図は回転しない
    // (gameMapInteractionOptions)ので、画面上のずらし量をそのまま足した
    // 点がずらした後のアイコンの中心になる。
    final shiftedIndexes = [
      for (var i = 0; i < markers.length; i++)
        if (shifts[i] != Offset.zero) i,
    ];

    return Stack(
      children: [
        if (camera != null && shiftedIndexes.isNotEmpty) ...[
          PolylineLayer(
            polylines: [
              for (final i in shiftedIndexes)
                Polyline(
                  points: [
                    points[i],
                    camera.screenOffsetToLatLng(
                      camera.latLngToScreenOffset(points[i]) + shifts[i],
                    ),
                  ],
                  strokeWidth: leaderLineWidth,
                  color: leaderLineColor,
                ),
            ],
          ),
          CircleLayer(
            circles: [
              for (final i in shiftedIndexes)
                CircleMarker(
                  point: points[i],
                  radius: trueLocationDotRadius,
                  color: leaderLineColor,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
        ],
        MarkerLayer(
          markers: [
            for (var i = 0; i < markers.length; i++)
              Marker(
                key: markers[i].marker.key,
                point: points[i],
                width: markers[i].marker.width,
                height: markers[i].marker.height,
                alignment: markers[i].marker.alignment,
                rotate: markers[i].marker.rotate,
                child: shifts[i] == Offset.zero
                    ? markers[i].marker.child
                    : Transform.translate(
                        offset: shifts[i],
                        child: markers[i].marker.child,
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// ずらしたピンと本当の位置を結ぶ線、および本当の位置の点の色。
/// 役割の色(赤=鬼・青=自分・緑=逃走者)と紛れないよう無彩色にする。
const Color leaderLineColor = Color(0xCC424242);

/// ずらしたピンと本当の位置を結ぶ線の太さ(論理px)。
const double leaderLineWidth = 1.5;

/// 本当の位置に打つ点の半径(論理px)。
const double trueLocationDotRadius = 4;

/// 画面上でピン同士がこれより近ければ「重なっている」とみなす距離(論理px)。
/// アイコン同士がぶつかり始める距離にしている。
const double markerOverlapDistance = markerIconSize;

/// 重なったピンをずらして並べるときの、隣り合うピン同士の中心の間隔
/// (論理px)。名前のラベルが重ならない幅にしている。
const double markerSpreadSpacing = markerWidth;

/// 画面上で重なっているピンを、見えるように少しずつずらす量を返す
/// (issue #123)。
///
/// [screenPoints] は各ピンの画面座標で、戻り値は同じ順の「ずらす量」。
/// 重なっていないピンは [Offset.zero]。
///
/// 近すぎるピン同士(間接的なつながりも含む)を1つの組にまとめ、組の
/// 重心を中心とする円周上に、隣同士が [spacing] 離れるよう並べ直す。
/// 並び順は [screenPoints] の順(=参加者の並び順)で固定なので、位置が
/// 更新されても誰がどこに出るかは入れ替わらない。2人なら左右に並ぶ。
List<Offset> spreadOverlappingMarkers(
  List<Offset> screenPoints, {
  double overlapDistance = markerOverlapDistance,
  double spacing = markerSpreadSpacing,
}) {
  final count = screenPoints.length;
  // 素朴なunion-find。ピンは参加者の人数ぶん(数人〜十数人)しかない。
  final parent = List<int>.generate(count, (i) => i);
  int find(int i) {
    var root = i;
    while (parent[root] != root) {
      root = parent[root];
    }
    return root;
  }

  for (var i = 0; i < count; i++) {
    for (var j = i + 1; j < count; j++) {
      if ((screenPoints[i] - screenPoints[j]).distance < overlapDistance) {
        parent[find(j)] = find(i);
      }
    }
  }

  // 組ごとに並べ直すと、動かした先で別の組のピンと新たに重なることが
  // ある(例: 画面上の位置が0, 0, 40の3人。前の2人を左右に動かすと40の
  // 人に重なる)。重なったらその組同士をまとめて並べ直し、重なりが無く
  // なるまで繰り返す。組は減る一方なので、最悪でも全員が1つの組になって
  // 終わる。1つの組の中では隣同士が[spacing]離れる(>= overlapDistance)。
  while (true) {
    final shifts = _placeGroupsOnCircles(screenPoints, find, spacing);
    final placed = [
      for (var i = 0; i < count; i++) screenPoints[i] + shifts[i],
    ];
    var merged = false;
    for (var i = 0; i < count; i++) {
      for (var j = i + 1; j < count; j++) {
        if (find(i) != find(j) &&
            (placed[i] - placed[j]).distance < overlapDistance) {
          parent[find(j)] = find(i);
          merged = true;
        }
      }
    }
    if (!merged) return shifts;
  }
}

/// [find]で同じ組と判定されるピンを、組の重心を中心とする円周上に
/// 隣同士が[spacing]離れるよう並べたときの「ずらす量」を返す。
/// 1人だけの組は動かさない。
List<Offset> _placeGroupsOnCircles(
  List<Offset> screenPoints,
  int Function(int) find,
  double spacing,
) {
  final count = screenPoints.length;
  final groups = <int, List<int>>{};
  for (var i = 0; i < count; i++) {
    groups.putIfAbsent(find(i), () => []).add(i);
  }

  final shifts = List<Offset>.filled(count, Offset.zero);
  for (final members in groups.values) {
    final n = members.length;
    if (n < 2) continue;
    var center = Offset.zero;
    for (final i in members) {
      center += screenPoints[i];
    }
    center /= n.toDouble();
    // 円周上で隣り合うピンの弦の長さが spacing になる半径。
    final radius = spacing / (2 * math.sin(math.pi / n));
    for (var k = 0; k < n; k++) {
      // 左(π)から時計回りに並べる。2人なら左右に並ぶ。
      final angle = math.pi + 2 * math.pi * k / n;
      final target = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      shifts[members[k]] = target - screenPoints[members[k]];
    }
  }
  return shifts;
}
