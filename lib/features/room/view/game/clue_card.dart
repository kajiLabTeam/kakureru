import 'package:flutter/material.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/room/model/clue_floor_math.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

/// 手がかりカードの判定(近さ)。
enum ClueVerdict {
  /// 近いかも。
  close,

  /// 遠いかも。
  far,

  /// まだ分からない(同じWi-Fiが届いていない)。
  unknown,
}

/// Wi-Fiの3段階判定[level]とメーターの値[meter]から判定を決める。
///
/// メーターが出せない(共通APが無い)ときは、判定が何であっても
/// 「まだ分からない」にする。メーターと判定が食い違って見えないようにするため。
ClueVerdict clueVerdictOf({
  required ProximityLevel? level,
  required double? meter,
}) {
  if (meter == null) return ClueVerdict.unknown;
  switch (level) {
    case ProximityLevel.close:
      return ClueVerdict.close;
    case ProximityLevel.far:
      return ClueVerdict.far;
    case ProximityLevel.notDetected:
    case null:
      return ClueVerdict.unknown;
  }
}

/// 判定の見出し(チップにも同じ言葉を出す)。
String clueVerdictLabel(ClueVerdict verdict) {
  switch (verdict) {
    case ClueVerdict.close:
      return '近いかも';
    case ClueVerdict.far:
      return '遠いかも';
    case ClueVerdict.unknown:
      return 'まだ分からない';
  }
}

/// 判定の下に添える一言。遠いときは傾向に応じて次の一歩を示す。
String clueVerdictHint(ClueVerdict verdict, ClueTrend trend) {
  switch (verdict) {
    case ClueVerdict.close:
      return 'このあたりを探してみよう';
    case ClueVerdict.unknown:
      return '同じWi-Fiが届いていません';
    case ClueVerdict.far:
      switch (trend) {
        case ClueTrend.closer:
          return '方向は合っている。このまま進もう';
        case ClueTrend.farther:
          return '反対方向へ行ってみよう';
        case ClueTrend.unchanged:
          return '歩いて、近づくか確かめよう';
      }
  }
}

/// 傾向タグの文言。
String clueTrendLabel(ClueTrend trend) {
  switch (trend) {
    case ClueTrend.closer:
      return '近づいた';
    case ClueTrend.farther:
      return '離れた';
    case ClueTrend.unchanged:
      return '変わらない';
  }
}

/// 手がかりカードの「高さ」欄の状態。
enum ClueHeightStatus {
  /// 自分の気圧センサーを確認中。
  checking,

  /// 自分の端末に気圧センサーが無い。
  unsupported,

  /// 自分がキャリブレーションしていない(その場で直せる)。
  notCalibrated,

  /// 相手の高さがまだ届いていない。
  waiting,

  /// 高さを出せる。
  ready,
}

/// 高さ欄の状態を決める。センサー → キャリブレーション → 相手の値の順に見る。
ClueHeightStatus clueHeightStatusOf({
  required PressureSensorAvailability availability,
  required bool isCalibrated,
  required bool hasOpponentHeight,
}) {
  switch (availability) {
    case PressureSensorAvailability.unavailable:
      return ClueHeightStatus.unsupported;
    case PressureSensorAvailability.checking:
      return ClueHeightStatus.checking;
    case PressureSensorAvailability.available:
      if (!isCalibrated) return ClueHeightStatus.notCalibrated;
      if (!hasOpponentHeight) return ClueHeightStatus.waiting;
      return ClueHeightStatus.ready;
  }
}

/// 選んだ相手1人ぶんの手がかりカード(ゲーム画面モック C1〜C5)。
///
/// 上から「判定+傾向」「近さメーター+電波の一致」「高さ」の順に並べる。
/// 共通のWi-Fiが無いとき(C3)はメーターの代わりに次の行動を書いた枠を出す。
/// 高さが出せないとき(C4/C5ほか)は、理由と、直せるならその場のボタンを出す。
///
/// 値の計算はすべて呼び出し側(GamePage)が行い、このウィジェットは
/// providerを読まない。
class ClueCard extends StatelessWidget {
  /// 手がかりカードを作る。
  const ClueCard({
    required this.name,
    required this.role,
    required this.verdict,
    required this.meter,
    required this.matchCount,
    required this.trend,
    required this.heightStatus,
    required this.opponentLowerHPa,
    required this.onHelp,
    this.onCalibrate,
    this.isCalibrating = false,
    super.key,
  });

  /// 相手の表示名。
  final String name;

  /// 相手の役割。点やメーターの色に使う。
  final UserRole? role;

  /// 近さの判定。
  final ClueVerdict verdict;

  /// 近さメーターの値(0〜100)。[verdict]がunknownなら使わない。
  final double? meter;

  /// 電波の一致数(0〜[signalMatchCount])。
  final int matchCount;

  /// 数秒前と比べた傾向。
  final ClueTrend trend;

  /// 高さ欄の状態。
  final ClueHeightStatus heightStatus;

  /// 相手の気圧が自分よりどれだけ低いか(hPa)。[heightStatus]がreadyの
  /// ときだけ使う。
  final double? opponentLowerHPa;

  /// 「?」(手がかりの見方)が押されたとき。
  final VoidCallback onHelp;

  /// 「いま合わせる」が押されたとき。nullなら押せない(準備中など)。
  final VoidCallback? onCalibrate;

  /// キャリブレーション中か。
  final bool isCalibrating;

  @override
  Widget build(BuildContext context) {
    final accent = opponentAccentOf(role);
    final showMeter = verdict != ClueVerdict.unknown;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: gameBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(accent),
          Padding(
            // 見出し行だけは「?」のタップ領域(44dp)のため右と上の余白を
            // 詰めてある。残りの行はモックどおり右14dpに揃える。
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _verdictRow(accent, showTrend: showMeter),
                const SizedBox(height: 10),
                if (showMeter)
                  _meter(accent)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: gameHint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '建物に近づくと手がかりが出ます。まずは地図のピンを目指してください。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: gameInkSoft,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _height(accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(OpponentAccent accent) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: accent.pin, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$name の手がかり',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: gameInk,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: '手がかりの見方',
          child: GestureDetector(
            key: const ValueKey('clueHelpButton'),
            onTap: onHelp,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: gameBorder),
                  ),
                  child: const Text(
                    '?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: gameMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _verdictRow(OpponentAccent accent, {required bool showTrend}) {
    final (
      IconData icon,
      Color circle,
      Color iconColor,
      Color textColor,
    ) = switch (verdict) {
      ClueVerdict.close => (
        Icons.track_changes,
        accent.tint,
        accent.ink,
        accent.ink,
      ),
      ClueVerdict.far => (Icons.adjust, gameTrack, gameMuted, gameInkSoft),
      ClueVerdict.unknown => (
        Icons.wifi_off,
        gameTrack,
        gameFaint,
        gameMuted,
      ),
    };
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
          child: Icon(icon, size: 24, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clueVerdictLabel(verdict),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                clueVerdictHint(verdict, trend),
                style: const TextStyle(fontSize: 11, color: gameMuted),
              ),
            ],
          ),
        ),
        if (showTrend) ...[const SizedBox(width: 10), _trendTag(accent)],
      ],
    );
  }

  Widget _trendTag(OpponentAccent accent) {
    final (IconData icon, Color background, Color color) = switch (trend) {
      ClueTrend.closer => (Icons.arrow_upward, accent.tint, accent.ink),
      ClueTrend.farther => (Icons.arrow_downward, gameTrack, gameMuted),
      ClueTrend.unchanged => (Icons.horizontal_rule, gameTrack, gameMuted),
    };
    return Container(
      key: const ValueKey('clueTrendTag'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            clueTrendLabel(trend),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meter(OpponentAccent accent) {
    final fraction = ((meter ?? 0) / 100).clamp(0.0, 1.0);
    const caption = TextStyle(fontSize: 10, color: gameMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 12,
            color: gameTrack,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              key: const ValueKey('clueMeterFill'),
              widthFactor: fraction,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.pin,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('遠い', style: caption),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('電波の一致', style: caption),
                for (var i = 0; i < signalMatchCount; i++) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < matchCount ? accent.pin : gameEmptyDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const SizedBox(width: 5),
                Text('$matchCount / $signalMatchCount', style: caption),
              ],
            ),
            const Text('近い', style: caption),
          ],
        ),
      ],
    );
  }

  Widget _height(OpponentAccent accent) {
    switch (heightStatus) {
      case ClueHeightStatus.ready:
        return _heightPanel(accent, opponentLowerHPa ?? 0);
      case ClueHeightStatus.notCalibrated:
        return _calibrateStrip();
      case ClueHeightStatus.unsupported:
        return _heightNotice(
          icon: Icons.layers_clear_outlined,
          title: 'この端末では高さが分かりません',
          subtitle: '上のメーターだけで追えます',
        );
      case ClueHeightStatus.checking:
        return _heightNotice(
          icon: Icons.hourglass_empty,
          title: '高さを確認しています',
          subtitle: 'しばらくすると出ます',
        );
      case ClueHeightStatus.waiting:
        return _heightNotice(
          icon: Icons.sync,
          title: '相手の高さがまだ届いていません',
          subtitle: '届くまでは上のメーターで追えます',
        );
    }
  }

  Widget _heightPanel(OpponentAccent accent, double hpa) {
    final floors = floorsOf(hpa);
    // 上端(+3階)で3、下端(-3階)で61。同じ高さのとき自分の線(37〜40)と
    // ほぼ重なる位置に来る。
    final dotTop = (61 - floorDotFraction(floors) * 58).clamp(0.0, 60.0);
    const barLabel = TextStyle(fontSize: 8, color: gameFaint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: gameSoftBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            key: const ValueKey('clueHeightBar'),
            width: 34,
            height: 76,
            decoration: BoxDecoration(
              color: gameTrack,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 4,
                  child: Text(
                    '上',
                    textAlign: TextAlign.center,
                    style: barLabel,
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 3,
                  child: Text(
                    '下',
                    textAlign: TextAlign.center,
                    style: barLabel,
                  ),
                ),
                Positioned(
                  left: 3,
                  top: 37,
                  child: Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: selfColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('clueHeightDot'),
                  left: 9,
                  top: dotTop,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accent.pin,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  floorHeadline(floors),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: gameInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  floorActionHint(floors),
                  style: const TextStyle(fontSize: 11, color: gameMuted),
                ),
                const SizedBox(height: 3),
                Text(
                  pressureDetailText(name, hpa),
                  style: const TextStyle(fontSize: 10, color: gameFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calibrateStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: gameNoticeSoftBackground,
        border: Border.all(color: gameNoticeBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '高さはまだ分かりません',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: gameNoticeInk,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '開始前の高さ合わせをしていません',
                  style: TextStyle(fontSize: 10, color: gameNoticeSubInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          FilledButton(
            onPressed: isCalibrating ? null : onCalibrate,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              backgroundColor: gameNoticeAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: gameNoticeAccent.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: isCalibrating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('いま合わせる'),
          ),
        ],
      ),
    );
  }

  Widget _heightNotice({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: gameHint,
        border: Border.all(color: gameSoftBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: gameSelected,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: gameFaint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: gameInkSoft,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: gameMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
