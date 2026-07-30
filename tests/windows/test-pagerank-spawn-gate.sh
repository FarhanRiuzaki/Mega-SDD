#!/usr/bin/env bash
# test-pagerank-spawn-gate.sh — generate-units Step 7.5 spawn-cost gate
# (windows-portability audit finding `pagerank-symbolgraph-ungated`).
#
# Step 7.5 rebuilds a FULL-REPO tree-sitter symbol graph — one `tree-sitter query`
# process per repo FILE, because scan-codebase does not persist the
# `name.reference.*` captures. At the ~220 ms/spawn measured on the team's Windows
# laptops (CrowdStrike EDR) a 10,000-file repo is ~37 minutes, while the reference
# documented the build as "~5-10s" — a figure calibrated on POSIX. There was no
# spawn-cost gate anywhere in the skill: the v5.11.0 gate landed only in
# scan-codebase, and its N (post-invalidation extracted files) structurally cannot
# cover this pass (the graph needs every node, not just the changed files).
#
# This test pins: the gate exists, carries the threshold + formula + per_spawn
# constant, asks via AskUserQuestion with per-option keterangan (output-language.md
# §Prompt surfaces), and that the false POSIX timing figure is gone from every surface.
#
# Round 2 (adversarial review of the round-1 patch) adds the three defects the
# reviewers found in the gate itself:
#   (a) ONE canonical definition of N — the excluded source-file set, stated in
#       pagerank-targeting.md and only there; every other surface POINTS at it.
#       Round 1 had four definitions, three of them "total repo files", a set that
#       admits node_modules/ + vendor/ + dist/ and therefore fires the gate
#       spuriously on repos that are nowhere near the threshold.
#   (b) A NAMED ZERO-SPAWN SOURCE for N. generate-units has no walk of its own, so a
#       gate that says only "compute N" would need the very walk it is gating.
#       N is read from codebase-map.md §2, which scan-codebase already wrote.
#   (c) An --auto POLICY. Without one the gate is a no-op in the autonomous lane —
#       exactly where a 37-minute stall has nobody watching. Safest = skip the pass,
#       but DECLARED (unit body + handoff warning), and never the tier drop.
#
# Run: bash tests/windows/test-pagerank-spawn-gate.sh </dev/null
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
GU="$P/skills/generate-units"
PR="$GU/references/pagerank-targeting.md"
TT="$GU/references/task-typing.md"
HP="$GU/references/halt-protocol.md"
SK="$GU/SKILL.md"
# Independent, separately-maintained file carrying the shipped v5.11.0 gate —
# used as a LIVE control that the matchers fire on real content.
CTRL="$P/skills/scan-codebase/references/scan-procedure.md"
# The artifact the gate names as its zero-spawn source for N. Owned by scan-codebase,
# maintained independently — used as a LIVE control that the pointer is not dangling.
MAP="$P/skills/scan-codebase/references/codebase-map-schema.md"

FAILED=0
CHECKS=0
ok()   { CHECKS=$((CHECKS+1)); printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { CHECKS=$((CHECKS+1)); printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
has()  { grep -qF -- "$2" "$1"; }
hasnt(){ ! grep -qF -- "$2" "$1"; }

echo "== generate-units Step 7.5 spawn-cost gate (pagerank-symbolgraph-ungated) =="

# ---------------------------------------------------------------- vacuity guard
for f in "$PR" "$TT" "$HP" "$SK" "$CTRL" "$MAP"; do
  if [ ! -s "$f" ]; then echo "  \xe2\x9c\x97 FATAL: missing or empty inspected file: $f"; exit 1; fi
done
INSPECTED=6
[ "$INSPECTED" -eq 6 ] && ok "vacuity: 6 non-empty files under inspection" \
  || { echo "FATAL vacuity"; exit 1; }

# --------------------------------------------------------------- (1) gate body
has "$PR" '## Spawn-cost gate (MANDATORY before building the symbol graph)' \
  && ok "gate section present in pagerank-targeting.md" || fail "no Spawn-cost gate section"

has "$PR" 'per_spawn = 0.22s on OS=windows-bash, else 0.02s' \
  && ok "per_spawn constant verbatim (0.22s windows-bash / 0.02s else)" || fail "per_spawn constant missing/reworded"

has "$PR" 'estimate  = N × per_spawn' \
  && ok "estimate formula N × per_spawn present" || fail "estimate formula missing"

has "$PR" '60 s' && ok "60 s threshold named" || fail "60 s threshold missing"
has "$PR" '`estimate` > 60 s' && ok "threshold wired to the ASK branch" || fail "no '> 60 s → ask' branch"
has "$PR" '`estimate` ≤ 60 s' && ok "threshold wired to the silent-proceed branch" || fail "no '≤ 60 s → proceed' branch"

has "$PR" 'N = 0 when a valid <vault>/.internal/symbol-graph.json cache exists' \
  && ok "warm cache → N = 0 (gate cannot false-fire per unit)" || fail "warm-cache N=0 rule missing"

has "$PR" 'one per FILE' && ok "one-process-per-FILE cost stated" || fail "per-FILE spawn cost not stated"
has "$PR" '220' && ok "the measured ~220 ms Windows spawn oracle cited" || fail "220 ms oracle missing"

# ------------------------------------------------- (2) AskUserQuestion keterangan
has "$PR" 'AskUserQuestion before building' \
  && ok "gate asks via AskUserQuestion (not a silent downgrade)" || fail "AskUserQuestion surface missing"
has "$PR" 'plugins/mega-sdd/references/output-language.md' \
  && ok "cites the keterangan contract (output-language.md)" || fail "keterangan contract not cited"
has "$PR" '§Prompt surfaces' && ok "cites §Prompt surfaces specifically" || fail "§Prompt surfaces citation missing"

# three options, each with a real keterangan (a bare label is a violation)
has "$PR" '**`--skip-pagerank`**' && ok "option 1: --skip-pagerank offered (verified flag, SKILL.md flag list)" || fail "option 1 missing"
has "$PR" 'tetap dari binding citations' \
  && ok "option 1 keterangan states the actual mechanic (binding-only target_files)" || fail "option 1 keterangan missing/bare"
has "$PR" '**Continue building the graph**' && ok "option 2: continue offered" || fail "option 2 missing"
has "$PR" 'Dibayar SEKALI per vault' \
  && ok "option 2 keterangan states the once-per-vault cache consequence" || fail "option 2 keterangan missing/bare"
has "$PR" '**Re-scan at regex tier**' && ok "option 3: regex tier offered" || fail "option 3 missing"
has "$PR" 'LEBIH LUAS dari Step 7.5' \
  && ok "option 3 keterangan is honest about the map-wide precision cost" || fail "option 3 keterangan missing/understated"

REC=$(grep -c '(recommended' "$PR" | tr -d ' ')
[ "$REC" = "1" ] && ok "exactly ONE recommended default in the gate" || fail "expected 1 '(recommended' marker in $PR, found $REC"

has "$PR" 'Do NOT silently downgrade' && ok "explicit no-silent-downgrade rail" || fail "no-silent-downgrade rail missing"
has "$PR" '272 files is already 60 s' && ok "'looks small' rail carries the Windows break-even (272 files)" || fail "small-repo rail missing"

# --------------------------------------- (3) the false POSIX timing figure is gone
hasnt "$PR" '~5-10s for repos <10000 files' \
  && ok "false POSIX figure '~5-10s for repos <10000 files' removed" || fail "false ~5-10s figure still present"
hasnt "$PR" 'For very large repos (>50k files), `--skip-pagerank` flag disables' \
  && ok "the >50k-files-only escape hatch sentence removed" || fail ">50k-only escape hatch still present"
hasnt "$PR" 'Total cost per unit: ~1-2s additional' \
  && ok "the '~1-2s per unit' figure (which hid the one-time full-repo build) removed" || fail "~1-2s per-unit figure still present"
has "$PR" 'windows-bash (0.22 s/spawn)' \
  && ok "performance table replaced with an OS-conditional one" || fail "OS-conditional perf table missing"
has "$PR" '~272 files on windows-bash' \
  && ok "escape-hatch threshold lowered to the real 60 s break-even" || fail "escape-hatch threshold not lowered"

# repo-wide sweep: no other surviving copy of the POSIX-calibrated figure in the skill
if grep -rqF '5-10s' "$GU"; then fail "a '5-10s' figure survives somewhere under $GU"; else ok "sweep: no '5-10s' figure left anywhere in generate-units"; fi

# ------------------------------------------------------------------ (4) wiring
has "$SK" 'version: 2.16.0' && ok "SKILL frontmatter version bumped to 2.16.0" || fail "SKILL version not bumped"
has "$SK" '**Spawn-cost gate first**' && ok "SKILL.md Step 7.5 names the gate inline" || fail "SKILL.md Step 7.5 does not name the gate"
has "$SK" 'one process per FILE over the WHOLE source set' && ok "SKILL.md carries the per-FILE cost inline" || fail "SKILL.md missing the per-FILE fact"
# ...and states it over the SOURCE set, not "the whole repo" — the loose phrasing round 1
# used, which is the same set-confusion as defect (a) wearing different clothes.
hasnt "$SK" 'over the WHOLE repo' \
  && ok "SKILL.md no longer says 'the WHOLE repo' (the inflated set)" || fail "SKILL.md still scopes the walk to 'the WHOLE repo'"
hasnt "$PR" 'one per FILE, whole repo' \
  && ok "the gate's cost table scopes invocations to N, not 'whole repo'" || fail "cost table still says 'whole repo'"
has "$PR" 'one per FILE in `N` — the entire source set' \
  && ok "cost table names N as the invocation count" || fail "cost table does not name N"
has "$PR" 'INTERACTIVE lane only' \
  && ok "the ASK branch marks itself interactive-only at the decision point" || fail "ASK branch does not exclude --auto where the decision is made"
has "$SK" 'references/pagerank-targeting.md §Spawn-cost gate' && ok "SKILL.md routes to the gate section" || fail "SKILL.md gate pointer missing"
has "$SK" '--skip-pagerank' && ok "SKILL.md flag list still spells --skip-pagerank" || fail "--skip-pagerank flag missing from SKILL.md"

has "$TT" '**Spawn-cost gate FIRST (mandatory).**' \
  && ok "task-typing.md §Step 7.5 (single owner of Step 7.5 mechanics) carries the gate" || fail "task-typing.md Step 7.5 has no gate"

has "$HP" '## Confirm gates (not halts' && ok "halt-protocol.md declares the confirm-gate class" || fail "halt-protocol.md confirm-gate section missing"
has "$HP" 'Step 7.5 spawn-cost gate' && ok "halt-protocol.md indexes the Step 7.5 gate" || fail "halt-protocol.md does not index the gate"
has "$HP" '- Confirm gates (not halts' && ok "halt-protocol.md ToC lists the new section" || fail "halt-protocol.md ToC not updated"
# the halt-vs-warning summary is an INDEX; a new class that is not in it is an unindexed class
has "$HP" 'Confirm gates (ASK, then proceed on the answer' \
  && ok "halt-vs-warning summary indexes the confirm-gate class too" || fail "halt-vs-warning summary does not list the new confirm-gate class"

# no invented halt code: the gate must NOT have grown an enum member
hasnt "$HP" 'spawn_cost' && ok "no invented halt code (closed enum preserved)" || fail "a spawn_cost halt code was invented"

has "$PR" '## Contents' && ok "pagerank-targeting.md has a ToC (now >100 lines)" || fail "ToC missing on a >100-line reference"
has "$PR" '- Spawn-cost gate (MANDATORY before building the symbol graph)' \
  && ok "ToC lists the gate section" || fail "ToC does not list the gate"

# =========================================================================== R2
# Round-2 repairs. Each block below fires RED against the round-1 text.
# ===============================================================================

# ------------------------------------------- (R2-a) ONE canonical definition of N
# Round 1 defined N four times, three of them as "total repo files" — a set that
# admits node_modules/ + vendor/ + dist/ + build/, which scan-codebase's enumeration
# explicitly excludes (scan-codebase/references/exclusions.md, the anti-bias rail).
echo "-- (a) one canonical N"

has "$PR" '**`N` is the excluded source-file set**' \
  && ok "canonical N: the EXCLUDED source-file set" || fail "canonical N definition (excluded source-file set) missing"
has "$PR" 'this section is the single owner' \
  && ok "pagerank-targeting.md declares itself the single owner of N" || fail "no single-owner declaration for N"
has "$PR" 'scan-codebase/references/exclusions.md' \
  && ok "cites the exclusion-list owner in skill-name-relative form" || fail "exclusions.md not cited (or not skill-name-relative)"
# ${CLAUDE_PLUGIN_ROOT} is not substituted in references/, and a bare `references/X.md`
# from inside a skill ref resolves ambiguously — the prefixed form is the contract.
if grep -n 'references/exclusions\.md' "$PR" | grep -qv 'scan-codebase/references/exclusions\.md'; then
  fail "a BARE references/exclusions.md (ambiguous cross-skill ref) appears in $PR"
else ok "no bare references/exclusions.md — every cite is skill-name-relative"; fi

has "$PR" '- **Not "total repo files."**' \
  && ok "the wrong set ('total repo files') is explicitly repudiated, not merely unused" || fail "no explicit repudiation of 'total repo files'"
has "$PR" 'node_modules/' && ok "names the concrete dirs a bare walk re-admits" || fail "re-admitted dirs not named"
has "$PR" 'Not `N_extract`' \
  && ok "the OTHER wrong set (scan-codebase's post-invalidation N_extract) repudiated too" || fail "N_extract repudiation missing"

# The discriminator: no surviving ASSERTIVE restatement anywhere in the skill.
# Anchored on 'N = total repo files' so the repudiation line above (which quotes the
# phrase in order to reject it) is not a false positive.
if grep -rqF -- 'N = total repo files' "$GU"; then
  fail "an assertive 'N = total repo files' restatement survives under $GU"
else ok "sweep: no 'N = total repo files' restatement anywhere in generate-units"; fi
if grep -rqF -- 'TOTAL source files in the repo' "$GU"; then
  fail "the round-1 'TOTAL source files in the repo' definition survives under $GU"
else ok "sweep: the round-1 'TOTAL source files in the repo' definition is gone"; fi

# Exactly ONE file may carry the canonical definition phrase.
OWNERS=$(grep -rlF -- 'excluded source-file set' "$GU" | wc -l | tr -d ' ')
[ "$OWNERS" = "1" ] \
  && ok "exactly ONE file under $GU carries the canonical N phrase" || fail "expected 1 owner file for the canonical N phrase, found $OWNERS"
grep -rlF -- 'excluded source-file set' "$GU" | grep -q 'pagerank-targeting\.md' \
  && ok "that one owner is pagerank-targeting.md" || fail "the canonical N phrase is not owned by pagerank-targeting.md"

# The other three surfaces must POINT, not restate.
has "$SK" 'is defined in exactly one place' \
  && ok "SKILL.md points at the single owner instead of restating N" || fail "SKILL.md does not point at the single owner of N"
has "$TT" '`N` has ONE definition, owned by' \
  && ok "task-typing.md points at the single owner instead of restating N" || fail "task-typing.md does not point at the single owner of N"
has "$HP" 'is defined in exactly one place' \
  && ok "halt-protocol.md points at the single owner instead of restating N" || fail "halt-protocol.md does not point at the single owner of N"

# ------------------------------------------------- (R2-b) named zero-spawn source
# generate-units has NO walk of its own. A gate whose N required a walk would cost
# exactly what it is gating.
echo "-- (b) zero-spawn source for N"

has "$PR" 'zero-spawn source (mandatory' \
  && ok "the gate has a labelled near-zero-spawn-source rule" || fail "no zero-spawn source named for N"
has "$PR" 'the `File` column of `codebase-map.md` §2' \
  && ok "zero-spawn source is codebase-map.md §2 (File column), an artifact that already exists" || fail "codebase-map.md §2 not named as the source"
has "$PR" 'zero spawns' && ok "states the read costs zero spawns" || fail "'zero spawns' claim missing"
has "$PR" 'has no enumeration of its own' \
  && ok "states WHY a source is needed (generate-units has no walk)" || fail "the no-walk-of-its-own rationale is missing"
has "$PR" 'files.z' \
  && ok "names scan-codebase's persisted enumeration as the Tier-1 source" || fail "files.z (Tier-1 exact source) not named"
has "$PR" 'scan-procedure.md §Step 4' \
  && ok "cites the section that actually persists files.z" || fail "§Step 4 citation missing"

# CROSS-FILE CONTROL — the citation above must match the CITED file, not merely exist.
# This is the assertion whose absence let a fabricated claim ship: an earlier revision
# said files.z "lives in a `mktemp -d` scratch file … gone by the time this skill runs",
# while scan-procedure.md says, in bold, the opposite. Citation discipline (invariant 5)
# is only enforced if something reads BOTH ends of the citation.
CTRL="$ROOT/plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md"
[ -f "$CTRL" ] || fail "control file not found: $CTRL (this check would be vacuous)"
has "$CTRL" '.mega-sdd/codebase/.scan/files.z' \
  && ok "control: scan-procedure.md really persists files.z at the cited path" \
  || fail "control: the cited path does not exist in scan-procedure.md — citation is stale or fabricated"
has "$CTRL" 'not' && has "$CTRL" 'mktemp' \
  && ok "control: scan-procedure.md explicitly rejects mktemp for that path" \
  || fail "control: scan-procedure.md no longer states the deterministic-path rule"
if grep -qF 'mktemp' "$PR" || grep -qF '$T/files.z' "$PR"; then
  fail "pagerank-targeting.md claims files.z is a mktemp scratch — refuted by scan-procedure.md"
else
  ok "no mktemp/\$T claim survives in pagerank-targeting.md (the retracted fabrication)"
fi
has "$PR" '--shallow-scan' \
  && ok "notes the REUSE branch keeps prior §2 rows (so §2 covers the WHOLE set)" || fail "the shallow-scan REUSE justification is missing"

# Both known undercounts of §2 bias AWAY from firing, so both need a rail.
has "$PR" 'a FLOOR' && ok "§2 count is declared a FLOOR, never a ceiling" || fail "no FLOOR rail on the §2 count"
has "$PR" 'truncated_sections' \
  && ok "the truncated-§2 case is handled" || fail "truncated_sections case unhandled (silent undercount)"
has "$PR" 'forces the ASK branch' \
  && ok "a truncated §2 forces the ASK branch instead of a meaningless estimate" || fail "truncated §2 does not force the ASK branch"

# The truncated-§2 rail is a BRANCH CONDITION, not the definition of N — so unlike the
# definition it MUST be reachable inline at both decision surfaces. An agent that runs
# Step 7.5 without loading $PR would otherwise read a capped §2, land under 60 s, and
# build: the same 37-min hang arriving through the undercount instead of a missing gate.
has "$SK" 'REGARDLESS of the count' \
  && ok "SKILL.md Step 7.5 carries the truncated-§2 branch condition inline" || fail "SKILL.md Step 7.5 cannot see the truncated-§2 rail (silent undercount → build)"
has "$TT" 'REGARDLESS of the count' \
  && ok "task-typing.md §Step 7.5 carries the truncated-§2 branch condition inline" || fail "task-typing.md Step 7.5 cannot see the truncated-§2 rail"
has "$SK" 'is a FLOOR' && ok "SKILL.md states the §2 count is a FLOOR" || fail "SKILL.md does not state the FLOOR property"
has "$TT" 'is a FLOOR' && ok "task-typing.md states the §2 count is a FLOOR" || fail "task-typing.md does not state the FLOOR property"

# LIVE control: the named source really has the shape the gate assumes.
has "$MAP" '## 2. Public interfaces' \
  && ok "CONTROL: codebase-map §2 really is 'Public interfaces' (pointer not dangling)" || fail "CONTROL BROKEN: codebase-map-schema.md has no §2 Public interfaces"
has "$MAP" '| File | Type | Symbol |' \
  && ok "CONTROL: §2 really carries a File column to count distinct values of" || fail "CONTROL BROKEN: §2 has no File column"

# ------------------------------------------------------- (R2-c) the --auto policy
# Every other interactive surface in this skill defines its --auto behavior; without
# one this gate is a no-op in the lane where a 37-min stall has nobody watching.
echo "-- (c) --auto policy"

has "$PR" '### `--auto` policy' \
  && ok "the gate has an explicit --auto policy section" || fail "no --auto policy — gate is a no-op in the autonomous lane"
has "$PR" 'SKIP the suggestion pass and keep generating units' \
  && ok "--auto picks the safest option: skip the pass, do not stall" || fail "--auto behaviour above threshold not stated"
has "$PR" 'Do NOT block on' \
  && ok "--auto explicitly must NOT prompt (unattended prompt = hang)" || fail "--auto does not forbid prompting"

# The tension round 1 left open: skipping silently is forbidden, yet --auto cannot ask.
# Resolution must be explicit — skip is RECORDED, tier is NEVER touched.
has "$PR" 'is not a SILENT skip' \
  && ok "tension resolved explicitly: the --auto skip is recorded, not silent" || fail "the skip-vs-no-silent-downgrade tension is left ambiguous"
has "$PR" 'SKIPPED by the Step 7.5 spawn-cost gate under `--auto`' \
  && ok "declaration surface 1: the unit body's PageRank suggestions section" || fail "no unit-body declaration of an --auto skip"
has "$PR" 'closing Hand-off summary line' \
  && ok "declaration surface 2: the closing Hand-off summary line" || fail "no second declaration surface for an --auto skip"
# ...and that surface must be REAL. The handoff YAML schema has blockers[]/metrics but no
# warnings channel; naming one would be fabrication (invariant #5).
has "$PR" 'warnings channel' \
  && ok "explicitly notes the handoff YAML has NO warnings channel (no invented field)" || fail "does not warn against inventing a handoff warnings field"
has "$PR" 'do NOT invent one' \
  && ok "the no-invented-field rail is spelled out" || fail "no-invented-field rail missing"
has "$PR" 'NEVER sets `status: halted`' \
  && ok "confirm gate never sets status: halted" || fail "status: halted not excluded for the confirm gate"
# LIVE control: the handoff schema really lacks a warnings channel and really has blockers[].
AM="$GU/references/auto-and-memory.md"
[ -s "$AM" ] || { echo "  FATAL: $AM missing"; exit 1; }
has "$AM" '  blockers: []' \
  && ok "CONTROL: handoff schema really has blockers[] (the field the gate declines to use)" || fail "CONTROL BROKEN: blockers[] not found in the handoff schema"
if grep -qE '^\s+warnings:' "$AM"; then
  fail "CONTROL: handoff schema NOW has a warnings: field — pagerank-targeting.md's 'no warnings channel' claim is stale"
else ok "CONTROL: handoff schema really has no warnings: field (the claim is true today)"; fi
has "$PR" 'Under `--auto` the regex tier is never picked.' \
  && ok "--auto may NEVER drop precision_tier (shared upstream state)" || fail "--auto is not forbidden from dropping the tier"
has "$PR" 'The ONE carve-out is the `--auto` policy above' \
  && ok "the no-silent-downgrade rail names its single carve-out" || fail "no-silent-downgrade rail and --auto policy still contradict"
has "$PR" 'Step 0.5 / Step 7.6' \
  && ok "the --auto policy is derived from the skill's own house rule, not invented" || fail "--auto policy does not cite the house rule"

# CONTROL: that house rule really exists at the sites the policy cites.
has "$SK" '`--auto` defaults to the safest option' \
  && ok "CONTROL: house rule '--auto defaults to the safest option' live in SKILL.md Step 0.5" || fail "CONTROL BROKEN: house rule not found in SKILL.md"
has "$TT" 'defaults to safest option' \
  && ok "CONTROL: the same house rule live in task-typing.md Step 7.6" || fail "CONTROL BROKEN: house rule not found in task-typing.md"

# A confirm gate must not inherit the halt-file's blanket '--auto ⇒ status: halted'.
has "$HP" 'does NOT prompt and does NOT halt' \
  && ok "halt-protocol.md states the gate neither prompts nor halts under --auto" || fail "halt-protocol.md leaves --auto behaviour of the confirm gate undefined"
has "$HP" '**Confirm gates are NOT halts**' \
  && ok "the blanket 'under --auto they set status: halted' claim is carved out" || fail "halt-protocol.md still asserts --auto ⇒ status: halted for ALL gates"

# the pointer surfaces carry the --auto policy too (an --auto run may never load $PR)
has "$SK" '`--auto` never prompts' \
  && ok "SKILL.md Step 7.5 carries the --auto policy inline" || fail "SKILL.md Step 7.5 has no --auto policy"
has "$TT" '`--auto` policy' \
  && ok "task-typing.md §Step 7.5 routes to the --auto policy" || fail "task-typing.md Step 7.5 has no --auto policy pointer"

# ------------------------------------------------------------- (5) LIVE control
# The scan-codebase spawn-cost gate is maintained independently of this patch and
# carries the same spawn oracle. If the matcher misses there, the matcher is broken —
# not the target. Matched on the two stable tokens rather than a whole sentence so a
# legitimate rewording of that file cannot red this suite.
has "$CTRL" 'per_spawn' \
  && ok "CONTROL: matcher fires on 'per_spawn' in the shipped scan-codebase gate" || fail "CONTROL BROKEN: matcher missed a known-present string"
has "$CTRL" '0.22' \
  && ok "CONTROL: the 0.22 s/spawn oracle is shared with scan-codebase (constants agree)" || fail "CONTROL BROKEN: 0.22 oracle not found in scan-procedure.md"

# ------------------------------------------------------ (6) BEFORE-STATE control
# Static fixture reproducing the pre-fix text. The positive matchers must NOT fire
# on it (proves they are not globally-true / vacuous) and the absence-matchers MUST
# fire on it (proves they can detect the regression they guard).
FIX="$(mktemp -t pagerank-before.XXXXXX)"
trap 'rm -f "$FIX"' EXIT
cat > "$FIX" <<'BEFORE'
# PageRank Symbol-Graph Targeting

## Detection prerequisites

Requires `engine: tree-sitter` in `codebase-map.md` frontmatter. If precision tier is `regex`, PageRank is SKIPPED — fallback to binding-only target_files.

## Performance

- Symbol graph build: ~1s for repos <1000 files; ~5-10s for repos <10000 files
- PageRank computation: <500ms per unit on typical repo size
- Total cost per unit: ~1-2s additional vs v1.5

For very large repos (>50k files), `--skip-pagerank` flag disables the suggestion pass; falls back to v1.5 behavior.
BEFORE

! has "$FIX" '## Spawn-cost gate (MANDATORY before building the symbol graph)' \
  && ok "BEFORE: gate matcher correctly does NOT fire on the pre-fix text" || fail "BEFORE control: gate matcher fires on text that has no gate"
! has "$FIX" 'per_spawn = 0.22s on OS=windows-bash, else 0.02s' \
  && ok "BEFORE: per_spawn matcher correctly does NOT fire on the pre-fix text" || fail "BEFORE control: per_spawn matcher is vacuous"
has "$FIX" '~5-10s for repos <10000 files' \
  && ok "BEFORE: the absence-matcher CAN detect the false figure (fires on pre-fix text)" || fail "BEFORE control: absence-matcher cannot see the string it guards"
has "$FIX" 'For very large repos (>50k files), `--skip-pagerank` flag disables' \
  && ok "BEFORE: the >50k absence-matcher fires on pre-fix text" || fail "BEFORE control: >50k matcher broken"

# ------------------------------------------- (7) ROUND-1-STATE control (defects a/b/c)
# The round-1 patch text, verbatim in the parts the round-2 review flagged. The new
# matchers must NOT fire on it (they would be vacuous otherwise) and the sweeps MUST
# detect the divergent N (they would be blind otherwise).
R1DIR="$(mktemp -d -t pagerank-r1.XXXXXX)"
trap 'rm -f "$FIX"; rm -rf "$R1DIR"' EXIT
cat > "$R1DIR/pagerank-targeting.md" <<'ROUND1'
## Spawn-cost gate (MANDATORY before building the symbol graph)

Before Step 1, compute:

```
N        = TOTAL source files in the repo (graph nodes per Step 1) —
           NOT the post-invalidation count scan-codebase's own gate used;
           N = 0 when a valid <vault>/.internal/symbol-graph.json cache exists
per_spawn = 0.22s on OS=windows-bash, else 0.02s
estimate  = N × per_spawn
```

Do NOT silently downgrade to `--skip-pagerank` or to the regex tier.
ROUND1
cat > "$R1DIR/task-typing.md" <<'ROUND1TT'
- **Spawn-cost gate FIRST (mandatory).** ... estimate `N x per_spawn` — N = total repo files (0 on a warm `<vault>/.internal/symbol-graph.json`) ...
ROUND1TT

R1="$R1DIR/pagerank-targeting.md"
! has "$R1" '**`N` is the excluded source-file set**' \
  && ok "ROUND-1: canonical-N matcher correctly does NOT fire on the round-1 text" || fail "ROUND-1 control: canonical-N matcher is vacuous"
! has "$R1" 'Zero-spawn source (mandatory' \
  && ok "ROUND-1: zero-spawn-source matcher correctly does NOT fire on the round-1 text" || fail "ROUND-1 control: zero-spawn matcher is vacuous"
! has "$R1" '### `--auto` policy' \
  && ok "ROUND-1: --auto-policy matcher correctly does NOT fire on the round-1 text" || fail "ROUND-1 control: --auto matcher is vacuous"
! has "$R1" 'The ONE carve-out is the `--auto` policy above' \
  && ok "ROUND-1: the tension-resolution matcher does NOT fire on the round-1 rail" || fail "ROUND-1 control: carve-out matcher is vacuous"

# the sweeps must SEE the round-1 divergence they guard against
grep -rqF -- 'TOTAL source files in the repo' "$R1DIR" \
  && ok "ROUND-1: the 'TOTAL source files' sweep fires on the round-1 tree" || fail "ROUND-1 control: sweep cannot see the definition it guards"
grep -rqF -- 'N = total repo files' "$R1DIR" \
  && ok "ROUND-1: the 'N = total repo files' sweep fires on the round-1 tree" || fail "ROUND-1 control: sweep cannot see the divergent restatement"
R1OWNERS=$(grep -rlF -- 'excluded source-file set' "$R1DIR" | wc -l | tr -d ' ')
[ "$R1OWNERS" = "0" ] \
  && ok "ROUND-1: the single-owner count is 0 there (so '==1' is a real discriminator)" || fail "ROUND-1 control: canonical phrase present in round-1 text"

echo "-- $CHECKS assertions executed"
[ "$CHECKS" -gt 60 ] || { echo "  \xe2\x9c\x97 FAIL: vacuity guard — only $CHECKS assertions ran"; FAILED=1; }

if [ "$FAILED" -eq 0 ]; then echo "ALL PAGERANK SPAWN-GATE PINS OK"; else echo "pagerank spawn-gate pins FAILED"; fi
exit $FAILED
