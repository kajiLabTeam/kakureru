import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/wifi_math.dart';

/// 選択中の相手1人ぶんの「手がかり」(上下判定+Wi-Fi距離感)をまとめたカード。
///
/// 以前は上下を縦バーのドット1つ、Wi-Fiを自分と相手のRSSIを並べた縦棒
/// グラフで出していたが、実機で遊ぶと**どちらへ動けばいいのかが読み取れ
/// ない**という指摘が出た(issue #76)。ドットや棒の位置を「見比べて解釈
/// する」作りをやめ、
///
/// - 上下は **矢印 + 「上にいるかも」+ 気圧差(hPa)** で言い切る
/// - Wi-Fiは **共通APごとの横トラックに自分と相手の点を置き**、
///   「2つの点を近づける」という1つの目標として読めるようにする
///
/// という形にしている。判定そのもの(`proximity_calculator.dart` /
/// `relative_vertical_position`)は変えていない。ここは表示だけ。
///
/// センサー非対応・未キャリブレーション・検知なしの状態は、以前と同じく
/// 実際に表示できる状態と明確に区別して案内する(黙って空欄にしない)。
class OpponentDetailCard extends StatelessWidget {
  /// すべての引数はGamePageが計算して渡す(このウィジェットはproviderを
  /// 一切読まない)。
  const OpponentDetailCard({
    super.key,
    required this.user,
    required this.pressureState,
    required this.isCalibrated,
    required this.verticalPosition,
    required this.wifiLevel,
    required this.comparisons,
  });

  /// 詳細を出す相手。選択中の相手がいなければnull(検知なし表示)。
  final RoomUser? user;

  /// 自分の気圧センサーの状態。非対応・確認中の案内の出し分けに使う。
  final PressureState pressureState;

  /// 自分がキャリブレーション済みか。未実施なら上下判定は出せない。
  final bool isCalibrated;

  /// 相手が自分より上か下か。判定できていなければnull。
  final RelativeVerticalPosition? verticalPosition;

  /// 相手とのWi-Fiの3段階判定。検知できていなければnull。
  final ProximityLevel? wifiLevel;

  /// Wi-Fiの内訳表示(共通AP・電波の強さの比較)。
  final List<WifiApComparison> comparisons;

  /// 上下バーの相手ドットの直径。
  static const _verticalDotSize = 14.0;

  /// 上下バーの高さ。矢印+文言+気圧差の行と釣り合う高さにしている。
  static const _verticalBarHeight = 84.0;

  /// 上下バーの幅。ドット([_verticalDotSize])に左右の余白を足した程度。
  static const _verticalBarWidth = 26.0;

  /// 距離感トラックのドットの直径。
  static const _trackDotSize = 13.0;

  /// 凡例に出す相手の名前の最大幅。長い名前でタイトルを押し潰さないため。
  static const _legendNameMaxWidth = 72.0;

  /// 「近い」の強調色。鬼の赤(role_theme.dart)と同じ値。
  static const _closeColor = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    final target = user;
    if (target == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: appFaintBorder, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '検知なし',
            style: TextStyle(color: appMuted, fontSize: 13),
          ),
        ),
      );
    }

    final color = colorForRole(target.role);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: appInk, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(target, color),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _verticalPanel(target, color)),
                const SizedBox(width: 10),
                Expanded(child: _wifiPanel(target, color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// タイトルと、点の色の凡例。
  ///
  /// 以前はWi-Fi側の一番下に「青=自分 / 色=相手のRSSI」という9pxの文字
  /// だけの凡例があり、まず読まれなかった。色見本つきでカードの一番上に出す。
  Widget _header(RoomUser target, Color opponentColor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${target.displayName} の手がかり',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: appInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _legendEntry(selfColor, const Text('自分', style: _legendTextStyle)),
        const SizedBox(width: 10),
        _legendEntry(
          opponentColor,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _legendNameMaxWidth),
            child: Text(
              target.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _legendTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  static const _legendTextStyle = TextStyle(fontSize: 10, color: appMuted);

  Widget _legendEntry(Color color, Widget label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        label,
      ],
    );
  }

  /// 枠付きの小パネル。上下と距離感を同じ見た目で並べる。
  Widget _panel({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: appFaintBorder, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: appMuted)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _verticalPanel(RoomUser target, Color opponentColor) {
    final message = _verticalStatusMessage();
    if (message != null) {
      return _panel(
        label: '上下',
        child: SizedBox(
          height: _verticalBarHeight,
          width: double.infinity,
          child: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: appMuted),
            ),
          ),
        ),
      );
    }

    final delta = verticalPosition!.deltaMeters;
    final height = relativeHeightOf(delta);
    return _panel(
      label: '上下',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _verticalBarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _verticalBarWidth,
                  child: _verticalBar(delta, height, opponentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _verticalIcon(height),
                        size: 24,
                        color: opponentColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _verticalLabel(height),
                        style: const TextStyle(
                          fontSize: 13,
                          color: appInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pressureDiffText(
              displayName: target.displayName,
              deltaMeters: delta,
            ),
            style: const TextStyle(fontSize: 11, color: appMuted),
          ),
        ],
      ),
    );
  }

  /// 縦バー。自分の線を中央に固定し、相手のドットをその上下に置く。
  ///
  /// 相手がいる側の半分を相手色で薄く塗る。ドットの位置だけだと、走りながら
  /// の一瞥では「線より上か下か」を読み違えるため。
  Widget _verticalBar(
    double delta,
    RelativeHeight height,
    Color opponentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (height != RelativeHeight.same)
                  Align(
                    alignment: height == RelativeHeight.above
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.5,
                      child: ColoredBox(
                        color: opponentColor.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                Container(height: 3, color: selfColor),
                _verticalDot(constraints.maxHeight, delta, opponentColor),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _verticalDot(double height, double delta, Color opponentColor) {
    final t = verticalDotFraction(delta);
    final top = (height * (1 - t) - _verticalDotSize / 2).clamp(
      0.0,
      height - _verticalDotSize,
    );

    return Positioned(
      top: top,
      child: Container(
        width: _verticalDotSize,
        height: _verticalDotSize,
        decoration: BoxDecoration(
          color: opponentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  /// 実際に上下を表示できないなら理由を返す。表示できるならnull。
  String? _verticalStatusMessage() {
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.unavailable) {
      return '非対応';
    }
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.checking) {
      return '確認中';
    }
    if (!isCalibrated) {
      return '未実施';
    }
    if (verticalPosition == null) {
      return '検知なし';
    }
    return null;
  }

  static IconData _verticalIcon(RelativeHeight height) {
    switch (height) {
      case RelativeHeight.above:
        return Icons.arrow_upward;
      case RelativeHeight.below:
        return Icons.arrow_downward;
      case RelativeHeight.same:
        return Icons.horizontal_rule;
    }
  }

  static String _verticalLabel(RelativeHeight height) {
    switch (height) {
      case RelativeHeight.above:
        return '上にいるかも';
      case RelativeHeight.below:
        return '下にいるかも';
      case RelativeHeight.same:
        return '同じ高さかも';
    }
  }

  Widget _wifiPanel(RoomUser target, Color opponentColor) {
    return _panel(
      label: '距離感',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 収束する2本の矢印に合うMaterialアイコンが無いため文字で出す。
              Text(
                '→←',
                style: TextStyle(fontSize: 13, color: _wifiLevelColor()),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _wifiLevelLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: _wifiLevelColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (comparisons.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final comparison in comparisons) ...[
              _track(comparison, opponentColor),
              const SizedBox(height: 6),
            ],
            Text(
              '青を${colorNameForRole(target.role)}に近づけよう',
              style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
            ),
          ],
        ],
      ),
    );
  }

  /// 共通AP1つぶんの横トラック。左が弱い(遠い)、右が強い(近い)。
  ///
  /// 同じAPに対する自分と相手のRSSIを同じ物差しの上に置くので、2つの点の
  /// 間隔がそのまま「その方向にどれだけ離れているか」になる。以前の縦棒
  /// グラフは高さを見比べる必要があり、近づいたのか離れたのかが分からなかった。
  Widget _track(WifiApComparison comparison, Color opponentColor) {
    return SizedBox(
      // 「共通AP1つにつき1本」をテストから数えられるようにする。
      key: ValueKey('wifiTrack:${comparison.bssid}'),
      height: _trackDotSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Center(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: appFaintBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _trackDot(width, comparison.selfRssi, selfColor),
              _trackDot(width, comparison.targetRssi, opponentColor),
            ],
          );
        },
      ),
    );
  }

  Widget _trackDot(double width, int rssi, Color color) {
    final left = (width * rssiTrackFraction(rssi) - _trackDotSize / 2).clamp(
      0.0,
      width - _trackDotSize,
    );
    return Positioned(
      left: left,
      top: 0,
      child: Container(
        width: _trackDotSize,
        height: _trackDotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  String _wifiLevelLabel() {
    switch (wifiLevel) {
      case ProximityLevel.close:
        return '近いかも';
      case ProximityLevel.far:
        return '遠いかも';
      case ProximityLevel.notDetected:
      case null:
        // ここだけ「かも」を付けない。推測ではなく「こちらに材料が無い」
        // という事実を言っているため。
        return '検知なし';
    }
  }

  /// 「近い」だけ強調色(赤)にし、それ以外は落ち着いた色にする
  /// (チップ一覧と同じ強弱付け)。
  Color _wifiLevelColor() {
    switch (wifiLevel) {
      case ProximityLevel.close:
        return _closeColor;
      case ProximityLevel.far:
        return appInk;
      case ProximityLevel.notDetected:
      case null:
        return appMuted;
    }
  }
}

/// 「◯◯の気圧は X hPa 低い」の1行を作る。
///
/// issue #41で上下表示から数値と単位を一度外したが、矢印と「〜かも」で
/// 不確かさを示したうえで**動いたときに値が変わるのを見せる**方を優先して
/// 戻している(issue #76)。高さ(m)ではなく気圧(hPa)を出すのは、8.3m/hPaの
/// 換算後の数値の方が「正確な高度」に見えてしまうため。
///
/// [deltaMeters]が正なら相手が上=相手の気圧の方が低い。
String pressureDiffText({
  required String displayName,
  required double deltaMeters,
}) {
  if (relativeHeightOf(deltaMeters) == RelativeHeight.same) {
    return '$displayNameの気圧は ほぼ同じ';
  }
  final diff = hectoPascalDiffOf(deltaMeters).toStringAsFixed(2);
  final direction = deltaMeters > 0 ? '低い' : '高い';
  return '$displayNameの気圧は $diff hPa $direction';
}
