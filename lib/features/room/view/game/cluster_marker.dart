import 'package:flutter/material.dart';
import 'package:kakureru/features/map/repository/marker_cluster.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';

/// クラスタの内訳ラベルの高さ(論理px)。
const double kClusterLabelHeight = 22;

/// クラスタのラベルとの間隔(論理px)。
const double kClusterLabelGap = 4;

/// クラスタのマーカー全体の幅。「鬼 10 ・ 逃走者 10」でも収まる。
const double kClusterMarkerWidth = 168;

/// クラスタのマーカー全体の高さ(四角+間隔+ラベル)。
const double kClusterMarkerHeight =
    kClusterBoxSize + kClusterLabelGap + kClusterLabelHeight;

/// 四角の中心を実座標に合わせるためのalignment。考え方は
/// `markerIconCenterAlignment` と同じ(flutter_mapのalignmentは座標から
/// 見てwidgetを置く側の指定)。
const clusterMarkerAlignment = Alignment(
  0,
  (kClusterMarkerHeight / 2 - kClusterBoxSize / 2) / (kClusterMarkerHeight / 2),
);

const _boxBorder = Color(0xFF1B1B19);

/// ラベルの幅の見積もり(日本語12pxの太字を1文字12px+左右の余白)。
double clusterLabelWidthEstimate(String label) => label.length * 12.0 + 16;

/// 近い人をまとめた四角のマーカー。中央に人数、下に役割色の点、四角の
/// 下に内訳ラベルを出す。名前は出さない。
///
/// [labelShiftX]は、ラベルが画面端で切れないよう内側へ寄せる量。
class ClusterMarkerView extends StatelessWidget {
  /// [cluster]の内訳を描く。タップで[onTap]。
  const ClusterMarkerView({
    super.key,
    required this.cluster,
    required this.onTap,
    this.labelShiftX = 0,
  });

  /// 描くクラスタ。
  final MarkerCluster cluster;

  /// タップされたとき(一覧シートを開く)。
  final VoidCallback onTap;

  /// ラベルを横へ寄せる量(論理px)。
  final double labelShiftX;

  @override
  Widget build(BuildContext context) {
    final label = clusterBreakdownLabel(
      demons: cluster.demonCount,
      fugitives: cluster.fugitiveCount,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: kClusterBoxSize,
            height: kClusterBoxSize,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _boxBorder, width: 4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cluster.members.length}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1,
                    color: _boxBorder,
                  ),
                ),
                const SizedBox(height: 3),
                // 点は人数ぶん。10人でも幅(56)に収まるよう折り返す。
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final member in cluster.members)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: member.isDemon
                              ? colorForRole(UserRole.demon)
                              : colorForRole(UserRole.fugitive),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: kClusterLabelGap),
          Transform.translate(
            offset: Offset(labelShiftX, 0),
            child: Container(
              height: kClusterLabelHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _boxBorder,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一覧シートに並べる1人ぶん。
typedef ClusterSheetMember = ({
  String uid,
  String name,
  bool isDemon,

  /// 「鬼を選ぶ」の対象にできるか(相手の役割の人だけ)。
  bool selectable,
});

/// クラスタの中身を名前+役割で出すボトムシート。選べる人をタップすると
/// そのuidを返す。閉じたらnull。
Future<String?> showClusterSheet(
  BuildContext context, {
  required List<ClusterSheetMember> members,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ClusterSheet(members: members),
  );
}

/// [showClusterSheet]の中身。widgetテストで単体確認できるよう公開する。
class ClusterSheet extends StatelessWidget {
  /// [members]を並べる。
  const ClusterSheet({super.key, required this.members});

  /// 並べる人。
  final List<ClusterSheetMember> members;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'この近くにいる ${members.length} 人',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: gameInk,
              ),
            ),
            const SizedBox(height: 8),
            for (final member in members)
              InkWell(
                onTap: member.selectable
                    ? () => Navigator.of(context).pop(member.uid)
                    : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorForRole(
                            member.isDemon ? UserRole.demon : UserRole.fugitive,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: gameInk,
                          ),
                        ),
                      ),
                      Text(
                        member.isDemon ? '鬼' : '逃走者',
                        style: const TextStyle(fontSize: 13, color: gameMuted),
                      ),
                      if (member.selectable)
                        const Icon(Icons.chevron_right, color: gameMuted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
