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

  final phase = determineGamePhase(releasedAt: releasedAt, nowMillis: nowMillis);

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
GamePhase determineGamePhase({required int? releasedAt, required int nowMillis}) {
  if (releasedAt == null || nowMillis < releasedAt) return GamePhase.beforeRelease;
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

/// 結果画面へ遷移すべきタイミングかどうかを判定する。
///
/// meta/status が FINISHED になった場合、または endsAt を過ぎた場合に真。
/// 端末ごとの時計のズレを避けるため、比較には絶対時刻(serverNowMillis)を使う。
bool isGameOver({required RoomStatus status, required int? endsAt, required int nowMillis}) {
  if (status == RoomStatus.finished) return true;
  return endsAt != null && nowMillis >= endsAt;
}
