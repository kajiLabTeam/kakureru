/// Wi-Fiの手がかりの計算に使うスキャン結果を、ホットスポットを除いた形に
/// そろえる(issue #142)。RTDBやプラグインに依存しない純粋な計算。
library;

import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';

/// 各参加者のBSSID→RSSIから、共有されたホットスポットを除いたもの(uid→)。
/// スキャン結果がまだ無い人は含めない。
///
/// テザリングの親機は持ち主と一緒に動くAPで、固定APを前提にした比較に
/// 混ぜると手がかりがブレる。近い/遠い・最寄り・電波の一致・メーターは
/// **すべてこの結果から計算する**(どこか1か所だけ除き忘れると、そこだけ
/// ホットスポットが戻ってくるため)。テザリングを使っていない人の端末でも
/// 同じように除く(その人のスキャンにも他人のホットスポットは入る)。
///
/// 除外に使う`hotspotBssid`は、[users]のうち**退出していない人**の分だけ
/// 集める。`locations/`は退出しても消さない運用のため、全員分を集めると
/// 退出した人の古い値がルームが続く限り残り続ける。[users]がまだ届いて
/// いない(null)ときは、全員分を集める。
Map<String, Map<String, int>> clueBssidRssiByUid({
  required List<UserLocation> locations,
  required List<RoomUser>? users,
}) {
  final activeUids = users == null
      ? null
      : {
          for (final user in users)
            if (!user.hasLeft) user.id,
        };
  final hotspots = hotspotBssidsOf(
    locations
        .where((l) => activeUids == null || activeUids.contains(l.uid))
        .map((l) => l.wifiScan),
  );
  return {
    for (final location in locations)
      if (location.wifiScan case final scan?)
        location.uid: excludeAccessPoints(scan.bssidRssi, hotspots),
  };
}
