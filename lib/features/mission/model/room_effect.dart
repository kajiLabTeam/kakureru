import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';

part 'room_effect.freezed.dart';
part 'room_effect.g.dart';

/// RTDB `rooms/{roomId}/effects/{effectId}` 1件ぶん。特典を引いた瞬間に
/// 1件足す(持ち歩かせない)。
///
/// 効果をuidごとではなく**ルーム単位**に持つのは、鬼に効く効果を全員の
/// 端末で同じ見え方にするため。`skip_foot_photo` だけは `byUid` の本人に効く。
///
/// キー(`effectId`)は、その特典を引いたミッションのID。1つのミッションから
/// 出る効果は1件だけなので、書き込みをやり直しても重ならない。
@freezed
abstract class RoomEffect with _$RoomEffect {
  const factory RoomEffect({
    required String id,
    required RewardType type,

    /// 引いた人のuid。
    required String byUid,

    /// 発動した時刻(ServerValue.timestamp)。
    required int startedAt,

    /// 効いている時間(ミリ秒)。回数もの(skip_foot_photo)は0。
    required int durationMs,

    /// skip_foot_photo で飛ばす撮影スロットの番号。引いた瞬間の状態(撮影
    /// タイムが来ていたか)で決めて書く。後から撮り直しても変わらないように、
    /// 読む側で計算し直さない。古いデータには無い。
    int? skipSlot,
  }) = _RoomEffect;

  factory RoomEffect.fromJson(Map<String, dynamic> json) =>
      _$RoomEffectFromJson(json);

  /// `effects/{effectId}` は id がパスのキーであり値の中には無いため、
  /// 呼び出し側から id を別途渡して合成する。
  factory RoomEffect.fromMap(String id, Map<dynamic, dynamic> raw) =>
      RoomEffect.fromJson({...rtdbMapToJson(raw), 'id': id});
}
