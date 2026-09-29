#!/usr/bin/env bash
# test-derive-state.sh — P1 state engine (v4.93.0, v5 execution spec, commit 45c6039b,
# decision 8; v5 research §3, commit 7724ec12).
#
# Pins the ONE-probe-library contract:
#   1. derive-state.sh produces the right `derived.position` + `proposed_next`
#      for every routing-decision-table fixture row (empty / legacy-code-only /
#      PRD-only / layout-2 vaults → layout2_needs_migration (9.0, spec
#      2026-09-27-v9-simplification-design.md §4) / plan-born layout-3 vaults:
#      context-without-json / units-no-bolts / stale-index + dirty-journal
#      Mode D (re-bind hop = rebind-units.sh) / bolts-present).
#   2. PARITY: validate-preflight.sh — now delegating its has_vault()-class
#      probes to _lib/state_probes.py — judges the same fixtures EXACTLY as the
#      pre-refactor committed script did (expected literals below were captured
#      from the v4.92.0 committed validate-preflight BEFORE the refactor); the
#      four classic skills removed in 9.0 FATAL skill_removed_in_9.
#   3. state.json's probes.preflight_predicates agree with the preflight verdicts
#      (one library, one truth).
#   4. derive-state NEVER creates .mega-sdd/ in a directory that lacks it
#      (no minted SDD signals), and stays fast (no subprocess storms).
#   5. session-start prints the 8.8.0 state-anchor block (spec
#      2026-09-25-state-anchor-design.md §6, D7): the old repo-wide "codebase moved"
#      notice is retired, the journal is never read at session start, and the
#      PENDING-SYNC queue stays at M/L entry.
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

# 9.0: plan writes the ONLY buildable layout (layout-3: context.md +
# constitution.md + vault.json + units/). The f4..f9 vaults above are layout-2 /
# legacy (classic-born) — still READ (parity/predicates/session-start below),
# but routed to the migrate row; the *l3 twins pin the surviving build rows.
vault_l3() {
  mkdir -p "$1"
  printf -- '---\ntype: context\nvault_layout: 3\n---\n# Context\n\n## Open Questions\n\n' > "$1/context.md"
  printf '# Constitution\n' > "$1/constitution.md"
}
write_index() { # $1=fixture  $2=head_commit stamp
  mkdir -p "$1/.mega-sdd/codebase"
  printf '{"generated_by":"build-symbol-index.sh","head_commit":"%s","symbols":[]}' "$2" \
    > "$1/.mega-sdd/codebase/symbol-index.json"
}
unit_binding() { # $1=vault  $2=unit — the per-unit JIT binding (lite "bound")
  mkdir -p "$1/bolts/$2"; printf '{"schema":"unit-binding/2","unit":"%s"}\n' "$2" > "$1/bolts/$2/binding.json"
}

mkdir -p "$WORK/f1-empty"

F="$WORK/f2-legacy-code"; mkdir -p "$F/src"
printf '{}\n' > "$F/composer.json"; printf '<?php echo 1;\n' > "$F/src/app.php"
gitinit "$F"

F="$WORK/f3-prd-only"; mkdir -p "$F"; printf '# PRD\n' > "$F/prd.md"

# f3b — the PRD lives one level down (PRD/prd-simkredit.md), NO root prd.md.
# Field finding 2026-08-03 (training-nextjs): the root-only probe missed it,
# mis-deriving the position AND false-failing the generate-intent preflight.
F="$WORK/f3b-prd-subdir"; mkdir -p "$F/PRD"; printf '# PRD simkredit\n' > "$F/PRD/prd-simkredit.md"

F="$WORK/f4-vault-md-no-json"; vault_docs "$F/.mega-sdd/vaults/v1"

F="$WORK/f5-binding-conflicts"; mkdir -p "$F/src" "$F/.mega-sdd/codebase"
printf '{}\n' > "$F/composer.json"; printf '<?php\n' > "$F/src/app.php"
vault_docs "$F/.mega-sdd/vaults/v1"; mkvj "$F/.mega-sdd/vaults/v1" existing
gitinit "$F"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "$(git -C "$F" rev-parse HEAD)"
# a symbol index at HEAD (the 9.0 freshness substrate) — host-independent:
# fixtures never depend on the runner having ast-grep (CI has none)
write_index "$F" "$(git -C "$F" rev-parse HEAD)"
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

# f9b — layout-2 vault that TRIPS Mode D (index at HEAD + binding.md + dirty
# journal): 9.0 syncs layout-3 only, so it still lands on the migrate row,
# never the rebind-units sync chain.
F="$WORK/f9b-l2-mode-d"; cp -R "$WORK/f9-dirty-journal" "$F"
write_index "$F" "$(git -C "$F" rev-parse HEAD)"

# ── layout-3 (plan-born) twins: the surviving build/sync rows ──
# f4l3 — context.md, no vault.json, no units, a PRD older than the vault
F="$WORK/f4l3-context-no-json"; vault_l3 "$F/.mega-sdd/vaults/v1"
printf '# PRD\n' > "$F/prd.md"
python3 -c "
import os, time
old = time.time() - 86400
os.utime('$F/prd.md', (old, old))
"
# f6l3 — context.md + vault.json + 2 units, no bolts
F="$WORK/f6l3-units-no-bolts"; mkdir -p "$F/src"
printf '{}\n' > "$F/composer.json"; printf '<?php\n' > "$F/src/app.php"
vault_l3 "$F/.mega-sdd/vaults/v1"; mkvj "$F/.mega-sdd/vaults/v1" existing
mkdir -p "$F/.mega-sdd/vaults/v1/units"
printf -- '---\nid: U-001\n---\n' > "$F/.mega-sdd/vaults/v1/units/U-001.md"
printf -- '---\nid: U-002\n---\n' > "$F/.mega-sdd/vaults/v1/units/U-002.md"
# f8l3 — per-unit binding + a STALE index stamp → Mode D
F="$WORK/f8l3-index-stale"; cp -R "$WORK/f6l3-units-no-bolts" "$F"; gitinit "$F"
unit_binding "$F/.mega-sdd/vaults/v1" U-001
write_index "$F" "ffffffffffffffffffffffffffffffffffffffff"
# f8l3b — index at HEAD, but a leftover pre-9.0 map with a STALE stamp: the map
# stamp never triggers Mode D (nothing refreshes it — the F4 livelock)
F="$WORK/f8l3b-map-stale-index-fresh"; cp -R "$WORK/f6l3-units-no-bolts" "$F"; gitinit "$F"
unit_binding "$F/.mega-sdd/vaults/v1" U-001
write_index "$F" "$(git -C "$F" rev-parse HEAD)"
mkdir -p "$F/.mega-sdd/codebase"
write_map "$F/.mega-sdd/codebase/codebase-map.md" "ffffffffffffffffffffffffffffffffffffffff"
# f9l3 — per-unit binding + index at HEAD + dirty journal → Mode D
F="$WORK/f9l3-dirty-journal"; cp -R "$WORK/f6l3-units-no-bolts" "$F"; gitinit "$F"
unit_binding "$F/.mega-sdd/vaults/v1" U-001
write_index "$F" "$(git -C "$F" rev-parse HEAD)"
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
for fx in f1-empty:empty f2-legacy-code:legacy_code_only f3-prd-only:prd_no_vault f3b-prd-subdir:prd_no_vault; do
  name="${fx%%:*}"; want="${fx##*:}"
  J=$(bash "$DS" --cwd="$WORK/$name" --json-only </dev/null 2>/dev/null)
  got=$(printf '%s' "$J" | python3 -c "import json,sys; print(json.load(sys.stdin)['derived']['position'])" 2>/dev/null)
  [ "$got" = "$want" ] && ok "$name: position=$want" || fail "$name: position expected $want, got '$got'"
  [ -d "$WORK/$name/.mega-sdd" ] && fail "$name: derive-state MINTED .mega-sdd/ (SDD-signal pollution)" \
    || ok "$name: no .mega-sdd/ minted"
done
# f3c (round CL-F1): prd_revision must diff the NEWEST candidate, not
# candidates[0] — an old root prd.md + a newer docs/ revision otherwise loops
# (diff-vault of the unchanged file never advances the vault mtime).
F="$WORK/f3c-prd-newest"; mkdir -p "$F/docs" "$F/.mega-sdd/codebase"
vault_docs "$F/.mega-sdd/vaults/v1"; mkvj "$F/.mega-sdd/vaults/v1" existing
printf '# old PRD\n' > "$F/prd.md"
printf '# new revision\n' > "$F/docs/prd-v2.md"
python3 -c "
import os, time
old = time.time() - 86400
os.utime('$F/prd.md', (old, old))
for r, _d, fs in os.walk('$F/.mega-sdd/vaults'):
    for fn in fs:
        p = os.path.join(r, fn); os.utime(p, (old + 3600, old + 3600))
"
J=$(bash "$DS" --cwd="$WORK/f3c-prd-newest" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['derived']['position']=='prd_revision', d['derived']['position']
nxt=' '.join(d['derived']['proposed_next'])
assert 'diff-vault docs/prd-v2.md' in nxt, nxt
assert d['probes']['prd']['newest']=='docs/prd-v2.md', d['probes']['prd']
" 2>/dev/null && ok "f3c: prd_revision diffs the NEWEST candidate (docs/prd-v2.md)" \
  || fail "f3c: prd_revision still acts on candidates[0] (round CL-F1 regression)"

# f3b: the subdir candidate is reported WITH its dir prefix (the probe scans one
# level inside the fixed PRD//prd//docs//documents//requirements/ set — never a walk)
J=$(bash "$DS" --cwd="$WORK/f3b-prd-subdir" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
p=json.load(sys.stdin)['probes']['prd']
assert p['present'] is True, p
assert 'PRD/prd-simkredit.md' in p['candidates'], p['candidates']
" 2>/dev/null && ok "f3b: probes.prd finds PRD/prd-simkredit.md (prefix kept)" \
  || fail "f3b: subdir PRD candidate missing from probes.prd"
# f3d: from-prompt writes its seed under the vault it grows into
# (.mega-sdd/vaults/<slug>/source/seed-PRD.md) with NO root PRD — the probe must list it
# (prefixed relname) or the status view derives "no PRD" on a live from-prompt project.
F="$WORK/f3d-prd-vault-seed"; mkdir -p "$F/.mega-sdd/vaults/leave-app/source"
printf '# seed PRD (from-prompt)\n' > "$F/.mega-sdd/vaults/leave-app/source/seed-PRD.md"
J=$(bash "$DS" --cwd="$WORK/f3d-prd-vault-seed" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
p=json.load(sys.stdin)['probes']['prd']
assert p['present'] is True, p
assert '.mega-sdd/vaults/leave-app/source/seed-PRD.md' in p['candidates'], p['candidates']
" 2>/dev/null && ok "f3d: probes.prd finds .mega-sdd/vaults/leave-app/source/seed-PRD.md (from-prompt seed, prefix kept)" \
  || fail "f3d: from-prompt seed under <vault>/source/ missing from probes.prd"
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

# ── layout-2 / legacy (classic-born) vaults → the migrate row (9.0, spec §4) ──
# Retired with the classic chain (9.0 removed generate-intent / bind-codebase /
# generate-units / scan-codebase): vault_greenfield_no_units, vault_map_unbound
# (→ bind-codebase --express), binding_resolved_no_rebind (→ generate-units) and
# the map-keyed Mode D. A layout-2 vault that needs building OR syncing now
# routes to layout2_needs_migration: empty chain + a note PROPOSING
# /mega-sdd:migrate-paths --vault-layout=3 (never run silently).
for fx in f4-vault-md-no-json f5-binding-conflicts f5b-binding-kv-defer f6-units-no-bolts \
          f8-map-stale f9-dirty-journal f9b-l2-mode-d; do
  run_ds "$WORK/$fx" >/dev/null 2>&1
  got=$(state_field "$WORK/$fx" "d['derived']['position']+'|'+repr(d['derived']['proposed_next'])+'|'+str(any('migrate-paths --vault-layout=3' in n for n in d['derived']['notes']))")
  [ "$got" = "layout2_needs_migration|[]|True" ] \
    && ok "$fx: layout-2 vault → layout2_needs_migration, chain [], migrate-paths --vault-layout=3 proposed in a note" \
    || fail "$fx: expected layout2_needs_migration|[]|True, got '$got'"
done
got=$(state_field "$WORK/f4-vault-md-no-json" "d['derived']['manifest_derive_needed']")
[ "$got" = "True" ] && ok "f4: manifest_derive_needed=True (P0 unification)" || fail "f4: manifest_derive_needed wrong: $got"
got=$(state_field "$WORK/f4-vault-md-no-json" "d['probes']['preflight_predicates']['has_vault']")
[ "$got" = "True" ] && ok "f4: has_vault() TRUE on bare docs (routing==preflight, one library)" \
  || fail "f4: has_vault predicate lost the P0 unification: $got"
got=$(state_field "$WORK/f5-binding-conflicts" "str(d['probes']['vaults'][0]['binding']['conflicts_active'])+'/'+str(d['probes']['vaults'][0]['binding']['conflicts_resolved'])")
[ "$got" = "1/1" ] && ok "f5: conflict counts active=1 resolved=1 (binding_md grammar — layout-2 stays READABLE)" \
  || fail "f5: conflict counts expected 1/1, got '$got'"
got=$(state_field "$WORK/f6-units-no-bolts" "str(d['probes']['vaults'][0]['units_count'])+'/'+str(d['probes']['vaults'][0]['bolts_count'])")
[ "$got" = "2/0" ] && ok "f6: units=2 bolts=0" || fail "f6: counts expected 2/0, got '$got'"
got=$(state_field "$WORK/f8-map-stale" "d['derived']['change_signal']['map_stamp_matches_head']")
[ "$got" = "no" ] && ok "f8: change_signal.map_stamp_matches_head=no" || fail "f8: matches_head got '$got'"
got=$(state_field "$WORK/f9-dirty-journal" "d['derived']['change_signal']['dirty_journal_rows']")
[ "$got" = "3" ] && ok "f9: change_signal.dirty_journal_rows=3" || fail "f9: dirty rows got '$got'"

# ── layout-3 (plan-born) twins: the surviving rows ──
# f4l3: P0 unification — bare docs without vault.json derive the manifest FIRST
# (repointed from the layout-2 f4 chain-head pin: the prepend fires on any
# non-empty chain, and a layout-2 vault's chain is now empty).
run_ds "$WORK/f4l3-context-no-json" >/dev/null 2>&1
got=$(state_field "$WORK/f4l3-context-no-json" "d['derived']['position']")
[ "$got" = "lite_context_no_units" ] && ok "f4l3: context.md, no units → position=lite_context_no_units" \
  || fail "f4l3: position expected lite_context_no_units, got '$got'"
got=$(state_field "$WORK/f4l3-context-no-json" "d['derived']['manifest_derive_needed']")
[ "$got" = "True" ] && ok "f4l3: manifest_derive_needed=True (context.md counts as a vault doc)" \
  || fail "f4l3: manifest_derive_needed wrong: $got"
got=$(state_field "$WORK/f4l3-context-no-json" "d['derived']['proposed_next'][0]")
case "$got" in scripts/derive-vault-json.sh*) ok "f4l3: chain FIRST derives vault.json (never hand-written)";;
  *) fail "f4l3: chain head expected derive-vault-json.sh, got '$got'";; esac
got=$(state_field "$WORK/f4l3-context-no-json" "d['derived']['proposed_next'][1:]")
[ "$got" = "['plan prd.md --lite --regenerate', 'execute-bolts --all --lite']" ] \
  && ok "f4l3: then plan --regenerate → execute-bolts --all --lite (never generate-units)" \
  || fail "f4l3: chain after the manifest hop wrong: $got"

# f6l3: repointed from f6 (layout-2 now migrates first)
run_ds "$WORK/f6l3-units-no-bolts" >/dev/null 2>&1
got=$(state_field "$WORK/f6l3-units-no-bolts" "d['derived']['position']")
[ "$got" = "units_pending_bolts" ] && ok "f6l3: position=units_pending_bolts" || fail "f6l3: position got '$got'"
got=$(state_field "$WORK/f6l3-units-no-bolts" "d['derived']['proposed_next']")
[ "$got" = "['execute-bolts --all --lite']" ] && ok "f6l3: proposed_next=[execute-bolts --all --lite] (the default inline run; --parallel/--per-squad proposed nowhere)" || fail "f6l3: chain wrong: $got"
got=$(state_field "$WORK/f6l3-units-no-bolts" "str(d['probes']['vaults'][0]['units_count'])+'/'+str(d['probes']['vaults'][0]['bolts_count'])")
[ "$got" = "2/0" ] && ok "f6l3: units=2 bolts=0" || fail "f6l3: counts expected 2/0, got '$got'"

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

# f8l3: repointed from f8 — the 9.0 Mode D trigger is the symbol-index stamp
# (the map stamp is informational), and the claim-scoped re-bind hop is the
# per-unit writer rebind-units.sh (bind-codebase --paths was removed).
run_ds "$WORK/f8l3-index-stale" >/dev/null 2>&1
got=$(state_field "$WORK/f8l3-index-stale" "d['derived']['position']")
[ "$got" = "maintenance_sync" ] && ok "f8l3: stale index stamp → position=maintenance_sync (Mode D)" \
  || fail "f8l3: position expected maintenance_sync, got '$got'"
got=$(state_field "$WORK/f8l3-index-stale" "d['derived']['change_signal']['index_stamp_matches_head']")
[ "$got" = "no" ] && ok "f8l3: change_signal.index_stamp_matches_head=no" || fail "f8l3: index matches_head got '$got'"
got=$(state_field "$WORK/f8l3-index-stale" "d['derived']['proposed_next'][2]")
[ "$got" = "scripts/rebind-units.sh --cwd=. --vault=.mega-sdd/vaults/v1 --paths=@.mega-sdd/vaults/v1/.sync-changed-paths.txt" ] \
  && ok "f8l3: Mode D chain keeps the claim-scoped re-bind hop (rebind-units.sh --paths=@…)" \
  || fail "f8l3: Mode D chain hop 3 expected rebind-units.sh --paths=@…, got '$got'"
# f8l3b: the map stamp never triggers Mode D (F4 livelock guard)
run_ds "$WORK/f8l3b-map-stale-index-fresh" >/dev/null 2>&1
got=$(state_field "$WORK/f8l3b-map-stale-index-fresh" "d['derived']['change_signal']['map_stamp_matches_head']+'|'+d['derived']['position']")
[ "$got" = "no|units_pending_bolts" ] && ok "f8l3b: stale MAP stamp alone (index at HEAD) never fires Mode D" \
  || fail "f8l3b: expected no|units_pending_bolts, got '$got'"

# f9l3: repointed from f9 (the journal fires Mode D on a layout-3 vault)
run_ds "$WORK/f9l3-dirty-journal" >/dev/null 2>&1
got=$(state_field "$WORK/f9l3-dirty-journal" "d['derived']['position']")
[ "$got" = "maintenance_sync" ] && ok "f9l3: dirty journal → position=maintenance_sync (Mode D)" \
  || fail "f9l3: position expected maintenance_sync, got '$got'"
got=$(state_field "$WORK/f9l3-dirty-journal" "d['derived']['change_signal']['dirty_journal_rows']")
[ "$got" = "3" ] && ok "f9l3: change_signal.dirty_journal_rows=3" || fail "f9l3: dirty rows got '$got'"

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

# no-.mega-sdd fixtures: the exact pre-refactor no-project PASS (probed via a
# surviving skill — the no-project exit precedes every per-skill check)
for fx in f1-empty f2-legacy-code f3-prd-only; do
  out=$(bash "$VPF" --cwd="$WORK/$fx" --skill=mega-sdd:execute-bolts </dev/null 2>/dev/null); rc=$?
  [ "$rc" = "0" ] && printf '%s' "$out" | grep -qF '"reason":"no .mega-sdd/ project"' \
    && ok "parity $fx: no-project PASS literal unchanged" \
    || fail "parity $fx: no-project lane changed (rc=$rc out=${out:0:80})"
done

# 9.0 retired the classic-skill cells (bind-codebase express/classic-spine
# map arm, generate-units, scan-codebase tree-sitter WARN) with their skills;
# the surviving execute-bolts cells are unchanged.
expect_pf f4-vault-md-no-json execute-bolts  1 FATAL bolts_units_missing
expect_pf f5-binding-conflicts execute-bolts  1 FATAL bolts_units_missing
expect_pf f6-units-no-bolts   execute-bolts  0 PASS -
expect_pf f7-bolts-present    execute-bolts  0 PASS -
# A direct --skill= dispatch of a removed classic skill FATALs with the one-line
# replacement pointer (state_probes.REMOVED_SKILLS) — never a fall-through PASS.
for s in generate-intent bind-codebase generate-units scan-codebase; do
  expect_pf f6-units-no-bolts "$s" 1 FATAL skill_removed_in_9
done

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

# ── 5. session-start state block (8.8.0 state anchor; the old notice is retired, D7) ──
note "== 5. session-start state block =="
RULE_TXT='Rule: code at HEAD decides what the code IS (files, symbols, lines, what is built).'
out=$( cd "$WORK/f9-dirty-journal" && printf '{"session_id":"t","source":"startup"}' | bash "$SS" 2>/dev/null )
printf '%s' "$out" | grep -q '^mega-sdd state @ [0-9a-f]\{12\} (' && printf '%s' "$out" | grep -qF "$RULE_TXT" \
  && ok "f9: session-start prints the state block header + the rule line" \
  || fail "f9: state block missing"
printf '%s' "$out" | grep -qF 'codebase moved since last scan' \
  && fail "f9: the retired repo-wide notice came back (D7)" \
  || ok "f9: the retired 'codebase moved' notice stays gone (the journal is not read at session start)"
# the engine's view (GROUND / the Stop bootstrap) is what names the vault — not the journal
python3 "${PLUGIN_ROOT}/scripts/_lib/freshness.py" --cwd="$WORK/f9-dirty-journal" >/dev/null 2>&1; sleep 1
out=$( cd "$WORK/f9-dirty-journal" && printf '{"session_id":"t2","source":"startup"}' | bash "$SS" 2>/dev/null )
printf '%s' "$out" | grep -q '^- .*v1' \
  && ok "f9: once the engine view exists, the block reports the vault (v1)" \
  || fail "f9: engine view written but no vault line in the block"
printf -- '- [ ] decide A\n- [ ] decide B\n' > "$WORK/f9-dirty-journal/.mega-sdd/vaults/v1/PENDING-SYNC.md"
out=$( cd "$WORK/f9-dirty-journal" && printf '{"session_id":"t3","source":"startup"}' | bash "$SS" 2>/dev/null )
# v7.5.0 №B (Fase-7 audit §3): the PENDING-SYNC open-count leg LEFT session-start
# with the probe engine; the queue surfaces at M/L entry, where derive-state's
# pending_sync_open probe (pinned by the digest arms above) is actually read.
# Negative pin: the queue text must NOT come back to session-start.
printf '%s' "$out" | grep -qF 'open sync decision(s) queued' \
  && fail "f9+queue: session-start re-grew the PENDING-SYNC leg (№B moved it to M/L entry)" \
  || ok "f9+queue: session-start stays queue-silent (the queue lives at M/L entry)"
printf '%s' "$out" | grep -q '^mega-sdd state @' \
  && ok "f9+queue: the state block still prints alongside an open queue" \
  || fail "f9+queue: state block lost when a queue exists"
rm -f "$WORK/f9-dirty-journal/.mega-sdd/vaults/v1/PENDING-SYNC.md"
out=$( cd "$WORK/f6-units-no-bolts" && printf '{"session_id":"t","source":"startup"}' | bash "$SS" 2>/dev/null )
printf '%s' "$out" | grep -qF 'codebase moved since last scan' \
  && fail "f6: clean fixture got the retired notice" \
  || ok "f6: clean fixture: no retired notice (the state block replaces it)"

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


# ── 11. knowledge_base: config key (7.30.0, spec 2026-09-07-shared-kb-config-path-design.md) ──
# A KB shared ACROSS projects (monorepo: FE app + BE app + one KB submodule two levels up)
# is pointed at by `knowledge_base: <dir>` in .mega-sdd/config.yaml. Config wins over the
# four in-project generations, and a configured-but-missing path NEVER falls through to a
# stale local copy — it reports absent + configured_missing + a note.
note ""
note "== 11. knowledge_base: config key (shared KB outside the project) =="
kb_diag() { printf '%s' "$1" | python3 -c 'import json,sys
d=json.load(sys.stdin); print(d["probes"]["knowledge_base"], d["derived"]["position"], d["derived"]["proposed_next"], d["derived"]["notes"])' 2>/dev/null; }
kb_fixture() { # $1=dir  $2=config-line-or-empty  $3=local-kb(yes/no)
  mkdir -p "$1/.mega-sdd"
  [ -n "$2" ] && printf 'spine: express\n%s\n' "$2" > "$1/.mega-sdd/config.yaml" || printf 'spine: express\n' > "$1/.mega-sdd/config.yaml"
  if [ "$3" = "yes" ]; then
    mkdir -p "$1/.mega-sdd/knowledge-base"
    printf '# Knowledge Base — STALE local copy\n' > "$1/.mega-sdd/knowledge-base/README.md"
  fi
  gitinit "$1"
}
mkdir -p "$WORK/shared-kb/kb/modules"
printf '# Knowledge Base — shared v2\n' > "$WORK/shared-kb/kb/README.md"
printf '{"schema":1}\n' > "$WORK/shared-kb/kb/census.json"

kb_fixture "$WORK/mono/f11a-kb-config-external" 'knowledge_base: ../../shared-kb/kb/' no
J=$(bash "$DS" --cwd="$WORK/mono/f11a-kb-config-external" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin); k=d['probes']['knowledge_base']
assert k['present'] is True, k
assert k['source']=='config', k
assert k['path']=='../../shared-kb/kb/README.md', k
assert d['derived']['position']=='kb_no_vault', d['derived']['position']
assert d['derived']['proposed_next'][0]=='plan --kb=../../shared-kb/kb --lite --mode=new', d['derived']['proposed_next']
" 2>/dev/null && ok "f11a: external KB via config → present/source=config, chain plan --kb=../../shared-kb/kb (9.0: plan is the KB consumer)" \
  || fail "f11a: configured external KB not detected/routed: $(kb_diag "$J")"

kb_fixture "$WORK/mono/f11b-kb-config-missing" 'knowledge_base: ../../shared-kb/does-not-exist/' yes
J=$(bash "$DS" --cwd="$WORK/mono/f11b-kb-config-missing" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin); k=d['probes']['knowledge_base']
assert k['present'] is False, k
assert k.get('configured_missing') is True, k
assert k.get('configured')=='../../shared-kb/does-not-exist/', k
assert d['derived']['position']!='kb_no_vault', d['derived']['position']
assert any('knowledge_base' in n and 'does-not-exist' in n for n in d['derived']['notes']), d['derived']['notes']
" 2>/dev/null && ok "f11b: configured-but-missing KB → absent + configured_missing + note (no fall-through to the stale local copy)" \
  || fail "f11b: missing configured KB fell through or is silent: $(kb_diag "$J")"

kb_fixture "$WORK/mono/f11c-kb-config-wins" 'knowledge_base: "../../shared-kb/kb"  # shared' yes
J=$(bash "$DS" --cwd="$WORK/mono/f11c-kb-config-wins" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
k=json.load(sys.stdin)['probes']['knowledge_base']
assert k['present'] is True and k['source']=='config', k
assert k['path']=='../../shared-kb/kb/README.md', k
" 2>/dev/null && ok "f11c: config beats the local .mega-sdd/knowledge-base/ (quoted value + trailing comment parsed)" \
  || fail "f11c: local KB shadowed the configured one: $(kb_diag "$J")"

kb_fixture "$WORK/mono/f11d-kb-default" '' yes
J=$(bash "$DS" --cwd="$WORK/mono/f11d-kb-default" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
k=json.load(sys.stdin)['probes']['knowledge_base']
assert k['present'] is True and k['source']=='default', k
assert k['path']=='.mega-sdd/knowledge-base/README.md', k
" 2>/dev/null && ok "f11d: no config → the 4-generation default still wins (regression pin)" \
  || fail "f11d: default KB detection regressed: $(kb_diag "$J")"

kb_fixture "$WORK/mono/f11e-kb-config-absolute" "knowledge_base: $WORK/shared-kb/kb" no
J=$(bash "$DS" --cwd="$WORK/mono/f11e-kb-config-absolute" --json-only </dev/null 2>/dev/null)
printf '%s' "$J" | python3 -c "
import json,sys
k=json.load(sys.stdin)['probes']['knowledge_base']
assert k['present'] is True and k['source']=='config', k
assert k['path'].endswith('/shared-kb/kb/README.md'), k
" 2>/dev/null && ok "f11e: absolute knowledge_base path accepted" \
  || fail "f11e: absolute path not accepted: $(kb_diag "$J")"

note ""
if [ "$FAILED" -eq 0 ]; then note "ALL P1 state-engine assertions PASS"; else note "P1 state-engine FAILURES"; fi
exit $FAILED
