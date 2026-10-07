# Suggested Commands
Run from the repository root.
- Full syntax and regression checks: `bash scripts/test.sh`.
- Bundled examples: `LC_ALL=C bash ./tesht.sh 'tests/*.tsh' 'examples/*.tsh'`. Both use runner-managed TESHT_TMPDIR.
- Single file: `bash ./tesht.sh tests/example.tsh`; usage: `bash ./tesht.sh --help`.
- ShellCheck: `shellcheck tesht.sh scripts/*.sh tests/*.tsh examples/*.tsh`.
- Container lint: `docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:v0.10.0 tesht.sh scripts/*.sh tests/*.tsh examples/*.tsh`.
- Container regressions: `docker run --rm -e LC_ALL=C -v "$PWD:/work:ro" -w /work bash:3.2 sh -c 'apk add --no-cache python3 && su -s /bin/sh nobody -c "bash scripts/test.sh"'`. Repeat with 4.4, 5.2, 5.3 for the CI matrix. Run unprivileged to exercise permission tests (root would skip them).
- Alternate local Bash: `TESHT_BASH=/path/to/bash python3 tests/regression.py`.
- Focused regressions: `python3 tests/regression.py RunnerTests.test_exact_arguments_and_command_path`.
- Memory reference integrity: `serena memories check`; inspect its report because it always exits zero.
- No build, package installation, formatter, or type checker is configured.
