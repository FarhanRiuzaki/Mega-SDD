#!/usr/bin/env bash
# test-bind-codebase-fork.sh — bind-codebase fork-READINESS contract (Phase 5a, Group C).
#
# WHY (fork-safety audit 2026-07-30, research/2026-07-30-fork-safety-audit-scan-bind.md
# §5 Group C + §6 T2): bind-codebase is the brownfield anti-hallucination KEYSTONE, so its
# fork work is confined to the INPUT and OUTPUT boundaries. `context: fork` is
# UNCONDITIONAL frontmatter — a forked body has no conversation history and cannot
# `AskUserQuestion` on ANY path — so Group C converted vault resolution into a
# deterministic Step 0, reattributed the one stale interactivity instruction to
# `resolve-oq`, and declared the contract in the always-loaded body.
#
# ─────────────────────────────────────────────────────────────────────────────
# DO NOT "FIX" THIS TEST BY ADDING `context: fork` TO THE FRONTMATTER.
# bind is NO-GO until the depth-2 probe returns. The flip is gated on two INTERACTIVE
# runs, per docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md
# §"5a amendment":
#   RUN 1 (pilot)   — /mega-sdd:sync on a Mode-D brownfield repo from a SUB-DIRECTORY:
#                     token before/after (Precondition 0, plugins/mega-sdd/CLAUDE.md),
#                     handoff survival, CWD inheritance.
#   RUN 2 (depth-2) — a `context: fork` skill attempting exactly one `Agent` dispatch.
#                     bind dispatches `phase-advisor` BY DEFAULT (SKILL.md Step 2.12) and
#                     that is a moat-RECALL layer; detect-drift dispatches no subagent at
#                     all, so the live fork pilot proves nothing about it. RUN 1 does NOT
#                     clear RUN 2's question.
# Headless does not count: under `claude -p`, `context: fork` silently NO-OPS
# (research/2026-07-20-fork-ab-headless-attempt.md). Audit item C9 owns the flip + bump.
# ─────────────────────────────────────────────────────────────────────────────
#
# Assertions 1–8 are fork-READINESS — the work that already shipped. They run and must
# pass TODAY, before the flip, and stay correct after it. Assertion 9 is CONDITIONAL on
# the frontmatter and FIRES the moment `context: fork` appears.
#
# UPDATED: the handoff `--auto` gate that assertion 9 was written to REPORT as an open
# flip-blocker has since been closed — emission is now unconditional at both sites, pinned
# positively by assertion 7b. Assertion 9's branch is kept as a REGRESSION guard: it still
# detects the old gating strings if either ever comes back.
#
# CI-safe: bash + python3 only. No network, no fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BC="$PLUGIN_ROOT/skills/bind-codebase"
SKILL="$BC/SKILL.md"
AMH="$BC/references/auto-memory-handoff.md"
CR="$BC/references/conflict-resolution.md"

# Pre-flip version recorded by the audit: Group C shipped its content at 2.13.0 and left
# `context:` untouched. C9 pairs the flip with a further bump, so post-flip must exceed it.
PREFLIP_VERSION="2.13.0"

for f in "$SKILL" "$AMH" "$CR"; do [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }; done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
note() { echo "  NOTE: $1"; }

has() { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }

# ── 1. The non-interactive declaration lives in the ALWAYS-LOADED body ───────
# It must be in SKILL.md, not commands/bind-codebase.md — the fork never sees the command
# file, and it inherits the USER PROJECT's CLAUDE.md rather than the plugin's.
if has "$SKILL" 'NEVER calls `AskUserQuestion`' \
   && has "$SKILL" 'never prompts on any path' \
   && has "$SKILL" 'the former `--auto` behavior is the *only* behavior'; then
  pass "SKILL.md carries the non-interactive declaration under the title (C1)"
else
  fail "SKILL.md is missing the non-interactive declaration (C1)"
fi
# The matching §Anti-hallucination rails entry — detect-drift/SKILL.md:82 shape.
has "$SKILL" '- **Non-interactive (fork-ready).** NEVER calls `AskUserQuestion` and never prompts.' \
  && pass "the non-interactive rail is present in §Anti-hallucination rails" \
  || fail "§Anti-hallucination rails has no non-interactive rail"
has "$SKILL" 'Conflict resolution belongs to `resolve-oq`, not bind' \
  && pass "the rail routes conflict resolution to resolve-oq (bind never asks, never patches)" \
  || fail "the rail does not route the KEEP_VAULT/KEEP_CODE/DEFER/SPLIT choice to resolve-oq"
# C7 — bind emits Indonesian keterangan and a fork never receives the SessionStart anchor.
has "$SKILL" '> **Instruction language:**' && has "$SKILL" 'output-language.md' \
  && pass "Instruction-language block present (a fork never receives the SessionStart anchor)" \
  || fail "no Instruction-language block — a forked bind loses its narration policy (C7)"

# ── 2. Ask-class sweep over EVERY fork-visible surface ───────────────────────
# NOT a bare `AskUserQuestion` grep — the audit found paraphrases. Sweeps SKILL.md and all
# ten references/*.md for the whole family (ask / confirm / prompt-a-human / offer to /
# wait for / awaiting, plus the Indonesian menunggu / bertanya / konfirmasi). Every hit
# must be claimed by an allow-list entry pinned to ONE file and ONE exact context, so the
# same paraphrase reintroduced in a DIFFERENT file still fails. The prohibition rails
# themselves are hits: they are allow-listed, never deleted — assertion 1 asserts their
# PRESENCE. Every allow-list entry must also match at least once, so a reworded line
# cannot leave a dead entry silently widening tolerance.
SWEEP="$(python3 - "$BC" <<'PY'
import re, os, sys, glob
root = sys.argv[1]

FAMILY = re.compile(
    r'(AskUserQuestion'
    r'|\bask(?:s|ing|ed)?\b'
    r'|\bconfirm(?:s|ing|ation)?\b'
    r'|\bprompts?\s+(?:the\s+)?(?:user|per\b)'
    r'|\b(?:confirmation|human-review|interactive)\s+prompts?\b'
    r'|\bprompts?\s+for\s+(?:a\s+|an\s+|the\s+)?(?:reply|answer|input|decision|confirmation)'
    r'|\boffer(?:s|ing|ed)?\s+to\b'
    r'|\bwait(?:s|ing|ed)?\s+for\b'
    r'|\bawait(?:s|ing)?\b'
    r'|\bmenunggu\b|\bbertanya\b|\bkonfirmasi\b)', re.I)

# (file, exact context substring, why it is legitimate under fork)
ALLOW = [
 ("SKILL.md", "NEVER calls `AskUserQuestion`",
  "the prohibition rail itself, in the title block and again in the rails (assertion 1 asserts its presence)"),
 ("SKILL.md", "Vault resolution (MANDATORY, deterministic — NEVER ask)",
  "C2 Step-0 prohibition — a prompt is not an option on any resolution branch"),
 ("references/auto-memory-handoff.md", "whether reuse confirms or rejects",
  "the shared-snapshot freshness attestation compares sha256s; no human in the loop"),
 ("references/conflict-resolution.md", "(interactive walker prompts per conflict)",
  "the flow diagram, attributed to resolve-oq's binding-mode walker — not to bind"),
 ("references/conflict-resolution.md", "`resolve-oq`'s binding-mode walker owns BOTH the confirm and the patch",
  "C4 reattribution: the confirm + patch belong to resolve-oq; the same line states bind cannot ask"),
 ("references/implementation-state.md", "triggers a human-review prompt in generate-units",
  "attributed to generate-units, a downstream interactive surface — not to bind"),
]

used = set()
violations = []
files = [os.path.join(root, "SKILL.md")] + sorted(glob.glob(os.path.join(root, "references", "*.md")))
for f in files:
    rel = os.path.relpath(f, root)
    for lineno, line in enumerate(open(f, encoding="utf-8"), 1):
        s = line.strip()
        hits = sorted(set(m.group(0) for m in FAMILY.finditer(s)))
        if not hits:
            continue
        claimed = False
        for idx, (af, ctx, _why) in enumerate(ALLOW):
            if af == rel and ctx in s:
                used.add(idx); claimed = True
        if not claimed:
            violations.append(f"{rel}:{lineno}: live ask-class directive {hits} :: {s[:150]}")

for idx, (af, ctx, _why) in enumerate(ALLOW):
    if idx not in used:
        violations.append(f"DEAD allow-list entry (reword or remove): {af} :: {ctx}")

print(f"{len(files)}|{len(ALLOW)}")
for v in violations:
    print(v)
PY
)"
SWEEP_HDR="$(printf '%s\n' "$SWEEP" | head -1)"
SWEPT_FILES="${SWEEP_HDR%%|*}"; ALLOW_N="${SWEEP_HDR##*|}"
SWEEP_OUT="$(printf '%s\n' "$SWEEP" | tail -n +2)"
if [ -z "$SWEEP_OUT" ]; then
  pass "ask-class sweep clean over $SWEPT_FILES fork-visible surfaces ($ALLOW_N allow-listed contexts, all live, 0 live directives)"
else
  fail "ask-class sweep found live directives / dead allow-list entries:"
  printf '%s\n' "$SWEEP_OUT" | sed 's/^/        /'
fi

# C4 specifically — the single genuine in-fork interactivity instruction in the skill.
hasnt "$CR" 'bind-codebase prompts user to confirm' \
  && pass "conflict-resolution no longer says 'bind-codebase prompts user to confirm'" \
  || fail "conflict-resolution still attributes the confirm prompt to bind-codebase (C4)"
has "$CR" 'never prompts and never patches the vault' \
  && pass "conflict-resolution states bind never prompts and never patches the vault" \
  || fail "conflict-resolution does not state that bind never prompts/patches"
# The SAFETY PROPERTY the prompt protected must still be enforced somewhere.
has "$CR" 'MUST NOT silently downgrade CONFLICT to OQ or auto-patch vault without user choice' \
  && pass "the no-auto-patch-without-user-choice anti-pattern rail is intact" \
  || fail "the 'without user choice' anti-pattern rail was weakened or removed"

# ── 3. bind_inputs_missing — referenced in SKILL.md AND defined with type: ───
# The two-location conjunction of tests/drift/test-detect-drift-fork.sh:64-65.
grep -qF 'bind_inputs_missing' "$SKILL" && grep -qE '^\s*type: bind_inputs_missing' "$AMH" \
  && pass "bind_inputs_missing referenced in SKILL.md + defined as type: in auto-memory-handoff.md" \
  || fail "bind_inputs_missing not wired (needs BOTH a SKILL.md reference and a type: YAML shape)"
# Closed-set discriminators — an open-ended reason field is not machine-readable.
if has "$AMH" 'missing`: `vault` | `codebase_map` | `vault_index`' \
   && has "$AMH" 'reason`: `not_found` | `vault_ambiguous` | `vault_outside_glob_root` | `malformed`'; then
  pass "bind_inputs_missing carries closed-set missing/reason discriminators"
else
  fail "bind_inputs_missing discriminators are not closed sets"
fi
has "$AMH" 'REQUIRED when `reason: vault_ambiguous`' \
  && pass "the candidate list is REQUIRED on vault_ambiguous (the caller can re-invoke)" \
  || fail "vault_ambiguous does not require a candidate list"
has "$AMH" 'next_action' \
  && pass "bind_inputs_missing carries a next_action (a blocker with no remedy is a dead end)" \
  || fail "bind_inputs_missing has no next_action"
# A Step-0 stop must never read downstream as a completion.
has "$AMH" '`bind_inputs_missing` (a Step-0 stop is a halt, not a completion' \
  && pass "bind_inputs_missing sets status: halted, never completed" \
  || fail "bind_inputs_missing is not in the status: halted trigger list"

# ── 4. C2 — the deterministic Step 0 ────────────────────────────────────────
has "$SKILL" '**Step 0 — Vault resolution (MANDATORY, deterministic — NEVER ask).**' \
  && pass "Step 0 exists in §Inputs" || fail "no deterministic Step 0 (C2)"
if has "$SKILL" '`--vault=<path>`, else the first positional arg' \
   && has "$SKILL" 'derive-state.sh --cwd=<project-root> --json-only' \
   && has "$SKILL" '**CWD probe**'; then
  pass "Step 0 resolves \$ARGUMENTS → derive-state → CWD probe, in that order"
else
  fail "Step 0's three-channel resolution order is incomplete"
fi
# R3 — `derived.vault` is the vault NAME; the PATH key is `derived.vault_path`. Asserted
# as a PRESENCE check, not a negative grep: the prose deliberately names both to pin R3.
has "$SKILL" 'derived.vault_path' \
  && pass "Step 0 names derived.vault_path (pins R3 — derived.vault is the NAME, not a path)" \
  || fail "Step 0 does not name derived.vault_path (resolving derived.vault yields a bare slug)"
has "$SKILL" 'is the vault NAME, not a path' \
  && pass "the R3 distinction is stated so a future edit cannot re-introduce it" \
  || fail "the derived.vault-is-a-name clarification is missing"
if has "$SKILL" 'never `vaults[0]`, never a guess, never a question' \
   && has "$SKILL" 'reason: vault_ambiguous'; then
  pass "ambiguity (>1 candidate) → bind_inputs_missing, never vaults[0], never a prompt"
else
  fail "Step 0 does not block on ambiguity (a silent vaults[0] binds an unintended vault)"
fi
has "$SKILL" '`VAULT_DIR` is already resolved by §Inputs **Step 0** — use it as-is; never re-resolve or widen it here' \
  && pass "Procedure step 1 consumes Step 0's VAULT_DIR (no split resolution surface)" \
  || fail "Procedure step 1 may re-resolve VAULT_DIR — two surfaces can disagree"

# ── 5. R2 — the moat-location invariant ─────────────────────────────────────
# binding.md is written under <vault>/, and validate-handoff-binding-units.sh scans four
# NON-RECURSIVE globs rooted at <cwd>/.mega-sdd/vaults/. A binding.md outside that root is
# invisible to the validator and the gate reports PASS while an active CONFLICT exists.
# This is the single path by which a fork could blind the gate.
has "$SKILL" '**Glob-root constraint — applies to all three channels.**' \
  && pass "Step 0 constrains the resolved vault to the gate's glob root" \
  || fail "Step 0 does not constrain resolution to <project-root>/.mega-sdd/vaults/ (R2)"
has "$SKILL" 'reason: vault_outside_glob_root' && has "$AMH" 'vault_outside_glob_root' \
  && pass "out-of-glob-root resolution emits bind_inputs_missing (defined in both places)" \
  || fail "vault_outside_glob_root is not wired as a blocker reason"
has "$SKILL" 'An explicit `--vault=`/positional does NOT bypass this' \
  && pass "an explicit --vault cannot bypass the glob-root constraint" \
  || fail "an explicit --vault can escape the glob root — the gate goes blind"
if has "$SKILL" 'non-recursive' && has "$SKILL" 'the gate reports PASS while an active CONFLICT exists'; then
  pass "the rail states WHY (non-recursive globs → silent PASS), not just what"
else
  fail "the glob-root rail does not state the silent-PASS mechanism it prevents"
fi
has "$SKILL" 'migrate-paths' \
  && pass "the out-of-root blocker routes to /mega-sdd:migrate-paths (a real remedy)" \
  || fail "vault_outside_glob_root is a dead end with no remedy"
# The constraint must match the globs it exists to satisfy. "under .mega-sdd/vaults/" is
# LOOSER than `vaults/*/binding.md`: a nested `vaults/<group>/<slug>/` is under the root and
# still invisible, so the wording has to bind at the DIRECT-CHILD level the globs reach.
if has "$SKILL" 'MUST be a **DIRECT CHILD** of' \
   && has "$SKILL" 'is NOT the test and is too loose'; then
  pass "the glob-root constraint is stated at direct-child level, not the looser 'under'"
else
  fail "the glob-root constraint is looser than the four non-recursive globs it must satisfy"
fi
has "$SKILL" '`vaults/*/binding.md`' \
  && pass "the rail names the actual glob patterns (a reader can check the claim)" \
  || fail "the rail asserts a reach it never shows"
has "$AMH" 'not a DIRECT CHILD' \
  && pass "the bind_inputs_missing shape mirrors the direct-child condition" \
  || fail "auto-memory-handoff still describes the looser 'outside the root' condition"

# ── 6. Negative — the skill body never WRITES .validation-blockers.json ──────
# Sole writer is scripts/validate-handoff-binding-units.sh, invoked by hooks with a
# hook-computed --cwd. Two descriptive mentions (who READS the file) are legitimate; any
# new occurrence fails, so a future refactor cannot move the write into the forkable body.
VB="$(python3 - "$BC" <<'PY'
import os, sys, glob
root = sys.argv[1]
ALLOW = [
 ("SKILL.md", "the exact token the Step 5 gate AND `validate-handoff-binding-units.sh`",
  "descriptive: names the token the gate + validator READ when materializing advisor findings"),
 ("references/binding-contract.md", "see exactly the same surface as a full re-bind",
  "descriptive: a claim-scoped re-bind rewrites binding.md whole so the READERS see the full set"),
]
used, bad = set(), []
files = [os.path.join(root, "SKILL.md")] + sorted(glob.glob(os.path.join(root, "references", "*.md")))
for f in files:
    rel = os.path.relpath(f, root)
    for lineno, line in enumerate(open(f, encoding="utf-8"), 1):
        if ".validation-blockers.json" not in line:
            continue
        s = line.strip()
        claimed = False
        for idx, (af, ctx, _w) in enumerate(ALLOW):
            if af == rel and ctx in s:
                used.add(idx); claimed = True
        if not claimed:
            bad.append(f"{rel}:{lineno}: new .validation-blockers.json mention :: {s[:150]}")
for idx, (af, ctx, _w) in enumerate(ALLOW):
    if idx not in used:
        bad.append(f"DEAD allow-list entry (reword or remove): {af} :: {ctx}")
for b in bad:
    print(b)
PY
)"
if [ -z "$VB" ]; then
  pass ".validation-blockers.json appears only in its two descriptive read-contexts (never written)"
else
  fail ".validation-blockers.json contexts changed — the write must never enter the forkable body:"
  printf '%s\n' "$VB" | sed 's/^/        /'
fi

# ── 7. The CONFLICT/OQ decision path (Steps 2–5) is UNTOUCHED ───────────────
# The audit's implementation rail: "any patch that touches the CONFLICT/OQ decision path
# while 'making it fork-safe' must be rejected on sight." All fork work is at the input
# and output boundaries. These are the load-bearing verdict strings.
MOAT_OK=1
while IFS= read -r s; do
  [ -z "$s" ] && continue
  has "$SKILL" "$s" || { fail "moat string missing from Steps 2–5: $s"; MOAT_OK=0; }
done <<'EOF'
Found but contradicts → **CONFLICT** (NEVER overridden by KB — codebase-map wins for conflicts)
**KB consultation fires ONLY when the codebase-map is silent**
**Never override a codebase-map CONFLICT via the KB.**
Project constitution gate (multi-PRD lifecycle)
This is fail-safe blocking
may NEVER auto-remove or auto-downgrade a CONFLICT (downgrade is human-only — invariant #2)
OR `advisor: unavailable` (agent error — NEVER reported as clean)
**5. Decision gate — non-negotiable:**
**DO NOT write `<vault>/bound/`.**
make-bound.sh independently refuses while any CONFLICT verdict is in binding.json
  type: bind_conflict
EOF
[ "$MOAT_OK" -eq 1 ] && pass "Steps 2–5 CONFLICT/OQ decision path intact (11 load-bearing verdict strings)"
has "$SKILL" 'Never auto-resolve CONFLICTs — always human-in-the-loop.' \
  && pass "the never-auto-resolve rail is intact" \
  || fail "the never-auto-resolve rail was removed"
# C5 — greenfield is a recorded completion, never a silent no-op a fork would swallow.
if has "$SKILL" '`claims_total == 0` → **not an error and not a halt**' \
   && has "$SKILL" 'never chat-only'; then
  pass "claims_total == 0 completes with the skip recorded on disk AND in the handoff (C5)"
else
  fail "claims_total == 0 is not recorded durably — a fork's chat is swallowed"
fi
# C6 — a fork has no conversation history, so a pointer slice is not enough.
has "$AMH" 'or any forked skill — no conversation history' \
  && pass "the memory-read fallback names the fork case (targeted Read is unconditional)" \
  || fail "the memory-read fallback does not name the fork case (C6)"

# ── 7b. The handoff is UNCONDITIONAL — asserted POSITIVELY at both sites ─────
# Assertion 9's HANDOFF_GATED branch only detects the OLD gating strings; deleting the
# handoff statement outright would clear it and pass. These pin the replacement, so both
# the removal and the restatement are required. Same defect scan closed as B8: a direct
# /mega-sdd:bind-codebase run never injects --auto, so an --auto-gated handoff emits nothing
# at all on the standalone lane — and bind's two stops (bind_conflict, bind_inputs_missing)
# are exactly the branches whose exit route would be lost.
has "$AMH" '**Emitted at the end of output on EVERY invocation**' \
  && has "$AMH" 'The handoff is **required on every invocation**, not only under `--auto`' \
  && pass "auto-memory-handoff declares handoff emission UNCONDITIONAL (both statements)" \
  || fail "auto-memory-handoff does not declare the handoff unconditional"
has "$SKILL" 'on **every** invocation, chain (`--auto`' && has "$SKILL" 'It is NOT `--auto`-gated' \
  && pass "SKILL.md §Hand-off mirrors the unconditional handoff (the fork sees only SKILL.md)" \
  || fail "SKILL.md §Hand-off still implies an --auto-gated handoff"
has "$AMH" 'The handoff YAML is STILL emitted before stopping — on EVERY invocation' \
  && pass "a Step-0 bind_inputs_missing stop emits its handoff on the standalone lane too" \
  || fail "the bind_inputs_missing stop still gates its handoff on --auto"

# ── 8. Frontmatter validity (always true, flip or no flip) ──────────────────
FM="$(python3 - "$SKILL" <<'PY'
import sys
try:
    import yaml
    d = yaml.safe_load(open(sys.argv[1]).read().split('---', 2)[1])
    print(f"{d.get('context')}|{d.get('version')}|{isinstance(d.get('description'), str)}")
except ImportError:
    fm = open(sys.argv[1]).read().split('---', 2)[1]
    ctx = 'None'; ver = '?'
    for ln in fm.splitlines():
        s = ln.strip()
        if s.startswith('context:'): ctx = s.split(':', 1)[1].strip()
        if s.startswith('version:'): ver = s.split(':', 1)[1].strip()
    print(f"{ctx}|{ver}|True")
PY
)"
CTX="${FM%%|*}"; REST="${FM#*|}"; VER="${REST%%|*}"; DSTR="${REST##*|}"
echo "  (context=$CTX version=$VER desc_is_str=$DSTR)"
[ "$DSTR" = "True" ] && pass "description is a valid YAML scalar" \
  || fail "description is not a scalar (the colon-space frontmatter bug)"

# ── 9. CONDITIONAL on the flip — these FIRE the moment context: fork lands ───
# The handoff --auto gate is the reason this is a branch and not a plain assertion. TODAY
# it is legitimate: bind runs inline, and a standalone non---auto run reports through chat
# to the human who invoked it. Under fork that chat is invisible, so a standalone forked
# bind would emit no next_action / artifacts[] / blockers[] at all — scan's B8 defect,
# which has no C-item counterpart. Pre-flip this is reported, not failed; post-flip it
# blocks. (Group C flagged it; it is an outstanding flip-blocker, not an oversight here.)
# TWO sites carry the gate, and SKILL.md is the worse one: under fork the SKILL.md body IS
# the subagent prompt. Checking only the reference would let someone fix auto-memory-
# handoff.md, flip the frontmatter, and pass while the prompt itself still says the handoff
# is --auto-conditional — the audit's top failure mode, reproduced inside the assertion
# meant to prevent it.
HANDOFF_GATED=0
HANDOFF_GATE_SITES=""
if has "$AMH" 'Required ONLY under `--auto`'; then
  HANDOFF_GATED=1
  HANDOFF_GATE_SITES="references/auto-memory-handoff.md (\"Required ONLY under \`--auto\`.\")"
fi
if has "$SKILL" 'Under `--auto` (typically `orchestrate-flow --deep` / `/mega-sdd`), emit the handoff YAML'; then
  HANDOFF_GATED=1
  HANDOFF_GATE_SITES="$HANDOFF_GATE_SITES${HANDOFF_GATE_SITES:+ + }SKILL.md §Hand-off (\"Under \`--auto\` …, emit the handoff YAML\")"
fi

case "$CTX" in
  None|'')
    note "context: fork NOT set — the flip is still owed (C9), gated on RUN 1 / RUN 2"
    pass "pre-flip state is consistent: fork-readiness shipped, frontmatter untouched"
    if [ "$HANDOFF_GATED" -eq 1 ]; then
      note "FLIP-BLOCKER: bind's handoff is still \`--auto\`-gated at: $HANDOFF_GATE_SITES"
      note "             No C-item shipped scan's B8 counterpart. Legitimate inline (an inline bind"
      note "             reports through chat to the human who invoked it); under fork a standalone"
      note "             bind would emit NO handoff at all. Fix BOTH sites before C9."
      pass "handoff --auto gate recorded as an open flip-blocker (fails once context: fork lands)"
    else
      pass "handoff is already unconditional — the flip-blocker is closed ahead of C9"
    fi
    ;;
  fork)
    # The flip landed — these now FIRE.
    python3 - "$VER" "$PREFLIP_VERSION" <<'PY'
import sys
def t(v):
    try: return tuple(int(x) for x in v.split('.')[:3])
    except Exception: return None
cur, floor = t(sys.argv[1]), t(sys.argv[2])
sys.exit(0 if cur and floor and cur > floor else 1)
PY
    if [ $? -eq 0 ]; then
      pass "context: fork + version bumped past the pre-flip $PREFLIP_VERSION ($VER)"
    else
      fail "context: fork is set but version ($VER) was not bumped past $PREFLIP_VERSION (C9 ships both)"
    fi
    if [ "$HANDOFF_GATED" -eq 1 ]; then
      fail "context: fork is set while the handoff is still --auto-gated at: $HANDOFF_GATE_SITES — a standalone forked bind emits no handoff at all"
    else
      pass "forked bind emits its handoff unconditionally"
    fi
    # C8 — a fork that cannot dispatch Agent must not ship a silent --no-advisor fallback.
    has "$SKILL" 'NEVER reported as clean' \
      && pass "advisor: unavailable is still never reported as clean under fork (C8 rail)" \
      || fail "the advisor-unavailable rail is gone — a forked bind could silently lose moat recall"
    ;;
  *)
    fail "unexpected frontmatter context: '$CTX' (expected absent, or 'fork' once C9 lands)"
    ;;
esac

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-bind-codebase-fork)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi
