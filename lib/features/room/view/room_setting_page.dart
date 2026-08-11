import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// 参加者が集まった後、ゲーム開始前にホストが設定する画面。
/// 待機画面(WAITING)からホストのみ遷移できる(RoomWaitingPageでガード)。
class RoomSettingPage extends HookConsumerWidget {
  const RoomSettingPage({super.key, required this.roomId});

  final String roomId;

  /// 鬼放出までの待機時間の上限(分)。長すぎても間延びするだけなので
  /// 適当に30分を仮の上限にしている(判断を委ねられた項目)。
  static const _releaseWaitMaxMinutes = 30;

  /// 全体時間の上限(分)。同様に仮の上限。
  static const _gameDurationMaxMinutes = 180;

  /// 現在地が取れない間の暫定センター(東京駅)。GamePage参照。
  static const _fallbackCenter = latlong.LatLng(35.681236, 139.767125);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final room = roomAsync.value;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    final releaseWaitMin = useState(1);
    final gameDurationMin = useState(5);
    final gameArea = useState<List<LatLng>>(const []);
    final hasInitialized = useRef(false);

    // room.settingの初期値をフォームへ1回だけ読み込む。以降はライブ更新で
    // 上書きしない(編集中の値を尊重する)。
    useEffect(() {
      if (room != null && !hasInitialized.value) {
        hasInitialized.value = true;
        releaseWaitMin.value = (room.setting.releaseWaitSec / 60).round().clamp(
          1,
          _releaseWaitMaxMinutes,
        );
        gameDurationMin.value = (room.setting.gameDurationSec / 60)
            .round()
            .clamp(
              1,
              _gameDurationMaxMinutes,
            );
        gameArea.value = room.setting.gameArea;
      }
      return null;
    }, [room]);

    // 自分の現在地。エリアを描くときの目印として地図にピンで出す。
    // この画面を閉じたら不要になる状態なのでhooksで持つ(Riverpodへは載せない)。
    final myLocation = useState<latlong.LatLng?>(null);
    // 地図を現在地へ寄せるのは最初の1回だけ。以降myLocationが更新されても
    // 動かさない(ホストが地図をずらして操作している最中に引き戻さないため)。
    final initialCenter = useState<latlong.LatLng?>(null);
    useEffect(() {
      var cancelled = false;
      StreamSubscription<Position>? subscription;

      void update(Position position) {
        if (cancelled) return;
        final point = latlong.LatLng(position.latitude, position.longitude);
        myLocation.value = point;
        initialCenter.value ??= point;
      }

      Future<void> watchMyLocation() async {
        try {
          // 最後に取れていた位置をまず出す(GPSの初回測位は数秒かかるため)。
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) update(last);
        } on Object {
          // 取得できなくてもフォールバック座標を使うだけなので致命的ではない。
        }
        if (cancelled) return;
        subscription =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            ).listen(
              update,
              // 権限が無い・位置情報がOFFの場合はここに来る。ピンが出ないだけで
              // 設定自体は続けられるので、画面は止めずに黙って諦める。
              onError: (Object _) {},
            );
      }

      unawaited(watchMyLocation());
      return () {
        cancelled = true;
        unawaited(subscription?.cancel());
      };
    }, const []);

    final isDrawing = useState(false);
    final dragStart = useState<latlong.LatLng?>(null);
    final dragCurrent = useState<latlong.LatLng?>(null);
    final isSaving = useState(false);
    final saveError = useState<Object?>(null);

    final isValid = gameDurationMin.value * 60 > releaseWaitMin.value * 60;

    return Scaffold(
      appBar: AppBar(title: const Text('ルーム設定')),
      body: roomAsync.when(
        data: (room) {
          if (room.hostUserId != myUid || room.status != RoomStatus.waiting) {
            // ホスト以外・WAITING以外は開けない画面。ここに来ること自体
            // 想定外だが、来てしまったら閉じるだけにする。
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MinuteStepper(
                  label: '鬼放出までの待機時間',
                  minutes: releaseWaitMin.value,
                  step: 1,
                  min: 1,
                  max: _releaseWaitMaxMinutes,
                  onChanged: (v) => releaseWaitMin.value = v,
                ),
                _MinuteStepper(
                  label: '全体時間',
                  minutes: gameDurationMin.value,
                  step: 5,
                  min: 1,
                  max: _gameDurationMaxMinutes,
                  onChanged: (v) => gameDurationMin.value = v,
                ),
                if (!isValid)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '全体時間は鬼放出までの待機時間より長くしてください',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('プレイエリア(ドラッグで矩形を指定)'),
                ),
                SizedBox(
                  height: 320,
                  child: _AreaMap(
                    initialCenter: initialCenter.value ?? _fallbackCenter,
                    myLocation: myLocation.value,
                    gameArea: gameArea.value,
                    isDrawing: isDrawing.value,
                    dragStart: dragStart.value,
                    dragCurrent: dragCurrent.value,
                    onDragStart: (point) {
                      dragStart.value = point;
                      dragCurrent.value = point;
                    },
                    onDragUpdate: (point) => dragCurrent.value = point,
                    onDragEnd: () {
                      if (dragStart.value != null &&
                          dragCurrent.value != null) {
                        gameArea.value = calculateRectangleCorners(
                          LatLng(
                            lat: dragStart.value!.latitude,
                            lng: dragStart.value!.longitude,
                          ),
                          LatLng(
                            lat: dragCurrent.value!.latitude,
                            lng: dragCurrent.value!.longitude,
                          ),
                        );
                      }
                      dragStart.value = null;
                      dragCurrent.value = null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (myLocation.value == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '現在地を取得中です(位置情報がOFFだとピンは出ません)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      if (gameArea.value.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '未設定です。ドラッグして範囲を指定してください',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      OutlinedButton(
                        onPressed: () => isDrawing.value = !isDrawing.value,
                        child: Text(
                          isDrawing.value ? '描画をやめる(地図の移動に戻す)' : 'エリアを描く',
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: isValid && !isSaving.value
                        ? () async {
                            isSaving.value = true;
                            saveError.value = null;
                            try {
                              await ref
                                  .read(roomRepositoryProvider)
                                  .updateSetting(
                                    roomId,
                                    room.setting.copyWith(
                                      releaseWaitSec: releaseWaitMin.value * 60,
                                      gameDurationSec:
                                          gameDurationMin.value * 60,
                                      gameArea: gameArea.value,
                                    ),
                                  );
                              if (context.mounted) Navigator.of(context).pop();
                            } on Object catch (e) {
                              saveError.value = e;
                            } finally {
                              isSaving.value = false;
                            }
                          }
                        : null,
                    child: isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ),
                if (saveError.value != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${saveError.value}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

class _MinuteStepper extends StatelessWidget {
  const _MinuteStepper({
    required this.label,
    required this.minutes,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int minutes;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: minutes - step >= min
                ? () => onChanged(minutes - step)
                : null,
          ),
          SizedBox(
            width: 56,
            child: Text('$minutes分', textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: minutes + step <= max
                ? () => onChanged(minutes + step)
                : null,
          ),
        ],
      ),
    );
  }
}

/// プレイエリアを指定する地図。isDrawing中は地図のパン/ズームを止めて
/// ドラッグをエリア指定のジェスチャーとして扱う(両方を同時に有効にすると
/// ジェスチャーが競合するため、モード切り替えにしている)。
class _AreaMap extends HookWidget {
  const _AreaMap({
    required this.initialCenter,
    required this.myLocation,
    required this.gameArea,
    required this.isDrawing,
    required this.dragStart,
    required this.dragCurrent,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final latlong.LatLng initialCenter;

  /// 自分の現在地。まだ取得できていなければnull(ピンを出さない)。
  final latlong.LatLng? myLocation;
  final List<LatLng> gameArea;
  final bool isDrawing;
  final latlong.LatLng? dragStart;
  final latlong.LatLng? dragCurrent;
  final ValueChanged<latlong.LatLng> onDragStart;
  final ValueChanged<latlong.LatLng> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final mapController = useMemoized(MapController.new);

    // initialCenterはgetLastKnownPositionの解決を待たずフォールバック座標で
    // 最初の1フレームが描画されることがある。GPS解決後に1度だけ実際の位置へ
    // 動かす(MapOptions.initialCenterは最初の1回しか効かないため)。
    final lastCenter = useRef(initialCenter);
    useEffect(() {
      if (initialCenter != lastCenter.value) {
        lastCenter.value = initialCenter;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            mapController.move(initialCenter, mapController.camera.zoom);
          } on Object {
            // 画面遷移直後などでmapがまだ存在しない場合は無視する。
          }
        });
      }
      return null;
    }, [initialCenter]);

    return GestureDetector(
      onPanStart: isDrawing
          ? (details) => onDragStart(
              mapController.camera.screenOffsetToLatLng(details.localPosition),
            )
          : null,
      onPanUpdate: isDrawing
          ? (details) => onDragUpdate(
              mapController.camera.screenOffsetToLatLng(details.localPosition),
            )
          : null,
      onPanEnd: isDrawing ? (_) => onDragEnd() : null,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 16,
          interactionOptions: InteractionOptions(
            flags: isDrawing ? InteractiveFlag.none : InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'me.nenex.kakureru',
          ),
          PolygonLayer(
            polygons: [
              if (gameArea.length >= 3)
                Polygon(
                  points: gameArea
                      .map((p) => latlong.LatLng(p.lat, p.lng))
                      .toList(),
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderStrokeWidth: 2,
                  borderColor: Colors.blue,
                  pattern: StrokePattern.dashed(segments: const [8, 4]),
                ),
              if (dragStart != null && dragCurrent != null)
                Polygon(
                  points: calculateRectangleCorners(
                    LatLng(lat: dragStart!.latitude, lng: dragStart!.longitude),
                    LatLng(
                      lat: dragCurrent!.latitude,
                      lng: dragCurrent!.longitude,
                    ),
                  ).map((p) => latlong.LatLng(p.lat, p.lng)).toList(),
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderStrokeWidth: 2,
                  borderColor: Colors.orange,
                  pattern: StrokePattern.dashed(segments: const [8, 4]),
                ),
            ],
          ),
          // 自分の現在地。GamePageの自分マーカーと同じ青いピンで揃えている。
          if (myLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: myLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.blue,
                    size: 36,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
