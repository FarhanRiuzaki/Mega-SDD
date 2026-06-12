#!/usr/bin/env bash
# Deterministic gate: an emitted_by=execute-bolts status=completed handoff that
# EXECUTED UNITS (metrics.items_processed > 0) but lists NO <vault>/bolts/U-XXX/
# artifact must FAIL with halt_type bolt_artifacts_missing (the vacuous-pass hole
# the user hit). It must NOT fire when:
#   - a real bolts/ dir IS listed (POSITIVE),
#   - the run did no work (items_processed == 0: --dry-run / all-units-already-done
#     no-op re-run),
#   - metrics/items_processed is absent (conservative — no false positive).
# Fixtures use the fenced-yaml handoff shape the validator's parser accepts
# (mirrors tests/fixtures/iter77-range-shorthand/).
set -u
V="plugins/mega-sdd/scripts/validate-handoff-yaml.sh"

# --- NEGATIVE: completed execute-bolts that executed 12 units, artifact exists
#     but is NOT a bolts/ dir -> MUST raise bolt_artifacts_missing
tmp="$(mktemp -d)"; mkdir -p "$tmp/.mega-sdd"; echo x > "$tmp/.mega-sdd/foo.txt"
neg="$tmp/neg.md"
cat > "$neg" <<'HANDOFF'
```yaml
handoff:
  emitted_by: mega-sdd:execute-bolts
  emitted_at: 2026-06-10T12:00:00Z
  status: completed
  artifacts:
    - .mega-sdd/foo.txt
  next_action:
    suggested_skill: mega-sdd:detect-drift
    rationale: "test"
  metrics:
    items_processed: 12    # units executed
    items_blocked: 0
  blockers: []
```
HANDOFF
out=$(bash "$V" --cwd="$tmp" --response-file="$neg" 2>/dev/null)
echo "$out" | grep -q '"bolt_artifacts_missing"' || { echo "FAIL(negative): completed execute-bolts that executed 12 units with no bolts/ artifact did NOT raise bolt_artifacts_missing. Got: $out"; rm -rf "$tmp"; exit 1; }
rm -rf "$tmp"

# --- POSITIVE: same but WITH a real bolts/U-001/ dir -> must NOT raise that halt
tmp="$(mktemp -d)"; mkdir -p "$tmp/.mega-sdd/vaults/v1/bolts/U-001"; echo r > "$tmp/.mega-sdd/vaults/v1/bolts/U-001/bolt-report.md"
pos="$tmp/pos.md"
cat > "$pos" <<'HANDOFF'
```yaml
handoff:
  emitted_by: mega-sdd:execute-bolts
  emitted_at: 2026-06-10T12:00:00Z
  status: completed
  artifacts:
    - .mega-sdd/vaults/v1/bolts/U-001/
  next_action:
    suggested_skill: mega-sdd:detect-drift
    rationale: "test"
  metrics:
    items_processed: 1
    items_blocked: 0
  blockers: []
```
HANDOFF
out=$(bash "$V" --cwd="$tmp" --response-file="$pos" 2>/dev/null)
echo "$out" | grep -q '"bolt_artifacts_missing"' && { echo "FAIL(positive): handoff WITH a real bolts/ dir wrongly raised bolt_artifacts_missing. Got: $out"; rm -rf "$tmp"; exit 1; }
rm -rf "$tmp"

# --- FALSE-POSITIVE GUARD 1: no-op re-run / --dry-run -> items_processed: 0, no
#     bolts dir. Legitimately completes with no work -> must NOT raise.
tmp="$(mktemp -d)"; mkdir -p "$tmp/.mega-sdd"; echo x > "$tmp/.mega-sdd/foo.txt"
noop="$tmp/noop.md"
cat > "$noop" <<'HANDOFF'
```yaml
handoff:
  emitted_by: mega-sdd:execute-bolts
  emitted_at: 2026-06-10T12:00:00Z
  status: completed
  artifacts:
    - .mega-sdd/foo.txt
  next_action:
    suggested_skill: mega-sdd:detect-drift
    rationale: "all units already done / dry-run"
  metrics:
    items_processed: 0    # no units executed
    items_blocked: 0
  blockers: []
```
HANDOFF
out=$(bash "$V" --cwd="$tmp" --response-file="$noop" 2>/dev/null)
echo "$out" | grep -q '"bolt_artifacts_missing"' && { echo "FAIL(no-op): completed execute-bolts with items_processed:0 (dry-run/no-op) wrongly raised bolt_artifacts_missing. Got: $out"; rm -rf "$tmp"; exit 1; }
rm -rf "$tmp"

# --- FALSE-POSITIVE GUARD 2: metrics block absent entirely -> conservative,
#     must NOT raise (a missing metrics block is a separate completeness concern).
tmp="$(mktemp -d)"; mkdir -p "$tmp/.mega-sdd"; echo x > "$tmp/.mega-sdd/foo.txt"
nom="$tmp/nometrics.md"
cat > "$nom" <<'HANDOFF'
```yaml
handoff:
  emitted_by: mega-sdd:execute-bolts
  emitted_at: 2026-06-10T12:00:00Z
  status: completed
  artifacts:
    - .mega-sdd/foo.txt
  next_action:
    suggested_skill: mega-sdd:detect-drift
    rationale: "no metrics block"
  blockers: []
```
HANDOFF
out=$(bash "$V" --cwd="$tmp" --response-file="$nom" 2>/dev/null)
echo "$out" | grep -q '"bolt_artifacts_missing"' && { echo "FAIL(no-metrics): completed execute-bolts with absent metrics wrongly raised bolt_artifacts_missing. Got: $out"; rm -rf "$tmp"; exit 1; }
rm -rf "$tmp"
exit 0
