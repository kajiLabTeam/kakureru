import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// ユーザーに見せるエラーの種類。直し方(ユーザーが次に取る行動)が同じもの
/// を1つにまとめている。
enum UserFacingErrorKind {
  /// 通信できない(圏外・機内モード・Wi-Fiが繋がっていない等)。
  network,

  /// 権限がない(RTDBの`permission-denied`)。終了済みの部屋を触った、
  /// ホスト専用の操作を参加者が行った、といったときに出る。
  permissionDenied,

  /// 対象が無い(部屋が見つからない等)。
  notFound,

  /// 上記のどれでもない想定外。原因を名指しできないので、生の例外文は
  /// 出さずに再試行だけ案内する。
  unknown,
}

/// 通信できないときにFirebaseが返す`code`。前方一致ではなく完全一致で見る
/// (`network-error`等、SDKのバージョンで増えることがあるため列挙で持つ)。
const _networkCodes = {
  'network-error',
  'network_error',
  'unavailable',
  'disconnected',
  'timeout',
};

/// 例外を、ユーザーに見せる粒度へ落とす。
///
/// `code`で分岐するだけでなく`toString()`の中身も見ているのは、RTDBの
/// エラーが常に[FirebaseException]で上がってくるとは限らないため。
/// プラグインの層をまたぐ経路では`Exception: permission_denied ...`の形の
/// ただの[Exception]になることがあり、そこで[UserFacingErrorKind.unknown]
/// へ落ちると「時間をおいて再試行」という直らない案内になってしまう。
UserFacingErrorKind classifyUserFacingError(Object error) {
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code == 'permission-denied' || code == 'permission_denied') {
      return UserFacingErrorKind.permissionDenied;
    }
    if (_networkCodes.contains(code)) return UserFacingErrorKind.network;
    if (code == 'not-found' || code == 'not_found') {
      return UserFacingErrorKind.notFound;
    }
  }
  if (error is SocketException || error is TimeoutException) {
    return UserFacingErrorKind.network;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('permission-denied') ||
      text.contains('permission_denied')) {
    return UserFacingErrorKind.permissionDenied;
  }
  if (text.contains('network') ||
      text.contains('offline') ||
      text.contains('failed host lookup')) {
    return UserFacingErrorKind.network;
  }
  // リポジトリ層が投げる日本語の例外(`Exception('ルームが見つかりません')`
  // 等)も、ここを通してユーザー向けの1文に揃える。`toString()`をそのまま
  // 出すと`Exception: `の接頭辞が付いてしまうため。
  if (text.contains('見つかりません') || text.contains('not found')) {
    return UserFacingErrorKind.notFound;
  }
  return UserFacingErrorKind.unknown;
}

/// 例外を、画面に出せる日本語1文へ変換する。
///
/// `'エラー: $e'` の形で内部の例外をそのまま赤字で見せていたため、
/// `[firebase_database/permission-denied] Client doesn't have permission...`
/// のような英語のスタックトレース混じりの文がユーザーに出ていた(issue #95)。
/// 何が起きたか分からないだけでなく、次に何をすればいいかも分からない。
///
/// 手本は`locationWarningMessage`(game_page.dart)で、原因ごとに「次に取る
/// 行動」まで書く方針をそろえている。原因を名指しできない
/// [UserFacingErrorKind.unknown]でも生の例外文は出さない(出しても直せない
/// ため)。開発時に原因を追うぶんは`debugPrint`側で見る。
String userFacingErrorMessage(Object error) =>
    switch (classifyUserFacingError(error)) {
      UserFacingErrorKind.network => 'ネットワークにつながっていません。電波の届く場所で、もう一度試してください',
      UserFacingErrorKind.permissionDenied =>
        'この操作は許可されませんでした。部屋がもう終了しているか、'
            'ホストだけができる操作かもしれません。ホームに戻ってやり直してください',
      UserFacingErrorKind.notFound => '部屋が見つかりません。ホストに部屋を作り直してもらってください',
      UserFacingErrorKind.unknown => 'うまくいきませんでした。時間をおいて、もう一度試してください',
    };
