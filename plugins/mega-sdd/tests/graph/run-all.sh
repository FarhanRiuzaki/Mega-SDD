#!/usr/bin/env bash
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "== $(basename "$t") =="
  bash "$t" || rc=1
done
exit $rc
