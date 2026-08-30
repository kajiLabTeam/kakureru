import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game_page.dart';

void main() {
  group('markerLabelFor (issue #13: GPSピンが誰のものか分かるようにする)', () {
    const myUid = 'uid-me';
    const otherUid = 'uid-other';

    RoomUser makeUser({required String id, required String displayName}) {
      return RoomUser(id: id, displayName: displayName);
    }

    test('自分のUIDなら「自分」を返す', () {
      final label = markerLabelFor(
        uid: myUid,
        myUid: myUid,
        user: makeUser(id: myUid, displayName: 'Alice'),
      );
      expect(label, '自分');
    });

    test('自分のUIDならuserがnullでも「自分」を返す', () {
      final label = markerLabelFor(uid: myUid, myUid: myUid, user: null);
      expect(label, '自分');
    });

    test('他プレイヤーのUIDならdisplayNameを返す', () {
      final label = markerLabelFor(
        uid: otherUid,
        myUid: myUid,
        user: makeUser(id: otherUid, displayName: 'Bob'),
      );
      expect(label, 'Bob');
    });

    test('他プレイヤーのdisplayNameが空なら「?」を返す', () {
      final label = markerLabelFor(
        uid: otherUid,
        myUid: myUid,
        user: makeUser(id: otherUid, displayName: ''),
      );
      expect(label, '?');
    });

    test('他プレイヤーのuserがnullなら「?」を返す', () {
      final label = markerLabelFor(uid: otherUid, myUid: myUid, user: null);
      expect(label, '?');
    });

    test('myUidがnullのとき他プレイヤーのdisplayNameを返す', () {
      final label = markerLabelFor(
        uid: otherUid,
        myUid: null,
        user: makeUser(id: otherUid, displayName: 'Carol'),
      );
      expect(label, 'Carol');
    });
  });
}
