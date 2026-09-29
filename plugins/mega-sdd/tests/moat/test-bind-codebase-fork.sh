#!/usr/bin/env bash
# test-bind-codebase-fork.sh — the CONFLICT/OQ decision path survives the whole-vault bind removal.
#
# HISTORY: this file used to pin the fork-READINESS contract of the classic whole-vault bind
# skill (fork-safety audit 2026-07-30, Group C: the non-interactive declaration, the ask-class
# sweep, the deterministic Step-0 vault resolution + `bind_inputs_missing`, the R2 glob-root
# rail, the unconditional handoff, the frontmatter, and the conditional `context: fork` flip).
# 9.0 P1 (docs/superpowers/specs/2026-09-27-v9-simplification-design.md §3 "bind-codebase —
# REMOVE (P1)") deleted that skill: the whole-vault bind is replaced by the JIT per-unit bind
# inside execute-bolts. Every fork-readiness assertion pinned content of the deleted skill,
# so those assertions were RETIRED with it — the fork flip (audit item C9) is moot because
# there is no longer a bind skill to fork.
#
# What SURVIVES is the part the old assertion 7 existed to protect: "any patch that touches
# the CONFLICT/OQ decision path must be rejected on sight." That path was relocated, not
# deleted, and it is pinned here at its new homes (same load-bearing strings, reworded only
# where the relocation changed the evidence source from codebase-map to code evidence):
#   - skills/execute-bolts/references/jit-bind-and-quarantine.md §3.9 + §E3 (verdict ladder,
#     KB rails, the dispatch-time CONFLICT gate)
#   - skills/resolve-oq/references/binding-mode.md (human-only resolution, the sole writer)
#   - skills/plan/references/context-authoring.md (the project constitution gate)
#   - references/halt-families/bind.md (a layout-2 CONFLICT still blocks — spec §7 #9)
# The classic `bound/` artefact strings (Step-5 decision gate heading, "DO NOT write bound/",
# the bound/ writer's refusal sentence) were retired: the lite lane produces no `bound/`, and
# 9.0 P1b deleted that writer. The layout-2 CONFLICT refusal stays pinned empirically on its
# surviving carrier, validate-handoff-binding-units.sh (tests/moat/test-conflict-unresolved.sh).
#
# CI-safe: bash + python3 only. No network, no fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JIT="$PLUGIN_ROOT/skills/execute-bolts/references/jit-bind-and-quarantine.md"
BM="$PLUGIN_ROOT/skills/resolve-oq/references/binding-mode.md"
CA="$PLUGIN_ROOT/skills/plan/references/context-authoring.md"
HF="$PLUGIN_ROOT/references/halt-families/bind.md"

for f in "$JIT" "$BM" "$CA" "$HF"; do [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }; done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

has() { grep -qF -- "$2" "$1"; }
# Whitespace-normalized containment: the relocated prose is hard-wrapped, so a phrase that
# spans a line break is matched after collapsing runs of whitespace (the wording itself
# must still match exactly).
hasn() {
  python3 - "$1" "$2" <<'PY'
import re, sys
text = re.sub(r'\s+', ' ', open(sys.argv[1], encoding='utf-8').read())
sys.exit(0 if re.sub(r'\s+', ' ', sys.argv[2]) in text else 1)
PY
}

# ── 1. The CONFLICT/OQ verdict strings (was assertion 7, repointed to JIT bind §E3) ──
# Old → new:
#   "Found but contradicts → **CONFLICT** (NEVER overridden by KB — codebase-map wins …)"
#       → rung 6 "contradicting evidence found anywhere → **CONFLICT**;" + the KB rail below
#   "**KB consultation fires ONLY when the codebase-map is silent**"
#       → "... when the code evidence (rungs 1–4) is silent." (evidence source changed)
#   "**Never override a codebase-map CONFLICT via the KB.**"
#       → "**Never override a code CONFLICT via the KB.**"
MOAT_OK=1
while IFS= read -r s; do
  [ -z "$s" ] && continue
  has "$JIT" "$s" || { fail "moat string missing from jit-bind-and-quarantine.md §E3: $s"; MOAT_OK=0; }
done <<'EOF'
contradicting evidence found anywhere → **CONFLICT**;
**KB consultation fires ONLY when the code evidence (rungs 1–4) is silent.**
**Never override a code CONFLICT via the KB.**
- **CONFLICT**: claim contradicts code evidence
EOF
[ "$MOAT_OK" -eq 1 ] && pass "JIT bind §E3 carries the CONFLICT/OQ verdict rails (contradiction → CONFLICT; KB only when code is silent; KB never overrides a code CONFLICT)"

# ── 2. The decision gate (was "**5. Decision gate — non-negotiable:**" + `type: bind_conflict`) ──
# The CONFLICT gate (spec v9 §8.5; the per-dispatch hook leg was removed in P3, §8.6): an unresolved
# CONFLICT halts `binding_conflict`, ALWAYS STOPs that unit, and is enforced by the run-start
# quarantine, each task's re-bind and the `conflict_bypassed` run-boundary gate.
if hasn "$JIT" 'FAIL with `conflict_unresolved` drops ⇒ **halt `binding_conflict`** — ALWAYS STOP for those units' \
   && hasn "$JIT" 'The gate is the run-start quarantine (`derive-exec-plan.sh`), each task'"'"'s re-bind, and `conflict_bypassed` at the run boundary and on Stop.'; then
  pass "JIT bind §3.9 decision gate: conflict_unresolved ⇒ halt binding_conflict, ALWAYS STOP, enforced at run start + each re-bind + conflict_bypassed"
else
  fail "JIT bind §3.9 lost the non-negotiable CONFLICT decision gate (halt binding_conflict / run-start quarantine + conflict_bypassed)"
fi
# The legacy halt name still blocks on a not-yet-migrated layout-2 vault (spec §7 #9).
has "$HF" '`bind_conflict` — the legacy name (a layout-2 `binding.md`) of `binding_conflict`. An existing layout-2 vault with an unresolved CONFLICT still blocks `execute-bolts` (moat invariant #2). ALWAYS STOP.' \
  && pass "halt-families/bind.md: a layout-2 bind_conflict still blocks execute-bolts (ALWAYS STOP)" \
  || fail "halt-families/bind.md no longer states that a layout-2 unresolved CONFLICT blocks execute-bolts"
# The verdict file is script-owned evidence: the model cannot hand-write a verdict past the gate.
has "$JIT" 'Write/Edit/Bash to it is denied; only the writer changes it.' \
  && pass "per-unit binding.json is hook-guarded evidence with one writer" \
  || fail "JIT bind no longer states binding.json is hook-guarded with a single writer"

# ── 3. Human-only resolution (was the never-auto-resolve rail + conflict-resolution C4 rail) ──
# Old: "Never auto-resolve CONFLICTs — always human-in-the-loop." and
#      "MUST NOT silently downgrade CONFLICT to OQ or auto-patch vault without user choice".
# New home: resolve-oq binding mode, which is now the only CONFLICT resolver.
has "$BM" '- **Never auto-resolve conflicts.** Always user choice per row.' \
  && pass "resolve-oq binding mode: never auto-resolve conflicts, user choice per row" \
  || fail "the never-auto-resolve rail was removed from resolve-oq binding mode"
has "$BM" 'writes back ONLY via `write-unit-binding.sh --resolve=<C-id>=<ACTION> --by=user`' \
  && has "$BM" 'The file is hook-guarded evidence (one writer); never Edit it.' \
  && pass "a CONFLICT resolution is written only by the writer, attributed --by=user (no silent patch)" \
  || fail "resolve-oq binding mode no longer restricts the write-back to write-unit-binding.sh --by=user"
# The only CONFLICT → OQ downgrade is the user's explicit DEFER choice — never silent.
has "$BM" '(DEFER = the `[D]` option: the CONFLICT is downgraded to an OQ the unit carries, the unit'"'"'s gate opens)' \
  && pass "CONFLICT → OQ downgrade happens only through the user's [D] DEFER choice" \
  || fail "the CONFLICT → OQ downgrade is no longer tied to the user's explicit DEFER choice"

# ── 4. Project constitution gate (was a bind Step-2..5 string, relocated to plan) ──
if has "$CA" '## Project constitution gate (multi-PRD lifecycle)' \
   && has "$CA" 'it is surfaced, never silently accepted'; then
  pass "plan context-authoring carries the project constitution gate (contradiction → surfaced OQ, never silently accepted)"
else
  fail "the project constitution gate is missing from plan/references/context-authoring.md"
fi

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-bind-codebase-fork)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi
