#!/bin/bash
# コンテナのエントリポイント。
# root: ファイアウォール適用 → git認証設定 → リポジトリclone/fetch → 非rootへ降格してnight_runner.pyを起動。
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN が設定されていない(GitHub操作に必須)}"
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY が設定されていない(claude -pの認証に必須)}"

echo "[entrypoint] applying network egress allowlist..."
/usr/local/bin/init-firewall.sh

REPO_URL="${NIGHT_RUN_REPO_URL:-https://github.com/kajiLabTeam/kakureru.git}"
REPO_DIR="${NIGHT_RUN_REPO_DIR:-/workdir/repo}"
STATE_FILE_PATH="${NIGHT_RUN_STATE_FILE:-/workdir/state/night-run-state.json}"
STATE_DIR="$(dirname "$STATE_FILE_PATH")"

echo "[entrypoint] configuring GitHub credential helper..."
# GH_TOKENはgh CLIが自動的に認識するので、gitの認証もgh経由のcredential helperに委ねる。
# システム全体(/etc/gitconfig)に設定することで、あとで降格するrunnerユーザーからも使える。
git config --system credential.helper '!gh auth git-credential'
git config --system --add safe.directory "$REPO_DIR"

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "[entrypoint] cloning $REPO_URL into $REPO_DIR ..."
    git clone "$REPO_URL" "$REPO_DIR"
else
    echo "[entrypoint] $REPO_DIR already exists, fetching..."
    git -C "$REPO_DIR" fetch origin
fi

mkdir -p "$STATE_DIR"

if [ ! -f "$STATE_FILE_PATH" ]; then
    echo "[entrypoint] FATAL: state file が見つからない ($STATE_FILE_PATH)。" >&2
    echo "  ヒアリングSkill(.claude/skills/night-run-hearing/)で night-run-state.json を書き出してから起動すること。" >&2
    exit 1
fi

chown -R runner:runner /workdir

echo "[entrypoint] starting night_runner.py as non-root user 'runner'..."
exec runuser -u runner -- env \
    "HOME=/home/runner" \
    "PATH=$PATH" \
    "NIGHT_RUNNER_SANDBOX=1" \
    "NIGHT_RUN_REPO_DIR=$REPO_DIR" \
    "NIGHT_RUN_STATE_FILE=$STATE_FILE_PATH" \
    "NIGHT_RUN_MAX_BUDGET_USD=${NIGHT_RUN_MAX_BUDGET_USD:-15}" \
    "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" \
    "GH_TOKEN=$GH_TOKEN" \
    python3 "$REPO_DIR/night-run/night_runner.py"
