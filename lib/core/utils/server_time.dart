import 'dart:async';

import 'package:clock/clock.dart';
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
///
/// `DateTime.now()`ではなく`clock.now()`を通すのは、テストから時間を進めら
/// れるようにするため。本番では`clock`の既定が`DateTime.now`なので挙動は
/// 同じ。時間で発火する判定(`GameAlerts`)は1秒ごとのタイマーで回っており、
/// `fakeAsync`で実時間を待たずに検証するにはここが差し替え可能である必要が
/// ある(issue #71)。
///
/// なお**経過時間の計測にこれを使ってはいけない**。NTP補正で時刻が巻き
/// 戻ると猶予が進まず、進みすぎると一気に飛ぶ。経過時間には`Stopwatch`
/// など単調増加の時計を使うこと(`GameAlerts`の`_elapsed`参照)。
int serverNowMillis(int offsetMillis) {
  return clock.now().millisecondsSinceEpoch + offsetMillis;
}

/// `.info/serverTimeOffset`を1回だけ読んで返す。
///
/// このノードはSDKがローカルに持つ値なので購読すればすぐ届くが、
/// 届かないまま呼び出し側の処理(ルーム参加など)を止めてしまわないよう、
/// [timeout]を過ぎたらオフセット0(=端末時計)にフォールバックする。
/// [Stream.first]はイベントが来るまで購読を解いてくれず、タイムアウト時に
/// 購読が宙に浮くため、ここでは自前で[StreamSubscription]を持って必ず
/// キャンセルする。
///
/// 画面から継続的に見る場合は[serverTimeOffsetProvider]を使うこと。
/// こちらは単発で必要な場所(リポジトリ層)のための入口で、
/// オフセットの取得経路を1箇所にまとめるために置いている。
Future<int> fetchServerTimeOffset(
  FirebaseDatabase db, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final completer = Completer<int>();
  final subscription = db
      .ref('.info/serverTimeOffset')
      .onValue
      .listen(
        (event) {
          if (!completer.isCompleted) {
            completer.complete((event.snapshot.value as num?)?.toInt() ?? 0);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(0);
        },
      );
  try {
    return await completer.future.timeout(timeout, onTimeout: () => 0);
  } finally {
    await subscription.cancel();
  }
}
