import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/room/async_action.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/game_map_options.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_tone_theme.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view/room_stream_error.dart';
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

  /// 鬼ごっこの時間(鬼放出後)の上限(分)。同様に仮の上限。
  static const _gameDurationMaxMinutes = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final room = roomAsync.value;
    final myUid = ref.watch(myUidProvider);

    final releaseWaitMin = useState(1);
    final gameDurationMin = useState(5);
    final gameArea = useState<List<LatLng>>(const []);
    final gpsOnly = useState(false);
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
        gpsOnly.value = room.setting.gpsOnly;
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
    // 直近のドラッグがエリアとして小さすぎ/大きすぎて弾かれた理由。
    // 弾かれた場合gameAreaは更新しない(直前の有効なエリアを保つ)。
    final areaSizeError = useState<String?>(null);
    final save = useAsyncAction(context);

    // ゲーム画面と同じトーン(生成りの地・白いカード・丸い黒ボタン)で包む。
    return Theme(
      data: buildGameToneTheme(Theme.of(context)),
      child: Scaffold(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GameToneCard(
                    title: '時間',
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Column(
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
                          // 放出後から数える(issue #119)。放出待ちの時間は含まない。
                          label: '鬼ごっこの時間(放出後)',
                          minutes: gameDurationMin.value,
                          step: 5,
                          min: 1,
                          max: _gameDurationMaxMinutes,
                          onChanged: (v) => gameDurationMin.value = v,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GameToneCard(
                    title: 'モード',
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('GPSのみモード', style: TextStyle(fontSize: 14)),
                              Text(
                                'Wi-Fiと気圧を使わず、GPSとBLEだけで遊ぶ(A/Bテスト用)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: gameMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: gpsOnly.value,
                          onChanged: (v) => gpsOnly.value = v,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GameToneCard(
                    title: 'プレイエリア(ドラッグで矩形を指定)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 320,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _AreaMap(
                              initialCenter:
                                  initialCenter.value ?? fallbackMapCenter,
                              myLocation: myLocation.value,
                              gameArea: gameArea.value,
                              isDrawing: isDrawing.value,
                              dragStart: dragStart.value,
                              dragCurrent: dragCurrent.value,
                              hasSizeError: areaSizeError.value != null,
                              onDragStart: (point) {
                                // 新しいドラッグを始めたら前回のエラー状態はクリアする。
                                areaSizeError.value = null;
                                dragStart.value = point;
                                dragCurrent.value = point;
                              },
                              onDragUpdate: (point) =>
                                  dragCurrent.value = point,
                              onDragEnd: () {
                                final start = dragStart.value;
                                final current = dragCurrent.value;
                                if (start == null || current == null) return;

                                // 矩形の対角線の長さでサイズを検証する。数px程度の
                                // タップに近いドラッグ(退化した矩形)や、地図を
                                // 世界スケールまで引いてから引いた極端に大きい矩形を
                                // 弾く(理由はgame_map_options.dartのコメント参照)。
                                final diagonalMeters =
                                    Geolocator.distanceBetween(
                                      start.latitude,
                                      start.longitude,
                                      current.latitude,
                                      current.longitude,
                                    );
                                final error = describeGameAreaSizeError(
                                  diagonalMeters,
                                );
                                areaSizeError.value = error;
                                if (error == null) {
                                  gameArea.value = calculateRectangleCorners(
                                    LatLng(
                                      lat: start.latitude,
                                      lng: start.longitude,
                                    ),
                                    LatLng(
                                      lat: current.latitude,
                                      lng: current.longitude,
                                    ),
                                  );
                                  dragStart.value = null;
                                  dragCurrent.value = null;
                                }
                                // エラー時はリセットせず、仮矩形を赤枠のまま残して
                                // エラーメッセージと視覚的に結びつける
                                // (次のドラッグ開始 or 有効なドラッグで上書きされる)。
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (myLocation.value == null)
                          const _Notice(
                            '現在地を取得中です(位置情報がOFFだとピンは出ません)',
                            color: gameMuted,
                          ),
                        if (gameArea.value.isEmpty)
                          const _Notice(
                            '未設定です。ドラッグして範囲を指定してください',
                            color: gameNoticeAccent,
                          ),
                        if (areaSizeError.value != null)
                          _Notice(areaSizeError.value!, color: gameNewBadge),
                        OutlinedButton.icon(
                          onPressed: () {
                            isDrawing.value = !isDrawing.value;
                            // モード切り替え時に仮矩形とエラー表示も持ち越さない
                            // (描画をやめたのに赤枠だけ残るのを防ぐ)。
                            dragStart.value = null;
                            dragCurrent.value = null;
                            areaSizeError.value = null;
                          },
                          icon: Icon(
                            isDrawing.value
                                ? Icons.pan_tool_outlined
                                : Icons.edit,
                            size: 18,
                          ),
                          label: Text(
                            isDrawing.value ? '描画をやめる(地図の移動に戻す)' : 'エリアを描く',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: !save.isRunning
                        ? () => save.run(() async {
                            await ref
                                .read(roomRepositoryProvider)
                                .updateSetting(
                                  roomId,
                                  room.setting.copyWith(
                                    releaseWaitSec: releaseWaitMin.value * 60,
                                    gameDurationSec: gameDurationMin.value * 60,
                                    gameArea: gameArea.value,
                                    gpsOnly: gpsOnly.value,
                                  ),
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          })
                        : null,
                    child: save.isRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('保存'),
                  ),
                  if (save.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        userFacingErrorMessage(save.error!),
                        style: const TextStyle(
                          color: gameNewBadge,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => RoomStreamErrorView(roomId: roomId, error: e),
        ),
      ),
    );
  }
}

/// エリアの状態(取得中・未設定・サイズ超過)を知らせる一行。
class _Notice extends StatelessWidget {
  const _Notice(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: minutes - step >= min
                ? () => onChanged(minutes - step)
                : null,
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$minutes分',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: gameInk,
              ),
            ),
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
    required this.hasSizeError,
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

  /// 直近のドラッグ結果(dragStart/dragCurrent)がサイズ超過等で
  /// 弾かれているかどうか。trueの間は仮矩形を赤枠で表示し、
  /// 無効なままであることを視覚的に伝える。
  final bool hasSizeError;
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
          buildMapTileLayer(context),
          PolygonLayer(
            polygons: [
              if (gameArea.length >= 3)
                Polygon(
                  points: toLatLngPoints(gameArea),
                  color: selfColor.withValues(alpha: 0.15),
                  borderStrokeWidth: 2,
                  borderColor: selfColor,
                  pattern: StrokePattern.dashed(segments: const [8, 4]),
                ),
              if (dragStart != null && dragCurrent != null)
                Polygon(
                  points: toLatLngPoints(
                    calculateRectangleCorners(
                      LatLng(
                        lat: dragStart!.latitude,
                        lng: dragStart!.longitude,
                      ),
                      LatLng(
                        lat: dragCurrent!.latitude,
                        lng: dragCurrent!.longitude,
                      ),
                    ),
                  ),
                  color: (hasSizeError ? gameNewBadge : gameNoticeAccent)
                      .withValues(alpha: 0.2),
                  borderStrokeWidth: 2,
                  borderColor: hasSizeError ? gameNewBadge : gameNoticeAccent,
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
                  // Icons.location_pinの先端(下端)を座標に合わせる。
                  // 既定のcenter合わせだと約18px下にずれる。
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_pin,
                    color: selfColor,
                    size: 36,
                  ),
                ),
              ],
            ),
          buildMapAttribution(),
        ],
      ),
    );
  }
}
