import 'package:freezed_annotation/freezed_annotation.dart';

/// 特典が誰に効くか。カードには必ずこれを書く(鬼に効くものと自分に効く
/// ものが混ざるため)。
enum RewardTarget {
  /// 鬼に効く。効果はルーム全員の端末で同じ見え方にする。
  demon,

  /// 引いた本人にだけ効く。
  self,
}

/// ミッションの特典。RTDBの `missions/{id}/reward` と
/// `effects/{effectId}/type` に書く文字列を持つ。
///
/// ハズレは作らない。抽選はクライアントで選んでよい(身内で遊ぶ前提)。
@JsonEnum(valueField: 'raw')
enum RewardType {
  /// 30秒、鬼の端末で Wi-Fi と気圧の手がかりを隠す。
  blockClues(
    raw: 'block_clues',
    title: '鬼の手がかりを止める',
    description: '30秒のあいだ、鬼は Wi-Fi と気圧を見られなくなる',
    target: RewardTarget.demon,
    duration: Duration(seconds: 30),
  ),

  /// 30秒、逃走者の地図で鬼のピンを2倍にする。
  bigDemonIcon(
    raw: 'big_demon_icon',
    title: '鬼のアイコンを大きくする',
    description: '地図でひと目で分かるようになる',
    target: RewardTarget.demon,
    duration: Duration(seconds: 30),
  ),

  /// 引いた本人の次の撮影タイムを1回飛ばす(回数ものなので時間は0)。
  skipFootPhoto(
    raw: 'skip_foot_photo',
    title: '足元写真を1回まぬがれる',
    description: '次の撮影タイムを飛ばせる',
    target: RewardTarget.self,
    duration: Duration.zero,
  );

  const RewardType({
    required this.raw,
    required this.title,
    required this.description,
    required this.target,
    required this.duration,
  });

  /// RTDBに書く文字列。
  final String raw;

  /// カードの見出し。
  final String title;

  /// カードの説明文。
  final String description;

  /// 誰に効くか。
  final RewardTarget target;

  /// 効いている時間。回数もの([skipFootPhoto])は0。
  final Duration duration;

  /// [raw]から引く。知らない値ならnull(新しい版の端末が書いた特典など)。
  static RewardType? fromRaw(String? raw) {
    for (final type in values) {
      if (type.raw == raw) return type;
    }
    return null;
  }
}
