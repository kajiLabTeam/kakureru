import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/pressure/model/calibration_failure.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:kakureru/features/pressure/repository/pressure_repository.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

part 'pressure_view_model.freezed.dart';

final pressureRepositoryProvider = Provider((ref) => PressureRepository());

@freezed
abstract class PressureState with _$PressureState {
  const factory PressureState({
    @Default(PressureSensorAvailability.checking)
    PressureSensorAvailability sensorAvailability,
    double? myPressureHPa,
    @Default(false) bool isCalibrating,
    @Default(CalibrationFailure.none) CalibrationFailure calibrationFailure,
  }) = _PressureState;
}

class PressureViewModel extends Notifier<PressureState> {
  @override
  PressureState build() => const PressureState();

  PressureRepository get _repo => ref.read(pressureRepositoryProvider);

  /// センサーの有無の判定が終わるまでの、実行中の[init]。
  ///
  /// 待機画面とゲーム画面が一瞬同時にマウントされる遷移中など、判定が
  /// 終わる前に[init]が二重に呼ばれることがある。状態はまだchecking
  /// なので下のガードをすり抜けてしまうため、実行中のものに相乗りさせる。
  Future<void>? _initInFlight;

  /// [stopSendingAndDispose]のたびに進む世代番号。センサーの有無の判定
  /// (最大3秒)を待っている最中にゲーム画面を離れると、待ちが明けたときには
  /// もう`disposeSensor()`が済んでいる。そこで購読を始めてしまうと、
  /// **誰も止めないセンサー購読**が残る(issue #93と同じ「画面を離れたのに
  /// 止まらない」)。LocationViewModel・BleViewModelと同じやり方で、
  /// 自分を始めた世代のままかどうかを見る。
  int _epoch = 0;

  /// 待機画面・ゲーム画面に入った時に呼ぶ。センサーの有無を確認し、使える
  /// なら気圧の購読を始める(何度呼んでも安全)。判定結果は他の参加者にも
  /// 伝わるようroomIdのRTDBへ記録する(待機画面の一覧・集計表示用)。
  ///
  /// センサーの有無は端末固有で変わらないため、一度判定できたら再判定は
  /// しない。以前は「available のときだけ早期return」だったので、センサー
  /// 非搭載端末では待機→ゲームの遷移のたびに [checkSensorAvailable] の
  /// タイムアウト(最大3秒)を待ち直していた(issue #30)。
  Future<void> init(String roomId) async {
    if (state.sensorAvailability != PressureSensorAvailability.checking) {
      // 判定は済んでいる。ただしRTDBへの記録はルームごとに要るため、
      // 判定済みの結果をそのまま書き直しておく(別のルームに入り直した
      // 場合でも、そのルームのusers/{uid}に載るように)。
      unawaited(
        _repo.reportSensorAvailability(
          roomId,
          available:
              state.sensorAvailability == PressureSensorAvailability.available,
        ),
      );
      return;
    }

    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;

    final future = _checkAndStart(roomId);
    _initInFlight = future;
    try {
      await future;
    } finally {
      _initInFlight = null;
    }
  }

  /// 前のルーム・前の画面で出た失敗表示を消す(待機画面を開いたときに呼ぶ)。
  ///
  /// このproviderはルームをまたいで生き続けるため、失敗したまま退出して
  /// 別のルームに入ると、何も押していないのに失敗文が残って見える。
  /// 状態を書き換えるので、ビルド中(useEffectの中)から直接呼ばず、
  /// フレーム確定後に呼ぶこと。
  void clearCalibrationFailure() {
    if (state.calibrationFailure == CalibrationFailure.none) return;
    state = state.copyWith(calibrationFailure: CalibrationFailure.none);
  }

  Future<void> _checkAndStart(String roomId) async {
    final epoch = _epoch;
    final available = await _repo.checkSensorAvailable();
    unawaited(_repo.reportSensorAvailability(roomId, available: available));

    // 待っている間に画面を離れていたら、ローカルstateへの反映も購読の開始も
    // しない(RTDBへの記録は上で済ませている。端末にセンサーがあるかどうかは
    // 画面を離れても変わらない事実なので、書いて困らない)。
    // **状態をcheckingのまま残すのが大事**で、ここでavailabilityを書くと
    // 上のガードに引っかかって`_checkAndStart`が二度と走らず、次に
    // ゲームへ入ったとき気圧が永久に取れなくなる。
    if (epoch != _epoch) return;

    if (!available) {
      state = state.copyWith(
        sensorAvailability: PressureSensorAvailability.unavailable,
      );
      return;
    }

    state = state.copyWith(
      sensorAvailability: PressureSensorAvailability.available,
    );
    _repo.watchMyPressure().listen((value) {
      state = state.copyWith(myPressureHPa: value);
    });
  }

  /// ホストが自分の気圧を基準値として書き込む。
  ///
  /// 失敗しても例外は投げず、理由を[PressureState.calibrationFailure]に
  /// 残す(押した本人が画面で理由を読めるようにするため。issue #98)。
  Future<void> calibrateAsHost(String roomId) async {
    final myPressure = state.myPressureHPa;
    if (myPressure == null) {
      state = state.copyWith(calibrationFailure: CalibrationFailure.noPressure);
      return;
    }

    state = state.copyWith(
      isCalibrating: true,
      calibrationFailure: CalibrationFailure.none,
    );
    try {
      await _repo.calibrateAsHost(roomId, myPressure);
    } on Object catch (e) {
      debugPrint('[PressureViewModel] calibrateAsHost failed: $e');
      state = state.copyWith(
        calibrationFailure: CalibrationFailure.writeFailed,
      );
    } finally {
      state = state.copyWith(isCalibrating: false);
    }
  }

  /// 参加者が「自分の気圧 - 基準値」をoffsetとして書き込む。
  /// basePressureHPa はホストがキャリブレーション済みでないとnull。
  ///
  /// [calibrateAsHost]と同じく、失敗の理由は状態に残す(issue #98)。
  Future<void> calibrateAsParticipant(
    String roomId,
    double? basePressureHPa,
  ) async {
    final myPressure = state.myPressureHPa;
    if (myPressure == null) {
      state = state.copyWith(calibrationFailure: CalibrationFailure.noPressure);
      return;
    }
    if (basePressureHPa == null) {
      state = state.copyWith(
        calibrationFailure: CalibrationFailure.noBasePressure,
      );
      return;
    }

    state = state.copyWith(
      isCalibrating: true,
      calibrationFailure: CalibrationFailure.none,
    );
    try {
      await _repo.calibrateAsParticipant(roomId, myPressure, basePressureHPa);
    } on Object catch (e) {
      debugPrint('[PressureViewModel] calibrateAsParticipant failed: $e');
      state = state.copyWith(
        calibrationFailure: CalibrationFailure.writeFailed,
      );
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
    _epoch++;
    _repo.disposeSensor();
  }
}

final pressureViewModelProvider =
    NotifierProvider<PressureViewModel, PressureState>(
      PressureViewModel.new,
    );

/// 自分から見た、他の参加者それぞれの相対的な高さ。
///
/// room(基準気圧・offset)とlocations(各人の生の気圧)の両方に依存する
/// 純粋な計算結果なので、PressureViewModelの状態としてではなく
/// 導出Providerとして持たせている(どちらかが変わるたびに自動で再計算される)。
final relativeVerticalPositionsProvider =
    Provider.family<List<RelativeVerticalPosition>, String>(
      (ref, roomId) {
        final room = ref.watch(roomStreamProvider(roomId)).value;
        final myPressure = ref.watch(pressureViewModelProvider).myPressureHPa;
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        if (room == null || myPressure == null || myUid == null)
          return const [];

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
          positions.add(
            RelativeVerticalPosition(uid: location.uid, deltaMeters: delta),
          );
        }
        return positions;
      },
    );

/// 表示を「鬼(または逃走者)だけ」に絞るため、Wi-Fi側の
/// nearestOpponentUidProvider(共通APのRSSI差が最小の相手)をそのまま流用し、
/// 上のrelativeVerticalPositionsProviderからその1人分だけを取り出す。
/// 対象が見つからない、またはその相手がまだ気圧を送っていない場合はnull
/// (画面側で「検知なし」として扱う)。
final nearestOpponentVerticalPositionProvider =
    Provider.family<RelativeVerticalPosition?, String>(
      (ref, roomId) {
        final nearestUid = ref.watch(nearestOpponentUidProvider(roomId));
        if (nearestUid == null) return null;

        final positions = ref.watch(relativeVerticalPositionsProvider(roomId));
        for (final position in positions) {
          if (position.uid == nearestUid) return position;
        }
        return null;
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
