# teSHT

teSHT is a small functional testing framework for Bash. Run a command with `test`,
then check its status, output, or filesystem effects with assertions.

## Quick start

Copy `tesht.sh` into your project or add this repository as a Git submodule. No
package installation or build is required. Create a test file:

```bash
# tests/directories.tsh
test mkdir -p "$TESHT_TMPDIR/my directory"
assert_success
assert_dir "$TESHT_TMPDIR/my directory"

test cd "$TESHT_TMPDIR/my directory"
assert_success
test pwd
assert_stdout_equal "$TESHT_TMPDIR/my directory"$'\n'

test printf '%s' 'hello world'
assert_stdout_equal 'hello world'
assert_stdout_match '^hello'
```

Run it from your project directory:

```bash
bash ./tesht.sh 'tests/*.tsh'
# Or select individual files, including paths containing spaces:
bash ./tesht.sh tests/directories.tsh 'tests/file with spaces.tsh'
```

The runner expands quoted pathname patterns without evaluating shell code. It
also accepts patterns already expanded by your shell. Existing literal paths take
precedence over pattern expansion. Standard `*`, `?`, and bracket patterns are
supported; quoted brace expressions and recursive `**` expansion are not enabled.
A file selected more than once runs more than once. Use `--` before a filename
that would otherwise be interpreted as an option, such as `--help`.

Every selected file must be readable, a regular file, and valid Bash. The entire
selection is checked before any test runs. Missing files, unmatched patterns, and
an empty selection are errors. A file that executes no assertions also fails.

## Assertions

Expected values or patterns come first. All assertions record their result and
continue, so a failed assertion does not hide later failures.

| Assertion | Behavior |
| --- | --- |
| `assert_equal EXPECTED ACTUAL` | Literal string equality, including whitespace. |
| `assert_not_equal UNEXPECTED ACTUAL` | Literal string inequality. |
| `assert_match REGEX ACTUAL` | Bash extended regular expression matches the string. |
| `assert_not_match REGEX ACTUAL` | The expression does not match. Invalid expressions fail. |
| `assert_success` | The last command executed through `test` exited with status 0. |
| `assert_fail [STATUS]` | The last command failed; optionally require status 1–255. |
| `assert_dir PATH` | A directory exists, following symbolic links. |
| `assert_file PATH` | A regular file exists, following symbolic links. Directories fail. |
| `assert_stdout_match REGEX` / `assert_stderr_match REGEX` | Match captured output with a regular expression. |
| `assert_not_stdout_match REGEX` / `assert_not_stderr_match REGEX` | Require that the expression does not match captured output. |
| `assert_stdout_equal TEXT` / `assert_stderr_equal TEXT` | Compare captured text literally, preserving trailing newlines. |
| `assert_not_stdout_equal TEXT` / `assert_not_stderr_equal TEXT` | Require literal inequality, including trailing newlines. |

The original `assert_stdout`, `assert_stderr`, `assert_not_stdout`, and
`assert_not_stderr` remain aliases for their regex forms. These regex assertions
remove trailing newline characters before matching, preserving the original
behavior. Exact comparisons retain them:

```bash
test printf 'hello\n\n'
assert_stdout '^hello$'
assert_stdout_equal $'hello\n\n'
assert_not_stdout_equal 'hello'
```

Regex matching is unanchored unless you supply `^` and `$`. Captures are text:
Bash variables cannot represent NUL bytes, so output assertions are not suitable
for binary data. Status/output assertions fail if no command has been executed.
Each `test` call replaces the previous stdout, stderr, and exit status.

## Execution and isolation

- Each `.tsh` file runs in its own subshell, starting in the directory where the
  runner was invoked. Variables, exported environment changes, functions, shell
  options, traps, and directory changes do not leak to later files.
- Commands within one file share shell state. `test cd`, shell functions, empty
  arguments, and arguments containing spaces or wildcard characters work.
- `test` shadows Bash's builtin of the same name. Use `[` / `[[` in test code, or
  `test builtin test ...` when you need to run that builtin through the framework.
- Pass a command and its arguments to `test`, not a command string. To capture a
  pipeline or compound command, put it in a function, then call `test function_name`.
- Files start with `errexit` enabled: an unhandled command failure aborts that file
  and fails the run. Expected failures belong inside `test`. Bash suppresses
  `errexit` inside commands/functions used as conditions; `test` uses a condition
  to capture the command status, so compound functions must return their intended
  status explicitly. Normal Bash conditional and pipeline rules still apply.
- Use `return` to finish a file after its assertions. Calling `exit`, including
  `exit 0`, is an error because it bypasses normal file completion. Remaining files
  still run. Do not replace the reserved `EXIT`, `INT`, `TERM`, or `ERR` traps.
- `TESHT_TMPDIR` is a per-file scratch directory. The runner removes it and its
  output captures on normal completion and on handled `INT`/`TERM` signals. Set
  `TMPDIR` to an existing writable parent directory to choose their location.
  `SIGKILL`, machine shutdown, and detached processes cannot be cleaned up by traps.
- Framework internals use the reserved `__tesht_` / `__TESHT_` prefixes. Test files
  are trusted Bash code, not a security sandbox. Isolation does not undo writes
  outside `TESHT_TMPDIR` or stop processes started by test code.

## Results and exit codes

Passing assertions print a dot. Failures include the test file and line, a reason,
expected/received values when applicable, and the last captured command. A summary
counts files, failed files, passed/failed assertions, and execution errors:

```text
Summary: 2 files, 0 failed; 14 assertions, 14 passed, 0 failed; 0 errors.
```

| Exit code | Meaning |
| --- | --- |
| `0` | All selected files and assertions passed, or `--help` was requested. |
| `1` | An assertion failed, a file had an execution error, or it ran no assertions. |
| `2` | Invalid selection, syntax error, or failure to create runner scratch space. |
| `130` / `143` | The runner handled `INT` / `TERM`. |

A later passing file never clears an earlier failure.

## Requirements and Docker

Requires Bash and standard utilities (`mktemp`, `mkdir`, `cat`, and `rm`). Run with
Bash, not POSIX `sh`. The CI compatibility matrix targets Bash **3.2, 4.4, 5.2, and
5.3** on Linux. Other versions/platforms are not covered by that matrix.

Docker is optional. To select a Bash version:

```bash
docker run --rm -e LC_ALL=C -v "$PWD:/work:ro" -w /work \
  bash:5.3 bash ./tesht.sh 'tests/*.tsh'
```

Remove `:ro` only if your tests need to write inside the mounted project. Use a
fixed locale such as `LC_ALL=C` when checking localized command diagnostics.

## Developing teSHT

The regression suite uses Python 3.8+ and the standard library. It runs teSHT in
separate processes and checks their outputs and exit codes independently of the
framework's assertions. Tests cover argument handling, all assertion forms,
selection errors, isolation, summaries, and temporary-file cleanup.

```bash
bash scripts/test.sh
shellcheck tesht.sh scripts/*.sh tests/*.tsh examples/*.tsh
```

To run regressions with another installed Bash executable, either invoke
`scripts/test.sh` with that executable or use
`TESHT_BASH=/path/to/bash python3 tests/regression.py`.

Equivalent container checks:

```bash
docker run --rm -e LC_ALL=C -v "$PWD:/work:ro" -w /work bash:3.2 \
  sh -c 'apk add --no-cache python3 && su -s /bin/sh nobody -c "bash scripts/test.sh"'
docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:v0.10.0 \
  tesht.sh scripts/*.sh tests/*.tsh examples/*.tsh
```

The [CI workflow](.github/workflows/ci.yml) runs these checks for pushes and pull
requests, using a Bash version matrix and a separate ShellCheck job. Container
tests run as an unprivileged user so unreadable-file checks are exercised too.

## Compatibility changes

Compared with the original runner, missing/empty selections and empty test files
now fail; `assert_equal` is literal; `assert_file` rejects directories; test files
are isolated; and unhandled command failures and premature `exit` calls fail the
run. Replace cross-file shared state with explicit fixture setup in each file.
The old generic globals (`STDOUT`, `RETURNCODE`, etc.) and `setup`/`report` helpers
are internal implementation details and are no longer used. Existing output
assertion names keep their regex semantics.
