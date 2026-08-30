"""deny_dangerous_agy.py の回帰テスト。

検出ロジック本体(何を危険と判定するか)は .claude/hooks/test_deny_dangerous_bash.py が
既にカバーしている(deny_dangerous_agy.py はそこから check_command() を import するだけ
なので、判定基準を重複してテストしない)。ここでテストするのは、Antigravity側の
I/O契約(stdinのtoolCall.args.CommandLine、stdoutのdecision JSON)を正しく
取り扱えているかというアダプタ部分だけ。

hookを変更したら実行すること: python3 .agents/hooks/test_deny_dangerous_agy.py
"""
import json
import os
import subprocess
import sys

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "deny_dangerous_agy.py")


def run_hook(payload):
    result = subprocess.run(
        [sys.executable, HOOK],
        input=json.dumps(payload),
        capture_output=True, text=True,
    )
    return result


def decision_of(stdout):
    stdout = stdout.strip()
    if not stdout:
        return None
    return json.loads(stdout.splitlines()[-1])


def make_payload(command_line, tool_name="run_command"):
    return {
        "toolCall": {"name": tool_name, "args": {"CommandLine": command_line}},
        "stepIdx": 1,
        "conversationId": "test",
    }


def test_dangerous_command_is_denied():
    result = run_hook(make_payload("git reset --hard"))
    assert result.returncode == 0, result.stderr
    decision = decision_of(result.stdout)
    assert decision is not None, "デフォルト拒否のコマンドでdecisionが出力されていない"
    assert decision["decision"] == "deny"
    assert "reason" in decision and decision["reason"]


def test_safe_command_is_not_denied():
    result = run_hook(make_payload("git status"))
    assert result.returncode == 0, result.stderr
    assert decision_of(result.stdout) is None, "安全なコマンドをブロックしている"


def test_non_run_command_tool_is_ignored():
    # このhookはコマンド実行以外のツール(read_file等)には反応しない
    result = run_hook(make_payload("git reset --hard", tool_name="read_file"))
    assert result.returncode == 0, result.stderr
    assert decision_of(result.stdout) is None


def test_malformed_json_fails_open():
    result = subprocess.run(
        [sys.executable, HOOK],
        input="not json",
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    assert decision_of(result.stdout) is None


def test_missing_command_line_fails_open():
    payload = {"toolCall": {"name": "run_command", "args": {}}}
    result = run_hook(payload)
    assert result.returncode == 0, result.stderr
    assert decision_of(result.stdout) is None


TESTS = [
    test_dangerous_command_is_denied,
    test_safe_command_is_not_denied,
    test_non_run_command_tool_is_ignored,
    test_malformed_json_fails_open,
    test_missing_command_line_fails_open,
]


def main():
    failures = 0
    for test in TESTS:
        try:
            test()
        except AssertionError as e:
            failures += 1
            print(f"FAIL {test.__name__}: {e}")
        else:
            print(f"ok   {test.__name__}")
    if failures:
        print(f"{failures}件失敗")
        return 1
    print("全件成功")
    return 0


if __name__ == "__main__":
    sys.exit(main())
