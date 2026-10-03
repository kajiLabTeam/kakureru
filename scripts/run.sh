#!/usr/bin/env bash
# `flutter run` のラッパー。CARTO_API_KEY・PHOTO_API_BASE_URL(dart_defines.json)を毎回手で
# --dart-define-from-file 付きで指定しなくて済むようにするためのもの。
# 使い方: ./scripts/run.sh [--mission-debug] [flutter runに渡す追加引数、例: -d <device>]
#   --mission-debug: --dart-define=DEBUG_MISSION=true を足す(ミッションカードの下に
#                    「着いたことにする」、ミッションが無い間は「ミッションをいますぐ
#                    出す」(回を選んで即発動)が出る。リリースビルドでは出ない)
set -euo pipefail

cd "$(dirname "$0")/.."

defines_file="dart_defines.json"
args=(run)

if [[ -f "$defines_file" ]]; then
  args+=("--dart-define-from-file=$defines_file")
else
  echo "警告: $defines_file が見つかりません。地図タイルに透かしが表示され、写真も撮れません。" >&2
  echo "  cp dart_defines.example.json $defines_file で作成し、CARTO_API_KEY と PHOTO_API_BASE_URL を設定してください(README参照)。" >&2
fi

# --mission-debug だけ抜き取り、残りはそのまま flutter run に渡す。
for arg in "$@"; do
  if [[ "$arg" == "--mission-debug" ]]; then
    args+=("--dart-define=DEBUG_MISSION=true")
  else
    args+=("$arg")
  fi
done

exec flutter "${args[@]}"
