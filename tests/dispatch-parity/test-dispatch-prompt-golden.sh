#!/usr/bin/env bash
# test-dispatch-prompt-golden.sh — the CROSS-VERSION parity harness for
# build-dispatch-prompt.sh (spec 2026-08-12-dispatch-prompt-lib-extraction.md P0).
#
# Golden corpus: tests/dispatch-parity/golden/<fixture>/ — normalized builder
# outputs COMMITTED to the repo. Any change to what the builder emits fails
# here until a human regenerates the corpus on purpose:
#
#   GOLDEN_REGEN=1 bash tests/dispatch-parity/test-dispatch-prompt-golden.sh
#
# A regen commit MUST state why the output legitimately changed. CI never
# regens. An `_lib` extraction commit accompanied by a regen is a red flag by
# definition (spec P1 rule 2 — extraction must be byte-identical).
#
# Fixtures are FRAMEWORK-LESS on purpose: no framework_pack, no manifest, so
# goldens pin BUILDER logic — a pack-body edit (laravel.md etc.) must never
# break this suite. Pack behavior is owned by the shape suite §A.
# CORPUS-FROZEN plugin docs (disclosed, deliberate — round M1): the f2 golden
# embeds the builder-INJECTED bodies of references/ui-design-heuristics.md and
# rows from references/design-intelligence/{style-principles,ux-rules}.md —
# that injection IS a builder seam an extraction must preserve byte-for-byte,
# so an edit to those three docs legitimately regens f2 (state why in the
# regen commit). No other plugin content reaches any golden.
# Normalization: fixture-root -> @PROJ@, plugin-root -> @PLUGIN@, un-normalized
# byte counters (file_total / file_bytes) -> @N@, plugin version stamp -> @VER@
# (the builder is otherwise deterministic — no datetime/random anywhere in it).
# Run: bash tests/dispatch-parity/test-dispatch-prompt-golden.sh </dev/null
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/mega-sdd"
BUILD="$PLUGIN_ROOT/scripts/build-dispatch-prompt.sh"
GOLD="$REPO_ROOT/tests/dispatch-parity/golden"
[ -f "$BUILD" ] || { echo "missing $BUILD"; exit 1; }

if [ -f "$PLUGIN_ROOT/scripts/_lib/resolve-python.sh" ]; then
  # shellcheck disable=SC1091
  . "$PLUGIN_ROOT/scripts/_lib/resolve-python.sh"
  if mega_sdd_python; then PY="$MEGA_SDD_PY"; else
    echo "SKIP: no usable python interpreter"; mega_sdd_python_remedy; exit 0
  fi
else
  echo "missing resolve-python.sh"; exit 1
fi

rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t dpgold)"
trap 'rm -rf "$WORK"' EXIT

normalize() {  # normalize <in> <out> <proj>
  # Beyond path TEXT, two derived values are machine/version-bound and must be
  # tokenized (round B1/B2, both live-proven): byte counters that measure the
  # UN-normalized file (file_total / file_bytes — their value shifts with the
  # absolute-path length of the checkout), and the plugin version stamp (would
  # redden the corpus on every release).
  # v6.10.0 catch (the length-sensitive-counter class, VERSION flavor): tier
  # content embeds the "mega-sdd v<version>" stamp, so t1/total counters are
  # version-LENGTH-sensitive — 6.7.1→6.10.0 grew t1_bytes by exactly 1 and
  # reddened the corpus; the B2 fake-9.9.9 proof had missed it because 9.9.9
  # and 6.7.1 share a LENGTH (the same shape as the mktemp path-length miss).
  # Those counters are tokenized too; intra-version drift stays covered by the
  # determinism arm (two live runs must be byte-identical INCLUDING counters).
  $PY - "$1" "$2" "$3" "$PLUGIN_ROOT" <<'EOF'
import json, os, re, sys
src, dst, proj, plug = sys.argv[1:5]
s = open(src, encoding="utf-8", errors="replace").read()
s = s.replace(proj, "@PROJ@").replace(plug, "@PLUGIN@")
s = re.sub(r"(file_total:\s*)\d+", r"\1@N@", s)
s = re.sub(r"(\"file_bytes\":\s*)\d+", r"\1@N@", s)
# inline_core embeds the ABSOLUTE dispatch path, so its byte counter is
# path-LENGTH-sensitive too (CI red 53c16f3: mac and ubuntu mktemp paths
# differ in LENGTH even when both normalize to @PROJ@ — the moved-copy proof
# missed it because same-machine mktemp paths share a length).
s = re.sub(r"(\"inline_core_bytes\":\s*)\d+", r"\1@N@", s)
s = re.sub(r"(\"t1_bytes\":\s*)\d+", r"\1@N@", s)
s = re.sub(r"(\"total_bytes\":\s*)\d+", r"\1@N@", s)
s = re.sub(r"(consumed_t1:\s*)\d+", r"\1@N@", s)
s = re.sub(r"(consumed_total:\s*)\d+", r"\1@N@", s)
# 7.10.0 catch (same class, third flavor): the tracker line is `total: N bytes`
# — the `consumed_total:` pattern above matched NOTHING after the tracker
# rename, so the version-LENGTH sensitivity came back at 7.9.0 -> 7.10.0
# (one more digit, +1 byte, corpus red). Tokenize the line as it is actually
# rendered; the determinism arm still pins intra-version byte-identity.
s = re.sub(r"(?m)^(total:\s*)\d+", r"\1@N@", s)
try:
    ver = json.load(open(os.path.join(plug, ".claude-plugin", "plugin.json")))["version"]
    s = s.replace("mega-sdd v%s" % ver, "mega-sdd v@VER@")
except Exception:
    pass
open(dst, "w", encoding="utf-8").write(s)
EOF
}

mkfix() {  # mkfix <name> -> project root; fixture content per spec P0
  local p="$WORK/$1"
  mkdir -p "$p/.mega-sdd/vaults/v1/units"
  case "$1" in
    f1-minimal)
      cat > "$p/.mega-sdd/vaults/v1/units/U-001.md" <<'MD'
---
id: U-001
title: Add the npwp column handler
task_type: create
scope: S-01
scope_name: Core
module: core
risk: low
status: pending
target_files:
  - path: app/Handlers/NpwpHandler.php
    operation: create
acceptance_test:
  - command: "run the npwp handler unit test"
    _authored_by: same-pass
---

## Intent

Add the npwp column handler with validation.

## Hard rules

- DO NOT modify app/Kernel.php
MD
      ;;
    f2-ui)
      mkdir -p "$p/.mega-sdd/codebase"
      cat > "$p/.mega-sdd/vaults/v1/units/U-002.md" <<'MD'
---
id: U-002
title: Render the nasabah detail view
task_type: create
scope: S-01
scope_name: Nasabah
module: nasabah
risk: medium
status: pending
starterkit_relevance: [ui_ux]
target_files:
  - path: resources/views/nasabah/show.blade.php
    operation: create
acceptance_test:
  - command: "run the nasabah detail feature test"
    _authored_by: same-pass
---

## Intent

Render the nasabah detail view with the npwp field.

## Hard rules

- DO NOT modify app/Models/Nasabah.php
MD
      cat > "$p/.mega-sdd/vaults/v1/vault.json" <<'JSON'
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
      cat > "$p/.mega-sdd/codebase/starterkit-context.yaml" <<'YAML'
ui_ux:
  layout_extends: layouts.app
  notification_lib: sweetalert2
  idioms:
    - toast on success
  design_tokens:
    colors:
      primary: "#2563EB"
      surface: "#F8FAFC"
    spacing: "8px scale"
    fonts:
      - Inter
YAML
      ;;
    f3-hardrules)
      cat > "$p/.mega-sdd/vaults/v1/units/U-003.md" <<'MD'
---
id: U-003
title: Refactor the interest calculator with locked signatures
task_type: modify
scope: S-01
scope_name: Core
module: core
risk: high
status: pending
target_files:
  - path: app/Services/InterestCalculator.php
    operation: modify
  - path: app/Services/RateTable.php
    operation: modify
  - path: tests/Unit/InterestCalculatorTest.php
    operation: create
acceptance_test:
  - command: "run the interest calculator unit test"
    _authored_by: adversarial-reviewed
---

## Intent

Refactor the interest calculator to read rates from RateTable while keeping
every public signature stable.

## Hard rules

- DO NOT modify app/Models/Account.php
- DO NOT modify config/banking.php
- SIGNATURE LOCK: InterestCalculator::calculate(float $principal, int $days): float
- Citation: 05-decisions.md D-004
MD
      ;;
  esac
  printf '%s' "$p"
}

run_fixture() {  # run_fixture <name> <unit> -> populates $WORK/out/<name>/
  local name="$1" unit="$2"
  local proj; proj="$(mkfix "$name")"
  local out="$WORK/out/$name"; mkdir -p "$out"
  # Full-tree snapshot BEFORE the build — the emitted-paths golden below is the
  # structural sweep (round M2): a curated copy list is blind to strays, so the
  # COMPLETE set of paths the builder created becomes a golden artifact itself.
  ( cd "$proj" && find . -type f | sort ) > "$WORK/pre.$name"
  bash "$BUILD" --cwd="$proj" --vault="$proj/.mega-sdd/vaults/v1" --unit="$unit" \
       --plugin-root="$PLUGIN_ROOT" --explain >"$out/stdout.raw" 2>"$out/stderr.raw" </dev/null
  local brc=$?
  echo "$brc" > "$out/exit-code"
  ( cd "$proj" && find . -type f | sort ) > "$WORK/post.$name"
  comm -13 "$WORK/pre.$name" "$WORK/post.$name" > "$out/emitted-paths.txt"
  local prompt="$proj/.mega-sdd/vaults/v1/bolts/$unit/dispatch-prompt.md"
  [ -f "$prompt" ] && normalize "$prompt" "$out/dispatch-prompt.md" "$proj"
  normalize "$out/stdout.raw" "$out/stdout.json" "$proj"
  normalize "$out/stderr.raw" "$out/stderr" "$proj"
  local slice="$proj/.mega-sdd/vaults/v1/lens-inputs/$unit/design-slice.md"
  [ -f "$slice" ] && normalize "$slice" "$out/design-slice.md" "$proj"
  rm -f "$out/stdout.raw" "$out/stderr.raw"
  return "$brc"
}

FIXTURES="f1-minimal:U-001 f2-ui:U-002 f3-hardrules:U-003"

# ── regen mode (manual, never CI) ────────────────────────────────────────────
# All-or-nothing (round m1): every fixture builds into $WORK first; golden/ is
# swapped only after ALL succeed — a mid-regen builder failure leaves the
# committed corpus untouched.
if [ "${GOLDEN_REGEN:-0}" = "1" ]; then
  for fx in $FIXTURES; do
    name="${fx%%:*}"; unit="${fx##*:}"
    run_fixture "$name" "$unit" || { echo "regen ABORTED (corpus untouched): builder rc=$? on $name"; exit 1; }
  done
  for fx in $FIXTURES; do
    name="${fx%%:*}"
    rm -rf "$GOLD/$name"; mkdir -p "$GOLD/$name"
    cp "$WORK/out/$name/"* "$GOLD/$name/"
    echo "regenerated golden/$name"
  done
  echo "GOLDEN CORPUS REGENERATED — commit must state why the output changed."
  exit 0
fi

# ── verify mode ──────────────────────────────────────────────────────────────
for fx in $FIXTURES; do
  name="${fx%%:*}"; unit="${fx##*:}"
  if [ ! -d "$GOLD/$name" ]; then fail "$name: golden corpus missing — run GOLDEN_REGEN=1 once and commit"; continue; fi
  run_fixture "$name" "$unit"
  BRC=$?
  [ "$BRC" -eq 0 ] && pass "$name: builder exit 0" || fail "$name: builder exit $BRC (stderr: $(head -2 "$WORK/out/$name/stderr" 2>/dev/null))"
  for g in "$GOLD/$name"/*; do
    base="$(basename "$g")"
    got="$WORK/out/$name/$base"
    if [ ! -f "$got" ]; then fail "$name/$base: builder no longer emits this artifact"; continue; fi
    if cmp -s "$g" "$got"; then pass "$name/$base: byte-identical to golden"
    else fail "$name/$base: DIVERGES from golden — first diff: $(diff "$g" "$got" | head -4 | tr '\n' ' ')"; fi
  done
  for got in "$WORK/out/$name"/*; do
    base="$(basename "$got")"
    [ -f "$GOLD/$name/$base" ] || fail "$name/$base: NEW artifact not in the golden corpus"
  done
done

# ── determinism sanity: second run of f1 must be byte-identical to the first ──
cp "$WORK/out/f1-minimal/dispatch-prompt.md" "$WORK/first-run.md" 2>/dev/null
rm -rf "$WORK/f1-minimal" "$WORK/out/f1-minimal"
run_fixture f1-minimal U-001 >/dev/null 2>&1
cmp -s "$WORK/first-run.md" "$WORK/out/f1-minimal/dispatch-prompt.md" \
  && pass "determinism: two independent f1 runs byte-identical" \
  || fail "determinism: consecutive runs diverge"

# ── path-LENGTH independence: the CI-red class made a standing arm ───────────
# Rebuild f1 under a project root of a DIFFERENT length; every normalized
# artifact must equal the standard run's. This is what catches a counter that
# measures un-normalized text (inline_core_bytes, 53c16f3) — a moved-copy or
# second-machine check can silently share path lengths; this arm cannot.
LP="$WORK/len-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
mkdir -p "$LP"
cp -R "$WORK/f1-minimal/." "$LP/" 2>/dev/null
rm -rf "$LP/.mega-sdd/vaults/v1/bolts"
LOUT="$WORK/out/len-f1"; mkdir -p "$LOUT"
bash "$BUILD" --cwd="$LP" --vault="$LP/.mega-sdd/vaults/v1" --unit=U-001 \
     --plugin-root="$PLUGIN_ROOT" --explain >"$LOUT/stdout.raw" 2>/dev/null </dev/null
normalize "$LOUT/stdout.raw" "$LOUT/stdout.json" "$LP"
normalize "$LP/.mega-sdd/vaults/v1/bolts/U-001/dispatch-prompt.md" "$LOUT/dispatch-prompt.md" "$LP"
cmp -s "$LOUT/stdout.json" "$WORK/out/f1-minimal/stdout.json" \
  && cmp -s "$LOUT/dispatch-prompt.md" "$WORK/out/f1-minimal/dispatch-prompt.md" \
  && pass "path-length independence: different-length root -> identical normalized outputs" \
  || fail "path-length independence: a counter/field still measures un-normalized text — $(diff "$LOUT/stdout.json" "$WORK/out/f1-minimal/stdout.json" 2>/dev/null | head -3 | tr '\n' ' ')"

# ── self-check: a tampered golden COPY must be caught (no vacuous pass) ──────
TAMP="$WORK/tamper"; mkdir -p "$TAMP"
if [ -f "$GOLD/f1-minimal/dispatch-prompt.md" ] && [ -f "$WORK/out/f1-minimal/dispatch-prompt.md" ]; then
  cp "$GOLD/f1-minimal/dispatch-prompt.md" "$TAMP/golden.md"
  printf 'x' >> "$TAMP/golden.md"
  cmp -s "$TAMP/golden.md" "$WORK/out/f1-minimal/dispatch-prompt.md" \
    && fail "self-check: comparator missed a 1-byte tamper" \
    || pass "self-check: comparator catches a 1-byte divergence"
else
  fail "self-check: inputs missing — cannot prove the comparator (round m3 guard)"
fi

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
