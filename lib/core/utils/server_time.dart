import 'package:firebase_database/firebase_database.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 端末時計とサーバー時刻のズレ。サーバー時刻 = 端末時刻 + このオフセット。
final serverTimeOffsetProvider = StreamProvider<int>((ref) {
  return FirebaseDatabase.instance
      .ref('.info/serverTimeOffset')
      .onValue
      .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
});

/// 与えられたオフセットを使って、現在のサーバー時刻(エポックミリ秒)を返す。
int serverNowMillis(int offsetMillis) {
  return DateTime.now().millisecondsSinceEpoch + offsetMillis;
}
