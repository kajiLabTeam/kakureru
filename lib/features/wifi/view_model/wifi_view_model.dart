import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/clue_scans.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';
import 'package:kakureru/features/wifi/repository/wifi_scan_repository.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

final wifiScanRepositoryProvider = Provider((ref) => WifiScanRepository());

/// Wi-Fiスキャンがいま実行できているか(待機画面の表示用。issue #98)。
///
/// スキャンを止めたり再開したりはせず、[refresh]が呼ばれたときだけ
/// 1回試して結果を状態に反映する。位置情報のON/OFFや権限は端末の設定
/// 画面で変えられる(=アプリ側からは変化を検知できない)ので、画面を開いた
/// ときと「再確認」を押したときに確認し直す形にしている。
class WifiScanStatusNotifier extends Notifier<WifiScanStatus> {
  @override
  WifiScanStatus build() => WifiScanStatus.checking;

  /// 実行中の[refresh]。待機画面のマウントと連打が重なっても、
  /// 実際のスキャン要求は1回にまとめる(スロットルの回数を無駄に
  /// 消費しないため)。
  Future<void>? _inFlight;

  Future<void> refresh() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _check();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _check() async {
    state = WifiScanStatus.checking;
    WifiScanStatus result;
    try {
      result = await ref.read(wifiScanRepositoryProvider).triggerScan();
    } on Object catch (e) {
      // プラグイン側の例外(未対応端末でのMissingPluginException等)。
      // ここで握らないと、待機画面が「確認中...」のまま固まる。
      debugPrint('[WifiScanStatusNotifier] triggerScan failed: $e');
      result = WifiScanStatus.failed;
    }
    // 確認を待っている間に画面を離れた(=providerが破棄された)場合、
    // 破棄済みのNotifierへ代入すると例外になる。
    if (!ref.mounted) return;
    state = result;
  }
}

final wifiScanStatusProvider =
    NotifierProvider<WifiScanStatusNotifier, WifiScanStatus>(
      WifiScanStatusNotifier.new,
    );

/// 手がかりの計算に使う、各参加者のBSSID→RSSI(uid→)。共有された
/// ホットスポットは除いてある(issue #142)。
///
/// このファイルのWi-Fiの判定・表示はすべてこれを読む。除外の手順は
/// [clueBssidRssiByUid]を参照。
final clueBssidRssiProvider =
    Provider.family<Map<String, Map<String, int>>, String>((ref, roomId) {
      return clueBssidRssiByUid(
        locations: ref.watch(locationViewModelProvider).locations,
        users: ref.watch(roomStreamProvider(roomId)).value?.users,
      );
    });

/// 表示方式A用: 自分以外の参加者それぞれの3段階判定(ヒステリシス適用前の生の値)。
///
/// 気圧の relativeVerticalPositionsProvider と同じ方針で、room(役割)と
/// locations(各人のWi-Fiスキャン結果)の両方に依存する導出Providerにしている。
final _rawWifiProximityLevelsProvider =
    Provider.family<List<WifiProximityEntry>, String>((ref, roomId) {
      final myUid = ref.watch(myUidProvider);
      final scans = ref.watch(clueBssidRssiProvider(roomId));
      final self = scans[myUid];
      if (myUid == null || self == null) return const [];

      return [
        for (final MapEntry(key: uid, value: target) in scans.entries)
          if (uid != myUid)
            WifiProximityEntry(
              uid: uid,
              level: calculateProximity(self, target),
            ),
      ];
    });

/// 表示方式A用: 自分以外の参加者それぞれの3段階判定。
///
/// Wi-Fiスキャンは端末ごとに非同期・約10秒間隔で行われRSSIも揺らぐため、
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
  final myUid = ref.watch(myUidProvider);
  if (room == null || myUid == null) return null;

  final myRole = _roleOf(room.users, myUid);
  final opponentRole = myRole == UserRole.demon
      ? UserRole.fugitive
      : UserRole.demon;

  final scans = ref.watch(clueBssidRssiProvider(roomId));
  final self = scans[myUid];
  if (self == null) return null;

  return findNearestUid(self, {
    for (final MapEntry(key: uid, value: target) in scans.entries)
      if (uid != myUid && _roleOf(room.users, uid) == opponentRole) uid: target,
  });
});

/// 自分から見て最も近い「対象の役割」の相手のuid。
///
/// [_rawNearestOpponentUidProvider]と同じ理由(Wi-Fiスキャンのノイズ)で、
/// 直近で見つかっていた相手は[proximityHysteresisGraceDuration]の間、
/// 保持してからnullに切り替える。この値は詳細カードの既定選択対象と
/// 気圧の上下判定(nearestOpponentVerticalPositionProvider)の両方が
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

/// 指定した相手との上位3AP比較データ(表示方式B)。
///
/// ゲーム画面の詳細カードは「いま選んでいる相手」(既定は最も近い相手だが
/// タップで任意の相手に切り替えられる。UI改修モック2a-03「逃走者を選んで
/// 詳細を見る」)の比較データを必要とするため、最も近い相手専用だった
/// 旧`topWifiComparisonsProvider`を任意uid対応に一般化した。
final wifiComparisonsForProvider =
    Provider.family<List<WifiApComparison>, (String roomId, String targetUid)>((
      ref,
      args,
    ) {
      final (roomId, targetUid) = args;
      final scans = ref.watch(clueBssidRssiProvider(roomId));
      final self = scans[ref.watch(myUidProvider)];
      final target = scans[targetUid];
      if (self == null || target == null) return const [];

      return selectTopCommonAccessPoints(self, target);
    });

/// 指定した相手との手がかりメーターの値(0〜100)。共通APが無い、
/// またはどちらかのスキャン結果がまだ届いていなければnull。
///
/// 式と係数(暫定)は`wifi_clue_math.dart`の[calculateClueMeter]を参照。
/// 近い/遠いの判定([wifiProximityLevelsProvider])とは独立の表示用の値で、
/// 判定そのものには使わない。
final clueMeterForProvider =
    Provider.family<double?, (String roomId, String targetUid)>((ref, args) {
      final (roomId, targetUid) = args;
      final scans = ref.watch(clueBssidRssiProvider(roomId));
      final self = scans[ref.watch(myUidProvider)];
      final target = scans[targetUid];
      if (self == null || target == null) return null;
      return calculateClueMeter(self, target);
    });

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}

UserRole? _roleOf(List<RoomUser> users, String uid) =>
    _findUser(users, uid)?.role;
