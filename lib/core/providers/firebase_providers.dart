import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// サインイン済みの自分のuid。まだサインインしていなければnull。
///
/// 画面から `FirebaseAuth.instance` を直接触ると、Firebaseを初期化して
/// いないwidgetテストでは参照した瞬間に `[core/no-app]` 例外になり、
/// その画面のテストが一切組めなくなる(providerを経由していないので
/// 差し替える隙間が無い)。Provider経由にしておけば
/// `overrideWithValue` でテスト用のuidに差し替えられるため、uidの取得は
/// ここに集約する。
///
/// 匿名サインインは `main()` が `runApp` の前に完了させる(main.dart参照)
/// ため、アプリの生存期間中この値は変わらない。したがってProviderが
/// 値をキャッシュしたままでも、毎回 `FirebaseAuth.instance` を読むのと
/// 同じ結果になる。
final myUidProvider = Provider<String?>(
  (ref) => FirebaseAuth.instance.currentUser?.uid,
);
