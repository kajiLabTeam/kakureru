import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// 横に見せるチップの枚数。
///
/// 1枚ぶんに満たない端数(0.8枚)を残すことで、**2枚目が必ず右端で見切れる**。
/// 以前は「収まるときは均等割り、溢れたら横スクロール」にしていたが
/// (issue #67 / PR #68)、収まっている間はスクロールできること自体が
/// 分からず、人数が増えた瞬間に見た目と操作が変わっていた(issue #76)。
const double opponentChipsVisibleCount = 1.8;

/// チップ同士の間隔。
const double opponentChipSpacing = 8;

/// 横幅が測れないとき(親が横方向に無制限)に使う幅。
///
/// GamePageでは左右16dpの余白を持つColumnの中なので通常は通らない。
const double opponentChipFallbackWidth = 168;

/// 使える横幅と人数から、チップ1枚の幅を決める。
///
/// 相手が1人のときだけ全幅にする。送る先が無いのに半端な幅のカードが左に
/// 浮いて右が空くと、壊れているようにしか見えないため。「常に固定幅」から
/// 外れる唯一の例外。
double opponentChipWidthFor({
  required double availableWidth,
  required int count,
}) {
  if (!availableWidth.isFinite) return opponentChipFallbackWidth;
  if (count <= 1) return availableWidth;
  return (availableWidth - opponentChipSpacing) / opponentChipsVisibleCount;
}

/// チップに出す1行の要約。「近い・上かも」「遠い・同じ高さ」など。
///
/// 上下が出せないとき([verticalPosition]がnull。気圧センサー非対応・
/// 未キャリブレーション・まだ相手の気圧が届いていない)はWi-Fi側だけを返す。
/// GamePageが渡す`visibleVerticalPositions`はそれらの場合に空になるので、
/// 別途ゲート条件を渡す必要はない。
String opponentChipSummary({
  required ProximityLevel? level,
  required RelativeVerticalPosition? verticalPosition,
}) {
  final String wifi;
  switch (level) {
    case ProximityLevel.close:
      wifi = '近い';
    case ProximityLevel.far:
      wifi = '遠い';
    case ProximityLevel.notDetected:
    case null:
      wifi = '検知なし';
  }

  if (verticalPosition == null) return wifi;

  final String vertical;
  switch (relativeHeightOf(verticalPosition.deltaMeters)) {
    case RelativeHeight.above:
      vertical = '上かも';
    case RelativeHeight.below:
      vertical = '下かも';
    case RelativeHeight.same:
      vertical = '同じ高さ';
  }
  return '$wifi・$vertical';
}

/// 相手を1人選ぶための横並びのチップ(UI改修モック2a-03)。
///
/// **常に固定幅の横スクロール**で、2枚目が右端で見切れる
/// ([opponentChipsVisibleCount])。人数に関わらず見た目と操作が変わらず、
/// 「横に送れる」ことが一目で分かる。
///
/// アバターは出さない。28dpの丸に頭文字1文字を出しても誰なのかは名前で
/// しか分からず、そのぶん名前と要約の文字を小さくしていたため(issue #76)。
class OpponentSelectorChips extends StatelessWidget {
  /// すべての引数はGamePageが計算して渡す(このウィジェットはproviderを
  /// 一切読まない)。
  const OpponentSelectorChips({
    super.key,
    required this.roster,
    required this.entries,
    required this.verticalPositions,
    required this.selectedUid,
    required this.onSelect,
  });

  /// 並べる相手の一覧(自分と逆の役割で、いま見えている人)。
  final List<RoomUser> roster;

  /// Wi-Fiの3段階判定。載っていない相手は「検知なし」として出す。
  final List<WifiProximityEntry> entries;

  /// 気圧による上下判定。載っていない相手は上下を出さない。
  final List<RelativeVerticalPosition> verticalPositions;

  /// いま選ばれている相手のuid。未選択ならnull。
  final String? selectedUid;

  /// チップがタップされたときに呼ぶ。
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = opponentChipWidthFor(
          availableWidth: constraints.maxWidth,
          count: roster.length,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < roster.length; i++) ...[
                if (i > 0) const SizedBox(width: opponentChipSpacing),
                SizedBox(width: width, child: _buildChip(roster[i])),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(RoomUser user) {
    final isSelected = user.id == selectedUid;
    final color = colorForRole(user.role);
    final level = levelFor(entries, user.id);
    final isNotDetected = level == null || level == ProximityLevel.notDetected;

    return Opacity(
      opacity: isNotDetected ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: () => onSelect(user.id),
        // 枠だけで塗りの無い(未選択の)チップでも、余白を含めた全体が
        // タップに反応するようにする。
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : appFaintBorder,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? color.withValues(alpha: 0.07) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 未選択でも名前は濃いまま出す。選ばれているかどうかは枠と
              // 塗りで示す(名前を薄くすると、そもそも誰がいるのか読めない)。
              Text(
                user.displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  color: appInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                opponentChipSummary(
                  level: level,
                  verticalPosition: verticalFor(verticalPositions, user.id),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: _levelColor(level)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「近い」だけ強調色(赤)にし、それ以外は落ち着いた色にする
  /// (詳細カードと同じ強弱付け)。
  Color _levelColor(ProximityLevel? level) {
    return level == ProximityLevel.close
        ? const Color(0xFFE5484D)
        : const Color(0xFFAAAAAA);
  }
}
