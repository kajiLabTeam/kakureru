/// アバター表示用に名前の先頭1文字を返す。空なら「?」。
///
/// `String.substring(0, 1)`はUTF-16コードユニット単位の切り出しのため、
/// サロゲートペアを使う絵文字などが名前の先頭に来ると不正な文字になる。
/// `runes`(Unicodeコードポイント単位)から組み立てることでこれを避ける。
String avatarInitial(String name) {
  if (name.isEmpty) return '?';
  return String.fromCharCode(name.runes.first);
}
