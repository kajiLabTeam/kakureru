#!/usr/bin/env bash
# `flutter run` のラッパー。CARTO_API_KEY・PHOTO_API_BASE_URL(dart_defines.json)を毎回手で
# --dart-define-from-file 付きで指定しなくて済むようにするためのもの。
# 使い方: ./scripts/run.sh [flutter runに渡す追加引数、例: -d <device>]
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

exec flutter "${args[@]}" "$@"
