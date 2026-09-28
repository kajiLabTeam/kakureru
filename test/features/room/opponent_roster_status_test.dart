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

  group('opponentRevealRemainingSec', () {
    const releasedAt = 1000000;

    test('鬼から見た逃走者は、放出時刻に見えるようになる', () {
      expect(
        opponentRevealRemainingSec(
          viewerRole: UserRole.demon,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: 30,
          nowMillis: releasedAt - 150000,
        ),
        150,
      );
    });

    test('逃走者から見た鬼は、放出時刻+ディレイで見えるようになる', () {
      expect(
        opponentRevealRemainingSec(
          viewerRole: UserRole.fugitive,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: 30,
          nowMillis: releasedAt - 150000,
        ),
        180,
      );
    });

    test('端数の秒は切り上げる(0秒になる前に表示が消えない)', () {
      expect(
        opponentRevealRemainingSec(
          viewerRole: UserRole.demon,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: 0,
          nowMillis: releasedAt - 1500,
        ),
        2,
      );
    });

    test('既に過ぎていれば0', () {
      expect(
        opponentRevealRemainingSec(
          viewerRole: UserRole.fugitive,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: 30,
          nowMillis: releasedAt + 60000,
        ),
        0,
      );
    });

    test('放出時刻が分からなければnull', () {
      expect(
        opponentRevealRemainingSec(
          viewerRole: UserRole.fugitive,
          releasedAt: null,
          fugitiveInfoDelaySec: 30,
          nowMillis: 0,
        ),
        isNull,
      );
    });
  });

  group('emptyOpponentMessage', () {
    test('鬼視点で逃走者が0人なら「全員捕まりました」', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.demon,
        opponentCountInRoom: 0,
        hiddenByVisibility: false,
        beforeRelease: false,
        revealRemainingSec: null,
      );
      expect(message.icon, GameStatusIcon.allCaught);
      expect(message.headline, '逃走者は全員捕まりました');
      expect(message.detail, isNotNull);
      expect(message.pill, isNull);
    });

    test('逃走者視点で鬼が0人なら「まだ鬼がいません」', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.fugitive,
        opponentCountInRoom: 0,
        hiddenByVisibility: false,
        beforeRelease: true,
        revealRemainingSec: null,
      );
      expect(message.icon, GameStatusIcon.waiting);
      expect(message.headline, 'まだ鬼がいません');
    });

    test('逃走者視点の放出前は、モック03の文言といつ見えるかを出す', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.fugitive,
        opponentCountInRoom: 1,
        hiddenByVisibility: true,
        beforeRelease: true,
        revealRemainingSec: 150,
      );
      expect(message.icon, GameStatusIcon.hidden);
      expect(message.headline, '鬼の手がかりはまだ出ません');
      expect(
        message.detail,
        '放出されると、ここに鬼の近さと高さが出ます。\n'
        'それまでは、同じ逃走者の位置だけ見えます。',
      );
      expect(message.pill, 'あと 02:30 で表示されます');
    });

    test('鬼視点の放出前は、逃走者の手がかりがまだ出ないと出す', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.demon,
        opponentCountInRoom: 3,
        hiddenByVisibility: true,
        beforeRelease: true,
        revealRemainingSec: 151,
      );
      expect(message.headline, '逃走者の手がかりはまだ出ません');
      expect(message.detail, contains('同じ鬼の位置だけ'));
      expect(message.pill, 'あと 02:31 で表示されます');
    });

    test('放出後のディレイ中は「もうすぐ」と出す', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.fugitive,
        opponentCountInRoom: 1,
        hiddenByVisibility: true,
        beforeRelease: false,
        revealRemainingSec: 20,
      );
      expect(message.detail, startsWith('もうすぐ、ここに鬼の近さと高さが出ます。'));
      expect(message.pill, 'あと 00:20 で表示されます');
    });

    test('いつ見えるか分からなければ、放出待ちとだけ出す', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.demon,
        opponentCountInRoom: 3,
        hiddenByVisibility: true,
        beforeRelease: true,
        revealRemainingSec: null,
      );
      expect(message.pill, '鬼の放出を待っています');
    });

    test('相手は居るが未検知なら、居ることを明示する', () {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.demon,
        opponentCountInRoom: 2,
        hiddenByVisibility: false,
        beforeRelease: false,
        revealRemainingSec: null,
      );
      expect(message.icon, GameStatusIcon.notDetected);
      // 「相手が居ない」と区別が付くよう、居ることを明示する(issue #30)。
      expect(message.detail, contains('逃走者はいます'));
    });
  });
}
