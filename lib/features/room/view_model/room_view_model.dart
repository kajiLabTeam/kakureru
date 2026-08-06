import 'package:device_info_plus/device_info_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../model/room.dart';
import '../repository/room_repository.dart';

final roomRepositoryProvider = Provider((ref) => RoomRepository());

final deviceIdProvider = FutureProvider<String>((ref) async {
  final info = await DeviceInfoPlugin().androidInfo;
  return info.id;
});

class RoomViewModel extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  RoomRepository get _repo => ref.read(roomRepositoryProvider);

  Future<void> createRoom(String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await ref.read(deviceIdProvider.future);
      return _repo.createRoom(displayName: displayName, deviceId: deviceId);
    });
  }

  Future<void> joinRoom(String code, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await ref.read(deviceIdProvider.future);
      return _repo.joinRoom(
        code: code,
        displayName: displayName,
        deviceId: deviceId,
      );
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
