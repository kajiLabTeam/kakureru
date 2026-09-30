import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/new_photo_badge.dart';

void main() {
  group('isSettledForPhotoBadge', () {
    test('値が届いていれば済んだとみなす', () {
      expect(isSettledForPhotoBadge(const AsyncValue.data(<int>[])), isTrue);
    });

    // catchPhotosの読み取りが拒否されても、足元の写真の赤い点は出したい。
    test('エラーで終わっても済んだとみなす', () {
      expect(
        isSettledForPhotoBadge(
          AsyncValue<List<int>>.error(Exception('denied'), StackTrace.empty),
        ),
        isTrue,
      );
    });

    test('読み込み中はまだ済んでいない', () {
      expect(isSettledForPhotoBadge(const AsyncValue<int>.loading()), isFalse);
    });
  });
}
