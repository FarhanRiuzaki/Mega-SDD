#!/usr/bin/env bash
# Run all roadmap gate tests from repo root.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
rc=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "=== $(basename "$t") ==="
  bash "$t" || rc=1
done
exit $rc
