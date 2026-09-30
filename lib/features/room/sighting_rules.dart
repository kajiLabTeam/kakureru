/// 目撃写真(見つけた鬼の写真、`sightings`)の絞り込み・未読数・表示文言。
///
/// 画面(sighting_sheet.dart)とゲーム画面のバッジの両方から使うため、
/// Flutterに依存しない純粋な関数として置く(テストを書きやすくするため)。
library;

import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/sighting.dart';

/// 今のゲームの目撃写真だけを、撮った順(古い→新しい)に並べて返す。
///
/// `restartRoom`は`sightings`を消さないので、`meta/startedAt`より前の
/// ものは前のゲームの写真として除く(`catchesOfCurrentGame`と同じ考え方)。
/// [startedAt]が無い(まだ始まっていない・読み込み前)なら空。
/// 同じ時刻のものはIDの順にして、並びが描き直しのたびに揺れないようにする。
List<Sighting> sightingsOfCurrentGame(
  List<Sighting> sightings, {
  required int? startedAt,
}) {
  if (startedAt == null) return const [];
  return sightings.where((s) => s.takenAt >= startedAt).toList()..sort((a, b) {
    final byTime = a.takenAt.compareTo(b.takenAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
}

/// ボタンのバッジに出す未読の数。
///
/// [sightings]は[sightingsOfCurrentGame]で並べたもの。[seenCount]は最後に
/// シートを見たときの枚数(画面に入った時点で既にあったものは見たことに
/// する。写真タブの新着の点と同じ考え方)。まだ数え始めていなければ(null)0。
///
/// 見た枚数より後に増えたもののうち、**自分が撮ったものは数えない**。
/// シートを閉じた後に自分の写真の送信が終わると、自分の写真が「未読」に
/// なってしまうため。新しい写真はサーバー時刻で書かれるので、並びの
/// 末尾に足される(見た枚数より後ろ=新しく増えたもの)。
int unreadSightingCount({
  required List<Sighting> sightings,
  required int? seenCount,
  required String? myUid,
}) {
  if (seenCount == null || seenCount >= sightings.length) return 0;
  return sightings.skip(seenCount).where((s) => s.uid != myUid).length;
}

/// 写真の上に小さく出す「名前 ・ 時刻 ・ 場所」。場所が無ければ省く。
///
/// 自分が撮ったものは名前の代わりに「自分」と出す(左右の配置と合わせて、
/// どれが自分の写真かを一目で分かるようにするため)。
String sightingCaption({
  required String authorName,
  required bool isMine,
  required int takenAt,
  String? place,
}) {
  return [
    if (isMine) '自分' else authorName,
    formatClockTime(takenAt),
    if (place != null && place.trim().isNotEmpty) place.trim(),
  ].join(' ・ ');
}
