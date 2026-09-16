#!/usr/bin/env python3
"""night_runner.pyの純粋関数・フェイルセーフ挙動のユニットテスト。

docker/claude/ghの実プロセスは呼ばず、subprocessやネットワークをモックする。
実行方法: python3 night-run/test_night_runner.py
"""
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

    def test_rate_limited_envelope_gives_up_after_max_attempts(self):
        rate_limited_stdout = json.dumps({
            "is_error": True, "subtype": "error_during_execution", "result": "429 rate limit",
        })
        # MAX_RETRY_ATTEMPTS=2に対して3回とも同じレートリミット応答
        responses = [(0, rate_limited_stdout, "")] * 3

        with mock.patch.object(night_runner, "run_claude_with_timeout", side_effect=responses), \
             mock.patch.object(night_runner, "build_prompt", return_value="prompt"), \
             mock.patch.object(night_runner.time, "sleep"), \
             mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"):
            night_runner.run_task_with_retry(self.task, self.state)

        final_state = night_runner.load_state()
        final_task = final_state["tasks"][0]
        self.assertEqual(final_task["status"], "failed")

    def test_rate_limited_give_up_still_records_accumulated_cost_and_usage(self):
        # give-up経路(_retry_after_rate_limit_or_give_up内でmark_task_failedを
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
        self.assertEqual(final_task["status"], "failed")
        self.assertEqual(final_task["total_cost_usd"], 7.5)  # 2.5 x 3試行
        self.assertEqual(final_task["usage"], {"input_tokens": 30, "output_tokens": 15})

    def test_stderr_rate_limit_give_up_records_accumulated_cost_if_stdout_has_envelope(self):
        # returncode!=0 でstderrの正規表現マッチによりgive-upする経路でも、
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
        self.assertEqual(final_task["status"], "failed")
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
        self.assertEqual(final_task["failure_reason"], "hard_limit_exceeded")
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

    def test_no_branch_skips_draft_pr_and_notifies(self):
        with mock.patch.object(night_runner, "save_diagnostic_branch", return_value=None), \
             mock.patch.object(night_runner, "create_draft_pr_from_branch") as mock_create_pr, \
             mock.patch.object(night_runner, "notify_human") as mock_notify:
            night_runner.handle_hard_limit_exceeded(self.task, self.state)

        mock_create_pr.assert_not_called()
        self.assertEqual(self.task["status"], "failed")
        # mark_task_failed()自体の通知 + 「draft PRも作れない」通知の2回
        self.assertEqual(mock_notify.call_count, 2)

    def test_with_branch_creates_draft_pr(self):
        with mock.patch.object(night_runner, "save_diagnostic_branch", return_value="diagnostic/x"), \
             mock.patch.object(night_runner, "create_draft_pr_from_branch") as mock_create_pr:
            night_runner.handle_hard_limit_exceeded(self.task, self.state)

        mock_create_pr.assert_called_once_with(self.task, "diagnostic/x", reason="締切バッファを超過したため強制終了")


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


if __name__ == "__main__":
    unittest.main()
