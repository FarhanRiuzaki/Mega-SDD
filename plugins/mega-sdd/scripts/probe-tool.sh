#!/usr/bin/env bash
# probe-tool.sh — owns install-deps' bounded execution-probe ladder (audit
# Phase-2b spec 2026-08-11-audit-phase2b-scripts-and-owners.md §S2).
#
# Source of truth for the ladder's WHY: skills/install-deps/SKILL.md Steps 2/6
# + rails 12-13, and references/os-detection.md. This script makes the
# false-`missing` class structurally impossible.
#
# Contract:
#   probe-tool.sh --verify-cmd='<cmd>' [--tool=<id>] [--bound=<seconds>]
# Output: ONE line
#   <verdict> bound=<N>s rc=<rc>     verdict ∈ present|missing|slow-verify|probe-inconclusive
# Exit 0 ALWAYS — the verdict is the output, never the exit code.
#
# The ladder (field lessons baked in — do not re-derive at call sites):
# 1. BOUND resolution: `timeout -k 2 <N>` else `gtimeout -k 2 <N>` else EMPTY.
#    Stock macOS ships NEITHER; a literal prefix there exits 127 on every
#    probe and would report every installed tool `missing` (SKILL rail 13).
#    When BOUND is empty the probe runs unbounded and the line reports
#    bound=0s — the absence of the bounding utility is NEVER a verdict about
#    the probed tool.
# 2. `-k 2` escalation: GNU timeout sends SIGTERM then WAITS; under Git Bash
#    (MSYS2) SIGTERM lands via an injected ExitProcess thread with a ~10s
#    TerminateProcess overshoot — `-k 2` makes the ceiling a number this
#    script owns. Flag BEFORE duration (the reverse order is a 127 parse
#    error).
# 3. `command -v` pre-filter FIRST (SKILL Step 2.2): name not on PATH →
#    `missing` immediately, no exec probe (rail 12: never exec a tool
#    command -v reported absent). A `command -v` HIT is never sufficient on
#    its own — Windows App Execution Alias stubs resolve on PATH and exit 49
#    (rail 8), so promotion to `present` requires the execution probe.
# 4. `sh -c` wrapping when the cmd carries `||` `&&` `|` `;`: substituted
#    bare, the shell parses the operator at the TOP level — the fallback limb
#    runs unbounded AND swallows the 124/137 the bound just produced (SKILL
#    Step 2.3: the `||`-escapes-the-bound lesson).
# 5. resolve-python carve-out: a python verify cmd routes through
#    scripts/_lib/resolve-python.sh (WindowsApps stub rejection + the
#    python3→python→py -3 ladder) — SKILL Step 2.5.
# 6. Verdict map (SKILL Steps 2/6 verdict table is authoritative):
#      rc 0          → present
#      rc 124 | 137  → slow-verify   (present-ish: the bound fired; BOTH codes
#                      carry the same verdict — a native .exe that ignores
#                      SIGTERM exits 137; NEVER missing)
#      rc 127        → probe-inconclusive UNCONDITIONALLY: the `command -v`
#                      pre-filter already proved the name resolves before any
#                      probe ran (an absent name is reported missing WITHOUT
#                      executing — that path stands), so a 127 here means the
#                      probe LAYER could not run — the SKILL Step-2 verdict
#                      table + rail 12 are the source of truth: "127 NEVER
#                      means missing" once presence is proven
#      any other rc  → missing       (incl. the WindowsApps stub's 49:
#                      presence ≠ usability; propose the real install)
#    The exit code is the verdict — never gate on a stdout pattern (semgrep
#    prints an upgrade banner before its version).
#
# --bound=<seconds> (default 10; a non-numeric value falls back to 10) exists
# for callers/tests that need a tighter ceiling; the output line always
# reports the bound actually applied.
# Read-only: writes nothing but the stdout line.

set -u

VERIFY_CMD=""
TOOL=""
BOUND_SECS=10
for arg in "$@"; do
  case "$arg" in
    --verify-cmd=*) VERIFY_CMD="${arg#*=}" ;;
    --tool=*) TOOL="${arg#*=}" ;;
    --bound=*) BOUND_SECS="${arg#*=}" ;;
  esac
done

# --bound must be a positive integer; anything else falls back to the
# default (a malformed bound must never reach the timeout prefix).
case "$BOUND_SECS" in
  ''|*[!0-9]*) BOUND_SECS=10 ;;
esac

if [ -z "$VERIFY_CMD" ]; then
  echo "probe-inconclusive bound=0s rc=2"
  exit 0
fi

# ── 1. BOUND resolution (never hard-code the prefix at a probe site) ────────
if command -v timeout >/dev/null 2>&1; then
  BOUND="timeout -k 2 $BOUND_SECS"
elif command -v gtimeout >/dev/null 2>&1; then
  BOUND="gtimeout -k 2 $BOUND_SECS"
else
  BOUND=""
  BOUND_SECS=0   # reported as bound=0s: probes unbounded on this machine
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)}"

FIRST_WORD="${VERIFY_CMD%%[[:space:]]*}"
NAME="${TOOL:-$FIRST_WORD}"

# ── 5. resolve-python carve-out (SKILL Step 2.5) ────────────────────────────
IS_PYTHON=0
case "$NAME" in
  python3|python|py) IS_PYTHON=1 ;;
esac

if [ "$IS_PYTHON" = 1 ]; then
  # The resolver owns stub rejection + the name ladder; carries the SAME
  # resolved prefix and the same 124/137/127 carve-out as any other probe.
  ( $BOUND bash -c '. "'"$PLUGIN_ROOT"'/scripts/_lib/resolve-python.sh" && mega_sdd_python && $MEGA_SDD_PY -V' ) >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0)       v="present" ;;
    124|137) v="slow-verify" ;;
    127)     v="probe-inconclusive" ;;   # probe layer failed; never missing
    *)       v="missing" ;;              # resolver found no usable interpreter
  esac
  echo "$v bound=${BOUND_SECS}s rc=$rc"
  exit 0
fi

# ── 3. command -v pre-filter (mandatory ordering, SKILL Step 2.2) ───────────
if ! command -v "$NAME" >/dev/null 2>&1; then
  echo "missing bound=${BOUND_SECS}s rc=127"
  exit 0
fi

# ── 4. operator detection → one bounded shell (SKILL Step 2.3) ──────────────
WRAP=0
case "$VERIFY_CMD" in
  *"||"*|*"&&"*|*"|"*|*";"*) WRAP=1 ;;
esac

# ── 2. run the bounded probe (subshell: a builtin like `exit` in the cmd
#       must terminate the PROBE, never this script) ─────────────────────────
# The brace group's 2>/dev/null silences the SHELL's job-control lines
# ("Segmentation fault: 11"): bash exec-optimizes the single-command
# subshell, so a probe killed by a signal is reaped by THIS script's shell,
# which reports to the script's stderr — OUTSIDE the subshell redirection —
# breaking the ONE-line contract for 2>&1 callers.
if [ "$WRAP" = 1 ]; then
  { ( $BOUND sh -c "$VERIFY_CMD" ) >/dev/null 2>&1; } 2>/dev/null  # operator INSIDE the bound
else
  # shellcheck disable=SC2086 — $BOUND/$VERIFY_CMD unquoted on purpose:
  # an empty BOUND must vanish; the cmd is plain words + flags per matrix.
  { ( $BOUND $VERIFY_CMD ) >/dev/null 2>&1; } 2>/dev/null
fi
rc=$?

# ── 6. verdict map ──────────────────────────────────────────────────────────
case "$rc" in
  0)       v="present" ;;
  124|137) v="slow-verify" ;;
  127)
    # UNCONDITIONAL: the command -v pre-filter already proved the name
    # resolves before this probe ran (an absent name was reported missing
    # WITHOUT executing, above) — SKILL Step-2 verdict table + rail 12:
    # "127 NEVER means missing" once presence is proven; a 127 here is the
    # probe LAYER failing, never the tool.
    v="probe-inconclusive"
    ;;
  *)       v="missing" ;;      # incl. the WindowsApps stub's exit 49
esac

echo "$v bound=${BOUND_SECS}s rc=$rc"
exit 0
