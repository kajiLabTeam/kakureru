import 'package:freezed_annotation/freezed_annotation.dart';

part 'mission_notice.freezed.dart';

/// ミッションのお知らせの種類(逃走者にだけ出す)。
enum MissionNoticeKind {
  /// ミッションが出た。
  created,

  /// のこり1分で、まだ空いている地点がある。
  oneMinuteLeft,

  /// 終わった(すべて取られた・期限切れ)。
  finished,
}

/// ミッションのお知らせ1件。アプリを開いていればバナー、閉じていれば
/// OSの通知として出す(`MissionController`)。
@freezed
abstract class MissionNotice with _$MissionNotice {
  const factory MissionNotice({
    required MissionNoticeKind kind,
    required String missionId,
    required String message,
  }) = _MissionNotice;

  const MissionNotice._();

  /// 同じお知らせを二度出さないためのキー。
  String get key => '$missionId/${kind.name}';
}
