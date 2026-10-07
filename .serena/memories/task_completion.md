# Task Completion
- Run bash scripts/test.sh (syntax of runner/scripts/fixtures plus the independent regression suite).
- Run shellcheck tesht.sh scripts/*.sh tests/*.tsh examples/*.tsh, or the pinned Docker equivalent in `mem:suggested_commands`.
- Runtime compatibility changes should pass the Docker Bash 3.2/4.4/5.2/5.3 matrix. Report actual execution versions and skips; permission checks are skipped when the test process is root.
- For assertion/runner changes, extend process-level regressions for both success and failure, counters/diagnostics where relevant, and cleanup. Keep the harness independent from the assertion implementation.
- Never accept success text alone as validation: check subprocess status, expected assertion totals, and scratch-directory removal.
- For CI edits, validate workflow syntax (actionlint when available); distinguish local Docker validation from a remote GitHub Actions run.
- Run git diff --check and review git status --short; preserve unrelated changes. No mandatory build/format/type-check stage.
- Update README compatibility notes and durable Serena knowledge when behavior changes; use serena memories check after memory edits. Record implementation status and verification limits in Basic Memory.
