import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/room/single_flight_action.dart';

/// ボタンを押して非同期処理を1回走らせる、という画面共通の手続きをまとめた
/// フック。
///
/// 「送信中フラグを立てる → try → await → catchでエラーを保持 → finallyで
/// フラグを下ろす」という同じ形が、ルーム設定・待機・ゲーム・結果の4画面で
/// 重複していた(issue #30)。あわせて、毎回書き忘れがちな2点も内側で面倒を
/// 見る:
///
/// - 二重押しの抑止([SingleFlightAction]。RTDBの往復が終わるまでボタンが
///   有効なままなことがあるため、ローカルのフラグで同期的に弾く)
/// - awaitの後の[BuildContext.mounted]チェック(画面遷移と重なると、破棄
///   済みのHookElementへのsetStateになる)
///
/// 戻り値はレコードにしている。値を保持するだけの型のためFreezedを使う
/// 規約(AGENTS.md)の対象になりそうだが、フックの戻り値はコールバックを
/// 含むうえにこのフック以外から生成されないため、クラスを増やさずに済む
/// レコードを選んだ。
///
/// 使い方:
/// ```dart
/// final save = useAsyncAction(context);
/// FilledButton(
///   onPressed: save.isRunning ? null : () => save.run(() => repo.save()),
///   child: save.isRunning ? const CircularProgressIndicator() : const Text('保存'),
/// );
/// if (save.error != null) Text(userFacingErrorMessage(save.error!));
/// ```
///
/// `error`は内部の例外そのものなので、**画面へ出すときは必ず
/// `userFacingErrorMessage`(error_message.dart)を通す**。`'失敗しました:
/// ${save.error}'` のように埋め込むと
/// `[firebase_database/permission-denied] Client doesn't have permission...`
/// のような英語の例外文がユーザーに出る(issue #95)。
AsyncAction useAsyncAction(BuildContext context) {
  final isRunning = useState(false);
  final error = useState<Object?>(null);
  final guard = useMemoized(SingleFlightAction.new);

  Future<AsyncActionResult> run(Future<void> Function() action) async {
    var result = (status: AsyncActionStatus.skipped, error: null as Object?);
    await guard.run(() async {
      isRunning.value = true;
      error.value = null;
      try {
        await action();
        result = (status: AsyncActionStatus.succeeded, error: null);
      } on Object catch (e) {
        result = (status: AsyncActionStatus.failed, error: e);
        if (context.mounted) error.value = e;
      } finally {
        if (context.mounted) isRunning.value = false;
      }
    });
    return result;
  }

  return (isRunning: isRunning.value, error: error.value, run: run);
}

/// [useAsyncAction]の戻り値。
typedef AsyncAction = ({
  /// 実行中かどうか。ボタンのdisabled・スピナー表示に使う。
  bool isRunning,

  /// 直近の実行で投げられた例外。次の実行の開始時にnullへ戻る。
  ///
  /// リビルドを経て初めて更新されるため、`await run(...)` の直後に
  /// この値を読んでも古いままになる。直後に結果で分岐したい場合は
  /// `run` の戻り値([AsyncActionResult])を使うこと。
  Object? error,

  /// 非同期処理を1回走らせる。実行中に呼ばれた分は何もしない(先勝ち)。
  Future<AsyncActionResult> Function(Future<void> Function() action) run,
});

/// [AsyncAction.run]1回分の結果。
///
/// `error`は[AsyncActionStatus.failed]のときだけ入る。await直後に読める
/// よう、[AsyncAction.error](リビルドを経て更新される)とは別に返す。
typedef AsyncActionResult = ({AsyncActionStatus status, Object? error});

/// [AsyncAction.run]1回分の顛末。
enum AsyncActionStatus {
  /// 実行して、例外を投げずに終わった。
  succeeded,

  /// 実行したが、例外を投げた。
  failed,

  /// 前の実行がまだ終わっていないため、何もしなかった(二重押し)。
  skipped,
}
