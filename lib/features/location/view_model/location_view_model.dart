import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_permission.dart';
import 'package:kakureru/features/location/repository/location_repository.dart';

part 'location_view_model.freezed.dart';

final locationRepositoryProvider = Provider((ref) => LocationRepository());

final locationPermissionServiceProvider = Provider(
  (ref) => LocationPermissionService(),
);

/// 「自分の位置が送れていない」理由。画面の警告文はこれで出し分ける。
///
/// 当初はboolを2つ(permissionDenied / sendingFailed)持っていたが、実際には
/// 同時に成り立たない排他の原因なので、両方trueという無い状態が表現できて
/// しまい、原因が増えるたびに3箇所のcopyWithを手で揃える必要があった
/// (issue #66のレビュー指摘)。1つの列挙にして、ありえない状態を作れない
/// ようにしている。
enum LocationFailure {
  /// 問題なし。
  none,

  /// 端末の位置情報(GPS)自体がOFF。
  serviceDisabled,

  /// 位置情報の権限が無い。
  locationPermission,

  /// Foreground Serviceの通知(Android 13+)が許可されていない。位置情報の
  /// 権限はあるので、設定で位置情報を見に行っても直らない。
  notificationPermission,

  /// 権限はそろっているのに、Foreground Serviceを起動できなかった。
  sendingFailed,
}

@freezed
abstract class LocationState with _$LocationState {
  const factory LocationState({
    @Default([]) List<UserLocation> locations,
    @Default(LocationFailure.none) LocationFailure failure,
    @Default(false) bool isSending,
  }) = _LocationState;
}

class LocationViewModel extends Notifier<LocationState> {
  StreamSubscription<List<UserLocation>>? _locationsSub;

  /// ensurePermission()の呼び出し順を追うためのカウンタ。
  ///
  /// アプリ起動直後(MyApp)とゲーム開始時(start())の両方がensurePermission()
  /// を呼ぶことがあり、後から呼ばれた方が先に終わるとは限らない(権限
  /// ダイアログの応答待ち時間はまちまちなため)。単純に「終わった順」で
  /// stateへ書き込むと、古い呼び出しの結果が新しい呼び出しの結果を
  /// 上書きしうるため、「一番最後に呼ばれた呼び出し」の結果だけを反映する。
  int _permissionRequestSeq = 0;

  /// start()/stop()の呼び出し世代を追うためのカウンタ。呼ぶたびに進める。
  ///
  /// start()は複数のawaitをまたぐため、待機中にGamePageが離脱されて
  /// stop()が呼ばれることがある。そのままstart()を最後まで走らせると、
  /// 「stop()した後にForeground Serviceの送信を開始してしまい、以後誰も
  /// 止めない」という事故になる。各awaitの後にこの値をチェックし、
  /// 自分より新しい呼び出しに追い越されていたら中断する。
  int _epoch = 0;

  /// [stop]が最後に打ち切った世代。
  ///
  /// [_epoch]だけでは「離脱(stop)に追い越された」のか「もう一度start()に
  /// 追い越された」のかが区別できない。後者でForeground Serviceを止めると、
  /// **新しいstart()が今まさに起動したサービスを古い呼び出しが止めてしまう**
  /// (画面は「送信中」なのに1件も送られない。issue #66のレビュー指摘)。
  /// stop()に追い越されたときだけ後始末するために、stop側の世代を覚えておく。
  int _stoppedEpoch = 0;

  // start()で最初に必要になったときに読み、以後はキャッシュを使う。
  //
  // 単純に「毎回ref.readするgetter」にすると、ref.onDispose内(dispose時)
  // にそのgetterを呼んだ際「dispose中に他のprovider操作はできない」という
  // Riverpodの制約(Ref._throwIfInvalidUsage)に触れ、破棄のたびに
  // assertion errorになる。かといってbuild()内で毎回ref.readして
  // 即キャッシュすると、一度もstart()を呼んでいない(=位置送信を一度も
  // 始めていない)状態でもLocationRepositoryの生成(内部でFirebaseへ触れる)
  // が走ってしまう。「実際に必要になるまで作らない」ことと「dispose時は
  // 新たにref.readしない」ことを両立するため、遅延生成してキャッシュする。
  LocationRepository? _repoInstance;
  LocationRepository get _repo {
    final existing = _repoInstance;
    if (existing != null) return existing;
    final created = ref.read(locationRepositoryProvider);
    _repoInstance = created;
    return created;
  }

  @override
  LocationState build() {
    ref.onDispose(_disposeSubscriptions);
    return const LocationState();
  }

  /// アプリを開いた直後に呼ぶ。位置送信は始めず、権限の要求だけを行う。
  /// ゲーム開始時にまとめて聞かれると場所の移動中に操作させることになるため、
  /// 起動時に済ませておく。結果は failure に反映する。
  ///
  /// permission_handler / flutter_foreground_task 側の例外(Activity未接続、
  /// 別のリクエストが進行中、等)を握りつぶさず権限の失敗として
  /// 扱う。ここで例外を外へ投げると、呼び出し側がunawaitedで呼んでいる
  /// (main.dart)ため未処理の非同期エラーとして消え、画面には何も出ずに
  /// 送信だけが始まらない「無音の失敗」になってしまうため。
  Future<bool> ensurePermission() async {
    final seq = ++_permissionRequestSeq;
    try {
      final result = await ref
          .read(locationPermissionServiceProvider)
          .ensureGranted();
      if (seq == _permissionRequestSeq) {
        state = state.copyWith(failure: _failureOf(result));
      }
      return result == LocationPermissionResult.granted;
    } on Object catch (e) {
      debugPrint('[LocationViewModel] 権限確認に失敗: $e');
      if (seq == _permissionRequestSeq) {
        state = state.copyWith(failure: LocationFailure.locationPermission);
      }
      return false;
    }
  }

  static LocationFailure _failureOf(LocationPermissionResult result) {
    switch (result) {
      case LocationPermissionResult.granted:
        return LocationFailure.none;
      case LocationPermissionResult.locationDenied:
        return LocationFailure.locationPermission;
      case LocationPermissionResult.notificationDenied:
        return LocationFailure.notificationPermission;
    }
  }

  /// ゲーム画面に入った時に呼ぶ。権限を確認し、位置送信を開始して
  /// 他ユーザーの位置の購読を始める。権限が無ければ送信は行わないが、
  /// 他ユーザーの位置の購読は張る。失敗した理由は failure に入れる
  /// (画面の警告文を出し分けるため)。
  ///
  /// 失敗した状態のままでも、設定で許可してアプリへ戻れば
  /// useGameSession が復帰を拾って呼び直す。何度呼んでも安全なように
  /// (_epochで世代管理しているため)作ってある。
  Future<void> start(String roomId) async {
    final epoch = ++_epoch;
    try {
      // 他の参加者の位置の購読は、自分が送れるかどうかと無関係に張る。
      // 権限が無い・送信を開始できない場合にここを飛ばすと、自分の位置が
      // 出ないだけでなく**地図・Wi-Fi距離感・気圧の上下が全部空になる**
      // (どれもlocationsを見ているため)。自分が送れないことと、相手の位置
      // を見られないことは別(issue #66のレビュー指摘)。
      await _watchLocations(roomId, epoch);
      if (epoch != _epoch) return;

      // 端末の位置情報(GPS)自体がOFFだと権限があっても値が取れないため、
      // 送信を始める直前のここで確認する(起動時の権限要求では見ない)。
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      // このawaitの間にGamePageが離脱されてstop()が呼ばれているかもしれ
      // ない。追い越されていたら、ここから先の送信開始・状態更新はしない。
      if (epoch != _epoch) return;
      if (!serviceEnabled) {
        state = state.copyWith(failure: LocationFailure.serviceDisabled);
        return;
      }

      // 失敗の理由(位置情報か通知か)はensurePermission()がstateへ入れる。
      final granted = await ensurePermission();
      if (epoch != _epoch) return;
      if (!granted) return;

      final started = await _repo.startSendingLocation(roomId);
      if (epoch != _epoch) {
        // 追い越されていた。ただし後始末は「離脱(stop)に追い越された」
        // ときだけ。新しいstart()に追い越された場合にここで止めると、
        // その新しい呼び出しが起動したばかりのサービスを消してしまう。
        if (_stoppedEpoch >= epoch) await _repo.stopSendingLocation();
        return;
      }
      if (!started) {
        // 権限はあるのにForeground Serviceを起動できなかった。以前はこの
        // 失敗を無視してisSending:trueにしていたため、画面には「送信中」と
        // 出たまま1件も送られない無音の失敗になっていた(issue #66)。
        state = state.copyWith(
          failure: LocationFailure.sendingFailed,
          isSending: false,
        );
        return;
      }
      state = state.copyWith(
        failure: LocationFailure.none,
        isSending: true,
      );
    } on Object catch (e) {
      // ここへ来るのは測位サービスの確認・送信開始・購読の失敗。権限の確認
      // 自体の失敗はensurePermission()が内部でfailureへ落とすので、ここで
      // 権限のせいにすると原因を取り違えた文言が出てしまう。
      debugPrint('[LocationViewModel] 位置送信の開始に失敗: $e');
      // 送信だけ始まっていて後段で失敗した場合、止めずに「開始できません
      // でした」と出すと、通知バーには送信中の通知が出たまま画面の案内と
      // 食い違う(issue #66のレビュー指摘)。_repoではなく_repoInstanceを
      // 見るのは、まだ一度も作っていないなら止めるものも無いため
      // (ここで作るとFirebaseに触れてしまう)。
      await _repoInstance?.stopSendingLocation();
      if (epoch == _epoch) {
        state = state.copyWith(
          failure: LocationFailure.sendingFailed,
          isSending: false,
        );
      }
    }
  }

  Future<void> _watchLocations(String roomId, int epoch) async {
    await _locationsSub?.cancel();
    if (epoch != _epoch) return;
    _locationsSub = _repo.watchLocations(roomId).listen((locations) {
      state = state.copyWith(locations: locations);
    });
  }

  /// ゲーム画面を離れた時に呼ぶ。送信・購読を止め、前のルームの状態を捨てる。
  ///
  /// このproviderはアプリの生存期間ずっと生きているので、残したものは次の
  /// ルームへそのまま持ち越される。畳むものが2つある:
  ///
  /// - `locations`: 残すと、次のルームに入った直後のまだ購読が始まっていない
  ///   間に「別の公園にいたときの自分の最後の位置」が新しいルームのエリアと
  ///   突き合わされ、開始直後にエリア外アラートが誤報を出す(issue #61)
  /// - `failure`: 残すと、次のルームの初回描画にいきなり前のルームの赤い
  ///   警告が出る(しかも復帰時の再試行がそれを見て走り出す。issue #66)
  void stop() {
    _epoch++;
    _stoppedEpoch = _epoch;
    _disposeSubscriptions();
    state = state.copyWith(
      isSending: false,
      failure: LocationFailure.none,
      locations: const [],
    );
  }

  void _disposeSubscriptions() {
    // _repoではなく_repoInstanceを直接見る。dispose時にref.read()を新たに
    // 呼ばないため(_repoの中身を参照)。start()を一度も呼んでいなければ
    // _repoInstanceはnullのままで、そもそも止めるものが無い。
    _repoInstance?.stopSendingLocation();
    _locationsSub?.cancel();
    _locationsSub = null;
  }
}

final locationViewModelProvider =
    NotifierProvider<LocationViewModel, LocationState>(
      LocationViewModel.new,
    );
