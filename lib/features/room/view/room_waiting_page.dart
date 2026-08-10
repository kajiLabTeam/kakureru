import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game_page.dart';
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
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    useEffect(() {
      ref.read(pressureViewModelProvider.notifier).init();
      return null;
    }, const []);

    ref.listen(roomStreamProvider(roomId), (prev, next) {
      final room = next.value;
      if (room == null) return;

      if (room.status == RoomStatus.playing && !hasNavigated.value) {
        hasNavigated.value = true;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => GamePage(roomId: roomId)));
        return;
      }

      // 自分が鬼に指名されたら、自分でroleを更新して受諾する
      // (docs/rtdb-schema.mdの「鬼の決定」参照。ホストは他人のroleを
      // 直接書けないため、指名された本人が自分で書く方式)。
      final myself = myUid == null ? null : _findUser(room.users, myUid);
      if (room.pendingDemonUid == myUid && myself?.role != UserRole.demon) {
        ref.read(roomRepositoryProvider).acceptDemonNomination(roomId, myUid!);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('待機中')),
      body: roomAsync.when(
        data: (room) {
          final isHost = room.hostUserId == myUid;
          final hostCalibrated = room.basePressure != null;
          final demonCandidates = room.users.where((u) => u.role != UserRole.demon).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'ルームコード: ${room.roomCode}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const Text('参加者'),
              Expanded(
                child: ListView(
                  children: room.users.map((u) {
                    final calibrated = u.id == room.hostUserId
                        ? hostCalibrated
                        : u.pressureOffset != null;
                    final isPending = room.pendingDemonUid == u.id && u.role != UserRole.demon;

                    return ListTile(
                      title: Text(u.displayName),
                      subtitle: Text(
                        u.role == UserRole.demon
                            ? '鬼'
                            : isPending
                            ? '逃走者(鬼に指名中...)'
                            : '逃走者',
                        style: TextStyle(color: u.role == UserRole.demon ? Colors.red : null),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (u.isHost) const Padding(padding: EdgeInsets.only(right: 8), child: Text('ホスト')),
                          Icon(
                            calibrated ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: calibrated ? Colors.green : Colors.grey,
                          ),
                          if (isHost && u.role != UserRole.demon)
                            IconButton(
                              icon: const Icon(Icons.warning_amber),
                              tooltip: '鬼にする',
                              onPressed: room.pendingDemonUid != null
                                  ? null
                                  : () => ref.read(roomRepositoryProvider).nominateDemon(roomId, u.id),
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
                    onPressed: room.pendingDemonUid != null || demonCandidates.isEmpty
                        ? null
                        : () {
                            final target = demonCandidates[Random().nextInt(demonCandidates.length)];
                            ref.read(roomRepositoryProvider).nominateDemon(roomId, target.id);
                          },
                    child: const Text('鬼をランダムで決める'),
                  ),
                ),
              _CalibrationSection(
                roomId: roomId,
                isHost: isHost,
                hostCalibrated: hostCalibrated,
                basePressure: room.basePressure,
                pressureState: pressureState,
              ),
              if (isHost)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    onPressed: isStarting.value
                        ? null
                        : () async {
                            isStarting.value = true;
                            startError.value = null;
                            try {
                              await ref.read(roomRepositoryProvider).startGame(roomId);
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
                  child: Text('${startError.value}', style: const TextStyle(color: Colors.red)),
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

class _CalibrationSection extends ConsumerWidget {
  const _CalibrationSection({
    required this.roomId,
    required this.isHost,
    required this.hostCalibrated,
    required this.basePressure,
    required this.pressureState,
  });

  final String roomId;
  final bool isHost;
  final bool hostCalibrated;
  final double? basePressure;
  final PressureState pressureState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pressureState.sensorAvailability == PressureSensorAvailability.unavailable) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text('この端末は気圧センサー非対応です', style: TextStyle(color: Colors.orange)),
      );
    }

    final checking = pressureState.sensorAvailability == PressureSensorAvailability.checking;
    final myPressureReady = pressureState.myPressureHPa != null;
    final canCalibrate = !checking && myPressureReady && !pressureState.isCalibrating && (isHost || hostCalibrated);

    String? hint;
    if (checking) {
      hint = 'センサーを確認中...';
    } else if (!myPressureReady) {
      hint = '気圧を取得中...';
    } else if (!isHost && !hostCalibrated) {
      hint = 'ホストのキャリブレーション待ち';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          OutlinedButton(
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
            child: const Text('キャリブレーション'),
          ),
          if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint)),
        ],
      ),
    );
  }
}
