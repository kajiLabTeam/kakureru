import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/game_map_options.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/rectangle_area.dart';

/// FlutterMapが内部で行う表明と同じ検証。
///
/// MapControllerImpl.options には
/// `cameraConstraint.constrain(camera) == camera` というassertがあり、
/// これを破ると地図の組み立て時に例外が投げ続けられ、画面が固まる
/// (2026-08-11に実機で発生。initialCenterを渡さずcameraConstraintだけ
/// 付けたため、初期カメラがflutter_map既定の座標=範囲外から始まっていた)。
void expectInitialCameraSatisfiesConstraint(MapOptions options) {
  final camera = MapCamera.initialCamera(options);
  expect(
    options.cameraConstraint.constrain(camera),
    camera,
    reason: '初期カメラがcameraConstraintの外にある。FlutterMapのassertで落ちる',
  );
}

void main() {
  group('buildGameMapOptions', () {
    test('エリア指定時、初期カメラがカメラ制限を満たす(固まる不具合の再発防止)', () {
      final bounds = gameAreaBounds(
        calculateRectangleCorners(
          const LatLng(lat: 35.0, lng: 139.0),
          const LatLng(lat: 35.01, lng: 139.01),
        ),
      );

      expectInitialCameraSatisfiesConstraint(
        buildGameMapOptions(
          areaBounds: bounds,
          fallbackCenter: fallbackMapCenter,
        ),
      );
    });

    test('面積が極端に小さいエリアでも初期カメラがカメラ制限を満たす', () {
      final bounds = gameAreaBounds(
        calculateRectangleCorners(
          const LatLng(lat: 35.0, lng: 139.0),
          const LatLng(lat: 35.000001, lng: 139.000001),
        ),
      );

      expectInitialCameraSatisfiesConstraint(
        buildGameMapOptions(
          areaBounds: bounds,
          fallbackCenter: fallbackMapCenter,
        ),
      );
    });

    test(
      '経度方向に大きく広がったエリアでも初期カメラがカメラ制限を満たす'
      '(LatLngBounds.centerは大圏中心のためboundsの外へ飛び出しうる再発防止)',
      () {
        // 緯度45度・経度-100〜100(スパン200度)の細長いエリア。
        // LatLngBounds.center(大圏中心)はこのケースで緯度80度付近まで
        // 飛び出し、south/north(どちらも45度)の範囲外になる。
        // buildGameMapOptionsはsimpleCenter(単純な中点)を使うため
        // 常にbounds内に収まる。
        final bounds = gameAreaBounds(
          calculateRectangleCorners(
            const LatLng(lat: 45.0, lng: -100.0),
            const LatLng(lat: 45.0, lng: 100.0),
          ),
        )!;
        expect(
          bounds.center.latitude,
          greaterThan(bounds.north),
          reason: '前提: このケースではLatLngBounds.centerがboundsの外に出ることの確認',
        );

        expectInitialCameraSatisfiesConstraint(
          buildGameMapOptions(
            areaBounds: bounds,
            fallbackCenter: fallbackMapCenter,
          ),
        );
      },
    );

    test('エリア指定時の初期位置はエリアの単純中心(フォールバック中心ではない)', () {
      final bounds = gameAreaBounds(
        calculateRectangleCorners(
          const LatLng(lat: 35.0, lng: 139.0),
          const LatLng(lat: 35.01, lng: 139.01),
        ),
      )!;

      final options = buildGameMapOptions(
        areaBounds: bounds,
        fallbackCenter: fallbackMapCenter,
      );

      // center(大圏中心)ではなくsimpleCenter(単純な中点)を使うことの確認。
      expect(options.initialCenter, bounds.simpleCenter);
    });

    test('エリア未設定なら制限を掛けず、フォールバック中心を使う', () {
      final options = buildGameMapOptions(
        areaBounds: null,
        fallbackCenter: fallbackMapCenter,
      );

      expect(options.initialCenter, fallbackMapCenter);
      expect(options.cameraConstraint, isA<UnconstrainedCamera>());
      expectInitialCameraSatisfiesConstraint(options);
    });
  });

  group('gameAreaBounds', () {
    test('エリア未設定(空)ならnull', () {
      expect(gameAreaBounds(const []), isNull);
    });

    test('頂点が3未満ならポリゴンとして扱えないのでnull', () {
      expect(
        gameAreaBounds(const [
          LatLng(lat: 35.0, lng: 139.0),
          LatLng(lat: 34.0, lng: 140.0),
        ]),
        isNull,
      );
    });

    test('矩形の四隅から南西端・北東端を持つ矩形を作る', () {
      final bounds = gameAreaBounds(
        calculateRectangleCorners(
          const LatLng(lat: 35.0, lng: 139.0),
          const LatLng(lat: 34.0, lng: 140.0),
        ),
      )!;

      expect(bounds.south, 34.0);
      expect(bounds.north, 35.0);
      expect(bounds.west, 139.0);
      expect(bounds.east, 140.0);
    });

    test('矩形以外のポリゴンでも全頂点を含む矩形になる(頂点の並び順にも依存しない)', () {
      final bounds = gameAreaBounds(const [
        LatLng(lat: 35.0, lng: 140.0),
        LatLng(lat: 36.0, lng: 139.5),
        LatLng(lat: 34.5, lng: 139.0),
      ])!;

      expect(bounds.south, 34.5);
      expect(bounds.north, 36.0);
      expect(bounds.west, 139.0);
      expect(bounds.east, 140.0);
    });
  });

  group('describeGameAreaSizeError', () {
    test('下限未満なら小さすぎるエラーを返す', () {
      expect(
        describeGameAreaSizeError(gameAreaMinDiagonalMeters - 1),
        isNotNull,
      );
    });

    test('下限ちょうどはエラーにしない', () {
      expect(describeGameAreaSizeError(gameAreaMinDiagonalMeters), isNull);
    });

    test('上限超過なら大きすぎるエラーを返す', () {
      expect(
        describeGameAreaSizeError(gameAreaMaxDiagonalMeters + 1),
        isNotNull,
      );
    });

    test('上限ちょうどはエラーにしない', () {
      expect(describeGameAreaSizeError(gameAreaMaxDiagonalMeters), isNull);
    });

    test('下限と上限の間はエラーにしない', () {
      expect(describeGameAreaSizeError(1000), isNull);
    });
  });
}
