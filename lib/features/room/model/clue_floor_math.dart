/// 手がかりカードの「高さ」欄(何階ぶん上/下か)の純粋な計算と文言。
/// RTDBやセンサーに依存しないため、実機なしで単体テストできる。
///
/// **1階ぶんの気圧差[hectoPascalPerFloor]は暫定**。建物の階高(3〜4m)と
/// 換算係数(`metersPerHectoPascal` = 8.3m/hPa)からの目安で、実機で
/// 階段を上り下りして確かめたうえで調整する前提の値である。
library;

import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:kakureru/features/room/model/room_user.dart';

/// 1階ぶんとみなす気圧差(hPa)。暫定。
const double hectoPascalPerFloor = 0.4;

/// 表示する階数の上限(上下それぞれ)。これを超える差は±この値に丸める。
const int maxClueFloors = 3;

/// 高さの差(m)から、「相手の気圧が自分よりどれだけ低いか」(hPa)を求める。
///
/// [deltaMeters]は`calculateRelativeHeightMeters`の戻り値(正なら相手が上)。
/// 高い所ほど気圧は低いので、相手が上なら正(相手の気圧の方が低い)になる。
double opponentLowerPressureHPaOf(double deltaMeters) =>
    deltaMeters / metersPerHectoPascal;

/// 気圧差[opponentLowerHPa](正なら相手の気圧の方が低い=相手が上)から、
/// 相手が何階ぶん上か(負なら下)を求める。±[maxClueFloors]に丸める。
int floorsOf(double opponentLowerHPa) {
  final floors = (opponentLowerHPa / hectoPascalPerFloor).round();
  return floors.clamp(-maxClueFloors, maxClueFloors);
}

/// 高さバー上の相手のドット位置を、0.0(下端)〜1.0(上端)で返す。
///
/// 同じ高さ(0階)がちょうど中央(0.5)になる。
double floorDotFraction(int floors) {
  final clamped = floors.clamp(-maxClueFloors, maxClueFloors);
  return (clamped + maxClueFloors) / (2 * maxClueFloors);
}

/// 高さ欄の見出し(例: 「1階ぶんくらい 上かも」「同じくらいの高さかも」)。
String floorHeadline(int floors) {
  if (floors == 0) return '同じくらいの高さかも';
  final direction = floors > 0 ? '上' : '下';
  return '${floors.abs()}階ぶんくらい $directionかも';
}

/// 高さ欄の見出しの下に添える一言(issue #135)。
///
/// 鬼([viewerRole]がnullのときも)には探すための行動のすすめ
/// (例: 「階段をのぼってみよう」)を出す。逃走者には鬼がどこにいるかの
/// 状況だけを伝え、どう動くかは書かない。逃げ方まで指示すると、同じ
/// 情報でも逃走者が動きやすくなり、Wi-Fi・気圧で鬼の情報を増やして
/// 対等にするというゲームの狙いに反するため。
String floorActionHint(int floors, {required UserRole? viewerRole}) {
  if (viewerRole == UserRole.fugitive) {
    if (floors == 0) return '鬼は同じフロアにいるかも';
    return floors > 0 ? '鬼は上の階にいるかも' : '鬼は下の階にいるかも';
  }
  if (floors == 0) return 'このフロアを探してみよう';
  return floors > 0 ? '階段をのぼってみよう' : '階段をおりてみよう';
}

/// 高さ欄の気圧の補足(例: 「たくみの気圧は 0.4 hPa 低い」)。
///
/// 見出しと食い違わないよう、「ほぼ同じ」かどうかは階数(0階か)で決める。
/// hPaは小数1桁で出す。
String pressureDetailText(String name, double opponentLowerHPa) {
  final value = opponentLowerHPa.abs().toStringAsFixed(1);
  if (floorsOf(opponentLowerHPa) == 0) {
    return '$nameの気圧は ほぼ同じ（$value hPa）';
  }
  final comparison = opponentLowerHPa > 0 ? '低い' : '高い';
  return '$nameの気圧は $value hPa $comparison';
}
