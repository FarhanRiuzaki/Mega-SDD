#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/references/reuse-index-schema.md"
err=0
[ -f "$f" ] || { echo "missing reuse-index-schema.md"; exit 1; }
for s in "helpers:" "model_api:" "services:" "commands:"; do
  grep -qF "$s" "$f" || { echo "missing section: $s"; err=1; }
done
grep -qF "_source:" "$f" || { echo "missing _source anti-halu rail"; err=1; }
grep -qiE 'signature' "$f" || { echo "missing signature field"; err=1; }
grep -qiE 'no body|signatures only|never store' "$f" || { echo "missing 'signatures-only' rail"; err=1; }
fx="tests/fixtures/reuse-awareness/laravel-sample/.mega-sdd/codebase/reuse-index.yaml"
if [ -f "$fx" ]; then
  for s in "helpers:" "model_api:" "services:" "commands:"; do grep -qF "$s" "$fx" || { echo "fixture missing $s"; err=1; }; done
  grep -q '_source:' "$fx" || { echo "fixture missing _source"; err=1; }
fi
exit $err
