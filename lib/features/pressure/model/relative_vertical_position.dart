import 'package:freezed_annotation/freezed_annotation.dart';

part 'relative_vertical_position.freezed.dart';

/// 自分から見た、他の参加者1人分の相対的な高さ。
///
/// deltaMeters が正なら相手が自分より上、負なら下
@freezed
abstract class RelativeVerticalPosition with _$RelativeVerticalPosition {
  const factory RelativeVerticalPosition({required String uid, required double deltaMeters}) =
      _RelativeVerticalPosition;
}
