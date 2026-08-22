#!/usr/bin/env bash
# test-dispatch-prompt-builder-shape.sh — tranche 2b (spec
# docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md §2b):
# SHAPE + PARITY pins for the deterministic dispatch-prompt assembler
# plugins/mega-sdd/scripts/build-dispatch-prompt.sh.
#
# The cascade/budget arithmetic is pinned by its own sibling suite. THIS suite
# pins the surfaces a cascade test cannot see:
#
#   A  PARITY WITH THE LIVE ADVISORY VALIDATOR — the free oracle. A ui_ux
#      fixture (unit `starterkit_relevance: [ui_ux]`, starterkit design_tokens +
#      a view pattern whose `_source` exists on disk, pack `## UI quality
#      signatures` view_glob, vault `design_system`) is built, then
#      scripts/validate-dispatch-prompt.sh is run over the SAME project and must
#      return PASS with tokens_not_injected / design_system_not_injected /
#      exemplar_missing all zero. A builder whose own output trips the shipped
#      gate is a self-inflicted regression on every single run.
#   B  the `_authored_by` acceptance-test NOTE, all four ways (this inverts
#      easily — absence is NOT omission here, and `adversarial-reviewed` is the
#      near-miss of `adversarial-review-failed`).
#   C  inline_core — the entire point of 2b: <=700 bytes, the trace tag, the
#      absolute path to the on-disk dispatch, the target_files whitelist, and
#      the documented whitelist -> count degradation.
#   D  ANTI-FABRICATION (moat invariant #5) — every optional input absent =>
#      still a valid prompt, sections OMITTED with a cited reason, and NOT ONE
#      of their marker lines present.
#   E  invariant #5 on the exact input the design slice names: ui-bearing unit,
#      vault with NO design_system => no invented style/palette, note emitted.
#   F  the Map §6 fallback (starterkit absent) + no double-emission when both
#      starterkit-context.yaml and codebase-map.md §6 are present.
#   G  the T1 UNCONDITIONAL reuse-index rail (ships even with zero candidates
#      and no reuse-index.yaml on disk).
#   H  idempotence + determinism — two consecutive runs on an unchanged fixture
#      are BYTE-IDENTICAL (that is what makes the artifact diffable for
#      provenance), and T1+T2 carry no absolute path at all (the abs paths are
#      confined to the T3 pointer block).
#   I  exit codes: 2 on a missing/unreadable unit and on usage errors; 0 with a
#      RECORDED soft halt on a corrupt starterkit-context.yaml (never a hard
#      failure); `--quiet` emits nothing on stdout (execute-bolts must NOT pass
#      it — inline_core is the only carrier of the payload the controller pastes).
#
# Sections J-W carry their own rationale block at the point of use. The four that
# exist because a FIX ROUND broke something are worth naming here, because each
# is a case where the remedy was more damaging than the defect:
#   S  a failed run DESTROYS NOTHING (round 2's pre-assembly unlink turned a
#      stdout-encoding failure into a deleted, correct artifact),
#   T  the design slice is a neutral lens-input FILE, path on stdout,
#   U  the absent-value detector is a smoke alarm, never a circuit breaker,
#   V  cp1252 stdout must not cost the artifact,
#   W  a markdown table HEADER is never emitted as a locked path.
#
# HERMETICITY NOTES (load-bearing, do not "simplify"):
#   * EVERY sub-test gets its OWN project root. validate-dispatch-prompt.sh
#     globs `<cwd>/.mega-sdd/vaults/*/bolts/*/dispatch-prompt.md` PROJECT-WIDE
#     and FAILs on any in-scope ui_ux prompt lacking tokens/exemplar — a shared
#     root would let an unrelated fixture decide the parity verdict.
#   * `--plugin-root=<repo plugin>` is passed on every build. Without it the
#     builder resolves the plugin root via resolve-plugin-root.sh, which on a
#     developer machine points at the INSTALLED marketplace cache — so the pack
#     BODIES would come from a different (possibly older) plugin version than
#     the pack CHAIN, which resolve-framework-pack.sh derives from its own
#     on-disk location. Pinning it makes the suite test THIS tree.
#   * laravel.md is the fixture pack ONLY because it is one of the packs that
#     declares a `## UI quality signatures` view_glob. No Laravel signature is
#     asserted anywhere in this file; swap the pack, swap the fixture paths.
#
# Run: bash tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/mega-sdd"
BUILD="$PLUGIN_ROOT/scripts/build-dispatch-prompt.sh"
VALIDATE="$PLUGIN_ROOT/scripts/validate-dispatch-prompt.sh"
for f in "$BUILD" "$VALIDATE"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done
# INTERPRETER — resolved through the SHARED probe, never `command -v python3`.
# `command -v python3` is the documented Windows FALSE POSITIVE this very
# changeset hardened three scripts against: the WindowsApps App Execution Alias
# stub answers `command -v`, writes to stderr and exits 49. A suite gated that
# way does NOT take its SKIP branch on the target machine — it runs, and every
# one of the ~45 assertion helpers below exits 49 with empty stdout, producing a
# wall of spurious FAILs including in section P, the section that exists to prove
# the alias stub no longer breaks the builder. The twin suite
# (plugins/mega-sdd/tests/moat/test-dispatch-prompt-cascade.sh) already resolves
# it this way; the two suites must not disagree about the one portability rule
# this tranche is about.
#
# $PY is expanded UNQUOTED at every call site: the Windows fallback is `py -3`,
# two words. MEGA_SDD_PY is NOT exported by the helper and must not be exported
# here — the builder under test does its OWN resolution, and section P depends on
# that being independent of the suite's.
if [ -f "$PLUGIN_ROOT/scripts/_lib/resolve-python.sh" ]; then
  # shellcheck disable=SC1091
  . "$PLUGIN_ROOT/scripts/_lib/resolve-python.sh"
  if mega_sdd_python; then
    PY="$MEGA_SDD_PY"
  else
    echo "SKIP: no usable python interpreter (the suite cannot read builder JSON)"
    mega_sdd_python_remedy
    echo
    exit 0
  fi
else
  echo "missing $PLUGIN_ROOT/scripts/_lib/resolve-python.sh"; exit 1
fi

ASSERTS=0
FAILED=0
ok()   { ASSERTS=$((ASSERTS + 1)); printf '  \342\234\223 %s\n' "$*"; }
fail() { ASSERTS=$((ASSERTS + 1)); FAILED=$((FAILED + 1)); printf '  \342\234\227 FAIL: %s\n' "$*"; }
note() { printf '%s\n' "$*"; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t dpbshape)"
trap 'rm -rf "$WORK"' EXIT

# ── helpers ───────────────────────────────────────────────────────────────────
# A project root per sub-test. WORK itself carries no .mega-sdd/, so
# resolve_project_root never walks out of the fixture it was handed.
mkproj() {                                    # mkproj <name> -> echoes project root
  local p="$WORK/$1"
  mkdir -p "$p/.mega-sdd/vaults/v1/units"
  printf '%s' "$p"
}

RC=0
# `--explain` is on EVERY build() here on purpose. The forensic keys
# (sections_emitted / sections_omitted / caps / inline_core_bytes /
# inline_core_degraded / pack_chain / pack_resolver_exit / interpreter) moved OFF
# default stdout — they are a measured input channel the controller never reads —
# and this suite's whole job is to audit them. Section K asserts the DEFAULT
# shape (they must all be ABSENT there); everything else runs with --explain so
# the forensics are visible. Do not "tidy" the flag away in either direction.
build() {                                     # build <outjson> <proj> <unit> [extra args...]
  local out="$1" proj="$2" unit="$3"
  shift 3
  bash "$BUILD" --cwd="$proj" --vault="$proj/.mega-sdd/vaults/v1" --unit="$unit" \
       --plugin-root="$PLUGIN_ROOT" --explain "$@" >"$out" 2>"${out}.err" </dev/null
  RC=$?
}

build_default() {                             # build_default <outjson> <proj> <unit>
  # The SHIPPED invocation — exactly what skills/execute-bolts runs. No --explain.
  local out="$1" proj="$2" unit="$3"
  shift 3
  bash "$BUILD" --cwd="$proj" --vault="$proj/.mega-sdd/vaults/v1" --unit="$unit" \
       --plugin-root="$PLUGIN_ROOT" "$@" >"$out" 2>"${out}.err" </dev/null
  RC=$?
}

promptof() { printf '%s' "$1/.mega-sdd/vaults/v1/bolts/$2/dispatch-prompt.md"; }

# grep -c exits 1 on zero matches; `|| true` keeps the count ("0") flowing.
cntF() { grep -cF -- "$1" "$2" 2>/dev/null || true; }   # fixed string
cntE() { grep -cE -- "$1" "$2" 2>/dev/null || true; }   # ERE

# ══════════════════════════════════════════════════════════════════════════════
note "== A. PARITY with the live advisory validator (the free oracle) =="
# ══════════════════════════════════════════════════════════════════════════════
P_UI="$(mkproj proj-ui)"
mkdir -p "$P_UI/.mega-sdd/codebase" \
         "$P_UI/resources/views/orders" "$P_UI/app/Http/Controllers"

cat > "$P_UI/.mega-sdd/vaults/v1/units/U-002.md" <<'MD'
---
id: U-002
title: Render the order detail view
task_type: create
scope: S-01
scope_name: Orders
module: orders
risk: medium
status: pending
starterkit_relevance: [ui_ux, libs]
target_files:
  - path: resources/views/orders/show.blade.php
    operation: create
  - path: app/Http/Controllers/OrderController.php
    operation: modify
acceptance_test:
  - command: "run the order-detail feature test"
    _authored_by: same-pass
---

## Intent

Render the order detail view with its line items.

## Hard rules

- DO NOT modify app/Models/Order.php
MD

cat > "$P_UI/.mega-sdd/vaults/v1/vault.json" <<'JSON'
{
  "vault_version": "v1",
  "design_system": {
    "style": "minimalism",
    "palette": "trust-blue",
    "typography": "Inter",
    "a11y_level": "AA",
    "source": "scanned-template"
  }
}
JSON

# framework_pack is what resolve-framework-pack.sh keys on; the pack supplies the
# view_glob BOTH the builder (ui_bearing) and the validator (exemplar check) read.
cat > "$P_UI/.mega-sdd/codebase/starterkit-context.yaml" <<'YAML'
framework_pack: laravel
ui_ux:
  layout_extends: layouts.app
  notification_lib: sweetalert2
  idioms:
    - toast on success
    - modal confirm on destroy
  design_tokens:
    colors:
      primary: "#2563EB"
      surface: "#F8FAFC"
    spacing: "8px scale"
    fonts:
      - Inter
libs:
  - name: acme/http-kit
    version: "2.1"
    usage_hint:
      - app/Http/Controllers
patterns:
  view:
    location: resources/views
    naming: "{model}.blade.php"
    extension: ".blade.php"
    _source:
      - resources/views/orders/index.blade.php
  controller:
    location: app/Http/Controllers
    naming: "{Model}Controller"
    extension: ".php"
    _source:
      - app/Http/Controllers/HomeController.php
YAML

printf '@extends("layouts.app")\n@section("content")\n<div class="p-4">Orders</div>\n@endsection\n' \
  > "$P_UI/resources/views/orders/index.blade.php"
printf '<?php\n\nclass HomeController\n{\n    public function index() {}\n}\n' \
  > "$P_UI/app/Http/Controllers/HomeController.php"

# PRECONDITION, not a stack assertion: the fixture's file paths are chosen to match
# whatever view_glob the fixture pack declares. If the pack's glob moves, A6/A7 would
# fail for a confusing reason — this turns that into a one-line remediation notice.
FIXTURE_GLOB="$(bash "$PLUGIN_ROOT/scripts/_lib/resolve-framework-pack.sh" \
                 --cwd="$P_UI" --section="UI quality signatures" --quiet 2>/dev/null </dev/null \
               | sed -n 's/^[[:space:]]*view_glob[[:space:]]*:[[:space:]]*//p' | head -1 | tr -d "'\"")"
[ "$FIXTURE_GLOB" = "resources/views/**/*.blade.php" ] \
  && ok "A0: precondition — the fixture pack still declares view_glob '$FIXTURE_GLOB'" \
  || fail "A0: fixture pack view_glob is now '$FIXTURE_GLOB' — update this suite's fixture view/_source paths to match (no builder defect implied)"

build "$WORK/ui.json" "$P_UI" U-002
PR_UI="$(promptof "$P_UI" U-002)"
[ "$RC" = "0" ] && ok "A1: builder exit 0 on the ui_ux fixture" \
                || fail "A1: builder exit $RC (stderr: $(head -2 "$WORK/ui.json.err"))"
[ -s "$PR_UI" ] && ok "A2: dispatch-prompt.md written at the contractual bolts/U-XXX path" \
                || fail "A2: no dispatch-prompt.md at $PR_UI"

$PY - "$WORK/ui.json" <<'PY' && ok "A3: JSON reports the starterkit slice emitted, no halt" || fail "A3: starterkit slice not emitted / halted"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] in ("ok", "ok_with_soft_halts"), d["status"]
assert d["halt"] is None, d["halt"]
assert "starterkit_slice" in d["sections_emitted"], d["sections_emitted"]
PY

# The three verdict markers the shipped gate looks for, asserted on the BYTES.
[ "$(cntE '^[[:space:]]*Design tokens[[:space:]]*:.*#[0-9a-fA-F]{3,8}' "$PR_UI")" -ge 1 ] \
  && ok "A4: 'Design tokens:' line carries REAL token content (a hex colour), not a bare label" \
  || fail "A4: no content-bearing 'Design tokens:' line"
[ "$(cntE '^[[:space:]]*Design system[[:space:]]*:[[:space:]]*[A-Za-z]' "$PR_UI")" -ge 1 ] \
  && ok "A5: 'Design system:' marker line present in the gate-matching spelling" \
  || fail "A5: no marker-compatible 'Design system:' line (the gate regex is ^\\s*Design system\\s*:)"
[ "$(cntE '^[[:space:]]*File:[[:space:]]+resources/views/.*\.blade\.php' "$PR_UI")" -ge 1 ] \
  && ok "A6: a cited code-example File: matches the pack view_glob (view exemplar)" \
  || fail "A6: no view exemplar File: citation"

bash "$VALIDATE" --cwd="$P_UI" --quiet >/dev/null 2>&1 </dev/null
VRC=$?
[ "$VRC" = "0" ] && ok "A7: validate-dispatch-prompt.sh exits 0 over the builder's own output" \
                 || fail "A7: validator exit $VRC (expected 0/PASS)"
VSTATE="$P_UI/.mega-sdd/.dispatch-prompt-state.json"
$PY - "$VSTATE" <<'PY' && ok "A8: validator status is PASS on a real check (not a vacuous SKIP)" || fail "A8: validator did not reach a PASS verdict"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] == "PASS", d.get("status", "") + " :: " + str(d.get("reason", ""))
assert d["prompts_checked"] >= 1, d["prompts_checked"]
assert d["summary"]["ui_prompts_checked"] == 1, d["summary"]
PY
$PY - "$VSTATE" <<'PY' && ok "A9-A11: tokens_not_injected / design_system_not_injected / exemplar_missing all 0" || fail "A9-A11: a verdict finding fired"
import json, sys
s = json.load(open(sys.argv[1]))["summary"]
for k in ("tokens_not_injected", "design_system_not_injected", "exemplar_missing"):
    assert s[k] == 0, "%s=%s" % (k, s[k])
PY
$PY - "$VSTATE" <<'PY' && ok "A12: validator issues[] is empty" || fail "A12: validator reported issues"
import json, sys
iss = json.load(open(sys.argv[1]))["issues"]
assert iss == [], iss
PY

# T1+T2 must be path-free: the absolute vault/project pointers belong to the T3
# reference block ONLY. (Confining them there is what keeps the assembled tiers
# portable; the T3 block is by contract a set of Read-tool pointers.)
$PY - "$PR_UI" "$P_UI" <<'PY' && ok "A13: no absolute project path leaks into T1/T2 (confined to the T3 pointer block)" || fail "A13: absolute project path found before the TIER 3 marker"
import sys
doc = open(sys.argv[1], encoding="utf-8").read()
root = sys.argv[2]
t3 = doc.find("TIER 3")
assert t3 > 0, "no TIER 3 marker"
assert root not in doc[:t3], doc[:t3][max(0, doc[:t3].find(root) - 60):doc[:t3].find(root) + 120]
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== B. acceptance-test provenance NOTE — all four ways =="
# ══════════════════════════════════════════════════════════════════════════════
P_AB="$(mkproj proj-authored)"
printf '{"vault_version":"v1"}\n' > "$P_AB/.mega-sdd/vaults/v1/vault.json"
AB_UNIT="$P_AB/.mega-sdd/vaults/v1/units/U-003.md"

write_ab_unit() {                             # write_ab_unit [<_authored_by value>|__omit__]
  {
    printf -- '---\n'
    printf 'id: U-003\ntitle: Recalculate the settlement ledger\ntask_type: modify\n'
    printf 'module: ledger\nrisk: low\nstatus: pending\n'
    printf 'target_files:\n  - path: app/Services/Settlement.php\n    operation: modify\n'
    printf 'acceptance_test:\n  - command: "run the settlement tests"\n'
    [ "$1" = "__omit__" ] || printf '    _authored_by: %s\n' "$1"
    printf -- '---\n\n## Intent\n\nRecalculate the ledger.\n'
  } > "$AB_UNIT"
}

NOTE_HDR='## Acceptance-test provenance NOTE'
ab_case() {                                   # ab_case <value> <expect: present|absent> <label>
  write_ab_unit "$1"
  build "$WORK/ab.json" "$P_AB" U-003
  local pr n emitted
  pr="$(promptof "$P_AB" U-003)"
  n="$(cntF "$NOTE_HDR" "$pr")"
  emitted="$($PY -c 'import json,sys; print("YES" if "t1.acceptance_test_note" in json.load(open(sys.argv[1]))["sections_emitted"] else "NO")' "$WORK/ab.json")"
  if [ "$2" = "present" ]; then
    { [ "$n" -ge 1 ] && [ "$emitted" = "YES" ]; } \
      && ok "B: $3 => NOTE PRESENT (prompt hits=$n, sections_emitted=$emitted)" \
      || fail "B: $3 => expected NOTE present, got prompt hits=$n sections_emitted=$emitted"
  else
    { [ "$n" = "0" ] && [ "$emitted" = "NO" ]; } \
      && ok "B: $3 => NOTE ABSENT (prompt hits=$n, sections_emitted=$emitted)" \
      || fail "B: $3 => expected NOTE absent, got prompt hits=$n sections_emitted=$emitted"
  fi
}

ab_case "same-pass" present "_authored_by: same-pass"
ab_case "adversarial-review-failed" present "_authored_by: adversarial-review-failed"
# The near-miss. `adversarial-reviewed` is STRONG provenance; it starts to fire the
# moment someone loosens startswith('adversarial-review-failed') to
# startswith('adversarial-review'). That loosening is the bug this pins.
ab_case "adversarial-reviewed" absent "_authored_by: adversarial-reviewed (near-miss of ...-failed)"
ab_case "independent-llm" absent "_authored_by: independent-llm"
# Field entirely MISSING (legacy unit) — absence here is NOT omission: legacy units
# default to same-pass, so the NOTE must FIRE. Getting this inverted is the classic bug.
ab_case "__omit__" present "_authored_by MISSING entirely (legacy unit)"

write_ab_unit "__omit__"
build "$WORK/ab.json" "$P_AB" U-003
[ "$(cntF 'absent — legacy unit, treated as same-pass' "$(promptof "$P_AB" U-003)")" -ge 1 ] \
  && ok "B6: the legacy-unit NOTE names its own provenance honestly (no fabricated value)" \
  || fail "B6: legacy NOTE does not disclose that _authored_by was absent"

# ── REGION PARITY: the acceptance_test block in the BODY, not the frontmatter ──
# validate-unit-spec.sh accepts a BODY `acceptance_test:` block, and the builder
# finds the ENTRIES whole-file. `_authored_by` must be read from THE SAME REGION.
# The retired asymmetry (`_authored_by` scanned in the frontmatter only, entries
# scanned whole-file) made a body-authored STRONG value read as ABSENT — and
# absent FIRES the weak-provenance NOTE. The same prompt then showed the real
# strong value in the verbatim unit body and asserted it was missing, capping
# `confidence` at MEDIUM on exactly the units generate-units spent adversarial
# review on. This case is the inverse of B5: both are "field not in frontmatter",
# and only ONE of them is an absence.
P_ABB="$(mkproj proj-authored-body)"
printf '{"vault_version":"v1"}\n' > "$P_ABB/.mega-sdd/vaults/v1/vault.json"
cat > "$P_ABB/.mega-sdd/vaults/v1/units/U-004.md" <<'MD'
---
id: U-004
title: Recalculate the settlement ledger
task_type: modify
module: ledger
risk: low
status: pending
target_files:
  - path: app/Services/Settlement.php
    operation: modify
---

## Intent

Recalculate the ledger.

## Acceptance

acceptance_test:
  - command: "run the settlement tests"
    _authored_by: adversarial-reviewed (+2 gaps merged)
MD
build "$WORK/abb.json" "$P_ABB" U-004
PR_ABB="$(promptof "$P_ABB" U-004)"
[ "$RC" = "0" ] && ok "B7a: builder exit 0 on a unit whose acceptance_test block lives in the BODY" \
                || fail "B7a: exit $RC"
# NON-VACUITY GUARD: prove the body block was actually PARSED. Without this, B7c
# passes for the wrong reason the day the body block stops being read at all.
[ "$(cntF 'run the settlement tests' "$PR_ABB")" -ge 1 ] \
  && ok "B7b: ...the body block's acceptance command IS parsed and emitted (non-vacuity guard)" \
  || fail "B7b: the body acceptance_test block was not parsed — B7c would be vacuous"
{ [ "$(cntF "$NOTE_HDR" "$PR_ABB")" = "0" ] \
  && [ "$($PY -c 'import json,sys; print("YES" if "t1.acceptance_test_note" in json.load(open(sys.argv[1]))["sections_emitted"] else "NO")' "$WORK/abb.json")" = "NO" ]; } \
  && ok "B7c: ...and a BODY-region STRONG _authored_by gets NO weak-provenance NOTE (region parity)" \
  || fail "B7c: the weak-provenance NOTE fired on a strong body-region _authored_by (frontmatter-vs-whole-file asymmetry is back)"
[ "$(cntF 'absent — legacy unit' "$PR_ABB")" = "0" ] \
  && ok "B7d: ...and the prompt never asserts the value is absent while quoting it verbatim above" \
  || fail "B7d: prompt simultaneously shows the strong value and calls it absent"

# ══════════════════════════════════════════════════════════════════════════════
note "== C. inline_core — the payload the model pastes instead of ~9KB =="
# ══════════════════════════════════════════════════════════════════════════════
$PY - "$WORK/ui.json" <<'PY' && ok "C1-C2: inline_core present, non-empty, <=700 bytes, and inline_core_bytes agrees" || fail "C1-C2: inline_core missing / over cap / byte count disagrees"
import json, sys
d = json.load(open(sys.argv[1]))
core = d["inline_core"]
assert isinstance(core, str) and core.strip(), repr(core)
n = len(core.encode("utf-8"))
assert n <= 700, "inline_core is %d bytes" % n
assert d["inline_core_bytes"] == n, (d["inline_core_bytes"], n)
PY
$PY - "$WORK/ui.json" <<'PY' && ok "C3: inline_core starts at the UNIT line, no trace tag (v7.3.0)" || fail "C3: inline_core head wrong / trace tag survived"
import json, sys
d = json.load(open(sys.argv[1]))
assert "mega-sdd-trace" not in d["inline_core"], d["inline_core"].splitlines()[0]
assert d["inline_core"].splitlines()[0].startswith("UNIT: "), d["inline_core"].splitlines()[0]
assert d["unit"] == "U-002", d["unit"]
PY
$PY - "$WORK/ui.json" <<'PY' && ok "C4: inline_core carries the ABSOLUTE path of the written dispatch-prompt.md" || fail "C4: absolute prompt path missing from inline_core"
import json, os, sys
d = json.load(open(sys.argv[1]))
p = d["prompt_path"]
assert os.path.isabs(p) and os.path.isfile(p), p
assert p in d["inline_core"], d["inline_core"]
PY
$PY - "$WORK/ui.json" <<'PY' && ok "C5: inline_core carries the full target_files whitelist" || fail "C5: whitelist missing from inline_core"
import json, sys
d = json.load(open(sys.argv[1]))
core = d["inline_core"]
assert "TARGET FILES (whitelist):" in core, core
for p in ("resources/views/orders/show.blade.php", "app/Http/Controllers/OrderController.php"):
    assert p in core, "%s not in inline_core" % p
assert d["inline_core_degraded"] == [], d["inline_core_degraded"]
PY

# Documented degradation: a whitelist that would blow the 700-byte budget becomes
# a count + a pointer INTO the on-disk file. Non-ui_ux on purpose (own root anyway).
P_IN="$(mkproj proj-inline)"
printf '{"vault_version":"v1"}\n' > "$P_IN/.mega-sdd/vaults/v1/vault.json"
{
  printf -- '---\nid: U-030\ntitle: Split the settlement batch pipeline into per-tenant workers\n'
  printf 'task_type: modify\nmodule: settlement\nrisk: high\nstatus: pending\ntarget_files:\n'
  i=1
  while [ "$i" -le 12 ]; do
    printf '  - path: app/Modules/Settlement/Workers/PerTenantBatchWorkerPart%02d.php\n    operation: create\n' "$i"
    i=$((i + 1))
  done
  printf -- '---\n\n## Intent\n\nSplit the batch pipeline.\n'
} > "$P_IN/.mega-sdd/vaults/v1/units/U-030.md"

build "$WORK/inline.json" "$P_IN" U-030
[ "$RC" = "0" ] && ok "C6a: builder exit 0 on the 12-target-file unit" || fail "C6a: builder exit $RC"
$PY - "$WORK/inline.json" <<'PY' && ok "C6b: whitelist degraded to count+pointer, still <=700B, abs path never dropped" || fail "C6b: inline_core degradation path wrong"
import json, sys
d = json.load(open(sys.argv[1]))
core = d["inline_core"]
assert "whitelist -> count + pointer" in d["inline_core_degraded"], d["inline_core_degraded"]
assert "12 file(s)" in core, core
assert "PerTenantBatchWorkerPart01.php" not in core, "raw whitelist survived the degradation"
assert "target_files:" in core, "the pointer INTO the file is missing"
assert len(core.encode("utf-8")) <= 700, len(core.encode("utf-8"))
assert core.splitlines()[0].startswith('UNIT: U-030'), core.splitlines()[0]
assert d["prompt_path"] in core, core
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== D. ANTI-FABRICATION — every optional input absent (moat invariant #5) =="
# ══════════════════════════════════════════════════════════════════════════════
# No starterkit-context.yaml, no codebase-map.md, no reuse-index.yaml, no KB, no
# memory, no constitution.md, no design_system, no depends_on / upstream bolts,
# no binding.md / binding_refs. Deliberately NON-ui-bearing so `design_slice` is
# omitted outright (case E below covers "ui-bearing but no design_system").
P_BARE="$(mkproj proj-bare)"
printf '{"vault_version":"v1"}\n' > "$P_BARE/.mega-sdd/vaults/v1/vault.json"
cat > "$P_BARE/.mega-sdd/vaults/v1/units/U-010.md" <<'MD'
---
id: U-010
title: Add invoice total calculator service
task_type: create
module: billing
risk: low
status: pending
target_files:
  - path: app/Services/InvoiceTotal.php
    operation: create
acceptance_test:
  - command: "run the billing unit tests"
    _authored_by: independent-llm
---

## Intent

Compute invoice totals from line items.
MD

build "$WORK/bare.json" "$P_BARE" U-010
PR_BARE="$(promptof "$P_BARE" U-010)"
[ "$RC" = "0" ] && ok "D1: builder exit 0 with EVERY optional input absent" || fail "D1: builder exit $RC"
[ -s "$PR_BARE" ] && ok "D2: a valid prompt is still produced (non-empty file)" || fail "D2: no prompt written"

# The invented-content-free property, asserted on the BYTES: not one marker line
# of an absent section may appear.
D_MISS=""
for m in \
  '### Starterkit context' \
  'Codebase patterns:' \
  '### Reuse index (filtered slice)' \
  '## Historical memory' \
  '## Upstream bolts' \
  '## KB anti-patterns' \
  'DO NOT REPLICATE:' \
  '## Confidence labels per claim' \
  '## Constitution clauses' \
  '## Framework pack rules' \
  '## Design system' \
  '## Reuse candidates' \
  'Design tokens:' \
  'Design system:' \
  'Libs in scope:' \
  '### Reference code example'
do
  [ "$(cntF "$m" "$PR_BARE")" = "0" ] || D_MISS="$D_MISS [$m]"
done
[ -z "$D_MISS" ] && ok "D3: ZERO marker lines for absent sections (16 markers checked)" \
                 || fail "D3: fabricated marker(s) present:$D_MISS"

$PY - "$WORK/bare.json" <<'PY' && ok "D4: all 10 absent sections listed in sections_omitted with a cited, input-naming reason" || fail "D4: an absent section is unlisted or its reason does not cite the missing input"
import json, sys
d = json.load(open(sys.argv[1]))
om = {o["section"]: o["reason"] for o in d["sections_omitted"]}
want = {
    "starterkit_slice":      "no starterkit-context.yaml at",
    "map_patterns":          "no codebase-map.md",
    "reuse_slice":           "reuse-index.yaml absent at",
    "symbol_slice":          "symbol-index.json absent at",
    # The reason now names the FILTER, not just the file: a run that matches
    # neither the unit id nor any target-file basename is DROPPED, and zero
    # matches omits the section (it used to emit every run under a header that
    # claimed relevance). Section L below pins the filter's behavior directly.
    "historical_memory":     "no outcomes.md run passed the relevance filter",
    "depends_on_summaries":  "no depends_on entries",
    "constitution_clauses":  "no constitution.md in",
    "kb_anti_patterns":      "phantom field",
    "confidence_labels":     "no binding_refs",
    "design_slice":          "not ui_bearing",
}
missing = [k for k in want if k not in om]
assert not missing, "unlisted sections: %s (have %s)" % (missing, sorted(om))
bad = [(k, om[k]) for k, v in want.items() if v not in om[k]]
assert not bad, "reason does not cite the missing input: %s" % bad
# framework_pack_rules is env-dependent (pack chain), but if omitted it must still
# carry a non-empty reason — never a silent drop.
if "framework_pack_rules" in om:
    assert om["framework_pack_rules"].strip(), "empty reason for framework_pack_rules"
assert all(o["reason"].strip() for o in d["sections_omitted"]), "an omission carries an empty reason"
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== E. ui-bearing unit, vault with NO design_system (invariant #5, named input) =="
# ══════════════════════════════════════════════════════════════════════════════
P_NODS="$(mkproj proj-nodesign)"
printf '{"vault_version":"v1"}\n' > "$P_NODS/.mega-sdd/vaults/v1/vault.json"
cat > "$P_NODS/.mega-sdd/vaults/v1/units/U-020.md" <<'MD'
---
id: U-020
title: Build the operations dashboard page
task_type: create
module: dash
risk: low
status: pending
target_files:
  - path: src/pages/Dashboard.tsx
    operation: create
---

## Intent

Build the operations dashboard page.
MD

build "$WORK/nods.json" "$P_NODS" U-020
PR_NODS="$(promptof "$P_NODS" U-020)"
[ "$RC" = "0" ] && ok "E1: builder exit 0 for a ui-bearing unit with no vault design_system" || fail "E1: exit $RC"
[ "$(cntE '^[[:space:]]*Design system[[:space:]]*:' "$PR_NODS")" = "0" ] \
  && ok "E2: no 'Design system:' value line — style/palette/typography are NEVER defaulted" \
  || fail "E2: a design system value was invented from thin air"
# The NOTE is the VALUE, not the spec's pseudocode ASSIGNMENT. context-enrichment.md
# §Design slice writes `design_slice.note = "…"`; the note is the quoted sentence.
# Emitting the assignment made the ONE line that tells the subagent to raise an OQ
# read as a leaked internal variable name.
[ "$(cntF 'No design_system in this vault — raise it as an OQ at chain end; do not invent a palette or a type pairing.' "$PR_NODS")" -ge 1 ] \
  && ok "E3: the absence is DISCLOSED as the note VALUE (an instruction, not \`design_slice.note = …\`)" \
  || fail "E3: absence not disclosed as the note value"
[ "$(cntF 'design_slice.note =' "$PR_NODS")" = "0" ] \
  && ok "E3b: ...and the pseudocode assignment expression never reaches the agent-facing prompt" \
  || fail "E3b: the spec's \`design_slice.note = …\` assignment leaked into the prompt"
$PY - "$WORK/nods.json" <<'PY' && ok "E4: design_slice.system recorded in sections_omitted with the 'never defaulted' reason" || fail "E4: design_slice.system omission not recorded"
import json, sys
om = {o["section"]: o["reason"] for o in json.load(open(sys.argv[1]))["sections_omitted"]}
assert "design_slice.system" in om, sorted(om)
assert "no design_system" in om["design_slice.system"], om["design_slice.system"]
assert "defaulted" in om["design_slice.system"], om["design_slice.system"]
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== F. Map §6 fallback + no double-emission =="
# ══════════════════════════════════════════════════════════════════════════════
P_M6="$(mkproj proj-map6)"
mkdir -p "$P_M6/.mega-sdd/codebase"
printf '{"vault_version":"v1"}\n' > "$P_M6/.mega-sdd/vaults/v1/vault.json"
cp "$P_BARE/.mega-sdd/vaults/v1/units/U-010.md" "$P_M6/.mega-sdd/vaults/v1/units/U-010.md"
# Header literal matters: the reader regex needs whitespace after the optional dot.
cat > "$P_M6/.mega-sdd/codebase/codebase-map.md" <<'MD'
---
framework: laravel
---

# Codebase map

## 6. Pattern signatures

- services live in app/Services and are constructor-injected
- calculators end with the Total suffix

## 7. Something else
MD

build "$WORK/map6.json" "$P_M6" U-010
PR_M6="$(promptof "$P_M6" U-010)"
[ "$RC" = "0" ] && ok "F1: builder exit 0 with starterkit ABSENT and codebase-map §6 PRESENT" || fail "F1: exit $RC"
[ "$(cntE '^Codebase patterns:' "$PR_M6")" = "1" ] \
  && ok "F2: the 'Codebase patterns:' fallback line IS emitted, exactly once" \
  || fail "F2: expected exactly 1 'Codebase patterns:' line, got $(cntE '^Codebase patterns:' "$PR_M6")"
$PY - "$WORK/map6.json" "$PR_M6" <<'PY' && ok "F3: map_patterns in sections_emitted; §6 rows carried VERBATIM with their source cited" || fail "F3: map fallback rows not verbatim / source not cited"
import json, sys
d = json.load(open(sys.argv[1]))
assert "map_patterns" in d["sections_emitted"], d["sections_emitted"]
doc = open(sys.argv[2], encoding="utf-8").read()
for row in ("services live in app/Services and are constructor-injected",
            "calculators end with the Total suffix"):
    assert row in doc, row
assert ".mega-sdd/codebase/codebase-map.md §6 Pattern signatures" in doc, "source not cited"
PY

# Both present => starterkit WINS and the Map §6 branch is never evaluated
# (it is gated on `sk_text is None`), so there is no second patterns line.
P_BOTH="$(mkproj proj-both)"
mkdir -p "$P_BOTH/.mega-sdd/codebase"
printf '{"vault_version":"v1"}\n' > "$P_BOTH/.mega-sdd/vaults/v1/vault.json"
cat > "$P_BOTH/.mega-sdd/vaults/v1/units/U-011.md" <<'MD'
---
id: U-011
title: Wire the invoice calculator into the HTTP layer
task_type: modify
module: billing
risk: low
status: pending
starterkit_relevance: [libs]
target_files:
  - path: app/Http/Controllers/InvoiceController.php
    operation: modify
---

## Intent

Wire the calculator in.
MD
cat > "$P_BOTH/.mega-sdd/codebase/starterkit-context.yaml" <<'YAML'
framework_pack: laravel
libs:
  - name: acme/http-kit
    version: "2.1"
    usage_hint:
      - app/Http/Controllers
YAML
cp "$P_M6/.mega-sdd/codebase/codebase-map.md" "$P_BOTH/.mega-sdd/codebase/codebase-map.md"

build "$WORK/both.json" "$P_BOTH" U-011
PR_BOTH="$(promptof "$P_BOTH" U-011)"
[ "$RC" = "0" ] && ok "F4: builder exit 0 with BOTH starterkit and codebase-map §6 present" || fail "F4: exit $RC"
{ [ "$(cntF '### Starterkit context' "$PR_BOTH")" -ge 1 ] && [ "$(cntE '^Codebase patterns:' "$PR_BOTH")" = "0" ]; } \
  && ok "F5: starterkit wins; NO duplicate 'Codebase patterns:' line" \
  || fail "F5: expected starterkit-only, got starterkit=$(cntF '### Starterkit context' "$PR_BOTH") map=$(cntE '^Codebase patterns:' "$PR_BOTH")"
$PY - "$WORK/both.json" <<'PY' && ok "F6: map_patterns is neither emitted nor evaluated when the starterkit is present" || fail "F6: map_patterns leaked into the report"
import json, sys
d = json.load(open(sys.argv[1]))
assert "starterkit_slice" in d["sections_emitted"], d["sections_emitted"]
assert "map_patterns" not in d["sections_emitted"], d["sections_emitted"]
assert "map_patterns" not in {o["section"] for o in d["sections_omitted"]}, d["sections_omitted"]
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== G. the T1 UNCONDITIONAL reuse-index rail =="
# ══════════════════════════════════════════════════════════════════════════════
RAIL='Reuse index: .mega-sdd/codebase/reuse-index.yaml'
[ ! -f "$P_BARE/.mega-sdd/codebase/reuse-index.yaml" ] \
  && ok "G1: precondition — the bare fixture has no reuse-index.yaml and no reuse_candidates" \
  || fail "G1: fixture is not bare"
[ "$(cntF "$RAIL" "$PR_BARE")" = "1" ] \
  && ok "G2: the reuse-index path line SHIPS anyway (Iron Rule 4 rail is unconditional)" \
  || fail "G2: rail missing with zero candidates + no index on disk"
[ "$(cntF '## Reuse candidates' "$PR_BARE")" = "0" ] \
  && ok "G3: ...while the 'Reuse candidates' HINT block stays absent (nothing invented)" \
  || fail "G3: a reuse-candidates hint block was fabricated"
[ "$(cntF "$RAIL" "$PR_UI")" = "1" ] \
  && ok "G4: the same rail ships on the enriched ui_ux prompt (unconditional means always)" \
  || fail "G4: rail missing on the enriched prompt"

# ══════════════════════════════════════════════════════════════════════════════
note "== H. idempotence + determinism (the artifact must stay diffable) =="
# ══════════════════════════════════════════════════════════════════════════════
cp "$PR_UI" "$WORK/run1.md"
cp "$WORK/ui.json" "$WORK/run1.json"
build "$WORK/ui2.json" "$P_UI" U-002
[ "$RC" = "0" ] && ok "H1: second consecutive run on the unchanged fixture exits 0" || fail "H1: exit $RC"
cmp -s "$WORK/run1.md" "$PR_UI" \
  && ok "H2: dispatch-prompt.md is BYTE-IDENTICAL across two runs" \
  || fail "H2: prompt differs between runs — $(cmp "$WORK/run1.md" "$PR_UI" 2>&1 | head -1)"
cmp -s "$WORK/run1.json" "$WORK/ui2.json" \
  && ok "H3: the stdout JSON report is byte-identical too (no clock, no dict-order drift)" \
  || fail "H3: JSON report differs between runs"
[ "$(cntE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}' "$PR_UI")" = "0" ] \
  && ok "H4: no ISO-8601 timestamp anywhere in the emitted prompt" \
  || fail "H4: a timestamp leaked into the prompt"
# A third run from a SUB-cwd must resolve UP to the same project root and stay
# identical (resolve_project_root), not mint a nested .mega-sdd/ under the subdir.
# NOTE: --vault stays the REAL vault; only --cwd is the subdir. Pointing --vault at
# the subdir too would exit 2 and make this assertion pass vacuously.
# --explain matches build()'s flags exactly: H6 byte-compares this JSON against a
# build() run, so a flag mismatch would fail for a reason that has nothing to do
# with the project-root resolution this pins.
bash "$BUILD" --cwd="$P_UI/app/Http/Controllers" --vault="$P_UI/.mega-sdd/vaults/v1" \
     --unit=U-002 --plugin-root="$PLUGIN_ROOT" --explain >"$WORK/ui3.json" 2>"$WORK/ui3.err" </dev/null
RC=$?
[ "$RC" = "0" ] && ok "H5: a build launched from a SUB-cwd still exits 0" \
                || fail "H5: sub-cwd build exit $RC (stderr: $(head -1 "$WORK/ui3.err"))"
{ cmp -s "$WORK/run1.md" "$PR_UI" && cmp -s "$WORK/run1.json" "$WORK/ui3.json"; } \
  && ok "H6: ...and produces the identical prompt AND report (project root resolved up)" \
  || fail "H6: sub-cwd run diverged from the project-root run"
[ ! -d "$P_UI/app/Http/Controllers/.mega-sdd" ] \
  && ok "H7: ...with no nested .mega-sdd/ minted under the sub-cwd" \
  || fail "H7: a nested .mega-sdd/ was minted under the sub-cwd"

# ══════════════════════════════════════════════════════════════════════════════
note "== I. exit codes, soft halts, and the --quiet contract =="
# ══════════════════════════════════════════════════════════════════════════════
build "$WORK/e1.json" "$P_BARE" U-999
[ "$RC" = "2" ] && ok "I1: missing unit (U-999) => exit 2" || fail "I1: expected exit 2, got $RC"
[ ! -e "$P_BARE/.mega-sdd/vaults/v1/bolts/U-999" ] \
  && ok "I2: ...and nothing is written for a unit that does not exist" \
  || fail "I2: a bolt dir was created for a nonexistent unit"

if [ "$(id -u 2>/dev/null || echo 1)" = "0" ]; then
  note "  (skipping the unreadable-unit assertion: running as root, chmod 000 is not enforced)"
else
  P_UR="$(mkproj proj-unreadable)"
  printf '{"vault_version":"v1"}\n' > "$P_UR/.mega-sdd/vaults/v1/vault.json"
  cp "$P_BARE/.mega-sdd/vaults/v1/units/U-010.md" "$P_UR/.mega-sdd/vaults/v1/units/U-010.md"
  chmod 000 "$P_UR/.mega-sdd/vaults/v1/units/U-010.md" 2>/dev/null
  # Git Bash on Windows does not enforce POSIX mode bits — assert only if the
  # chmod actually took, so this never reports a false FAIL on the team's laptops.
  if head -c 1 "$P_UR/.mega-sdd/vaults/v1/units/U-010.md" >/dev/null 2>&1; then
    note "  (skipping the unreadable-unit assertion: this filesystem does not enforce chmod 000)"
  else
    build "$WORK/e2.json" "$P_UR" U-010
    [ "$RC" = "2" ] && ok "I3: unreadable unit file => exit 2 (fails CLOSED, never an empty prompt)" \
                    || fail "I3: expected exit 2, got $RC"
  fi
  chmod 644 "$P_UR/.mega-sdd/vaults/v1/units/U-010.md" 2>/dev/null
fi

bash "$BUILD" --cwd="$P_BARE" --vault="$P_BARE/.mega-sdd/vaults/v1" --unit=U-010 --bogus \
  >/dev/null 2>&1 </dev/null
[ "$?" = "2" ] && ok "I4: unknown argument => exit 2 (strict parse)" || fail "I4: strict arg parse missing"
bash "$BUILD" --cwd="$P_BARE" --unit=U-010 --plugin-root="$PLUGIN_ROOT" >/dev/null 2>&1 </dev/null
[ "$?" = "2" ] && ok "I5: missing --vault => exit 2" || fail "I5: expected exit 2 for missing --vault"

# Corrupt starterkit: a `patterns:` block PRESENT but not a mapping. This is the
# FAIL-LOUD case (validate-starterkit-conformance S5R) — but it must be recorded as
# a SOFT halt and the chain must continue, not die.
P_CR="$(mkproj proj-corrupt)"
mkdir -p "$P_CR/.mega-sdd/codebase"
printf '{"vault_version":"v1"}\n' > "$P_CR/.mega-sdd/vaults/v1/vault.json"
cp "$P_BARE/.mega-sdd/vaults/v1/units/U-010.md" "$P_CR/.mega-sdd/vaults/v1/units/U-010.md"
printf 'framework_pack: laravel\npatterns: "oops-this-is-a-scalar"\n' \
  > "$P_CR/.mega-sdd/codebase/starterkit-context.yaml"
build "$WORK/corrupt.json" "$P_CR" U-010
[ "$RC" = "0" ] && ok "I6: corrupt starterkit-context.yaml => exit 0 (NOT a hard failure)" || fail "I6: exit $RC"
[ -s "$(promptof "$P_CR" U-010)" ] && ok "I7: ...the prompt is still written" || fail "I7: no prompt written"
$PY - "$WORK/corrupt.json" <<'PY' && ok "I8: ...and the corruption is RECORDED as soft halt deep_scan_cache_corrupt" || fail "I8: soft halt not recorded"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] == "ok_with_soft_halts", d["status"]
assert d["halt"] is None, d["halt"]
halts = [h["halt"] for h in d["soft_halts"]]
assert "deep_scan_cache_corrupt" in halts, halts
assert all(h.get("detail", "").strip() for h in d["soft_halts"]), d["soft_halts"]
PY

# Wholly unparseable starterkit (parses to nothing) — same soft-halt lane.
printf '%s\n' '!!! not: [yaml' '@@@@' > "$P_CR/.mega-sdd/codebase/starterkit-context.yaml"
build "$WORK/corrupt2.json" "$P_CR" U-010
$PY - "$WORK/corrupt2.json" <<'PY' && ok "I9: an unparseable starterkit is a soft halt too — never a chain-killer" || fail "I9: unparseable starterkit not handled as a soft halt"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] in ("ok", "ok_with_soft_halts"), d["status"]
assert d["halt"] is None, d["halt"]
PY
[ "$RC" = "0" ] && ok "I10: ...exit 0" || fail "I10: exit $RC"

# --quiet suppresses the ONLY channel carrying inline_core. Pinned so the
# execute-bolts wiring can never "tidy up" by adding it.
bash "$BUILD" --cwd="$P_BARE" --vault="$P_BARE/.mega-sdd/vaults/v1" --unit=U-010 \
  --plugin-root="$PLUGIN_ROOT" --quiet >"$WORK/quiet.out" 2>/dev/null </dev/null
QRC=$?
{ [ "$QRC" = "0" ] && [ ! -s "$WORK/quiet.out" ] && [ -s "$PR_BARE" ]; } \
  && ok "I11: --quiet emits NOTHING on stdout (inline_core rides that channel — execute-bolts must not pass it)" \
  || fail "I11: --quiet contract broken (exit=$QRC stdout bytes=$(wc -c <"$WORK/quiet.out" | tr -d ' '))"

# ══════════════════════════════════════════════════════════════════════════════
note "== J. the DEFAULT plugin-root path (spawn 1) still works =="
# ══════════════════════════════════════════════════════════════════════════════
# Every build above pins --plugin-root for hermeticity, which SKIPS the
# resolve-plugin-root.sh spawn entirely. Exercise the default branch once so it
# cannot rot unnoticed. Byte parity is deliberately NOT asserted: without the
# flag the pack BODIES come from whatever plugin root the resolver elects (on a
# developer machine, the installed marketplace cache), which is a different tree
# from the pack CHAIN's. Exit code + a written prompt + inline_core is the
# contract that must hold on either root.
P_DEF="$(mkproj proj-defaultroot)"
printf '{"vault_version":"v1"}\n' > "$P_DEF/.mega-sdd/vaults/v1/vault.json"
cp "$P_BARE/.mega-sdd/vaults/v1/units/U-010.md" "$P_DEF/.mega-sdd/vaults/v1/units/U-010.md"
bash "$BUILD" --cwd="$P_DEF" --vault="$P_DEF/.mega-sdd/vaults/v1" --unit=U-010 \
  >"$WORK/def.json" 2>"$WORK/def.err" </dev/null
DRC=$?
[ "$DRC" = "0" ] && ok "J1: a build with NO --plugin-root exits 0 (resolve-plugin-root.sh branch)" \
                 || fail "J1: default-plugin-root build exit $DRC (stderr: $(head -1 "$WORK/def.err"))"
[ -s "$(promptof "$P_DEF" U-010)" ] && ok "J2: ...and still writes the dispatch prompt" \
                                    || fail "J2: no prompt written on the default-plugin-root path"
$PY - "$WORK/def.json" <<'PY' && ok "J3: ...and still emits a capped inline_core (UNIT-first, v7.3.0)" || fail "J3: inline_core broken on the default-plugin-root path"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["inline_core"].splitlines()[0].startswith("UNIT: U-010"), d["inline_core"]
assert "mega-sdd-trace" not in d["inline_core"]
assert len(d["inline_core"].encode("utf-8")) <= 700
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== K. the DEFAULT stdout shape — the channel the controller actually reads =="
# ══════════════════════════════════════════════════════════════════════════════
# `--quiet` is FORBIDDEN for execute-bolts (stdout is the sole carrier of
# inline_core), so this JSON lands as a tool result on EVERY bolt of every run.
# The forensic keys moved OFF the default channel into the prompt file's own
# `PROVENANCE — omissions` appendix, and the design slice's 9.6 KB of TEXT was
# replaced by a ~70-byte path to a lens-input file (section T). Every OTHER
# sub-test in this suite passes --explain, so WITHOUT this section the slimming
# has zero coverage and regresses silently the first time a key is "restored" for
# convenience. --explain ADDS; --quiet REMOVES EVERYTHING; they are not two
# settings of one verbosity dial.
FORENSIC_KEYS='caps sections_emitted sections_omitted inline_core_bytes inline_core_degraded pack_chain pack_resolver_exit interpreter'
build_default "$WORK/slim.json" "$P_UI" U-002
[ "$RC" = "0" ] && ok "K1: the SHIPPED invocation (no --explain) exits 0" || fail "K1: exit $RC"
$PY - "$WORK/slim.json" "$FORENSIC_KEYS" <<'PY' && ok "K2: NOT ONE of the 8 forensic keys rides the default channel" || fail "K2: a forensic key leaked back onto default stdout"
import json, sys
d = json.load(open(sys.argv[1]))
leaked = [k for k in sys.argv[2].split() if k in d]
assert not leaked, "forensic key(s) on default stdout: %s" % leaked
PY
$PY - "$WORK/slim.json" <<'PY' && ok "K3: ...while every controller-consumed key IS present and inline_core is non-empty" || fail "K3: a controller-consumed key is missing from default stdout"
import json, sys
d = json.load(open(sys.argv[1]))
for k in ("status", "unit", "prompt_path", "t1_bytes", "t2_bytes", "total_bytes",
          "file_bytes", "truncations", "soft_halts", "warnings", "halt", "inline_core"):
    assert k in d, "missing controller key: %s" % k
assert isinstance(d["inline_core"], str) and d["inline_core"].strip(), repr(d["inline_core"])
PY
# THE SELF-REPORTING RAIL. `total_bytes` is T1+T2 — the BUDGETED tiers the
# cascade truncates and the halt reasons about — and it is NOT the size of the
# file. The prompt's own `### T2 budget tracker` used to report only that number
# to a subagent that agents/bolt-implementer.md Rule 0 had just ordered to read
# the whole file and treat all of it as BINDING: a 24–59 % understatement of the
# artifact, measured. Round 3 added `file_bytes` and an in-prompt `file_total`,
# rendered through a fixed-width `%-8d` two-pass fixed point. All three numbers
# must be THE SAME NUMBER; if the fixed point ever stops converging, this is
# where it surfaces.
$PY - "$WORK/slim.json" <<'PY' && ok "K8: file_bytes == the tracker's own file_total == the bytes on disk (the prompt never understates the file it sits in)" || fail "K8: the three byte figures disagree — the subagent is told a size the artifact does not have"
import json, os, re, sys
d = json.load(open(sys.argv[1]))
disk = os.path.getsize(d["prompt_path"])
assert d["file_bytes"] == disk, ("file_bytes=%s, on disk=%s" % (d["file_bytes"], disk))
doc = open(d["prompt_path"], encoding="utf-8").read()
m = re.search(r"(?m)^file_total:\s*(\d+)\s", doc)
assert m, "the in-prompt tracker carries no `file_total:` line"
assert int(m.group(1)) == disk, ("tracker file_total=%s, on disk=%s" % (m.group(1), disk))
# ...and `total_bytes` keeps its own distinct meaning — it is the BUDGET figure,
# never renamed into the file size. On any real prompt the banners, the tracker,
# the Tier-3 list and the provenance appendix sit outside it.
assert d["total_bytes"] < disk, (
    "total_bytes (%s) is not smaller than the file (%s) — the two numbers were "
    "conflated" % (d["total_bytes"], disk))
PY
cp "$PR_UI" "$WORK/slim-prompt.md"
build "$WORK/explain.json" "$P_UI" U-002
$PY - "$WORK/explain.json" "$FORENSIC_KEYS" <<'PY' && ok "K4: --explain ADDS all 8 back (nothing was deleted, only the channel changed)" || fail "K4: --explain does not restore the forensic keys"
import json, sys
d = json.load(open(sys.argv[1]))
missing = [k for k in sys.argv[2].split() if k not in d]
assert not missing, "--explain did not restore: %s" % missing
assert d["sections_omitted"], "sections_omitted is empty under --explain"
PY
cmp -s "$WORK/slim-prompt.md" "$PR_UI" \
  && ok "K5: ...and the on-disk ARTIFACT is byte-identical either way (flags touch stdout only)" \
  || fail "K5: --explain changed the emitted dispatch-prompt.md"
[ "$(cntF 'PROVENANCE — omissions' "$PR_UI")" -ge 1 ] \
  && ok "K6: the omission audit trail still exists — in the prompt file's own provenance appendix" \
  || fail "K6: sections_omitted left default stdout with no on-disk home (forensics deleted, not moved)"
bash "$BUILD" --cwd="$P_BARE" --vault="$P_BARE/.mega-sdd/vaults/v1" --unit=U-010 \
  --plugin-root="$PLUGIN_ROOT" --quiet --explain >/dev/null 2>&1 </dev/null
[ "$?" = "2" ] && ok "K7: --quiet --explain is a USAGE ERROR (exit 2), not a merged verbosity dial" \
                || fail "K7: --quiet --explain was accepted"

# ══════════════════════════════════════════════════════════════════════════════
note "== L. historical memory — the relevance filter is APPLIED, not decorated =="
# ══════════════════════════════════════════════════════════════════════════════
# The header says "last 5 RELEVANT patterns". That word is a CLAIM. The builder
# used to emit EVERY run in outcomes.md and use the needle test only to decorate
# the provenance string (`matched X` vs `recency-only`), so a zero-relevance run
# consumed the priority-2 budget a section with a real join would have used.
P_MEM="$(mkproj proj-memory)"
mkdir -p "$P_MEM/.mega-sdd/memory"
printf '{"vault_version":"v1"}\n' > "$P_MEM/.mega-sdd/vaults/v1/vault.json"
cp "$P_BARE/.mega-sdd/vaults/v1/units/U-010.md" "$P_MEM/.mega-sdd/vaults/v1/units/U-010.md"
cat > "$P_MEM/.mega-sdd/memory/outcomes.md" <<'MD'
## Run #1

- totally unrelated alpha work on the shipping label printer

## Run #2

- rounded the tax line inside InvoiceTotal.php and re-ran the suite

## Run #3

- totally unrelated gamma work bumping a lockfile
MD
build "$WORK/mem.json" "$P_MEM" U-010
PR_MEM="$(promptof "$P_MEM" U-010)"
[ "$RC" = "0" ] && ok "L1: builder exit 0 with an outcomes.md carrying 3 runs, 1 relevant" || fail "L1: exit $RC"
{ [ "$(cntF '## Historical memory' "$PR_MEM")" -ge 1 ] \
  && [ "$(cntF 'InvoiceTotal.php' "$PR_MEM")" -ge 1 ]; } \
  && ok "L2: the RELEVANT run (target-file basename overlap) IS carried, with its match named" \
  || fail "L2: the relevant outcomes.md run did not reach the prompt"
{ [ "$(cntF 'totally unrelated alpha' "$PR_MEM")" = "0" ] \
  && [ "$(cntF 'totally unrelated gamma' "$PR_MEM")" = "0" ]; } \
  && ok "L3: ...and the 2 zero-relevance runs are DROPPED, not relabelled 'recency-only'" \
  || fail "L3: a run matching neither the unit id nor any target basename shipped under a 'relevant' header"
$PY - "$WORK/mem.json" <<'PY' && ok "L4: ...with the drop RECORDED (count + the filter that dropped them)" || fail "L4: the dropped runs are not recorded in sections_omitted"
import json, sys
om = {o["section"]: o["reason"] for o in json.load(open(sys.argv[1]))["sections_omitted"]}
k = "historical_memory.unmatched_runs"
assert k in om, sorted(om)
assert "2 run(s)" in om[k], om[k]
assert "relevance filter" in om[k], om[k]
PY
# Zero matches OMITS the section — an absent input, never an unfiltered dump.
printf '## Run #1\n\n- totally unrelated alpha\n\n## Run #2\n\n- totally unrelated beta\n' \
  > "$P_MEM/.mega-sdd/memory/outcomes.md"
build "$WORK/mem0.json" "$P_MEM" U-010
{ [ "$(cntF '## Historical memory' "$(promptof "$P_MEM" U-010)")" = "0" ] \
  && [ "$(cntF 'totally unrelated' "$(promptof "$P_MEM" U-010)")" = "0" ]; } \
  && ok "L5: an outcomes.md where NO run passes the filter omits the section entirely" \
  || fail "L5: a zero-relevance outcomes.md still produced a 'Historical memory' section"

# ══════════════════════════════════════════════════════════════════════════════
note "== M. halted upstream — [<status>] is UNCONDITIONAL, and absence is not zero =="
# ══════════════════════════════════════════════════════════════════════════════
# A bolt that HALTED is PRECISELY the bolt that never wrote a `bolt_self_report:`
# block. A derivation that returned early when the block was missing therefore
# dropped `[<status>]` exactly for the upstreams that most need it, and the
# downstream implementer read a bare committed line byte-identical in shape to a
# clean success — then built on a halted dependency.
P_UP="$(mkproj proj-upstream)"
mkdir -p "$P_UP/.mega-sdd/vaults/v1/bolts/U-000"
printf '{"vault_version":"v1"}\n' > "$P_UP/.mega-sdd/vaults/v1/vault.json"
cat > "$P_UP/.mega-sdd/vaults/v1/units/U-000.md" <<'MD'
---
id: U-000
title: Upstream that halted
task_type: create
module: ledger
risk: high
status: halted
target_files:
  - path: app/Services/Ledger.php
    operation: create
---

## Intent

Upstream.
MD
# The normal shape of a halted bolt's report: frontmatter + a Summary, NO
# `bolt_self_report:` block, and NO `retries:` key.
cat > "$P_UP/.mega-sdd/vaults/v1/bolts/U-000/bolt-report.md" <<'MD'
---
unit: U-000
status: halted_postflight
attempted_at: 2026-07-30T09:00:00Z
commits: [abc1234]
---

## Summary

Halted at post-flight before writing a self-report.
MD
cat > "$P_UP/.mega-sdd/vaults/v1/units/U-005.md" <<'MD'
---
id: U-005
title: Build on the ledger upstream
task_type: modify
module: ledger
risk: medium
status: pending
depends_on:
  - U-000
target_files:
  - path: app/Services/Settlement.php
    operation: modify
---

## Intent

Build on it.
MD
build "$WORK/up.json" "$P_UP" U-005
PR_UP="$(promptof "$P_UP" U-005)"
[ "$RC" = "0" ] && ok "M1: builder exit 0 with a halted upstream in depends_on" || fail "M1: exit $RC"
[ "$(cntF '[halted_postflight]' "$PR_UP")" -ge 1 ] \
  && ok "M2: the [<status>] marker SHIPS for an upstream with no bolt_self_report block" \
  || fail "M2: [halted_postflight] absent — a halted upstream reads as a clean success"
$PY - "$PR_UP" <<'PY' && ok "M3: ...on the line DIRECTLY under the committed line (no bare committed line)" || fail "M3: the committed line is not immediately followed by its status marker"
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
idx = [i for i, l in enumerate(lines) if l.startswith('- U-000 "Upstream that halted"')]
assert idx, "no upstream summary line for U-000"
i = idx[0]
assert "committed at abc1234" in lines[i], lines[i]
nxt = lines[i + 1] if i + 1 < len(lines) else ""
assert nxt.strip().startswith("└─ [halted_postflight]"), (
    "next line is %r — a halted upstream must never render as a bare committed line" % nxt)
PY
[ "$(cntF 'no bolt_self_report block in that report' "$PR_UP")" -ge 1 ] \
  && ok "M4: ...and the MISSING self-report is stated, not papered over" \
  || fail "M4: the absent bolt_self_report block is silently swallowed"
# ABSENCE IS NOT ZERO. The report never said "zero retries"; two chars away on
# the same line `confidence or 'n/a'` already did the right thing.
[ "$(cntF '0 retries' "$PR_UP")" = "0" ] \
  && ok "M5: an upstream report with NO retries: key never renders '0 retries'" \
  || fail "M5: absence was rendered as the value 0 on a line cited to a real file"
[ "$(cntF 'retries n/a' "$PR_UP")" -ge 1 ] \
  && ok "M6: ...it renders 'retries n/a', matching how the same line treats confidence" \
  || fail "M6: no 'retries n/a' rendering for an absent retries key"

# `_upstream_line()` has TWO renderings — self-report-with-a-certain-decision, and
# the confidence/retries fallback M2-M6 exercise. F3 only named the second, but
# "UNCONDITIONAL" has to mean both, so the first branch is pinned here too. (Note
# the certain-decision branch carries NEITHER confidence NOR retries by design —
# it carries the decision — so M5/M6 are branch-scoped and this is not.)
cat > "$P_UP/.mega-sdd/vaults/v1/bolts/U-000/bolt-report.md" <<'MD'
---
unit: U-000
status: halted_postflight
attempted_at: 2026-07-30T09:00:00Z
commits: [abc1234]
---

## Summary

Halted, but a self-report was written first.

bolt_self_report:
  confidence: 0.4
  certain_decisions:
    - Used the existing ledger writer rather than a new one
MD
build "$WORK/up2.json" "$P_UP" U-005
$PY - "$(promptof "$P_UP" U-005)" <<'PY' && ok "M7: the [<status>] marker is unconditional on the OTHER branch too (self-report present)" || fail "M7: the status marker is conditional on which upstream rendering fires"
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
idx = [i for i, l in enumerate(lines) if l.startswith('- U-000 ')]
assert idx, "no upstream summary line"
nxt = lines[idx[0] + 1]
assert nxt.strip().startswith("└─ [halted_postflight]"), nxt
assert "Used the existing ledger writer" in nxt, nxt
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== N. the absent-value rule — a sub-key of a PRESENT dict is still absent =="
# ══════════════════════════════════════════════════════════════════════════════
# `design_system: {style: modern}` is LEGAL — nothing requires all four keys.
# `Design system: style=modern · palette=None` is not a degraded line, it is a
# placeholder that SATISFIES validate-ui-quality.sh's `design_system_not_injected`
# check while handing the implementer `None` as its authoritative palette, whose
# only two continuations are invent-a-palette (fabrication) or ship untokened.
#
# The scan is on the VALUE-POSITION SHAPES a `%s`-of-None produces, deliberately
# NOT on the bare token `None`: style-principles.md itself contains the English
# word, and a whole-file token ban would break on unrelated content and read as a
# builder defect. The shapes ARE the defect class.
# The scan runs in python, not `grep -E`: BSD grep (macOS) rejects `\b`, so an ERE
# spelling would silently return "no matches" on half the team's machines — a rail
# that passes because it never ran is worse than no rail.
NONE_SCAN_PY="$WORK/none_scan.py"
cat > "$NONE_SCAN_PY" <<'PY'
import re, sys
PAT = re.compile(r"[=@/\[:]None\b"           # key=None | lib@None | style/None | {k:None}
                 r"|\bNone\s*[,;\]\)]"       # None, | None; | None] | None)
                 r"|:[ \t]+None[ \t]*$")     # "    naming:    None"
hits = [l.rstrip("\n") for l in open(sys.argv[1], encoding="utf-8") if PAT.search(l)]
sys.stdout.write(" ||| ".join(h.strip()[:120] for h in hits[:3]))
PY
none_scan() {                                 # none_scan <label> <prompt>
  local out
  out="$($PY "$NONE_SCAN_PY" "$2" 2>&1)"
  [ -z "$out" ] && ok "$1" || fail "$1 — value-position None line(s): $out"
}

# ── N-greenfield ──────────────────────────────────────────────────────────────
P_NG="$(mkproj proj-none-greenfield)"
printf '{"vault_version":"v1","design_system":{"style":"modern"}}\n' \
  > "$P_NG/.mega-sdd/vaults/v1/vault.json"
cat > "$P_NG/.mega-sdd/vaults/v1/units/U-040.md" <<'MD'
---
id: U-040
title: Build the operations dashboard page
task_type: create
module: dash
risk: low
status: pending
target_files:
  - path: src/pages/Dashboard.tsx
    operation: create
---

## Intent

Build the operations dashboard page.
MD
build "$WORK/ng.json" "$P_NG" U-040
PR_NG="$(promptof "$P_NG" U-040)"
[ "$RC" = "0" ] && ok "N1: builder exit 0 on a design_system carrying ONLY style (greenfield)" || fail "N1: exit $RC"
none_scan "N2: greenfield prompt carries ZERO value-position \`None\` renderings" "$PR_NG"
[ "$(cntF 'palette=None' "$PR_NG")" = "0" ] \
  && ok "N3: ...specifically no \`palette=None\` (the reproduced F1 line)" \
  || fail "N3: palette=None is back in the emitted prompt"
[ "$(cntF '=None' "$PR_NG")" = "0" ] \
  && ok "N4: ...and no \`=None\` anywhere" || fail "N4: an =None pair survived"
$PY - "$PR_NG" <<'PY' && ok "N5: the Design system: line ships style=modern and DROPS the 3 absent pairs" || fail "N5: the composed Design system: line is wrong"
import sys
ln = [l for l in open(sys.argv[1], encoding="utf-8").read().splitlines()
      if l.strip().startswith("Design system:")]
assert len(ln) == 1, ln
l = ln[0]
assert "style=modern" in l, l
for k in ("palette", "typography", "a11y"):
    assert k not in l, "absent key %r rendered on the line: %r" % (k, l)
assert "source: vault.json design_system" in l, l
PY
$PY - "$WORK/ng.json" <<'PY' && ok "N6: ...and the 3 dropped keys are RECORDED (dropped, never silently gone)" || fail "N6: the dropped keys are not in sections_omitted"
import json, sys
om = {o["section"]: o["reason"] for o in json.load(open(sys.argv[1]))["sections_omitted"]}
k = "design_slice.system.absent_keys"
assert k in om, sorted(om)
for want in ("palette", "typography", "a11y"):
    assert want in om[k], (want, om[k])
assert "never rendered as None" in om[k], om[k]
PY

# ── N-starterkit (the path with 6 of the 9 sites) ─────────────────────────────
P_NS="$(mkproj proj-none-starterkit)"
mkdir -p "$P_NS/.mega-sdd/codebase" "$P_NS/resources/views/orders"
printf '{"vault_version":"v1","design_system":{"style":"modern"}}\n' \
  > "$P_NS/.mega-sdd/vaults/v1/vault.json"
# ui_ux with NO notification_lib, design_tokens with colors only, a lib with NO
# version, a pattern with location only, auth with lib only.
cat > "$P_NS/.mega-sdd/codebase/starterkit-context.yaml" <<'YAML'
framework_pack: laravel
auth:
  lib: acme/breeze
ui_ux:
  layout_extends: layouts.app
  design_tokens:
    colors:
      primary: "#2563EB"
libs:
  - name: acme/alpine
    usage_hint:
      - resources/views
patterns:
  view:
    location: resources/views
YAML
cat > "$P_NS/.mega-sdd/vaults/v1/units/U-041.md" <<'MD'
---
id: U-041
title: Render the order detail view
task_type: create
module: orders
risk: low
status: pending
starterkit_relevance: [ui_ux, libs, auth]
target_files:
  - path: resources/views/orders/show.blade.php
    operation: create
---

## Intent

Render it.
MD
build "$WORK/ns.json" "$P_NS" U-041
PR_NS="$(promptof "$P_NS" U-041)"
[ "$RC" = "0" ] && ok "N7: builder exit 0 on the starterkit path with 5 absent sub-keys" || fail "N7: exit $RC"
none_scan "N8: starterkit prompt carries ZERO value-position \`None\` renderings" "$PR_NS"
{ [ "$(cntF 'acme/alpine' "$PR_NS")" -ge 1 ] && [ "$(cntF 'acme/alpine@' "$PR_NS")" = "0" ]; } \
  && ok "N9: a lib with no version ships as \`name\`, never \`name@None\`" \
  || fail "N9: the @<version> suffix was rendered for an unrecorded version"
$PY - "$PR_NS" <<'PY' && ok "N10: the starterkit Design system: line drops absent pieces, keeps the shape" || fail "N10: the piecewise starterkit Design system: line is wrong"
import sys
ln = [l for l in open(sys.argv[1], encoding="utf-8").read().splitlines()
      if l.strip().startswith("Design system:")]
assert len(ln) == 1, ln
l = ln[0]
assert "modern" in l, l
assert "/None" not in l and "type None" not in l and "a11y None" not in l and "source None" not in l, l
PY
# THE SUBTLE HALF OF C1: a trailing clause that talks ABOUT a value must not
# outlive that value. `source` is absent here, so the line cannot also assert
# what happens "when source=scanned-template".
[ "$(cntF 'When source=scanned-template' "$PR_NS")" = "0" ] \
  && ok "N11: ...and the 'When source=scanned-template' clause is NOT emitted when source is absent" \
  || fail "N11: a trailing clause asserts a source= value the same line never carries"
[ "$(cntE '^[[:space:]]*(naming|extension)[[:space:]]*:' "$PR_NS")" = "0" ] \
  && ok "N12: §patterns emits only the fields the source recorded (no invented naming/extension)" \
  || fail "N12: an absent §patterns field was rendered"
[ "$(cntF 'notification=' "$PR_NS")" = "0" ] \
  && ok "N13: the UI/UX: line drops \`notification\` rather than rendering it empty" \
  || fail "N13: notification was rendered despite being absent"

# ══════════════════════════════════════════════════════════════════════════════
note "== O. style-slice honesty — the labels must be style-principles.md's OWN columns =="
# ══════════════════════════════════════════════════════════════════════════════
# style-principles.md's header is `| Style | Best For | Avoid For | CSS Keywords |`.
# There is NO traits column and NO anti-patterns column. Relabelling the
# PRODUCT-SUITABILITY lists as `Style traits:` / `Style anti-patterns:` told the
# implementer that a style's anti-patterns are "creative portfolios,
# entertainment, playful brands" — product categories, not design defects — while
# citing the file by section. The source was real and the assertion invented, and
# review-panel.md points the design lens at this SAME slice, so implementer and
# reviewer would share a contract style-principles.md does not state.
SP_MD="$PLUGIN_ROOT/references/design-intelligence/style-principles.md"
P_ST="$(mkproj proj-style)"
printf '%s\n' '{"vault_version":"v1","design_system":{"style":"minimalism","palette":"trust-blue","typography":"Inter","a11y_level":"AA"}}' \
  > "$P_ST/.mega-sdd/vaults/v1/vault.json"
cp "$P_NG/.mega-sdd/vaults/v1/units/U-040.md" "$P_ST/.mega-sdd/vaults/v1/units/U-040.md"
build "$WORK/st.json" "$P_ST" U-040
PR_ST="$(promptof "$P_ST" U-040)"
[ "$RC" = "0" ] && ok "O1: builder exit 0 on a greenfield UI unit with a matching style token" || fail "O1: exit $RC"
$PY - "$SP_MD" <<'PY' && ok "O2: precondition — style-principles.md still declares Style | Best For | Avoid For | CSS Keywords" || fail "O2: style-principles.md columns moved — re-derive this section before reading it as a builder defect"
import sys
for ln in open(sys.argv[1], encoding="utf-8"):
    if ln.strip().startswith("| Style |"):
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        assert cells == ["Style", "Best For", "Avoid For", "CSS Keywords"], cells
        break
else:
    raise AssertionError("no `| Style |` header row in style-principles.md")
PY
{ [ "$(cntF 'Style traits:' "$PR_ST")" = "0" ] && [ "$(cntF 'Style anti-patterns:' "$PR_ST")" = "0" ]; } \
  && ok "O3: the retired invented labels are gone (no Style traits: / Style anti-patterns:)" \
  || fail "O3: an invented column label is back in the design slice"
$PY - "$SP_MD" "$PR_ST" <<'PY' && ok "O4: the Best For cell travels under 'best for:', and under NO traits/anti-pattern label" || fail "O4: product-suitability text is carried under a design-defect label"
import sys
rows = []
for ln in open(sys.argv[1], encoding="utf-8"):
    s = ln.strip()
    if not s.startswith("|"):
        continue
    cells = [c.strip() for c in s.strip("|").split("|")]
    if len(cells) >= 4 and cells[0] not in ("Style",) and not set("".join(cells)) <= set("-: "):
        rows.append(cells)
hit = [r for r in rows if r[0].lower().startswith("minimalism")]
assert hit, "no style-principles.md row prefix-matching 'minimalism'"
best, avoid, css = hit[0][1], hit[0][2], hit[0][3]
doc = open(sys.argv[2], encoding="utf-8").read()
carriers = [l for l in doc.splitlines() if best and best in l]
assert carriers, "the matched row's Best For text never reached the prompt"
for l in carriers:
    low = l.lower()
    assert "trait" not in low and "anti-pattern" not in low, (
        "Best For (product suitability) is emitted under a design-defect label: %r" % l[:160])
    assert "best for:" in low, "Best For text emitted under no 'best for:' label: %r" % l[:160]
# Avoid For likewise, and the CSS cell must have its own honest label.
acarriers = [l for l in doc.splitlines() if avoid and avoid in l]
assert acarriers, "the matched row's Avoid For text never reached the prompt"
for l in acarriers:
    assert "avoid for:" in l.lower(), "Avoid For emitted under the wrong label: %r" % l[:160]
assert "Style CSS keywords:" in doc, "no 'Style CSS keywords:' label"
assert css.split(",")[0].strip() in doc, "the CSS Keywords cell content never reached the prompt"
PY
[ "$(cntE '^[[:space:]]*\(style-principles\.md §' "$PR_ST")" -ge 1 ] \
  && ok "O5: ...and every emitted style row cites its own section + how it was matched" \
  || fail "O5: style rows carry no style-principles.md citation"

# ══════════════════════════════════════════════════════════════════════════════
note "== P. Windows App-Execution-Alias stub — the framework pack must not vanish =="
# ══════════════════════════════════════════════════════════════════════════════
# The documented target machine: `python3` resolves to the WindowsApps alias stub
# (stderr message, exit 49) while a real interpreter exists under another name.
# `|| PACK_CHAIN=""` collapsed exit 0 / exit 3 (documented SKIP) / exit 49 into
# ONE empty chain, so `## Framework pack rules` AND the pack-derived
# `DO NOT WRITE:` anti-context vanished from every bolt at exit 0 with empty
# stderr — and the recorded omission reasons read exactly like a legitimately
# packless project, so the audit trail CONCEALED the loss.
P_WIN="$(mkproj proj-winstub)"
mkdir -p "$P_WIN/.mega-sdd/codebase" "$P_WIN/app/Models" "$P_WIN/app/Http/Controllers"
printf '{"vault_version":"v1"}\n' > "$P_WIN/.mega-sdd/vaults/v1/vault.json"
printf 'framework_pack: laravel\n' > "$P_WIN/.mega-sdd/codebase/starterkit-context.yaml"
cat > "$P_WIN/.mega-sdd/vaults/v1/units/U-050.md" <<'MD'
---
id: U-050
title: Add the role model and its controller
task_type: create
module: rbac
risk: medium
status: pending
target_files:
  - path: app/Models/Role.php
    operation: create
  - path: app/Http/Controllers/RoleController.php
    operation: create
---

## Intent

Add the role model.
MD
# The stub: a `python3` that behaves exactly like the alias (stderr + exit 49),
# living in a dir NAMED WindowsApps, ahead of a real interpreter reachable under
# the name `python`. This is the state resolve-python.sh was written for.
STUB_DIR="$WORK/winstub/WindowsApps"
REAL_DIR="$WORK/winstub/realbin"
mkdir -p "$STUB_DIR" "$REAL_DIR"
printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Microsoft Store." >&2\nexit 49\n' > "$STUB_DIR/python3"
# The shim must exec the REAL interpreter by ABSOLUTE path: $STUB_DIR is FIRST on
# WINPATH, so a bare name inside the shim would resolve straight back to the stub
# and the arm would loop into exit 49. Two branches because $PY is a COMMAND, not
# always a single word:
#   `py -3` (the Windows launcher fallback) is written unquoted and left as a
#           name — `py` is not shadowed by the alias directory, which is the
#           whole reason resolve-python.sh falls back to it.
#   anything else is resolved to its absolute path with `command -v`.
# NOT COVERED, stated rather than papered over: an absolute interpreter path that
# itself contains a space would need the quoted form, and the same expansion
# cannot serve both. No reference interpreter on this repo's targets has one.
case "$PY" in
  *' '*) printf '#!/bin/sh\nexec %s "$@"\n' "$PY" > "$REAL_DIR/python" ;;
  *)     REALPY="$(command -v "$PY" 2>/dev/null)"
         [ -n "$REALPY" ] || REALPY="$PY"
         printf '#!/bin/sh\nexec "%s" "$@"\n' "$REALPY" > "$REAL_DIR/python" ;;
esac
chmod +x "$STUB_DIR/python3" "$REAL_DIR/python"
WINPATH="$STUB_DIR:$REAL_DIR:$PATH"

# The ONE deliberately-bare `python3` in this file: the precondition IS that the
# stub answers to that exact name under this PATH. Resolving it through $PY here
# would test the opposite of what section P is about.
env PATH="$WINPATH" python3 -c 'pass' >/dev/null 2>&1
[ "$?" = "49" ] && ok "P1: precondition — the simulated alias stub really does exit 49 for bare python3" \
                 || fail "P1: the stub is not being reached; the rest of section P would be vacuous"

# ARM A — healthy interpreter.
build "$WORK/win_a.json" "$P_WIN" U-050
[ "$RC" = "0" ] && ok "P2: ARM A (healthy python3) exits 0" || fail "P2: ARM A exit $RC"
cp "$(promptof "$P_WIN" U-050)" "$WORK/win_a.md"
$PY - "$WORK/win_a.json" <<'PY' && ok "P3: precondition — ARM A really does resolve a non-empty pack chain" || fail "P3: ARM A resolved no pack chain; the parity assertion below would be vacuous"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["pack_resolver_exit"] == 0, d["pack_resolver_exit"]
assert d["pack_chain"], d["pack_chain"]
PY

# ARM B — the same fixture, same project root, under the alias-stub PATH.
env PATH="$WINPATH" bash "$BUILD" --cwd="$P_WIN" --vault="$P_WIN/.mega-sdd/vaults/v1" \
  --unit=U-050 --plugin-root="$PLUGIN_ROOT" --explain \
  >"$WORK/win_b.json" 2>"$WORK/win_b.err" </dev/null
WBRC=$?
[ "$WBRC" = "0" ] && ok "P4: ARM B (WindowsApps stub ahead of a real interpreter) exits 0" \
                  || fail "P4: ARM B exit $WBRC (stderr: $(head -2 "$WORK/win_b.err"))"
# THE RAIL: landed OR recorded. Never silently omitted in a way that reads like a
# project which genuinely has no pack.
$PY - "$WORK/win_b.json" "$(promptof "$P_WIN" U-050)" <<'PY' && ok "P5: the pack contribution either LANDS or the failure is RECORDED — never a silent omission" || fail "P5: the pack vanished silently, indistinguishable from a packless project"
import json, sys
d = json.load(open(sys.argv[1]))
doc = open(sys.argv[2], encoding="utf-8").read()
rc = d["pack_resolver_exit"]
if d["pack_chain"]:
    assert "## Framework pack rules" in doc or "framework:" in doc, "chain resolved but nothing landed"
else:
    assert rc in (0, 3) or any("UNRESOLVED" in w for w in d["warnings"]), (
        "resolver exit %s produced an empty chain with no warning" % rc)
    assert rc != 0 or True
# The indistinguishability rail, stated literally: an UNRESOLVED chain may never
# describe itself with the packless wording.
if rc not in (0, 3):
    assert "(no pack resolved)" not in doc, "an UNRESOLVED chain rendered as a packless project"
    assert "UNRESOLVED" in doc, "the unresolved state is not visible in the prompt header"
    assert any("UNRESOLVED" in w for w in d["warnings"]), d["warnings"]
    assert any(o["section"] == "framework_pack.chain" for o in d["sections_omitted"]), \
        "the unresolved chain is not in the omission audit trail"
PY
$PY - "$WORK/win_a.json" "$WORK/win_b.json" <<'PY' && ok "P6: ...and in fact ARM B resolves the IDENTICAL chain — the interpreter is inherited, not re-guessed" || fail "P6: ARM B lost the pack chain the alias-stub bug used to strip"
import json, sys
a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))
assert b["pack_resolver_exit"] == 0, "resolver exit %s under the stub PATH" % b["pack_resolver_exit"]
assert b["pack_chain"] == a["pack_chain"], (a["pack_chain"], b["pack_chain"])
# THE PROPERTY, stated directly rather than by proxy: under WINPATH the name
# `python3` IS the stub, so a builder reporting `python3` here used it (and
# would have exited 49). This holds on every machine. The old form
# (`b != a`) is EQUIVALENT only when ARM A itself resolved python3 — on a
# machine with no python3 at all both arms legitimately resolve `python` and
# the old assertion failed for a reason that had nothing to do with the stub.
# Kept, conditioned on the state that makes it meaningful. This is the real
# detector, not a softened one.
assert b["interpreter"] != "python3", (
    "ARM B reports the stub NAME as its interpreter — the alias was not bypassed")
if a["interpreter"] == "python3":
    assert b["interpreter"] != a["interpreter"], (
        "ARM A resolved python3 and ARM B reports the same name — the stub was not exercised")
PY
cmp -s "$WORK/win_a.md" "$(promptof "$P_WIN" U-050)" \
  && ok "P7: ...and the emitted prompt is BYTE-IDENTICAL across the two interpreter states" \
  || fail "P7: the alias-stub PATH changed the dispatch prompt ($(cmp "$WORK/win_a.md" "$(promptof "$P_WIN" U-050)" 2>&1 | head -1))"

# ══════════════════════════════════════════════════════════════════════════════
note "== Q. Provenance values claims: block carries C-NNN, not a confidence label =="
# ══════════════════════════════════════════════════════════════════════════════
# This block is the ONLY sanctioned source for the agent's mandated trailer
# `Implements claim: C-NNN "<claim text>"`. Emitting `- HIGH "notes"` left the
# agent two options — omit the id, or back-derive one from binding_refs — and the
# second is exactly the fabrication the block exists to prevent. Post-flight only
# checks the trailer is PRESENT, so a malformed-but-present trailer passed
# every gate.
P_CL="$(mkproj proj-claims)"
printf '{"vault_version":"v1"}\n' > "$P_CL/.mega-sdd/vaults/v1/vault.json"
cat > "$P_CL/.mega-sdd/vaults/v1/binding.md" <<'MD'
# Binding

## Implementation State Map

| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-007 | CONFIRMED | UNKNOWN | app/Http/Kernel.php:12 | low | n/a |

## Confirmed Claims

- C-007 | binding | app/Http/Kernel.php:12 | Dynamic route resolution is registered at boot
MD
cat > "$P_CL/.mega-sdd/vaults/v1/units/U-060.md" <<'MD'
---
id: U-060
title: Register the dynamic route resolver
task_type: modify
module: routing
risk: medium
status: pending
binding_refs: [C-007]
target_files:
  - path: app/Http/Kernel.php
    operation: modify
---

## Intent

Register it.
MD
build "$WORK/cl.json" "$P_CL" U-060
PR_CL="$(promptof "$P_CL" U-060)"
[ "$RC" = "0" ] && ok "Q1: builder exit 0 with binding.md + binding_refs" || fail "Q1: exit $RC"
$PY - "$PR_CL" <<'PY' && ok "Q2: the claims: block carries C-NNN plus the claim text — the id the trailer needs" || fail "Q2: the claims: block does not carry a C-NNN id"
import re, sys
doc = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?m)^  claims:\n((?:    - .*\n)+)", doc)
assert m, "no populated `claims:` block in the Provenance values"
rows = [l.strip() for l in m.group(1).splitlines() if l.strip()]
assert rows, rows
for r in rows:
    assert re.match(r'^- C-\d{3} "', r), "claims row is not id-shaped: %r" % r
assert any("Dynamic route resolution is registered at boot" in r for r in rows), rows
# The confidence LABEL must not be standing in for the id INSIDE this block.
for bad in ("- HIGH \"", "- MEDIUM \"", "- LOW \"", "- OQ \""):
    assert not any(r.startswith(bad.rstrip('"')) for r in rows), (bad, rows)
PY
[ "$(cntF '## Confidence labels per claim' "$PR_CL")" -ge 1 ] \
  && ok "Q3: ...while the confidence LABEL keeps its own T2 section (the axes are not merged)" \
  || fail "Q3: the confidence_labels section disappeared"

# ══════════════════════════════════════════════════════════════════════════════
note "== R. DO NOT MODIFY — a LABELLED UNION, never one source substituted =="
# ══════════════════════════════════════════════════════════════════════════════
# The template names data-mutation-policy.md as the source. The builder used to
# read the unit's own `## Hard rules` ALONE and label it as the whole line — an
# undisclosed source SUBSTITUTION. Failure it produced: a legacy-rebuild project
# whose KB marks a ledger [LOCKED] there, on a unit whose generated Hard rules do
# not restate it, ships a bolt that modifies the locked file.
P_DMP="$(mkproj proj-dmp)"
mkdir -p "$P_DMP/.mega-sdd/knowledge-base/99-rebuild-architecture"
printf '{"vault_version":"v1"}\n' > "$P_DMP/.mega-sdd/vaults/v1/vault.json"
cat > "$P_DMP/.mega-sdd/knowledge-base/99-rebuild-architecture/data-mutation-policy.md" <<'MD'
# Data mutation policy

## Per-locked-field policy

| Entity.field | Legacy source | Regulation | Notes |
|---|---|---|---|
| app/Models/LegacyLedger.php | ledgermast | BI Reg 23/2/2021 §4 | never rewrite |

## Entity-level summary

| Entity | Fields | Locked | Discardable | Overall tier | Notes |
|---|---|---|---|---|---|
| transactions | 8 | 6 | 0 | LOCKED (audit trail compliance) | No rewrite |
| customers | 12 | 3 | 2 | INTENT (mixed; 3 locked fields) | Rebuild |

## Discardable artifacts

| Entity | Reason |
|---|---|
| tmp_import_scratch | staging only |
MD
cat > "$P_DMP/.mega-sdd/vaults/v1/units/U-070.md" <<'MD'
---
id: U-070
title: Rebuild the settlement writer
task_type: modify
module: ledger
risk: high
status: pending
target_files:
  - path: app/Services/Settlement.php
    operation: modify
---

## Intent

Rebuild it.

## Hard rules

- DO NOT modify app/Models/Order.php
MD
build "$WORK/dmp.json" "$P_DMP" U-070
PR_DMP="$(promptof "$P_DMP" U-070)"
[ "$RC" = "0" ] && ok "R1: builder exit 0 with a data-mutation-policy.md in the KB" || fail "R1: exit $RC"
[ "$(cntF 'DO NOT MODIFY:' "$PR_DMP")" -ge 1 ] && ok "R2: the DO NOT MODIFY: block is emitted" \
                                               || fail "R2: no DO NOT MODIFY: block"
[ "$(cntF 'app/Models/LegacyLedger.php  (source: data-mutation-policy.md §Per-locked-field policy)' "$PR_DMP")" -ge 1 ] \
  && ok "R3: a §Per-locked-field row reaches the bolt though the unit's Hard rules never restate it" \
  || fail "R3: the KB-locked entry never reached the prompt (the F9 failure survives)"
[ "$(cntF 'transactions  (source: data-mutation-policy.md §Entity-level summary' "$PR_DMP")" -ge 1 ] \
  && ok "R4: an §Entity-level row whose OVERALL TIER cell reads LOCKED is carried, with its tier" \
  || fail "R4: the entity-level LOCKED row was dropped"
# NOTE for anyone editing labels in this file: backticks inside a DOUBLE-quoted
# label are a command substitution, not markup. This one used to read
# "...and `INTENT (mixed; 3 locked fields)` is NOT read as locked", which bash
# executed — every run printed a shell syntax error and the label rendered with
# the entity eaten out of it. A suite whose green output contains the words
# "syntax error" trains its readers to skim the one line a real failure would
# use. Escape them (\`) or, as here, drop them.
$PY - "$PR_DMP" <<'PY' && ok "R5: ...and INTENT (mixed; 3 locked fields) is NOT read as locked (tier cell, not row scan)" || fail "R5: a whole-row token scan mis-read an INTENT entity as LOCKED"
import re, sys
doc = open(sys.argv[1], encoding="utf-8").read()
# (?m) ONLY — with (?s) the `.` swallows newlines and the "block" becomes the
# rest of the file, which makes every assertion below meaningless.
m = re.search(r"(?m)^DO NOT MODIFY:\n((?:  - .*\n)+)", doc)
assert m, "no DO NOT MODIFY block"
entries = [l.strip() for l in m.group(1).splitlines() if l.strip()]
assert entries, "the DO NOT MODIFY block captured no entries"
assert not any(e.startswith("- customers") for e in entries), entries
assert not any("tmp_import_scratch" in e for e in entries), entries
assert all("(source: " in e for e in entries), "an entry ships without its own source label: %s" % entries
PY
[ "$(cntF 'app/Models/Order.php  (source: U-070.md `## Hard rules`)' "$PR_DMP")" -ge 1 ] \
  && ok "R6: ...and the unit's own Hard-rule half is still there, under ITS OWN label (a union, not a swap)" \
  || fail "R6: the Hard-rules half of the union was lost or mislabelled"

# ══════════════════════════════════════════════════════════════════════════════
note "== S. exit 4 — an internal error is NOT a halt and DESTROYS NOTHING =="
# ══════════════════════════════════════════════════════════════════════════════
# Before exit 4 existed, ANY unhandled exception exited 1 with zero stdout and no
# file written. The controller's exit-1 contract reads exit 1 as
# `dispatch_prompt_too_large`, looks for a `halt` object that is not there, and is
# told by that same contract to TRUST the file on disk as forensic evidence —
# which was the PREVIOUS unit's prompt. This section stands the whole state up.
#
# S4/S5 ARE THE INVERSE OF WHAT THEY ASSERTED LAST ROUND, DELIBERATELY. Round 2
# gave the builder a pre-assembly `_unlink_target()` and this suite pinned it
# ("the target is UNLINKED before assembly"). On the documented Windows target
# that turned a stdout ENCODING failure — a defect in the report channel, with a
# CORRECT prompt already on disk — into a DELETED artifact plus a "never
# dispatch" verdict, on every UI-bearing bolt and every unit with a non-Latin-1
# path. Round 3 removed the unlink outright: publication is guaranteed by
# temp-file + os.replace() ALONE, and a run that fails anywhere simply never
# renames. The guarantee the suite must now pin is the one that actually holds:
#   * a failed run PUBLISHES NOTHING (it did not rename), and
#   * it DESTROYS NOTHING (the artifact already at the path is untouched, byte
#     for byte), and
#   * the discriminator is the EXIT CODE — 2 and 4 both mean NEVER DISPATCH —
#     not the presence or absence of a file.
# The residual is real and is named rather than hidden: after a failed run the
# path may hold THIS unit's previous attempt. That is what exit 4 exists to say.
# SCOPE NOTE: the exit-1 budget-halt ARITHMETIC (the three-way conjunction and
# the amended caps) is owned by the sibling cascade suite,
# plugins/mega-sdd/tests/moat/test-dispatch-prompt-cascade.sh. What is pinned
# HERE is the discriminability the controller branches on — a different exit
# code, a different `status`, and `halt` absent rather than populated.
BADS="$WORK/badscripts"
cp -R "$PLUGIN_ROOT/scripts" "$BADS"
# Stand in for ANY in-body exception: an unimportable shared lib. This is also
# the exact reproduction that caught the import-ordering bug (imports must sit
# BELOW the excepthook install, or the default handler exits 1 with no JSON).
rm -f "$BADS/_lib/vault_layouts.py"
P_ERR="$(mkproj proj-internal-error)"
mkdir -p "$P_ERR/.mega-sdd/vaults/v1/bolts/U-010"
printf '{"vault_version":"v1"}\n' > "$P_ERR/.mega-sdd/vaults/v1/vault.json"
cp "$P_BARE/.mega-sdd/vaults/v1/units/U-010.md" "$P_ERR/.mega-sdd/vaults/v1/units/U-010.md"
STALE="$P_ERR/.mega-sdd/vaults/v1/bolts/U-010/dispatch-prompt.md"
printf 'A CORRECT PROMPT FROM THIS UNIT PREVIOUS ATTEMPT — MUST SURVIVE A FAILED RUN\n' > "$STALE"
cp "$STALE" "$WORK/prior-prompt.md"          # the reference, taken BEFORE the crash
bash "$BADS/build-dispatch-prompt.sh" --cwd="$P_ERR" --vault="$P_ERR/.mega-sdd/vaults/v1" \
  --unit=U-010 --plugin-root="$PLUGIN_ROOT" >"$WORK/err.json" 2>"$WORK/err.err" </dev/null
ERC=$?
[ "$ERC" = "4" ] && ok "S1: an unhandled internal exception exits 4, NOT 1" \
                 || fail "S1: internal error exited $ERC (1 is indistinguishable from the budget halt)"
$PY - "$WORK/err.json" <<'PY' && ok "S2: ...with a machine-readable {\"status\":\"internal_error\", error, traceback} on stdout" || fail "S2: no internal_error JSON payload on stdout"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] == "internal_error", d["status"]
assert d.get("error"), d
assert d.get("traceback"), d
assert d.get("unit") == "U-010", d.get("unit")
PY
$PY - "$WORK/err.json" <<'PY' && ok "S3: ...and NO halt object — a crash can never be read as dispatch_prompt_too_large" || fail "S3: the internal-error payload is confusable with the budget halt"
import json, sys
d = json.load(open(sys.argv[1]))
assert "halt" not in d, "internal_error payload carries a `halt` key: %r" % d.get("halt")
assert d["status"] != "halt", d["status"]
PY
# THE ROUND-3 RAIL, and the reason it is spelled as byte-identity rather than
# mere existence: an artifact that survives in a MUTATED state is no better than
# a deleted one. Nothing about a failed run may touch the file already there.
{ [ -f "$STALE" ] && cmp -s "$WORK/prior-prompt.md" "$STALE"; } \
  && ok "S4: a pre-existing CORRECT prompt at the target path survives the crash BYTE-IDENTICAL (nothing is unlinked, nothing is mutated)" \
  || fail "S4: the failed run destroyed or modified the artifact already at the contractual path — this is the regression that deleted a good prompt on the Windows target"
# The other half: the failed run published NOTHING OF ITS OWN. The rename never
# happened, so what is at the path is still the PRIOR text and not a partial
# assembly — and the controller's discriminator is the exit code (4 = never
# dispatch), not the presence of a file.
[ "$(cntF 'MUST SURVIVE A FAILED RUN' "$STALE")" -ge 1 ] \
  && ok "S5: ...and the crashed run renamed nothing into place — the path still holds the PRIOR text, never a half-assembled one" \
  || fail "S5: the target holds something other than the prior attempt after a failed run (a partial assembly was published)"
# LITTER, not the artifact. VACUITY DISCLOSED: this particular reproduction
# raises at the `_lib` import, which is BEFORE the builder ever creates its
# sibling temp file — so on THIS path there is nothing to leave behind and the
# assertion is a guard against a future crash site, not a proof. Its non-vacuous
# twin is S7, on the success path, where both temp files provably existed.
[ "$(ls -a "$P_ERR/.mega-sdd/vaults/v1/bolts/U-010" 2>/dev/null | grep -cE '\.tmp-[0-9]+$' || true)" = "0" ] \
  && ok "S6: ...and no .dispatch-prompt.md.tmp-* litter is left in the bolt dir (guard: this crash fires BEFORE the temp exists)" \
  || fail "S6: a temp sibling survived the crash — it is as dispatchable as the artifact"
# S7 — THE NON-VACUOUS TEMP SWEEP. $P_ST completed a normal greenfield-UI build,
# so BOTH temp files (the prompt's and the lens input's) were really created and
# really renamed. A survivor here means os.replace() was skipped or a cleanup
# path was dropped.
S7_LITTER="$( { ls -a "$P_ST/.mega-sdd/vaults/v1/bolts/U-040" 2>/dev/null
                ls -a "$P_ST/.mega-sdd/vaults/v1/lens-inputs/U-040" 2>/dev/null; } \
              | grep -cE '\.tmp-[0-9]+$' || true)"
# THE PRECONDITION IS PART OF THE CONDITION, deliberately: a missing directory
# also yields a litter count of 0, so without these two `-f` tests S7 would pass
# vacuously the day either write moved — which is the exact defect S6 discloses
# about itself and S7 exists to repair.
{ [ -f "$P_ST/.mega-sdd/vaults/v1/bolts/U-040/dispatch-prompt.md" ] \
  && [ -f "$P_ST/.mega-sdd/vaults/v1/lens-inputs/U-040/design-slice.md" ] \
  && [ "$S7_LITTER" = "0" ]; } \
  && ok "S7: ...and a SUCCESSFUL build leaves no .tmp-* survivor in either bolts/ or lens-inputs/ (both temps provably existed here)" \
  || fail "S7: $S7_LITTER temp file(s) survived a successful build"

# ══════════════════════════════════════════════════════════════════════════════
note "== T. the design slice — a NEUTRAL lens-input FILE, path on stdout =="
# ══════════════════════════════════════════════════════════════════════════════
# THE BLIND RAIL, SCOPED TO ITS PURPOSE: no lens may receive a path that reaches
# ANOTHER LENS'S VERDICT or the IMPLEMENTER'S SELF-REPORT. That is why
# <vault>/bolts/U-XXX/ is off limits to a lens prompt — it also holds
# bolt-report.md, and on a --resume/retry it already holds the prior attempt's
# `## Review panel` verdicts and `bolt_self_report`; a lens with Read/Grep is one
# Glob of the parent directory away from all of it.
#
# Round 2 restated that rail ABSOLUTELY ("not the file, not the directory, not a
# glob that reaches either") and then, to satisfy it, put the whole ~9.6 KB
# rubric on stdout as TEXT. Two problems. (1) The absolute wording was already
# falsified by review-panel.md:38, which routes design-lens screenshots to
# `<bolt-dir>/views` — so it could not be the rule. (2) The text form is billed
# TWICE per greenfield UI bolt: once as builder stdout (input) and again as the
# controller's verbatim re-typing into the lens prompt, which is the OUTPUT
# channel. Round 3 writes the slice to `<vault>/lens-inputs/U-XXX/design-slice.md`
# — a SIBLING of bolts/ holding only controller-written lens inputs and never any
# implementer output — and puts that PATH on stdout. The rail is untouched; the
# output channel stops paying for the same bytes twice.
#
# THE SLICE IS STILL INJECTED INTO THE DISPATCH PROMPT ITSELF. Implementer and
# reviewer must hold the byte-identical contract, so T1/T2 assert the FILE's
# content is a verbatim substring of the prompt — two renderings would be two
# contracts, which is the defect these assertions have always pinned.
build_default "$WORK/tg.json" "$P_ST" U-040
$PY - "$WORK/tg.json" "$PR_ST" <<'PY' && ok "T1: greenfield UI unit — design_slice_path on DEFAULT stdout, and the FILE is a VERBATIM slice of the prompt" || fail "T1: design_slice_path missing / the lens-input file is not byte-identical to the shipped section"
import json, os, sys
d = json.load(open(sys.argv[1]))
assert "design_slice_text" not in d, (
    "the 9.6 KB slice TEXT is back on stdout — the cost fix regressed: %d bytes"
    % len(d.get("design_slice_text") or ""))
p = d.get("design_slice_path")
assert isinstance(p, str) and p, repr(p)
assert os.path.isabs(p) and os.path.isfile(p), p
# The canonical location, asserted as a path SHAPE: a sibling of bolts/, never
# inside it. `lens-inputs/U-XXX/design-slice.md` is what references/paths.md
# declares and what the review-panel + context-enrichment agents were written to.
norm = p.replace(os.sep, "/")
assert "/lens-inputs/U-040/design-slice.md" in norm, norm
assert "/bolts/" not in norm, (
    "the lens input sits inside the bolt dir — a lens handed this path is one Glob "
    "from the implementer's self-report and the other lenses' verdicts: %s" % norm)
txt = open(p, encoding="utf-8").read()
# The writer appends exactly ONE newline. Strip exactly one — rstrip("\n") would
# over-strip a slice that legitimately ends in a blank line and silently shorten
# the needle, turning a real divergence into a pass.
if txt.endswith("\n"):
    txt = txt[:-1]
assert txt.strip(), repr(txt[:80])
doc = open(sys.argv[2], encoding="utf-8").read()
assert txt in doc, (
    "the lens-input file is a RE-RENDERING, not the shipped text — implementer and "
    "reviewer would hold two contracts")
PY
$PY - "$WORK/tg.json" <<'PY' && ok "T1b: ...and stdout is now SMALLER than the slice it points at (the path replaced the text on the billed channel)" || fail "T1b: stdout is not smaller than the lens-input file — the relocation bought nothing"
import json, os, sys
raw = os.path.getsize(sys.argv[1])
d = json.load(open(sys.argv[1]))
slice_bytes = os.path.getsize(d["design_slice_path"])
# RELATIONAL ON PURPOSE. No byte threshold is asserted anywhere in this suite:
# three different published figures have now been derived from each other, and
# the measurement is owned by one dedicated pass against shipped code. What is
# pinned here is the PROPERTY the change bought, which cannot rot.
assert raw < slice_bytes, (
    "whole stdout report = %d B, lens-input file = %d B — the slice did not leave "
    "the channel" % (raw, slice_bytes))
PY
# `ls -A`, NOT `ls -1`: the lens-input temp is `.design-slice.md.tmp-<pid>`, a
# DOTFILE, and `ls -1` hides dotfiles — so the intruder this assertion exists to
# catch is exactly the one `ls -1` cannot see. (-A rather than -a: `.` and `..`
# are not entries anyone put there.)
[ "$(ls -A "$P_ST/.mega-sdd/vaults/v1/lens-inputs/U-040" 2>/dev/null | wc -l | tr -d ' ')" = "1" ] \
  && ok "T1c: ...and lens-inputs/U-040/ holds EXACTLY ONE entry, dotfiles included — the directory carries lens input and nothing else" \
  || fail "T1c: lens-inputs/U-040/ holds $(ls -A "$P_ST/.mega-sdd/vaults/v1/lens-inputs/U-040" 2>/dev/null | wc -l | tr -d ' ') entries — a neutral lens-input dir is only neutral while it stays pure"
build_default "$WORK/ts.json" "$P_UI" U-002
$PY - "$WORK/ts.json" "$PR_UI" <<'PY' && ok "T2: starterkit UI unit — the lens-input file is the DESIGN lines only, verbatim from the shipped rung" || fail "T2: starterkit lens input wrong / not a verbatim slice"
import json, os, sys
d = json.load(open(sys.argv[1]))
assert "design_slice_text" not in d, "the slice TEXT is back on stdout"
p = d.get("design_slice_path")
assert isinstance(p, str) and os.path.isfile(p), repr(p)
assert "/lens-inputs/U-002/design-slice.md" in p.replace(os.sep, "/"), p
t = open(p, encoding="utf-8").read()
if t.endswith("\n"):
    t = t[:-1]
assert t.strip(), repr(t)
doc = open(sys.argv[2], encoding="utf-8").read()
assert t in doc, "the starterkit lens input is not a verbatim slice of the emitted prompt"
# A lens judging UI quality against an auth line judges against a contract nobody
# wrote — the extraction boundary is the three design lines and nothing else.
for forbidden in ("Auth:", "Authz:", "Libs in scope:", "### Reference code example"):
    assert forbidden not in t, "non-design content leaked into the lens rubric: %r" % forbidden
assert "Design tokens:" in t or "Design system:" in t or "UI/UX:" in t, t
PY
# ABSENT KEY, never "": a UI-bearing unit whose every design input is absent gets
# NO rubric, and the controller is told so rather than handed a substitute.
P_NOR="$(mkproj proj-norubric)"
mkdir -p "$P_NOR/.mega-sdd/codebase" "$P_NOR/resources/views"
printf '{"vault_version":"v1"}\n' > "$P_NOR/.mega-sdd/vaults/v1/vault.json"
printf 'framework_pack: laravel\nui_ux:\n  layout_extends: ""\n  notification_lib: ""\n' \
  > "$P_NOR/.mega-sdd/codebase/starterkit-context.yaml"
cat > "$P_NOR/.mega-sdd/vaults/v1/units/U-080.md" <<'MD'
---
id: U-080
title: Render the bare listing view
task_type: create
module: orders
risk: low
status: pending
starterkit_relevance: [ui_ux]
target_files:
  - path: resources/views/bare.blade.php
    operation: create
---

## Intent

Render it.
MD
build "$WORK/nor.json" "$P_NOR" U-080
[ "$RC" = "0" ] && ok "T3a: builder exit 0 for a UI-bearing unit with every design input absent" || fail "T3a: exit $RC"
$PY - "$WORK/nor.json" <<'PY' && ok "T3b: ...design_slice_path is an ABSENT KEY (never \"\", never a path to a file that was not written), with the no-rubric reason recorded" || fail "T3b: design_slice_path was emitted empty / the absence is unrecorded"
import json, sys
d = json.load(open(sys.argv[1]))
assert "design_slice_path" not in d, "empty rubric emitted as a present key: %r" % d.get("design_slice_path")
assert "design_slice_text" not in d, "the retired TEXT key is back: %r" % d.get("design_slice_text")
om = {o["section"]: o["reason"] for o in d["sections_omitted"]}
assert "design_slice_path" in om, sorted(om)
assert "NO rubric" in om["design_slice_path"] or "no rubric" in om["design_slice_path"], om["design_slice_path"]
PY
[ ! -e "$P_NOR/.mega-sdd/vaults/v1/lens-inputs/U-080/design-slice.md" ] \
  && ok "T3c: ...and NO lens-input file is written for a unit that has no rubric (the key's absence and the file's absence agree)" \
  || fail "T3c: a lens-input file exists for a unit whose stdout says there is no rubric"

# ── T4: a PURE-BACKEND unit on a starterkit repo pays NOTHING for the lens ─────
# THE GATE MUST BE `ui_bearing`, NOT "the slice text is non-empty". The design
# lens (`design-reviewer`) joins the panel only when the unit is UI-bearing
# (review-panel.md §Tier selection), so a rubric written for a backend unit is a
# file no reader is ever handed.
#
# Round 3 gated the WRITE on the slice text alone, and on the starterkit branch
# that text exists for ANY unit whose frontmatter carries
# `starterkit_relevance: [ui_ux]` — regardless of `target_files`. Reproduced
# live before the fix: this exact fixture, whose only target is
# `app/Services/Settlement.php`, received a `design_slice_path` AND a written
# lens-input file. On a real starterkit repo that is a per-non-UI-bolt stdout
# cost plus an unread file, and it made review-panel.md's "pure-backend units
# never pay for it" false in the same changeset that shipped it.
#
# WHY THIS FIXTURE AND NOT SECTION L's: the cascade suite's non-UI rail (L1)
# passes with the defect LIVE, because its project has no
# starterkit-context.yaml — `sk_ui is None`, so the buggy branch never runs. The
# starterkit yaml below is what makes this rail non-vacuous, and the ui_ux slice
# it carries must be genuinely renderable or the arm proves nothing.
P_BEK="$(mkproj proj-backend-starterkit)"
mkdir -p "$P_BEK/.mega-sdd/codebase" "$P_BEK/app/Services"
printf '{"vault_version":"v1","design_system":{"style":"minimalism","palette":"trust-blue","typography":"Inter","a11y_level":"AA"}}\n' \
  > "$P_BEK/.mega-sdd/vaults/v1/vault.json"
cat > "$P_BEK/.mega-sdd/codebase/starterkit-context.yaml" <<'YAML'
framework_pack: laravel
ui_ux:
  layout_extends: layouts.app
  notification_lib: sweetalert2
  idioms:
    - toast on success
design_tokens:
  colors: "#112233"
  spacing: "4px"
  fonts: Inter
YAML
cat > "$P_BEK/.mega-sdd/vaults/v1/units/U-500.md" <<'MD'
---
id: U-500
title: Settlement posting service
task_type: modify
module: settlement
risk: medium
status: pending
starterkit_relevance: [ui_ux]
target_files:
  - path: app/Services/Settlement.php
    operation: modify
---

## Intent

Post settlements to the ledger.
MD
build "$WORK/bek.json" "$P_BEK" U-500
[ "$RC" = "0" ] && ok "T4a: a pure-backend unit on a starterkit repo builds normally (exit 0)" || fail "T4a: exit $RC"
$PY - "$WORK/bek.json" <<'PY' && ok "T4b: ...design_slice_path is ABSENT for a unit that is NOT ui_bearing, even though its starterkit_relevance carries ui_ux — and the reason is RECORDED" || fail "T4b: a non-ui_bearing unit was handed a design rubric (the write is gated on slice text, not on ui_bearing)"
import json, sys
d = json.load(open(sys.argv[1]))
assert "design_slice_path" not in d, (
    "a pure-backend unit got a lens rubric path: %r" % d.get("design_slice_path"))
om = {o["section"]: o["reason"] for o in d["sections_omitted"]}
assert "design_slice_path" in om, sorted(om)
assert "ui_bearing" in om["design_slice_path"], om["design_slice_path"]
# NON-VACUITY, the assertion this rail lives or dies on: the starterkit ui_ux
# slice must actually have been BUILT for this unit. If it were not, "no
# design_slice_path" would pass for a fixture that could never have produced one,
# and the rail would be theatre.
emitted = set(d["sections_emitted"])
assert "starterkit_slice" in emitted, sorted(emitted)
PY
[ ! -e "$P_BEK/.mega-sdd/vaults/v1/lens-inputs" ] \
  && ok "T4c: ...and NO lens-input file (indeed no lens-inputs/ directory at all) is written for it" \
  || fail "T4c: a lens-input file/dir was written for a pure-backend unit"
# The bolt itself must lose NOTHING — the unit declared ui_ux relevance, so its
# starterkit slice still ships INTO THE PROMPT. Only the LENS input is withheld.
# Without this, "fix" could mean "stop building the slice", which would be a
# content regression wearing a cost fix's clothes.
[ "$(cntE '^(UI/UX|Design tokens):' "$(promptof "$P_BEK" U-500)")" -ge 1 ] \
  && ok "T4d: ...while the unit's own starterkit slice STILL ships in the dispatch prompt (the fix withholds a lens input, it does not delete content)" \
  || fail "T4d: the starterkit slice vanished from the prompt — the fix removed content instead of withholding a lens input"

# ══════════════════════════════════════════════════════════════════════════════
note "== U. the absent-value SMOKE ALARM is not a circuit breaker =="
# ══════════════════════════════════════════════════════════════════════════════
# Section N pins the absent-value RULE (a `%s`-of-None must never be rendered).
# THIS section pins the other half, and it is the half round 2 got catastrophically
# wrong: the DETECTOR must never be able to kill a bolt.
#
# Round 2 answered N by adding a regex scan of the ASSEMBLED PROMPT that exited 4
# — the "internal error, NEVER dispatch" code — whenever the value-position
# shapes appeared anywhere in it. Reproduced live on legal, machine-generated
# input: `.mega-sdd/codebase/reuse-index.yaml` is written by scan-codebase, and a
# `purpose:` string reading "Look up a user by email; returns None, or the user
# record." is the commonest docstring phrase in two of the ecosystems this
# pipeline must serve. The bolt became PERMANENTLY undispatchable, the operator
# could not edit the input away, and the exemption mechanism (a whitelist of
# remembered verbatim sources) could only ever be under-populated. It was also a
# tech-agnosticism breach: PHP and Ruby repos were unaffected.
#
# The property, stated so it cannot rot: file-sourced PROSE containing the English
# word "None" produces a NORMAL prompt at exit 0, the bolt is dispatchable, and
# the smoke alarm does not fire. `warnings[]` is deliberately NOT asserted empty —
# that is a fixture fact, not the contract; an unrelated legitimate warning must
# not make this rail red.
P_RN="$(mkproj proj-reuse-none)"
mkdir -p "$P_RN/.mega-sdd/codebase"
printf '{"vault_version":"v1"}\n' > "$P_RN/.mega-sdd/vaults/v1/vault.json"
cat > "$P_RN/.mega-sdd/vaults/v1/units/U-090.md" <<'MD'
---
id: U-090
title: Harden the user lookup helper
task_type: modify
module: identity
risk: low
status: pending
target_files:
  - path: app/Support/UserLookup.php
    operation: modify
---

## Intent

Harden it.
MD
# `path` equals the unit's target_file so the entry passes the overlap filter,
# and `_source` is truthy because the builder drops entries without one — both
# are what make this fixture reach the renderer instead of being filtered out.
cat > "$P_RN/.mega-sdd/codebase/reuse-index.yaml" <<'YAML'
helpers:
  - name: findUserByEmail
    path: app/Support/UserLookup.php
    purpose: "Look up a user by email; returns None, or the user record."
    _source: app/Support/UserLookup.php:12
YAML
build "$WORK/rn.json" "$P_RN" U-090
PR_RN="$(promptof "$P_RN" U-090)"
[ "$RC" = "0" ] && ok "U1: a reuse-index purpose containing the English word None exits 0 (the detector is NOT a chain-killer)" \
                || fail "U1: exit $RC — legal machine-generated prose made the bolt undispatchable (round-2 R-CRIT-A is back)"
[ -s "$PR_RN" ] && ok "U2: ...the dispatch prompt EXISTS and is non-empty — the bolt is dispatchable" \
                || fail "U2: no prompt at $PR_RN"
# NON-VACUITY: prove the offending string actually reached the assembled prompt.
# Without this the rail passes for the wrong reason the day the reuse slice stops
# being rendered at all.
[ "$(cntF 'returns None, or the user record.' "$PR_RN")" -ge 1 ] \
  && ok "U3: ...and the string REACHED the prompt verbatim (non-vacuity guard: the detector had something to trip on)" \
  || fail "U3: the reuse purpose never reached the prompt — U1/U2 would be vacuous"
$PY - "$WORK/rn.json" "$PR_RN" <<'PY' && ok "U4: ...status is ok, no halt, and the smoke alarm did NOT fire on file-sourced prose" || fail "U4: the placeholder detector fired on a verbatim file blob"
import json, os, sys
d = json.load(open(sys.argv[1]))
assert d["status"] in ("ok", "ok_with_soft_halts"), d["status"]
assert d["halt"] is None, d["halt"]
# The property, not the fixture: no warning of the smoke-alarm CLASS. warnings[]
# is free to carry unrelated entries.
alarm = [w for w in d["warnings"] if "absent-value smoke alarm" in w]
assert not alarm, "the pair-level detector fired on a verbatim file blob: %s" % alarm
# Dispatchable means the controller has what it needs to dispatch.
core = d["inline_core"]
assert core.splitlines()[0].startswith("UNIT: U-090"), core.splitlines()[0]
assert d["prompt_path"] in core and os.path.isfile(d["prompt_path"]), core
PY

# ── U5-U8: when the alarm DOES fire, the pair is OMITTED — not rendered ────────
# THE DETECTOR'S OTHER HALF, and it was self-contradictory until round 4. The
# module comment above compose() states the rule this suite's section N pins —
# "a rendered None is worse than an omitted line", because a placeholder
# SATISFIES validate-ui-quality.sh's `design_system_not_injected` check while
# handing the implementer `None` as its authoritative palette. compose() warned
# that a value was a placeholder token and then rendered it anyway, producing
# exactly the outcome its own comment names as the bad one.
#
# Invariant #5 discriminates and is not ambiguous: absent input is OMITTED with a
# recorded reason, never defaulted. A source that literally says "None" supplied
# no palette. Reproduced before the fix on the fixture below: the prompt read
# `Design system: style=minimalism · palette=None · typography=Inter · a11y=AA`.
#
# NOTE the difference from U1-U4, which is the whole reason both exist: U1-U4
# pin that PROSE containing the word "None" never trips the alarm; U5-U8 pin that
# a whole rendered VALUE equal to the token always does, and is dropped. One
# detector, two directions, neither able to kill a bolt.
P_PH="$(mkproj proj-placeholder)"
mkdir -p "$P_PH/resources/views/orders"
printf '{"vault_version":"v1","design_system":{"style":"minimalism","palette":"None","typography":"Inter","a11y_level":"AA"}}\n' \
  > "$P_PH/.mega-sdd/vaults/v1/vault.json"
cat > "$P_PH/.mega-sdd/vaults/v1/units/U-600.md" <<'MD'
---
id: U-600
title: Order detail view
task_type: create
module: orders
risk: low
status: pending
target_files:
  - path: resources/views/orders/show.blade.php
    operation: create
---

## Intent

Render the order detail view.
MD
build "$WORK/ph.json" "$P_PH" U-600
PR_PH="$(promptof "$P_PH" U-600)"
[ "$RC" = "0" ] && ok "U5: a vault whose design_system.palette literally says \"None\" still builds (the alarm is not a circuit breaker in this direction either)" || fail "U5: exit $RC — the placeholder detector became a chain-killer"
[ "$(cntF 'palette=None' "$PR_PH")" = "0" ] \
  && ok "U6: ...and \`palette=None\` is NOT rendered — the placeholder pair is DROPPED, so design_system_not_injected can no longer be satisfied vacuously" \
  || fail "U6: palette=None shipped into the prompt — the builder renders a value its own comment calls worse than an omitted line"
# NON-VACUITY: the rest of the line must still ship. "No palette=None" would pass
# trivially if the whole Design system: line had been dropped or never composed.
[ "$(cntE '^Design system: style=minimalism · typography=Inter · a11y=AA' "$PR_PH")" -ge 1 ] \
  && ok "U7: ...while the three REAL values still compose one line (only the placeholder pair was withheld, not the section)" \
  || fail "U7: the whole Design system: line was lost — the fix dropped a section instead of a pair"
$PY - "$WORK/ph.json" <<'PY' && ok "U8: ...and the drop is BOTH warned about (the source is what to fix) and recorded as an omission with its reason (invariant #5)" || fail "U8: the placeholder pair was dropped without a warning and/or without a recorded reason"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] in ("ok", "ok_with_soft_halts"), d["status"]
assert d["halt"] is None, d["halt"]
alarm = [w for w in d["warnings"] if "absent-value smoke alarm" in w and "palette" in w]
assert alarm, "the alarm did not fire on a whole rendered value equal to the token: %s" % d["warnings"]
assert "OMITTED" in alarm[0], "the warning still describes the value as shipped: %s" % alarm[0]
om = {o["section"]: o["reason"] for o in d["sections_omitted"]}
k = [s for s in om if s.endswith("placeholder_keys")]
assert k, sorted(om)
assert "palette" in om[k[0]], om[k[0]]
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== V. the Windows stdout channel — cp1252 must not cost the artifact =="
# ══════════════════════════════════════════════════════════════════════════════
# THE REGRESSION THIS PINS, exactly: on the documented Windows/Git-Bash target a
# REDIRECTED Python stdout falls back to the ANSI code page (cp1252) with
# errors='strict'. The report legitimately carries characters cp1252 cannot
# encode, so the FINAL WRITE raised UnicodeEncodeError — and round 2's exit-4
# handler then DELETED the dispatch prompt the builder had already written
# correctly. A defect in the report channel destroyed the artifact, on every
# UI-bearing bolt and every unit whose paths or title are outside cp1252.
# `PYTHONIOENCODING=cp1252` reproduces it on any platform: Python uses
# locale.getpreferredencoding() with errors='strict' whenever stdout is a pipe,
# which is exactly what the Bash tool hands it.
#
# THE TWO ARMS PROVE DIFFERENT THINGS AND THE LABELS SAY WHICH. Since the design
# slice left stdout (section T), a UI unit's stdout is no longer the carrier of
# the offending characters — the UI arm now exercises the FILE write and the
# LENS-INPUT write under a hostile locale. The CJK arm is the one that still
# exercises the STDOUT leg, because the unit title and its target path ride
# `inline_core`, which is on stdout unconditionally and cannot be suppressed.
cp "$PR_ST" "$WORK/cp_ref_prompt.md"
cp "$P_ST/.mega-sdd/vaults/v1/lens-inputs/U-040/design-slice.md" "$WORK/cp_ref_slice.md"
env PYTHONIOENCODING=cp1252 bash "$BUILD" --cwd="$P_ST" --vault="$P_ST/.mega-sdd/vaults/v1" \
  --unit=U-040 --plugin-root="$PLUGIN_ROOT" >"$WORK/cp_ui.json" 2>"$WORK/cp_ui.err" </dev/null
CPRC=$?
[ "$CPRC" = "0" ] && ok "V1: UI-bearing unit under PYTHONIOENCODING=cp1252 exits 0" \
                  || fail "V1: exit $CPRC under cp1252 (stderr: $(head -2 "$WORK/cp_ui.err"))"
{ [ -s "$PR_ST" ] && cmp -s "$WORK/cp_ref_prompt.md" "$PR_ST"; } \
  && ok "V2: ...and the dispatch prompt is present and BYTE-IDENTICAL — the hostile locale cost the artifact nothing" \
  || fail "V2: the prompt was deleted or changed under cp1252 — this is the exact regression that destroyed a correct artifact on the target machine"
{ [ -s "$P_ST/.mega-sdd/vaults/v1/lens-inputs/U-040/design-slice.md" ] \
  && cmp -s "$WORK/cp_ref_slice.md" "$P_ST/.mega-sdd/vaults/v1/lens-inputs/U-040/design-slice.md"; } \
  && ok "V3: ...and so is the lens-input file (the second UTF-8 write path survives too)" \
  || fail "V3: the lens-input file was lost or changed under cp1252"
$PY - "$WORK/cp_ui.json" "$PR_ST" <<'PY' && ok "V4: ...stdout is still parseable JSON carrying design_slice_path (non-vacuity: the FILE holds bytes cp1252 cannot encode)" || fail "V4: the cp1252 report is unparseable / the arm is vacuous"
import json, os, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["status"] in ("ok", "ok_with_soft_halts"), d["status"]
assert d.get("design_slice_path") and os.path.isfile(d["design_slice_path"]), d.get("design_slice_path")
# NON-VACUITY for THIS arm: the artifact really does contain characters cp1252
# cannot represent, so the UTF-8 file writes were genuinely exercised.
raw = open(sys.argv[2], "rb").read()
assert any(b > 127 for b in raw), (
    "the emitted prompt is pure ASCII — this arm proves nothing; the fixture must "
    "carry non-cp1252 content")
PY
# ── The STDOUT leg: a unit whose title AND target path are outside cp1252 ─────
P_CJK="$(mkproj proj-cjk)"
printf '{"vault_version":"v1"}\n' > "$P_CJK/.mega-sdd/vaults/v1/vault.json"
cat > "$P_CJK/.mega-sdd/vaults/v1/units/U-110.md" <<'MD'
---
id: U-110
title: 结算处理器 — rebuild the settlement processor
task_type: modify
module: settlement
risk: high
status: pending
target_files:
  - path: app/Services/账单/结算处理器.php
    operation: modify
---

## Intent

Rebuild it.
MD
env PYTHONIOENCODING=cp1252 bash "$BUILD" --cwd="$P_CJK" --vault="$P_CJK/.mega-sdd/vaults/v1" \
  --unit=U-110 --plugin-root="$PLUGIN_ROOT" >"$WORK/cp_cjk.json" 2>"$WORK/cp_cjk.err" </dev/null
CJRC=$?
PR_CJK="$(promptof "$P_CJK" U-110)"
[ "$CJRC" = "0" ] && ok "V5: a non-ASCII TITLE + non-ASCII target path under cp1252 exits 0 (this is the stdout leg — inline_core carries both and cannot be suppressed)" \
                  || fail "V5: exit $CJRC (stderr: $(head -2 "$WORK/cp_cjk.err"))"
[ -s "$PR_CJK" ] && ok "V6: ...and the dispatch prompt is written and non-empty" \
                 || fail "V6: no prompt at $PR_CJK — a CJK path cost the bolt its dispatch"
$PY - "$WORK/cp_cjk.json" <<'PY' && ok "V7: ...the report parses and inline_core carries BOTH the CJK title and the CJK path (non-vacuity: the stdout payload is genuinely un-encodable in cp1252)" || fail "V7: the cp1252 stdout leg is broken or vacuous"
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
core = d["inline_core"]
assert "结算处理器" in core, core
assert "app/Services/账单/结算处理器.php" in core, core
PY
# THE BELT, ASSERTED INDEPENDENTLY OF THE BRACES. Two fixes contain this
# regression: `ensure_ascii=True` on every stdout json.dumps(), and a
# sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace"). The
# reconfigure alone would make V5-V7 pass on macOS even if ensure_ascii were
# dropped — so this asserts the documented contract directly: the bytes the
# builder writes to stdout are PURE ASCII, which cannot raise on ANY code page.
$PY - "$WORK/cp_cjk.json" <<'PY' && ok "V8: ...and every byte of raw stdout is < 128 — pure-ASCII output cannot raise on any code page (pins ensure_ascii independently of the reconfigure)" || fail "V8: raw stdout carries non-ASCII bytes — the encoding fix rests on the reconfigure alone"
import sys
raw = open(sys.argv[1], "rb").read()
bad = [(i, b) for i, b in enumerate(raw) if b > 127]
assert not bad, "non-ASCII byte(s) on stdout at offsets %s" % [i for i, _ in bad[:5]]
PY

# ══════════════════════════════════════════════════════════════════════════════
note "== W. a data-mutation-policy TABLE HEADER is never a locked path =="
# ══════════════════════════════════════════════════════════════════════════════
# Round 2's new §Per-locked-field parser dropped the markdown header row by a
# hardcoded NAME allowlist ("entity", "entity.field"), so a project whose table
# is headed differently shipped that header CELL as a `DO NOT MODIFY:` path,
# stamped with a real citation to a real KB file and section. That is invariant
# #5's exact shape — the source is genuine, the assertion is invented — and it
# lands inside the T1 anti-context block agents/bolt-implementer.md declares
# BINDING. No validator pins the header wording (the KB is an LLM-generated
# artifact), so the wording could never have been the discriminator. Round 3
# drops the header STRUCTURALLY: the row immediately before a `|---|` delimiter
# is the header, whatever it says.
P_HDR="$(mkproj proj-dmp-header)"
mkdir -p "$P_HDR/.mega-sdd/knowledge-base/99-rebuild-architecture"
printf '{"vault_version":"v1"}\n' > "$P_HDR/.mega-sdd/vaults/v1/vault.json"
cat > "$P_HDR/.mega-sdd/knowledge-base/99-rebuild-architecture/data-mutation-policy.md" <<'MD'
# Data mutation policy

## Per-locked-field policy

| Field | Tier | Policy |
|---|---|---|
| app/Models/LegacyLedger.php | [LOCKED] | never modify |
MD
cp "$P_DMP/.mega-sdd/vaults/v1/units/U-070.md" "$P_HDR/.mega-sdd/vaults/v1/units/U-070.md"
build "$WORK/hdr.json" "$P_HDR" U-070
PR_HDR="$(promptof "$P_HDR" U-070)"
[ "$RC" = "0" ] && ok "W1: builder exit 0 on a policy table headed | Field | Tier | Policy |" || fail "W1: exit $RC"
$PY - "$PR_HDR" <<'PY' && ok "W2: the header cell 'Field' is NOT emitted as a DO NOT MODIFY path, while the real data row IS (structural drop, not a name allowlist)" || fail "W2: a table header cell shipped as a locked path cited to a real KB section"
import re, sys
doc = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?m)^DO NOT MODIFY:\n((?:  - .*\n)+)", doc)
assert m, "no DO NOT MODIFY block"
entries = [l.strip() for l in m.group(1).splitlines() if l.strip()]
# NON-VACUITY first: the data row must be there, or "no header cell" would pass
# for a parser that emitted nothing at all.
assert any(e.startswith("- app/Models/LegacyLedger.php") for e in entries), entries
assert not any(e.startswith("- Field") for e in entries), (
    "the table HEADER cell was emitted as a locked path: %s" % entries)
PY
# THE OTHER DIRECTION — FAIL CLOSED. A pipe block with no `|---|` row is not a
# markdown table: its first row cannot be distinguished from data. Guessing
# "row 1 is the header" or "row 1 is data" both mint a fabricated locked path in
# one of the two cases, so NOTHING is emitted and the skip is RECORDED. This is
# the direction a future "just treat row 1 as data" shortcut would re-open.
P_NOD="$(mkproj proj-dmp-nodelim)"
mkdir -p "$P_NOD/.mega-sdd/knowledge-base/99-rebuild-architecture"
printf '{"vault_version":"v1"}\n' > "$P_NOD/.mega-sdd/vaults/v1/vault.json"
cat > "$P_NOD/.mega-sdd/knowledge-base/99-rebuild-architecture/data-mutation-policy.md" <<'MD'
# Data mutation policy

## Per-locked-field policy

| Entity.field | Legacy source | Regulation | Notes |
| customers.nip | cifmast.cifNip | BI Reg 23/2/2021 §4 | never rewrite |
MD
cp "$P_DMP/.mega-sdd/vaults/v1/units/U-070.md" "$P_NOD/.mega-sdd/vaults/v1/units/U-070.md"
build "$WORK/nodelim.json" "$P_NOD" U-070
PR_NOD="$(promptof "$P_NOD" U-070)"
[ "$RC" = "0" ] && ok "W3: builder exit 0 on a delimiter-less pipe block" || fail "W3: exit $RC"
{ [ "$(cntF 'Entity.field' "$PR_NOD")" = "0" ] && [ "$(cntF 'customers.nip' "$PR_NOD")" = "0" ]; } \
  && ok "W4: ...and NEITHER row is emitted — with no |---| the header cannot be identified, so the whole table is skipped (fail closed)" \
  || fail "W4: a delimiter-less table contributed a locked path — one of the two rows is necessarily a fabrication"
$PY - "$WORK/nodelim.json" <<'PY' && ok "W5: ...and the skip is RECORDED with its reason (an absent input, never a silent drop)" || fail "W5: the delimiter-less table was dropped silently"
import json, sys
om = {o["section"]: o["reason"] for o in json.load(open(sys.argv[1]))["sections_omitted"]}
k = [s for s in om if s.endswith("data_mutation_policy.Per-locked-field_policy")]
assert k, sorted(om)
r = om[k[0]]
assert "delimiter" in r, r
PY
# The unit's OWN Hard-rule half is unaffected by either table defect — the two
# sources are a labelled union, and one source failing must not take the other
# with it (section R pins the union; this pins its independence).
[ "$(cntF 'app/Models/Order.php  (source: U-070.md `## Hard rules`)' "$PR_NOD")" -ge 1 ] \
  && ok "W6: ...while the unit's own Hard-rules half still ships (a skipped KB table never suppresses the other source)" \
  || fail "W6: the Hard-rules half was lost when the KB table was skipped"

# ── W7-W9: a LOCKED entry sitting above a FILLER row must survive ─────────────
# THE OTHER HALF OF INVARIANT #5. W2 pins "never invent a locked path"; this pins
# "never silently lose one". Both directions corrupt the same T1 anti-context
# block that agents/bolt-implementer.md declares BINDING — one fabricates a rule,
# the other fabricates its absence, and the second is worse because nothing in
# the artifact shows it happened.
#
# Round 3's structural drop treated ANY row whose cells hold only dashes, colons
# and spaces as a delimiter, then discarded the row BEFORE it as the header. A
# legal empty row written `| - | - | - | - |` therefore ate the real `[LOCKED]`
# entry directly above it. Reproduced on this exact fixture before the fix:
# `LegacyLedger.php` vanished from `DO NOT MODIFY:` and `sections_omitted` was
# EMPTY — unlike the no-delimiter case (W5), the loss was not recorded anywhere.
#
# The fix is positional: in markdown the alignment row is the SECOND row of the
# table, never any later one (and the KB schema puts exactly one table per
# section — extract-intelligence/references/knowledge-base-schema.md
# §`data-mutation-policy.md` template). A dash-only row anywhere below is filler,
# dropped and RECORDED.
P_FIL="$(mkproj proj-dmp-filler)"
mkdir -p "$P_FIL/.mega-sdd/knowledge-base/99-rebuild-architecture"
printf '{"vault_version":"v1"}\n' > "$P_FIL/.mega-sdd/vaults/v1/vault.json"
cat > "$P_FIL/.mega-sdd/knowledge-base/99-rebuild-architecture/data-mutation-policy.md" <<'MD'
# Data mutation policy

## Per-locked-field policy

| Entity.field | Legacy source | Mandated by | Rebuild permission |
|---|---|---|---|
| app/Models/LegacyLedger.php | ledgermast | BI Reg 23/2/2021 §4 | never modify |
| - | - | - | - |
| app/Models/AuditTrail.php | auditmast | SEOJK 21/2017 | never modify |
MD
cp "$P_DMP/.mega-sdd/vaults/v1/units/U-070.md" "$P_FIL/.mega-sdd/vaults/v1/units/U-070.md"
build "$WORK/fil.json" "$P_FIL" U-070
PR_FIL="$(promptof "$P_FIL" U-070)"
[ "$RC" = "0" ] && ok "W7: builder exit 0 on a policy table carrying a dash-only filler row" || fail "W7: exit $RC"
$PY - "$PR_FIL" <<'PY' && ok "W8: the LOCKED entry directly ABOVE a filler row SURVIVES, the filler contributes nothing, and the header is still dropped" || fail "W8: a real LOCKED entry was silently eaten by a filler row (or the filler/header shipped as a locked path)"
import re, sys
doc = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?m)^DO NOT MODIFY:\n((?:  - .*\n)+)", doc)
assert m, "no DO NOT MODIFY block"
entries = [l.strip() for l in m.group(1).splitlines() if l.strip()]
paths = [e[2:].split("  (source:")[0] for e in entries]
# THE ROW THAT USED TO VANISH.
assert "app/Models/LegacyLedger.php" in paths, (
    "the LOCKED entry above the filler row was DROPPED: %s" % paths)
# The row below it must be unaffected too (proves the fix did not just special-case row 3).
assert "app/Models/AuditTrail.php" in paths, paths
# The filler row itself is not an entry, and the header is still not one.
assert "-" not in paths and "Entity.field" not in paths, paths
PY
$PY - "$WORK/fil.json" <<'PY' && ok "W9: ...and the dropped filler row is RECORDED with its reason — a row the parser discards is never discarded silently" || fail "W9: the filler row was dropped with no audit trail (the exact gap that hid the W8 defect)"
import json, sys
om = {o["section"]: o["reason"] for o in json.load(open(sys.argv[1]))["sections_omitted"]}
k = [s for s in om if s.endswith("Per-locked-field_policy.filler_row")]
assert k, sorted(om)
assert "filler" in om[k[0]], om[k[0]]
PY

# ── W10-W11: TWO tables in one section — neither direction may leak ────────────
# The schema promises one table per `##` section, but that is a prompt-level promise
# about an LLM-written file and nothing enforces it. Rows are grouped into contiguous
# pipe BLOCKS (a markdown table ends at its first blank line), so each table gets its
# OWN header/alignment pair skipped. Both failure directions are pinned here:
#   fabrication  — a second table's HEADER cell shipping as a locked path with a real
#                  citation (invariant #5), and
#   under-lock   — a genuine [LOCKED] path in the second table being dropped, which
#                  lets a bolt modify a file the KB locked.
P_2T="$(mkproj proj-dmp-two-tables)"
mkdir -p "$P_2T/.mega-sdd/knowledge-base/99-rebuild-architecture"
printf '{"vault_version":"v1"}\n' > "$P_2T/.mega-sdd/vaults/v1/vault.json"
cat > "$P_2T/.mega-sdd/knowledge-base/99-rebuild-architecture/data-mutation-policy.md" <<'MD'
# Data mutation policy

## Per-locked-field policy

| Entity.field | Legacy source | Mandated by | Rebuild permission |
|---|---|---|---|
| app/Models/Ledger.php | ledgermast | BI Reg 23/2/2021 §4 | never modify |

| Field | Tier | Policy |
|---|---|---|
| app/Models/Invoice.php | [LOCKED] | never modify |
MD
cp "$P_DMP/.mega-sdd/vaults/v1/units/U-070.md" "$P_2T/.mega-sdd/vaults/v1/units/U-070.md"
build "$WORK/twotab.json" "$P_2T" U-070
PR_2T="$(promptof "$P_2T" U-070)"
[ "$RC" = "0" ] && ok "W10: builder exit 0 on a policy section carrying TWO markdown tables" || fail "W10: exit $RC"
$PY - "$PR_2T" <<'PY' && ok "W11: both tables' real LOCKED paths survive AND neither table's header ships as a locked path" || fail "W11: a second-table header leaked as a locked path, or a real LOCKED entry in the second table was dropped"
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r"^DO NOT MODIFY:\n((?:  - .*\n)*)", txt, re.M)
assert m, "no DO NOT MODIFY block emitted"
paths = [l.strip()[2:].split("  (source:")[0].strip() for l in m.group(1).splitlines()]
# fabrication direction: NEITHER header row may appear
for header_cell in ("Entity.field", "Field"):
    assert header_cell not in paths, (
        "table header %r shipped as a locked path (invariant #5): %s" % (header_cell, paths))
# under-lock direction: BOTH tables' real entries must be present
for real in ("app/Models/Ledger.php", "app/Models/Invoice.php"):
    assert real in paths, ("real [LOCKED] entry %r was dropped: %s" % (real, paths))
PY

echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL PASS (test-dispatch-prompt-builder-shape): $ASSERTS assertions"
  exit 0
else
  echo "FAILED: $FAILED of $ASSERTS assertion(s) (test-dispatch-prompt-builder-shape)"
  exit 1
fi
