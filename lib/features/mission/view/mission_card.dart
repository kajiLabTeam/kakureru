import 'package:flutter/material.dart';
import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_progress.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// ミッションのカードの状態。
enum MissionCardStatus {
  /// 位置情報の権限が無い。GPSの判定ができないので差し替える。
  needsLocationPermission,

  /// 自分の位置がまだ届いていない。
  locating,

  /// GPSの精度が悪く、判定していない。
  weakGps,

  /// アクセスポイントへ向かっている。
  approaching,

  /// 判定範囲に入った(2回続けて範囲内)。「特典を引く」を出す。
  arrived,

  /// ほかの人に先に取られた。
  takenByOther,

  /// 自分が取った。
  claimedByMe,

  /// 「鬼に近づけ」に挑戦中。
  approachInProgress,

  /// 「鬼に近づけ」を達成した。
  approachAchieved,
}

/// カードの状態を決める。
///
/// 取られたかどうかを最初に見る(取られた後に位置の話を出しても意味が
/// 無いため)。次に権限、到着、GPSの順。到着は一度決まったら保つ
/// ([advanceArrival])ので、到着後にGPSが弱くなってもボタンは消えない。
MissionCardStatus missionCardStatusOf({
  required Mission mission,
  required String? myUid,
  required LocationFailure locationFailure,
  required AccessPointReading reading,
  required MissionProgress progress,
}) {
  switch (mission.type) {
    case MissionType.approachDemon:
      return progress.approach.achieved
          ? MissionCardStatus.approachAchieved
          : MissionCardStatus.approachInProgress;
    case MissionType.accessPoint:
      final claimedBy = mission.claimedBy;
      if (claimedBy != null) {
        return claimedBy == myUid
            ? MissionCardStatus.claimedByMe
            : MissionCardStatus.takenByOther;
      }
      if (locationFailure == LocationFailure.locationPermission) {
        return MissionCardStatus.needsLocationPermission;
      }
      final arrived =
          progress.missionId == mission.id && progress.arrival.arrived;
      if (arrived) return MissionCardStatus.arrived;
      return switch (reading.fix) {
        AccessPointFix.noFix => MissionCardStatus.locating,
        AccessPointFix.weakGps => MissionCardStatus.weakGps,
        AccessPointFix.outside ||
        AccessPointFix.inside => MissionCardStatus.approaching,
      };
  }
}

/// 残り時間(ミリ秒)を「02:14」の形にする。切り上げ。
String formatMissionRemaining(int remainingMillis) =>
    formatCountdown((remainingMillis / 1000).ceil());

/// 距離(m)を「62m」の形にする。
String formatMeters(double meters) => '${meters.round()}m';

/// 地図の上に重ねるミッションのカード(モック1・2・5)。逃走者にだけ出す。
///
/// 表示するだけで、判定はしない(状態は[missionCardStatusOf]で決めて渡す)。
class MissionCard extends StatelessWidget {
  /// すべての値は呼び出し側(GamePage)が計算して渡す。
  const MissionCard({
    super.key,
    required this.mission,
    required this.status,
    required this.reading,
    required this.remainingMillis,
    this.claimedByName,
  });

  /// いま受けているミッション。
  final Mission mission;

  /// カードの状態。
  final MissionCardStatus status;

  /// アクセスポイントとの位置関係(のこり N m・GPS ±N m)。
  final AccessPointReading reading;

  /// 期限までの残り(ミリ秒)。
  final int remainingMillis;

  /// 取った人の名前([MissionCardStatus.takenByOther]のとき)。
  final String? claimedByName;

  @override
  Widget build(BuildContext context) {
    final highlighted = status == MissionCardStatus.arrived;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? missionAccent : gameBorder,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241B1B19),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          const SizedBox(height: 9),
          Text(
            _title(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: gameInk,
            ),
          ),
          ..._body(),
        ],
      ),
    );
  }

  Widget _header() {
    final isApproach = mission.type == MissionType.approachDemon;
    final urgent = remainingMillis < 60 * 1000;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: missionDeep,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.flag, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 7),
        const Text(
          'ミッション',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: gameInk,
          ),
        ),
        const SizedBox(width: 7),
        _Tag(
          label: isApproach ? '全員が挑める' : '先着1名',
          background: isApproach ? fugitiveSoft : missionSoft,
          foreground: isApproach ? fugitiveDeep : missionInk,
        ),
        const Spacer(),
        const Icon(Icons.timer_outlined, size: 16, color: gameMuted),
        const SizedBox(width: 4),
        Text(
          formatMissionRemaining(remainingMillis),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: urgent ? demonDeep : gameInk,
          ),
        ),
      ],
    );
  }

  String _title() => switch (status) {
    MissionCardStatus.needsLocationPermission => '位置情報の許可が必要',
    MissionCardStatus.arrived => 'アクセスポイントに着いた',
    MissionCardStatus.takenByOther => 'ほかの人に取られた',
    MissionCardStatus.claimedByMe => '特典を引いた',
    MissionCardStatus.approachInProgress ||
    MissionCardStatus.approachAchieved => '鬼に近づけ',
    MissionCardStatus.locating ||
    MissionCardStatus.weakGps ||
    MissionCardStatus.approaching => 'アクセスポイントへ行こう',
  };

  List<Widget> _body() {
    switch (status) {
      case MissionCardStatus.needsLocationPermission:
        return const [
          SizedBox(height: 6),
          Text(
            '設定から位置情報を許可すると、アクセスポイントに着いたかを判定できる',
            style: TextStyle(fontSize: 12, height: 1.5, color: gameMuted),
          ),
        ];
      case MissionCardStatus.locating:
        return [
          const SizedBox(height: 6),
          const Text(
            '位置を取得しています',
            style: TextStyle(fontSize: 12, color: gameMuted),
          ),
          const SizedBox(height: 9),
          _footer('半径15m に入ると 特典 を1つ引ける'),
        ];
      case MissionCardStatus.weakGps:
        return [
          const SizedBox(height: 9),
          _distanceRow(),
          const SizedBox(height: 9),
          const _Notice(
            text: 'GPSの電波が弱いため判定していない。空の見える場所で少し待つ',
            icon: Icons.gps_not_fixed,
          ),
          const SizedBox(height: 9),
          _footer('GPSの誤差が30m以内になると判定する'),
        ];
      case MissionCardStatus.approaching:
        return [
          const SizedBox(height: 9),
          _distanceRow(),
          const SizedBox(height: 9),
          _footer('半径15m に入ると 特典 を1つ引ける'),
        ];
      case MissionCardStatus.arrived:
        return [
          const SizedBox(height: 9),
          const _Notice(text: 'まだ誰も取っていない', dot: true),
          const SizedBox(height: 9),
          _footer('判定範囲（半径15m）の中にいる'),
        ];
      case MissionCardStatus.takenByOther:
        final name = claimedByName;
        return [
          const SizedBox(height: 6),
          Text(
            name == null || name.isEmpty
                ? '先に取られた。次のミッションを待とう'
                : '$name が先に取った。次のミッションを待とう',
            style: const TextStyle(fontSize: 12, color: gameMuted),
          ),
        ];
      case MissionCardStatus.claimedByMe:
        final reward = mission.reward;
        return [
          const SizedBox(height: 6),
          if (reward != null)
            Row(
              children: [
                RewardTargetTag(target: reward.target),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reward.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: gameInk,
                    ),
                  ),
                ),
              ],
            )
          else
            const Text(
              '特典を引いています',
              style: TextStyle(fontSize: 12, color: gameMuted),
            ),
        ];
      case MissionCardStatus.approachInProgress:
        return const [
          SizedBox(height: 9),
          _ApproachGoal(),
          SizedBox(height: 9),
          Text(
            '捕まらない距離で。BLEが届くと捕まる',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: demonDeep,
            ),
          ),
        ];
      case MissionCardStatus.approachAchieved:
        return const [
          SizedBox(height: 9),
          _Notice(text: '達成した', icon: Icons.check_circle),
        ];
    }
  }

  Widget _distanceRow() {
    final distance = reading.distanceM;
    return Row(
      children: [
        const Icon(Icons.place, size: 18, color: missionDeep),
        const SizedBox(width: 7),
        Text(
          distance == null ? 'のこり --' : 'のこり ${formatMeters(distance)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: gameInk,
          ),
        ),
      ],
    );
  }

  Widget _footer(String left) {
    final accuracy = reading.accuracyM;
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(fontSize: 11, color: gameMuted),
          ),
        ),
        const Text('GPS ', style: TextStyle(fontSize: 11, color: gameMuted)),
        Text(
          accuracy == null ? '--' : '±${formatMeters(accuracy)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: gameInk,
          ),
        ),
      ],
    );
  }
}

/// 「Wi-Fi の反応を なし → あり に」の行。
class _ApproachGoal extends StatelessWidget {
  const _ApproachGoal();

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: gameMuted,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: gameBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text('Wi-Fi の反応を', style: label),
          _Tag(
            label: 'なし',
            background: Colors.white,
            foreground: gameMuted,
            bordered: true,
          ),
          Icon(Icons.arrow_forward, size: 16, color: missionDeep),
          _Tag(label: 'あり', background: missionSoft, foreground: missionInk),
          Text('に', style: label),
        ],
      ),
    );
  }
}

/// 淡いミッション色の囲み(「まだ誰も取っていない」など)。
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.icon, this.dot = false});

  final String text;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final leading = icon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: missionSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (dot)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: missionAccent,
                shape: BoxShape.circle,
              ),
            ),
          if (leading != null) Icon(leading, size: 16, color: missionInk),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: missionInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 丸いタグ。
class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
    this.bordered = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: bordered ? Border.all(color: gameBorder) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// 「鬼に効く」「自分に効く」のタグ。特典には必ず添える(特典カードと共通)。
class RewardTargetTag extends StatelessWidget {
  /// [target]に応じて文言と色を変える。
  const RewardTargetTag({super.key, required this.target, this.fontSize = 10});

  /// 誰に効くか。
  final RewardTarget target;

  /// 文字の大きさ。
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isDemon = target == RewardTarget.demon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDemon ? demonSoft : selfSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rewardTargetLabel(target),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: isDemon ? demonDeep : const Color(0xFF2F5FC4),
        ),
      ),
    );
  }
}

/// 「鬼に効く」「自分に効く」。
String rewardTargetLabel(RewardTarget target) => switch (target) {
  RewardTarget.demon => '鬼に効く',
  RewardTarget.self => '自分に効く',
};

/// 地図の下寄せに出す「特典を引く」ボタン(モック2)。押す場所は1か所で、
/// 高さは44px以上(58)にする。
class MissionClaimButton extends StatelessWidget {
  /// [onPressed]がnullの間は押せない(送信中など)。
  const MissionClaimButton({
    super.key,
    required this.onPressed,
    required this.isClaiming,
  });

  /// 押したとき。
  final VoidCallback? onPressed;

  /// 取り合いの送信中か。
  final bool isClaiming;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: missionDeep,
              foregroundColor: Colors.white,
              disabledBackgroundColor: missionDeep.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: isClaiming ? null : onPressed,
            icon: isClaiming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.card_giftcard),
            label: const Text('特典を引く'),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: gameBackground.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '引くと、その場で効果が出る',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: gameMuted),
          ),
        ),
      ],
    );
  }
}
