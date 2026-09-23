import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/photo_tile_visibility.dart';

void main() {
  test('鬼は撮っていなくても常にvisible', () {
    expect(
      photoTileVisibilityOf(
        viewerIsDemon: true,
        viewerCapturedInSlot: false,
        isCurrentSlot: true,
      ),
      PhotoTileVisibility.visible,
    );
    expect(
      photoTileVisibilityOf(
        viewerIsDemon: true,
        viewerCapturedInSlot: false,
        isCurrentSlot: false,
      ),
      PhotoTileVisibility.visible,
    );
  });

  test('現在スロットで未撮影ならlockedCurrentSlot', () {
    expect(
      photoTileVisibilityOf(
        viewerIsDemon: false,
        viewerCapturedInSlot: false,
        isCurrentSlot: true,
      ),
      PhotoTileVisibility.lockedCurrentSlot,
    );
  });

  test('過去スロットで未撮影ならmissedPastSlot', () {
    expect(
      photoTileVisibilityOf(
        viewerIsDemon: false,
        viewerCapturedInSlot: false,
        isCurrentSlot: false,
      ),
      PhotoTileVisibility.missedPastSlot,
    );
  });

  test('逃走者でも自分が撮っていればvisible(現在/過去どちらでも)', () {
    expect(
      photoTileVisibilityOf(
        viewerIsDemon: false,
        viewerCapturedInSlot: true,
        isCurrentSlot: true,
      ),
      PhotoTileVisibility.visible,
    );
    expect(
      photoTileVisibilityOf(
        viewerIsDemon: false,
        viewerCapturedInSlot: true,
        isCurrentSlot: false,
      ),
      PhotoTileVisibility.visible,
    );
  });
}
