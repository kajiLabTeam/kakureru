import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/features/room/model/room_user.dart';

/// 案内カードの丸の中に出すアイコンの種類。
///
/// 以前は絵文字を出していたが、ゲーム画面モック(kakureru-ui-mock.html)は
/// 絵文字を使わず線のアイコンで統一しているため、種類だけをここで決め、
/// 実際のIconDataはウィジェット側(`HiddenOpponentCard`)で割り当てる。
enum GameStatusIcon {
  /// 鬼視点で逃走者が全員捕まった。
  allCaught,

  /// 逃走者視点でまだ鬼が指名されていない。
  waiting,

  /// 可視性ディレイでまだ見えない。
  hidden,

  /// 見えてもいいが、まだ検知できていない。
  notDetected,
}

/// ゲーム画面の「相手一覧」欄に、チップ一覧の代わりに出す案内の内容。
///
/// 文言の組み立てはこのファイルの純粋関数で行い、ウィジェット
/// (`HiddenOpponentCard`)は受け取ったものを並べるだけにしている。
///
/// `pill`はカード下端の「あと MM:SS で表示されます」のような、いつ解消する
/// かを示す短い一言。出すものが無ければnull。
///
/// 値を保持するだけの型だが、Freezed必須ルール(AGENTS.md)の対象になる
/// クラスを増やさずに済むようレコードの型エイリアスにしてある。
typedef GameStatusMessage = ({
  GameStatusIcon icon,
  String headline,
  String? detail,
  String? pill,
});

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

/// 相手の手がかりが見えるようになるまでの残り秒数。
///
/// 可視性の規則(role_visibility.dartの`isRoleVisible`)と同じ時刻を使う:
/// 鬼から逃走者は放出時刻([releasedAt])、逃走者から鬼は放出時刻に
/// [fugitiveInfoDelaySec]を足した時刻に見えるようになる。
/// [releasedAt]が分からなければnull。既に過ぎていれば0。
int? opponentRevealRemainingSec({
  required UserRole viewerRole,
  required int? releasedAt,
  required int fugitiveInfoDelaySec,
  required int nowMillis,
}) {
  if (releasedAt == null) return null;
  final revealAt = viewerRole == UserRole.demon
      ? releasedAt
      : releasedAt + fugitiveInfoDelaySec * 1000;
  final remainingMs = revealAt - nowMillis;
  if (remainingMs <= 0) return 0;
  return (remainingMs / 1000).ceil();
}

/// 相手一覧が空のときに出す案内文を組み立てる。
///
/// [hiddenByVisibility]は相手が可視性ディレイで見えていないか、
/// [beforeRelease]は鬼の放出前か、[revealRemainingSec]は見えるように
/// なるまでの残り秒数([opponentRevealRemainingSec]。分からなければnull)。
///
/// 見えない理由と「いつ見えるか」を同じカードに書き、空欄のままにしない
/// (ゲーム画面モック03)。
GameStatusMessage emptyOpponentMessage({
  required UserRole viewerRole,
  required int opponentCountInRoom,
  required bool hiddenByVisibility,
  required bool beforeRelease,
  required int? revealRemainingSec,
}) {
  final opponentRole = viewerRole == UserRole.demon
      ? UserRole.fugitive
      : UserRole.demon;
  final opponentLabel = roleLabelOf(opponentRole);
  final selfLabel = roleLabelOf(viewerRole);
  final reason = describeEmptyOpponentReason(
    opponentCountInRoom: opponentCountInRoom,
    hiddenByVisibility: hiddenByVisibility,
  );

  switch (reason) {
    case EmptyOpponentReason.noOpponentsInRoom:
      return viewerRole == UserRole.demon
          ? (
              icon: GameStatusIcon.allCaught,
              headline: '逃走者は全員捕まりました',
              detail: 'まもなく結果画面に移ります',
              pill: null,
            )
          : (
              icon: GameStatusIcon.waiting,
              headline: 'まだ鬼がいません',
              detail: 'ホストが鬼を指名するまで待ちます',
              pill: null,
            );
    case EmptyOpponentReason.hiddenByVisibility:
      final lead = beforeRelease ? '放出されると' : 'もうすぐ';
      return (
        icon: GameStatusIcon.hidden,
        headline: '$opponentLabelの手がかりはまだ出ません',
        detail:
            '$lead、ここに$opponentLabelの近さと高さが出ます。\n'
            'それまでは、同じ$selfLabelの位置だけ見えます。',
        pill: revealRemainingSec == null
            ? '鬼の放出を待っています'
            : 'あと ${formatCountdown(revealRemainingSec)} で表示されます',
      );
    case EmptyOpponentReason.notDetected:
      return (
        icon: GameStatusIcon.notDetected,
        headline: '$opponentLabelはまだ見つかっていません',
        detail: '$opponentLabelはいますが、まだ近くで検知できていません',
        pill: null,
      );
  }
}

/// 案内文に使う役割の呼び名。
String roleLabelOf(UserRole role) {
  return role == UserRole.demon ? '鬼' : '逃走者';
}
