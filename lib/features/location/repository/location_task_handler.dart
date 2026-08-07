import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

/// Foreground Service側で別isolateとして動く TaskHandler。
///
/// このisolateではFirebaseを呼ばない。Firebaseプラグインをバックグラウンド
/// isolateで初期化・使用するのは前例が少なく壊れやすいため、位置情報の取得と
/// RTDBへの書き込みの責務を分離している。ここでは位置を取得して
/// [FlutterForegroundTask.sendDataToMain] でメインisolate
/// (`LocationRepository`)へ渡すだけにし、実際のFirebase書き込みは
/// 従来通り動作確認済みのメインisolate側で行う。
class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    _sendCurrentPosition();
  }

  Future<void> _sendCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      FlutterForegroundTask.sendDataToMain({
        'lat': position.latitude,
        'lng': position.longitude,
        'altitude': position.altitude,
      });
    } on Object catch (_) {
      // 取得失敗時は今回はスキップし、次のonRepeatEventで再試行する。
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Foreground Service起動時に呼ばれるトップレベル関数。
/// PluginUtilities.getCallbackHandle の制約上、トップレベル関数(またはstatic)
/// である必要があり、@pragma('vm:entry-point') も必須。
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}
