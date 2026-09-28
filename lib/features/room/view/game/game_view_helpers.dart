/// ゲーム画面(`view/game/`配下)の各ウィジェットが共有する小さなヘルパー。
///
/// 地図・チップ・手がかりカードのうち複数から使うものだけをここに置く。片方からしか
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

/// 自分自身を表す色(青)。ゲーム画面モックの配色ルール
/// (赤=鬼/青=自分/緑=逃走者)に合わせている。
const selfColor = Color(0xFF2F5FC4);

/// 役割に対応する表示色。地図のピンと上下バーの両方で使う。
/// role_theme.dartと同じ配色(鬼=赤/逃走者=緑)に揃え、役割が不明な間は
/// グレーにする。
Color colorForRole(UserRole? role) {
  return role == null ? Colors.grey : roleThemeOf(role).color;
}

/// 手がかり表示(チップ・手がかりカード)で使う、相手の役割ごとの色。
///
/// - `pin`: 点・メーターの塗り(地図のピンと同じ)
/// - `border`: 選ばれたチップの枠(白文字を載せる面と同じ濃さ)
/// - `tint`: 判定の丸・「近づいた」タグの下地
/// - `chipTint`: 選ばれたチップの下地
/// - `ink`: 薄い下地の上に載せる文字・アイコンの色
///
/// 逃走者の`pin`(#4A9C5D)は薄い下地の上だと文字として読みにくいため、
/// 文字には一段濃い`ink`を使う(ゲーム画面モックの配色)。
typedef OpponentAccent = ({
  Color pin,
  Color border,
  Color tint,
  Color chipTint,
  Color ink,
});

/// [role]に対応する[OpponentAccent]。役割が不明な間はグレーにする。
OpponentAccent opponentAccentOf(UserRole? role) {
  switch (role) {
    case UserRole.demon:
      return (
        pin: roleThemeOf(UserRole.demon).color,
        border: roleThemeOf(UserRole.demon).surfaceColor,
        tint: const Color(0xFFFCEDEC),
        chipTint: const Color(0xFFFCF0EF),
        ink: const Color(0xFFC0343A),
      );
    case UserRole.fugitive:
      return (
        pin: roleThemeOf(UserRole.fugitive).color,
        border: roleThemeOf(UserRole.fugitive).surfaceColor,
        tint: const Color(0xFFEFF6F0),
        chipTint: const Color(0xFFEFF6F0),
        ink: const Color(0xFF2F6B3D),
      );
    case null:
      return (
        pin: Colors.grey,
        border: Colors.grey,
        tint: const Color(0xFFF1EFE9),
        chipTint: const Color(0xFFF1EFE9),
        ink: const Color(0xFF6B6A64),
      );
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
