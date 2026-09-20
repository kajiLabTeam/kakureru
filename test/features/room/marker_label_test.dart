import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';

void main() {
  group('markerLabelFor (issue #13: GPSピンが誰のものか分かるようにする)', () {
    const myUid = 'uid-me';
    const otherUid = 'uid-other';

    test('自分のUIDなら「自分」を返す', () {
      final label = markerLabelFor(
        uid: myUid,
        myUid: myUid,
        displayName: 'Alice',
        role: null,
      );
      expect(label, '自分');
    });

    test('自分のUIDならdisplayNameがnullでも「自分」を返す', () {
      final label = markerLabelFor(
        uid: myUid,
        myUid: myUid,
        displayName: null,
        role: null,
      );
      expect(label, '自分');
    });

    test('他プレイヤーのUIDならdisplayNameを返す', () {
      final label = markerLabelFor(
        uid: otherUid,
        myUid: myUid,
        displayName: 'Bob',
        role: null,
      );
      expect(label, 'Bob');
    });

    test('他プレイヤーのdisplayNameが空なら「?」を返す', () {
      final label = markerLabelFor(
        uid: otherUid,
        myUid: myUid,
        displayName: '',
        role: null,
      );
      expect(label, '?');
    });

    test('他プレイヤーのdisplayNameがnullなら「?」を返す', () {
      final label = markerLabelFor(
        uid: otherUid,
        myUid: myUid,
        displayName: null,
        role: null,
      );
      expect(label, '?');
    });

    test('myUidがnullのとき他プレイヤーのdisplayNameを返す', () {
      final label = markerLabelFor(
        uid: otherUid,
        myUid: null,
        displayName: 'Carol',
        role: null,
      );
      expect(label, 'Carol');
    });

    group('役割表記(issue #42: 地図ピンの見分けやすさ改善)', () {
      test('自分が鬼なら「自分（鬼）」を返す', () {
        final label = markerLabelFor(
          uid: myUid,
          myUid: myUid,
          displayName: null,
          role: UserRole.demon,
        );
        expect(label, '自分（鬼）');
      });

      test('自分が逃走者なら「自分（逃走者）」を返す', () {
        final label = markerLabelFor(
          uid: myUid,
          myUid: myUid,
          displayName: null,
          role: UserRole.fugitive,
        );
        expect(label, '自分（逃走者）');
      });

      test('他プレイヤーが鬼なら名前に「（鬼）」が付く', () {
        final label = markerLabelFor(
          uid: otherUid,
          myUid: myUid,
          displayName: 'Bob',
          role: UserRole.demon,
        );
        expect(label, 'Bob（鬼）');
      });

      test('他プレイヤーが逃走者なら名前に「（逃走者）」が付く', () {
        final label = markerLabelFor(
          uid: otherUid,
          myUid: myUid,
          displayName: 'Bob',
          role: UserRole.fugitive,
        );
        expect(label, 'Bob（逃走者）');
      });

      test('役割が未知(null)なら役割表記を付けない(断定しない)', () {
        final label = markerLabelFor(
          uid: otherUid,
          myUid: myUid,
          displayName: 'Bob',
          role: null,
        );
        expect(label, 'Bob');
      });
    });
  });
}
