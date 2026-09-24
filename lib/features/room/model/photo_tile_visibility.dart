/// 写真一覧のタイル1枚をどう見せるかの3状態(純粋関数)。
///
/// 「見られる」写真だけが実際にダウンロードされる。ぼかし表示になる2状態
/// (`lockedCurrentSlot`/`missedPastSlot`)では、通信量・プライバシーの両面から
/// 実データを一切取得してはいけない(呼び出し側で徹底すること)。
library;

enum PhotoTileVisibility {
  /// 写真をそのまま表示できる。
  visible,

  /// 現在のスロットで、自分がまだ撮っていない。撮れば見られる。
  lockedCurrentSlot,

  /// 過去のスロットで、自分がそのとき撮っていなかった。もう見られない。
  missedPastSlot,
}

/// タイルの表示状態を決める。
///
/// - 鬼は常に`visible`(鬼は撮影しないが閲覧はできる、というゲームルール)。
/// - 逃走者は、自分がそのスロットで撮っていれば`visible`。
/// - 撮っていなければ、現在のスロットなら`lockedCurrentSlot`
///   (これから撮れば見られる)、過去のスロットなら`missedPastSlot`
///   (もう見られない)。
PhotoTileVisibility photoTileVisibilityOf({
  required bool viewerIsDemon,
  required bool viewerCapturedInSlot,
  required bool isCurrentSlot,
}) {
  if (viewerIsDemon) return PhotoTileVisibility.visible;
  if (viewerCapturedInSlot) return PhotoTileVisibility.visible;
  return isCurrentSlot
      ? PhotoTileVisibility.lockedCurrentSlot
      : PhotoTileVisibility.missedPastSlot;
}
