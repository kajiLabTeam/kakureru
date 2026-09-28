import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

bool _enabled = false;

/// RTDBのオフライン永続化を有効にする(アプリ起動時に1回だけ呼ぶ)。
///
/// 電波が切れている間の書き込みを端末に溜め、再接続したときに送る。
/// テザリングが切れた・圏外に入ったときの取りこぼしを減らすため。
///
/// `setPersistenceEnabled`は、そのインスタンスで参照(`ref()`)を作る前に
/// 呼ばないと効かない。`Firebase.initializeApp`の直後、他のどのFirebase
/// 操作よりも前(main.dart)で呼ぶこと。2回目以降の呼び出しは何もしない。
/// ホットリスタート等でネイティブ側が既に使用中だった場合の例外は
/// ログに残して握りつぶす(永続化が効かなくてもアプリは動く)。
void enableDatabasePersistence(FirebaseDatabase db) {
  if (_enabled) return;
  _enabled = true;
  try {
    db.setPersistenceEnabled(true);
  } on Object catch (e) {
    debugPrint('[enableDatabasePersistence] 有効化に失敗: $e');
  }
}

/// テスト用: 「呼び出し済み」の印を戻す。
@visibleForTesting
void resetDatabasePersistenceForTest() => _enabled = false;
