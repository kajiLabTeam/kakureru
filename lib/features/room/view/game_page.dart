import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
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
                Expanded(
                  child: _LocationMap(
                    locations: locationState.locations,
                    users: room.users,
                    myUid: myUid,
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

class _LocationMap extends StatelessWidget {
  const _LocationMap({required this.locations, required this.users, required this.myUid});

  final List<UserLocation> locations;
  final List<RoomUser> users;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    final selfLocation = _findLocation(locations, myUid);
    if (selfLocation == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), SizedBox(height: 16), Text('位置情報を取得中...')],
        ),
      );
    }

    final center = latlong.LatLng(selfLocation.latitude, selfLocation.longitude);

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 17),
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
    );
  }

  Marker _buildMarker(UserLocation location) {
    final isSelf = location.uid == myUid;
    final color = isSelf ? Colors.blue : _roleColor(_findUser(users, location.uid)?.role);

    return Marker(
      point: latlong.LatLng(location.latitude, location.longitude),
      width: 40,
      height: 40,
      child: Icon(Icons.location_pin, color: color, size: 36),
    );
  }

  // 役割による表示制御(誰に誰が見えるか)は別タスクで扱う。ここでは
  // 取得できた位置を単純に色分けして表示するだけ。
  Color _roleColor(UserRole? role) {
    return role == UserRole.demon ? Colors.red : Colors.green;
  }

  UserLocation? _findLocation(List<UserLocation> locations, String? uid) {
    if (uid == null) return null;
    for (final location in locations) {
      if (location.uid == uid) return location;
    }
    return null;
  }

  RoomUser? _findUser(List<RoomUser> users, String uid) {
    for (final user in users) {
      if (user.id == uid) return user;
    }
    return null;
  }
}
