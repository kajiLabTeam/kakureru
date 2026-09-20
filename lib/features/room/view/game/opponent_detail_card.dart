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

/// 選択中の相手1人ぶんの詳細(上下判定+Wi-Fi距離感)をまとめて表示する
/// カード(UI改修モック2a-03「◯◯ の詳細」)。
///
/// センサー非対応・未キャリブレーション・検知なしの状態は、実際に
/// 表示できる状態と明確に区別して案内する。
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

  static const _dotSize = 14.0;

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
          Text(
            '${target.displayName} の詳細',
            style: const TextStyle(
              fontSize: 12,
              color: appInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 84, child: _verticalSection(color)),
                const VerticalDivider(
                  width: 20,
                  color: appFaintBorder,
                  thickness: 2,
                ),
                Expanded(child: _wifiSection(color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalSection(Color opponentColor) {
    final message = _verticalStatusMessage();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('上下', style: TextStyle(fontSize: 10, color: appMuted)),
        const SizedBox(height: 4),
        SizedBox(
          height: 80,
          child: message != null
              ? Center(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: appMuted),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(height: 3, color: selfColor),
                          _buildDot(constraints.maxHeight, opponentColor),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
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

  Widget _buildDot(double height, Color opponentColor) {
    final t = verticalDotFraction(verticalPosition!.deltaMeters);
    final top = (height * (1 - t) - _dotSize / 2).clamp(0.0, height - _dotSize);

    return Positioned(
      top: top,
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: opponentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget _wifiSection(Color opponentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Wi-Fi距離感',
          style: TextStyle(fontSize: 10, color: appMuted),
        ),
        const SizedBox(height: 3),
        Text(
          _wifiLevelLabel(),
          style: TextStyle(
            fontSize: 16,
            color: _wifiLevelColor(),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (comparisons.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final comparison in comparisons) ...[
                  Expanded(child: _miniBar(comparison.selfRssi, selfColor)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _miniBar(comparison.targetRssi, opponentColor),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '青=自分 / 色=相手 のRSSI',
            style: TextStyle(fontSize: 9, color: Color(0xFFAAAAAA)),
          ),
        ],
      ],
    );
  }

  String _wifiLevelLabel() {
    switch (wifiLevel) {
      case ProximityLevel.close:
        return '近い';
      case ProximityLevel.far:
        return '遠い';
      case ProximityLevel.notDetected:
      case null:
        return '検知なし';
    }
  }

  /// 「近い」だけ強調色(赤)にし、それ以外は落ち着いた色にする
  /// (チップ一覧と同じ強弱付け)。
  Color _wifiLevelColor() {
    switch (wifiLevel) {
      case ProximityLevel.close:
        return const Color(0xFFE5484D);
      case ProximityLevel.far:
        return appInk;
      case ProximityLevel.notDetected:
      case null:
        return appMuted;
    }
  }

  Widget _miniBar(int rssi, Color color) {
    const minRssi = -90;
    const maxRssi = -40;
    final ratio = ((rssi - minRssi) / (maxRssi - minRssi)).clamp(0.05, 1.0);
    return FractionallySizedBox(
      heightFactor: ratio,
      alignment: Alignment.bottomCenter,
      child: Container(color: color),
    );
  }
}
