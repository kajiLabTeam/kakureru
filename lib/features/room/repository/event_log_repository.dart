import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// `rooms/{roomId}/events/{pushKey}` に書くイベントの種類。
///
/// プレイテスト後に、エクスポートしたJSONから手で集計するための記録
/// (docs/rtdb-schema.md「events」参照)。
enum GameEventType {
  /// ホストがゲームを開始した。
  gameStarted('game_started'),

  /// 鬼が放出された(ホスト端末が検知した時刻)。
  released('released'),

  /// 逃走者が「捕まった」を申告した。uidは捕まった本人。
  caught('catch'),

  /// 指名を受諾して鬼になった(開始前の初期鬼)。
  becameDemon('became_demon'),

  /// ゲーム終了を検知した(ホスト端末が検知した時刻)。
  gameEnded('game_ended'),

  /// 足元写真のアップロードに成功した。
  photoTaken('photo_taken');

  const GameEventType(this.raw);

  /// RTDBに書く文字列。
  final String raw;
}

/// 1件のイベントとしてRTDBに書く値を組み立てる(純粋関数)。
///
/// 値の無いフィールド(`null`)はキーごと省く。`at` には[timestamp]を
/// そのまま入れる(本番では`ServerValue.timestamp`)。
Map<String, Object> buildGameEventPayload({
  required GameEventType type,
  required String uid,
  required Object timestamp,
  String? targetUid,
  double? lat,
  double? lng,
  double? accuracy,
  double? pressure,
  bool? indoor,
}) {
  return {
    'type': type.raw,
    'at': timestamp,
    'uid': uid,
    'targetUid': ?targetUid,
    'lat': ?lat,
    'lng': ?lng,
    'accuracy': ?accuracy,
    'pressure': ?pressure,
    'indoor': ?indoor,
  };
}

/// 分析用のイベントログを `rooms/{roomId}/events` に追記するリポジトリ。
///
/// 書き込みはfire-and-forget。記録に失敗してもゲームの進行を止めない
/// よう、例外は投げ返さずデバッグログにだけ出す。呼び出し側は
/// `unawaited(...)` で投げっぱなしにしてよい。
class EventLogRepository {
  /// 引数を省略すると `FirebaseDatabase.instance` を使う。
  EventLogRepository({FirebaseDatabase? db}) : _dbOverride = db;

  final FirebaseDatabase? _dbOverride;

  // RoomRepositoryと同じ理由でlateの遅延初期化にしている。Firebase未初期化
  // のテスト環境でも、ここを触るのは[log]のtry内だけなので例外は握りつぶされる。
  late final FirebaseDatabase _db = _dbOverride ?? FirebaseDatabase.instance;

  /// イベントを1件追記する。失敗しても例外は投げない。
  Future<void> log(
    String roomId, {
    required GameEventType type,
    required String uid,
    String? targetUid,
    double? lat,
    double? lng,
    double? accuracy,
    double? pressure,
    bool? indoor,
    @visibleForTesting void Function(String message)? onError,
  }) async {
    try {
      await _db
          .ref('rooms/$roomId/events')
          .push()
          .set(
            buildGameEventPayload(
              type: type,
              uid: uid,
              timestamp: ServerValue.timestamp,
              targetUid: targetUid,
              lat: lat,
              lng: lng,
              accuracy: accuracy,
              pressure: pressure,
              indoor: indoor,
            ),
          );
    } on Object catch (e) {
      (onError ?? debugPrint)('[EventLog] ${type.raw}の記録に失敗: $e');
    }
  }
}

/// [EventLogRepository]のProvider。テストでは差し替えられる。
final Provider<EventLogRepository> eventLogRepositoryProvider = Provider(
  (ref) => EventLogRepository(),
);
