#!/usr/bin/env bash
# test-scan-codebase-fork.sh — scan-codebase fork-READINESS contract (Phase 5a, Group B).
#
# WHY (fork-safety audit 2026-07-30, research/2026-07-30-fork-safety-audit-scan-bind.md
# §5 Group B + §6 T1): `context: fork` is UNCONDITIONAL frontmatter — a forked body IS the
# subagent prompt, has no conversation history, and cannot `AskUserQuestion` on ANY path.
# Group B converted every human-stop in scan-codebase into a named deterministic blocker
# carrying its exact re-run command. This suite pins that conversion.
#
# ─────────────────────────────────────────────────────────────────────────────
# DO NOT "FIX" THIS TEST BY ADDING `context: fork` TO THE FRONTMATTER.
# The flip is deliberately NOT taken. It is gated on two INTERACTIVE runs, per
# docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md §"5a amendment":
#   RUN 1 (pilot)   — /mega-sdd:sync on a Mode-D brownfield repo from a SUB-DIRECTORY:
#                     token before/after (Precondition 0, plugins/mega-sdd/CLAUDE.md),
#                     handoff survival to the orchestrator capture point, CWD inheritance.
#   RUN 2 (depth-2) — a `context: fork` skill attempting exactly one `Agent` dispatch;
#                     decides whether scan's default-on 5-way deep-scan stage survives.
# Headless does not count: under `claude -p`, `context: fork` silently NO-OPS
# (research/2026-07-20-fork-ab-headless-attempt.md). Audit item B13 owns the flip + bump.
# ─────────────────────────────────────────────────────────────────────────────
#
# Assertions 1–9 are fork-READINESS — the work that already shipped. They run and must
# pass TODAY, before the flip, and stay correct after it. Assertion 10 is CONDITIONAL on
# the frontmatter: pre-flip it records that the flip is still owed; the moment `context:
# fork` appears it FIRES and demands the version bump that must land with it (B13).
#
# CI-safe: bash + python3 only. No network, no fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SC="$PLUGIN_ROOT/skills/scan-codebase"
SKILL="$SC/SKILL.md"
HFH="$SC/references/halts-flags-handoff.md"
PROC="$SC/references/scan-procedure.md"

# Pre-flip version recorded by the audit. Group B shipped content at 2.20.0; the spawn-gate
# lane-split fix (see assertion 4) shipped at 2.21.0. B13 still owes a FURTHER bump in the
# same commit as `context: fork`, so post-flip must exceed the CURRENT pre-flip content
# version — keep this in step with SKILL.md's `version:` on every content change, or the
# flip/bump pairing this test enforces silently becomes free.
PREFLIP_VERSION="2.21.0"

for f in "$SKILL" "$HFH" "$PROC"; do [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }; done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
note() { echo "  NOTE: $1"; }

has() { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }

# ── 1. The non-interactive declaration lives in the ALWAYS-LOADED body ───────
# Under fork the body is the subagent prompt and the fork inherits the USER PROJECT's
# CLAUDE.md, not the plugin's — so the contract must be stated locally, not inherited.
if has "$SKILL" 'NEVER calls `AskUserQuestion`' \
   && has "$SKILL" 'Non-interactive on every path' \
   && has "$SKILL" '`--auto` is NOT semantically empty: it selects the CHAIN LANE' \
   && has "$SKILL" 'Never a prompt, never an UNRECORDED downgrade, never a wait.'; then
  pass "SKILL.md carries the non-interactive declaration (never AskUserQuestion, --auto = chain lane)"
else
  fail "SKILL.md is missing the non-interactive declaration (B1)"
fi
# Each named blocker must point at the file where its YAML actually lives. dep_missing is
# defined in halts-flags-handoff.md since v7.4.0 (it moved there when the
# tree-sitter lane + its integration ref were removed) — a pointer that names
# the wrong file sends a forked body looking for a shape it will not find.
grep -qE '`dep_missing` \(YAML in `references/halts-flags-handoff\.md`\)' "$SKILL" \
  && grep -qE '^type: dep_missing$' "$SC/references/halts-flags-handoff.md" \
  && pass "dep_missing points at halts-flags-handoff.md, where its type: shape lives (v7.4.0 home)" \
  || fail "SKILL.md misdirects dep_missing's YAML location (shape + pointer must agree)"
has "$SKILL" 'the body IS the subagent prompt' \
  && pass "declaration states WHY it is local (forked body = subagent prompt)" \
  || fail "declaration does not say why the contract is stated locally"

# ── 2. Ask-class sweep over EVERY fork-visible surface ───────────────────────
# NOT a bare `AskUserQuestion` grep — the audit found paraphrases. Sweeps SKILL.md and
# every references/*.md for the whole family (ask / confirm / prompt-a-human / offer to /
# wait for / awaiting, plus the Indonesian menunggu / bertanya / konfirmasi). Every hit
# must be claimed by an allow-list entry pinned to ONE file and ONE exact context, so the
# same paraphrase reintroduced in a DIFFERENT file still fails — that is precisely the
# audit's top failure mode ("fixed scan-procedure.md, left SKILL.md live"). Note that the
# prohibition rails themselves ("NEVER calls AskUserQuestion") are hits: they are
# allow-listed, never deleted — assertion 1 asserts their PRESENCE.
# Every allow-list entry must also match at least once (dead entries silently widen
# tolerance forever, which is how this kind of test becomes a rubber stamp).
SWEEP="$(python3 - "$SC" <<'PY'
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
  "the prohibition rail itself (assertion 1 asserts its presence)"),
 ("SKILL.md", 'User asks "siapkan context buat AI dev di repo ini"',
  "a When-to-use TRIGGER phrase — the user asking the assistant, not the skill asking the user"),
 ("SKILL.md", "never ASK, never downgrade without the record",
  "B2 prohibition rail on the spawn-cost gate, lane-split form"),
 ("SKILL.md", "creates confirmation bias",
  "'confirmation bias' — the anti-bias rationale for excluding .mega-sdd/, not a confirmation prompt"),
 ("SKILL.md", "never wait for a reply",
  "B3 prohibition on the 0-public-interfaces branch"),
 ("references/deep-scan-dispatch.md", "Confirm against codebase-map.md",
  "verify a pack hint against an ARTIFACT; no human in the loop"),
 ("references/deep-scan-dispatch.md", "deep-scan confirms in real codebase",
  "same: pack says WHERE, the scan verifies it against the repo"),
 ("references/exclusions.md", "creates confirmation bias",
  "'confirmation bias' — the anti-bias rationale"),
 ("references/halts-flags-handoff.md", "Scan tidak menebak dan tidak menunggu jawaban",
  "Indonesian prohibition inside the scan_repo_too_large keterangan"),
 ("references/halts-flags-handoff.md", "scan tidak memilih sendiri dan tidak bertanya",
  "Indonesian prohibition inside the scan_primary_app_ambiguous keterangan"),
 ("references/halts-flags-handoff.md", "**Never:** calls `AskUserQuestion`",
  "the table's Never: prohibition line (assertion 8 asserts its presence)"),
 ("references/scan-procedure.md", "bind is non-interactive on this lane, so it cannot ask",
  "attribution to bind-codebase, and it states bind CANNOT ask"),
 ("references/scan-procedure.md", "Monorepo rail (deterministic precedence — NEVER ask)",
  "B5 prohibition rail"),
 ("references/scan-procedure.md", "Never guess, never scan-all-and-hope, never ask",
  "B5 prohibition rail"),
 ("references/scan-procedure.md", "They are remedies, NOT options awaiting a reply",
  "B4 prohibition — the three re-run commands are remedies, not a menu"),
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

# ── 3. The new blockers are referenced in SKILL.md AND defined with type: ────
# The two-location conjunction of tests/drift/test-detect-drift-fork.sh:64-65 — a blocker
# named in the router but never given a YAML shape is unemittable from a fork.
for b in scan_spawn_budget_exceeded scan_repo_too_large scan_primary_app_ambiguous; do
  if grep -qF "$b" "$SKILL" && grep -qE "^type: $b\$" "$HFH"; then
    pass "$b referenced in SKILL.md + defined as type: in halts-flags-handoff.md"
  else
    fail "$b not wired (needs BOTH a SKILL.md reference and a type: YAML shape)"
  fi
done
# Each blocker must carry a re-run command — a blocker with no remedy is a dead end.
# (Assigned, not piped into a group: a pipeline runs in a subshell and would swallow the
# `fails` increment, making this assertion silently unable to fail.)
NEXT_N="$(grep -c '^next_action:' "$HFH")"
[ "$NEXT_N" -ge 3 ] \
  && pass "blocker YAMLs carry next_action re-run commands (n=$NEXT_N)" \
  || fail "blocker YAMLs missing next_action (n=$NEXT_N)"

# ── 4. B2 — the spawn-cost gate: the THREE-LANE split, in the ALWAYS-LOADED body ─
# The load-bearing edit: a fix confined to scan-procedure.md would leave an unexecutable
# directive inside the fork prompt.
#
# UPDATED (spawn-gate lane-split fix). The first cut of B2 converted this gate into an
# unconditional hard blocker. That was a LIVE REGRESSION, not a future one: the pre-B2
# `--auto` behaviour PROCEEDED, and zero orchestrate-flow routing rows carry
# `--engine`/`--include`/`--force-large`, so a chain cannot pre-resolve the gate — on
# Windows (~0.22 s/spawn) it trips at ~272 files and would have hard-stopped phase 1 of
# nearly every brownfield chain. Restoring a bare "proceed" was equally wrong: that
# re-opens the unattended multi-hour stall (100k files ~= 6.1 h) the gate was built to
# close. The shipped resolution is a LANE SPLIT, asserted below:
#   lane 1 decided (explicit --engine=/--include=) → proceed + log
#   lane 2 undecided STANDALONE                    → scan_spawn_budget_exceeded, STOP
#   lane 3 --auto (chain + every forked run)       → regex downgrade, RECORDED in 3 places
# Do not collapse this back to one outcome in either direction.
hasnt "$SKILL" 'ASK before' \
  && pass "SKILL.md no longer says 'ASK before' at the spawn-cost gate" \
  || fail "SKILL.md still carries an 'ASK before' directive (B2 not landed in the body)"
has "$SKILL" '`scan_spawn_budget_exceeded` blocker + STOP' \
  && pass "SKILL.md Step 5 emits scan_spawn_budget_exceeded and STOPs" \
  || fail "SKILL.md Step 5 does not emit the spawn-budget blocker"
# Lane 2 must be scoped to STANDALONE in the always-loaded body, or the fork prompt still
# reads as an unconditional phase-1 halt.
has "$SKILL" 'undecided STANDALONE' \
  && pass "SKILL.md scopes the blocker to the undecided STANDALONE lane" \
  || fail "SKILL.md still reads as an unconditional halt (the chain-lane regression)"
# Lane 3's condition must NOT be flag-literal on `--auto`. ZERO orchestrate-flow routing rows
# render `--auto` on the SCAN hop (phase 1 is bare `scan-codebase` / `scan-codebase
# --changed-only`; only downstream hops carry the flag), so "no --auto ⇒ standalone" would put
# every chain-dispatched scan back in lane 2 — the regression, re-created inside the fix.
if has "$SKILL" '`--auto` alone is never the discriminator' \
   && has "$PROC" 'the test is UNATTENDED-ness, and ties go to lane 3' \
   && has "$PROC" 'rows render `--auto` on the *scan* hop'; then
  pass "lane 3 keys on unattended-ness, not on the --auto literal (routing rows do not render it)"
else
  fail "lane 3 keys on the --auto literal — chain-dispatched scans would fall into the blocker lane"
fi
has "$PROC" 'The failure modes are not symmetric' \
  && pass "the ambiguous case is resolved toward lane 3, with the asymmetry stated" \
  || fail "no fail-safe tie-break between lane 2 and lane 3"
# Lane 3 must exist AND be recorded in all three surfaces.
if has "$SKILL" 'downgrade to the highest OOM-safe tier and RECORD it loudly' \
   && has "$SKILL" 'precision_downgrade_reason' \
   && has "$PROC" 'next_action.rationale'; then
  pass "SKILL.md --auto lane downgrades to the highest OOM-safe tier and records it (frontmatter + chat + handoff)"
else
  fail "SKILL.md has no recorded --auto downgrade lane — a chain halts at phase 1 or stalls for hours"
fi
has "$PROC" 'choice belongs to the user' \
  && pass "the rail survives, lane-scoped: precision choice stays with the user where there IS one" \
  || fail "SKILL.md lost the no-unrecorded-downgrade rationale"
has "$PROC" 'never a question' \
  && pass "scan-procedure spawn-cost gate states the halt is never a question" \
  || fail "scan-procedure spawn-cost gate lost the never-a-question rail"
# The remedy must terminate, or the blocker becomes a loop.
has "$PROC" 'IS the caller' && has "$HFH" 'already IS the caller' \
  && pass "an explicit --engine=/--include= suppresses the gate (the remedy terminates)" \
  || fail "no loop-termination clause on the spawn-budget remedy"

# ── 4b. The lane split's REASONING is written down, not implied ──────────────
# Two claims must be on the page, because both are non-obvious and both were re-litigated
# by the audit: (a) --auto takes the SAFEST option, and unattended "safest" is neither a
# multi-hour stall nor a phase-1 chain halt; (b) this does not break the no-silent-downgrade
# rail, because that rail protects the RECORD, not the action.
if has "$PROC" 'the SAFEST option' \
   && has "$PROC" 'phase-1 chain halt'; then
  pass "lane-3 rationale (a): --auto takes the safest option, and a phase-1 halt is not it"
else
  fail "lane-3 rationale (a) is missing — the --auto safest-option principle is not stated"
fi
has "$PROC" 'is about the record, not the action' \
  && pass "lane-3 rationale (b): the 'record, not the action' sentence is scan's own (post-5.29.0 owner)" \
  || fail "the 'record, not the action' sentence is missing"
# Since 5.29.0 the pagerank consumer rail is gone; the legitimacy argument is
# producer-stamps-own-output, stated in scan's own words.
has "$PROC" 'Producer-stamps-own-output' \
  && pass "the producer-stamps-own-output legitimacy line is written down" \
  || fail "the producer-stamps-own-output line is missing"
if has "$PROC" 'pagerank-targeting.md'; then
  fail "scan-procedure still cites the REMOVED pagerank-targeting.md"
else
  pass "no dangling citation of the removed pagerank-targeting.md"
fi
# The no-silent-downgrade paragraph must NAME the lane split, or it reads as contradicted.
if has "$PROC" 'The no-silent-downgrade rail, restated WITH the lane split' \
   && has "$PROC" 'Lane 3 does downgrade, and it is not "silent" in the sense this rail forbids'; then
  pass "the 'Do NOT silently downgrade' paragraph names the lane split (cannot read as contradicted)"
else
  fail "the no-silent-downgrade paragraph still reads as forbidding what lane 3 does"
fi
# precision_downgrade_reason must have a schema home, or lane 3's record is unspecified.
has "$SC/references/codebase-map-schema.md" 'precision_downgrade_reason' \
  && pass "precision_downgrade_reason is defined in codebase-map-schema.md" \
  || fail "lane 3 stamps a frontmatter field that no schema defines"

# ── 5. B3 — >100k files is a blocker; 0 public interfaces is NOT a halt ──────
has "$SKILL" 'emit `scan_repo_too_large` carrying the exact re-run command' \
  && pass ">100k files → scan_repo_too_large + exact re-run command (not a confirm)" \
  || fail ">100k files rule is not a named blocker with a re-run command"
has "$SKILL" '**`0 public interfaces` is NOT a halt**' && has "$SKILL" 'never wait for a reply' \
  && pass "0 public interfaces completes with a recorded re-run suggestion (never waits)" \
  || fail "0 public interfaces still reads as an instruction to wait"
has "$HFH" '**`0 public interfaces` is deliberately NOT in this list**' \
  && pass "0 public interfaces is explicitly excluded from the halted trigger list" \
  || fail "halted trigger list does not exclude 0-public-interfaces explicitly"
# A named blocker at status: completed reads downstream as a clean scan — the halting IS
# the safety property the removed prompts protected.
has "$HFH" 'Status `halted` on: `dep_missing` | `scan_spawn_budget_exceeded` (STANDALONE lane only) | `scan_repo_too_large` | `scan_primary_app_ambiguous`' \
  && pass "every new blocker sets status: halted, with the spawn gate marked STANDALONE-only inline" \
  || fail "the new blockers are not in the status: halted trigger list (or the lane marker is missing)"

# ── 6. B5 — the monorepo rail is deterministic, not a question ───────────────
hasnt "$PROC" 'ask ONCE' \
  && pass "the 'ask ONCE which app is the PRIMARY scan target' directive is gone" \
  || fail "scan-procedure still says 'ask ONCE' (B5 not landed)"
if has "$PROC" 'Explicit `--include=<glob>`' \
   && has "$PROC" 'A root manifest that owns the tree' \
   && has "$PROC" 'Exactly ONE app-root manifest' \
   && has "$PROC" 'first match wins'; then
  pass "deterministic precedence present (--include > owning root manifest > single app-root)"
else
  fail "the chosen deterministic precedence rule is missing (spec §5a amendment decision)"
fi
has "$PROC" '**Residual ambiguity only**' && has "$PROC" 'scan_primary_app_ambiguous' \
  && pass "blocker fires only on residual ambiguity" \
  || fail "residual-ambiguity branch does not route to scan_primary_app_ambiguous"
has "$PROC" 'is **not** ambiguity' \
  && pass "multi-language inside ONE app is explicitly not ambiguity" \
  || fail "the multi-language-is-not-ambiguity carve-out is missing"
has "$HFH" 'Precedence: explicit `--include` > owning root manifest > single app-root manifest' \
  && pass "the behavior table mirrors the precedence rule (surfaces cannot drift)" \
  || fail "the deterministic-behavior table does not mirror the monorepo precedence"

# ── 7. B8 — handoff emission is UNCONDITIONAL, not --auto-gated ──────────────
# Anchored on the ORIGINAL phrase ("Required ONLY under"). A naive absence-grep for
# "only under `--auto`" would red on the `**Never:**` rail, which legitimately says
# "writes a handoff only under `--auto`" as a PROHIBITION.
hasnt "$HFH" 'Required ONLY under' \
  && pass "halts-flags-handoff no longer gates the handoff on --auto" \
  || fail "halts-flags-handoff still says 'Required ONLY under \`--auto\`' (B8 not landed)"
has "$HFH" '**UNCONDITIONAL — emitted at the end of skill output on EVERY invocation**' \
  && pass "handoff emission declared UNCONDITIONAL" \
  || fail "handoff emission is not declared unconditional"
has "$HFH" 'The handoff is **required on every invocation**, not only under `--auto`.' \
  && pass "the §status close-out restates the unconditional requirement" \
  || fail "the handoff section lost its unconditional close-out"
has "$SKILL" 'on **every** invocation' && has "$SKILL" 'It is NOT `--auto`-gated' \
  && pass "SKILL.md mirrors the unconditional handoff (a direct run never injects --auto)" \
  || fail "SKILL.md still implies an --auto-gated handoff"

# ── 8. B7 — the deterministic-behavior table replaced the suppression flag ───
has "$HFH" '## Deterministic behavior (non-interactive; `--auto` selects the chain lane)' \
  && pass "deterministic-behavior section present (detect-drift auto-and-chain shape)" \
  || fail "no deterministic-behavior section"
has "$HFH" 'the one lane-dependent row' \
  && pass "the table marks the spawn-cost gate as the ONLY lane-dependent row" \
  || fail "the table does not identify which row depends on --auto"
has "$HFH" '| Site | Deterministic behavior (never prompts, never waits) |' \
  && pass "the table names an outcome per former prompt site" \
  || fail "the deterministic-behavior table header is missing"
has "$HFH" '**Never:** calls `AskUserQuestion`' \
  && pass "the table closes with the Never: prohibition line" \
  || fail "the Never: prohibition line is missing"
hasnt "$HFH" '`--auto`: skip confirmation prompts' \
  && pass "the flag catalog no longer describes --auto as prompt suppression" \
  || fail "flag catalog still reads '--auto: skip confirmation prompts' (suppression, no resolution)"
has "$HFH" '`--auto`: **selects the CHAIN LANE — it is not semantically empty.**' \
  && pass "--auto documented as the chain-lane selector, not as an empty/implied flag" \
  || fail "the flag catalog still treats --auto as semantically empty"

# ── 9. B9 — the secret-scan warning has a durable on-disk home ───────────────
# The map keeps only [REDACTED-SECRET]; a chat-only warning is swallowed by a fork, so the
# LIVE credential's file:line would exist nowhere and could not be rotated.
has "$PROC" 'write them to disk FIRST' && has "$PROC" 'SECRET-FINDINGS.md' \
  && pass "secret findings are written to SECRET-FINDINGS.md before any chat line" \
  || fail "secret findings still route to chat only (the fork would swallow them)"
has "$PROC" 'never the matched value' \
  && pass "SECRET-FINDINGS.md is a rotation worklist, never a secret store" \
  || fail "the never-the-matched-value rail is missing from the secret-findings write"
has "$HFH" 'SECRET-FINDINGS.md' \
  && pass "SECRET-FINDINGS.md is listed in the handoff artifacts[]" \
  || fail "SECRET-FINDINGS.md is not surfaced through the handoff"
has "$SKILL" 'SECRET-FINDINGS.md' \
  && pass "SKILL.md Step 10a routes findings to the durable file" \
  || fail "SKILL.md Step 10a still describes a chat-only warning"
hasnt "$HFH" 'warnings:' \
  && pass "no invented handoff warnings: key (schema carries blockers[] only)" \
  || fail "a warnings: key was invented in the handoff schema"
# The rail claims findings from EVERY scrub site reach disk. There are TWO more scrub sites
# than Step 10a — deep-scan-dispatch.md Step 10.5.3 step 6 (starterkit-context.yaml) and the
# step-3 EXCEPTION (reuse-index.yaml). The claim must not be wider than the implementation.
has "$HFH" 'Findings from EVERY scrub site are routed to disk' \
  && has "$SC/references/deep-scan-dispatch.md" 'FINDINGS ROUTING' \
  && has "$SC/references/deep-scan-dispatch.md" 'SECRET-FINDINGS.md' \
  && pass "the deep-scan scrub sites implement the routing the EVERY-site claim asserts" \
  || fail "halts-flags-handoff claims every scrub site routes to disk, but deep-scan-dispatch does not"

# ── 10. Frontmatter — CONDITIONAL on the flip (see the header) ───────────────
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

# Always true, flip or no flip: a description with a bare `key: value` parses as a nested
# mapping and breaks skill loading.
[ "$DSTR" = "True" ] && pass "description is a valid YAML scalar" \
  || fail "description is not a scalar (the colon-space frontmatter bug)"

case "$CTX" in
  None|'')
    note "context: fork NOT set — the flip is still owed (B13), gated on RUN 1 / RUN 2"
    pass "pre-flip state is consistent: fork-readiness shipped, frontmatter untouched"
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
      fail "context: fork is set but version ($VER) was not bumped past $PREFLIP_VERSION (B13 ships both)"
    fi
    ;;
  *)
    fail "unexpected frontmatter context: '$CTX' (expected absent, or 'fork' once B13 lands)"
    ;;
esac

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-scan-codebase-fork)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi
