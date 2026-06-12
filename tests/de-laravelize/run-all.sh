#!/usr/bin/env bash
# Runs the de-laravelize deterministic gate suite. Exit non-zero on any failure.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
# Tests use repo-root-relative paths; run them from the repo root so the suite
# works regardless of the caller's CWD (run-all.sh lives at <repo>/tests/de-laravelize/).
cd "$here/../.." || { echo "cannot locate repo root"; exit 2; }
fail=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "=== $(basename "$t") ==="
  bash "$t" || { echo "FAIL: $(basename "$t")"; fail=1; }
done
exit $fail
