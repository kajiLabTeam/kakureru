import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';

/// あるビューア(役割)から、あるターゲット(役割)の位置が見えるかどうかを判定する。
///
/// 7/13のプレイテストで「最初の1人を見つけるまでの鬼がきつい」という
/// 課題が出たため、鬼側が先に情報を得られる非対称な可視性にしている:
/// - 同じ役割同士は常に見える(チームメイトを隠す理由が無い)
/// - 鬼→逃走者: releasedAt を過ぎたら(released フェーズ)見える
/// - 逃走者→鬼: 鬼放出前(beforeRelease)は一切見えない(issue #10)、
///   放出後も releasedAt + fugitiveInfoDelaySec(=最初の1分は鬼タイム)
///   を過ぎるまで見えない
///
/// Phase 1ではクライアント側の表示制御のみ(Phase 3でvisible/方式へ移行、
/// docs/rtdb-schema.md参照)。
bool isRoleVisible({
  required UserRole viewerRole,
  required UserRole targetRole,
  required int? releasedAt,
  required int fugitiveInfoDelaySec,
  required int nowMillis,
}) {
  if (viewerRole == targetRole) return true;
  if (releasedAt == null) return false;

  final phase = determineGamePhase(
    releasedAt: releasedAt,
    nowMillis: nowMillis,
  );

  switch (viewerRole) {
    case UserRole.demon:
      // 鬼→逃走者: 鬼放出後(releasedフェーズ)なら見える
      return phase == GamePhase.released;
    case UserRole.fugitive:
      // 逃走者→鬼: 鬼放出前(beforeRelease)は一切見せない(issue #10)。
      // タイムスタンプ比較だけに依存すると、サーバー時刻のズレで意図せず
      // 表示されるリスクがあるため、フェーズを使って明示的にブロックする。
      if (phase == GamePhase.beforeRelease) return false;
      return nowMillis >= releasedAt + fugitiveInfoDelaySec * 1000;
  }
}

/// ゲームの局面。鬼放出前か後か。
enum GamePhase {
  /// releasedAt より前(鬼放出待ち)。
  beforeRelease,

  /// releasedAt を過ぎた(鬼放出後、ゲーム終了まで)。
  released,
}

/// 現在時刻がreleasedAtの前か後かを判定する。releasedAtが未確定ならbeforeRelease扱い。
GamePhase determineGamePhase({
  required int? releasedAt,
  required int nowMillis,
}) {
  if (releasedAt == null || nowMillis < releasedAt)
    return GamePhase.beforeRelease;
  return GamePhase.released;
}

/// 画面に表示すべき残り秒数(切り上げ)。
///
/// beforeRelease中はreleasedAtまでの残り、released後はendsAtまでの残りを返す。
/// 対象の時刻がまだ確定していなければnull。
int? calculateCountdownSeconds({
  required GamePhase phase,
  required int? releasedAt,
  required int? endsAt,
  required int nowMillis,
}) {
  final target = phase == GamePhase.beforeRelease ? releasedAt : endsAt;
  if (target == null) return null;
  return ((target - nowMillis) / 1000).ceil();
}

/// 「捕まった」ボタンを表示すべきかどうかを判定する。
///
/// まだ誰も追いかけていない鬼放出前(beforeRelease)は不要なため、
/// 逃走者(role==fugitive)かつ鬼放出後(phase==released)のときだけ表示する。
bool canReportCaught({required UserRole role, required GamePhase phase}) {
  return role == UserRole.fugitive && phase == GamePhase.released;
}

/// 新たに鬼になった参加者のうち、SnackBarで通知すべきuidの集合を返す。
///
/// 自分自身(myUid)は除く。「捕まった」ボタンで自分が鬼になった場合は
/// GamePage側で別途CaughtTransitionOverlay(全画面演出)を出すため、
/// 同じ変化に対してSnackBarも表示すると二重の通知になってしまう(issue #15)。
Set<String> uidsToNotifyOfDemonChange({
  required Set<String> previousDemonUids,
  required Set<String> currentDemonUids,
  required String? myUid,
}) {
  return currentDemonUids
      .difference(
        previousDemonUids,
      )
      .where((uid) => uid != myUid)
      .toSet();
}

/// 逃走者から見て、鬼の位置が可視性ディレイでまだ見えない理由の案内文。
///
/// [isRoleVisible]がfalseを返す状況(逃走者→鬼、鬼放出前 or
/// fugitiveInfoDelaySec経過前)に対応するメッセージを返す。それ以外の
/// 状況(もう見えているはず)ではnull。
///
/// UI改修モック(docs/ui-mockup-2a.html 2a-04)で、可視性ディレイ中に
/// 何も表示されないと「壊れているのか仕様なのか分からない」という課題が
/// 指摘されたための追加。
String? fugitiveHiddenDemonReason({
  required GamePhase phase,
  required int? releasedAt,
  required int fugitiveInfoDelaySec,
  required int nowMillis,
}) {
  if (phase == GamePhase.beforeRelease) {
    return '鬼の放出後、$fugitiveInfoDelaySec秒経つと表示されます';
  }
  if (releasedAt == null) return null;
  final remainingMs = releasedAt + fugitiveInfoDelaySec * 1000 - nowMillis;
  if (remainingMs <= 0) return null;
  final remainingSec = (remainingMs / 1000).ceil();
  return 'あと$remainingSec秒で表示されます';
}

/// 結果画面へ遷移すべきタイミングかどうかを判定する。
///
/// meta/status が FINISHED になった場合、endsAt を過ぎた場合、または
/// ゲーム進行中(PLAYING)に逃走者が0人(全員鬼)になった場合に真。
/// 逃走者0人での終了は「ゲームが始まった後」だけ意味を持つため、
/// PLAYING時のみ判定する(WAITING中はまだ誰も逃走者を割り当てていない
/// だけなので、それを終了扱いにしない)。
/// 端末ごとの時計のズレを避けるため、比較には絶対時刻(serverNowMillis)を使う。
bool isGameOver({
  required RoomStatus status,
  required int? endsAt,
  required int nowMillis,
  bool hasFugitives = true,
}) {
  if (status == RoomStatus.finished) return true;
  if (status == RoomStatus.playing && !hasFugitives) return true;
  return endsAt != null && nowMillis >= endsAt;
}

/// ホストが「ゲーム開始」を押せる役割構成かどうかを判定する。
///
/// 鬼が1人もいない、または全員鬼(逃走者が1人もいない)のいずれかだと
/// 開始した瞬間に[isGameOver]が真になってしまい成立しないため、
/// どちらの役割も1人以上いることを開始条件にする(issue #33)。
bool hasStartableRoleComposition({
  required int demonCount,
  required int totalUserCount,
}) {
  return demonCount > 0 && demonCount < totalUserCount;
}
