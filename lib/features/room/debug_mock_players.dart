/// デバッグビルド専用の「偽プレイヤー」(issue #67)。
///
/// 多人数でのゲーム画面の見え方(相手選択チップ・地図のピン・詳細カード)は、
/// 本来なら人数分の端末を集めないと確認できない。そこで、この端末の画面に
/// だけ足す偽の参加者一式をここで組み立てる。
///
/// **RTDBには一切書かない**。ここで作った値はGamePageが表示用のリストに
/// 足すだけなので、他の参加者からは見えないし、ゲームの進行にも影響しない。
///
/// **リリースビルドには入らない**。各関数は [kDebugMode] がfalseなら空の
/// リストを返し、呼び出し側(GamePage)も `if (kDebugMode)` で囲んでいるため、
/// リリースビルドではこのコードごと落ちる(game_map_options.dartと同じ方針)。
///
/// **値は固定シードで決まる**。ゲーム画面は残り時間の更新で毎秒
/// リビルドされるので、乱数をそのまま使うとチップのWi-Fi判定や地図のピンが
/// 毎秒ちらついてしまう。同じ引数なら常に同じ値を返すようにしてある
/// (テストでも同じ値を期待できる)。
library;

import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// 偽プレイヤーの人数。実機1台で「チップが均等割りに収まらなくなる」
/// 状態まで持っていける人数にしてある。
///
/// 6人にしているのは、360dp幅の端末だと5人目から横スクロールに切り替わる
/// ため、切り替わった後の見え方(スクロールできること、各チップの幅が
/// 48dpを下回らないこと)まで確認したいから。
///
/// **増やすときは、下の各定数リストも同じ数だけ伸ばすこと。**
/// 数が合わないと[_mockUsers]のassertで落ちる。
const debugMockPlayerCount = 6;

/// 乱数の固定シード。issueの番号をそのまま使っているだけで、値自体に
/// 意味はない(毎回同じ並びになることだけが重要)。
const debugMockPlayerSeed = 67;

/// 偽プレイヤーのuid。実在のFirebase Authのuidとは形が違うので、
/// 万一ログに出ても本物と取り違えない。
const debugMockPlayerUids = [
  'debug-mock-0',
  'debug-mock-1',
  'debug-mock-2',
  'debug-mock-3',
  'debug-mock-4',
  'debug-mock-5',
];

/// 偽プレイヤーの表示名。UI改修モック2a-03に出てくる名前
/// (ゆい/たくみ/そら)を含む、短い日本語の名前にしてある。
const _debugMockPlayerNames = [
  'ゆい',
  'たくみ',
  'そら',
  'あおい',
  'はると',
  'みなと',
];

/// Wi-Fiの3段階判定。「近い/遠い/検知なし」が必ず混ざるよう、乱数ではなく
/// 固定の並びで持つ(混ざっていないと表示の作り分けを確認できないため)。
const List<ProximityLevel> _debugMockWifiLevels = [
  ProximityLevel.close,
  ProximityLevel.far,
  ProximityLevel.notDetected,
  ProximityLevel.close,
  ProximityLevel.far,
  ProximityLevel.notDetected,
];

/// 上下バーの基準になる高さの差(メートル)。上(正)・下(負)・ほぼ同じ高さ(0)
/// が必ず混ざるようにしてある。バーの表示範囲は±20m
/// (pressure_math.dartの`verticalDotFraction`)なので、その中に収まる値。
const _debugMockVerticalBaseMeters = [8.0, -6.0, 0.0, 14.0, -12.0, 3.0];

/// 高さの差に乗せる揺らぎの幅(メートル)。±[_debugMockVerticalJitterMeters]/2
/// の範囲で揺らす。「ほぼ同じ高さ」の1人が上下どちらかに振り切れない程度の
/// 小さい値にしている。
const _debugMockVerticalJitterMeters = 1.6;

/// 偽プレイヤーを自分の周りに散らす半径(メートル)の下限。
const _debugMockRadiusMinMeters = 30.0;

/// 偽プレイヤーを自分の周りに散らす半径(メートル)の上限。プレイエリアを
/// はみ出して地図の外へ飛ばないよう、歩いて届く程度に抑えている。
const _debugMockRadiusMaxMeters = 120.0;

/// 均等に割り振った方角(2π/人数)に乗せる揺らぎ(ラジアン)。きれいな
/// 正五角形に並ぶと不自然なので少しずらす。
const _debugMockAngleJitterRadians = 0.6;

/// 緯度1度あたりの距離(メートル)。経度方向は緯度に応じて縮むため、
/// この値にcos(緯度)を掛けて使う。
const _metersPerDegreeLatitude = 111320.0;

/// 偽プレイヤーを出しているかどうか。
///
/// 待機画面とゲーム画面の**両方**で使うのでRiverpodに持つ(AGENTS.mdの
/// 状態管理規約: 画面が消えても状態が残ってほしいものはRiverpod)。
/// 以前は各画面が別々の`useState`で持っていたため、待機画面で出しても
/// ゲーム画面へ移った瞬間に消え、「モックが壊れている」ように見えた。
final showDebugMockPlayersProvider =
    NotifierProvider<ShowDebugMockPlayers, bool>(ShowDebugMockPlayers.new);

/// [showDebugMockPlayersProvider]の実体。
class ShowDebugMockPlayers extends Notifier<bool> {
  @override
  bool build() => false;

  /// 出す/隠すを切り替える。
  void toggle() => state = !state;
}

/// [uid]が偽プレイヤーのものか。
///
/// RTDBへ書き込むボタン(鬼の指名・取り消し)を偽プレイヤーの行に出さない
/// ための判定。出してしまうと実在しないuidが`meta/pendingDemonUid`等へ
/// 書き込まれ、誰も受諾できないまま残って**部屋が鬼を指名できなくなる**。
bool isDebugMockPlayer(String uid) => debugMockPlayerUids.contains(uid);

/// 待機画面に足す偽プレイヤーの役割。鬼2人・逃走者3人が混ざる。
///
/// ゲーム開始の条件は「鬼が1人以上 かつ 逃走者が1人以上」
/// (`hasStartableRoleComposition`、issue #33)。全員を同じ役割にすると、
/// 自分がどちらになるかで条件を満たせなくなる。混ぜておけば、自分が
/// 鬼でも逃走者でも必ず両方が1人以上いる状態になる。
const List<UserRole> _debugMockWaitingRoles = [
  UserRole.demon,
  UserRole.fugitive,
  UserRole.demon,
  UserRole.fugitive,
  UserRole.fugitive,
  UserRole.fugitive,
];

/// 待機画面に足す偽プレイヤー5人ぶんの [RoomUser](issue #67)。
///
/// ゲーム画面用の[debugMockUsers]と分けているのは、必要な役割の配り方が
/// 逆だから。ゲーム画面は「自分と逆の役割」しか表示しないので全員を逆の
/// 役割にするが、待機画面は開始条件を満たしたいので両方の役割を混ぜる。
///
/// `pressureSensorAvailable: false` にしているのは、キャリブレーションの
/// 完了判定(`calibrationStatusFor`)で「非対応」として数から外すため。
/// 偽プレイヤーは当然キャリブレーションできないので、そうしないと
/// 「キャリブレーション未完了」で永久に開始できない。
List<RoomUser> debugMockWaitingUsers() =>
    _mockUsers(roles: _debugMockWaitingRoles);

/// ゲーム画面に足す偽プレイヤー5人ぶんの [RoomUser]。
///
/// 役割は [myRole] の逆にする(自分が鬼なら逃走者5人)。相手選択チップも
/// 地図のピンも「自分と逆の役割」しか出さないため、同じ役割で作ると
/// どこにも現れない。
List<RoomUser> debugMockUsers({required UserRole myRole}) {
  final role = myRole == UserRole.demon ? UserRole.fugitive : UserRole.demon;
  return _mockUsers(roles: List.filled(debugMockPlayerCount, role));
}

/// 偽プレイヤー5人ぶんの [RoomUser] を組み立てる。役割の配り方だけが
/// 画面ごとに違うので、そこだけ[roles]で受け取る。
///
/// `pressureSensorAvailable: false` は待機画面のキャリブレーション判定で
/// 「非対応」として数から外すため。どちらの画面でも同じ人物として扱いたい
/// ので、片方だけ未設定にはしない。
List<RoomUser> _mockUsers({required List<UserRole> roles}) {
  if (!kDebugMode) return const [];
  assert(
    roles.length == debugMockPlayerCount,
    '役割の数が偽プレイヤーの人数と合っていない',
  );

  return [
    for (var i = 0; i < debugMockPlayerCount; i++)
      RoomUser(
        id: debugMockPlayerUids[i],
        displayName: _debugMockPlayerNames[i],
        role: roles[i],
        pressureSensorAvailable: false,
      ),
  ];
}

/// 偽プレイヤー5人ぶんのWi-Fi3段階判定。「近い/遠い/検知なし」が混ざる。
List<WifiProximityEntry> debugMockWifiEntries() {
  if (!kDebugMode) return const [];

  return [
    for (var i = 0; i < debugMockPlayerCount; i++)
      WifiProximityEntry(
        uid: debugMockPlayerUids[i],
        level: _debugMockWifiLevels[i],
      ),
  ];
}

/// 偽プレイヤー5人ぶんの上下関係。上・下・ほぼ同じ高さが混ざるので、
/// 詳細カードの上下バーの点が相手ごとに違う位置に出る。
List<RelativeVerticalPosition> debugMockVerticalPositions({
  int seed = debugMockPlayerSeed,
}) {
  if (!kDebugMode) return const [];

  final random = Random(seed);
  return [
    for (var i = 0; i < debugMockPlayerCount; i++)
      RelativeVerticalPosition(
        uid: debugMockPlayerUids[i],
        deltaMeters:
            _debugMockVerticalBaseMeters[i] +
            (random.nextDouble() - 0.5) * _debugMockVerticalJitterMeters,
      ),
  ];
}

/// 偽プレイヤーを散らす中心にする座標を選ぶ。
///
/// 自分の現在地(GPS実測)が [locations] にあればそれを使い、無ければ
/// [fallbackLatitude]/[fallbackLongitude](端末キャッシュや地図の暫定
/// センターを渡す想定)を返す。地図が映している範囲の中に偽のピンを
/// 出すためのもの。
({double latitude, double longitude}) debugMockCenterOf({
  required List<UserLocation> locations,
  required String? myUid,
  required double fallbackLatitude,
  required double fallbackLongitude,
}) {
  for (final location in locations) {
    if (location.uid == myUid) {
      return (latitude: location.latitude, longitude: location.longitude);
    }
  }
  return (latitude: fallbackLatitude, longitude: fallbackLongitude);
}

/// 偽プレイヤー5人ぶんのGPS位置。[centerLatitude]/[centerLongitude]
/// (自分の現在地を渡す想定)の周りに、方角を均等に割り振って散らす。
///
/// 極付近では経度1度あたりの距離が0に近づいて座標が発散するため、
/// cos(緯度)には下限を設けている(実際に遊ぶ緯度では効かない保険)。
List<UserLocation> debugMockLocations({
  required double centerLatitude,
  required double centerLongitude,
  int seed = debugMockPlayerSeed,
}) {
  if (!kDebugMode) return const [];

  final random = Random(seed);
  final latitudeRadians = centerLatitude * pi / 180;
  final metersPerDegreeLongitude =
      _metersPerDegreeLatitude * max(cos(latitudeRadians).abs(), 0.01);

  final locations = <UserLocation>[];
  for (var i = 0; i < debugMockPlayerCount; i++) {
    final angle =
        2 * pi * i / debugMockPlayerCount +
        (random.nextDouble() - 0.5) * _debugMockAngleJitterRadians;
    final radiusMeters =
        _debugMockRadiusMinMeters +
        random.nextDouble() *
            (_debugMockRadiusMaxMeters - _debugMockRadiusMinMeters);

    locations.add(
      UserLocation(
        uid: debugMockPlayerUids[i],
        latitude:
            centerLatitude +
            radiusMeters * cos(angle) / _metersPerDegreeLatitude,
        longitude:
            centerLongitude +
            radiusMeters * sin(angle) / metersPerDegreeLongitude,
      ),
    );
  }
  return locations;
}
