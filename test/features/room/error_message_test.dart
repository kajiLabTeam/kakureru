import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/error_message.dart';

FirebaseException _firebaseError(String code) =>
    FirebaseException(plugin: 'database', code: code);

void main() {
  group('classifyUserFacingError', () {
    test('permission-deniedは権限として分類する', () {
      expect(
        classifyUserFacingError(_firebaseError('permission-denied')),
        UserFacingErrorKind.permissionDenied,
      );
    });

    test('通信できない系のcodeはネットワークとして分類する', () {
      for (final code in ['network-error', 'unavailable', 'disconnected']) {
        expect(
          classifyUserFacingError(_firebaseError(code)),
          UserFacingErrorKind.network,
          reason: 'code=$code',
        );
      }
    });

    test('SocketException・TimeoutExceptionはネットワークとして分類する', () {
      expect(
        classifyUserFacingError(const SocketException('failed')),
        UserFacingErrorKind.network,
      );
      expect(
        classifyUserFacingError(TimeoutException('timeout')),
        UserFacingErrorKind.network,
      );
    });

    test('FirebaseExceptionで上がってこない権限エラーも文面から権限として分類する', () {
      // プラグインの層をまたぐ経路では、codeを持たないただのExceptionに
      // なることがある。ここでunknownへ落ちると「時間をおいて再試行」という
      // 直らない案内になってしまう。
      expect(
        classifyUserFacingError(
          Exception(
            "permission_denied at /rooms/abc: Client doesn't have "
            'permission to access the desired data.',
          ),
        ),
        UserFacingErrorKind.permissionDenied,
      );
    });

    test('リポジトリ層の日本語の例外も「見つからない」として分類する', () {
      // joinRoomが投げるException('ルームが見つかりません')。toString()を
      // そのまま出すと`Exception: `の接頭辞が付くため、この関数を通す。
      expect(
        classifyUserFacingError(Exception('ルームが見つかりません')),
        UserFacingErrorKind.notFound,
      );
    });

    test('not-foundのcodeも「見つからない」として分類する', () {
      expect(
        classifyUserFacingError(_firebaseError('not-found')),
        UserFacingErrorKind.notFound,
      );
    });

    test('分類できない例外はunknownにする', () {
      expect(
        classifyUserFacingError(Exception('something went sideways')),
        UserFacingErrorKind.unknown,
      );
      expect(
        classifyUserFacingError(_firebaseError('database-error')),
        UserFacingErrorKind.unknown,
      );
    });
  });

  group('userFacingErrorMessage', () {
    test('原因ごとに違う日本語の案内を返す', () {
      final messages = {
        for (final error in <Object>[
          const SocketException('failed'),
          _firebaseError('permission-denied'),
          Exception('ルームが見つかりません'),
          Exception('something went sideways'),
        ])
          error: userFacingErrorMessage(error),
      };

      expect(messages.values.toSet(), hasLength(4));
      expect(
        messages[const SocketException('failed')],
        contains('ネットワーク'),
      );
      expect(
        messages[_firebaseError('permission-denied')],
        contains('許可されませんでした'),
      );
    });

    test('どの分類でも生の例外文を混ぜない', () {
      final errors = <Object>[
        _firebaseError('permission-denied'),
        _firebaseError('network-error'),
        _firebaseError('database-error'),
        Exception('ルームが見つかりません'),
        Exception('[firebase_database/boom] Client raw message'),
      ];

      for (final error in errors) {
        final message = userFacingErrorMessage(error);
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('firebase')));
        expect(message, isNot(contains('[')));
        expect(message, isNot(contains(error.toString())));
      }
    });

    test('unknownでも再試行の案内になっている(生の例外文の代わり)', () {
      expect(
        userFacingErrorMessage(Exception('想定外')),
        contains('もう一度'),
      );
    });
  });
}
