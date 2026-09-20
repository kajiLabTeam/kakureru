import 'dart:async';

/// 権限要求を1つずつ順番に実行させるためのキュー。
///
/// permission_handler は「前のリクエストがまだ返っていないのに次を要求する」
/// ことを許さず、2つ目の要求に例外を返す。ゲーム画面に入った瞬間は位置情報
/// (LocationPermissionService)とBLE(BlePermissionService)の要求が同じ
/// フレームで発火するため、初回プレー(=両方が実際にダイアログを出す回)
/// だけこの衝突窓が開き、片方の権限要求がまるごと失敗していた(issue #66)。
/// 2回目以降は両方とも granted で即座に返るので衝突しない——「初回だけ
/// 位置が反映されない」という症状はこれが理由のひとつ。
///
/// ここでやるのは「前の要求が終わるまで次を待たせる」ことだけ。要求は捨てず、
/// 必ず順番に実行される。同じ「多重実行を防ぐ」目的でも
/// SingleFlightAction(lib/features/room/single_flight_action.dart)は
/// 先勝ちで後の呼び出しを捨てる挙動なので、権限要求には使えない
/// (捨てられた側は permissionDenied のまま二度と要求されなくなる)。
class PermissionQueue {
  /// [timeout]を省略すると[defaultTimeout]。テストからのみ短くする。
  PermissionQueue({Duration? timeout}) : _timeout = timeout ?? defaultTimeout;

  /// 1つの要求を待つ上限。これを過ぎたら[TimeoutException]にして次へ進む。
  ///
  /// permission_handler は、Activityが差し替わった(画面回転、ダイアログに
  /// 割り込まれた)場合などに、例外を投げずFutureが永久に返らないことが
  /// 知られている。キューは「前の要求が終わるまで次を待たせる」仕組みなので、
  /// 1つ返らないだけで**以後アプリ全体の権限要求が二度と走らなくなる**
  /// (BLEの広告・スキャンごと止まる)。上限を切って必ず次へ進める。
  ///
  /// 「常に許可」のように設定画面へ飛ばされる要求は、ユーザーが設定を
  /// 触って戻ってくるまで返らない。数十秒では足りないので長めに取る。
  static const defaultTimeout = Duration(minutes: 3);

  /// アプリ全体で共有するキュー。位置情報・BLEなど機能をまたいで直列化する
  /// 必要があるため、既定では各サービスがこの単一インスタンスを使う。
  static final PermissionQueue shared = PermissionQueue();

  final Duration _timeout;

  /// 最後にキューへ積んだ要求の完了を表すFuture。次の要求はこれを待ってから
  /// 走る。`_run`の中で例外もタイムアウトも捕まえて呼び出し元のFutureへ
  /// 移し替えるので、この鎖自体が止まることはない(1つ失敗・1つ返らなくても
  /// 後続は流れる)。
  Future<void> _tail = Future<void>.value();

  /// 直前の要求が終わってから[request]を実行し、その結果を返す。
  ///
  /// [request]が例外を投げた場合は、その例外をこのFutureへそのまま伝える
  /// (呼び出し側の try/catch でこれまで通り扱える)。[defaultTimeout]を
  /// 過ぎても返らない場合は[TimeoutException]になる。
  Future<T> add<T>(Future<T> Function() request) {
    final completer = Completer<T>();
    _tail = _tail.then((_) => _run(request, completer, _timeout));
    return completer.future;
  }

  static Future<void> _run<T>(
    Future<T> Function() request,
    Completer<T> completer,
    Duration timeout,
  ) async {
    try {
      completer.complete(await request().timeout(timeout));
    } on Object catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
    }
  }
}
