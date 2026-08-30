import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_result.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';
import 'package:kakureru/features/wifi/repository/wifi_scan_repository.dart';

final wifiScanRepositoryProvider = Provider((ref) => WifiScanRepository());

/// 表示方式A用: 自分以外の参加者それぞれの3段階判定(ヒステリシス適用前の生の値)。
///
/// 気圧の relativeVerticalPositionsProvider と同じ方針で、room(役割)と
/// locations(各人のWi-Fiスキャン結果)の両方に依存する導出Providerにしている。
final _rawWifiProximityLevelsProvider =
    Provider.family<List<WifiProximityEntry>, String>((ref, roomId) {
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

/// 表示方式A用: 自分以外の参加者それぞれの3段階判定。
///
/// Wi-Fiスキャンは端末ごとに非同期・約25秒間隔で行われRSSIも揺らぐため、
/// 生の判定([_rawWifiProximityLevelsProvider])をそのまま出すと、実際は
/// 近くにいても1回のスキャンのノイズで一瞬「検知なし」に振れてしまう
/// (issue #8 追加調査)。直近で検知できていた相手は
/// [proximityHysteresisGraceDuration]の間、判定を保持してから
/// notDetectedに切り替える。
class WifiProximityLevelsNotifier extends Notifier<List<WifiProximityEntry>> {
  WifiProximityLevelsNotifier(this.roomId);

  final String roomId;

  final Map<String, ProximityLevel> _lastLevel = {};
  final Map<String, DateTime> _lastGoodAt = {};

  @override
  List<WifiProximityEntry> build() {
    final rawEntries = ref.watch(_rawWifiProximityLevelsProvider(roomId));
    final now = DateTime.now();

    // ルームを離れた(=locationsから消えた)相手のヒステリシス状態は残さない。
    final currentUids = rawEntries.map((e) => e.uid).toSet();
    _lastLevel.removeWhere((uid, _) => !currentUids.contains(uid));
    _lastGoodAt.removeWhere((uid, _) => !currentUids.contains(uid));

    return rawEntries.map((entry) {
      if (entry.level != ProximityLevel.notDetected) {
        _lastGoodAt[entry.uid] = now;
        _lastLevel[entry.uid] = entry.level;
        return entry;
      }
      final displayed = applyProximityHysteresis(
        lastDisplayedLevel: _lastLevel[entry.uid],
        lastGoodAt: _lastGoodAt[entry.uid],
        now: now,
      );
      _lastLevel[entry.uid] = displayed;
      return displayed == entry.level
          ? entry
          : entry.copyWith(level: displayed);
    }).toList();
  }
}

final wifiProximityLevelsProvider =
    NotifierProvider.family<
      WifiProximityLevelsNotifier,
      List<WifiProximityEntry>,
      String
    >(
      WifiProximityLevelsNotifier.new,
    );

/// 自分から見て最も近い「対象の役割」の相手のuid(ヒステリシス適用前の生の値)。
final _rawNearestOpponentUidProvider = Provider.family<String?, String>((
  ref,
  roomId,
) {
  final room = ref.watch(roomStreamProvider(roomId)).value;
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (room == null || myUid == null) return null;

  final myRole = _roleOf(room.users, myUid);
  final opponentRole = myRole == UserRole.demon
      ? UserRole.fugitive
      : UserRole.demon;

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

/// 自分から見て最も近い「対象の役割」の相手のuid。
///
/// [_rawNearestOpponentUidProvider]と同じ理由(Wi-Fiスキャンのノイズ)で、
/// 直近で見つかっていた相手は[proximityHysteresisGraceDuration]の間、
/// 保持してからnullに切り替える。この値はRSSI比較表示(topWifiComparisonsProvider)
/// と気圧の上下判定(nearestOpponentVerticalPositionProvider)の両方が
/// 経由するため、ここで平滑化すればどちらの表示も一緒に安定する。
class NearestOpponentUidNotifier extends Notifier<String?> {
  NearestOpponentUidNotifier(this.roomId);

  final String roomId;

  String? _lastUid;
  DateTime? _lastFoundAt;

  @override
  String? build() {
    final rawUid = ref.watch(_rawNearestOpponentUidProvider(roomId));
    final now = DateTime.now();

    if (rawUid != null) {
      _lastUid = rawUid;
      _lastFoundAt = now;
      return rawUid;
    }
    final displayed = applyNearestUidHysteresis(
      lastUid: _lastUid,
      lastFoundAt: _lastFoundAt,
      now: now,
    );
    _lastUid = displayed;
    return displayed;
  }
}

final nearestOpponentUidProvider =
    NotifierProvider.family<NearestOpponentUidNotifier, String?, String>(
      NearestOpponentUidNotifier.new,
    );

/// 表示方式B用: 最も近い相手との上位3AP比較データ。
final topWifiComparisonsProvider =
    Provider.family<List<WifiApComparison>, String>((ref, roomId) {
      final nearestUid = ref.watch(nearestOpponentUidProvider(roomId));
      if (nearestUid == null) return const [];

      final myUid = FirebaseAuth.instance.currentUser?.uid;
      final locations = ref.watch(locationViewModelProvider).locations;
      final selfScan = _scanFor(locations, myUid);
      final targetScan = _scanFor(locations, nearestUid);
      if (selfScan == null || targetScan == null) return const [];

      return selectTopCommonAccessPoints(
        selfScan.bssidRssi,
        targetScan.bssidRssi,
      );
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

UserRole? _roleOf(List<RoomUser> users, String uid) =>
    _findUser(users, uid)?.role;
