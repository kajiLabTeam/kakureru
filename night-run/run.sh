#!/bin/bash
# night-run/run.sh — 夜間実行コンテナのホスト側ラッパー(0章のサンドボックス実行環境)
#
# 使い方:
#   night-run/run.sh build   # イメージをビルド
#   night-run/run.sh start [--retry-failed] [--use-api-key]
#                             # コンテナを起動(デタッチ)。--rm付きなので終了後に
#                             #   コンテナは自動で削除される(docker logsでの事後確認は
#                             #   できなくなる。alerts.log/night-run-state.jsonがそのための
#                             #   永続化された確認先)。
#                             #   事前に .claude/skills/night-run-hearing/SKILL.md で
#                             #   night-run/state/night-run-state.json を作成しておくこと
#                             #   --retry-failed: 起動前に、state内のstatus="failed"な
#                             #   タスクをpendingへ戻す(failure_reason/diagnostic_branch/
#                             #   step/review_roundは消す)。デバッグ中に毎回エディタで
#                             #   手で書き換える手間を省くためのもの
#                             #   --use-api-key: デフォルトのCLAUDE_CODE_OAUTH_TOKENの代わりに
#                             #   ANTHROPIC_API_KEYを使う(明示的に選んだときだけ)。Claude Code
#                             #   のセッション内でこのスクリプトを実行すると、Claude Code自身が
#                             #   プロキシ用のANTHROPIC_API_KEYを環境に注入していることがあるが、
#                             #   このフラグを付けない限りそれは無視される
#   night-run/run.sh logs    # ログを追う(そのまま朝まで放置してよい)
#   night-run/run.sh stop    # コンテナを止める(進行中のタスクは完走できず中断される)
#   night-run/run.sh rm      # 停止済みコンテナを削除する(--rm運用では通常不要だが、
#                             #   異常終了時などに残った場合の後始末として残す)
#
# 必須の環境変数(ホスト側で事前に export しておく。詳細はnight-run/README.md):
#   CLAUDE_CODE_OAUTH_TOKEN (デフォルト) か ANTHROPIC_API_KEY(--use-api-key時)   claude -p の認証
#   GH_TOKEN            git push / gh pr create の認証(対象repoへの書き込み権限が要る)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="night-runner"
CONTAINER_NAME="night-runner"
VOLUME_NAME="night-runner-workdir"
STATE_DIR="$REPO_ROOT/night-run/state"

cmd="${1:-}"

require_env() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        echo "エラー: 環境変数 $name が設定されていない。night-run/README.md のセットアップ手順を確認すること。" >&2
        exit 1
    fi
}

case "$cmd" in
    build)
        docker build -t "$IMAGE_NAME" "$REPO_ROOT/night-run/docker"
        ;;
    start)
        shift
        retry_failed=0
        use_api_key=0
        for arg in "$@"; do
            case "$arg" in
                --retry-failed) retry_failed=1 ;;
                --use-api-key) use_api_key=1 ;;
                *)
                    echo "エラー: 不明なオプション '$arg'" >&2
                    exit 1
                    ;;
            esac
        done

        require_env GH_TOKEN

        # CLAUDE_CODE_OAUTH_TOKENとANTHROPIC_API_KEYを両方渡すと、claude CLIが
        # ANTHROPIC_API_KEYを優先してしまい、有効なCLAUDE_CODE_OAUTH_TOKENがあっても
        # 無視される(2026-09-13の実運用で確認済み)。特にClaude Codeのセッション内で
        # このスクリプトを実行していると、Claude Code自身がプロキシ用の
        # ANTHROPIC_API_KEYを環境に注入しているため、黙って両方渡ると必ずこれで
        # 事故る。--use-api-keyで明示的に選ばれた方だけをコンテナに渡す(選ばれな
        # かった方は環境にあっても一切渡さない)。
        if [ "$use_api_key" = "1" ]; then
            require_env ANTHROPIC_API_KEY
            auth_env_args=(-e ANTHROPIC_API_KEY)
        else
            if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
                echo "エラー: CLAUDE_CODE_OAUTH_TOKEN が設定されていない。night-run/README.md のセットアップ手順を確認すること。" >&2
                echo "  ANTHROPIC_API_KEYを使いたい場合は --use-api-key を付けて実行すること。" >&2
                exit 1
            fi
            auth_env_args=(-e CLAUDE_CODE_OAUTH_TOKEN)
        fi

        if [ ! -f "$STATE_DIR/night-run-state.json" ]; then
            echo "エラー: $STATE_DIR/night-run-state.json が無い。先にヒアリングSkillで作成すること。" >&2
            exit 1
        fi

        if [ "$retry_failed" = "1" ]; then
            echo "[run.sh] --retry-failed: failedタスクをpendingへ戻します..."
            python3 - "$STATE_DIR/night-run-state.json" <<'PYEOF'
import json
import sys

path = sys.argv[1]
with open(path) as f:
    state = json.load(f)

changed = 0
for t in state.get("tasks", []):
    if t.get("status") == "failed":
        t["status"] = "pending"
        for key in ("failure_reason", "diagnostic_branch", "step", "review_round"):
            t.pop(key, None)
        changed += 1

with open(path, "w") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"[run.sh] {changed}件のfailedタスクをpendingに戻しました。")
PYEOF
        fi

        mkdir -p "$STATE_DIR"
        docker volume create "$VOLUME_NAME" >/dev/null

        docker_env_args=(-e GH_TOKEN "${auth_env_args[@]}")

        docker run -d --rm \
            --name "$CONTAINER_NAME" \
            --cap-add=NET_ADMIN --cap-add=NET_RAW \
            -v "$VOLUME_NAME:/workdir" \
            -v "$STATE_DIR:/workdir/state" \
            "${docker_env_args[@]}" \
            -e NIGHT_RUN_REPO_URL="${NIGHT_RUN_REPO_URL:-https://github.com/kajiLabTeam/kakureru.git}" \
            -e NIGHT_RUN_MAX_BUDGET_USD="${NIGHT_RUN_MAX_BUDGET_USD:-15}" \
            "$IMAGE_NAME"
        echo "起動した。ログ確認: night-run/run.sh logs / 進捗確認: night-run/state/night-run-state.json, alerts.log"
        ;;
    logs)
        docker logs -f "$CONTAINER_NAME"
        ;;
    stop)
        docker stop "$CONTAINER_NAME"
        ;;
    rm)
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
        ;;
    *)
        echo "使い方: $0 {build|start [--retry-failed] [--use-api-key]|logs|stop|rm}" >&2
        exit 1
        ;;
esac
