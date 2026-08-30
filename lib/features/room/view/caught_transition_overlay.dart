import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';

/// 「捕まった」ボタン押下が確定した直後に表示する全画面演出。
///
/// ボタンを押しても画面上の変化が乏しく押せたのか分かりにくい、という
/// issue #15の課題に対応する。docs/ui-mockup-2a.html の画面06(鬼になった
/// 直後)に合わせ、画面全体を鬼テーマの色にフェードで切り替えることで
/// 「操作が確定した」ことを本人に強く印象づける。役割の色・文言・アイコンは
/// ヘッダー表示(issue #12)と同じ `roleThemeOf` を再利用し、表記を揃える。
class CaughtTransitionOverlay extends HookWidget {
  const CaughtTransitionOverlay({super.key, required this.onContinue});

  /// 「鬼の画面へ」ボタン押下時に呼ばれる。演出を閉じる責務は呼び出し側が持つ。
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 400),
    );
    useEffect(() {
      controller.forward();
      return null;
    }, const []);

    final theme = roleThemeOf(UserRole.demon);

    return FadeTransition(
      opacity: controller,
      child: Material(
        color: theme.color,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(theme.icon, color: Colors.white, size: 96),
                  const SizedBox(height: 24),
                  Text(
                    theme.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '逃走者の位置が見えるようになります',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme.color,
                    ),
                    onPressed: onContinue,
                    child: const Text('鬼の画面へ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
