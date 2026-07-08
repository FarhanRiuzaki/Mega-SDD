#!/usr/bin/env bash
# Learning-loop contract pins (spec: 2026-06-10-learning-loop-design.md §Test obligations).
# Grep-based: each pin asserts a load-bearing contract sentence/structure exists.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0

fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# L1 — drift-history schema + fingerprint format
grep -q 'drift-history.md' "$P/skills/memory/references/memory-schema.md" \
  && grep -q '<category>:<vault-section>:<normalized-name>' "$P/skills/memory/references/memory-schema.md" \
  && pass "L1 schema: drift-history + fingerprint format pinned" \
  || fail "L1 schema: drift-history fingerprint format missing from memory-schema.md"

grep -q 'code_right | vault_stale | deferred' "$P/skills/memory/references/memory-schema.md" \
  && pass "L1 schema: direction enum pinned" \
  || fail "L1 schema: direction enum missing"

# L1 — detect-drift never auto-resolves from memory
grep -q 'NEVER auto-resolves a finding' "$P/skills/detect-drift/SKILL.md" \
  && pass "L1 moat: detect-drift memory suggestion never auto-resolves" \
  || fail "L1 moat: 'NEVER auto-resolves a finding' sentence missing from detect-drift SKILL.md"

grep -q 'drift-history' "$P/skills/detect-drift/SKILL.md" \
  && pass "L1 wiring: detect-drift writes/reads drift-history" \
  || fail "L1 wiring: detect-drift does not mention drift-history"

# L2 — sync rows observable + suggestion gated on ACCEPT
grep -q 'kind: sync' "$P/skills/memory/references/memory-schema.md" \
  && grep -q 'kind: sync' "$P/skills/orchestrate-flow/references/memory-layer.md" \
  && pass "L2: kind:sync rows pinned in schema + orchestrator" \
  || fail "L2: kind:sync row contract missing"

grep -q 'explicit ACCEPT' "$P/commands/sync.md" \
  && pass "L2 moat: auto-apply=safe default only on explicit ACCEPT" \
  || fail "L2 moat: sync.md missing explicit-ACCEPT gate for auto-apply suggestion"

# L3/L4 — bolt-outcomes new fields
grep -q 'failure_reflection' "$P/skills/memory/references/memory-schema.md" \
  && grep -q 'failure_reflection' "$P/skills/execute-bolts/references/halts-and-handoff.md" \
  && pass "L3: failure_reflection pinned in schema + execute-bolts" \
  || fail "L3: failure_reflection missing"

grep -q '"concerns"' "$P/skills/memory/references/memory-schema.md" \
  && grep -qi 'concerns=\[' "$P/skills/execute-bolts/references/halts-and-handoff.md" \
  && pass "L4: acceptance-test concerns persisted to bolt-outcomes" \
  || fail "L4: concerns persistence missing"

# L5 — owned threshold pass, once at chain end
grep -q 'extract-learnings' "$P/skills/orchestrate-flow/references/memory-layer.md" \
  && grep -q 'No skill evaluates thresholds mid-chain' "$P/skills/memory/references/learning-rules.md" \
  && pass "L5: owned extract-learnings step, thresholds once at chain end" \
  || fail "L5: extract-learnings ownership missing"

# L6 — index is derived, hint-not-data
grep -q '_index.md' "$P/skills/memory/references/memory-schema.md" \
  && grep -q 'never as the data' "$P/skills/memory/references/memory-schema.md" \
  && pass "L6: _index.md derived + hint-not-data rail" \
  || fail "L6: _index.md contract missing"

# L7 — hygiene: secret-scan on write + size suggestion + detector versioning
# M-16 (v4.77.0) moved the scan from orchestrator prose INTO the writer script —
# pin the new enforcement site: the doc states the writer-side redaction AND the
# script deterministically contains the scan call.
grep -qi 'secret-scan' "$P/skills/orchestrate-flow/references/memory-layer.md" \
  && grep -q 'secret-scan.sh' "$P/scripts/memory-write.sh" \
  && pass "L7: secret-scan on memory write (inside memory-write.sh, stated in memory-layer.md)" \
  || fail "L7: secret-scan-on-write missing (doc mention or script wiring)"

grep -q 'NEVER auto-prune' "$P/skills/memory/references/memory-schema.md" \
  && pass "L7: size threshold is a suggestion, never auto-prune" \
  || fail "L7: never-auto-prune rail missing"

grep -q 'Detector versioning' "$P/skills/scan-codebase/references/halts-flags-handoff.md" \
  && pass "L7: detector versioning on conventions" \
  || fail "L7: detector versioning missing from scan-codebase"

# Doctrine sentence — capture automatic, behavior suggestion-gated
grep -q 'suggestion-only' "$P/skills/memory/references/learning-rules.md" \
  && pass "Doctrine: suggestion-only lock intact" \
  || fail "Doctrine: suggestion-only lock sentence missing"

# New threshold rows present
for k in "Drift direction" "Sync write-back class" "Acceptance-test concern"; do
  grep -q "$k" "$P/skills/memory/references/learning-rules.md" \
    && pass "Threshold row: $k" \
    || fail "Threshold row missing: $k"
done

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
