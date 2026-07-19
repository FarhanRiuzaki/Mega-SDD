#!/usr/bin/env bash
# test-derive-state.sh — P1 state engine (v4.93.0, spec 2026-07-19-v5-execution-spec.md
# decision 8; research/2026-07-19-v5-architecture-research.md §3).
#
# Pins the ONE-probe-library contract:
#   1. derive-state.sh produces the right `derived.position` + `proposed_next`
#      for every routing-decision-table fixture row (empty / legacy-code-only /
#      PRD-only / vault-md-without-json / vault+binding+conflicts /
#      KEEP_VAULT-DEFER-resolved binding / units-no-bolts / bolts-present /
#      map-stale-vs-HEAD / dirty-journal).
#   2. PARITY: validate-preflight.sh — now delegating its has_vault()-class
#      probes to _lib/state_probes.py — judges the same fixtures EXACTLY as the
#      pre-refactor committed script did (expected literals below were captured
#      from the v4.92.0 committed validate-preflight BEFORE the refactor).
#   3. state.json's probes.preflight_predicates agree with the preflight verdicts
#      (one library, one truth).
#   4. derive-state NEVER creates .mega-sdd/ in a directory that lacks it
#      (no minted SDD signals), and stays fast (no subprocess storms).
#   5. session-start's staleness notice reads the digest and emits the SAME
#      notice strings as the pre-P1 bash computation.
#
# Run: bash plugins/mega-sdd/tests/state/test-derive-state.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
DS="${PLUGIN_ROOT}/scripts/derive-state.sh"
VPF="${PLUGIN_ROOT}/scripts/validate-preflight.sh"
SS="${PLUGIN_ROOT}/hooks/session-start"
LIB="${PLUGIN_ROOT}/scripts/_lib/state_probes.py"
for f in "$DS" "$VPF" "$SS" "$LIB"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t p1state)"
trap 'rm -rf "$WORK"' EXIT

# ── Fixture builders ─────────────────────────────────────────────────────────
gitinit() { ( cd "$1" && git init -q . && git -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1 || true
              cd "$1" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base ); }

vault_docs() {
  mkdir -p "$1"
  for n in 00-index 01-goals 02-architecture 03-data-model 04-flows 05-decisions 06-constraints; do
    printf '# %s\n' "$n" > "$1/${n}.md"
  done
}

write_map() { # $1=file  $2=sha
  cat > "$1" <<EOF
---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-07-19T10:00:00Z
repo_root: ./
languages_detected: ["php"]
engine: tree-sitter
precision_tier: ast
last_scanned_commit: $2
---
## 1. Top-level structure
- src/
EOF
}

BINDING_ACTIVE='---
binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: 0123456789abcdef0123456789abcdef01234567
---
# Binding

## Implementation State Map

| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | src/app.php:10 | high | n/a |
| C-002 | CONFLICT | DIVERGED | src/app.php:20 | high | n/a |

## Conflicts

### CONFLICT-1
- **Claim**: C-002
- Vault says X, code says Y.

### ✅ CONFLICT-2 RESOLVED (KEEP_VAULT)
- **Claim**: C-003
- **Resolution**: ✅ RESOLVED (KEEP_VAULT) keep the vault claim.
'

BINDING_KV_DEFER='---
binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: 0123456789abcdef0123456789abcdef01234567
---
# Binding

## Implementation State Map

| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | src/app.php:10 | high | n/a |

## Conflicts

### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT)
- **Claim**: C-001
- **Resolution**: ✅ RESOLVED (KEEP_VAULT) keep it.

### ✅ CONFLICT-2 RESOLVED (DEFER)
- **Claim**: C-002
- **Resolution**: ✅ RESOLVED (DEFER) later.
'

mkvj() { printf '{"vault_version":"1.0","mode":"%s","open_questions":[]}\n' "$2" > "$1/vault.json"; }

mkdir -p "$WORK/f1-empty"

F="$WORK/f2-legacy-code"; mkdir -p "$F/src"
printf '{}\n' > "$F/composer.json"; printf '<?php echo 1;\n' > "$F/src/app.php"
gitinit "$F"

F="$WORK/f3-prd-only"; mkdir -p "$F"; printf '# PRD\n' > "$F/prd.md"

F="$WORK/f4-vault-md-no-json"; vault_docs "$F/.mega-sdd/vaults/v1"

F="$WORK/f5-binding-conflicts"; mkdir -p "$F/src" "$F/.mega-sdd/codebase"
printf '{}\n' > "$F/composer.json"; printf '<?php\n' > "$F/src/app.php"
vault_docs "$F/.mega-sdd/vaults/v1"; mkvj "$F/.mega-sdd/vaults/v1" existing
gitinit "$F"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "$(git -C "$F" rev-parse HEAD)"
printf '%s' "$BINDING_ACTIVE" > "$F/.mega-sdd/vaults/v1/binding.md"

F="$WORK/f5b-binding-kv-defer"; mkdir -p "$F/src" "$F/.mega-sdd/codebase"
printf '{}\n' > "$F/composer.json"; printf '<?php\n' > "$F/src/app.php"
vault_docs "$F/.mega-sdd/vaults/v1"; mkvj "$F/.mega-sdd/vaults/v1" existing
gitinit "$F"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "$(git -C "$F" rev-parse HEAD)"
printf '%s' "$BINDING_KV_DEFER" > "$F/.mega-sdd/vaults/v1/binding.md"

F="$WORK/f6-units-no-bolts"; mkdir -p "$F/src" "$F/.mega-sdd/codebase"
printf '{}\n' > "$F/composer.json"; printf '<?php\n' > "$F/src/app.php"
vault_docs "$F/.mega-sdd/vaults/v1"; mkvj "$F/.mega-sdd/vaults/v1" existing
mkdir -p "$F/.mega-sdd/vaults/v1/bound" "$F/.mega-sdd/vaults/v1/units"
printf '# bound\n' > "$F/.mega-sdd/vaults/v1/bound/00-index.md"
printf -- '---\nid: U-001\n---\n' > "$F/.mega-sdd/vaults/v1/units/U-001.md"
printf -- '---\nid: U-002\n---\n' > "$F/.mega-sdd/vaults/v1/units/U-002.md"
gitinit "$F"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "$(git -C "$F" rev-parse HEAD)"
printf '%s' "$BINDING_KV_DEFER" > "$F/.mega-sdd/vaults/v1/binding.md"

F="$WORK/f7-bolts-present"; cp -R "$WORK/f6-units-no-bolts" "$F"
rm -rf "$F/.git"; gitinit "$F"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "$(git -C "$F" rev-parse HEAD)"
mkdir -p "$F/.mega-sdd/vaults/v1/bolts/U-001" "$F/.mega-sdd/vaults/v1/bolts/U-002"
printf '# report\n' > "$F/.mega-sdd/vaults/v1/bolts/U-001/bolt-report.md"
printf '# report\n' > "$F/.mega-sdd/vaults/v1/bolts/U-002/bolt-report.md"

F="$WORK/f8-map-stale"; cp -R "$WORK/f6-units-no-bolts" "$F"
rm -rf "$F/.git"; gitinit "$F"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "ffffffffffffffffffffffffffffffffffffffff"

F="$WORK/f9-dirty-journal"; cp -R "$WORK/f6-units-no-bolts" "$F"
rm -rf "$F/.git"; gitinit "$F"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "$(git -C "$F" rev-parse HEAD)"
printf '{"p":"a.php"}\n{"p":"b.php"}\n{"p":"c.php"}\n' > "$F/.mega-sdd/codebase/.dirty-paths.jsonl"

# P2 adoption: foreign-SDD signals — spec-kit dir + generic specs/ (one file WITH
# frontmatter counts, one bare-prose file must NOT).
F="$WORK/f10-foreign-sdd"; mkdir -p "$F/.mega-sdd" "$F/.specify" "$F/specs"
printf -- '---\ntitle: checkout spec\n---\n# Checkout\n' > "$F/specs/checkout.md"
printf 'plain notes, no frontmatter\n' > "$F/specs/notes.md"

# ── Helpers ──────────────────────────────────────────────────────────────────
state_field() { # $1=fixture-dir  $2=python expr over the loaded state dict `d`
  python3 -c "
import json,sys
d=json.load(open('$1/.mega-sdd/state.json'))
print($2)
" 2>/dev/null
}

run_ds() { bash "$DS" --cwd="$1" </dev/null; }

# ── 1. Decision-table fixture matrix → position + proposed_next ─────────────
note "== 1. derive-state: routing decision table =="

# f1/f2/f3 have NO .mega-sdd — digest comes from --json-only stdout; no dir minted.
for fx in f1-empty:empty f2-legacy-code:legacy_code_only f3-prd-only:prd_no_vault; do
  name="${fx%%:*}"; want="${fx##*:}"
  J=$(bash "$DS" --cwd="$WORK/$name" --json-only </dev/null 2>/dev/null)
  got=$(printf '%s' "$J" | python3 -c "import json,sys; print(json.load(sys.stdin)['derived']['position'])" 2>/dev/null)
  [ "$got" = "$want" ] && ok "$name: position=$want" || fail "$name: position expected $want, got '$got'"
  [ -d "$WORK/$name/.mega-sdd" ] && fail "$name: derive-state MINTED .mega-sdd/ (SDD-signal pollution)" \
    || ok "$name: no .mega-sdd/ minted"
done
# flag-/intent-conditioned rows: empty chain + a note (the script never invents intent)
J=$(bash "$DS" --cwd="$WORK/f2-legacy-code" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin)['derived']
assert d['proposed_next']==[], d['proposed_next']
assert d['notes'], 'expected an intent note'
assert d['mode_inferred']=='brownfield', d['mode_inferred']
" 2>/dev/null && ok "f2: empty chain + intent note + brownfield inference" \
  || fail "f2: legacy-code default chain/notes/mode wrong"

run_ds "$WORK/f4-vault-md-no-json" >/dev/null 2>&1
got=$(state_field "$WORK/f4-vault-md-no-json" "d['derived']['position']")
[ "$got" = "vault_greenfield_no_units" ] && ok "f4: bare-docs vault position=vault_greenfield_no_units" \
  || fail "f4: position expected vault_greenfield_no_units, got '$got'"
got=$(state_field "$WORK/f4-vault-md-no-json" "d['derived']['manifest_derive_needed']")
[ "$got" = "True" ] && ok "f4: manifest_derive_needed=True (P0 unification)" || fail "f4: manifest_derive_needed wrong: $got"
got=$(state_field "$WORK/f4-vault-md-no-json" "d['derived']['proposed_next'][0]")
case "$got" in scripts/derive-vault-json.sh*) ok "f4: chain FIRST derives vault.json (never hand-written)";;
  *) fail "f4: chain head expected derive-vault-json.sh, got '$got'";; esac
got=$(state_field "$WORK/f4-vault-md-no-json" "d['probes']['preflight_predicates']['has_vault']")
[ "$got" = "True" ] && ok "f4: has_vault() TRUE on bare docs (routing==preflight, one library)" \
  || fail "f4: has_vault predicate lost the P0 unification: $got"

run_ds "$WORK/f5-binding-conflicts" >/dev/null 2>&1
got=$(state_field "$WORK/f5-binding-conflicts" "d['derived']['position']")
[ "$got" = "vault_map_unbound" ] && ok "f5: active conflict → position=vault_map_unbound (bind-codebase row)" \
  || fail "f5: position expected vault_map_unbound, got '$got'"
got=$(state_field "$WORK/f5-binding-conflicts" "str(d['probes']['vaults'][0]['binding']['conflicts_active'])+'/'+str(d['probes']['vaults'][0]['binding']['conflicts_resolved'])")
[ "$got" = "1/1" ] && ok "f5: conflict counts active=1 resolved=1 (binding_md grammar)" \
  || fail "f5: conflict counts expected 1/1, got '$got'"
got=$(state_field "$WORK/f5-binding-conflicts" "d['derived']['proposed_next']")
[ "$got" = "['bind-codebase']" ] && ok "f5: proposed_next=[bind-codebase]" || fail "f5: chain wrong: $got"

run_ds "$WORK/f5b-binding-kv-defer" >/dev/null 2>&1
got=$(state_field "$WORK/f5b-binding-kv-defer" "d['derived']['position']")
[ "$got" = "binding_resolved_no_rebind" ] && ok "f5b: KEEP_VAULT/DEFER-only → binding_resolved_no_rebind (no re-bind loop)" \
  || fail "f5b: position expected binding_resolved_no_rebind, got '$got'"
got=$(state_field "$WORK/f5b-binding-kv-defer" "d['derived']['proposed_next']")
[ "$got" = "['generate-units']" ] && ok "f5b: proposed_next=[generate-units]" || fail "f5b: chain wrong: $got"

run_ds "$WORK/f6-units-no-bolts" >/dev/null 2>&1
got=$(state_field "$WORK/f6-units-no-bolts" "d['derived']['position']")
[ "$got" = "units_pending_bolts" ] && ok "f6: position=units_pending_bolts" || fail "f6: position got '$got'"
got=$(state_field "$WORK/f6-units-no-bolts" "d['derived']['proposed_next']")
[ "$got" = "['execute-bolts --all']" ] && ok "f6: proposed_next=[execute-bolts --all]" || fail "f6: chain wrong: $got"
got=$(state_field "$WORK/f6-units-no-bolts" "str(d['probes']['vaults'][0]['units_count'])+'/'+str(d['probes']['vaults'][0]['bolts_count'])")
[ "$got" = "2/0" ] && ok "f6: units=2 bolts=0" || fail "f6: counts expected 2/0, got '$got'"

run_ds "$WORK/f7-bolts-present" >/dev/null 2>&1
got=$(state_field "$WORK/f7-bolts-present" "d['derived']['position']")
[ "$got" = "all_units_executed" ] && ok "f7: position=all_units_executed" || fail "f7: position got '$got'"
got=$(state_field "$WORK/f7-bolts-present" "d['derived']['proposed_next']")
[ "$got" = "['detect-drift']" ] && ok "f7: proposed_next=[detect-drift] (no recent drift check)" || fail "f7: chain wrong: $got"
# recent drift report flips f7 to pipeline_complete
touch "$WORK/f7-bolts-present/.mega-sdd/vaults/v1/DRIFT-REPORT.md"
run_ds "$WORK/f7-bolts-present" >/dev/null 2>&1
got=$(state_field "$WORK/f7-bolts-present" "d['derived']['position']")
[ "$got" = "pipeline_complete" ] && ok "f7+drift: position=pipeline_complete (drift_recent)" \
  || fail "f7+drift: position expected pipeline_complete, got '$got'"

run_ds "$WORK/f8-map-stale" >/dev/null 2>&1
got=$(state_field "$WORK/f8-map-stale" "d['derived']['position']")
[ "$got" = "maintenance_sync" ] && ok "f8: stale map stamp → position=maintenance_sync (Mode D)" \
  || fail "f8: position expected maintenance_sync, got '$got'"
got=$(state_field "$WORK/f8-map-stale" "d['derived']['change_signal']['map_stamp_matches_head']")
[ "$got" = "no" ] && ok "f8: change_signal.map_stamp_matches_head=no" || fail "f8: matches_head got '$got'"
got=$(state_field "$WORK/f8-map-stale" "d['derived']['proposed_next'][2]")
case "$got" in "bind-codebase --paths=@"*) ok "f8: Mode D chain keeps the claim-scoped re-bind hop";;
  *) fail "f8: Mode D chain hop 3 expected bind-codebase --paths=@…, got '$got'";; esac

run_ds "$WORK/f9-dirty-journal" >/dev/null 2>&1
got=$(state_field "$WORK/f9-dirty-journal" "d['derived']['position']")
[ "$got" = "maintenance_sync" ] && ok "f9: dirty journal → position=maintenance_sync (Mode D)" \
  || fail "f9: position expected maintenance_sync, got '$got'"
got=$(state_field "$WORK/f9-dirty-journal" "d['derived']['change_signal']['dirty_journal_rows']")
[ "$got" = "3" ] && ok "f9: change_signal.dirty_journal_rows=3" || fail "f9: dirty rows got '$got'"

# ── 2. PARITY: validate-preflight verdicts unchanged from pre-refactor ──────
# Expected literals captured from the COMMITTED v4.92.0 validate-preflight.sh
# (inline probes) run against these exact fixtures BEFORE the delegation
# refactor. scan-codebase asserts rc=0 + PASS|WARN (tree-sitter presence is
# machine-dependent); every other cell is exact.
note "== 2. preflight parity (pre-refactor captured verdicts) =="

expect_pf() { # $1=fixture $2=skill $3=want_rc $4=want_status $5=want_check(- for null)
  local fx="$1" skill="$2" wrc="$3" wst="$4" wck="$5"
  rm -f "$WORK/$fx/.mega-sdd/.preflight-state.json" 2>/dev/null
  out=$(bash "$VPF" --cwd="$WORK/$fx" --skill="mega-sdd:$skill" </dev/null 2>/dev/null)
  rc=$?
  st=$(printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status'))" 2>/dev/null)
  ck=$(printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('fatal_check_id') or '-')" 2>/dev/null)
  if [ "$rc" = "$wrc" ] && [ "$st" = "$wst" ] && [ "$ck" = "$wck" ]; then
    ok "parity $fx/$skill: rc=$rc status=$st check=$ck"
  else
    fail "parity $fx/$skill: expected rc=$wrc/$wst/$wck, got rc=$rc/$st/$ck"
  fi
}

# no-.mega-sdd fixtures: the exact pre-refactor no-project PASS
for fx in f1-empty f2-legacy-code f3-prd-only; do
  out=$(bash "$VPF" --cwd="$WORK/$fx" --skill=mega-sdd:bind-codebase </dev/null 2>/dev/null); rc=$?
  [ "$rc" = "0" ] && printf '%s' "$out" | grep -qF '"reason":"no .mega-sdd/ project"' \
    && ok "parity $fx: no-project PASS literal unchanged" \
    || fail "parity $fx: no-project lane changed (rc=$rc out=${out:0:80})"
done

expect_pf f4-vault-md-no-json bind-codebase  1 FATAL binding_input_map_missing
expect_pf f4-vault-md-no-json generate-units 0 PASS  -
expect_pf f4-vault-md-no-json execute-bolts  1 FATAL bolts_units_missing
expect_pf f5-binding-conflicts bind-codebase  0 PASS -
expect_pf f5-binding-conflicts generate-units 0 PASS -
expect_pf f5-binding-conflicts execute-bolts  1 FATAL bolts_units_missing
expect_pf f5b-binding-kv-defer bind-codebase  0 PASS -
expect_pf f6-units-no-bolts   bind-codebase  0 PASS -
expect_pf f6-units-no-bolts   generate-units 0 PASS -
expect_pf f6-units-no-bolts   execute-bolts  0 PASS -
expect_pf f7-bolts-present    execute-bolts  0 PASS -
expect_pf f8-map-stale        bind-codebase  0 PASS -
expect_pf f9-dirty-journal    bind-codebase  0 PASS -
# scan-codebase: machine-dependent tree-sitter WARN — rc must be 0 either way
out=$(bash "$VPF" --cwd="$WORK/f6-units-no-bolts" --skill=mega-sdd:scan-codebase </dev/null 2>/dev/null); rc=$?
st=$(printf '%s' "$out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status'))" 2>/dev/null)
{ [ "$rc" = "0" ] && { [ "$st" = "PASS" ] || [ "$st" = "WARN" ]; }; } \
  && ok "parity f6/scan-codebase: rc=0 status=$st (PASS|WARN, tree-sitter-dependent)" \
  || fail "parity f6/scan-codebase: rc=$rc status=$st"

# ── 3. predicates in the digest == preflight verdicts (one library) ─────────
note "== 3. digest predicates agree with preflight =="
for fx in f4-vault-md-no-json f6-units-no-bolts f7-bolts-present; do
  run_ds "$WORK/$fx" >/dev/null 2>&1
  hv=$(state_field "$WORK/$fx" "d['probes']['preflight_predicates']['has_vault']")
  hu=$(state_field "$WORK/$fx" "d['probes']['preflight_predicates']['has_units']")
  bash "$VPF" --cwd="$WORK/$fx" --skill=mega-sdd:execute-bolts --quiet </dev/null >/dev/null 2>&1
  eb_rc=$?
  if [ "$hu" = "True" ]; then want_rc=0; else want_rc=1; fi
  [ "$eb_rc" = "$want_rc" ] && ok "$fx: has_units=$hu ⇔ execute-bolts rc=$eb_rc" \
    || fail "$fx: predicate/verdict split (has_units=$hu but execute-bolts rc=$eb_rc)"
  [ "$hv" = "True" ] && ok "$fx: has_vault=True" || fail "$fx: has_vault expected True, got $hv"
done

# ── 4. speed: no subprocess storms ──────────────────────────────────────────
note "== 4. speed =="
start_ns=$(python3 -c 'import time; print(time.time_ns())')
run_ds "$WORK/f6-units-no-bolts" >/dev/null 2>&1
end_ns=$(python3 -c 'import time; print(time.time_ns())')
ms=$(( (end_ns - start_ns) / 1000000 ))
note "  derive-state on f6: ${ms}ms"
[ "$ms" -lt 2000 ] && ok "derive-state completes fast (${ms}ms < 2000ms CI bound; local target <300ms)" \
  || fail "derive-state too slow: ${ms}ms — subprocess storm?"

# ── 5. session-start staleness notice reads the digest (same strings) ───────
note "== 5. session-start digest parity =="
out=$( cd "$WORK/f9-dirty-journal" && printf '{"session_id":"t","source":"startup"}' | bash "$SS" 2>/dev/null )
printf '%s' "$out" | grep -qF 'mega-sdd: codebase moved since last scan (3 journaled write(s)) — `/mega-sdd:sync` reconciles map → drift → binding → units.' \
  && ok "f9: staleness notice (digest path) byte-matches the pre-P1 string" \
  || fail "f9: staleness notice missing/reworded"
printf -- '- [ ] decide A\n- [ ] decide B\n' > "$WORK/f9-dirty-journal/.mega-sdd/vaults/v1/PENDING-SYNC.md"
out=$( cd "$WORK/f9-dirty-journal" && printf '{"session_id":"t","source":"startup"}' | bash "$SS" 2>/dev/null )
printf '%s' "$out" | grep -qF 'mega-sdd: 2 open sync decision(s) queued in .mega-sdd/vaults/v1/PENDING-SYNC.md — resolve the queue first. Code also moved since last scan (3 journaled write(s)) — re-run `/mega-sdd:sync` after.' \
  && ok "f9+queue: PENDING-SYNC-first notice byte-matches the pre-P1 string" \
  || fail "f9+queue: PENDING-SYNC notice missing/reworded"
rm -f "$WORK/f9-dirty-journal/.mega-sdd/vaults/v1/PENDING-SYNC.md"
out=$( cd "$WORK/f6-units-no-bolts" && printf '{"session_id":"t","source":"startup"}' | bash "$SS" 2>/dev/null )
printf '%s' "$out" | grep -qF 'codebase moved since last scan' \
  && fail "f6: clean fixture got a staleness notice" \
  || ok "f6: clean fixture stays silent (no notice)"

# ── 6. foreign-SDD adoption probe (P2) ──────────────────────────────────────
note "== 6. foreign-SDD adoption probe (P2) =="
DIGEST=$(run_ds "$WORK/f10-foreign-sdd" 2>/dev/null)
got=$(state_field "$WORK/f10-foreign-sdd" "len(d['derived']['foreign_sdd'])")
[ "$got" = "2" ] && ok "f10: derived.foreign_sdd has 2 rows (.specify + frontmatter'd specs/*.md; bare-prose notes.md excluded)" \
  || fail "f10: foreign_sdd rows expected 2, got '$got'"
got=$(state_field "$WORK/f10-foreign-sdd" "sorted(h['tool'] for h in d['derived']['foreign_sdd'])")
[ "$got" = "['generic-specs', 'spec-kit']" ] && ok "f10: tools = generic-specs + spec-kit" \
  || fail "f10: tools wrong: $got"
got=$(state_field "$WORK/f10-foreign-sdd" "d['probes']['foreign_sdd']==d['derived']['foreign_sdd']")
[ "$got" = "True" ] && ok "f10: probes.foreign_sdd == derived.foreign_sdd (one probe, surfaced)" \
  || fail "f10: probe/derived foreign_sdd split: $got"
printf '%s' "$DIGEST" | grep -qF 'foreign_sdd=generic-specs,spec-kit' \
  && ok "f10: digest line mentions foreign_sdd=generic-specs,spec-kit" \
  || fail "f10: digest missing foreign_sdd token: $DIGEST"
state_field "$WORK/f10-foreign-sdd" "'\n'.join(d['derived']['notes'])" | grep -q 'adoption_demote_confirm' \
  && ok "f10: adoption note names the confirmed C2 lane (decision 7 — never unconfirmed)" \
  || fail "f10: adoption note missing/unwired"
# digest byte-stability: clean fixtures NEVER carry the token
DIGEST=$(run_ds "$WORK/f6-units-no-bolts" 2>/dev/null)
printf '%s' "$DIGEST" | grep -qF 'foreign_sdd=' \
  && fail "f6: clean fixture digest grew a foreign_sdd token (byte-stability broken)" \
  || ok "f6: clean digest unchanged (no foreign_sdd token)"

note ""
if [ "$FAILED" -eq 0 ]; then note "ALL P1 state-engine assertions PASS"; else note "P1 state-engine FAILURES"; fi
exit $FAILED
