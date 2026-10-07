#!/usr/bin/env python3
"""Process-level regression tests; deliberately independent of teSHT assertions."""

import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get("TESHT_BASH", shutil.which("bash") or "bash")
RUNNER = ROOT / "tesht.sh"


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tesht-regression-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.scratch = self.root / "runner scratch"
        self.scratch.mkdir()
        self.env = dict(os.environ, LC_ALL="C", TMPDIR=str(self.scratch))
        self.env.pop("BASH_ENV", None)
        self.env.pop("SHELLOPTS", None)
        self.index = 0

    def fixture(self, code, name=None):
        self.index += 1
        path = self.root / (name or f"case-{self.index}.tsh")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(code, encoding="utf-8")
        return path

    def run_files(self, *files, expected=0, env=None):
        result = subprocess.run(
            [BASH, str(RUNNER), *(str(path) for path in files)],
            cwd=self.root, env=env or self.env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertEqual(list(self.scratch.iterdir()), [], "runner leaked temporary files")
        return result

    def run_code(self, code, expected=0):
        return self.run_files(self.fixture(code), expected=expected)

    def test_bundled_examples(self):
        result = self.run_files(ROOT / "tests/example.tsh", ROOT / "examples/assertions.tsh")
        self.assertIn("14 assertions, 14 passed, 0 failed", result.stdout)

    def test_no_arguments_and_help(self):
        self.assertIn("Usage:", self.run_files(expected=2).stderr)
        self.assertIn("Usage:", self.run_files("--help").stdout)
        self.run_files("--", expected=2)

    def test_missing_unmatched_directory_and_syntax_error(self):
        directory = self.root / "directory"
        directory.mkdir()
        invalid = self.fixture("if then\n")
        for path in [self.root / "missing.tsh", self.root / "missing-*.tsh", directory, invalid]:
            with self.subTest(path=path):
                result = self.run_files(path, expected=2)
                self.assertIn("ERROR", result.stderr)
                self.assertNotIn("Loading", result.stdout)

    def test_invalid_selection_runs_nothing(self):
        marker = self.root / "marker"
        valid = self.fixture('touch marker\nassert_equal ok ok\n')
        self.run_files(valid, self.root / "missing.tsh", expected=2)
        self.assertFalse(marker.exists())

    def test_unreadable_file(self):
        if hasattr(os, "geteuid") and os.geteuid() == 0:
            self.skipTest("root bypasses file read permissions")
        path = self.fixture("assert_equal ok ok\n")
        path.chmod(0)
        self.addCleanup(path.chmod, 0o600)
        self.run_files(path, expected=2)

    def test_paths_with_spaces_newlines_and_glob_characters(self):
        paths = [self.fixture("assert_equal ok ok\n", name) for name in
                 ["space dir/a one.tsh", "space dir/b\ntwo.tsh", "[literal]*.tsh", "-case.tsh"]]
        self.run_files(*paths)
        result = self.run_files(str(self.root / "space dir/*.tsh"))
        self.assertIn("2 assertions, 2 passed", result.stdout)
        self.run_files("--", "-case.tsh")

    def test_pattern_is_not_evaluated_as_shell_code(self):
        self.run_files("$(touch marker)*.tsh", expected=2)
        self.assertFalse((self.root / "marker").exists())

    def test_exact_arguments_and_command_path(self):
        command = self.root / "command with spaces"
        command.write_text('#!/usr/bin/env bash\nprintf "<%s>\\n" "$@"\n')
        command.chmod(0o700)
        self.run_code('''test "./command with spaces" "two words" "" "*" "[abc]" '$(false)' "-n"
assert_success
assert_stdout_equal $'<two words>\n<>\n<*>\n<[abc]>\n<$(false)>\n<-n>\n'
''')

    def test_commands_share_state_within_file(self):
        self.run_code('''test mkdir -p "$TESHT_TMPDIR/space dir"
assert_success
test cd "$TESHT_TMPDIR/space dir"
assert_success
test pwd
assert_stdout_equal "$TESHT_TMPDIR/space dir"$'\n'
function set_value() { shared_value=changed; }
test set_value
assert_equal changed "$shared_value"
''')

    def test_files_isolate_variables_functions_options_traps_and_cwd(self):
        first = self.fixture('''export example_value=changed
function assert_equal() { false; }
function user_function() { :; }
COMMAND=changed
STDOUT=changed
test true
assert_success
cd "$TESHT_TMPDIR"
set -u
shopt -s nullglob
trap ':' USR1
''')
        second = self.fixture('''assert_equal "" "${example_value-}"
assert_equal "" "${COMMAND-}"
assert_equal "" "${STDOUT-}"
test declare -F user_function
assert_fail
test shopt -q nullglob
assert_fail
assert_equal "" "$(trap -p USR1)"
assert_equal "${PWD}" "$(pwd)"
test builtin test -d "runner scratch"
assert_success
''')
        result = self.run_files(first, second)
        self.assertIn("2 files, 0 failed", result.stdout)

    def test_literal_equality_and_inequality(self):
        cases = [
            ('assert_equal "*" "*"', 0),
            ('assert_equal abc "*"', 1),
            ('assert_equal "" ""', 0),
            ('assert_not_equal abc "*"', 0),
            ('assert_not_equal same same', 1),
            ('assert_equal "a b" "a b"', 0),
        ]
        for code, status in cases:
            with self.subTest(code=code):
                self.run_code(code + "\n", expected=status)

    def test_regex_assertions_and_invalid_patterns(self):
        cases = [
            ('assert_match "^a.+c$" abc', 0),
            ('assert_match "^x$" abc', 1),
            ('assert_not_match "^x$" abc', 0),
            ('assert_not_match abc abc', 1),
            ('assert_match "[" abc', 1),
            ('assert_not_match "[" abc', 1),
        ]
        for code, status in cases:
            with self.subTest(code=code):
                self.run_code(code + "\n", expected=status)

    def test_all_output_assertions_pass_and_fail(self):
        for stream in ["stdout", "stderr"]:
            redirect = " >&2" if stream == "stderr" else ""
            for suffix in ["", "_match", "_equal"]:
                for negate in [False, True]:
                    name = f"assert_{'not_' if negate else ''}{stream}{suffix}"
                    for matches in [False, True]:
                        expected = "hello" if matches else "other"
                        succeeds = matches != negate
                        with self.subTest(assertion=name, matches=matches):
                            self.run_code(
                                f"emit() {{ printf hello{redirect}; }}\ntest emit\n{name} '{expected}'\n",
                                expected=0 if succeeds else 1,
                            )

    def test_literal_output_preserves_newlines_and_regex_keeps_legacy_behavior(self):
        self.run_code('''test printf 'hello\n\n'
assert_stdout '^hello$'
assert_stdout_equal $'hello\n\n'
assert_not_stdout_equal hello
test printf ''
assert_stdout_equal ''
emit() { printf 'first\nsecond\n\n' >&2; }
test emit
assert_stderr_equal $'first\nsecond\n\n'
assert_stderr_match $'^first\nsecond$'
''')
        self.run_code("test printf 'hello\\n'\nassert_stdout_equal hello\n", expected=1)

    def test_capture_files_are_overwritten(self):
        self.run_code('''emit() { printf first; printf error >&2; }
test emit
assert_stdout_equal first
assert_stderr_equal error
test true
assert_stdout_equal ''
assert_stderr_equal ''
''')

    def test_exit_status_assertions(self):
        cases = [
            ("test true\nassert_success", 0),
            ("test false\nassert_success", 1),
            ("test false\nassert_fail", 0),
            ("test true\nassert_fail", 1),
            ("test false\nassert_fail 1", 0),
            ("test false\nassert_fail 2", 1),
            ("test false\nassert_fail 001", 0),
            ("test false\nassert_fail 0", 1),
            ("test false\nassert_fail 256", 1),
            ("test false\nassert_fail invalid", 1),
            ("test false\nassert_fail 999999999999999999999999", 1),
            ("test command_that_does_not_exist_tesht\nassert_fail 127", 0),
            ("set -eu\ntest false\nassert_fail 1", 0),
        ]
        for code, status in cases:
            with self.subTest(code=code):
                self.run_code(code + "\n", expected=status)

    def test_assertions_require_a_command_and_validate_arity(self):
        for code in ["assert_success", "assert_fail", "assert_stdout hello", "assert_stderr_equal ''",
                     "assert_equal one", "assert_not_equal", "assert_match x", "assert_not_match",
                     "assert_file", "assert_dir", "test true\nassert_success extra",
                     "test true\nassert_stdout", "test false\nassert_fail 1 2"]:
            with self.subTest(code=code):
                self.run_code(code + "\n", expected=1)
        self.run_code("test\nassert_success\n", expected=1)

    def test_regular_files_directories_and_symlinks(self):
        self.run_code('''touch "$TESHT_TMPDIR/file"
mkdir "$TESHT_TMPDIR/directory"
ln -s "$TESHT_TMPDIR/file" "$TESHT_TMPDIR/link"
assert_file "$TESHT_TMPDIR/file"
assert_file "$TESHT_TMPDIR/link"
assert_dir "$TESHT_TMPDIR/directory"
''')
        for code in ['assert_file "$TESHT_TMPDIR"', 'assert_file "$TESHT_TMPDIR/missing"',
                     'touch "$TESHT_TMPDIR/file"\nassert_dir "$TESHT_TMPDIR/file"',
                     'assert_dir "$TESHT_TMPDIR/missing"']:
            with self.subTest(code=code):
                self.run_code(code + "\n", expected=1)

    def test_failures_continue_and_summary_aggregates(self):
        first = self.fixture("assert_equal expected received\nassert_equal ok ok\n")
        second = self.fixture("assert_equal fine fine\n")
        result = self.run_files(first, second, expected=1)
        self.assertIn("2 files, 1 failed; 3 assertions, 2 passed, 1 failed; 0 errors", result.stdout)
        self.assertIn(f"{first}:1", result.stdout)
        self.assertIn("expected: expected", result.stdout)
        self.assertIn("received: received", result.stdout)

    def test_nested_assertions_report_user_line_and_command(self):
        result = self.run_code("test printf 'actual\\n'\nassert_stdout_equal expected\n", expected=1)
        self.assertIn(":2:", result.stdout)
        self.assertIn("command: printf", result.stdout)
        self.assertIn("actual", result.stdout)

    def test_empty_files_and_premature_exit_cannot_pass(self):
        for code in ["", "# empty\n", "exit 0\n", "assert_equal ok ok\nexit 0\n",
                     "assert_equal ok ok\nexit 7\n", "assert_equal ok ok\nreturn 3\n",
                     "assert_equal ok ok\nfalse\nassert_equal ignored ignored\n"]:
            with self.subTest(code=code):
                result = self.run_code(code, expected=1)
                self.assertIn("ERROR", result.stderr)

    def test_overridden_exit_trap_cannot_hide_missing_result(self):
        self.run_code("trap ':' EXIT\nassert_equal ok ok\n", expected=1)

    def test_internal_state_uses_reserved_prefix(self):
        self.run_code('''BROKEN=true
TESTFAILED=true
FAILLOG=unused
STDOUT=unused
STDERR=unused
RETURNCODE=123
COMMAND=unused
MESSAGE=unused
setup() { false; }
report() { false; }
test printf ok
assert_success
assert_stdout_equal ok
''')

    def test_relative_tmpdir(self):
        env = dict(self.env, TMPDIR="runner scratch")
        self.run_files(self.fixture('test cd /\nassert_success\n'), env=env)

    def test_unavailable_tmpdir(self):
        env = dict(self.env, TMPDIR=str(self.root / "missing"))
        self.run_files(self.fixture("assert_equal ok ok\n"), env=env, expected=2)

    def test_cleanup_on_termination(self):
        self.check_signal_cleanup(signal.SIGTERM, 143)

    def test_cleanup_on_interrupt(self):
        self.check_signal_cleanup(signal.SIGINT, 130)

    def check_signal_cleanup(self, selected_signal, expected):
        if not hasattr(os, "killpg"):
            self.skipTest("requires POSIX process groups")
        marker = self.root / "ready"
        path = self.fixture('assert_equal ok ok\ntouch ready\nsleep 30\n')
        process = subprocess.Popen(
            [BASH, str(RUNNER), str(path)], cwd=self.root, env=self.env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True,
        )
        try:
            deadline = time.monotonic() + 5
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(marker.exists(), "fixture did not start")
            os.killpg(process.pid, selected_signal)
            output, errors = process.communicate(timeout=5)
            self.assertEqual(process.returncode, expected, output + errors)
            self.assertEqual(list(self.scratch.iterdir()), [])
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()


if __name__ == "__main__":
    unittest.main(verbosity=2)
