#!/usr/bin/env python3
"""night_runner.pyの純粋関数・フェイルセーフ挙動のユニットテスト。

docker/claude/ghの実プロセスは呼ばず、subprocessやネットワークをモックする。
実行方法: python3 night-run/test_night_runner.py
"""
import datetime
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import night_runner  # noqa: E402


class SandboxGuardTest(unittest.TestCase):
    def test_exits_when_env_and_marker_file_both_missing(self):
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("NIGHT_RUNNER_SANDBOX", None)
            with mock.patch.object(night_runner, "notify_human"):
                with self.assertRaises(SystemExit) as ctx:
                    night_runner.assert_sandbox_or_exit()
                self.assertEqual(ctx.exception.code, 1)

    def test_exits_when_env_set_but_marker_file_missing(self):
        # 環境変数のspoofだけではガードを通せないことを確認する
        with tempfile.TemporaryDirectory() as tmp:
            missing_marker = os.path.join(tmp, "does-not-exist")
            with mock.patch.dict(os.environ, {"NIGHT_RUNNER_SANDBOX": "1"}), \
                 mock.patch.object(night_runner, "SANDBOX_MARKER_FILE", missing_marker), \
                 mock.patch.object(night_runner, "notify_human"):
                with self.assertRaises(SystemExit) as ctx:
                    night_runner.assert_sandbox_or_exit()
                self.assertEqual(ctx.exception.code, 1)

    def test_passes_when_env_and_marker_file_both_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            marker = os.path.join(tmp, "sandbox-marker")
            open(marker, "w").close()
            with mock.patch.dict(os.environ, {"NIGHT_RUNNER_SANDBOX": "1"}), \
                 mock.patch.object(night_runner, "SANDBOX_MARKER_FILE", marker):
                night_runner.assert_sandbox_or_exit()  # 例外が飛ばなければOK


class StateFileTest(unittest.TestCase):
    def test_save_state_is_atomic_and_adds_timestamp(self):
        with tempfile.TemporaryDirectory() as tmp:
            state_path = os.path.join(tmp, "night-run-state.json")
            with mock.patch.object(night_runner, "STATE_FILE", state_path):
                night_runner.save_state({"tasks": []})
                self.assertTrue(os.path.exists(state_path))
                # tmpファイルが残っていないこと(os.replaceで置き換わっている)
                leftovers = [f for f in os.listdir(tmp) if f.endswith(".tmp")]
                self.assertEqual(leftovers, [])
                loaded = night_runner.load_state()
                self.assertIn("last_updated", loaded)


class BackoffTest(unittest.TestCase):
    def test_sequence_matches_design_then_caps(self):
        got = [night_runner.backoff_seconds(a) for a in range(1, 8)]
        self.assertEqual(got, [60, 120, 240, 480, 960, 1800, 1800])


class MainValidationTest(unittest.TestCase):
    def _run_main_with_state(self, state):
        with tempfile.TemporaryDirectory() as tmp:
            state_path = os.path.join(tmp, "night-run-state.json")
            with open(state_path, "w") as f:
                json.dump(state, f)
            marker = os.path.join(tmp, "sandbox-marker")
            open(marker, "w").close()
            with mock.patch.object(night_runner, "STATE_FILE", state_path), \
                 mock.patch.object(night_runner, "REPO_DIR", tmp), \
                 mock.patch.object(night_runner, "SANDBOX_MARKER_FILE", marker), \
                 mock.patch.dict(os.environ, {"NIGHT_RUNNER_SANDBOX": "1"}), \
                 mock.patch.object(night_runner, "notify_human"):
                with self.assertRaises(SystemExit) as ctx:
                    night_runner.main()
                return ctx.exception.code

    def test_missing_hard_limit_exits(self):
        code = self._run_main_with_state({"tasks": []})
        self.assertEqual(code, 1)

    def test_unresolved_depends_on_exits(self):
        state = {
            "hard_limit": "2999-01-01T00:00:00+09:00",
            "deadline": "2999-01-01T00:00:00+09:00",
            "tasks": [{"title": "A", "status": "pending", "depends_on": "B"}],
        }
        code = self._run_main_with_state(state)
        self.assertEqual(code, 1)


class UpdateStateDoneTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state_path = os.path.join(self.tmp.name, "night-run-state.json")
        patcher_state_file = mock.patch.object(night_runner, "STATE_FILE", self.state_path)
        patcher_state_file.start()
        self.addCleanup(patcher_state_file.stop)
        patcher_alerts = mock.patch.object(
            night_runner, "ALERTS_LOG", os.path.join(self.tmp.name, "alerts.log")
        )
        patcher_alerts.start()
        self.addCleanup(patcher_alerts.stop)
        patcher_diag = mock.patch.object(
            night_runner, "save_diagnostic_branch", return_value="diagnostic/fake-branch"
        )
        patcher_diag.start()
        self.addCleanup(patcher_diag.stop)

        self.task = {"title": "タスクA", "status": "pending", "branch": "night-run/task-a"}
        self.state = {"tasks": [self.task]}

    def test_non_dict_envelope_marks_failed(self):
        # 呼び出し元(run_task_with_retry)はJSONパースに失敗するとNoneを渡す。
        night_runner.update_state_done(self.task, self.state, None)
        self.assertEqual(self.task["status"], "failed")

    def test_is_error_marks_failed(self):
        envelope = {"is_error": True, "subtype": "error_max_turns", "result": "boom"}
        night_runner.update_state_done(self.task, self.state, envelope)
        self.assertEqual(self.task["status"], "failed")

    def test_missing_structured_output_marks_failed(self):
        envelope = {"is_error": False, "result": "plain text, no schema"}
        night_runner.update_state_done(self.task, self.state, envelope)
        self.assertEqual(self.task["status"], "failed")

    def test_self_reported_failed_status_marks_failed(self):
        envelope = {
            "is_error": False,
            "structured_output": {
                "status": "failed", "pr_url": None, "branch": "night-run/task-a",
                "review_round": 1, "completed_summary": "", "remaining_summary": "無理だった",
            },
        }
        night_runner.update_state_done(self.task, self.state, envelope)
        self.assertEqual(self.task["status"], "failed")

    def test_unverifiable_pr_marks_failed_even_if_self_reported_success(self):
        envelope = {
            "is_error": False,
            "structured_output": {
                "status": "success", "pr_url": "https://github.com/x/y/pull/1",
                "branch": "night-run/task-a", "review_round": 1,
                "completed_summary": "done", "remaining_summary": "なし",
            },
        }
        with mock.patch.object(night_runner, "verify_pr", return_value=False):
            night_runner.update_state_done(self.task, self.state, envelope)
        self.assertEqual(self.task["status"], "failed")

    def test_verified_success_marks_done(self):
        envelope = {
            "is_error": False,
            "structured_output": {
                "status": "success", "pr_url": "https://github.com/x/y/pull/1",
                "branch": "night-run/task-a", "review_round": 2,
                "completed_summary": "done", "remaining_summary": "なし",
            },
        }
        with mock.patch.object(night_runner, "verify_pr", return_value=True):
            night_runner.update_state_done(self.task, self.state, envelope)
        self.assertEqual(self.task["status"], "done")
        self.assertEqual(self.task["pr_url"], "https://github.com/x/y/pull/1")

    def test_does_not_record_cost_itself_even_if_envelope_has_it(self):
        # PR #50レビュー指摘: コスト/usageの記録は呼び出し元(run_task_with_retry)が
        # _record_cost_and_usage()で既に行う。update_state_done がここでも記録すると
        # 同じ試行分を二重にカウントしてしまうため、ここでは一切触らないことを
        # 固定する回帰テスト。
        envelope = {
            "is_error": False,
            "total_cost_usd": 1.23,
            "usage": {"input_tokens": 100, "output_tokens": 50},
            "structured_output": {
                "status": "success", "pr_url": "https://github.com/x/y/pull/1",
                "branch": "night-run/task-a", "review_round": 2,
                "completed_summary": "done", "remaining_summary": "なし",
            },
        }
        with mock.patch.object(night_runner, "verify_pr", return_value=True):
            night_runner.update_state_done(self.task, self.state, envelope)
        self.assertEqual(self.task["status"], "done")
        self.assertNotIn("total_cost_usd", self.task)
        self.assertNotIn("usage", self.task)


class MergeUsageTest(unittest.TestCase):
    def test_no_existing_returns_copy_of_new(self):
        new = {"input_tokens": 5}
        merged = night_runner._merge_usage(None, new)
        self.assertEqual(merged, {"input_tokens": 5})
        self.assertIsNot(merged, new)  # 呼び出し元のdictをそのまま共有参照しない

    def test_numeric_keys_are_summed(self):
        merged = night_runner._merge_usage(
            {"input_tokens": 10, "output_tokens": 2},
            {"input_tokens": 5, "output_tokens": 1},
        )
        self.assertEqual(merged, {"input_tokens": 15, "output_tokens": 3})

    def test_new_key_not_in_existing_is_added(self):
        merged = night_runner._merge_usage({"input_tokens": 10}, {"cache_read_input_tokens": 3})
        self.assertEqual(merged, {"input_tokens": 10, "cache_read_input_tokens": 3})

    def test_non_numeric_value_overwrites_instead_of_summing(self):
        merged = night_runner._merge_usage({"service_tier": "standard"}, {"service_tier": "priority"})
        self.assertEqual(merged, {"service_tier": "priority"})


class RecordCostAndUsageTest(unittest.TestCase):
    def setUp(self):
        self.task = {}
        self.state = {"tasks": [self.task]}

    def test_non_dict_envelope_does_not_raise_or_save(self):
        with mock.patch.object(night_runner, "save_state") as mock_save:
            night_runner._record_cost_and_usage(self.task, self.state, None)
            night_runner._record_cost_and_usage(self.task, self.state, "not-a-dict")
        self.assertEqual(self.task, {})
        mock_save.assert_not_called()

    def test_extracts_present_fields_only_and_persists(self):
        # PR #50レビュー指摘: 記録した時点でsave_state()し、呼び出し元が
        # リトライへ進んでload_state()し直しても消えないようにする。
        with mock.patch.object(night_runner, "save_state") as mock_save:
            night_runner._record_cost_and_usage(self.task, self.state, {"total_cost_usd": 0.5})
        self.assertEqual(self.task, {"total_cost_usd": 0.5})
        mock_save.assert_called_once_with(self.state)

    def test_wrong_type_values_are_skipped_and_not_saved(self):
        with mock.patch.object(night_runner, "save_state") as mock_save:
            night_runner._record_cost_and_usage(
                self.task, self.state, {"total_cost_usd": "N/A", "usage": "not-a-dict"}
            )
        self.assertEqual(self.task, {})
        mock_save.assert_not_called()

    def test_repeated_calls_accumulate_cost_and_merge_usage(self):
        # PR #50レビュー指摘: リトライで複数回呼ばれても上書きではなく累積する。
        with mock.patch.object(night_runner, "save_state"):
            night_runner._record_cost_and_usage(
                self.task, self.state,
                {"total_cost_usd": 1.0, "usage": {"input_tokens": 10, "output_tokens": 2}},
            )
            night_runner._record_cost_and_usage(
                self.task, self.state,
                {"total_cost_usd": 2.5, "usage": {"input_tokens": 20, "output_tokens": 3}},
            )
        self.assertEqual(self.task["total_cost_usd"], 3.5)
        self.assertEqual(self.task["usage"], {"input_tokens": 30, "output_tokens": 5})

    def test_non_numeric_existing_total_cost_usd_does_not_raise(self):
        # 再レビューで発見した回帰: state.jsonが手動編集等で
        # "total_cost_usd": null (あるいは文字列等)を既に持っている状態で
        # 新しいコストを加算しようとすると、素朴に
        # task.get("total_cost_usd", 0) + cost するとTypeErrorになる
        # (dict.getのdefaultはキーが無いときしか使われないため)。
        # run_task_with_retry内でこの呼び出しはtry/exceptに囲まれておらず、
        # ここで例外を出すとタスク単体ではなくnight_runner.py全体が落ちて
        # 残りの全タスクが処理されなくなる。既存値が数値でなければ0として
        # 扱い、例外を出さずに加算できることを確認する。
        self.task["total_cost_usd"] = None
        with mock.patch.object(night_runner, "save_state"):
            night_runner._record_cost_and_usage(self.task, self.state, {"total_cost_usd": 1.5})
        self.assertEqual(self.task["total_cost_usd"], 1.5)


class RateLimitEnvelopeTest(unittest.TestCase):
    def test_is_error_with_rate_limit_text_is_detected(self):
        envelope = {"is_error": True, "subtype": "error_during_execution", "result": "429 too many requests"}
        self.assertTrue(night_runner._envelope_is_rate_limited(envelope))

    def test_is_error_without_rate_limit_text_is_not_detected(self):
        envelope = {"is_error": True, "subtype": "error_max_turns", "result": "gave up after too many turns"}
        self.assertFalse(night_runner._envelope_is_rate_limited(envelope))

    def test_non_error_envelope_is_not_detected(self):
        envelope = {"is_error": False, "result": "usage limit"}  # is_errorでなければ対象外
        self.assertFalse(night_runner._envelope_is_rate_limited(envelope))

    def test_non_dict_is_not_detected(self):
        self.assertFalse(night_runner._envelope_is_rate_limited(None))


class RunTaskWithRetryRateLimitTest(unittest.TestCase):
    """returncode 0 + JSON封筒内でのレートリミット報告が、update_state_doneで
    即failedにされず、backoffリトライへ回ることを確認する(コードレビュー指摘の
    再現ケース)。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state_path = os.path.join(self.tmp.name, "night-run-state.json")
        for name, value in [
            ("STATE_FILE", self.state_path),
            ("ALERTS_LOG", os.path.join(self.tmp.name, "alerts.log")),
            ("MAX_RETRY_ATTEMPTS", 2),
        ]:
            patcher = mock.patch.object(night_runner, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

        self.task = {"title": "タスクA", "status": "pending", "branch": "night-run/task-a"}
        state = {
            "hard_limit": "2999-01-01T00:00:00+09:00",
            "tasks": [self.task],
        }
        with open(self.state_path, "w") as f:
            json.dump(state, f)
        self.state = state

    def test_rate_limited_envelope_retries_then_succeeds(self):
        rate_limited_stdout = json.dumps({
            "is_error": True, "subtype": "error_during_execution", "result": "429 rate limit",
        })
        success_stdout = json.dumps({
            "is_error": False,
            "structured_output": {
                "status": "success", "pr_url": "https://github.com/x/y/pull/1",
                "branch": "night-run/task-a", "review_round": 1,
                "completed_summary": "done", "remaining_summary": "なし",
            },
        })
        responses = [(0, rate_limited_stdout, ""), (0, success_stdout, "")]

        with mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=responses), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner.time, "sleep") as mock_sleep, \
             mock.patch.object(night_runner, "verify_pr", return_value=True):
            night_runner.run_task_with_retry(self.task, self.state)

        mock_sleep.assert_called_once()  # backoffで一度待ってからリトライしたこと
        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "done")  # 一度目でfailed確定していないこと

    def test_rate_limited_defers_task_after_max_attempts(self):
        # 枠が戻らないのは「実装の失敗」ではないので、failedではなく
        # pendingのまま持ち越して次回の実行で再開できるようにする。
        rate_limited_stdout = json.dumps({
            "is_error": True, "subtype": "error_during_execution", "result": "429 rate limit",
        })
        # MAX_RETRY_ATTEMPTS=2に対して3回とも同じレートリミット応答
        responses = [(0, rate_limited_stdout, "")] * 3

        with mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=responses), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner.time, "sleep"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"):
            outcome = night_runner.run_task_with_retry(self.task, self.state)

        self.assertEqual(outcome, "deferred")  # main()はこれを見て実行自体を終える
        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "pending")
        self.assertIn("レートリミット", final_task["deferred_reason"])
        self.assertEqual(final_task["diagnostic_branch"], "diagnostic/x")
        self.assertNotIn("failure_reason", final_task)

    def test_rate_limited_defer_still_records_accumulated_cost_and_usage(self):
        # 持ち越し経路(_handle_rate_limit内でmark_task_deferredを
        # 直接呼ぶ)はupdate_state_doneを経由しないため、記録漏れが起きやすい
        # (コードレビュー指摘の再現ケース)。3回とも同じレートリミット応答だが、
        # 各試行は実際に課金が発生しているため、記録される値は3回分の累積になる
        # (PR #50レビュー指摘: 最後の1回だけを残す実装だと過小評価になる)。
        rate_limited_stdout = json.dumps({
            "is_error": True, "subtype": "error_during_execution", "result": "429 rate limit",
            "total_cost_usd": 2.5, "usage": {"input_tokens": 10, "output_tokens": 5},
        })
        responses = [(0, rate_limited_stdout, "")] * 3

        with mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=responses), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner.time, "sleep"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"):
            night_runner.run_task_with_retry(self.task, self.state)

        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "pending")  # 持ち越し
        self.assertEqual(final_task["total_cost_usd"], 7.5)  # 2.5 x 3試行
        self.assertEqual(final_task["usage"], {"input_tokens": 30, "output_tokens": 15})

    def test_stderr_rate_limit_defer_records_accumulated_cost_if_stdout_has_envelope(self):
        # returncode!=0 でstderrの正規表現マッチにより持ち越す経路でも、
        # stdoutにenvelopeが残っている場合は各試行のコストを累積して記録する。
        stdout_with_cost = json.dumps({"total_cost_usd": 3.7, "usage": {"input_tokens": 20}})
        responses = [(1, stdout_with_cost, "429 rate limit")] * 3

        with mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=responses), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner.time, "sleep"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"):
            night_runner.run_task_with_retry(self.task, self.state)

        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "pending")  # 持ち越し
        self.assertAlmostEqual(final_task["total_cost_usd"], 11.1)  # 3.7 x 3試行(浮動小数点誤差を許容)
        self.assertEqual(final_task["usage"], {"input_tokens": 60})

    def test_cost_accumulates_across_retry_then_success(self):
        # PR #50レビュー指摘: 「リトライを挟んでもコストが累積して記録される」
        # ことを確認する。1試行目(レートリミットで捨てられる)と2試行目(成功)、
        # 両方の実コストが合算されて最終的なtotal_cost_usdになる
        # (最後に完了した試行1回分だけを残す旧実装では、1試行目の2.0が失われ
        # 3.0のみが記録されていた)。
        rate_limited_stdout = json.dumps({
            "is_error": True, "subtype": "error_during_execution", "result": "429 rate limit",
            "total_cost_usd": 2.0, "usage": {"input_tokens": 10, "output_tokens": 4},
        })
        success_stdout = json.dumps({
            "is_error": False,
            "total_cost_usd": 3.0,
            "usage": {"input_tokens": 20, "output_tokens": 8},
            "structured_output": {
                "status": "success", "pr_url": "https://github.com/x/y/pull/1",
                "branch": "night-run/task-a", "review_round": 1,
                "completed_summary": "done", "remaining_summary": "なし",
            },
        })
        responses = [(0, rate_limited_stdout, ""), (0, success_stdout, "")]

        with mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=responses), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner.time, "sleep"), \
             mock.patch.object(night_runner, "verify_pr", return_value=True):
            night_runner.run_task_with_retry(self.task, self.state)

        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "done")
        self.assertEqual(final_task["total_cost_usd"], 5.0)  # 2.0 + 3.0
        self.assertEqual(final_task["usage"], {"input_tokens": 30, "output_tokens": 12})

    def test_retry_cost_persists_even_if_next_attempt_times_out(self):
        # PR #50レビュー指摘(重要): リトライ試行で記録したコストは、
        # save_state()されるより前に次のループのload_state()で上書きされて
        # 失われてはいけない。1試行目はレートリミットで捨てられ、2試行目が
        # TIMEOUT(hard_limit超過扱い)で打ち切られるケースでも、1試行目で
        # 実際に発生していたコストがfailedタスクに残ることを確認する。
        rate_limited_stdout = json.dumps({
            "is_error": True, "subtype": "error_during_execution", "result": "429 rate limit",
            "total_cost_usd": 2.0, "usage": {"input_tokens": 10},
        })
        responses = [
            (0, rate_limited_stdout, ""),
            (None, "", "TIMEOUT"),
        ]

        with mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=responses), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner.time, "sleep"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"), \
             mock.patch.object(night_runner, "create_draft_pr_from_branch"):
            night_runner.run_task_with_retry(self.task, self.state)

        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "failed")
        # 締切まではまだ余裕があるので、hard_limitではなく1タスクの時間上限で切れる
        self.assertEqual(final_task["failure_reason"], "task_time_cap_exceeded")
        self.assertEqual(final_task["total_cost_usd"], 2.0)
        self.assertEqual(final_task["usage"], {"input_tokens": 10})


class GitCleanupRetryTest(unittest.TestCase):
    def test_succeeds_on_second_attempt_without_raising(self):
        with mock.patch.object(
            night_runner, "git_cleanup",
            side_effect=[subprocess.CalledProcessError(1, ["git", "fetch"]), None],
        ), mock.patch.object(night_runner, "notify_human") as mock_notify, \
             mock.patch.object(night_runner, "time") as mock_time:
            night_runner.git_cleanup_with_retry(max_attempts=3, wait_seconds=1)

        mock_time.sleep.assert_called_once_with(1)
        mock_notify.assert_called_once()

    def test_raises_after_exhausting_all_attempts(self):
        error = subprocess.CalledProcessError(1, ["git", "fetch"])
        with mock.patch.object(night_runner, "git_cleanup", side_effect=[error, error, error]), \
             mock.patch.object(night_runner, "notify_human"), \
             mock.patch.object(night_runner, "time"):
            with self.assertRaises(subprocess.CalledProcessError):
                night_runner.git_cleanup_with_retry(max_attempts=3, wait_seconds=1)


class SaveDiagnosticBranchTest(unittest.TestCase):
    """save_diagnostic_branch()自身の失敗(例: git identity未設定)が、元の異常終了
    処理を握り潰してプロセスを落とさないことを確認する(不具合報告の再現ケース)。"""

    def test_git_failure_is_caught_and_returns_none(self):
        task = {"title": "タスクA"}
        error = subprocess.CalledProcessError(128, ["git", "commit"], stderr="Author identity unknown")
        with mock.patch.object(night_runner.subprocess, "run", side_effect=error), \
             mock.patch.object(night_runner, "notify_human") as mock_notify:
            branch = night_runner.save_diagnostic_branch(task)

        self.assertIsNone(branch)
        mock_notify.assert_called_once()

    def test_success_returns_branch_name(self):
        task = {"title": "タスクA"}
        with mock.patch.object(night_runner.subprocess, "run") as mock_run:
            branch = night_runner.save_diagnostic_branch(task)

        self.assertTrue(branch.startswith("diagnostic/"))
        self.assertEqual(mock_run.call_count, 4)  # checkout -b / add -A / commit / push


class HandleHardLimitExceededTest(unittest.TestCase):
    """save_diagnostic_branch()がNoneを返した場合でも、create_draft_pr_from_branch()に
    Noneブランチを渡して失敗させず、通知だけで終えることを確認する。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        patcher_state_file = mock.patch.object(
            night_runner, "STATE_FILE", os.path.join(self.tmp.name, "night-run-state.json")
        )
        patcher_state_file.start()
        self.addCleanup(patcher_state_file.stop)
        self.task = {"title": "タスクA", "status": "pending", "branch": "night-run/task-a"}
        self.state = {"tasks": [self.task]}

    def _terminate(self):
        night_runner.terminate_task_with_draft_pr(
            self.task, self.state,
            failure_code="hard_limit_exceeded",
            pr_reason="締切バッファを超過したため強制終了",
        )

    def test_no_branch_skips_draft_pr_and_notifies(self):
        with mock.patch.object(night_runner, "save_diagnostic_branch", return_value=None), \
             mock.patch.object(night_runner, "create_draft_pr_from_branch") as mock_create_pr, \
             mock.patch.object(night_runner, "notify_human") as mock_notify:
            self._terminate()

        mock_create_pr.assert_not_called()
        self.assertEqual(self.task["status"], "failed")
        # mark_task_failed()自体の通知 + 「draft PRも作れない」通知の2回
        self.assertEqual(mock_notify.call_count, 2)

    def test_with_branch_creates_draft_pr(self):
        with mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"), \
             mock.patch.object(night_runner, "create_draft_pr_from_branch") as mock_create_pr:
            self._terminate()

        mock_create_pr.assert_called_once_with(self.task, "diagnostic/x", reason="締切バッファを超過したため強制終了")

    def test_draft_pr_failure_does_not_kill_the_runner(self):
        # 1タスクの時間上限を入れたことでこの経路は夜の途中でも通る。ghの一時的な
        # 失敗で例外が伝播すると、残りのタスクが全部未着手のまま朝を迎える
        # (コードレビュー指摘の再現ケース)。
        error = subprocess.CalledProcessError(1, ["gh", "pr", "create"])
        with mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"), \
             mock.patch.object(night_runner, "create_draft_pr_from_branch", side_effect=error), \
             mock.patch.object(night_runner, "notify_human") as mock_notify:
            self._terminate()  # 例外が飛ばなければOK

        self.assertEqual(self.task["status"], "failed")
        self.assertEqual(self.task["diagnostic_branch"], "diagnostic/x")
        self.assertTrue(any("draft PR" in str(c) for c in mock_notify.call_args_list))


class MaskSecretsTest(unittest.TestCase):
    def test_masks_env_var_values_found_in_text(self):
        with mock.patch.dict(os.environ, {"GH_TOKEN": "ghp_supersecret123"}):
            masked = night_runner._mask_secrets("error: bad credentials ghp_supersecret123 (401)")
        self.assertNotIn("ghp_supersecret123", masked)
        self.assertIn("***MASKED***", masked)

    def test_empty_env_var_is_not_masked_as_empty_string(self):
        # os.environ.get(name)が""だと"".replaceで文字化けする心配があるための回帰確認
        with mock.patch.dict(os.environ, {"GH_TOKEN": ""}):
            text = "no secrets here"
            self.assertEqual(night_runner._mask_secrets(text), text)


class DescribeClaudeFailureTest(unittest.TestCase):
    def test_includes_returncode_and_elapsed_time_even_if_stderr_empty(self):
        # 不具合報告の再現ケース: stderrが空でも診断内容が空にならないこと
        message = night_runner.describe_claude_failure(
            returncode=1, stdout='{"is_error": true}', stderr="", elapsed_seconds=12.3
        )
        self.assertIn("returncode=1", message)
        self.assertIn("12.3", message)
        self.assertIn('{"is_error": true}', message)

    def test_truncates_long_output_with_omitted_count(self):
        long_text = "x" * (night_runner.DIAGNOSTIC_PREVIEW_CHARS + 100)
        message = night_runner.describe_claude_failure(1, long_text, "", 1.0)
        self.assertIn("以下100文字省略", message)


class RunTaskNonRateLimitFailureTest(unittest.TestCase):
    """claude -pがstderrを空にしたまま非0で終了するケース(不具合報告の再現ケース)で、
    失敗理由が空文字にならず、alerts.logにも診断内容が残ることを確認する。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state_path = os.path.join(self.tmp.name, "night-run-state.json")
        for name, value in [
            ("STATE_FILE", self.state_path),
            ("ALERTS_LOG", os.path.join(self.tmp.name, "alerts.log")),
        ]:
            patcher = mock.patch.object(night_runner, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

        self.task = {"title": "タスクA", "status": "pending", "branch": "night-run/task-a"}
        state = {"hard_limit": "2999-01-01T00:00:00+09:00", "tasks": [self.task]}
        with open(self.state_path, "w") as f:
            json.dump(state, f)
        self.state = state

    def test_empty_stderr_nonzero_exit_marks_failed_with_nonblank_reason(self):
        with mock.patch.object(
            night_runner, "run_claude_with_timeout", return_value=(1, "some stdout, no error json", "")
        ), mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"):
            night_runner.run_task_with_retry(self.task, self.state)

        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "failed")
        self.assertTrue(final_task["failure_reason"].strip())  # 空文字にならないこと

        with open(os.path.join(self.tmp.name, "alerts.log")) as f:
            alerts = f.read()
        self.assertIn("returncode=1", alerts)
        self.assertIn("some stdout, no error json", alerts)


class DraftPrBodyTest(unittest.TestCase):
    def test_body_has_no_todo_placeholder_and_embeds_progress(self):
        task = {
            "title": "タスクB",
            "step": "レビュー",
            "review_round": 2,
            "completed_summary": "画面Aを実装した",
        }
        with mock.patch.object(night_runner, "subprocess") as mock_subprocess:
            night_runner.create_draft_pr_from_branch(task, "diagnostic/task-b-1", "hard_limit_exceeded")

        create_call = next(
            c for c in mock_subprocess.run.call_args_list if c.args[0][0:2] == ["gh", "pr"]
        )
        argv = create_call.args[0]
        body_index = argv.index("--body") + 1
        body = argv[body_index]

        self.assertNotIn("TODO", body)
        self.assertIn("レビュー", body)
        self.assertIn("画面Aを実装した", body)


def clean_limit_env(**overrides):
    """NIGHT_RUN_* の設定系環境変数を取り除いた状態を作る。実行環境に残っている
    値でテストの期待値がぶれないようにするため。"""
    env = {
        k: v for k, v in os.environ.items()
        if k not in night_runner.LIMIT_ENV_VARS.values()
    }
    env.update(overrides)
    return mock.patch.dict(os.environ, env, clear=True)


class ResolveLimitsTest(unittest.TestCase):
    """消費量の設定は 環境変数 > state["limits"] > DEFAULT_LIMITS の順で解決する。"""

    def setUp(self):
        patcher = mock.patch.object(night_runner, "notify_human")
        self.notify = patcher.start()
        self.addCleanup(patcher.stop)

    def test_defaults_are_pro_plan_oriented(self):
        # 夜間は締切まで使い切ってよい(タスク数は無制限)が、1タスクは時間と
        # 金額の両方で必ず頭打ちにする——1件が夜を丸ごと食わないようにするため。
        with clean_limit_env():
            limits = night_runner.resolve_limits({})
        self.assertEqual(limits["model"], "sonnet")   # ProにOpusは含まれない
        self.assertEqual(limits["effort"], "medium")
        self.assertEqual(limits["autocompact"], "150k")     # 1タスクが長引いても文脈を頭打ちに
        self.assertEqual(limits["max_tasks_per_run"], 0)    # 無制限
        self.assertEqual(limits["max_review_rounds"], 2)
        self.assertEqual(limits["max_task_minutes"], 60)
        self.assertEqual(limits["max_budget_usd_per_task"], 8.0)
        self.assertEqual(limits["max_total_budget_usd"], 50.0)

    def test_state_limits_override_defaults(self):
        with clean_limit_env():
            limits = night_runner.resolve_limits(
                {"limits": {"model": "opus", "max_tasks_per_run": 5}}
            )
        self.assertEqual(limits["model"], "opus")
        self.assertEqual(limits["max_tasks_per_run"], 5)
        self.assertEqual(limits["effort"], "medium")  # 指定しなかったものは既定のまま

    def test_env_var_overrides_state(self):
        with clean_limit_env(NIGHT_RUN_MAX_TASKS="3"):
            limits = night_runner.resolve_limits({"limits": {"max_tasks_per_run": 5}})
        self.assertEqual(limits["max_tasks_per_run"], 3)

    def test_empty_env_var_does_not_override(self):
        # run.sh/entrypoint.shは未設定の変数を渡さない方針だが、空文字が
        # 紛れ込んでもstateの設定を潰さないこと。
        with clean_limit_env(NIGHT_RUN_MODEL="   "):
            limits = night_runner.resolve_limits({"limits": {"model": "haiku"}})
        self.assertEqual(limits["model"], "haiku")

    def test_unknown_key_in_state_is_ignored(self):
        with clean_limit_env():
            limits = night_runner.resolve_limits({"limits": {"max_turns": 10}})
        self.assertNotIn("max_turns", limits)

    def test_non_numeric_value_falls_back_to_default_without_raising(self):
        with clean_limit_env(NIGHT_RUN_MAX_TASK_MINUTES="たくさん"):
            limits = night_runner.resolve_limits({})
        self.assertEqual(limits["max_task_minutes"], 60)
        self.notify.assert_called()  # 黙って既定値に戻さず、alerts.logに残す

    def test_negative_value_falls_back_to_default(self):
        with clean_limit_env():
            limits = night_runner.resolve_limits({"limits": {"max_total_budget_usd": -1}})
        self.assertEqual(limits["max_total_budget_usd"], 50.0)

    def test_unknown_effort_falls_back_to_default(self):
        # 未知のeffortをそのまま渡すとCLIが引数エラーで即死し、その夜が
        # 丸ごと無駄になるため、既定値へ寄せて警告だけ残す。
        with clean_limit_env(NIGHT_RUN_EFFORT="ultra"):
            limits = night_runner.resolve_limits({})
        self.assertEqual(limits["effort"], "medium")
        self.notify.assert_called()

    def test_autocompact_can_be_overridden(self):
        with clean_limit_env(NIGHT_RUN_AUTOCOMPACT="auto"):
            limits = night_runner.resolve_limits({"limits": {"autocompact": "200k"}})
        self.assertEqual(limits["autocompact"], "auto")

    def test_out_of_range_autocompact_falls_back_to_default(self):
        # CLIが受け付けるのは100k〜1M。範囲外をそのまま渡すと引数エラーで
        # claude -pが起動直後に落ち、その夜のタスクが1件も進まない。
        for bad in ("50k", "2000k", "だいたい"):
            with self.subTest(bad=bad):
                self.notify.reset_mock()
                with clean_limit_env(NIGHT_RUN_AUTOCOMPACT=bad):
                    limits = night_runner.resolve_limits({})
                self.assertEqual(limits["autocompact"], "150k")
                self.notify.assert_called()

    def test_autocompact_accepts_auto_and_plain_token_counts(self):
        for good in ("auto", "100k", "1000000", "150000"):
            with self.subTest(good=good):
                self.notify.reset_mock()
                with clean_limit_env(NIGHT_RUN_AUTOCOMPACT=good):
                    limits = night_runner.resolve_limits({})
                self.assertEqual(limits["autocompact"], good)
                self.notify.assert_not_called()

    def test_zero_means_unlimited_and_is_preserved(self):
        with clean_limit_env():
            limits = night_runner.resolve_limits(
                {"limits": {"max_tasks_per_run": 0, "max_total_budget_usd": 0}}
            )
        self.assertEqual(limits["max_tasks_per_run"], 0)
        self.assertEqual(limits["max_total_budget_usd"], 0)


class BuildClaudeArgvTest(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.object(night_runner, "notify_human")
        self.notify = patcher.start()
        self.addCleanup(patcher.stop)

    def _limits(self, **overrides):
        limits = dict(night_runner.DEFAULT_LIMITS)
        limits.update(overrides)
        return limits

    def test_model_effort_and_budget_are_passed(self):
        with mock.patch.object(night_runner, "claude_supported_flags", return_value=None):
            argv = night_runner.build_claude_argv("p", self._limits())
        self.assertEqual(argv[argv.index("--model") + 1], "sonnet")
        self.assertEqual(argv[argv.index("--effort") + 1], "medium")
        self.assertEqual(argv[argv.index("--autocompact") + 1], "150k")
        self.assertEqual(argv[argv.index("--max-budget-usd") + 1], "8.0")

    def test_unsupported_flags_are_dropped_instead_of_crashing_the_cli(self):
        # 古いCLIが焼き込まれたイメージで --effort を渡すと引数エラーで即死し、
        # その夜のタスクが1件も進まない。落として警告する方を選ぶ。
        supported = frozenset({"--model", "--output-format", "--max-budget-usd"})
        with mock.patch.object(night_runner, "claude_supported_flags", return_value=supported):
            argv = night_runner.build_claude_argv("p", self._limits())
        self.assertIn("--model", argv)
        self.assertNotIn("--effort", argv)
        self.notify.assert_called()

    def test_zero_budget_is_omitted(self):
        with mock.patch.object(night_runner, "claude_supported_flags", return_value=None):
            argv = night_runner.build_claude_argv("p", self._limits(max_budget_usd_per_task=0))
        self.assertNotIn("--max-budget-usd", argv)

    def test_empty_model_is_omitted(self):
        with mock.patch.object(night_runner, "claude_supported_flags", return_value=None):
            argv = night_runner.build_claude_argv("p", self._limits(model=""))
        self.assertNotIn("--model", argv)

    def test_empty_autocompact_is_omitted(self):
        with mock.patch.object(night_runner, "claude_supported_flags", return_value=None):
            argv = night_runner.build_claude_argv("p", self._limits(autocompact=""))
        self.assertNotIn("--autocompact", argv)

    def test_unsupported_autocompact_flag_is_dropped(self):
        supported = frozenset({"--model", "--effort", "--output-format"})
        with mock.patch.object(night_runner, "claude_supported_flags", return_value=supported):
            argv = night_runner.build_claude_argv("p", self._limits())
        self.assertIn("--effort", argv)
        self.assertNotIn("--autocompact", argv)
        self.notify.assert_called()

    def test_reviewer_model_is_only_set_when_configured(self):
        without = json.loads(night_runner.reviewer_agents_json(self._limits()))
        self.assertNotIn("model", without["reviewer"])
        with_model = json.loads(
            night_runner.reviewer_agents_json(self._limits(reviewer_model="haiku"))
        )
        self.assertEqual(with_model["reviewer"]["model"], "haiku")
        # 元の定義を書き換えていないこと(次のタスクに漏れない)
        self.assertNotIn("model", night_runner.REVIEWER_AGENT_DEFINITION["reviewer"])


class ParseRateLimitResetTest(unittest.TestCase):
    def test_epoch_after_pipe_is_parsed(self):
        # Claude Code CLIが返す "Claude AI usage limit reached|<epoch>" 形式
        reset = night_runner.parse_rate_limit_reset("Claude AI usage limit reached|1757808000")
        self.assertEqual(reset, datetime.datetime.fromtimestamp(1757808000, datetime.timezone.utc))

    def test_iso_with_timezone_is_parsed(self):
        reset = night_runner.parse_rate_limit_reset("usage limit; resets at 2026-09-14T03:00:00+09:00")
        self.assertEqual(
            reset,
            datetime.datetime(2026, 9, 13, 18, 0, tzinfo=datetime.timezone.utc),
        )

    def test_naive_iso_is_treated_as_utc(self):
        reset = night_runner.parse_rate_limit_reset("rate limit reset 2026-09-14 03:00:00")
        self.assertEqual(reset, datetime.datetime(2026, 9, 14, 3, 0, tzinfo=datetime.timezone.utc))

    def test_returns_none_when_no_reset_information(self):
        self.assertIsNone(night_runner.parse_rate_limit_reset("429 rate limit"))
        self.assertIsNone(night_runner.parse_rate_limit_reset(""))
        self.assertIsNone(night_runner.parse_rate_limit_reset(None))


class PlanRateLimitWaitTest(unittest.TestCase):
    def setUp(self):
        self.now = datetime.datetime(2026, 9, 14, 0, 0, tzinfo=datetime.timezone.utc)

    def test_waits_until_reset_time_when_it_fits_in_the_window(self):
        reset_epoch = int((self.now + datetime.timedelta(hours=2)).timestamp())
        hard_limit = self.now + datetime.timedelta(hours=6)
        action, wait_seconds, reset_at = night_runner.plan_rate_limit_wait(
            1, f"usage limit reached|{reset_epoch}", self.now, hard_limit,
        )
        self.assertEqual(action, "wait")
        self.assertAlmostEqual(
            wait_seconds, 2 * 3600 + night_runner.RATE_LIMIT_RESET_MARGIN_SECONDS, delta=1
        )
        self.assertIsNotNone(reset_at)

    def test_defers_when_reset_is_after_the_hard_limit(self):
        # Pro契約の5時間枠。締切までに戻らないと分かっているのに待つのは
        # 待ち時間もトークンも無駄なので、待たずに持ち越す。
        reset_epoch = int((self.now + datetime.timedelta(hours=5)).timestamp())
        hard_limit = self.now + datetime.timedelta(hours=2)
        action, wait_seconds, _ = night_runner.plan_rate_limit_wait(
            1, f"usage limit reached|{reset_epoch}", self.now, hard_limit,
        )
        self.assertEqual(action, "defer")
        self.assertEqual(wait_seconds, 0.0)

    def test_defers_when_only_a_few_minutes_would_remain(self):
        reset_epoch = int((self.now + datetime.timedelta(minutes=50)).timestamp())
        hard_limit = self.now + datetime.timedelta(minutes=55)
        action, _, _ = night_runner.plan_rate_limit_wait(
            1, f"usage limit reached|{reset_epoch}", self.now, hard_limit,
        )
        self.assertEqual(action, "defer")

    def test_falls_back_to_backoff_when_reset_time_is_unknown(self):
        hard_limit = self.now + datetime.timedelta(hours=6)
        action, wait_seconds, reset_at = night_runner.plan_rate_limit_wait(
            2, "429 rate limit", self.now, hard_limit,
        )
        self.assertEqual(action, "wait")
        self.assertEqual(wait_seconds, float(night_runner.backoff_seconds(2)))
        self.assertIsNone(reset_at)

    def test_past_reset_time_falls_back_to_backoff_instead_of_zero_wait(self):
        # 「5時間枠は明けたが週次上限で止まっている」場合や、エージェントの出力に
        # 紛れた10桁数字を誤検出した場合、解除時刻が過去になる。0秒待機で
        # リトライを撃ち切ると、その夜が数秒で終わる(コードレビュー指摘)。
        past_epoch = int((self.now - datetime.timedelta(hours=1)).timestamp())
        hard_limit = self.now + datetime.timedelta(hours=6)
        action, wait_seconds, _ = night_runner.plan_rate_limit_wait(
            1, f"usage limit reached|{past_epoch}", self.now, hard_limit,
        )
        self.assertEqual(action, "wait")
        self.assertEqual(wait_seconds, float(night_runner.backoff_seconds(1)))

    def test_wait_is_budgeted_against_deadline_not_hard_limit(self):
        # 第4引数は deadline(人が「何時まで」と答えた時刻)。hard_limitは進行中の
        # 作業を終わらせる猶予であって、そこまで眠ってよい時刻ではない。
        reset_epoch = int((self.now + datetime.timedelta(hours=3)).timestamp())
        deadline = self.now + datetime.timedelta(hours=3)  # 起きた時点で締切を過ぎる
        action, _, _ = night_runner.plan_rate_limit_wait(
            1, f"usage limit reached|{reset_epoch}", self.now, deadline,
        )
        self.assertEqual(action, "defer")

    def test_defers_once_retry_attempts_are_exhausted(self):
        hard_limit = self.now + datetime.timedelta(hours=6)
        action, _, _ = night_runner.plan_rate_limit_wait(
            night_runner.MAX_RETRY_ATTEMPTS + 1, "429 rate limit", self.now, hard_limit,
        )
        self.assertEqual(action, "defer")


class ClearDeferredMarkersTest(unittest.TestCase):
    def test_done_clears_previous_deferral(self):
        task = {
            "title": "タスクA", "status": "pending", "branch": "night-run/task-a",
            "deferred_reason": "レートリミット", "deferred_at": "2026-09-14T00:00:00+00:00",
            "rate_limit_reset_at": "2026-09-14T05:00:00+00:00",
        }
        state = {"tasks": [task]}
        envelope = {
            "is_error": False,
            "structured_output": {
                "status": "success", "pr_url": "https://github.com/x/y/pull/1",
                "branch": "night-run/task-a", "review_round": 1,
                "completed_summary": "done", "remaining_summary": "なし",
            },
        }
        with mock.patch.object(night_runner, "verify_pr", return_value=True), \
             mock.patch.object(night_runner, "save_state"):
            night_runner.update_state_done(task, state, envelope)
        self.assertEqual(task["status"], "done")
        self.assertNotIn("deferred_reason", task)
        self.assertNotIn("rate_limit_reset_at", task)


class MainRunLimitsTest(unittest.TestCase):
    """1回の実行で使い切らないための歯止め(タスク数・実行全体の予算)。"""

    def setUp(self):
        # main()はos.chdir(REPO_DIR)する。TemporaryDirectoryを消す前にCWDを戻さないと、
        # 以降のテストが存在しないディレクトリから動くことになる(コードレビュー指摘)。
        self.addCleanup(os.chdir, os.getcwd())
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state_path = os.path.join(self.tmp.name, "night-run-state.json")
        marker = os.path.join(self.tmp.name, "sandbox-marker")
        open(marker, "w").close()
        for name, value in [
            ("STATE_FILE", self.state_path),
            ("ALERTS_LOG", os.path.join(self.tmp.name, "alerts.log")),
            ("SANDBOX_MARKER_FILE", marker),
            ("REPO_DIR", self.tmp.name),
        ]:
            patcher = mock.patch.object(night_runner, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        for target in ("notify_human", "git_cleanup_with_retry"):
            patcher = mock.patch.object(night_runner, target)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = mock.patch.dict(os.environ, {"NIGHT_RUNNER_SANDBOX": "1"})
        patcher.start()
        self.addCleanup(patcher.stop)

    def _write_state(self, limits, task_count=3):
        state = {
            "deadline": "2999-01-01T00:00:00+09:00",
            "hard_limit": "2999-01-01T01:00:00+09:00",
            "limits": limits,
            "tasks": [
                {"title": f"タスク{i}", "status": "pending", "branch": f"night-run/task-{i}"}
                for i in range(1, task_count + 1)
            ],
        }
        with open(self.state_path, "w") as f:
            json.dump(state, f)

    @staticmethod
    def _complete_with_cost(cost):
        def side_effect(task, state):
            task["status"] = "done"
            task["total_cost_usd"] = cost
            night_runner.save_state(state)
        return side_effect

    def test_stops_after_max_tasks_per_run_and_leaves_the_rest_pending(self):
        self._write_state({"max_tasks_per_run": 2, "max_total_budget_usd": 0})
        with clean_limit_env(), \
             mock.patch.object(
                 night_runner, "run_task_with_retry",
                 side_effect=self._complete_with_cost(1.0),
             ) as mock_run:
            night_runner.main()

        self.assertEqual(mock_run.call_count, 2)
        state = night_runner.load_state()
        self.assertEqual([t["status"] for t in state["tasks"]], ["done", "done", "pending"])
        self.assertEqual(state["run_summary"]["tasks_started"], 2)
        self.assertIn("タスク数上限", state["run_summary"]["stopped_reason"])

    def test_stops_when_total_budget_is_reached(self):
        # 1タスク4ドル・上限5ドル: 1件目で4ドル(継続) → 2件目で8ドル(打ち切り)
        self._write_state({"max_tasks_per_run": 0, "max_total_budget_usd": 5})
        with clean_limit_env(), \
             mock.patch.object(
                 night_runner, "run_task_with_retry",
                 side_effect=self._complete_with_cost(4.0),
             ) as mock_run:
            night_runner.main()

        self.assertEqual(mock_run.call_count, 2)
        state = night_runner.load_state()
        self.assertEqual(state["tasks"][2]["status"], "pending")
        self.assertIn("予算上限", state["run_summary"]["stopped_reason"])
        self.assertAlmostEqual(state["run_summary"]["spent_usd"], 8.0)

    def test_deferred_task_stops_the_run(self):
        # 枠が戻らないまま次のタスクへ進んでも同じところで止まるだけなので、
        # 実行自体を終えて残りは次回に回す。
        self._write_state({"max_tasks_per_run": 0, "max_total_budget_usd": 0})

        def defer(task, state):
            task["deferred_reason"] = "レートリミットのため中断"
            night_runner.save_state(state)
            return "deferred"

        with clean_limit_env(), \
             mock.patch.object(night_runner, "run_task_with_retry", side_effect=defer) as mock_run:
            night_runner.main()

        self.assertEqual(mock_run.call_count, 1)
        state = night_runner.load_state()
        self.assertEqual([t["status"] for t in state["tasks"]], ["pending"] * 3)
        self.assertIn("レートリミット", state["run_summary"]["stopped_reason"])

    def test_only_this_runs_cost_counts_toward_the_budget(self):
        # total_cost_usdは夜をまたいで累積する(issue #47)。前回までの消費を
        # 今回の予算にカウントすると、再開した瞬間に上限に達してしまう。
        self._write_state({"max_tasks_per_run": 0, "max_total_budget_usd": 5})
        state = json.load(open(self.state_path))
        state["tasks"][0]["total_cost_usd"] = 100.0  # 前回までの累積
        with open(self.state_path, "w") as f:
            json.dump(state, f)

        def add_cost(task, state):
            task["status"] = "done"
            task["total_cost_usd"] = night_runner._task_cost_usd(task) + 1.0
            night_runner.save_state(state)

        with clean_limit_env(), \
             mock.patch.object(night_runner, "run_task_with_retry", side_effect=add_cost) as mock_run:
            night_runner.main()

        self.assertEqual(mock_run.call_count, 3)  # 増分1ドル x 3件 = 上限未満
        self.assertAlmostEqual(night_runner.load_state()["run_summary"]["spent_usd"], 3.0)


class TaskTimeCapTest(unittest.TestCase):
    """1タスクが夜を丸ごと使い切らないための時間上限。金額の上限
    (--max-budget-usd)はサブスク認証だとコストが報告されず効かないことが
    あるため、時間で切れる手段を併せて持つ。"""

    def _limits(self, minutes):
        return dict(night_runner.DEFAULT_LIMITS, max_task_minutes=minutes)

    def test_cap_shorter_than_remaining_time_wins(self):
        seconds, hit_cap = night_runner.task_timeout_seconds(8 * 3600, self._limits(60))
        self.assertEqual(seconds, 3600)
        self.assertTrue(hit_cap)

    def test_remaining_time_shorter_than_cap_wins(self):
        # 締切間際は締切の方が先に来る(こちらはhard_limit扱い)
        seconds, hit_cap = night_runner.task_timeout_seconds(600, self._limits(60))
        self.assertEqual(seconds, 600)
        self.assertFalse(hit_cap)

    def test_zero_means_no_task_cap(self):
        seconds, hit_cap = night_runner.task_timeout_seconds(8 * 3600, self._limits(0))
        self.assertEqual(seconds, 8 * 3600)
        self.assertFalse(hit_cap)


class TaskTimeCapIntegrationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state_path = os.path.join(self.tmp.name, "night-run-state.json")
        for name, value in [
            ("STATE_FILE", self.state_path),
            ("ALERTS_LOG", os.path.join(self.tmp.name, "alerts.log")),
        ]:
            patcher = mock.patch.object(night_runner, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.task = {"title": "タスクA", "status": "pending", "branch": "night-run/task-a"}
        state = {"hard_limit": "2999-01-01T00:00:00+09:00", "tasks": [self.task]}
        with open(self.state_path, "w") as f:
            json.dump(state, f)
        self.state = state

    def test_timeout_at_task_cap_salvages_to_draft_pr_and_moves_on(self):
        # 締切(2999年)にはまだ余裕があるので、これはhard_limit超過ではなく
        # 1タスクの時間上限による打ち切り。作業はdraft PRへ退避し、
        # run_task_with_retryは戻る(main()が次のタスクへ進める)。
        with clean_limit_env(), \
             mock.patch.object(night_runner, "run_claude_with_timeout", return_value=(None, "", "TIMEOUT")), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner, "notify_human"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"), \
             mock.patch.object(night_runner, "create_draft_pr_from_branch") as mock_pr:
            outcome = night_runner.run_task_with_retry(self.task, self.state)

        self.assertIsNone(outcome)  # "deferred"ではない: 実行は続く
        final_task = night_runner.load_state()["tasks"][0]
        self.assertEqual(final_task["status"], "failed")
        self.assertEqual(final_task["failure_reason"], "task_time_cap_exceeded")
        mock_pr.assert_called_once()
        self.assertIn("60分", mock_pr.call_args.kwargs["reason"])

    def test_timeout_passed_to_claude_is_capped(self):
        captured = {}

        def fake_run(prompt, timeout_seconds, limits=None):
            captured["timeout"] = timeout_seconds
            return (None, "", "TIMEOUT")

        with clean_limit_env(), \
             mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=fake_run), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner, "notify_human"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value=None):
            night_runner.run_task_with_retry(self.task, self.state)

        # 締切まで数百年あっても、claude -p に渡るのは60分
        self.assertEqual(captured["timeout"], 3600)


class GenerateSummaryTest(unittest.TestCase):
    def test_deferred_tasks_are_listed_separately_from_untouched_ones(self):
        with tempfile.TemporaryDirectory() as tmp:
            state_path = os.path.join(tmp, "night-run-state.json")
            state = {
                "tasks": [
                    {"title": "済", "status": "done", "pr_url": "u", "total_cost_usd": 1.5},
                    {"title": "持ち越し", "status": "pending",
                     "deferred_reason": "レートリミットのため中断", "diagnostic_branch": "diagnostic/x"},
                    {"title": "未着手", "status": "pending"},
                ],
                "run_summary": {"tasks_started": 1, "spent_usd": 1.5, "stopped_reason": "テスト"},
            }
            with mock.patch.object(night_runner, "STATE_FILE", state_path):
                night_runner.generate_summary(state)
                summary = open(os.path.join(tmp, "summary.txt"), encoding="utf-8").read()

        self.assertIn("持ち越し: 1件", summary)
        self.assertIn("未着手: 1件", summary)
        self.assertIn("[deferred] 持ち越し", summary)
        self.assertIn("[pending] 未着手", summary)
        self.assertIn("$1.50", summary)


if __name__ == "__main__":
    unittest.main()
