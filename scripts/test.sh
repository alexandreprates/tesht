#!/usr/bin/env bash
# Run syntax checks and the independent process-level regression suite.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for script in tesht.sh scripts/*.sh tests/*.tsh examples/*.tsh; do
  "$BASH" -n "$script"
done
export TESHT_BASH=$BASH
python3 tests/regression.py
