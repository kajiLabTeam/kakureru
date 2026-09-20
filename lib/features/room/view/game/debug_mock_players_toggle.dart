import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/debug_mock_players.dart';

/// デバッグ用の偽プレイヤーを出す/隠すトグル(issue #67)。
///
/// 待機画面とゲーム画面のAppBarに同じものを置く。状態は
/// [showDebugMockPlayersProvider]で共有しているので、待機画面で出せば
/// ゲーム画面へ移ってもそのまま出たままになる。
///
/// `kDebugMode`がfalseのリリースビルドでは、このウィジェットは何も
/// 描かない(各画面も`if (kDebugMode)`で囲んでいるので、そもそも
/// ここまで来ない)。
class DebugMockPlayersToggle extends ConsumerWidget {
  /// AppBarの`actions`に置く。
  const DebugMockPlayersToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    final showing = ref.watch(showDebugMockPlayersProvider);
    return IconButton(
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      tooltip: showing ? 'デバッグ用の偽プレイヤーを隠す' : 'デバッグ用の偽プレイヤーを出す',
      icon: Icon(showing ? Icons.group : Icons.group_outlined),
      onPressed: ref.read(showDebugMockPlayersProvider.notifier).toggle,
    );
  }
}
