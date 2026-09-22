import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/photo_upload_decision.dart';

void main() {
  group('judgePhotoUploadStatusCode', () {
    test('204は成功', () {
      expect(
        judgePhotoUploadStatusCode(204),
        PhotoUploadOutcome.success,
      );
    });

    test('409は成功(冪等な再送)', () {
      expect(
        judgePhotoUploadStatusCode(409),
        PhotoUploadOutcome.success,
      );
    });

    test('401はunauthorized', () {
      expect(
        judgePhotoUploadStatusCode(401),
        PhotoUploadOutcome.unauthorized,
      );
    });

    test('413はtooLarge(再試行しない)', () {
      expect(
        judgePhotoUploadStatusCode(413),
        PhotoUploadOutcome.tooLarge,
      );
    });

    test('500はotherFailure(再試行してよい)', () {
      expect(
        judgePhotoUploadStatusCode(500),
        PhotoUploadOutcome.otherFailure,
      );
    });
  });
}
