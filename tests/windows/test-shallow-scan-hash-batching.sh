#!/usr/bin/env bash
# test-shallow-scan-hash-batching.sh
#
# Pins the `--shallow-scan` per-file invalidation gate in
#   plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md
# against the `shallow-scan-hash-fanout` finding (2026-07-29 Windows portability
# audit).
#
# WHY THIS IS A TEST AND NOT A CODE REVIEW: that gate is PURE PROSE — nothing in
# scripts/ or hooks/ mentions `Last_Scanned_Sha256`, so the MODEL executes it. The
# original wording ("compares each source file's current sha256 to …") carried no
# batching instruction, and the model therefore ran one `sha256sum <file>` spawn per
# file. Measured on this dev box, 501 files: one-at-a-time = 501 spawns / 13,085 ms;
# batched `xargs -0 shasum -a 256` = 1 hasher process / 448 ms (29x). Under Windows
# endpoint security a spawn costs ~220 ms instead of ~26 ms, where the same loop turns
# a sub-second gate into a multi-minute one — and since a sha256 spawn costs the same
# as a tree-sitter spawn there, the unbatched "fast path" is net-NEGATIVE.
#
# Three independent regressions are guarded:
#   A. the batching instruction + its command shape must be PRESENT and explicit
#      (vague prose is exactly how this regressed to a per-file loop);
#   B. the spawn-cost gate must budget the HASHING spawns too — it used to define
#      N as "files that will actually be extracted (after the invalidation gate)",
#      which structurally cannot see a cost paid before N exists;
#   F. the mandated command must be EXECUTABLE IN ORDER — the file it reads has to
#      be written by an earlier step that actually says so. The first fix shipped
#      `xargs -0 $HASH < "$T/files.z"` with `T="$(mktemp -d)"` in the SAME block and
#      only a comment asking Step 4 to "have THAT walk persist its result"; Step 4
#      was never touched, so the consumer read a file nothing produced and the
#      offered fallback was impossible. See §7.
#
# Every matcher runs as a function over a file path, and is ALSO run against a
# fixture reproducing the ORIGINAL pre-fix prose (§ CONTROL). If the matchers pass
# on that fixture they are inert and this suite FAILS — the `bounded-subprocess`
# lesson: a green matcher that never fires is worse than no test.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
REF="$ROOT/plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md"
SKILL="$ROOT/plugins/mega-sdd/skills/scan-codebase/SKILL.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

# ── vacuity guard 1: the file this suite is about must exist and be non-trivial ──
if [ ! -f "$REF" ]; then
  echo "FAIL (vacuity: $REF does not exist — every assertion below would pass on nothing)"
  exit 1
fi
if [ ! -f "$SKILL" ]; then
  echo "FAIL (vacuity: $SKILL does not exist)"
  exit 1
fi

# Slice the Step-5 gate region: from the Step 5 heading to the first engine branch.
# Both the invalidation gate and the spawn-cost gate live inside it, so a matcher
# cannot accidentally satisfy itself from unrelated prose elsewhere in the file.
slice() {
  awk '/^## Step 5 — Extract public interfaces/{f=1} f && /^### If `engine: tree-sitter`/{exit} f' "$1"
}
slice "$REF" > "$TMP/region.md"
region_lines=$(wc -l < "$TMP/region.md" | tr -d ' ')

# ── vacuity guard 2: the region must actually have been located ──
if [ "${region_lines:-0}" -lt 20 ]; then
  fail "vacuity: Step-5 gate region sliced to $region_lines lines — heading renamed? matchers below would inspect nothing"
  echo "FAILURES PRESENT"; exit 1
fi
# ── vacuity guard 3: the gate this suite pins must still be the sha256 gate ──
if ! grep -q 'Last_Scanned_Sha256' "$TMP/region.md"; then
  fail "vacuity: no Last_Scanned_Sha256 in the Step-5 region — this suite is pinning the wrong section"
  echo "FAILURES PRESENT"; exit 1
fi
# ── vacuity guard 4: fenced blocks in the region must be balanced ──
# Matcher E1 below detects fenced blocks by TOGGLING on every ``` line. An odd
# number of fence lines (a fence opened inside the region but closed after the
# slice boundary, or a boundary heading landing mid-fence) inverts that toggle
# for the rest of the region: E1 would then read prose as code and code as prose
# and go silently blind — the exact failure mode of the single-line regex it
# replaced. Assert parity BEFORE any matcher runs.
fences=$(grep -c '^[[:space:]]*```' "$TMP/region.md" | tr -d ' ')
if [ $(( ${fences:-0} % 2 )) -ne 0 ]; then
  fail "vacuity: odd fence count ($fences) in the Step-5 region — E1's block detection is inverted from that point on"
  echo "FAILURES PRESENT"; exit 1
fi
pass "vacuity: Step-5 gate region located ($region_lines lines, sha256 gate present, $fences fence lines — balanced)"

# ── the matchers (each: 0 = contract satisfied) ──────────────────────────────

# A1 — the batching instruction is EXPLICIT, not implied.
m_batching_stated() {
  grep -qi 'BATCHED' "$1" || return 1
  grep -qi 'ONE batched invocation' "$1" || return 1
  return 0
}

# A2 — a usable command shape is given (an instruction with no shape is how the
#      model reinvented the loop). xargs is required so the argv limit cannot bite.
m_command_shape() {
  grep -q 'xargs -0' "$1" || return 1
  grep -Eq 'sha256sum|shasum -a 256' "$1" || return 1
  # A2b — reject per-item xargs. `xargs -0 -n1 $HASH` passes every check above
  # while executing ONE hasher process PER PATH: the exact N-spawn fan-out this
  # whole section exists to remove, reintroduced by a two-character edit and
  # invisible to prose review. -L1 is the same thing spelled differently, and
  # both accept a space before the digit.
  ! grep -Eq 'xargs -0[^|&;]*[[:space:]]-(n|L)[[:space:]]?1\b' "$1" || return 1
  return 0
}

# A3 — the prohibition on the per-file loop is stated in so many words.
#      Deliberately tolerant of rewording ("do not" / "never") so a benign edit
#      does not make this go vacuous; the discriminating control in §4 still
#      proves it fires only on the fixed prose.
m_loop_prohibited() {
  grep -Eqi '(do NOT|never) loop the hasher' "$1"
}

# B  — the spawn-cost gate budgets the hashing spawns, not just extraction.
m_gate_counts_hashing() {
  grep -q 'N_hash' "$1" || return 1
  grep -q 'N_total' "$1" || return 1
  # and the estimate must be computed from the total, not from N_extract alone
  grep -Eq 'estimate[[:space:]]*=[[:space:]]*N_total' "$1" || return 1
  return 0
}

# C  — the honest windows-bash advice is present and names the net-negative regime.
m_windows_note() {
  grep -q 'OS=windows-bash' "$1" || return 1
  grep -qi 'net-negative' "$1" || return 1
  return 0
}

# D  — the ORIGINAL unbatched signature must be gone. This is the exact sentence
#      the audit quoted at scan-procedure.md:111.
m_no_original_perfile_prose() {
  ! grep -q "compares each source file's current sha256" "$1"
}

# E  — no per-file hash loop shape anywhere in the region (a runnable one-at-a-time
#      loop in a fenced block is what the model would copy).
#
#      HISTORY — this matcher was originally a SINGLE-LINE grep for
#        for X in ...; do ... sha256sum
#      An adversarial reviewer defeated it in one move by injecting the canonical
#      NUL-safe shape instead:
#        while IFS= read -r -d "" f
#        do
#          sha256sum "$f"
#        done < "$T/files.z"
#      `while` was not in the pattern at all, and one grep line cannot see a
#      multi-line body — the suite printed ALL PASS on prose that mandates exactly
#      the loop this file exists to forbid. A matcher that cannot reach the shape
#      it forbids is decoration.
#
#      E is now TWO independent checks:
#        E1 — a loop-depth machine over every fenced code block. It normalises
#             each line, counts loop openers (`for` / `while` / `until`) and
#             `done` terminators, and flags a hasher invocation seen at depth > 0.
#             This is form-agnostic: single-line, multi-line, nested, and any
#             fence in the region are all covered. Comments are stripped first so
#             the prose that FORBIDS the loop cannot itself trip the matcher.
#        E2 — the original single-line regex, kept and run over the WHOLE region,
#             so an unfenced one-liner in prose is still caught (E1 only reads
#             inside fences).
#      Deliberately NOT broadened to `$HASH`: `xargs -0 $HASH` is the sanctioned
#      shape, and a future legitimate chunked-batch loop around it must not go red.
#      The forbidden thing is the hasher named literally, one path at a time.
#      Verified identical on BSD awk (macOS), busybox awk (bash:5.3) and GNU awk 5.3.2
#      (the awk Git for Windows ships) — see the §6 controls below.
_e1_no_loop_in_fences() {
  awk '
    /^[[:space:]]*```/ { inblk = !inblk; next }
    !inblk { next }
    {
      line = $0
      sub(/[[:space:]]*#.*$/, "", line)          # comments cannot arm the matcher
      if (line ~ /^[[:space:]]*$/) next
      hasher = (line ~ /(sha256sum|shasum)/)
      t = " " line " "
      gsub(/[;&|(){}<>]/, " ", t)                # delimiters → spaces, so ` for ` matches
      c = t; n_open = gsub(/ (for|while|until) /, " ", c)
      d = t; n_done = gsub(/ done /, " ", d)
      depth += n_open
      if (depth > 0 && hasher) found = 1         # openers count BEFORE the check:
      depth -= n_done                            # a single-line loop is depth>0 on its own line
      if (depth < 0) depth = 0
    }
    END { exit(found ? 1 : 0) }
  ' "$1"
}
_e2_no_unfenced_oneliner() {
  ! grep -Eq 'for[[:space:]]+[A-Za-z_]+[[:space:]]+in[[:space:]].*;[[:space:]]*do[[:space:]].*(sha256sum|shasum)' "$1"
}
#        E3 — no shell-function wrapper around the hasher. `hash_one() { sha256sum
#             "$1"; }` called from a loop defeats E1 entirely: the hasher token sits
#             at depth 0 on the definition line, so the loop body never names it.
#             Rather than chase call graphs, forbid the wrapper — the sanctioned
#             shape is `xargs -0 $HASH`, and this document has no legitimate reason
#             to define a function around a hasher at all.
_e3_no_hasher_function() {
  ! grep -Eq '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{.*(sha256sum|shasum)' "$1"
}
m_no_perfile_loop() {
  _e1_no_loop_in_fences "$1" || return 1
  _e2_no_unfenced_oneliner "$1" || return 1
  _e3_no_hasher_function "$1" || return 1
  return 0
}

# F  — the producer/consumer chain is real: the file the hash command READS must be
#      WRITTEN by an earlier step in the same document, at a path that survives the
#      step boundary. Runs over the WHOLE reference (Step 4 is upstream of the
#      Step-5 slice, so the region alone structurally cannot see the producer —
#      which is precisely how the broken chain shipped).
m_chain_producer_exists() {  # $1 = whole reference file, $2 = its sliced Step-5 region
  local f="$1" reg="$2" cons pline sline var
  # consumer: the `xargs -0 <hasher> < "<path>"` the section mandates
  cons=$(grep -Eo 'xargs -0 [^<]*< *"[^"]+"' "$f" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
  [ -n "$cons" ] || { echo "     F: no \`xargs -0 … < \"<path>\"\` consumer found"; return 1; }
  sline=$(grep -n '^## Step 5 — Extract public interfaces' "$f" | head -1 | cut -d: -f1)
  [ -n "$sline" ] || { echo "     F: Step 5 heading not found"; return 1; }
  # producer: a `-print0 > "<same path>"` earlier in the document
  pline=$(grep -n -- '-print0' "$f" | grep -F -- "> \"$cons\"" | head -1 | cut -d: -f1)
  if [ -z "$pline" ]; then
    echo "     F: nothing in the document writes \"$cons\" with -print0 — the hash command reads a file no step produces"
    return 1
  fi
  if [ "$pline" -ge "$sline" ]; then
    echo "     F: the only producer of \"$cons\" is at line $pline, at/after Step 5 (line $sline) — a reader following the steps in order hits the consumer first"
    return 1
  fi
  # the path must not depend on shell state inherited across step invocations:
  # if it is variable-rooted, that variable must be assigned on BOTH sides.
  case "$cons" in
    '$'*)
      var=$(printf '%s' "$cons" | sed 's/^\$[{]*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/')
      grep -n "^[[:space:]]*$var=" "$f" | awk -F: -v s="$sline" '$1 < s {n++} END {exit(n?0:1)}' \
        || { echo "     F: \$$var is never assigned before Step 5 — the producer block cannot write the path"; return 1; }
      grep -Eq "(^|[[:space:]])$var=" "$reg" \
        || { echo "     F: \$$var is not re-declared inside the Step-5 block — it would be unset there (steps do not share shell state)"; return 1; }
      ;;
  esac
  return 0
}

run_all() {  # $1 = file, $2 = label; echoes PASS/FAIL per matcher, returns 0 if all hold
  local f="$1" lbl="$2" r=0
  m_batching_stated          "$f" || { echo "  [$lbl] A1 batching-stated: NO";      r=1; }
  m_command_shape            "$f" || { echo "  [$lbl] A2 command-shape: NO";        r=1; }
  m_loop_prohibited          "$f" || { echo "  [$lbl] A3 loop-prohibited: NO";      r=1; }
  m_gate_counts_hashing      "$f" || { echo "  [$lbl] B  gate-counts-hashing: NO";  r=1; }
  m_windows_note             "$f" || { echo "  [$lbl] C  windows-note: NO";         r=1; }
  m_no_original_perfile_prose "$f" || { echo "  [$lbl] D  original-prose-gone: NO"; r=1; }
  m_no_perfile_loop          "$f" || { echo "  [$lbl] E  no-per-file-loop: NO";     r=1; }
  return $r
}

echo "── 1. the live scan-procedure.md Step-5 region satisfies the contract ──"
if run_all "$TMP/region.md" live; then
  pass "batching mandated, command shape given, hashing folded into the spawn-cost gate"
else
  fail "shallow-scan hashing contract broken (see NO lines above)"
fi

echo "── 2. SKILL.md agrees with the reference (ordering + batching) ──"
if grep -q 'ONE batched invocation' "$SKILL" \
   && grep -q 'N_hash + N_extract' "$SKILL"; then
  pass "SKILL.md Step 5 states batched hashing and the total-spawn estimate"
else
  fail "SKILL.md Step 5 still implies per-file hashing / extraction-only estimate"
fi

echo "── 3. CONTROL: the matchers FIRE on the original pre-fix prose ──"
# Verbatim reconstruction of scan-procedure.md as it stood at v5.11.0 (the text the
# audit quoted). If this passes the matchers, the matchers are inert.
cat > "$TMP/before.md" <<'BEFORE'
## Step 5 — Extract public interfaces

### Per-file invalidation gate

This gate runs BEFORE tree-sitter / regex extraction below. When `--shallow-scan` flag is set AND a prior `codebase-map.md` exists in the project, the gate compares each source file's current sha256 to the `Last_Scanned_Sha256` column in prior `codebase-map.md` §2:
- File current sha256 == prior `Last_Scanned_Sha256` → REUSE prior §2 entries for this file; SKIP tree-sitter/regex re-extraction for it.
- File current sha256 != prior → re-extract symbols via tree-sitter/regex (logic below); update `Last_Scanned_Sha256` to current sha256.
- File not in prior map → re-extract symbols + add to §2 with current sha256.
- File in prior map but not in current repo enumeration → drop from §2 (file removed).

For a default scan (no `--shallow-scan`) OR `--no-cache` → SKIP gate; full re-extract for every file (correctness guarantee preserved for full scans). The gate runs BEFORE per-file extraction so it actually short-circuits the expensive per-file invocations.

### Spawn-cost gate (MANDATORY before extraction, both engines)

Before Step 5 extraction, compute:

```
N        = files that will actually be extracted (after the invalidation gate)
per_spawn = 0.22s on OS=windows-bash, else 0.02s
estimate  = N × per_spawn        # tree-sitter only; regex is ~n_languages × per_spawn
```

- `estimate` ≤ 60 s → proceed silently.
- `estimate` > 60 s → **AskUserQuestion before extracting.** State N, the estimate, and the OS.
BEFORE

# The control fixture must trip the SAME vacuity guards as the live file, otherwise
# it is not a faithful before-state.
if ! grep -q 'Last_Scanned_Sha256' "$TMP/before.md"; then
  fail "control fixture does not contain the gate — it is not a faithful before-state"
fi

echo "  (the NO lines below are EXPECTED — they are the before-state)"
if run_all "$TMP/before.md" before; then
  fail "control: the ORIGINAL prose satisfied every matcher — the matchers are inert, suite is worthless"
else
  pass "control: matchers fire on the original prose (assertion 1 is not vacuous)"
fi

# Sharper control: each individual matcher that is supposed to distinguish the two
# states must actually differ between them. A matcher that fails on BOTH files would
# make assertion 1 unreachable rather than meaningful.
echo "── 4. CONTROL (per-matcher): each matcher discriminates live vs before ──"
disc=0
for m in m_batching_stated m_command_shape m_loop_prohibited m_gate_counts_hashing m_windows_note m_no_original_perfile_prose; do
  if "$m" "$TMP/region.md" && ! "$m" "$TMP/before.md"; then
    disc=$((disc+1))
  else
    fail "control: $m does not discriminate (live=$("$m" "$TMP/region.md" && echo ok || echo no), before=$("$m" "$TMP/before.md" && echo ok || echo no))"
  fi
done
[ "$disc" -eq 6 ] && pass "control: all 6 discriminating matchers separate live from before"

# ── 5. the batching claim itself is true on this host (not just asserted in prose) ──
echo "── 5. the batched command shape actually works here ──"
D="$TMP/hashcheck"; mkdir -p "$D"
i=1; while [ "$i" -le 20 ]; do printf 'x%s\n' "$i" > "$D/f$i.txt"; i=$((i+1)); done
printf 'y\n' > "$D/with space.txt"
HASH="sha256sum"; command -v sha256sum >/dev/null 2>&1 || HASH="shasum -a 256"
find "$D" -type f -print0 | xargs -0 $HASH > "$TMP/digests.txt" 2>/dev/null
n=$(wc -l < "$TMP/digests.txt" | tr -d ' ')
if [ "${n:-0}" -eq 21 ] && grep -q 'with space' "$TMP/digests.txt"; then
  pass "one batched \`xargs -0 $HASH\` emitted $n digests including a path with a space"
else
  fail "batched hashing produced $n digests (expected 21) — the shape in the prose may not hold on this host"
fi
# CONTROL for 5: prove the digest count is load-bearing (a single file yields ONE line,
# so 21 above was not an artifact of the matcher counting something else).
one=$($HASH "$D/f1.txt" | wc -l | tr -d ' ')
[ "${one:-0}" -eq 1 ] && pass "control: one path → one digest line (the count in 5 is meaningful)" \
  || fail "control: hasher line accounting is not what this test assumes"

# ── 6. CONTROL for matcher E: it REACHES the shape it forbids, in every loop form ──
# The previous version of E was a single-line `for … ; do … sha256sum` grep. A reviewer
# injected the canonical NUL-safe multi-line `while` loop into the Step-5 region and the
# suite still printed ALL PASS. Each fixture below is the LIVE region with one per-file
# hash loop appended, so the injection is the ONLY difference from the passing state.
echo "── 6. CONTROL: matcher E fires on an injected per-file hash loop (every form) ──"
inject() {  # $1 = name, $2 = the block to append (already fenced)
  local name="$1" body="$2" f="$TMP/inj-$1.md" other=0
  cat "$TMP/region.md" > "$f"
  printf '\n%s\n' "$body" >> "$f"
  if m_no_perfile_loop "$f"; then
    fail "control: E did NOT fire on the '$name' injection — the matcher cannot reach the shape it forbids"
    return
  fi
  # E's failure must be ISOLATED: every other matcher still holds on the injected
  # fixture, so a red suite is attributable to E and not to collateral damage.
  m_batching_stated           "$f" || other=1
  m_command_shape             "$f" || other=1
  m_loop_prohibited           "$f" || other=1
  m_gate_counts_hashing       "$f" || other=1
  m_windows_note              "$f" || other=1
  m_no_original_perfile_prose "$f" || other=1
  if [ "$other" -eq 0 ]; then
    pass "control: E fires on '$name' and is the ONLY matcher that does (failure is attributable)"
  else
    fail "control: E fires on '$name' but another matcher broke too — E's signal is not isolated"
  fi
}

# 6a — the reviewer's exact injection: NUL-safe multi-line while-read loop.
inject while-multiline '```bash
while IFS= read -r -d "" f
do
  sha256sum "$f"
done < "$T/files.z"
```'
# 6b — multi-line for loop.
inject for-multiline '```bash
for f in $(cat list.txt)
do
    shasum -a 256 "$f"
done
```'
# 6c — single-line for (the ONLY shape the old matcher could see).
inject for-oneline '```bash
for f in $(cat list.txt); do sha256sum "$f"; done
```'
# 6d — single-line while.
inject while-oneline '```bash
while read -r f; do sha256sum "$f"; done < list.txt
```'
# 6e — nested loops, hasher in the inner body.
inject nested '```bash
for d in src lib
do
  while read -r f
  do
    sha256sum "$f"
  done < "$d/list"
done
```'
# 6f — unfenced one-liner in prose (E1 only reads fences; E2 must catch this).
inject unfenced 'Just run for f in $(cat list); do sha256sum "$f"; done and diff the digests.'

# Negative controls for E — shapes that MUST NOT fire, otherwise E is a tripwire that
# forbids correct prose and the next agent deletes it.
neg() {  # $1 = name, $2 = block
  local f="$TMP/neg-$1.md"
  printf '%s\n' "$2" > "$f"
  m_no_perfile_loop "$f" && pass "control: E stays quiet on '$1' (no false positive)" \
    || fail "control: E false-positives on '$1' — it forbids a correct shape"
}
neg non-hash-loop '```bash
for lang in py js go; do rg -n "def " --type "$lang"; done
```
sha256sum lives outside the loop.'
neg hasher-after-closed-loop '```bash
for lang in py js; do rg -n x; done
xargs -0 sha256sum < files.z
```'
neg prose-that-forbids-the-loop 'Never loop the hasher; do not run sha256sum once per file.
A `for` loop over languages is fine, and while we are here, batching matters.'

# ── 7. the producer/consumer chain is executable in order ──────────────────────
echo "── 7. chain: the file the hash command reads is written by an EARLIER step ──"
if m_chain_producer_exists "$REF" "$TMP/region.md"; then
  pass "chain: the \`xargs -0\` input is produced with -print0 before Step 5, at a re-declared path"
else
  fail "chain: the mandated hash command reads an artifact no earlier step produces"
fi

# CONTROL for 7: the round-1 shape — a Step 4 that never persists anything and a Step 5
# that mints its own mktemp dir then reads a files.z from it. This is the exact defect,
# and F must reject it. Without this control, F could be inert.
cat > "$TMP/broken-chain.md" <<'BROKEN'
## Step 4 — Build tree (depth-limited)

Walk dirs up to `--depth`, respect `--exclude`. Output as markdown tree.

## Step 5 — Extract public interfaces

### Per-file invalidation gate

`Last_Scanned_Sha256` comparison, batched.

```bash
T="$(mktemp -d)"
HASH="sha256sum"; command -v sha256sum >/dev/null 2>&1 || HASH="shasum -a 256"
# REUSE Step 4's enumeration — have THAT walk persist its result NUL-delimited
# (`… -print0 > "$T/files.z"`), so this step is a pure read.
xargs -0 $HASH < "$T/files.z" > "$T/hashes.txt"
```

### If `engine: tree-sitter` (default when available)
BROKEN
slice "$TMP/broken-chain.md" > "$TMP/broken-region.md"
echo "  (the F: line below is EXPECTED — it is the round-1 defect)"
if m_chain_producer_exists "$TMP/broken-chain.md" "$TMP/broken-region.md"; then
  fail "control: F accepted the round-1 broken chain — F is inert"
else
  pass "control: F rejects the round-1 broken chain (assertion 7 is not vacuous)"
fi

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
