import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/calibration_status.dart';
import 'package:kakureru/features/room/left_user_notifications.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/single_flight_action.dart';
import 'package:kakureru/features/room/view/game_page.dart';
import 'package:kakureru/features/room/view/room_setting_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

class RoomWaitingPage extends HookConsumerWidget {
  final String roomId;
  const RoomWaitingPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final pressureState = ref.watch(pressureViewModelProvider);
    final isStarting = useState(false);
    final startError = useState<Object?>(null);
    final hasNavigated = useState(false);
    final isNominatingRandom = useState(false);
    final randomNominationGuard = useMemoized(SingleFlightAction.new);
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    useEffect(() {
      ref.read(pressureViewModelProvider.notifier).init(roomId);
      return null;
    }, const []);

    // ref.listenではなくuseEffect(roomAsync.value依存)にしているのは、
    // 既にゲームが進行中(room.status == playing)のルームに、コード入力
    // だけで新規参加してこのページに新規マウントされるケースがあるため
    // (joinRoomはroom.statusを見ずに参加を許可する)。最初のスナップショット
    // の時点で既にplayingだと、ref.listenは登録後の「変化」にしか反応しない
    // ので、GamePageへの遷移も鬼指名の自動受諾も発火しなかった(待機画面の
    // まま止まってしまう不具合の原因)。useEffectなら初回到達分の評価も
    // 行われる。
    useEffect(() {
      final room = roomAsync.value;
      if (room == null) return null;

      if (room.status == RoomStatus.playing && !hasNavigated.value) {
        hasNavigated.value = true;
        // useEffectはref.watchによるリビルドと同じフレーム内・ビルド直後に
        // 同期実行されるため、ここで即座にNavigatorを操作すると
        // 「ビルド中にNavigator操作をした」という一瞬のエラー画面が出る
        // (最終的には遷移自体は成功するが、ちらつきが起きる)。
        // addPostFrameCallbackでこのフレームの確定後まで遅延させる。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(
            context,
          ).pushReplacement(
            MaterialPageRoute(builder: (_) => GamePage(roomId: roomId)),
          );
        });
        return null;
      }

      // 自分が鬼に指名されたら、自分でroleを更新して受諾する
      // (docs/rtdb-schema.mdの「鬼の決定」参照。ホストは他人のroleを
      // 直接書けないため、指名された本人が自分で書く方式)。
      final myself = myUid == null ? null : _findUser(room.users, myUid);
      if (room.pendingDemonUid == myUid && myself?.role != UserRole.demon) {
        ref.read(roomRepositoryProvider).acceptDemonNomination(roomId, myUid!);
      }
      return null;
    }, [roomAsync.value]);

    // 誰かが離脱したら「(名前)さんが抜けました」で明示的に知らせる(issue #11)。
    useLeftUserNotifications(ref, context, roomId);

    // 以前はPopScope.onPopInvokedWithResultのdidPopで判定していたが、
    // GamePage側でWithForegroundTaskのWillPopScopeと競合してdidPopの
    // 解釈が信頼できなくなる不具合があったため、ウィジェットが実際に
    // 破棄されるタイミング(dispose)で判定する方式に統一した。ゲーム開始に
    // 伴うGamePageへのpushReplacementでもこのウィジェットは破棄されるが、
    // それは離脱ではないのでhasNavigatedで区別する。
    useEffect(() {
      return () {
        if (!hasNavigated.value) {
          unawaited(ref.read(roomRepositoryProvider).leaveRoom(roomId));
        }
      };
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const Text('待機中')),
      body: roomAsync.when(
        data: (room) {
          final isHost = room.hostUserId == myUid;
          final hostCalibrated = room.basePressure != null;
          final demonCandidates = room.users
              .where((u) => u.role != UserRole.demon)
              .toList();

          final calibrationStatuses = {
            for (final u in room.users)
              u.id: calibrationStatusFor(
                isHost: u.id == room.hostUserId,
                sensorAvailable: u.pressureSensorAvailable,
                basePressure: room.basePressure,
                pressureOffset: u.pressureOffset,
              ),
          };
          final requiredCount = calibrationStatuses.values
              .where((s) => s != CalibrationStatus.unavailable)
              .length;
          final doneCount = calibrationStatuses.values
              .where((s) => s == CalibrationStatus.done)
              .length;
          final allCalibrated = isCalibrationComplete(
            calibrationStatuses.values,
          );
          final pendingNames = room.users
              .where(
                (u) => calibrationStatuses[u.id] == CalibrationStatus.pending,
              )
              .map((u) => u.displayName)
              .toList();
          final myCalibrated =
              myUid != null &&
              calibrationStatuses[myUid] == CalibrationStatus.done;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'ルームコード: ${room.roomCode}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (isHost && room.status == RoomStatus.waiting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('設定'),
                    onPressed: () =>
                        Navigator.of(
                          context,
                        ).push(
                          MaterialPageRoute(
                            builder: (_) => RoomSettingPage(roomId: roomId),
                          ),
                        ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('参加者'),
                    if (requiredCount > 0)
                      Text(
                        'キャリブレーション $doneCount/$requiredCount人 完了',
                        style: TextStyle(
                          color: doneCount == requiredCount
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: room.users.map((u) {
                    final status =
                        calibrationStatuses[u.id] ?? CalibrationStatus.pending;
                    final isPending =
                        room.pendingDemonUid == u.id &&
                        u.role != UserRole.demon;

                    return ListTile(
                      title: Text(u.displayName),
                      subtitle: Text(
                        u.role == UserRole.demon
                            ? '鬼'
                            : isPending
                            ? '逃走者(鬼に指名中...)'
                            : '逃走者',
                        style: TextStyle(
                          color: u.role == UserRole.demon ? Colors.red : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (u.isHost)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Text('ホスト'),
                            ),
                          _CalibrationStatusIcon(status: status),
                          if (isHost && u.role != UserRole.demon)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: room.pendingDemonUid == u.id
                                  ? ActionChip(
                                      label: const Text('取り消す'),
                                      onPressed: () => ref
                                          .read(roomRepositoryProvider)
                                          .cancelDemonNomination(roomId),
                                    )
                                  : ActionChip(
                                      label: const Text('鬼にする'),
                                      onPressed: room.pendingDemonUid != null
                                          ? null
                                          : () => ref
                                                .read(roomRepositoryProvider)
                                                .nominateDemon(roomId, u.id),
                                    ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (isHost)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: OutlinedButton(
                    onPressed:
                        isNominatingRandom.value ||
                            room.pendingDemonUid != null ||
                            demonCandidates.isEmpty
                        ? null
                        : () {
                            // 連打対策: RTDBへの反映(room.pendingDemonUidの更新)には
                            // ネットワーク往復の遅延があり、その間はボタンがまだ有効な
                            // ままなので、SingleFlightActionで同一フレーム内の連打も
                            // 含めて多重発火を防ぐ。
                            unawaited(
                              randomNominationGuard.run(() async {
                                isNominatingRandom.value = true;
                                try {
                                  final target =
                                      demonCandidates[Random().nextInt(
                                        demonCandidates.length,
                                      )];
                                  await ref
                                      .read(roomRepositoryProvider)
                                      .nominateDemon(roomId, target.id);
                                } finally {
                                  isNominatingRandom.value = false;
                                }
                              }),
                            );
                          },
                    child: const Text('鬼をランダムで決める'),
                  ),
                ),
              _CalibrationSection(
                roomId: roomId,
                isHost: isHost,
                hostCalibrated: hostCalibrated,
                myCalibrated: myCalibrated,
                basePressure: room.basePressure,
                pressureState: pressureState,
              ),
              if (isHost && room.setting.gameArea.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'プレイエリアが未設定です。「設定」からエリアを指定してください',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              if (isHost && !allCalibrated && pendingNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'キャリブレーション未完了: ${pendingNames.join('、')}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              if (isHost)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    onPressed:
                        isStarting.value ||
                            room.setting.gameArea.isEmpty ||
                            !allCalibrated
                        ? null
                        : () async {
                            isStarting.value = true;
                            startError.value = null;
                            try {
                              await ref
                                  .read(roomRepositoryProvider)
                                  .startGame(roomId);
                            } on Object catch (e) {
                              startError.value = e;
                            } finally {
                              isStarting.value = false;
                            }
                          },
                    child: const Text('ゲーム開始'),
                  ),
                ),
              if (startError.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '${startError.value}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}

/// 参加者リストの行に出す、キャリブレーション状況アイコン。
/// done(緑のチェック)/pending(グレーの未チェック)/unavailable(非対応)の
/// 3状態を一目で区別できるようにする。
class _CalibrationStatusIcon extends StatelessWidget {
  const _CalibrationStatusIcon({required this.status});

  final CalibrationStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case CalibrationStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case CalibrationStatus.pending:
        return const Icon(Icons.radio_button_unchecked, color: Colors.orange);
      case CalibrationStatus.unavailable:
        return Tooltip(
          message: '気圧センサー非対応',
          child: Icon(Icons.sensors_off, color: Colors.grey.shade400),
        );
    }
  }
}

class _CalibrationSection extends ConsumerWidget {
  const _CalibrationSection({
    required this.roomId,
    required this.isHost,
    required this.hostCalibrated,
    required this.myCalibrated,
    required this.basePressure,
    required this.pressureState,
  });

  final String roomId;
  final bool isHost;
  final bool hostCalibrated;
  final bool myCalibrated;
  final double? basePressure;
  final PressureState pressureState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: _buildMyStatus(ref),
    );
  }

  Widget _buildMyStatus(WidgetRef ref) {
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.unavailable) {
      return const Row(
        children: [
          Icon(Icons.sensors_off, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'この端末は気圧センサーに非対応です(キャリブレーション不要)',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    if (myCalibrated) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'キャリブレーション完了',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    final checking =
        pressureState.sensorAvailability == PressureSensorAvailability.checking;
    final myPressureReady = pressureState.myPressureHPa != null;
    final canCalibrate =
        !checking &&
        myPressureReady &&
        !pressureState.isCalibrating &&
        (isHost || hostCalibrated);

    String? hint;
    if (checking) {
      hint = 'センサーを確認中...';
    } else if (!myPressureReady) {
      hint = '気圧を取得中...';
    } else if (!isHost && !hostCalibrated) {
      hint = 'ホストのキャリブレーション待ち';
    }

    return Column(
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.touch_app),
          onPressed: canCalibrate
              ? () {
                  final notifier = ref.read(pressureViewModelProvider.notifier);
                  if (isHost) {
                    notifier.calibrateAsHost(roomId);
                  } else {
                    notifier.calibrateAsParticipant(roomId, basePressure);
                  }
                }
              : null,
          label: const Text('キャリブレーションする(未実施)'),
        ),
        if (hint != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint)),
      ],
    );
  }
}
