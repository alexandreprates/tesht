# Technology Stack
- Runtime: Bash plus mktemp, mkdir, cat, rm; no package manager/build step/runtime Python requirement. UUID utilities and /proc UUID dependency have been removed.
- Linux compatibility matrix: official Docker bash:3.2, bash:4.4, bash:5.2, bash:5.3 images. Avoid syntax newer than Bash 3.2 unless changing the documented support contract.
- Development: Python 3.8+ standard-library unittest invokes independent Bash processes; TESHT_BASH selects the executable. scripts/test.sh exports its own BASH executable for consistent syntax/runtime testing.
- .shellcheckrc specifies Bash. CI pins koalaman/shellcheck:v0.10.0. tesht.sh locally suppresses SC2317 because assertions are dynamically invoked and helpers run through traps; SC1090 marks dynamic source and SC2206 marks deliberate glob expansion with splitting disabled.
- .github/workflows/ci.yml uses GitHub Actions checkout and read-only contents permissions; matrix jobs run syntax/regressions inside Bash Docker images, installing Python only for development tests. Separate ShellCheck job.
- Serena Bash symbol/body lookup works; reference lookup may miss dynamic callers in sourced .tsh files. Prefer scoped pattern searches when references appear empty.
