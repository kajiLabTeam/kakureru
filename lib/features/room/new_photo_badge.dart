import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 写真タブの「新着」の赤い点を数え始めてよい程度に、読み込みが済んだか。
///
/// 値が届いたときに加えて、エラーで終わったときも済んだとみなす(枚数は
/// 0枚として数える)。「捕まえた瞬間」の写真(`catchPhotos`)を読めない
/// とき(例: RTDBのルールが未反映で読み取りを拒否された)に、足元の写真の
/// 新着の点までずっと出なくなるのを防ぐため(issue #140)。
bool isSettledForPhotoBadge(AsyncValue<Object?> value) =>
    value.hasValue || value.hasError;
