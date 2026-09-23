import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/photo_download_decision.dart';

void main() {
  test('200はsuccess', () {
    expect(
      judgePhotoDownloadStatusCode(200),
      PhotoDownloadOutcome.success,
    );
  });

  test('401はunauthorized', () {
    expect(
      judgePhotoDownloadStatusCode(401),
      PhotoDownloadOutcome.unauthorized,
    );
  });

  test('それ以外はotherFailure', () {
    expect(
      judgePhotoDownloadStatusCode(404),
      PhotoDownloadOutcome.otherFailure,
    );
    expect(
      judgePhotoDownloadStatusCode(500),
      PhotoDownloadOutcome.otherFailure,
    );
  });
}
