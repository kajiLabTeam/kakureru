import 'package:kakureru/features/room/model/room_user.dart';

/// あるビューア(役割)から、あるターゲット(役割)の位置が見えるかどうかを判定する。
///
/// 7/13のプレイテストで「最初の1人を見つけるまでの鬼がきつい」という
/// 課題が出たため、鬼側が先に情報を得られる非対称な可視性にしている:
/// - 同じ役割同士は常に見える(チームメイトを隠す理由が無い)
/// - 鬼→逃走者: releasedAt を過ぎたら見える
/// - 逃走者→鬼: releasedAt + fugitiveInfoDelaySec(=最初の1分は鬼タイム)
///   を過ぎたら見える
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

  if (viewerRole == UserRole.demon) {
    return nowMillis >= releasedAt;
  }
  return nowMillis >= releasedAt + fugitiveInfoDelaySec * 1000;
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
