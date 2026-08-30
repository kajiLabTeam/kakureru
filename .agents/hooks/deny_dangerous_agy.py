#!/usr/bin/env python3
"""Antigravity CLI (agy) 版 PreToolUse hook: 破壊的コマンドをブロックする。

検出ロジック本体(ブロックリストの判定基準)は .claude/hooks/deny_dangerous_bash.py の
check_command() をそのまま import して使う。判定基準を2箇所に複製すると、片方だけ
直してもう片方が古いまま残る(drift)事故が起きるため、ここでは複製しない。
このファイルはAntigravity側のフックI/O契約(stdinのtoolCall.args.CommandLine、
stdoutのdecisionフィールド)への薄いアダプタに徹する。

検出パターンを変更する場合は .claude/hooks/deny_dangerous_bash.py と
test_deny_dangerous_bash.py を直すこと(このファイルの変更は不要)。
このアダプタ自体(I/Oの取り出し方)を変えたら test_deny_dangerous_agy.py を実行すること。

**未検証(2026-08時点、Google Antigravity公式ドキュメントに明記なし)**:
- agyのheadlessモード(`agy -p`)でこのフックが実際に発火するか
- `--dangerously-skip-permissions` がこのフック自体をバイパスするか
実運用(特に無人実行)に使う前に、実機でこの2点を確認すること。
"""
import json
import os
import sys

_CLAUDE_HOOKS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", ".claude", "hooks"
)
sys.path.insert(0, _CLAUDE_HOOKS_DIR)
from deny_dangerous_bash import check_command  # noqa: E402


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0  # 入力が解釈できない場合はブロックしない(フェイルオープン)

    tool_call = data.get("toolCall") or {}
    if tool_call.get("name") != "run_command":
        return 0

    command = (tool_call.get("args") or {}).get("CommandLine", "") or ""
    reason = check_command(command)
    if reason:
        print(reason, file=sys.stderr)
        print(json.dumps({"decision": "deny", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
