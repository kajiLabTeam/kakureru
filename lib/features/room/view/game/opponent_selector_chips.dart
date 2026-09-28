import 'package:flutter/material.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
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

/// チップに出す近さの一言。「近いかも」「遠いかも」「まだ分からない」。
///
/// 高さは選んだ相手の手がかりカードにだけ出し、チップには出さない
/// (ゲーム画面モックのチップは近さだけ)。Wi-Fiの判定はどれも推定なので
/// 手がかりカードと同じく「〜かも」と言い切らない形にする。
String opponentChipStatus(ProximityLevel? level) {
  switch (level) {
    case ProximityLevel.close:
      return '近いかも';
    case ProximityLevel.far:
      return '遠いかも';
    case ProximityLevel.notDetected:
    case null:
      return 'まだ分からない';
  }
}

/// チップ1枚の最低の高さ。タップ領域44dpを確保する。
const double opponentChipMinHeight = 44;

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
    required this.roster,
    required this.entries,
    required this.selectedUid,
    required this.onSelect,
    this.leadingLabel,
    super.key,
  });

  /// 並べる相手の一覧(自分と逆の役割で、いま見えている人)。
  final List<RoomUser> roster;

  /// Wi-Fiの3段階判定。載っていない相手は「検知なし」として出す。
  final List<WifiProximityEntry> entries;

  /// いま選ばれている相手のuid。未選択ならnull。
  final String? selectedUid;

  /// チップがタップされたときに呼ぶ。
  final ValueChanged<String> onSelect;

  /// チップ列の左に出す小さな見出し(「鬼を選ぶ」など)。nullなら出さない。
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    final label = leadingLabel;
    final chips = _buildChips();
    if (label == null) return chips;
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, height: 1.3, color: gameMuted),
        ),
        const SizedBox(width: opponentChipSpacing),
        Expanded(child: chips),
      ],
    );
  }

  Widget _buildChips() {
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
    final accent = opponentAccentOf(user.role);
    final level = levelFor(entries, user.id);

    return GestureDetector(
      onTap: () => onSelect(user.id),
      // 枠だけで塗りの無い(未選択の)チップでも、余白を含めた全体が
      // タップに反応するようにする。
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: opponentChipMinHeight),
        // 枠の太さが変わっても中身が動かないよう、選択時は1dpぶん余白を削る。
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 9 : 10,
          vertical: isSelected ? 5 : 6,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? accent.border : gameBorder,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? accent.chipTint : Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 未選択でも名前は濃いまま出す。選ばれているかどうかは枠と
            // 塗りで示す(名前を薄くすると、そもそも誰がいるのか読めない)。
            Text(
              user.displayName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                color: gameInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              opponentChipStatus(level),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? accent.ink : gameMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
