import 'package:kakureru/features/room/model/room_user.dart';

/// ゲーム画面の「相手一覧」欄に、チップ一覧の代わりに出す案内の内容。
///
/// 文言の組み立てはこのファイルの純粋関数で行い、ウィジェット
/// ([HiddenOpponentCard])は受け取ったものを並べるだけにしている。
///
/// 値を保持するだけの型だが、Freezed必須ルール(AGENTS.md)の対象になる
/// クラスを増やさずに済むようレコードの型エイリアスにしてある。
typedef GameStatusMessage = ({String emoji, String headline, String? detail});

/// 相手一覧が空のときの「なぜ空なのか」。
enum EmptyOpponentReason {
  /// 対象役割の相手がそもそもルームに1人もいない
  /// (鬼から見て逃走者を全員捕獲した / 逃走者から見て鬼が未指名)。
  noOpponentsInRoom,

  /// 相手はいるが、役割による可視性ディレイでまだ見えない。
  hiddenByVisibility,

  /// 相手はいて見えてもいいが、まだGPS/Wi-Fiで検知できていない。
  notDetected,
}

/// 相手一覧が空になっている理由を判定する。
///
/// 以前はこの3つを区別せず一律「検知なし」と出していたため、鬼が逃走者を
/// 全員捕まえた瞬間も「検知なし」としか出ず、勝ったのか壊れたのか
/// 分からなかった(issue #30)。
///
/// [opponentCountInRoom]は可視性を無視した実数(room.users中の逆役割の
/// 人数)を渡すこと。可視性で絞った後の数を渡すと「見えない」と「居ない」
/// の区別が付かなくなる。
EmptyOpponentReason describeEmptyOpponentReason({
  required int opponentCountInRoom,
  required bool hiddenByVisibility,
}) {
  if (opponentCountInRoom == 0) return EmptyOpponentReason.noOpponentsInRoom;
  if (hiddenByVisibility) return EmptyOpponentReason.hiddenByVisibility;
  return EmptyOpponentReason.notDetected;
}

/// 相手一覧が空のときに出す案内文を組み立てる。
///
/// [hiddenReason]は`hiddenOpponentReason`(role_visibility.dart)の戻り値。
/// 非nullなら可視性ディレイ中で、その文言を補足行に出す。
GameStatusMessage emptyOpponentMessage({
  required UserRole viewerRole,
  required int opponentCountInRoom,
  required String? hiddenReason,
}) {
  final opponentRole = viewerRole == UserRole.demon
      ? UserRole.fugitive
      : UserRole.demon;
  final opponentLabel = opponentRole == UserRole.demon ? '鬼' : '逃走者';
  final reason = describeEmptyOpponentReason(
    opponentCountInRoom: opponentCountInRoom,
    hiddenByVisibility: hiddenReason != null,
  );

  switch (reason) {
    case EmptyOpponentReason.noOpponentsInRoom:
      return viewerRole == UserRole.demon
          ? (
              emoji: '🎉',
              headline: '逃走者は全員捕まりました',
              detail: 'まもなく結果画面に移ります',
            )
          : (
              emoji: '👹',
              headline: 'まだ鬼がいません',
              detail: 'ホストが鬼を指名するまで待ちます',
            );
    case EmptyOpponentReason.hiddenByVisibility:
      return (
        emoji: emojiForRole(opponentRole),
        headline: '$opponentLabelの位置はまだ見えません',
        detail: hiddenReason,
      );
    case EmptyOpponentReason.notDetected:
      return (
        emoji: emojiForRole(opponentRole),
        headline: '検知なし',
        detail: '$opponentLabelはいますが、まだ近くで検知できていません',
      );
  }
}

/// 案内カードのアイコンに使う絵文字。地図のピン(role_theme.dartの
/// IconData)とは別で、カードの大きな飾り用。
String emojiForRole(UserRole role) {
  return role == UserRole.demon ? '👹' : '🏃';
}
