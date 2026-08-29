import 'package:device_info_plus/device_info_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../model/room.dart';
import '../player_name_validation.dart';
import '../repository/player_preferences_repository.dart';
import '../repository/room_repository.dart';

final roomRepositoryProvider = Provider((ref) => RoomRepository());

final playerPreferencesRepositoryProvider = Provider(
  (ref) => PlayerPreferencesRepository(),
);

/// 前回保存済みのプレイヤー名。未保存/読み込み失敗ならnull。
/// 名前入力欄の初期値の復元に使う。
final savedDisplayNameProvider = FutureProvider<String?>((ref) {
  return ref.watch(playerPreferencesRepositoryProvider).loadDisplayName();
});

final deviceIdProvider = FutureProvider<String>((ref) async {
  final info = await DeviceInfoPlugin().androidInfo;
  return info.id;
});

class RoomViewModel extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  RoomRepository get _repo => ref.read(roomRepositoryProvider);

  PlayerPreferencesRepository get _preferences =>
      ref.read(playerPreferencesRepositoryProvider);

  Future<void> createRoom(String displayName) async {
    final normalized = normalizePlayerName(displayName);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await ref.read(deviceIdProvider.future);
      final roomId = await _repo.createRoom(
        displayName: normalized,
        deviceId: deviceId,
      );
      await _preferences.saveDisplayName(normalized);
      return roomId;
    });
  }

  Future<void> joinRoom(String code, String displayName) async {
    final normalized = normalizePlayerName(displayName);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await ref.read(deviceIdProvider.future);
      final roomId = await _repo.joinRoom(
        code: code,
        displayName: normalized,
        deviceId: deviceId,
      );
      await _preferences.saveDisplayName(normalized);
      return roomId;
    });
  }
}

final roomViewModelProvider = AsyncNotifierProvider<RoomViewModel, String?>(
  RoomViewModel.new,
);

final roomStreamProvider = StreamProvider.family.autoDispose<Room, String>((
  ref,
  roomId,
) {
  return ref.watch(roomRepositoryProvider).watchRoom(roomId);
});
