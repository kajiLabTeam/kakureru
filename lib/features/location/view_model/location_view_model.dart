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

@freezed
abstract class LocationState with _$LocationState {
  const factory LocationState({
    @Default([]) List<UserLocation> locations,
    @Default(false) bool permissionDenied,
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
  /// 起動時に済ませておく。結果は permissionDenied に反映する。
  ///
  /// permission_handler / flutter_foreground_task 側の例外(Activity未接続、
  /// 別のリクエストが進行中、等)を握りつぶさずpermissionDenied:trueとして
  /// 扱う。ここで例外を外へ投げると、呼び出し側がunawaitedで呼んでいる
  /// (main.dart)ため未処理の非同期エラーとして消え、画面には何も出ずに
  /// 送信だけが始まらない「無音の失敗」になってしまうため。
  Future<bool> ensurePermission() async {
    final seq = ++_permissionRequestSeq;
    try {
      final granted = await ref
          .read(locationPermissionServiceProvider)
          .ensureGranted();
      if (seq == _permissionRequestSeq) {
        state = state.copyWith(permissionDenied: !granted);
      }
      return granted;
    } on Object catch (e) {
      debugPrint('[LocationViewModel] 権限確認に失敗: $e');
      if (seq == _permissionRequestSeq) {
        state = state.copyWith(permissionDenied: true);
      }
      return false;
    }
  }

  /// ゲーム画面に入った時に呼ぶ。権限を確認し、位置送信を開始して
  /// 他ユーザーの位置の購読を始める。権限が無ければ送信は行わず、
  /// permissionDenied を立てるだけにとどめる。
  Future<void> start(String roomId) async {
    final epoch = ++_epoch;
    try {
      // 端末の位置情報(GPS)自体がOFFだと権限があっても値が取れないため、
      // 送信を始める直前のここで確認する(起動時の権限要求では見ない)。
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      // このawaitの間にGamePageが離脱されてstop()が呼ばれているかもしれ
      // ない。追い越されていたら、ここから先の送信開始・状態更新はしない。
      if (epoch != _epoch) return;

      if (!serviceEnabled || !await ensurePermission()) {
        if (epoch == _epoch) {
          state = state.copyWith(permissionDenied: true);
        }
        return;
      }
      if (epoch != _epoch) return;

      await _repo.startSendingLocation(roomId);
      if (epoch != _epoch) {
        // 送信開始が完了する前に離脱されていた。stop()側は「まだ何も
        // 始まっていない」時点で素通りしているので、ここで止めないと
        // Foreground Serviceが離脱後も送信し続けたままになる。
        await _repo.stopSendingLocation();
        return;
      }
      state = state.copyWith(permissionDenied: false, isSending: true);

      await _locationsSub?.cancel();
      _locationsSub = _repo.watchLocations(roomId).listen((locations) {
        state = state.copyWith(locations: locations);
      });
    } on Object catch (e) {
      debugPrint('[LocationViewModel] 位置送信の開始に失敗: $e');
      if (epoch == _epoch) {
        state = state.copyWith(permissionDenied: true, isSending: false);
      }
    }
  }

  /// ゲーム画面を離れた時に呼ぶ。送信・購読を止める。
  void stop() {
    _epoch++;
    _disposeSubscriptions();
    state = state.copyWith(isSending: false);
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
