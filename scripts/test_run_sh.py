"""scripts/run.sh の引数の組み立てを確かめる。

本物の flutter の代わりに、受け取った引数を1行ずつ出すだけの偽の flutter を
PATH の先頭に置いて run.sh を実行する。
使い方: python3 scripts/test_run_sh.py
"""

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

RUN_SH = Path(__file__).resolve().parent / "run.sh"


def run(*args: str) -> list[str]:
    with tempfile.TemporaryDirectory() as bin_dir:
        fake = Path(bin_dir) / "flutter"
        fake.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@"\n')
        fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
        env = {**os.environ, "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}"}
        result = subprocess.run(
            ["bash", str(RUN_SH), *args],
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
    return result.stdout.splitlines()


class RunShTest(unittest.TestCase):
    def test_付けなければDEBUG_MISSIONを足さない(self):
        out = run("-d", "emulator-5554")
        self.assertEqual(out[0], "run")
        self.assertNotIn("--dart-define=DEBUG_MISSION=true", out)
        self.assertEqual(out[-2:], ["-d", "emulator-5554"])

    def test_mission_debugでDEBUG_MISSIONを足しオプション自体は渡さない(self):
        out = run("-d", "emulator-5554", "--mission-debug")
        self.assertIn("--dart-define=DEBUG_MISSION=true", out)
        self.assertNotIn("--mission-debug", out)
        self.assertIn("-d", out)
        self.assertIn("emulator-5554", out)

    def test_mission_debugは先頭に置いてもよい(self):
        out = run("--mission-debug", "-d", "emulator-5554")
        self.assertIn("--dart-define=DEBUG_MISSION=true", out)
        self.assertNotIn("--mission-debug", out)

    def test_空白を含む引数を割らない(self):
        out = run("--mission-debug", "--route", "/a b")
        self.assertIn("/a b", out)


if __name__ == "__main__":
    unittest.main()
