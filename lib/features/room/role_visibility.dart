import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';

/// あるビューア(役割)から、あるターゲット(役割)の位置が見えるかどうかを判定する。
///
/// 7/13のプレイテストで「最初の1人を見つけるまでの鬼がきつい」という
/// 課題が出たため、鬼側が先に情報を得られる非対称な可視性にしている:
/// - 同じ役割同士は常に見える(チームメイトを隠す理由が無い)
/// - 鬼→逃走者: releasedAt を過ぎたら(released フェーズ)見える
/// - 逃走者→鬼: 鬼放出前(beforeRelease)は一切見えない(issue #10)、
///   放出後は releasedAt + fugitiveInfoDelaySec を過ぎたら見える
///   (既定は0秒=放出されたらすぐ見える。以前は最初の1分を鬼タイムにしていた)
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

/// 「捕まえた」の帯(CatchButtonStrip)自体を表示すべきかどうか(issue #140)。
///
/// 旧「鬼になる」ボタン(issue #43)と同じく、ゲーム中は最初から出しておき、
/// 押せるかどうかだけを[canPressCatchButton]とBLEの検知で切り替える。
/// 鬼の放出前も出す(放出されてから帯が現れるとレイアウトがずれ、
/// どこに出るのかも分からないため)。
bool shouldShowCatchButton({required UserRole? role}) {
  return role == UserRole.demon;
}

/// 地図の右下の目撃写真ボタンを出すか。
///
/// 目撃写真は鬼の居場所の手がかりになるため、鬼には見せない。役割が
/// 分からない間も出さない(一瞬でも鬼に見えてしまうのを避けるため)。
bool shouldShowSightingPhotoButton({required UserRole? role}) {
  return role == UserRole.fugitive;
}

/// 「捕まえた」を押せるフェーズか。放出前の鬼はまだ捕まえられない。
/// 3m以内に逃走者がいるかどうか(BLE)は別に判定する。
bool canPressCatchButton({required UserRole? role, required GamePhase phase}) {
  return role == UserRole.demon && phase == GamePhase.released;
}

/// 新たに鬼になった参加者のうち、SnackBarで通知すべきuidの集合を返す。
///
/// 自分自身(myUid)は除く。自分が捕まって鬼になった場合はGamePage側で
/// 全画面の「あなたは鬼になった」を出すため、SnackBarも出すと二重になる。
///
/// [excludedUids](今のゲームで「捕まえた」で鬼になった人)も除く。捕獲は
/// 取り消しの期限(catch_rules.dartの`catchUndoWindow`)を過ぎてから「AがBを捕まえた」として
/// 全員に知らせる(issue #140)。ここで役割の変化をすぐ知らせると、期限前に
/// 捕まったことが漏れ、取り消されたら撤回もできないため。
Set<String> uidsToNotifyOfDemonChange({
  required Set<String> previousDemonUids,
  required Set<String> currentDemonUids,
  required String? myUid,
  Set<String> excludedUids = const {},
}) {
  return currentDemonUids
      .difference(previousDemonUids)
      .where((uid) => uid != myUid && !excludedUids.contains(uid))
      .toSet();
}

/// 相手の位置が可視性ディレイでまだ見えない理由の案内文。
///
/// [isRoleVisible]がfalseを返す状況に対応するメッセージを返す。もう
/// 見えているはずの状況ではnull。
///
/// UI改修モック(docs/ui-mockup-2a.html 2a-04)で、可視性ディレイ中に
/// 何も表示されないと「壊れているのか仕様なのか分からない」という課題が
/// 指摘されたための追加。当初は逃走者→鬼の片側にしか無かったが、
/// [isRoleVisible]の仕様上は鬼放出前は鬼→逃走者も見えないため、
/// 鬼視点にも同じ案内を出せるよう[viewerRole]で分岐する(issue #30)。
///
/// 鬼視点の放出前は残り時間が刻々と変わるので、案内文にも
/// カウントダウンを載せる。呼び出し側が毎秒リビルドしている前提
/// (GamePageのtick)。
String? hiddenOpponentReason({
  required UserRole viewerRole,
  required GamePhase phase,
  required int? releasedAt,
  required int fugitiveInfoDelaySec,
  required int nowMillis,
}) {
  switch (viewerRole) {
    case UserRole.demon:
      // 鬼→逃走者は、放出されるまでの間だけ見えない。
      if (phase == GamePhase.released) return null;
      if (releasedAt == null) return '鬼の放出を待っています';
      final remainingSec = ((releasedAt - nowMillis) / 1000).ceil();
      return '鬼の放出まで ${formatCountdown(remainingSec)}';
    case UserRole.fugitive:
      // 逃走者→鬼は、放出前に加えてfugitiveInfoDelaySecの間も見えない。
      if (phase == GamePhase.beforeRelease) {
        if (fugitiveInfoDelaySec <= 0) return '鬼が放出されると表示されます';
        return '鬼の放出後、$fugitiveInfoDelaySec秒経つと表示されます';
      }
      if (releasedAt == null) return null;
      final remainingMs = releasedAt + fugitiveInfoDelaySec * 1000 - nowMillis;
      if (remainingMs <= 0) return null;
      final remainingSec = (remainingMs / 1000).ceil();
      return 'あと$remainingSec秒で表示されます';
  }
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
