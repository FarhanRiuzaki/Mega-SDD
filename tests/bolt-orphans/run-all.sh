#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || { echo "cannot locate repo root"; exit 2; }
fail=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "=== $(basename "$t") ==="
  bash "$t" || { echo "FAIL: $(basename "$t")"; fail=1; }
done
exit $fail
