import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';

/// エリア外警告に使う赤。docs/ui-mockup-2a.html の 2a-07 と同じ #E5484D。
///
/// 配色ルール(赤=鬼/青=自分/緑=逃走者)上の赤は本来「鬼」だが、2a-07は
/// 警告帯・地図の赤かぶせ・矢印をすべてこの赤で描いている。危険を示す色を
/// ここだけ別に増やすより、モックに合わせる方を優先する。
///
/// ただし鬼のプレイヤーはヘッダーもこれと同じ赤(role_theme.dartの
/// 鬼の色は同じ値)なので、帯だけを出すとヘッダーが伸びただけに見えて
/// 気づかれない。[OutsideAreaBanner]は上下に境界線を入れて区切る。
const outsideAreaAlertColor = Color(0xFFE5484D);

/// 警告帯の区切り線の色。ヘッダー(鬼なら同じ赤)や地図との境目を出すため、
/// 帯の上下に細く入れる。
const _bannerBorderColor = Color(0xFF7F1D20);

/// 地図に重ねる赤の濃さ。モックの rgba(229,72,77,.16) と同じ。
const _mapOverlayAlpha = 0.16;

/// 帯の補足行の不透明度。モック2a-07の `opacity:.85` と同じ。
///
/// `Colors.white70` だとこの赤の上で10pxのコントラスト比が約2.8:1しか
/// 出ず(WCAG AAは4.5:1)、「振動は仕様であって不具合ではない」と伝える
/// 唯一の行が読み取りにくい。
const _bannerSubtitleOpacity = 0.85;

/// 「戻るまで◯◯が続きます」の補足文。
///
/// 判定はGamePageの毎秒の再描画で回っているため、画面を消している間は
/// 振動も通知も止まる(画面を消しても検知を続ける件は別issueで扱う)。
/// モック2a-07の「戻るまで振動と通知が続きます」をそのままにすると、
/// 実際には果たせない約束になるので、画面を開いている間の話だと分かる
/// 文言にしている。
const outsideAreaBannerSubtitle = 'アプリを開いている間、戻るまで振動と通知が続きます';

/// 画面上部に出すエリア外の警告帯(UI改修モック2a-07)。
///
/// 文言は2行。1行目で状態を、2行目で「戻るまで続く」ことを伝える
/// (振動が止まらないのを不具合と誤解させないため。issue #61の検討メモ:
/// エリア外はルール違反なのでペナルティとして意図的に継続する)。
class OutsideAreaBanner extends StatelessWidget {
  /// 表示内容は固定なので引数を取らない。出す/出さないの判断は
  /// 呼び出し側([OutsideAreaAlertMap])が持つ。
  const OutsideAreaBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: const BoxDecoration(
        color: outsideAreaAlertColor,
        // 鬼のヘッダーと同じ赤なので、境目が無いと「ヘッダーが伸びた」と
        // しか見えない。上下に濃い赤の線を入れて別の帯だと分かるようにする。
        border: Border.symmetric(
          horizontal: BorderSide(color: _bannerBorderColor, width: 2),
        ),
      ),
      child: const Row(
        children: [
          Text('🚨', style: TextStyle(fontSize: 19)),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'プレイエリアの外です',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  outsideAreaBannerSubtitle,
                  style: TextStyle(
                    color: Color.fromRGBO(
                      255,
                      255,
                      255,
                      _bannerSubtitleOpacity,
                    ),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 地図全体に赤の半透明を重ね、エリアの方向を指す矢印を出すオーバーレイ
/// (UI改修モック2a-07)。
///
/// 地図そのもの(エリアの破線境界・外側の暗転)は`GameLocationMap`が描くので、
/// ここではその上に重ねる警告表示だけを持つ。矢印は画面中央に出す: モックは
/// 自分のピンの横に添えているが、ピンのスクリーン座標は地図のカメラ次第で
/// 変わり、このウィジェットからは分からないため。
///
/// 地図のパン・ズームを邪魔しないよう[IgnorePointer]でタップを素通りさせる。
class OutsideAreaMapOverlay extends StatelessWidget {
  /// [bearingDegrees]はエリアへ戻る方位(北=0・東=90の時計回り)。
  /// `describeReturnToArea`の戻り値をそのまま渡す。判定に使える新しい位置が
  /// 無くて方位が出せないときはnullを渡すと、赤かぶせだけになる
  /// (古い位置のまま矢印を出すと、違う方向へ歩かせることになるため)。
  const OutsideAreaMapOverlay({super.key, required this.bearingDegrees});

  /// エリアへ戻る方位(度)。矢印の回転角に使う。nullなら矢印を出さない。
  final double? bearingDegrees;

  @override
  Widget build(BuildContext context) {
    final bearing = bearingDegrees;
    return IgnorePointer(
      child: Container(
        color: outsideAreaAlertColor.withValues(alpha: _mapOverlayAlpha),
        alignment: Alignment.center,
        // 地図は回転させない(game_map_options.dartでInteractiveFlag.rotateを
        // 外している)ので、方位角をそのまま時計回りの回転角として使える。
        // 上向きの矢印が北を指す。
        child: bearing == null
            ? null
            : Transform.rotate(
                angle: bearing * math.pi / 180,
                child: const Icon(
                  Icons.arrow_upward,
                  size: 72,
                  color: outsideAreaAlertColor,
                  // 赤い地図タイルの上でも輪郭が沈まないよう、白いにじみを
                  // 敷く(地図ピンの白フチと同じ狙い)。
                  shadows: [Shadow(color: Colors.white, blurRadius: 10)],
                ),
              ),
      ),
    );
  }
}

/// 画面に出すエリア外アラートの中身。警告していないときはnullを使う。
///
/// `meters`と`bearingDegrees`は「いま判定に使える新しい位置がある」ときだけ
/// 入る。古い位置は判定に使わない(`observeOutsideArea`)ため、警告を保った
/// まま距離と方位だけ分からなくなる瞬間があり、そのときは両方nullになる。
typedef OutsideAreaAlert = ({double? bearingDegrees});

/// 猶予判定の結果と観測から、画面に出すアラートの中身を決める。
///
/// [isWarning]がfalseならnull(何も出さない)。ここには**表示と同じ条件**を
/// 渡すこと。GamePageは「判定が警告」かつ「本文がroomのdataを描いている」
/// ときだけtrueにしており、同じ値を振動・通知の条件にも使っている。
///
/// 警告中でも、判定に使える新しい位置が無ければ方位はnullにする
/// (古い位置のまま矢印を出すと、違う方向へ歩かせることになるため)。
OutsideAreaAlert? outsideAreaAlertOf({
  required bool isWarning,
  required OutsideAreaObservation observation,
}) {
  if (!isWarning) return null;
  if (observation.status != OutsideAreaStatus.outside) {
    return (bearingDegrees: null);
  }
  return (bearingDegrees: observation.bearingDegrees);
}

/// 地図とエリア外アラートを重ねた、ゲーム画面の地図領域。
///
/// **アラートは地図の上に重ねるだけで、レイアウトの高さを取らない。**
/// 赤帯をbodyのColumnに足すと、その60px分だけ地図と下の相手選択カードが
/// 押し出され、小さい画面や大きいフォント設定では`Expanded`が0になって
/// 地図ごと潰れる。表示/非表示でレイアウトを動かさない、という考え方は
/// issue #43(become_demon_button)と同じ。
///
/// [alert]がnullなら地図だけを返す。「出す/出さない」の分岐をここに
/// 閉じ込めているので、呼び出し側(GamePage)もテストも同じ配線を通る。
class OutsideAreaAlertMap extends StatelessWidget {
  /// [map]には`GameLocationMap`を渡す。[alert]は警告中の内容(なければnull)。
  const OutsideAreaAlertMap({
    super.key,
    required this.map,
    required this.alert,
  });

  /// 下敷きになる地図。
  final Widget map;

  /// 出すアラートの中身。警告していないならnull。
  final OutsideAreaAlert? alert;

  @override
  Widget build(BuildContext context) {
    final alert = this.alert;
    final bearingDegrees = alert?.bearingDegrees;
    return Stack(
      children: [
        map,
        // エリアの破線境界と外側の暗転はGameLocationMapが既に描いている。
        // ここに重ねるのは、エリア外のときだけ出す赤かぶせ・方向矢印・
        // 赤帯(UI改修モック2a-07)。モックにある「エリアまで約◯m・◯へ
        // 戻ってください」のカードは、方向が矢印で分かり文字が重複する
        // ため入れていない。
        if (alert != null) ...[
          Positioned.fill(
            child: OutsideAreaMapOverlay(bearingDegrees: bearingDegrees),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OutsideAreaBanner(),
          ),
        ],
      ],
    );
  }
}

/// GamePageの地図領域(地図+エリア外アラート)をwidgetテストから組み立てる入口。
///
/// GamePage全体はFirebase・センサー系のproviderを丸ごと差し替えないと
/// 立ち上がらないため、地図領域だけをGamePageと同じ配線で組む
/// (`buildLocationMapForTest`と同じ考え方)。アラートを出す/出さないの
/// 分岐は[outsideAreaAlertOf]と[OutsideAreaAlertMap]の中にあるので、
/// テスト側で配線を組み直さずに本番と同じ経路を通せる。
@visibleForTesting
Widget buildGameMapAreaForTest({
  required OutsideAreaAlert? alert,
  List<UserLocation> locations = const [],
  List<RoomUser> users = const [],
  String? myUid,
  List<LatLng> gameArea = const [],
}) {
  return OutsideAreaAlertMap(
    alert: alert,
    map: GameLocationMap(
      locations: locations,
      users: users,
      myUid: myUid,
      cachedPosition: null,
      gameArea: gameArea,
    ),
  );
}
