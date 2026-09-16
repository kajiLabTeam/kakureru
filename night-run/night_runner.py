#!/usr/bin/env python3
"""夜間自律タスク実行の外側オーケストレーター(docs/night-run-design.md 4章)。

サンドボックス化されたDockerコンテナ内で動くことを前提にしている。
ホスト側で直接実行してはならない(assert_sandbox_or_exitが拒否する)。
"""
import copy
import json
import os
import re
import signal
import subprocess
import sys
import time
import traceback
import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _state_io import atomic_write_json  # noqa: E402

REPO_DIR = os.environ.get("NIGHT_RUN_REPO_DIR", "/workdir/repo")
# state/ はgit管理下に置かない(git_cleanupのgit clean -fdで消えるのを防ぐため、
# リポジトリの外・別のbind mountに置く前提)。
STATE_FILE = os.environ.get("NIGHT_RUN_STATE_FILE", "/workdir/state/night-run-state.json")
ALERTS_LOG = os.path.join(os.path.dirname(STATE_FILE), "alerts.log")

RATE_LIMIT_PATTERN = re.compile(r"rate.?limit|429|usage limit|overloaded", re.IGNORECASE)
# サブスクリプション(Pro/Max)のレートリミットは、解除時刻をエラー本文に含むことがある。
# Claude Code CLIが返す "Claude AI usage limit reached|1757808000" 形式のepoch秒と、
# ISO8601形式の2種類を拾う(どちらも拾えなければ従来どおり指数backoffへフォールバック)。
RATE_LIMIT_RESET_EPOCH_PATTERN = re.compile(r"\|\s*(\d{10})(?!\d)")
RATE_LIMIT_RESET_ISO_PATTERN = re.compile(
    r"reset[^0-9]{0,20}(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)",
    re.IGNORECASE,
)
RATE_LIMIT_RESET_MARGIN_SECONDS = 120   # リセット時刻ちょうどに叩き直さず、少し置いてから再開する
MIN_USEFUL_REMAINING_SECONDS = 900      # 待機後にこれ以下しか残らないなら、待たずに持ち越す
DIAGNOSTIC_PREVIEW_CHARS = 4000  # alerts.logに残すstdout/stderrの上限文字数
SECRET_ENV_VARS = ("GH_TOKEN", "ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN")
MAX_RETRY_ATTEMPTS = 5          # 9.10節: backoffの上限回数
MAX_BACKOFF_SECONDS = 1800      # 9.10節: 1回あたりの待機を最大30分でキャップ

# --- 消費量の上限(サブスクリプション契約前提の既定値) -------------------------
# 既定値はClaude Pro契約を基準にしている。Proは「5時間ローリング枠+週次上限」で
# 対話利用と同じ枠を共有し、Opusは含まれない。CLIの既定モデル任せ・上限なしで
# 1晩に何件も回すと、翌日の対話利用分まで含めて枠を使い切る(2026-09-13の実行では
# 7タスクを連続実行している)。ここを明示の既定値にして、1晩の消費を予測可能にする。
#
# 解決順は 環境変数 > state の "limits" > この既定値(resolve_limits)。
# ヒアリングSkillがstateに書いた値を、ホスト側に残った環境変数が黙って上書きしない
# よう、run.sh/entrypoint.shは明示的にexportされた変数だけをコンテナへ渡す。
DEFAULT_LIMITS = {
    "model": "sonnet",              # Proでは Opus は使えない。CLI既定任せにしない
    "effort": "medium",             # 1リクエストあたりの思考量
    "reviewer_model": "",           # 空ならセッションのモデルを継承する
    "max_tasks_per_run": 2,         # 1回の実行で着手するタスク数(0で無制限)
    "max_review_rounds": 2,         # reviewerサイクルの最大ラウンド数
    "max_budget_usd_per_task": 5.0,  # claude -p --max-budget-usd に渡す値(0で指定しない)
    "max_total_budget_usd": 10.0,   # 実行全体の上限(0で無制限)。超えたら新規タスクに着手しない
}

LIMIT_ENV_VARS = {
    "model": "NIGHT_RUN_MODEL",
    "effort": "NIGHT_RUN_EFFORT",
    "reviewer_model": "NIGHT_RUN_REVIEWER_MODEL",
    "max_tasks_per_run": "NIGHT_RUN_MAX_TASKS",
    "max_review_rounds": "NIGHT_RUN_MAX_REVIEW_ROUNDS",
    "max_budget_usd_per_task": "NIGHT_RUN_MAX_BUDGET_USD",
    "max_total_budget_usd": "NIGHT_RUN_MAX_TOTAL_BUDGET_USD",
}

VALID_EFFORTS = ("low", "medium", "high", "xhigh", "max")

REVIEWER_AGENT_DEFINITION = {
    "reviewer": {
        "description": (
            "実装担当とは別視点でコードレビューを行う専任エージェント。"
            "バグ・設計・テスト漏れ・AGENTS.md/CLAUDE.mdの規約違反を指摘する。"
        ),
        "prompt": (
            "あなたはkakureruリポジトリのコードレビュー専任エージェントです。実装は行わず、"
            "レビューだけを行ってください。以下の観点で指摘してください:\n"
            "- バグ・エッジケースの考慮漏れ\n"
            "- テストの過不足(新機能・修正に対するテストの有無)\n"
            "- AGENTS.mdの規約違反(状態管理でhooks/Riverpodの使い分けを誤っていないか、"
            "データクラスがFreezed以外で書かれていないか)\n"
            "- 設計上の重大な懸念\n"
            "問題がなければ「LGTM」とだけ明確に述べてください。"
        ),
    }
}

TASK_RESULT_SCHEMA = {
    "type": "object",
    "properties": {
        "status": {"type": "string", "enum": ["success", "draft", "failed"]},
        "pr_url": {"type": ["string", "null"]},
        "branch": {"type": "string"},
        "review_round": {"type": "integer"},
        "completed_summary": {"type": "string"},
        "remaining_summary": {"type": "string"},
    },
    "required": [
        "status", "pr_url", "branch", "review_round",
        "completed_summary", "remaining_summary",
    ],
}


# --- サンドボックス確認ガード(0.2節) ---
# 環境変数だけだと `NIGHT_RUNNER_SANDBOX=1 python3 night_runner.py` とホストで
# 直接打たれたら素通りしてしまう(spoof可能)。Dockerfileがイメージにしか
# 焼き込まないマーカーファイルも合わせて確認することで、実際にそのイメージから
# 起動されたコンテナ内であることを担保する。
SANDBOX_MARKER_FILE = "/.sandbox-marker"


def assert_sandbox_or_exit():
    ok = (
        os.environ.get("NIGHT_RUNNER_SANDBOX") == "1"
        and os.path.exists(SANDBOX_MARKER_FILE)
    )
    if not ok:
        message = "致命的エラー: サンドボックス環境が確認できません(環境変数またはマーカーファイルが無い)。実行を中止します。"
        print(message, file=sys.stderr)
        notify_human(message)
        sys.exit(1)


# --- 人間への通知(9.9節) ---
def notify_human(message):
    line = f"{datetime.datetime.now().isoformat()} {message}"
    print(f"[ALERT] {message}", file=sys.stderr)
    try:
        os.makedirs(os.path.dirname(ALERTS_LOG), exist_ok=True)
        with open(ALERTS_LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass
    # 拡張ポイント: Slack Incoming Webhook等を使うなら、
    # NIGHT_RUN_ALERT_WEBHOOK_URL を見てここでPOSTする(今回のスコープ外)。


# --- 状態ファイルの読み書き(アトミック書き込み、9.7節) ---
def load_state():
    with open(STATE_FILE) as f:
        return json.load(f)


def save_state(state):
    state["last_updated"] = datetime.datetime.now().isoformat()
    atomic_write_json(STATE_FILE, state)


def _slug(text):
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", text).strip("-.")
    return slug or "task"


# --- 消費量の設定解決(環境変数 > state["limits"] > DEFAULT_LIMITS) ---
def _coerce_limit(key, raw, source):
    """設定値をDEFAULT_LIMITSと同じ型へ寄せる。

    解釈できない値が来ても例外にしない——ここは人が寝ている間に無人で動く
    区間で、設定ミス1つで起動直後に全滅するより、既定値で走り切って朝に
    alerts.logで気付ける方がよいため。"""
    default = DEFAULT_LIMITS[key]
    if isinstance(default, str):
        value = str(raw).strip()
        if key == "effort" and value and value not in VALID_EFFORTS:
            notify_human(
                f"設定 effort の値 '{value}'({source})は未知の値のため既定値 '{default}' を使います"
                f"(有効な値: {', '.join(VALID_EFFORTS)})。"
            )
            return default
        return value
    try:
        value = float(raw)
    except (TypeError, ValueError):
        notify_human(f"設定 {key} の値 '{raw}'({source})を数値として解釈できないため既定値 {default} を使います。")
        return default
    if value < 0:
        notify_human(f"設定 {key} の値 '{raw}'({source})が負のため既定値 {default} を使います。")
        return default
    return int(value) if isinstance(default, int) else value


def resolve_limits(state):
    """このタスク/実行に適用する消費量の設定を決める。

    stateに書く(ヒアリングSkillが契約プランに応じて埋める)のが基本で、
    環境変数はその場限りの上書き用。どちらも無ければDEFAULT_LIMITS。"""
    limits = dict(DEFAULT_LIMITS)
    state_limits = (state or {}).get("limits")
    if isinstance(state_limits, dict):
        for key, raw in state_limits.items():
            if key in limits and raw is not None:
                limits[key] = _coerce_limit(key, raw, 'state["limits"]')
    for key, env_name in LIMIT_ENV_VARS.items():
        raw = os.environ.get(env_name)
        if raw is not None and raw.strip() != "":
            limits[key] = _coerce_limit(key, raw, f"環境変数 {env_name}")
    return limits


def describe_limits(limits):
    def usd(value):
        return f"${value:.2f}" if value else "上限なし"

    reviewer = limits.get("reviewer_model") or "実装と同じモデル"
    return (
        f"model={limits['model']} / effort={limits['effort']} / "
        f"reviewer={reviewer} / "
        f"1回のタスク数上限={limits['max_tasks_per_run'] or '無制限'} / "
        f"レビュー最大{limits['max_review_rounds']}ラウンド / "
        f"1タスク予算={usd(limits['max_budget_usd_per_task'])} / "
        f"実行全体の予算={usd(limits['max_total_budget_usd'])}"
    )


def _task_cost_usd(task):
    """stateに記録されたそのタスクの累積コスト。未記録・型不正は0として扱う。"""
    value = (task or {}).get("total_cost_usd")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    return 0.0


def backoff_seconds(attempt):
    """9.10節: 2^(attempt-1)*60秒、上限MAX_BACKOFF_SECONDSでキャップする。"""
    return min((2 ** (attempt - 1)) * 60, MAX_BACKOFF_SECONDS)


def _envelope_is_rate_limited(envelope):
    """claude -pはAPIレベルのレートリミットをexit code 0 + JSON封筒内のis_error=true
    として返すことがある(stderrの文字列マッチだけでは拾えない)。"""
    if not isinstance(envelope, dict) or not envelope.get("is_error"):
        return False
    text = f"{envelope.get('subtype', '')} {envelope.get('result', '')}"
    return bool(RATE_LIMIT_PATTERN.search(text))


def parse_rate_limit_reset(text):
    """レートリミットの解除時刻(aware UTC)をエラー本文から拾う。拾えなければNone。

    サブスクリプション契約の枠は「5時間ローリング」で、解除まで数時間空くことが
    ある。解除時刻が分かれば無駄なリトライを撃たずにその時刻まで待てる(または
    締切に間に合わないと判断して持ち越せる)ので、拾えるものは拾う。
    タイムゾーンの無いISO表記はUTCとみなす(コンテナのTZはUTC)。"""
    if not text:
        return None
    match = RATE_LIMIT_RESET_EPOCH_PATTERN.search(text)
    if match:
        try:
            return datetime.datetime.fromtimestamp(int(match.group(1)), datetime.timezone.utc)
        except (OverflowError, OSError, ValueError):
            return None
    match = RATE_LIMIT_RESET_ISO_PATTERN.search(text)
    if match:
        raw = match.group(1).replace(" ", "T").replace("Z", "+00:00")
        try:
            parsed = datetime.datetime.fromisoformat(raw)
        except ValueError:
            return None
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=datetime.timezone.utc)
        return parsed.astimezone(datetime.timezone.utc)
    return None


def plan_rate_limit_wait(attempt, detail_text, now, hard_limit):
    """レートリミット検知時に「待つか/持ち越すか」を決める(戻り値: (action, 待機秒, 解除時刻))。

    従来は指数backoffで最大5回(合計1時間強)待ち、解消しなければfailedにしていた。
    これはAPIキー課金のレートリミット(数分〜数十分で解ける)を想定した値で、
    サブスクリプション契約の5時間枠には届かない——ほぼ確実に「1時間待ってから
    failed」になり、待ち時間もそこまでのトークンも無駄になる。そこで:

    - 解除時刻が分かり、待っても締切内に実作業の時間が残る → その時刻+マージンまで待つ
    - 残らない、または試行回数の上限に達した → 待たずに持ち越す(翌回の実行で再開)

    と決める。持ち越しはfailedではなくpendingのままなので(mark_task_deferred)、
    次回の実行がそのまま同じブランチから再開できる。"""
    reset_at = parse_rate_limit_reset(detail_text)
    if attempt > MAX_RETRY_ATTEMPTS:
        return ("defer", 0.0, reset_at)
    if reset_at is not None:
        wait_seconds = max((reset_at - now).total_seconds() + RATE_LIMIT_RESET_MARGIN_SECONDS, 0.0)
    else:
        wait_seconds = float(backoff_seconds(attempt))
    remaining_after_wait = (hard_limit - now).total_seconds() - wait_seconds
    if remaining_after_wait < MIN_USEFUL_REMAINING_SECONDS:
        return ("defer", 0.0, reset_at)
    return ("wait", wait_seconds, reset_at)


# --- git操作 ---
# git_cleanup()はAGENTS.md安全ルール1が禁じるgit reset --hard/git cleanをそのまま使う。
# .claude/hooks/deny_dangerous_bash.pyはClaude Code自身のBashツール呼び出ししか
# 検査できないため、night_runner.pyのこの生subprocess呼び出しはそのフックの対象外
# ——ここが安全に許されるのは、night_runner.py自体がDockerサンドボックス(named
# volumeへのclone、ホストリポジトリはbind mountしない)内でしか動かないことを
# assert_sandbox_or_exit()が起動時に強制しているため。この前提が崩れると
# git_cleanup()はホストの実リポジトリを容赦なく吹き飛ばす。
def git_cleanup():
    assert_sandbox_or_exit()  # 破壊的コマンドの前に必ず確認する
    subprocess.run(["git", "fetch", "origin"], check=True)
    # -f: 前のタスクの未コミット変更(mergeコンフリクトの残骸等)があってもcheckoutを
    # 拒否させない。どうせ直後にreset --hard/clean -fdで消えるので安全。
    subprocess.run(["git", "checkout", "-f", "main"], check=True)
    subprocess.run(["git", "reset", "--hard", "origin/main"], check=True)
    subprocess.run(["git", "clean", "-fd"], check=True)


def git_cleanup_with_retry(max_attempts=3, wait_seconds=60):
    """git_cleanup()はcheck=Trueの生subprocess呼び出しの列で、ネットワークの
    一時的な不調(git fetchの瞬断等)でもCalledProcessErrorを投げる。ここで
    吸収しないと、その場でnight_runner.py全体が無通知でクラッシュし、
    残りの未着手タスクについて誰にも気付かれないまま朝を迎えることになる。"""
    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            git_cleanup()
            return
        except subprocess.CalledProcessError as e:
            last_error = e
            notify_human(f"git_cleanup()に失敗(試行{attempt}/{max_attempts}): {e}")
            if attempt < max_attempts:
                time.sleep(wait_seconds)
    raise last_error


def save_diagnostic_branch(task):
    """cleanupで消える前に、原因調査用に現状をブランチへ退避する。

    ここは異常終了時の記録処理であり、記録自体が失敗しても元のエラー
    (呼び出し元がこれから記録・通知しようとしている本来の失敗理由)を握り潰して
    プロセス全体を落としてはならない。失敗時はここでnotify_humanし、Noneを返す
    (呼び出し元は「退避ブランチが無い」ケースとして扱う)。
    """
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    branch = f"diagnostic/{_slug(task['title'])}-{ts}"
    try:
        subprocess.run(["git", "checkout", "-b", branch], check=True)
        subprocess.run(["git", "add", "-A"], check=True)
        subprocess.run(
            ["git", "commit", "-m", f"wip: 異常終了時点のスナップショット ({task['title']})", "--allow-empty"],
            check=True,
        )
        subprocess.run(["git", "push", "origin", branch], check=True)
        return branch
    except subprocess.CalledProcessError as e:
        notify_human(f"save_diagnostic_branch()が失敗した(タスク「{task['title']}」の退避ブランチを作成できなかった): {e}")
        return None


def create_draft_pr_from_branch(task, branch, reason):
    # プレースホルダーは書かない。state中の最後のstep/review_roundから
    # 実際の進捗を埋め込む(冒頭の注記が警告している事故の対応)。
    step = task.get("step", "(記録なし)")
    review_round = task.get("review_round", "(記録なし)")
    completed = task.get("completed_summary") or f"最後に記録された作業段階: {step}"
    remaining = task.get("remaining_summary") or (
        f"{branch} の作業ツリー・コミット履歴を確認してください。"
    )
    body = (
        f"## 自動終了理由\n{reason}\n\n"
        f"## 完了した内容\n{completed}\n\n"
        f"## 未完了の点 / 次にやるべきこと\n{remaining}\n\n"
        f"## 診断情報\n"
        f"- 退避ブランチ: `{branch}`\n"
        f"- 最終step: `{step}`\n"
        f"- レビューラウンド: {review_round}\n"
    )
    subprocess.run(["git", "push", "origin", branch], check=True)
    subprocess.run([
        "gh", "pr", "create", "--draft",
        "--head", branch,
        "--title", f"WIP: {task['title']} ({reason})",
        "--body", body,
    ], check=True)


def verify_pr(pr_url, expected_branch):
    """9.8節: claude -pの自己申告を無条件に信じず、実在するPRか外側で検証する。"""
    if not pr_url or not expected_branch:
        return False
    try:
        result = subprocess.run(
            ["gh", "pr", "view", pr_url, "--json", "url,headRefName,state"],
            capture_output=True, text=True, check=True,
        )
        info = json.loads(result.stdout)
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        return False
    return info.get("headRefName") == expected_branch and info.get("state") == "OPEN"


# --- タスク状態の更新 ---
def _merge_usage(existing, new):
    """usageオブジェクトの各キー(input_tokens/output_tokens/
    cache_creation_input_tokens/cache_read_input_tokens等)を試行間で合算する。
    値が両方とも数値の場合だけ加算し、どちらかが数値でない場合(将来envelopeに
    非数値の内訳が増えた場合など)は合算せず新しい方の値で上書きする——壊れた
    前提で例外を出さないため。"""
    if not isinstance(existing, dict):
        return dict(new)
    merged = dict(existing)
    for key, value in new.items():
        prev = merged.get(key)
        if (
            isinstance(value, (int, float)) and not isinstance(value, bool)
            and isinstance(prev, (int, float)) and not isinstance(prev, bool)
        ):
            merged[key] = prev + value
        else:
            merged[key] = value
    return merged


def _record_cost_and_usage(task, state, envelope):
    """total_cost_usd/usageはトークン消費のチューニング判断材料として残すだけの
    任意項目(issue #47)。envelopeが無い・キーが無い・値の型が不正な場合も
    例外を出さず、単に記録をスキップする。

    レートリミットでbackoffリトライが発生した場合、各試行のコストは累積して
    記録する(1試行だけを残す設計だと、打ち切り直前の試行がTIMEOUT/hard_limit
    で終わった際に、その直前の試行で実際に発生していたコストごと丸ごと失われる
    ため — PR #50レビュー指摘)。記録が実際に変化したときは、その場でsave_state()
    して即ディスクへ反映する。呼び出し側(run_task_with_retry)は次のループの
    先頭で必ずload_state()により状態を再読み込みするため、ここで永続化しないと
    リトライへ進んだ時点で今回記録した分が失われる。"""
    if not isinstance(envelope, dict):
        return
    changed = False
    cost = envelope.get("total_cost_usd")
    if isinstance(cost, (int, float)) and not isinstance(cost, bool):
        # task.get("total_cost_usd", 0) はキーが無い場合のみ0を返す——過去に
        # 人手でstate.jsonを編集して"total_cost_usd": nullにした等、キーは
        # 存在するが値が数値でないケースでは既存値がそのまま返り、+ cost で
        # TypeErrorになる。run_task_with_retry内でこの呼び出しを囲むtry/exceptは
        # 無く、ここで例外を出すとタスク単体ではなくnight_runner.py全体(main()の
        # ループ)が落ちて残りの全タスクが処理されなくなるため、既存値が数値
        # でなければ0扱いにしてから加算する。
        existing_cost = task.get("total_cost_usd")
        if not isinstance(existing_cost, (int, float)) or isinstance(existing_cost, bool):
            existing_cost = 0
        task["total_cost_usd"] = existing_cost + cost
        changed = True
    usage = envelope.get("usage")
    if isinstance(usage, dict):
        task["usage"] = _merge_usage(task.get("usage"), usage)
        changed = True
    if changed:
        save_state(state)


def update_state_done(task, state, envelope):
    """envelopeは呼び出し元(run_task_with_retry)で既にJSONパース済みのdict
    (パースに失敗していればNone)を受け取る。ここでは再パースしない——
    claude_stdoutを渡してこの関数がもう一度json.loads()する従来の実装は、
    成功パスで呼び出し元と合わせてJSONを2回パースする無駄があった(PR #50
    レビュー指摘)。コスト/usageの記録も呼び出し元がこの関数を呼ぶ前に
    _record_cost_and_usage()で既に行っている(このタスクの成否を問わず、
    レートリミットのgive-up経路も含めて1試行につき1回)ため、ここでは行わない。"""
    def fail(reason):
        branch = save_diagnostic_branch(task)
        mark_task_failed(task, state, reason, diagnostic_branch=branch)

    if not isinstance(envelope, dict):
        fail("claude -p の出力がJSONとして解釈できない")
        return

    if envelope.get("is_error"):
        fail(f"claude -p がエラー終了(subtype={envelope.get('subtype')}): {str(envelope.get('result'))[:500]}")
        return

    structured = envelope.get("structured_output")
    if not isinstance(structured, dict):
        fail("structured_output が得られなかった(自己申告JSONの欠落)")
        return

    status = structured.get("status")
    pr_url = structured.get("pr_url")

    if status not in ("success", "draft"):
        fail(f"タスクからの報告がfailed: {structured.get('remaining_summary')}")
        return

    if not verify_pr(pr_url, task.get("branch")):
        fail(f"PRの実在確認に失敗した(自己申告URL: {pr_url})")
        return

    task["status"] = "done"
    _clear_deferred_markers(task)
    task["pr_status"] = status  # "success"(ready) か "draft"
    task["pr_url"] = pr_url
    task["review_round"] = structured.get("review_round")
    task["completed_summary"] = structured.get("completed_summary")
    task["remaining_summary"] = structured.get("remaining_summary")
    save_state(state)


def _clear_deferred_markers(task):
    """持ち越しマーカーは「次回このタスクを再開する」という一時的な印なので、
    done/failedという終了状態に達した時点で消す(消さないと、翌朝の棚卸しで
    完了済みのタスクが持ち越し扱いのまま残り、実態と食い違う)。"""
    for key in ("deferred_reason", "deferred_at", "rate_limit_reset_at"):
        task.pop(key, None)


def mark_task_failed(task, state, reason, diagnostic_branch=None):
    task["status"] = "failed"
    _clear_deferred_markers(task)
    task["failure_reason"] = reason
    if diagnostic_branch:
        task["diagnostic_branch"] = diagnostic_branch
    save_state(state)
    notify_human(f"タスク「{task['title']}」が failed になりました: {reason}")


def mark_task_deferred(task, state, reason, reset_at=None, diagnostic_branch=None):
    """レートリミットで今回はこれ以上進めないタスクを、failedではなく
    「持ち越し」として記録する(statusはpendingのまま)。

    failedにすると、(1)翌回は`run.sh start --retry-failed`を人が手で叩かない限り
    拾われない (2)「実装が壊れて失敗した」ケースと区別がつかない、の2点で困る。
    枠が空くのを待てなかっただけのタスクは、次回そのまま再開できる状態で
    残すのが正しい。diagnostic_branchに作業途中を退避してあるので、
    build_promptの再開ノートから参照できる。"""
    task["status"] = "pending"
    task["deferred_reason"] = reason
    task["deferred_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    if reset_at is not None:
        task["rate_limit_reset_at"] = reset_at.isoformat()
    if diagnostic_branch:
        task["diagnostic_branch"] = diagnostic_branch
    save_state(state)
    notify_human(f"タスク「{task['title']}」を次回へ持ち越します(status=pending): {reason}")


def _mask_secrets(text):
    """環境変数に入っている秘密情報(GH_TOKEN等)がalerts.logへそのまま
    書き出されないようにする。claude -pのエラー出力が認証情報を含む
    エラーメッセージをそのまま返すことがあるため。"""
    if not text:
        return text
    masked = text
    for name in SECRET_ENV_VARS:
        value = os.environ.get(name)
        if value:
            masked = masked.replace(value, "***MASKED***")
    return masked


def _preview(text):
    text = _mask_secrets(text) or "(空)"
    if len(text) > DIAGNOSTIC_PREVIEW_CHARS:
        omitted = len(text) - DIAGNOSTIC_PREVIEW_CHARS
        return text[:DIAGNOSTIC_PREVIEW_CHARS] + f"...(以下{omitted}文字省略)"
    return text


def describe_claude_failure(returncode, stdout, stderr, elapsed_seconds):
    """claude -pがエラー内容をstderrではなくstdout側に出すことがあり
    (2026-09-13の実運用で確認済み)、stderrだけを見ているとreasonが
    空文字になってしまう。returncode/stdout/stderr/実行時間をすべて残す。"""
    return (
        f"claude -p 失敗: returncode={returncode}, 実行時間={elapsed_seconds:.1f}秒\n"
        f"--- stdout ---\n{_preview(stdout)}\n"
        f"--- stderr ---\n{_preview(stderr)}"
    )


def log_unexpected_error(task, state, detail_text):
    message = f"タスク「{task['title']}」で予期しないエラー: {detail_text}"
    print(f"[ERROR] {message}", file=sys.stderr)
    notify_human(message)  # docker logsだけでなくalerts.logにも残す


def _log_full_exception(task, context, exc):
    """例外の文字列表現(str(e))だけでは、種類によって空文字になり得る
    (例: subprocess.CalledProcessErrorはreturncodeのみでstderrが空だと
    str(e)がほぼ情報無しになる)。type(e).__name__とtraceback全文を
    alerts.logへ残し、どの行で・何が原因で落ちたかを追えるようにする。"""
    notify_human(
        f"タスク「{task['title']}」: {context}で例外が発生"
        f"({type(exc).__name__}: {exc})\n{traceback.format_exc()}"
    )


def handle_hard_limit_exceeded(task, state):
    branch = save_diagnostic_branch(task)
    mark_task_failed(task, state, reason="hard_limit_exceeded", diagnostic_branch=branch)
    if branch:
        create_draft_pr_from_branch(task, branch, reason="締切バッファを超過したため強制終了")
    else:
        notify_human(f"タスク「{task['title']}」: 退避ブランチを作成できなかったため draft PR も作成できません。手動確認が必要です。")


def _issue_urls(task):
    """issue_urlは単一issueなら文字列、依存関係でまとめたタスクなら配列で持つ。
    どちらでも扱えるようにリストへ正規化する。"""
    raw = task.get("issue_url") or task.get("issue_urls") or []
    if isinstance(raw, str):
        return [raw] if raw else []
    return list(raw)


# --- タスクプロンプトの組み立て(3章) ---
def build_prompt(task, state):
    limits = resolve_limits(state)
    max_review_rounds = limits["max_review_rounds"]

    resume_note = ""
    if task.get("step") or task.get("deferred_reason"):
        resume_note = (
            f"\n## 再開についての注意\n"
            f"このタスクは以前の試行で `{task['branch']}` ブランチまで進んでいます"
            f"(最後に記録された段階: {task.get('step', '(記録なし)')}, "
            f"レビューラウンド: {task.get('review_round', 0)})。"
            f"`git fetch origin && git checkout {task['branch']}` でこのブランチを再開し、"
            f"ゼロから作り直さないでください。\n"
        )
        if task.get("deferred_reason"):
            # 持ち越しは「失敗」ではない。作り直しではなく続きをやらせる。
            resume_note += (
                f"前回はレートリミットのため中断し、次回へ持ち越されたタスクです"
                f"({task['deferred_reason']})。\n"
            )
        if task.get("diagnostic_branch"):
            resume_note += (
                f"中断時点の作業ツリーは `{task['diagnostic_branch']}` に退避されています"
                f"(作業ブランチに反映されていない変更が残っている場合はここから拾えます)。\n"
            )

    urls = _issue_urls(task)
    if len(urls) <= 1:
        issue_fetch_instruction = f"`gh issue view {urls[0] if urls else ''}` でこのタスクの内容(issue本文)を取得し、実装する。"
    else:
        view_lines = "\n".join(f"   - `gh issue view {u}`" for u in urls)
        issue_fetch_instruction = (
            f"以下の複数issue(依存関係により1タスクにまとめられている)をすべて取得し、"
            f"まとめて実装する。片方だけ実装して終わりにしないこと:\n{view_lines}"
        )
    closes_line = " ".join(f"Closes {u}" for u in urls) if urls else ""

    return f"""あなたはkakureruリポジトリの実装エージェントです。以下の1タスクを実装からPR作成まで完走させてください。

## タスク
- タイトル: {task['title']}
- 使用するブランチ: `{task['branch']}`(まだ存在しなければ `origin/main` から新規作成する)
{resume_note}
## 手順
1. {issue_fetch_instruction} 実装規約はAGENTS.md/CLAUDE.mdに従うこと
   (状態管理でのhooks/Riverpodの使い分け、データクラスはFreezed限定、等)。
2. 各段階が終わるたびに以下を実行し、進捗を記録する(必須。レートリミット等で中断しても再開できるようにするため):
   `python3 night-run/update_step.py "{task['title']}" "<段階名: 実装/デバッグ/レビュー/修正/コンフリクト解消/PR作成>" [レビューラウンド数]`
3. `flutter test` と `flutter analyze` を実行し、失敗があれば直す。
4. Task/Agentツールで `reviewer` サブエージェントにレビューさせ、指摘に対応する。
   - グリーン かつ reviewer承認 → 次へ
   - 同じ指摘が2回連続、または最大{max_review_rounds}ラウンドに到達 → そこで打ち切り、readyではなくdraftとして扱う
5. PR作成前に `git fetch origin && git merge origin/main` でコンフリクトを解消する。
   **重要**: `git reset --hard` / `git clean` / `git push --force`(force-with-lease含む)は、このリポジトリの
   安全網で常にブロックされる。使う必要が生じたらやり方が間違っているサインなので、代わりに新しいコミットで対応すること。
6. `gh pr create` でPRを作成する。
   - グリーン かつ reviewer承認 → 通常PR(ready)。本文に `{closes_line}` を含め、マージ時に対象issueが自動クローズされるようにする
   - 打ち切りの場合 → `--draft` を付け、本文に「完了した内容」「未完了の点」「次にやるべきこと」を書く(このケースはまだ未完了なので `Closes` は書かない)

## 消費量について
このセッションはサブスクリプションの利用枠(model={limits['model']} / effort={limits['effort']})の中で動いています。
同じテスト・ビルドを目的なく繰り返さない、タスクと関係の無いファイルを全文読みしない、といった範囲で無駄な消費を避けてください。
**ただし手順3のテスト・解析と手順4のレビューは省略しないこと**(ここを飛ばすと、レビューで差し戻される分だけ消費が増えます)。

## 最後の出力
最後は指定されたJSONスキーマに従い、以下を報告すること:
- status: 通常PRを作成できたら "success"、打ち切ってdraft PRにしたら "draft"、致命的な問題で実装を進められなかったら "failed"
- pr_url: 実際に作成したPRのURL(作成できなかった場合はnull)
- branch: 実際に使ったブランチ名
- review_round: reviewerサブエージェントを呼んだ回数
- completed_summary: 完了した内容の要約(日本語、3行程度)
- remaining_summary: 未完了の点・次にやるべきことの要約(日本語、3行程度。すべて完了していれば「なし」)
"""


# --- claude -pの実行(プロセスグループごとタイムアウト管理、4.2節) ---
_claude_flags_loaded = False
_claude_flags = None


def claude_supported_flags():
    """`claude --help` に現れるオプションの集合を返す(プロセスにつき一度だけ実行)。

    コンテナに焼き込まれたCLI(DockerfileのCLAUDE_CODE_VERSION)が古く、
    --model/--effort を知らないまま渡すと、CLIは引数エラーで即座に終了する。
    そうなるとその夜のタスクが1件も進まないまま朝を迎えるため、事前に
    対応状況を確認し、知らないオプションは外したうえで警告を残す
    (消費量の制御は効かなくなるが、夜が丸ごと無駄になるよりはよい)。
    取得自体に失敗したらNoneを返し、呼び出し側はフィルタせず従来どおり渡す。"""
    global _claude_flags_loaded, _claude_flags
    if _claude_flags_loaded:
        return _claude_flags
    _claude_flags_loaded = True
    try:
        result = subprocess.run(
            ["claude", "--help"], capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.SubprocessError) as e:
        notify_human(f"`claude --help` を実行できず、オプションの対応確認をスキップします: {type(e).__name__}: {e}")
        return None
    if result.returncode != 0:
        notify_human(f"`claude --help` が終了コード{result.returncode}で失敗したため、オプションの対応確認をスキップします。")
        return None
    _claude_flags = frozenset(re.findall(r"--[a-zA-Z0-9][a-zA-Z0-9-]*", result.stdout))
    return _claude_flags


def reviewer_agents_json(limits):
    """reviewerサブエージェントの定義。reviewer_modelが空ならmodelキーを付けず、
    セッションのモデル(--model)を継承させる。"""
    definition = copy.deepcopy(REVIEWER_AGENT_DEFINITION)
    model = str(limits.get("reviewer_model") or "").strip()
    if model:
        definition["reviewer"]["model"] = model
    return json.dumps(definition, ensure_ascii=False)


def build_claude_argv(prompt, limits):
    argv = [
        "claude", "-p", prompt,
        "--output-format", "json",
        "--dangerously-skip-permissions",
        "--agents", reviewer_agents_json(limits),
        "--json-schema", json.dumps(TASK_RESULT_SCHEMA, ensure_ascii=False),
    ]
    # モデルとeffortを明示する理由: CLIの既定任せにすると、契約プランやCLIの
    # バージョンによって選ばれるモデルが変わる。Pro契約ではOpusは使えず、
    # 上位モデル・高effortのまま1晩回すと対話利用分まで枠を食い潰す。
    # --max-budget-usdはAPIキー課金のときだけ実質的な歯止めになる(サブスク
    # 認証ではコストが報告されないことがある)ので、タスク数の上限(main)と
    # 併用する前提の二重の網と位置づける。
    optional = [
        ("--model", str(limits.get("model") or "").strip()),
        ("--effort", str(limits.get("effort") or "").strip()),
        ("--max-budget-usd", _format_optional_number(limits.get("max_budget_usd_per_task"))),
    ]
    supported = claude_supported_flags()
    for flag, value in optional:
        if not value:
            continue
        if supported is not None and flag not in supported:
            notify_human(f"このCLIは {flag} に対応していない(claude --helpに現れない)ため、指定を省略します。")
            continue
        argv += [flag, value]
    return argv


def _format_optional_number(value):
    """0や未設定は「指定しない」を意味する(空文字を返す)。"""
    if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
        return ""
    return str(value)


def run_claude_with_timeout(prompt, timeout_seconds, limits=None):
    argv = build_claude_argv(prompt, limits if limits is not None else dict(DEFAULT_LIMITS))
    proc = subprocess.Popen(
        argv,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        start_new_session=True,  # 新しいプロセスグループを作る
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout_seconds)
        return proc.returncode, stdout, stderr
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)  # 孫プロセスごと強制終了
        proc.wait()
        return None, "", "TIMEOUT"


def _handle_rate_limit(task, state, attempt, detail_text):
    """レートリミット検知時の共通処理。待ってリトライするならTrueを返し、
    今回は進められないと判断したら持ち越し(status=pending)にしてFalseを返す
    (呼び出し側は"deferred"を返し、main()はそこで実行自体を終える)。

    従来はここで指数backoffを撃ち切ってfailedにしていたが、サブスクリプション
    契約では枠の解除が数時間先のことがあり、待ち切れずにfailedへ倒れるのが
    常態だった。待って意味があるときだけ待つ(plan_rate_limit_wait)。"""
    hard_limit = datetime.datetime.fromisoformat(state["hard_limit"])
    now = datetime.datetime.now(datetime.timezone.utc)
    action, wait_seconds, reset_at = plan_rate_limit_wait(attempt, detail_text, now, hard_limit)
    reset_note = f"(解除予定: {reset_at.isoformat()})" if reset_at else "(解除時刻は取得できず)"

    if action == "wait":
        message = (
            f"タスク「{task['title']}」: レートリミット検知{reset_note}。"
            f"{wait_seconds / 60:.1f}分待機して再開します({attempt}/{MAX_RETRY_ATTEMPTS})。"
        )
        print(message)
        notify_human(message)
        time.sleep(wait_seconds)
        return True

    branch = save_diagnostic_branch(task)
    mark_task_deferred(
        task, state,
        f"レートリミットのため中断{reset_note}。締切までに枠が戻らないと判断しました",
        reset_at=reset_at,
        diagnostic_branch=branch,
    )
    notify_human(f"タスク「{task['title']}」持ち越し時のclaude -p出力(抜粋):\n{_preview(detail_text)}")
    return False


# --- タスク単体の実行+レートリミットへのリトライ(4.3節/9.10節) ---
def run_task_with_retry(task, state):
    attempt = 0
    while True:
        hard_limit = datetime.datetime.fromisoformat(state["hard_limit"])
        now = datetime.datetime.now(datetime.timezone.utc)
        if now >= hard_limit:
            handle_hard_limit_exceeded(task, state)
            return

        remaining_seconds = (hard_limit - now).total_seconds()
        try:
            notify_human(f"タスク「{task['title']}」: プロンプト組み立て開始")
            limits = resolve_limits(state)
            prompt = build_prompt(task, state)
            notify_human(
                f"タスク「{task['title']}」: プロンプト組み立て完了(文字数={len(prompt)})。"
                f"claude -p 実行開始({describe_limits(limits)})"
            )
            started_at = time.monotonic()
            returncode, stdout, stderr = run_claude_with_timeout(
                prompt, timeout_seconds=remaining_seconds, limits=limits,
            )
            elapsed_seconds = time.monotonic() - started_at
            notify_human(
                f"タスク「{task['title']}」: claude -p 実行終了(returncode={returncode}, "
                f"実行時間={elapsed_seconds:.1f}秒)"
            )
        except Exception as e:  # noqa: BLE001 — ここで拾わないとnight_runner.py全体が落ちる(過去に実際発生済み)
            # issueの取得・作業ブランチの作成はclaude -p側のエージェントが自分の
            # セッション内で行う(update_step.pyでtask["step"]に記録される)ため、
            # night_runner.py自身が制御できる区間はここ(プロンプト組み立て〜
            # claude -p呼び出し)だけ。ここで想定外の例外が起きても、握り潰さず
            # 記録した上でこのタスクをfailedにし、次のタスクへ進む。
            _log_full_exception(task, "claude -p 実行前後の処理", e)
            branch = save_diagnostic_branch(task)
            mark_task_failed(task, state, f"{type(e).__name__}: {e}", diagnostic_branch=branch)
            return

        # update_step.py はタスク実行中に別プロセスとしてstateファイルへ書き込む。
        # ここで再読み込みしないと、以降で参照するtask/stateが古いままになる。
        state = load_state()
        task = next((t for t in state["tasks"] if t["title"] == task["title"]), task)

        if stderr == "TIMEOUT":
            handle_hard_limit_exceeded(task, state)
            return

        # レートリミットのgive-up経路(_retry_after_rate_limit_or_give_up内で
        # mark_task_failedを直接呼ぶ)や、下のレートリミット以外の異常終了経路は
        # update_state_doneを経由しないため、ここで先に記録しておかないと
        # コストが握り潰される(issue #47)。returncodeが0以外でもstdoutに
        # envelopeが残っていることがあるため、成否を問わず一度パースを試みる。
        # TypeErrorも拾うのは、stdoutがstr以外だった場合(communicate(text=True)
        # を使っている限り起きないはずだが)にコスト記録という任意処理のために
        # night_runner.py全体を落とさないため。JSONDecodeErrorはValueErrorの
        # サブクラスなので、この指定で従来のケースも引き続き含む。
        #
        # ここで得たenvelopeはこの後success判定にも使い回す(update_state_done
        # には既にパース済みのenvelopeを渡し、二重にjson.loads()しない —
        # PR #50レビュー指摘)。また_record_cost_and_usage()はこの1試行の
        # コストを直ちにsave_state()で永続化する。以降どの分岐(retry/give-up/
        # 成功/失敗)へ進んでも、次のloop先頭のload_state()で今回の記録が
        # 失われることはない(PR #50レビュー指摘)。
        try:
            envelope = json.loads(stdout)
        except (TypeError, ValueError):
            envelope = None
        _record_cost_and_usage(task, state, envelope)

        if returncode == 0:
            # claude -pはAPIレベルのレートリミットをexit 0 + JSON封筒内のエラーとして
            # 返すことがある。stderrの文字列マッチだけでなく、こちらも見ておかないと
            # 一度で"failed"確定してしまいbackoffリトライへ入れない。
            if _envelope_is_rate_limited(envelope):
                attempt += 1
                if _handle_rate_limit(task, state, attempt, stdout):
                    continue
                return "deferred"

            update_state_done(task, state, envelope)
            return

        if RATE_LIMIT_PATTERN.search(stderr):
            attempt += 1
            if _handle_rate_limit(task, state, attempt, stderr):
                continue
            return "deferred"
        else:
            # レートリミット以外のエラー: 診断用ブランチへ退避してからfailedに更新し、
            # 次のタスクへ進む(無限リトライを防止)。
            # stderrが空でもreasonを空文字にしない(claude -pがエラー内容をstdout側に
            # 出すケースがあり、そのままだと「が failed になりました: 」で情報ゼロになる)。
            diagnosis = describe_claude_failure(returncode, stdout, stderr, elapsed_seconds)
            log_unexpected_error(task, state, diagnosis)
            branch = save_diagnostic_branch(task)
            reason = (
                _mask_secrets(stderr).strip() if stderr and stderr.strip()
                else f"claude -p が終了コード{returncode}で失敗(詳細はalerts.logの直前の[ERROR]行を参照)"
            )
            mark_task_failed(task, state, reason, diagnostic_branch=branch)
            return


def generate_summary(state):
    tasks = state.get("tasks", [])
    done = [t for t in tasks if t["status"] == "done"]
    failed = [t for t in tasks if t["status"] == "failed"]
    # 持ち越し(deferred)はstatus上はpendingだが、「枠が戻らず中断した」ものと
    # 「そもそも着手していない」ものを混ぜると、翌朝の判断材料にならない。
    deferred = [t for t in tasks if t["status"] == "pending" and t.get("deferred_reason")]
    pending = [t for t in tasks if t["status"] == "pending" and not t.get("deferred_reason")]

    lines = [
        f"完了: {len(done)}件 / 失敗: {len(failed)}件 / "
        f"持ち越し: {len(deferred)}件 / 未着手: {len(pending)}件"
    ]

    run_summary = state.get("run_summary")
    if isinstance(run_summary, dict):
        spent = run_summary.get("spent_usd")
        spent_text = f"${spent:.2f}" if isinstance(spent, (int, float)) and not isinstance(spent, bool) else "計測なし"
        lines.append(
            f"今回の実行: {run_summary.get('tasks_started', 0)}件に着手 / 消費 {spent_text} / "
            f"終了理由: {run_summary.get('stopped_reason', '(記録なし)')}"
        )
        if run_summary.get("limits_description"):
            lines.append(f"設定: {run_summary['limits_description']}")

    for t in done:
        cost = _task_cost_usd(t)
        cost_text = f" (コスト: ${cost:.2f})" if cost > 0 else ""
        lines.append(f"  [done] {t['title']} -> {t.get('pr_url')}{cost_text}")
    for t in failed:
        lines.append(f"  [failed] {t['title']} -> {t.get('failure_reason')} (診断ブランチ: {t.get('diagnostic_branch')})")
    for t in deferred:
        lines.append(
            f"  [deferred] {t['title']} -> {t.get('deferred_reason')} "
            f"(退避ブランチ: {t.get('diagnostic_branch')}) — 次回の実行でそのまま再開されます"
        )
    for t in pending:
        lines.append(f"  [pending] {t['title']}")

    summary_text = "\n".join(lines)
    print(summary_text)
    try:
        summary_path = os.path.join(os.path.dirname(STATE_FILE), "summary.txt")
        with open(summary_path, "w", encoding="utf-8") as f:
            f.write(summary_text + "\n")
    except OSError:
        pass


def _run_cost_delta(title, cost_before):
    """そのタスクが今回の実行で消費した分(stateの累積値の増分)。

    total_cost_usdは同じタスクを何晩にもわたって再開すると累積していく
    (issue #47の記録方式)。実行全体の予算上限は「今回の実行で使った分」で
    判断したいので、着手前の値との差分を取る。"""
    try:
        tasks = load_state().get("tasks", [])
    except (OSError, ValueError):
        return 0.0
    task = next((t for t in tasks if t.get("title") == title), None)
    return max(0.0, _task_cost_usd(task) - cost_before)


# --- メインループ ---
def main():
    assert_sandbox_or_exit()  # 0.2節: 実行環境の安全性を最初に確認する
    os.chdir(REPO_DIR)

    initial_state = load_state()
    if "hard_limit" not in initial_state:
        print("設定エラー: state に hard_limit がありません。ヒアリング完了時点で確定値を書き出してください。", file=sys.stderr)
        sys.exit(1)
    for t in initial_state["tasks"]:
        if t.get("depends_on"):
            print(f"設定エラー: タスク「{t['title']}」に未解決の依存が残っています。ヒアリング時点で解消してください。", file=sys.stderr)
            sys.exit(1)

    limits = resolve_limits(initial_state)
    notify_human(f"night-run開始: {describe_limits(limits)}")

    tasks_started = 0
    spent_usd = 0.0
    stopped_reason = "全タスク完了"

    while True:
        state = load_state()
        # 設定は毎周読み直す。stateは実行中もホストから編集できる(bind mount)ので、
        # 夜中に「今夜はもう止めたい」と上限を下げる操作を効かせられるようにする。
        limits = resolve_limits(state)
        now = datetime.datetime.now(datetime.timezone.utc)
        deadline = datetime.datetime.fromisoformat(state["deadline"])

        if now >= deadline:
            stopped_reason = "締切到達。新規タスクには着手しません"
            break

        pending = [t for t in state["tasks"] if t["status"] == "pending"]
        if not pending:
            stopped_reason = "全タスク完了"
            break

        # 以下2つが、サブスクリプション契約の枠を使い切らないための主な歯止め。
        # 1タスクあたりの --max-budget-usd はAPIキー課金でしか実質的に効かない
        # (サブスク認証ではコストが報告されないことがある)ため、件数の上限を
        # 併せて置く。上限に達しても残りは pending のまま残すので、次回の実行が
        # そのまま続きを拾う。
        max_tasks = limits["max_tasks_per_run"]
        if max_tasks and tasks_started >= max_tasks:
            stopped_reason = (
                f"1回の実行あたりのタスク数上限({max_tasks}件)に達しました。"
                f"残り{len(pending)}件は次回へ持ち越します"
            )
            break

        max_total = limits["max_total_budget_usd"]
        if max_total and spent_usd >= max_total:
            stopped_reason = (
                f"実行全体の予算上限(${max_total})に達しました(消費 ${spent_usd:.2f})。"
                f"残り{len(pending)}件は次回へ持ち越します"
            )
            break

        task = pending[0]
        cost_before = _task_cost_usd(task)

        # 次のタスクに入る前に必ずクリーンな状態へ戻す
        try:
            git_cleanup_with_retry()
        except subprocess.CalledProcessError:
            stopped_reason = "git_cleanup()が繰り返し失敗したため停止しました"
            notify_human(
                "git_cleanup()が繰り返し失敗したため、night_runner.pyを停止します。"
                "手動で状況を確認してください(残りのタスクは pending のまま残ります)。"
            )
            break

        outcome = run_task_with_retry(task, state)
        tasks_started += 1
        spent_usd += _run_cost_delta(task["title"], cost_before)

        if outcome == "deferred":
            stopped_reason = (
                "レートリミットのため中断しました。着手済みのタスクも含めて"
                "残りは次回の実行で再開します"
            )
            break

    print(stopped_reason)
    final_state = load_state()
    final_state["run_summary"] = {
        "finished_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "tasks_started": tasks_started,
        "spent_usd": round(spent_usd, 4),
        "stopped_reason": stopped_reason,
        "limits": limits,
        "limits_description": describe_limits(limits),
    }
    save_state(final_state)
    notify_human(
        f"night-run終了: {stopped_reason}(着手{tasks_started}件 / 消費${spent_usd:.2f})"
    )
    generate_summary(final_state)


if __name__ == "__main__":
    main()
