import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/wifi/model/clue_meter_sample.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

/// 選んだ相手の近さメーターの履歴を持ち、傾向([ClueTrend])を[builder]へ渡す。
///
/// 履歴はこの端末の画面にだけあればよい一時状態なので、RTDBにもRiverpodにも
/// 置かずhooksで持つ(AGENTS.md規約)。GamePageでは選ばれている相手が
/// ルームのデータを受け取った後でしか決まらず、そこではhooksを呼べないため、
/// 小さなウィジェットに切り出している。
///
/// 相手を選び直しても、前の相手の履歴はuidごとに残す(戻したときに
/// 「変わらない」からやり直しにならないように)。
class ClueTrendScope extends HookWidget {
  /// [uid]の[meter]を記録し、傾向を[builder]に渡す。
  const ClueTrendScope({
    required this.uid,
    required this.meter,
    required this.builder,
    this.clock = DateTime.now,
    super.key,
  });

  /// 選ばれている相手のuid。
  final String uid;

  /// いまの近さメーター(0〜100)。出せないときはnullで、記録しない。
  final double? meter;

  /// 傾向を受け取って中身を作る。
  final Widget Function(BuildContext context, ClueTrend trend) builder;

  /// 記録する時刻の取り方(テスト用に差し替えられる)。
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final history = useRef(<String, List<ClueMeterSample>>{});
    final value = meter;

    // 値が変わったとき(=新しいスキャンが届いたとき)だけ記録する。
    // 再描画のたびに足すと、同じ値が1秒ごとに並んで基準の時刻がずれる。
    //
    // 記録はbuild中に行う。useEffectで足すと、その描画では傾向が1回ぶん
    // 古いままになり、次の再描画(最長1秒後)まで反映が遅れるため。
    // 同じ(uid, meter)では2回足さないよう、最後に記録した値と比べる。
    final lastRecorded = useRef<(String, double)?>(null);
    if (value != null && lastRecorded.value != (uid, value)) {
      lastRecorded.value = (uid, value);
      history.value[uid] = appendClueSample(
        history.value[uid] ?? const [],
        ClueMeterSample(at: clock(), meter: value),
      );
    }

    final trend = value == null
        ? ClueTrend.unchanged
        : clueTrendOf(history.value[uid] ?? const []);
    return builder(context, trend);
  }
}
