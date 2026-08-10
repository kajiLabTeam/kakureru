import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_result.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';
import 'package:kakureru/features/wifi/repository/wifi_scan_repository.dart';

final wifiScanRepositoryProvider = Provider((ref) => WifiScanRepository());

/// 表示方式A用: 自分以外の参加者それぞれの3段階判定。
///
/// 気圧の relativeVerticalPositionsProvider と同じ方針で、room(役割)と
/// locations(各人のWi-Fiスキャン結果)の両方に依存する導出Providerにしている。
final wifiProximityLevelsProvider = Provider.family<List<WifiProximityEntry>, String>((ref, roomId) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  final locations = ref.watch(locationViewModelProvider).locations;
  final selfScan = _scanFor(locations, myUid);
  if (myUid == null || selfScan == null) return const [];

  final entries = <WifiProximityEntry>[];
  for (final location in locations) {
    if (location.uid == myUid) continue;
    final targetScan = location.wifiScan;
    if (targetScan == null) continue;
    entries.add(
      WifiProximityEntry(
        uid: location.uid,
        level: calculateProximity(selfScan.bssidRssi, targetScan.bssidRssi),
      ),
    );
  }
  return entries;
});

/// 自分から見て最も近い「対象の役割」の相手のuid。
final nearestOpponentUidProvider = Provider.family<String?, String>((ref, roomId) {
  final room = ref.watch(roomStreamProvider(roomId)).value;
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (room == null || myUid == null) return null;

  final myRole = _roleOf(room.users, myUid);
  final opponentRole = myRole == UserRole.demon ? UserRole.fugitive : UserRole.demon;

  final locations = ref.watch(locationViewModelProvider).locations;
  final selfScan = _scanFor(locations, myUid);
  if (selfScan == null) return null;

  final candidates = <String, Map<String, int>>{};
  for (final location in locations) {
    if (location.uid == myUid) continue;
    if (_roleOf(room.users, location.uid) != opponentRole) continue;
    final scan = location.wifiScan;
    if (scan == null) continue;
    candidates[location.uid] = scan.bssidRssi;
  }

  return findNearestUid(selfScan.bssidRssi, candidates);
});

/// 表示方式B用: 最も近い相手との上位3AP比較データ。
final topWifiComparisonsProvider = Provider.family<List<WifiApComparison>, String>((ref, roomId) {
  final nearestUid = ref.watch(nearestOpponentUidProvider(roomId));
  if (nearestUid == null) return const [];

  final myUid = FirebaseAuth.instance.currentUser?.uid;
  final locations = ref.watch(locationViewModelProvider).locations;
  final selfScan = _scanFor(locations, myUid);
  final targetScan = _scanFor(locations, nearestUid);
  if (selfScan == null || targetScan == null) return const [];

  return selectTopCommonAccessPoints(selfScan.bssidRssi, targetScan.bssidRssi);
});

UserLocation? _findLocation(List<UserLocation> locations, String? uid) {
  if (uid == null) return null;
  for (final location in locations) {
    if (location.uid == uid) return location;
  }
  return null;
}

WifiScanResult? _scanFor(List<UserLocation> locations, String? uid) {
  return _findLocation(locations, uid)?.wifiScan;
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}

UserRole? _roleOf(List<RoomUser> users, String uid) => _findUser(users, uid)?.role;
