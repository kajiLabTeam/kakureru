#!/bin/bash
# コンテナのエントリポイント。
# root: ファイアウォール適用 → git認証設定 → リポジトリclone/fetch → 非rootへ降格してnight_runner.pyを起動。
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN が設定されていない(GitHub操作に必須)}"
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "FATAL: ANTHROPIC_API_KEY か CLAUDE_CODE_OAUTH_TOKEN のどちらかが必要(claude -pの認証に必須)" >&2
    exit 1
fi

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
runner_env=(
    "HOME=/home/runner"
    "PATH=$PATH"
    "NIGHT_RUNNER_SANDBOX=1"
    "NIGHT_RUN_REPO_DIR=$REPO_DIR"
    "NIGHT_RUN_STATE_FILE=$STATE_FILE_PATH"
    "NIGHT_RUN_MAX_BUDGET_USD=${NIGHT_RUN_MAX_BUDGET_USD:-15}"
    "GH_TOKEN=$GH_TOKEN"
)
# ANTHROPIC_API_KEY(APIキー課金)かCLAUDE_CODE_OAUTH_TOKEN(claude setup-tokenで発行する
# サブスクリプション連携の長期トークン)のどちらかで動く。両方渡さない
# (空文字を渡すと「設定されているが空」という別の状態になり、未設定より紛らわしいため)。
[ -n "${ANTHROPIC_API_KEY:-}" ] && runner_env+=("ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && runner_env+=("CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN")

exec runuser -u runner -- env "${runner_env[@]}" python3 "$REPO_DIR/night-run/night_runner.py"
