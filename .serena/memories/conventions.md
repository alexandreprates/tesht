# Conventions
- Runtime Bash: function snake_case() declarations, two-space indentation; internal functions/local variables use __tesht_, state uses __TESHT_. Public scratch is TESHT_TMPDIR.
- Public test shadows Bash test; use [ / [[ or test builtin test when needed. .tsh files are sourced Bash; arguments are passed directly, never eval'd.
- Expected value/pattern precedes observed value. Existing stdout/stderr assertion names remain regex aliases; explicit *_match and *_equal names distinguish patterns and literal text.
- Assertion helpers report and return success to continue collecting results; counters determine overall failure. Keep file-level isolation and same-file command state intact.
- Avoid unquoted expansions except the explicitly annotated pathname expansion with word splitting disabled. Preserve exact arguments and literal paths containing glob characters.
- Python regression code uses unittest, snake_case test names, TemporaryDirectory, subprocess timeouts, and external exit/output checks rather than teSHT assertions to validate the runner.
- Explain work in Brazilian Portuguese; write code/comments/documentation/memories in English. Commits, when created, use Conventional Commits.
- Serena stores durable code navigation/implementation knowledge. Basic Memory stores plans, task status, and cross-session history.
