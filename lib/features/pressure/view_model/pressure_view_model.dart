import 'package:firebase_auth/firebase_auth.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:kakureru/features/pressure/repository/pressure_repository.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

part 'pressure_view_model.freezed.dart';

final pressureRepositoryProvider = Provider((ref) => PressureRepository());

@freezed
abstract class PressureState with _$PressureState {
  const factory PressureState({
    @Default(PressureSensorAvailability.checking) PressureSensorAvailability sensorAvailability,
    double? myPressureHPa,
    @Default(false) bool isCalibrating,
  }) = _PressureState;
}

class PressureViewModel extends Notifier<PressureState> {
  @override
  PressureState build() => const PressureState();

  PressureRepository get _repo => ref.read(pressureRepositoryProvider);

  /// 待機画面に入った時に呼ぶ。センサーの有無を確認し、使えるなら
  /// 気圧の購読を始める(何度呼んでも安全)。
  Future<void> init() async {
    if (state.sensorAvailability == PressureSensorAvailability.available) return;

    final available = await _repo.checkSensorAvailable();
    if (!available) {
      state = state.copyWith(sensorAvailability: PressureSensorAvailability.unavailable);
      return;
    }

    state = state.copyWith(sensorAvailability: PressureSensorAvailability.available);
    _repo.watchMyPressure().listen((value) {
      state = state.copyWith(myPressureHPa: value);
    });
  }

  /// ホストが自分の気圧を基準値として書き込む。
  Future<void> calibrateAsHost(String roomId) async {
    final myPressure = state.myPressureHPa;
    if (myPressure == null) return;

    state = state.copyWith(isCalibrating: true);
    try {
      await _repo.calibrateAsHost(roomId, myPressure);
    } finally {
      state = state.copyWith(isCalibrating: false);
    }
  }

  /// 参加者が「自分の気圧 - 基準値」をoffsetとして書き込む。
  /// basePressureHPa はホストがキャリブレーション済みでないとnull。
  Future<void> calibrateAsParticipant(String roomId, double? basePressureHPa) async {
    final myPressure = state.myPressureHPa;
    if (myPressure == null || basePressureHPa == null) return;

    state = state.copyWith(isCalibrating: true);
    try {
      await _repo.calibrateAsParticipant(roomId, myPressure, basePressureHPa);
    } finally {
      state = state.copyWith(isCalibrating: false);
    }
  }

  /// ゲーム画面に入った時に呼ぶ。RTDBへの定期送信を開始する。
  ///
  /// [init] の完了(センサー有無の判定)を待たずに呼んでも安全:
  /// リポジトリ側の定期送信は、まだ値が無ければ単にその回の送信を
  /// スキップするだけなので、判定が後から終わっても自然に送信が始まる。
  void startSendingToRoom(String roomId) {
    _repo.startSendingToRoom(roomId);
  }

  /// ゲーム画面を離れる時に呼ぶ。送信とセンサー購読を止める。
  void stopSendingAndDispose() {
    _repo.disposeSensor();
  }
}

final pressureViewModelProvider = NotifierProvider<PressureViewModel, PressureState>(
  PressureViewModel.new,
);

/// 自分から見た、他の参加者それぞれの相対的な高さ。
///
/// room(基準気圧・offset)とlocations(各人の生の気圧)の両方に依存する
/// 純粋な計算結果なので、PressureViewModelの状態としてではなく
/// 導出Providerとして持たせている(どちらかが変わるたびに自動で再計算される)。
final relativeVerticalPositionsProvider = Provider.family<List<RelativeVerticalPosition>, String>(
  (ref, roomId) {
    final room = ref.watch(roomStreamProvider(roomId)).value;
    final myPressure = ref.watch(pressureViewModelProvider).myPressureHPa;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (room == null || myPressure == null || myUid == null) return const [];

    final myOffset = _offsetFor(room, myUid);
    final locations = ref.watch(locationViewModelProvider).locations;

    final positions = <RelativeVerticalPosition>[];
    for (final location in locations) {
      if (location.uid == myUid) continue;
      final targetPressure = location.pressure;
      // 相手がまだ気圧を送信していない(センサー非搭載機種等)場合はスキップ。
      if (targetPressure == null) continue;

      final targetOffset = _offsetFor(room, location.uid);
      final delta = calculateRelativeHeightMeters(
        selfPressureHPa: myPressure,
        selfOffsetHPa: myOffset,
        targetPressureHPa: targetPressure,
        targetOffsetHPa: targetOffset,
      );
      positions.add(RelativeVerticalPosition(uid: location.uid, deltaMeters: delta));
    }
    return positions;
  },
);

/// ホストのoffsetは0固定(基準そのものなので)。参加者はusers/{uid}/pressureOffset。
double _offsetFor(Room room, String uid) {
  if (uid == room.hostUserId) return 0;
  final user = _findUser(room.users, uid);
  return user?.pressureOffset ?? 0;
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}
