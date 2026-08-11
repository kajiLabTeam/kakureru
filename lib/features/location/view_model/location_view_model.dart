import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_permission.dart';
import 'package:kakureru/features/location/repository/location_repository.dart';

part 'location_view_model.freezed.dart';

final locationRepositoryProvider = Provider((ref) => LocationRepository());

final locationPermissionServiceProvider = Provider(
  (ref) => LocationPermissionService(),
);

@freezed
abstract class LocationState with _$LocationState {
  const factory LocationState({
    @Default([]) List<UserLocation> locations,
    @Default(false) bool permissionDenied,
    @Default(false) bool isSending,
  }) = _LocationState;
}

class LocationViewModel extends Notifier<LocationState> {
  StreamSubscription<List<UserLocation>>? _locationsSub;

  @override
  LocationState build() {
    ref.onDispose(_disposeSubscriptions);
    return const LocationState();
  }

  LocationRepository get _repo => ref.read(locationRepositoryProvider);

  /// アプリを開いた直後に呼ぶ。位置送信は始めず、権限の要求だけを行う。
  /// ゲーム開始時にまとめて聞かれると場所の移動中に操作させることになるため、
  /// 起動時に済ませておく。結果は permissionDenied に反映する。
  Future<bool> ensurePermission() async {
    final granted = await ref
        .read(locationPermissionServiceProvider)
        .ensureGranted();
    state = state.copyWith(permissionDenied: !granted);
    return granted;
  }

  /// ゲーム画面に入った時に呼ぶ。権限を確認し、位置送信を開始して
  /// 他ユーザーの位置の購読を始める。権限が無ければ送信は行わず、
  /// permissionDenied を立てるだけにとどめる。
  Future<void> start(String roomId) async {
    // 端末の位置情報(GPS)自体がOFFだと権限があっても値が取れないため、
    // 送信を始める直前のここで確認する(起動時の権限要求では見ない)。
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled || !await ensurePermission()) {
      state = state.copyWith(permissionDenied: true);
      return;
    }

    await _repo.startSendingLocation(roomId);
    state = state.copyWith(permissionDenied: false, isSending: true);

    await _locationsSub?.cancel();
    _locationsSub = _repo.watchLocations(roomId).listen((locations) {
      state = state.copyWith(locations: locations);
    });
  }

  /// ゲーム画面を離れた時に呼ぶ。送信・購読を止める。
  void stop() {
    _disposeSubscriptions();
    state = state.copyWith(isSending: false);
  }

  void _disposeSubscriptions() {
    _repo.stopSendingLocation();
    _locationsSub?.cancel();
    _locationsSub = null;
  }
}

final locationViewModelProvider =
    NotifierProvider<LocationViewModel, LocationState>(
      LocationViewModel.new,
    );
