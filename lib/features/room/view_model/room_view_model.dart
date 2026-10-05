import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show StreamProviderFamily;

import '../model/catch_photo.dart';
import '../model/room.dart';
import '../model/room_catch.dart';
import '../model/room_photo.dart';
import '../model/sighting.dart';
import '../player_name_validation.dart';
import '../repository/player_preferences_repository.dart';
import '../repository/room_repository.dart';
import '../room_code_validation.dart';
import '../room_join_error.dart';

final roomRepositoryProvider = Provider((ref) => RoomRepository());

final playerPreferencesRepositoryProvider = Provider(
  (ref) => PlayerPreferencesRepository(),
);

/// 前回保存済みのプレイヤー名。未保存/読み込み失敗ならnull。
/// 名前入力欄の初期値の復元に使う。
final savedDisplayNameProvider = FutureProvider<String?>((ref) {
  return ref.watch(playerPreferencesRepositoryProvider).loadDisplayName();
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
      final roomId = await _repo.createRoom(displayName: normalized);
      await _preferences.saveDisplayName(normalized);
      return roomId;
    });
  }

  Future<void> joinRoom(String code, String displayName) async {
    final normalized = normalizePlayerName(displayName);
    final normalizedCode = normalizeRoomCode(code);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 画面側でも参加ボタンを無効にしているが、ここでも弾いておく。
      // 不正なコードのまま進むと`roomCodes/`の読み取りが権限エラーになり、
      // 英文の例外がそのまま画面に出るため(issue #96)。
      if (validateRoomCode(normalizedCode) != null) {
        throw RoomJoinError.invalidCode;
      }
      final roomId = await _repo.joinRoom(
        code: normalizedCode,
        displayName: normalized,
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

final photosStreamProvider = StreamProvider.family
    .autoDispose<List<RoomPhoto>, String>((ref, roomId) {
      return ref.watch(roomRepositoryProvider).watchPhotos(roomId);
    });

/// 捕獲一覧(`catches`)。前のゲームの分も含むので、画面で使うときは
/// `catchesOfCurrentGame`(catch_rules.dart)で今のゲームに絞ること。
final catchesStreamProvider = StreamProvider.family
    .autoDispose<List<RoomCatch>, String>((ref, roomId) {
      return ref.watch(roomRepositoryProvider).watchCatches(roomId);
    });

/// 捕まえた瞬間の写真のメタデータ一覧(`catchPhotos`)。
final catchPhotosStreamProvider = StreamProvider.family
    .autoDispose<List<CatchPhoto>, String>((ref, roomId) {
      return ref.watch(roomRepositoryProvider).watchCatchPhotos(roomId);
    });

/// 目撃写真(見つけた鬼の写真)のメタデータ一覧(`sightings`)。前のゲームの
/// 分も含むので、画面で使うときは`sightingsOfCurrentGame`
/// (sighting_rules.dart)で今のゲームに絞ること。
final StreamProviderFamily<List<Sighting>, String> sightingsStreamProvider =
    StreamProvider.family.autoDispose<List<Sighting>, String>((ref, roomId) {
      return ref.watch(roomRepositoryProvider).watchSightings(roomId);
    });
