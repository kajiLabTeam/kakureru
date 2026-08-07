import 'package:firebase_database/firebase_database.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 端末時計とサーバー時刻のズレ(ミリ秒)。サーバー時刻 = 端末時刻 + このオフセット。
///
/// RTDBの特殊パス `.info/serverTimeOffset` を購読して求める。値が
/// 届く前(接続直後の一瞬)は 0 として扱い、端末時刻をそのまま使う。
final serverTimeOffsetProvider = StreamProvider<int>((ref) {
  return FirebaseDatabase.instance
      .ref('.info/serverTimeOffset')
      .onValue
      .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
});

/// 与えられたオフセットを使って、現在のサーバー時刻(エポックミリ秒)を返す。
///
/// `offsetMillis` には `serverTimeOffsetProvider` の現在値
/// (`ref.watch(serverTimeOffsetProvider).valueOrNull ?? 0`)を渡す。
int serverNowMillis(int offsetMillis) {
  return DateTime.now().millisecondsSinceEpoch + offsetMillis;
}
