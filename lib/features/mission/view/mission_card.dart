import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
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

  /// 判定範囲に入った(2回続けて範囲内)。「ごほうびガチャを引く」を出す。
  arrived,

  /// 一度着いたが、いまは範囲の外にいる。戻れば引ける。
  leftRange,

  /// 地点がすべてほかの人に取られた。
  takenByOther,

  /// 自分が取った。
  claimedByMe,

  /// 自分が取ったが、ごほうびの書き込みが済んでいない(取った直後に通信が
  /// 切れた等)。「ごほうびを受け取る」でやり直せる。
  claimedWithoutReward,
}

/// カードの状態を決める。
///
/// 自分が取ったか・すべて取られたかを最初に見る(取られた後に位置の話を
/// 出しても意味が無いため)。次に権限、到着、GPSの順。[reading]は
/// いちばん近い空いている地点([nearestOpenSpot])との位置関係で、到着は
/// その地点に対するもの([MissionProgress.spotId]が[targetSpotId]と同じ)
/// だけを見る。到着した後は、いまの読み取りで引けるかを
/// [canClaimAccessPoint]で決める(範囲の外に出たら引けない。GPSが弱く
/// なっただけなら引ける)。
MissionCardStatus missionCardStatusOf({
  required Mission mission,
  required String? myUid,
  required LocationFailure locationFailure,
  required AccessPointReading reading,
  required MissionProgress progress,
  required String? targetSpotId,
}) {
  if (spotClaimedBy(mission, myUid) case final mine?) {
    return mine.reward == null
        ? MissionCardStatus.claimedWithoutReward
        : MissionCardStatus.claimedByMe;
  }
  if (openSpots(mission).isEmpty || mission.finishedAt != null) {
    return MissionCardStatus.takenByOther;
  }
  if (locationFailure == LocationFailure.locationPermission) {
    return MissionCardStatus.needsLocationPermission;
  }
  if (progress.missionId == mission.id &&
      targetSpotId != null &&
      progress.spotId == targetSpotId &&
      progress.arrival.arrived) {
    if (canClaimAccessPoint(arrival: progress.arrival, reading: reading)) {
      return MissionCardStatus.arrived;
    }
    if (reading.fix == AccessPointFix.outside) {
      return MissionCardStatus.leftRange;
    }
  }
  return switch (reading.fix) {
    AccessPointFix.noFix => MissionCardStatus.locating,
    AccessPointFix.weakGps => MissionCardStatus.weakGps,
    AccessPointFix.outside ||
    AccessPointFix.inside => MissionCardStatus.approaching,
  };
}

/// 「半径15m」の「15m」。
String get _radiusLabel => formatMeters(accessPointRadiusM);

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
    required this.expanded,
    required this.onToggleExpanded,
    this.myReward,
  });

  /// いま受けているミッション。
  final Mission mission;

  /// カードの状態。
  final MissionCardStatus status;

  /// いちばん近い空いている地点との位置関係(のこり N m・GPS ±N m)。
  final AccessPointReading reading;

  /// 期限までの残り(ミリ秒)。
  final int remainingMillis;

  /// 開いている(本文まで出す)か、見出しだけに畳んでいるか。畳む/開くの
  /// 状態自体はGamePageのhooksが持つ(issue #155。地図を隠す面積を減らす)。
  final bool expanded;

  /// 見出しをタップしたとき(畳む/開くを切り替える)。
  final VoidCallback onToggleExpanded;

  /// 自分が引いたごほうび([MissionCardStatus.claimedByMe]のとき)。
  final RewardType? myReward;

  @override
  Widget build(BuildContext context) {
    final highlighted = status == MissionCardStatus.arrived;
    if (!expanded) return _collapsed(highlighted: highlighted);
    // カードのどこを1回タップしても、左上の旗のマークへ畳む(issue #155の
    // 追加要望)。カードの中に押せる部品は無いので、全体で受けてよい。
    return Semantics(
      button: true,
      label: 'ミッションをたたむ',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleExpanded,
        child: _expandedCard(highlighted: highlighted),
      ),
    );
  }

  Widget _expandedCard({required bool highlighted}) {
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
          if (expanded) ...[
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
        ],
      ),
    );
  }

  Widget _header() {
    final urgent = remainingMillis < missionLastMinuteWarning.inMilliseconds;
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
          label: '先着${mission.spots.length}人',
          background: missionSoft,
          foreground: missionInk,
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
        const SizedBox(width: 6),
        // 畳めることが分かるように「−」を出しておく(押せるのはカード全体)。
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: missionSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.remove, size: 18, color: missionInk),
        ),
      ],
    );
  }

  /// 畳んだときの、左上の旗のマーク。タップで開き直す。
  ///
  /// 着いたとき([MissionCardStatus.arrived])は縁を色付きにして、畳んだ
  /// ままでも気づけるようにする。
  Widget _collapsed({required bool highlighted}) {
    return Align(
      alignment: Alignment.centerLeft,
      heightFactor: 1,
      child: Semantics(
        button: true,
        label: 'ミッションを開く',
        child: Material(
          color: missionDeep,
          elevation: 6,
          shadowColor: const Color(0x401B1B19),
          shape: CircleBorder(
            side: highlighted
                ? const BorderSide(color: missionAccent, width: 3)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onToggleExpanded,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.flag, size: 22, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  String _title() => switch (status) {
    MissionCardStatus.needsLocationPermission => '位置情報の許可が必要',
    MissionCardStatus.arrived => 'アクセスポイントに着いた',
    MissionCardStatus.takenByOther => 'ほかの人に取られた',
    MissionCardStatus.claimedByMe => 'ごほうびを引いた',
    MissionCardStatus.claimedWithoutReward => 'ごほうびをまだ受け取っていない',
    MissionCardStatus.leftRange => '判定範囲の外に出た',
    MissionCardStatus.weakGps => 'GPSの電波が弱い',
    MissionCardStatus.locating ||
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
          _distanceRow(),
          const SizedBox(height: 9),
          _footer('半径$_radiusLabel に入ると ごほうび を1つ引ける'),
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
          _footer('GPSの誤差が${formatMeters(maxUsableAccuracyM)}以内になると判定する'),
        ];
      case MissionCardStatus.approaching:
        return [
          const SizedBox(height: 9),
          _distanceRow(),
          const SizedBox(height: 9),
          _footer('半径$_radiusLabel に入ると ごほうび を1つ引ける'),
        ];
      case MissionCardStatus.arrived:
        return [
          const SizedBox(height: 9),
          const _Notice(text: 'まだ誰も取っていない', dot: true),
          const SizedBox(height: 9),
          _distanceRow(),
          const SizedBox(height: 9),
          _footer('判定範囲（半径$_radiusLabel）の中にいる'),
        ];
      case MissionCardStatus.leftRange:
        return [
          const SizedBox(height: 9),
          _distanceRow(),
          const SizedBox(height: 9),
          _footer('半径$_radiusLabel に戻ると ごほうび を引ける'),
        ];
      case MissionCardStatus.claimedWithoutReward:
        return const [
          SizedBox(height: 6),
          Text(
            '先に取れたが、ごほうびの書き込みが終わっていない。下のボタンで受け取れる',
            style: TextStyle(fontSize: 12, height: 1.5, color: gameMuted),
          ),
        ];
      case MissionCardStatus.takenByOther:
        return const [
          SizedBox(height: 6),
          Text(
            'アクセスポイントはすべて取られた。次のミッションを待とう',
            style: TextStyle(fontSize: 12, color: gameMuted),
          ),
        ];
      case MissionCardStatus.claimedByMe:
        final reward = myReward;
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
              'ごほうびを引いています',
              style: TextStyle(fontSize: 12, color: gameMuted),
            ),
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
          distance == null
              ? '近いのは のこり --'
              : '近いのは のこり ${formatMeters(distance)}',
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
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
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

/// 「鬼をジャマする」「自分がトクする」のタグ。ごほうびには必ず添える
/// (ごほうびのカードと共通)。
class RewardTargetTag extends StatelessWidget {
  /// [target]に応じて文言と色を変える。
  const RewardTargetTag({super.key, required this.target, this.fontSize = 10});

  /// 誰に効くか。
  final RewardTarget target;

  /// 文字の大きさ。
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (target) {
      RewardTarget.demon => (demonSoft, demonDeep),
      RewardTarget.self => (selfSoft, const Color(0xFF2F5FC4)),
      RewardTarget.selfMiss => (missSoft, missDeep),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rewardTargetLabel(target),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// 「鬼をジャマする」「自分がトクする」「ハズレ」。
String rewardTargetLabel(RewardTarget target) => switch (target) {
  RewardTarget.demon => '鬼をジャマする',
  RewardTarget.self => '自分がトクする',
  RewardTarget.selfMiss => 'ハズレ',
};

/// 地図の下寄せに出す「ごほうびガチャを引く」ボタン(モック2)。押す場所は1か所で、
/// 高さは44px以上(58)にする。
class MissionClaimButton extends StatelessWidget {
  /// [onPressed]がnullの間は押せない(送信中など)。
  const MissionClaimButton({
    super.key,
    required this.onPressed,
    required this.isClaiming,
    this.label = 'ごほうびガチャを引く',
  });

  /// ボタンの文言。取った後にごほうびの書き込みをやり直すときは
  /// 「ごほうびを受け取る」にする。
  final String label;

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
            label: Text(label),
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

/// ミッションのデバッグ用のボタン(「着いたことにする」「ミッションを
/// いますぐ出す」)を出してよいか。
///
/// `flutter run --dart-define=DEBUG_MISSION=true` で起動したときだけtrue
/// (`./scripts/run.sh --mission-debug`)。リリースビルドでは定義があっても
/// 必ずfalse(本番で距離の判定や出す時刻を飛ばせない)。
const bool debugMissionArrivalEnabled =
    !kReleaseMode && bool.fromEnvironment('DEBUG_MISSION');

/// カードの下に出す、デバッグ用の「着いたことにする」(点線の枠)。
///
/// 距離とGPSの精度の判定だけを飛ばし、取り合いのトランザクションは
/// ふつうに走らせる(2台で同じ地点を同時に押す試験ができる)。
/// [enabled]がfalseなら何も描かない。既定は[debugMissionArrivalEnabled]。
class MissionDebugArrivalButton extends StatelessWidget {
  /// [onPressed]がnullの間は押せない(送信中など)。
  const MissionDebugArrivalButton({
    super.key,
    required this.onPressed,
    this.enabled = debugMissionArrivalEnabled,
  });

  /// 押したとき。
  final VoidCallback? onPressed;

  /// 出すか。テストからだけ差し替える。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return _DebugDashedButton(label: '着いたことにする', onPressed: onPressed);
  }
}

/// ミッションが出ていないときにカードの位置へ出す、デバッグ用の
/// 「ミッションをいますぐ出す」(点線の枠)。押したら
/// [showMissionDebugRoundPicker]で回を選ばせる。
/// [enabled]がfalseなら何も描かない。既定は[debugMissionArrivalEnabled]。
class MissionDebugCreateButton extends StatelessWidget {
  /// [onPressed]がnullの間は押せない(書き込み中など)。
  const MissionDebugCreateButton({
    super.key,
    required this.onPressed,
    this.enabled = debugMissionArrivalEnabled,
  });

  /// 押したとき。
  final VoidCallback? onPressed;

  /// 出すか。テストからだけ差し替える。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return _DebugDashedButton(label: 'ミッションをいますぐ出す', onPressed: onPressed);
  }
}

/// デバッグ用に、何回目のミッションを出すかを選ばせる。選ばなければnull。
///
/// 回ごとに地点の数が違う([debugMissionRoundChoices])ので、それも並べる。
Future<int?> showMissionDebugRoundPicker(
  BuildContext context, {
  required int fugitiveCount,
}) => showModalBottomSheet<int>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'どのミッションを出す?(デバッグ)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        for (final choice in debugMissionRoundChoices(
          fugitiveCount: fugitiveCount,
        ))
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text('${choice.round}回目のミッション'),
            subtitle: Text('地点 ${choice.spotCount}か所'),
            onTap: () => Navigator.of(context).pop(choice.round),
          ),
      ],
    ),
  ),
);

/// デバッグ用のボタンの見た目(点線の枠・虫のアイコン・高さ44)。
class _DebugDashedButton extends StatelessWidget {
  const _DebugDashedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(color: missionInk),
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.bug_report_outlined,
                  size: 18,
                  color: missionInk,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: missionInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 角丸の点線の枠。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dash),
          paint,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
