#!/usr/bin/env bash
set -u
err=0
# 9.0 P1: the unit schema moved from the deleted generate-units skill to plan/references/unit-schema.md.
# The reuse_candidates field survives there as a reader contract (build-dispatch-prompt.sh honours it on
# legacy units). The generate-units Step 7.7.f derivation (starterkit-derivation.md: "reads reuse-index",
# "emits reuse_candidates") is retired by design §7 decision #1 — reuse-index.yaml lost its only producer
# (deep-scan), so plan does not derive the field.
schema=plugins/mega-sdd/skills/plan/references/unit-schema.md
grep -q 'reuse_candidates' "$schema" || { echo "unit-schema missing reuse_candidates"; err=1; }
grep -qiE 'fast-path|hint, not|primary lookup|primary surface' "$schema" || { echo "unit-schema missing fast-path-hint framing for reuse_candidates"; err=1; }
exit $err
