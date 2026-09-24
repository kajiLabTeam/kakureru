import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo_capture_state.freezed.dart';

/// 撮影バナー(`usePhotoCaptureController`)が持つ画面ローカルな状態。
///
/// RTDBへ保存する値ではなく、GamePageが消えたら一緒に消えてよい一時状態
/// なので(AGENTS.mdの判断基準)、Riverpodではなくhooksで持つ。fromJson/toMap
/// は不要。
@freezed
abstract class PhotoCaptureState with _$PhotoCaptureState {
  const factory PhotoCaptureState({
    /// 次の撮影タイミングが来ているか。trueの間だけ撮影バナーを出す。
    @Default(false) bool isDue,

    /// アップロード中(通信・RTDB書き込み含む)か。
    @Default(false) bool isUploading,

    /// アップロードが最終的に失敗した後、手動再送のために保持している画像。
    /// 成功時・413での失敗時はnullに戻す。
    Uint8List? pendingBytes,

    /// 直近の失敗の説明文。バナーに出す。成功したらnullに戻す。
    String? lastErrorMessage,
  }) = _PhotoCaptureState;
}
