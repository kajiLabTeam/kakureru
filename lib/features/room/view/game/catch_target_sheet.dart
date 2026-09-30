import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/room/catch_rules.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

const _fugitiveColor = Color(0xFF4A9C5D);
const _fugitiveSurface = Color(0xFF3A7F4A);
const _selectedBackground = Color(0xFFEFF6F0);
const _handleColor = Color(0xFFDAD6CD);

/// 選択シートに並べる逃走者1人ぶん。
typedef CatchCandidate = ({String uid, String name});

/// 選択シートで確定した内容。`indoor`は「屋内で捕まえた」を押したか。
typedef CatchTargetChoice = ({String uid, bool indoor});

/// 「誰を捕まえた？」「どこで捕まえた？」を選ぶボトムシート(issue #140)。
///
/// [candidates]には3m以内にいる逃走者だけを渡すこと(鬼は含めない。
/// `fugitivesWithinCatchRange`)。1人だけなら最初から選んでおく。
/// 「やめる」・シートの外のタップではnullを返す。
Future<CatchTargetChoice?> showCatchTargetSheet(
  BuildContext context, {
  required List<CatchCandidate> candidates,
}) {
  return showModalBottomSheet<CatchTargetChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => CatchTargetSheet(candidates: candidates),
  );
}

/// [showCatchTargetSheet]の中身。widgetテストで単体確認できるよう公開する。
class CatchTargetSheet extends HookWidget {
  /// [candidates]は3m以内にいる逃走者(近い順)。
  const CatchTargetSheet({super.key, required this.candidates});

  /// 選べる相手。
  final List<CatchCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    // 選択中の相手はシートが閉じたら消えてよい一時状態なのでhooksで持つ。
    final selectedUid = useState<String?>(
      preselectedCatchTarget([for (final c in candidates) c.uid]),
    );
    final selected = selectedUid.value;

    void confirm({required bool indoor}) {
      if (selected == null) return;
      Navigator.of(
        context,
      ).pop<CatchTargetChoice>((uid: selected, indoor: indoor));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: _handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '捕まえた！',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '相手に知らせます。10秒以内なら相手が取り消せます。',
              style: TextStyle(fontSize: 12, color: gameMuted),
            ),
            const SizedBox(height: 18),
            const _SectionLabel('誰を捕まえた？'),
            const SizedBox(height: 8),
            for (final candidate in candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CandidateChip(
                  name: candidate.name,
                  selected: candidate.uid == selected,
                  onTap: () => selectedUid.value = candidate.uid,
                ),
              ),
            const Text(
              '3m以内にいる逃走者だけを出しています',
              style: TextStyle(fontSize: 11, color: gameFaint),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: gameBorder),
            const SizedBox(height: 16),
            const _SectionLabel('どこで捕まえた？'),
            const SizedBox(height: 8),
            _PlaceButton(
              icon: Icons.home_outlined,
              label: '屋内で捕まえた',
              onPressed: selected == null ? null : () => confirm(indoor: true),
            ),
            const SizedBox(height: 8),
            _PlaceButton(
              icon: Icons.park_outlined,
              label: '屋外で捕まえた',
              onPressed: selected == null ? null : () => confirm(indoor: false),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: gameMuted),
                child: const Text('やめる', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: gameInk,
      ),
    );
  }
}

class _CandidateChip extends StatelessWidget {
  const _CandidateChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _selectedBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected
            ? const BorderSide(color: _fugitiveSurface, width: 2)
            : const BorderSide(color: gameBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: _fugitiveColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: _fugitiveSurface,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: catchSurfaceColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: catchSurfaceColor.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
