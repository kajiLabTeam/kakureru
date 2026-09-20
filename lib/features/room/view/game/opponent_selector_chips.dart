import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// チップ1つの最小幅(論理px)。
///
/// Material Design のタップ領域の推奨最小サイズは48dpで、これを下回ると
/// 指で狙いにくくなる。チップはアバター(直径28)の下に名前と
/// Wi-Fi判定の2行を重ねるため、48dpちょうどだと名前がほぼ必ず
/// 省略記号だけになる。そこで、タップ領域の下限(48dp)に左右の余白ぶんを
/// 足した64dpを最小幅として扱う。人数が増えてこの幅を確保できなく
/// なったら、均等割りをやめて横スクロールに切り替える(issue #67)。
const opponentChipMinWidth = 64.0;

/// チップ同士の隙間(論理px)。均等割り・横スクロールのどちらでも同じ値を
/// 使い、「収まるか」の判定にもこの値を含める。
const opponentChipSpacing = 6.0;

/// [count] 人ぶんのチップを最小幅で並べるのに必要な横幅を返す。
///
/// 「均等割りのままで良いか、横スクロールに切り替えるか」の判定に使う
/// (テストからも同じ式を参照できるよう関数として切り出している)。
double opponentChipsRequiredWidth(int count) {
  if (count <= 0) return 0;
  return count * opponentChipMinWidth + (count - 1) * opponentChipSpacing;
}

/// 対象役割の相手を選ぶチップ一覧(UI改修モック2a-03
/// 「逃走者を選んで詳細を見る」)。タップで詳細カードに出す
/// 相手を切り替えられる。選択中の相手は本人の役割色の枠+薄い背景で
/// 強調し、Wi-Fi判定が「検知なし」の相手は薄く表示して目立たなくする。
///
/// 人数への対応(issue #67): 全員が[opponentChipMinWidth]以上の幅で
/// 収まるときは、モック2a-03どおりの均等割り(`Expanded`)で横幅いっぱいに
/// 広げる。収まらないときだけ横スクロールに切り替え、各チップを
/// 最小幅で固定する。少人数(モックが想定している3人程度)での見た目は
/// 従来のまま変わらない。
class OpponentSelectorChips extends StatelessWidget {
  /// すべての引数はGamePageが計算して渡す(このウィジェットはproviderを
  /// 一切読まない)。
  const OpponentSelectorChips({
    super.key,
    required this.roster,
    required this.entries,
    required this.selectedUid,
    required this.onSelect,
  });

  /// チップに並べる相手(自分と逆の役割で、いま見えている人だけ)。
  final List<RoomUser> roster;

  /// 各チップにWi-Fiの3段階判定を出すための一覧。
  final List<WifiProximityEntry> entries;

  /// 選択中の相手のuid。未選択ならnull。
  final String? selectedUid;

  /// チップがタップされたときに、そのuidを返す。
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 最小幅で並べても横幅に収まるなら、これまでどおり均等割りにする。
        // maxWidthが無限(横方向に制約が無い場所に置かれた場合)のときも
        // この分岐に入るため、挙動は従来と変わらない。
        final fitsEvenly =
            opponentChipsRequiredWidth(roster.length) <= constraints.maxWidth;
        if (fitsEvenly) {
          return Row(
            children: [
              for (var i = 0; i < roster.length; i++) ...[
                Expanded(child: _buildChip(roster[i])),
                if (i != roster.length - 1)
                  const SizedBox(width: opponentChipSpacing),
              ],
            ],
          );
        }

        // 収まらないときは、1つあたりを細くしていく(=タップできなくなる)
        // のではなく最小幅で固定し、横スクロールで全員に届くようにする。
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < roster.length; i++) ...[
                SizedBox(
                  width: opponentChipMinWidth,
                  child: _buildChip(roster[i]),
                ),
                if (i != roster.length - 1)
                  const SizedBox(width: opponentChipSpacing),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(RoomUser user) {
    final level = levelFor(entries, user.id);
    final color = colorForRole(user.role);
    final isSelected = user.id == selectedUid;
    final isNotDetected = level == null || level == ProximityLevel.notDetected;

    return Opacity(
      opacity: isNotDetected ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: () => onSelect(user.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? color.withValues(alpha: 0.07) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color,
                child: Text(
                  avatarInitial(user.displayName),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                user.displayName,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isSelected ? appInk : appMuted,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                _levelLabel(level),
                style: TextStyle(fontSize: 10, color: _levelColor(level)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel(ProximityLevel? level) {
    switch (level) {
      case ProximityLevel.close:
        return '近い';
      case ProximityLevel.far:
        return '遠い';
      case ProximityLevel.notDetected:
      case null:
        return '検知なし';
    }
  }

  /// 近接度に応じた文字色。「近い」だけ強調色(赤)にし、それ以外は
  /// 目立たないグレーにする(UI改修モックの強弱付けに合わせる)。
  Color _levelColor(ProximityLevel? level) {
    return level == ProximityLevel.close
        ? const Color(0xFFE5484D)
        : const Color(0xFFAAAAAA);
  }
}
