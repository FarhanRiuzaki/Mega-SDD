#!/usr/bin/env bash
set -u
out=$(bash plugins/mega-sdd/scripts/validate-pack.sh tests/fixtures/pack-kit/bad-pack.md 2>&1); rc=$?
[ $rc -ne 0 ] || { echo "linter accepted a malformed pack"; exit 1; }
echo "$out" | grep -qiE 'Testing conventions|missing section' || { echo "did not flag the missing section"; exit 1; }
echo "$out" | grep -qiE 'leak|Gate::define|cross-framework' || { echo "did not flag the Laravel leak"; exit 1; }
exit 0
