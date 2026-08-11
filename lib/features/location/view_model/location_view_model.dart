import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_repository.dart';
import 'package:permission_handler/permission_handler.dart';

part 'location_view_model.freezed.dart';

final locationRepositoryProvider = Provider((ref) => LocationRepository());

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
  late final LocationRepository _repo;

  @override
  LocationState build() {
    // dispose時のコールバック(_disposeSubscriptions)からはref.read()が
    // 呼べない(Riverpodのライフサイクル制約)ため、build()時に一度だけ取得
    // してフィールドに持っておく。
    _repo = ref.read(locationRepositoryProvider);
    ref.onDispose(_disposeSubscriptions);
    return const LocationState();
  }

  /// ゲーム画面に入った時に呼ぶ。権限を確認し、位置送信を開始して
  /// 他ユーザーの位置の購読を始める。権限が無ければ送信は行わず、
  /// permissionDenied を立てるだけにとどめる。
  Future<void> start(String roomId) async {
    final granted = await ensurePermission();
    if (!granted) {
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

  /// ポケットに入れたまま遊ぶ運用のため「常に許可」(バックグラウンド位置情報)まで
  /// 必要とする。Android 11+では「使用中のみ許可」と同時には付与できないため、
  /// まず使用中の許可を確定させてから、改めて常時許可をリクエストする。
  /// 加えてForeground Serviceの通知(Android 13+)の権限も確認する。

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    final whileInUse = await Permission.locationWhenInUse.request();
    if (!whileInUse.isGranted) return false;

    final always = await Permission.locationAlways.request();
    if (!always.isGranted) return false;

    var notification =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notification != NotificationPermission.granted) {
      notification =
          await FlutterForegroundTask.requestNotificationPermission();
    }
    return notification == NotificationPermission.granted;
  }
}

final locationViewModelProvider =
    NotifierProvider<LocationViewModel, LocationState>(
      LocationViewModel.new,
    );
