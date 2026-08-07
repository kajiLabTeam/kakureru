import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// ゲーム中の画面。ゲーム内容自体はまだ無く、残り時間と参加者の位置表示のみ行う仮実装。
class GamePage extends HookConsumerWidget {
  const GamePage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final offset = ref.watch(serverTimeOffsetProvider).value ?? 0;
    final locationState = ref.watch(locationViewModelProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    // 残り時間を1秒ごとに再計算するためのティッカー。
    // .info/serverTimeOffset 自体はズレが変化した時にしか流れてこないため、
    // 表示を毎秒更新するにはこのタイマーで再描画をトリガーする必要がある。
    final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        tick.value++;
      });
      return timer.cancel;
    }, const []);

    // ゲーム画面に入ったら位置送信・購読を開始し、離れたら止める。
    useEffect(() {
      ref.read(locationViewModelProvider.notifier).start(roomId);
      return () => ref.read(locationViewModelProvider.notifier).stop();
    }, [roomId]);

    // GPSの実測(getPositionStream)は初回の測位に時間がかかる(コールドスタート)。
    // 端末にキャッシュされた直近の位置を getLastKnownPosition で先に取り、
    // 地図の初期表示だけに使う。RTDBへは送らない(古い位置を他の参加者に
    // 見せないため。書き込みは LocationRepository 経由の実測のみで行う)。
    final cachedPosition = useState<Position?>(null);
    useEffect(() {
      Future<void> loadCached() async {
        try {
          cachedPosition.value = await Geolocator.getLastKnownPosition();
        } on Object {
          // 取得できなくても致命的ではない(フォールバック座標を使う)。
        }
      }

      loadCached();
      return null;
    }, const []);

    // 気圧の送信もゲーム画面滞在中だけ行う。センサー購読自体は待機画面の
    // キャリブレーションで既に始まっている想定(PressureViewModel.initは
    // 何度呼んでも安全)。
    useEffect(() {
      ref.read(pressureViewModelProvider.notifier)
        ..init()
        ..startSendingToRoom(roomId);
      return () => ref.read(pressureViewModelProvider.notifier).stopSendingAndDispose();
    }, [roomId]);

    final pressureState = ref.watch(pressureViewModelProvider);
    final relativePositions = ref.watch(relativeVerticalPositionsProvider(roomId));

    // 送信中(Foreground Service稼働中)にソフトバックキーで誤ってアプリごと
    // 閉じてしまうと位置送信が止まるため、最小化に倒す(プラグイン推奨パターン)。
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(title: const Text('ゲーム中')),
        body: roomAsync.when(
          data: (room) {
            final endsAt = room.endsAt;
            final remainingSec = endsAt == null
                ? null
                : ((endsAt - serverNowMillis(offset)) / 1000).ceil();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    remainingSec == null
                        ? '残り時間: 計算中...'
                        : '残り時間: ${remainingSec < 0 ? 0 : remainingSec}秒',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (locationState.permissionDenied)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '位置情報の権限(常に許可)がないため、自分の位置を送信できません',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                if (pressureState.sensorAvailability == PressureSensorAvailability.unavailable)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'この端末は気圧センサー非対応のため、上下判定は行えません',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _LocationMap(
                          locations: locationState.locations,
                          users: room.users,
                          myUid: myUid,
                          cachedPosition: cachedPosition.value,
                        ),
                      ),
                      _VerticalPositionBar(positions: relativePositions, users: room.users),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('エラー: $e')),
        ),
      ),
    );
  }
}

class _LocationMap extends HookWidget {
  const _LocationMap({
    required this.locations,
    required this.users,
    required this.myUid,
    required this.cachedPosition,
  });

  final List<UserLocation> locations;
  final List<RoomUser> users;
  final String? myUid;
  final Position? cachedPosition;

  /// 自分の位置が全く分からない間の暫定センター(東京駅)。
  /// あくまで「世界地図の原点が出るよりまし」という仮の値。
  static const _fallbackDefaultCenter = latlong.LatLng(35.681236, 139.767125);

  @override
  Widget build(BuildContext context) {
    final selfLocation = _findLocation(locations, myUid);

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

    useEffect(() {
      if (positionTier > bestTierShown.value) {
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

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: currentCenter, initialZoom: 17),
          children: [
            // Phase 1では手軽さを優先し、追加設定・課金設定が不要な
            // OpenStreetMapのタイルをそのまま使う(flutter_map採用)。
            // Google Mapsだと google_maps_flutter 用のAPIキー発行と
            // 課金設定が要るため、開発初期の身内テスト用途には過剰。
            // 公開規模が大きくなったら自前タイルサーバや商用プロバイダへの
            // 切り替えを検討すること(OSMのタイル使用ポリシー上、
            // 本番の常用には推奨されない)。
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'me.nenex.kakureru',
            ),
            MarkerLayer(markers: locations.map(_buildMarker).toList()),
          ],
        ),
        if (positionTier == 0)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  /// 自分の位置(実測・キャッシュとも)がまだ無い間の初期センター。
  /// ルーム内の他の参加者が既にいればその位置、いなければ固定の暫定座標。
  latlong.LatLng _initialFallbackCenter() {
    if (locations.isNotEmpty) {
      final other = locations.first;
      return latlong.LatLng(other.latitude, other.longitude);
    }
    return _fallbackDefaultCenter;
  }

  Marker _buildMarker(UserLocation location) {
    final isSelf = location.uid == myUid;
    final color = isSelf ? Colors.blue : _colorForRole(_findUser(users, location.uid)?.role);

    return Marker(
      point: latlong.LatLng(location.latitude, location.longitude),
      width: 40,
      height: 40,
      child: Icon(Icons.location_pin, color: color, size: 36),
    );
  }

  UserLocation? _findLocation(List<UserLocation> locations, String? uid) {
    if (uid == null) return null;
    for (final location in locations) {
      if (location.uid == uid) return location;
    }
    return null;
  }
}

// 役割による表示制御(誰に誰が見えるか)は別タスクで扱う。ここでは
// 取得できた位置を単純に色分けして表示するだけ。地図・上下バー共通で使う。
Color _colorForRole(UserRole? role) {
  return role == UserRole.demon ? Colors.red : Colors.green;
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}

/// 自分を中心線とした上下バー。
///
/// 「精密な階数判定ではなく、上か下かを曖昧に伝える」という方針のため、
/// 複数人を1本の共有バーに●として重ねて表示する形にした
/// (人数分バーを並べる案もあったが、数値を出さない曖昧な表現という
/// 目的には、視線を1箇所に集められるこちらの方が合うと判断した)。
/// 誰の●かは地図と同じ色分け(鬼=赤、逃走者=緑)で見分ける。
class _VerticalPositionBar extends StatelessWidget {
  const _VerticalPositionBar({required this.positions, required this.users});

  final List<RelativeVerticalPosition> positions;
  final List<RoomUser> users;

  static const _rangeMeters = 5.0;
  static const _dotSize = 16.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 2, height: height, color: Colors.grey.shade400),
              // 中心線 = 自分の高さ。
              Container(width: 24, height: 2, color: Colors.black54),
              for (final position in positions) _buildDot(position, height),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDot(RelativeVerticalPosition position, double height) {
    final clamped = position.deltaMeters.clamp(-_rangeMeters, _rangeMeters);
    // t: 0(下端)〜1(上端)。deltaMetersが正(相手が上)ほどtが大きくなる。
    final t = (clamped + _rangeMeters) / (2 * _rangeMeters);
    final top = (height * (1 - t) - _dotSize / 2).clamp(0.0, height - _dotSize);

    return Positioned(
      top: top,
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: _colorForRole(_findUser(users, position.uid)?.role),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}
