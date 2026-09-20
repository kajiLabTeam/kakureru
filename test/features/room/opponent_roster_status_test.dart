import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/opponent_roster_status.dart';

void main() {
  group('describeEmptyOpponentReason', () {
    test('対象役割の相手が0人なら noOpponentsInRoom', () {
      final reason = describeEmptyOpponentReason(
        opponentCountInRoom: 0,
        hiddenByVisibility: false,
      );
      expect(reason, EmptyOpponentReason.noOpponentsInRoom);
    });

    test('相手が0人なら、可視性ディレイ中でも「居ない」が優先される', () {
      // 0人のときは「見えない」も何も無いため、ディレイの案内を出しても
      // 意味がない(実際には起こりにくいが、分岐の優先順位を固定しておく)。
      final reason = describeEmptyOpponentReason(
        opponentCountInRoom: 0,
        hiddenByVisibility: true,
      );
      expect(reason, EmptyOpponentReason.noOpponentsInRoom);
    });

    test('相手が居て可視性ディレイ中なら hiddenByVisibility', () {
      final reason = describeEmptyOpponentReason(
        opponentCountInRoom: 2,
        hiddenByVisibility: true,
      );
      expect(reason, EmptyOpponentReason.hiddenByVisibility);
    });

    test('相手が居て見えてもいいなら notDetected', () {
      final reason = describeEmptyOpponentReason(
        opponentCountInRoom: 2,
        hiddenByVisibility: false,
      );
      expect(reason, EmptyOpponentReason.notDetected);
    });
  });

  group('emptyOpponentMessage', () {
    test('鬼視点で逃走者が0人なら「全員捕まりました」', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.demon,
        opponentCountInRoom: 0,
        hiddenReason: null,
      );
      expect(message.headline, '逃走者は全員捕まりました');
      expect(message.detail, isNotNull);
    });

    test('逃走者視点で鬼が0人なら「まだ鬼がいません」', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.fugitive,
        opponentCountInRoom: 0,
        hiddenReason: null,
      );
      expect(message.headline, 'まだ鬼がいません');
    });

    test('可視性ディレイ中は、見出しに相手の役割・補足に理由を出す', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.fugitive,
        opponentCountInRoom: 1,
        hiddenReason: 'あと20秒で表示されます',
      );
      expect(message.headline, '鬼の位置はまだ見えません');
      expect(message.detail, 'あと20秒で表示されます');
    });

    test('鬼視点の可視性ディレイ中は、逃走者の位置が見えないと出す', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.demon,
        opponentCountInRoom: 3,
        hiddenReason: '鬼の放出まで 2:31',
      );
      expect(message.headline, '逃走者の位置はまだ見えません');
      expect(message.detail, '鬼の放出まで 2:31');
    });

    test('相手は居るが未検知なら「検知なし」に補足を添える', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.demon,
        opponentCountInRoom: 2,
        hiddenReason: null,
      );
      expect(message.headline, '検知なし');
      // 「相手が居ない」と区別が付くよう、居ることを明示する(issue #30)。
      expect(message.detail, contains('逃走者はいます'));
    });
  });
}
