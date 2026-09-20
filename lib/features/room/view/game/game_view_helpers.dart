/// ゲーム画面(`view/game/`配下)の各ウィジェットが共有する小さなヘルパー。
///
/// 地図と相手詳細カードの両方から使うものだけをここに置く。片方からしか
/// 使わないものは、その使う側のファイルに置いたままにする。
library;

import 'package:flutter/material.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/room/calibration_status.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// 自分自身を表す色(青)。docs/ui-mockup-2a.htmlの配色ルール
/// (赤=鬼/青=自分/緑=逃走者)に合わせている。
const selfColor = Color(0xFF3B82F6);

/// 役割に対応する表示色。地図のピンと上下バーの両方で使う。
/// role_theme.dartと同じ配色(鬼=赤/逃走者=緑)に揃え、役割が不明な間は
/// グレーにする。
Color colorForRole(UserRole? role) {
  return role == null ? Colors.grey : roleThemeOf(role).color;
}

/// [colorForRole]が返す色を指す日本語の色名。
///
/// 相手詳細カードの「青を緑に近づけよう」のように、**画面上の点の色を
/// 名指しして操作を説明する**ために使う。役割が不明なときの'グレー'は
/// [colorForRole]のフォールバックに合わせたもので、通常は通らない
/// (相手一覧は役割で絞ってから作られるため)。
String colorNameForRole(UserRole? role) {
  switch (role) {
    case UserRole.demon:
      return '赤';
    case UserRole.fugitive:
      return '緑';
    case null:
      return 'グレー';
  }
}

/// [users]から指定uidの参加者を探す。居なければnull。
RoomUser? findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}

/// [users]から指定uidの役割を探す。uidがnull、または居なければnull。
UserRole? roleOf(List<RoomUser> users, String? uid) {
  if (uid == null) return null;
  return findUser(users, uid)?.role;
}

/// [entries]から指定uidの3段階判定を探す。uidがnull、または該当エントリが
/// 無ければnull(検知なし扱い)。
ProximityLevel? levelFor(List<WifiProximityEntry> entries, String? uid) {
  if (uid == null) return null;
  for (final entry in entries) {
    if (entry.uid == uid) return entry.level;
  }
  return null;
}

/// [positions]から指定uidの気圧上下判定を探す。uidがnull、または該当が
/// 無ければnull(検知なし扱い)。
RelativeVerticalPosition? verticalFor(
  List<RelativeVerticalPosition> positions,
  String? uid,
) {
  if (uid == null) return null;
  for (final position in positions) {
    if (position.uid == uid) return position;
  }
  return null;
}

/// 自分がキャリブレーション済みかどうか。
///
/// 待機画面と同じ判定を使う(ホストは meta/basePressure、参加者は自分の
/// users/{uid}/pressureOffset の有無)。以前はここで同じ条件を手書きして
/// いたが、待機画面側の[calibrationStatusFor]と二重管理になるため委譲する。
bool isCalibrated(Room room, String? myUid) {
  if (myUid == null) return false;
  final isHost = myUid == room.hostUserId;
  final status = calibrationStatusFor(
    isHost: isHost,
    // この関数は「済んでいるか」だけを見るので、センサーの有無は
    // done の判定に影響しない(未済がpendingかunavailableかの区別だけ)。
    sensorAvailable: null,
    basePressure: room.basePressure,
    pressureOffset: findUser(room.users, myUid)?.pressureOffset,
  );
  return status == CalibrationStatus.done;
}
