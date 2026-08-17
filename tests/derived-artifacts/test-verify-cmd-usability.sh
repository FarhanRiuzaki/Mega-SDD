#!/usr/bin/env bash
# test-verify-cmd-usability.sh
#
# Guards the ONE invariant that decides whether install-deps can tell a working
# tool from a broken one:
#
#     a `verify_cmd` must EXECUTE the tool, never merely look it up on PATH.
#
# Why this needs a mechanical guard rather than prose. Before 2026-07-30, 39 of the
# 46 `verify_cmd` values in tool-matrix.yaml were literally `command -v <tool>`.
# That made "run verify_cmd" and "test presence" the same operation for every tool
# except python3 — so the audit reported `✓ jd (command -v jd — RC=0)` and, more
# damagingly, reported a real interpreter for a Windows App Execution Alias stub
# that resolves on PATH, prints "Python was not found…" to stderr, and exits 49.
# A field run on a Windows 11 + Git Bash laptop shipped that false positive.
#
# `test-tool-matrix.sh` is structural — it checks that `verify_cmd` EXISTS, never
# what it contains — so nothing in the suite catches a regression here. This does.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
MATRIX="$HERE/../../plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml"
rc=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; rc=1; }

[ -f "$MATRIX" ] || { echo "FAIL: matrix not found at $MATRIX"; exit 1; }

echo "verify_cmd usability invariant"

# ── 1. no verify_cmd may be a bare PATH lookup ───────────────────────────────
# `command -v` is permitted INSIDE a compound probe only if the command is also
# executed; the cheap way to express that invariant is "the value must not START
# with a lookup", since a lookup that runs first and short-circuits is exactly the
# presence test we are banning.
bad=$(grep -n 'verify_cmd:' "$MATRIX" | grep -E 'verify_cmd: *"(command -v|which |type )' || true)
if [ -z "$bad" ]; then
  pass "no verify_cmd is a bare PATH lookup (command -v / which / type)"
else
  fail "verify_cmd values that only test PRESENCE, not usability:"
  printf '%s\n' "$bad" | sed 's/^/      /'
fi

# ── 2. every verify_cmd must actually run something ──────────────────────────
total=$(grep -c 'verify_cmd:' "$MATRIX")
execish=$(grep 'verify_cmd:' "$MATRIX" | grep -cE '(--version|-V\b| version\b|-v\b)' || true)
if [ "$total" -gt 0 ] && [ "$execish" -eq "$total" ]; then
  pass "all $total verify_cmd values carry an execution probe"
else
  fail "only $execish of $total verify_cmd values look like an execution probe"
  grep -n 'verify_cmd:' "$MATRIX" | grep -vE '(--version|-V\b| version\b|-v\b)' | sed 's/^/      /'
fi

# ── 3. python3 must NOT be verified by the bare `python3` name alone ─────────
# The winget/python.org installer ships python.exe but never python3.exe, so on
# that route `python3 -V` fails even though Python is installed and working. The
# matrix must therefore carry a `python -V` row too; resolve-python.sh's ladder is
# what makes the distinction at runtime.
if grep -q 'verify_cmd: "python -V"' "$MATRIX"; then
  pass "a 'python -V' route exists (winget ships no python3.exe)"
else
  fail "no 'python -V' verify_cmd — the winget python3 route cannot verify"
fi

# ── 4. the exec probe must be BOUNDED, and no bound-side failure may mean `missing` ──
# v5.8.0 converted 39 verify_cmd values from `command -v` (a shell builtin, which
# cannot hang) to execution probes — and shipped them with NO timeout and NO
# pre-filter. `semgrep --version` alone measures 3.9 s warm on macOS; the nine
# probes total ~5.1 s against ~53 ms for the builtins, ~96x. On a corporate Windows
# box with an EDR and a TLS-inspecting proxy that stalled an audit outright.
#
# Two separate invariants live here, and BOTH need pinning.
#
# (i) The bound must RESOLVE, never be a literal. Stock macOS ships neither
#     `timeout` nor `gtimeout` (`gtimeout` arrives only with `brew install
#     coreutils`), so a hard-coded prefix exits 127 on every probe there — and the
#     verdict table routes "non-zero, other code" to `missing`. That reports EVERY
#     installed tool as missing and proposes reinstalling software that is already
#     present: the absence of the bounding utility becoming a verdict about the
#     bounded tool. Git Bash ships MSYS2 coreutils `timeout` in /usr/bin and Linux
#     ships GNU coreutils, so the ladder `timeout` → `gtimeout` → empty covers all
#     three target platforms. The prefix is re-resolved per Bash invocation because
#     shell state does not survive between tool calls — Step 2 and Step 6 are
#     separated by a confirmation gate and an install batch, so a variable set in
#     one is unset in the other, and `$BOUND` would silently expand to nothing.
#
# (ii) `-k` and its exit code. GNU timeout sends SIGTERM at expiry and then WAITS
#     for the child; only `--kill-after`/`-k` escalates to SIGKILL. Measured against
#     GNU coreutils 9.7 with a SIGTERM-ignoring child: the unescalated form → rc=124
#     after 30 s; `timeout -k 1 2` → rc=137 after 3 s. On Git Bash the unescalated
#     form is NOT unbounded: verified against primary sources (cygwin.com `kill`
#     docs; git-for-windows/msys2-runtime PR#15, PR#16, commit c967bd8) MSYS2
#     delivers SIGTERM to a non-MSYS child by injecting a thread that calls
#     ExitProcess and escalating to TerminateProcess after ~10 s — a bounded
#     overshoot, not a hang. `-k 2` is kept because it makes the ceiling a number
#     the procedure owns rather than an MSYS2 implementation detail. Flag ORDER
#     matters: the flag must precede the duration or it is a parse error (rc 127).
#     Because `-k` makes 137 reachable, 137 must share 124's verdict, and 127 must
#     be excluded from the `missing` catch-all for BOTH reasons above.
SKILL="$HERE/../../plugins/mega-sdd/skills/install-deps/SKILL.md"
# 6.13.0 (spec 2026-08-17-token-lard-cuts-p1 D3): the probe contract was RELOCATED
# verbatim to references/audit-and-verify.md; SKILL.md keeps routers + the inline
# carve-outs. The invariant now holds over the UNION of the two files — a fact
# deleted from BOTH is still a failure, and the mutation controls mutate the union.
AV="$HERE/../../plugins/mega-sdd/skills/install-deps/references/audit-and-verify.md"
UNION_DIR="$(mktemp -d)"   # cleaned by the shared EXIT trap set at §5 below
UNION="$UNION_DIR/union.md"
cat "$SKILL" "$AV" > "$UNION" 2>/dev/null || true

# probe_skill <file> — runs every SKILL.md invariant against <file>, printing one
# `OK:<id>` or `BAD:<id>` line per check. Returns 1 if any check failed. Written as
# a function so the CONTROL block below exercises the REAL checks against mutated
# copies instead of re-implementing them (a re-implemented control proves nothing
# about the checks that actually run).
probe_skill() {
  ps_f="$1"; ps_rc=0
  ps_chk() { # ps_chk <id> <condition-rc>
    if [ "$2" -eq 0 ]; then echo "OK:$1"; else echo "BAD:$1"; ps_rc=1; fi
  }

  # the bound is RESOLVED via the 3-limb ladder. Pre-6.13.0 the block appeared
  # TWICE (Step 2 + a Step 6 copy); the D3 diet deduplicated it into ONE canonical
  # §Probe contract block that §Verify after install explicitly routes back to —
  # so the floor is ≥1, and deleting the ladder entirely still fails.
  n_t=$(grep -cF 'BOUND="timeout -k 2 10"'  "$ps_f")
  n_g=$(grep -cF 'BOUND="gtimeout -k 2 10"' "$ps_f")
  n_e=$(grep -cF 'BOUND=""'                 "$ps_f")
  [ "$n_t" -ge 1 ] && [ "$n_g" -ge 1 ] && [ "$n_e" -ge 1 ]
  ps_chk "bound-resolver(t=$n_t g=$n_g empty=$n_e)" $?

  # EVERY probe site uses the resolved prefix, never a literal. Counting the
  # prefix itself (not `$BOUND <verify_cmd>`) is deliberate: it also covers the
  # python3 probe, whose command is `$BOUND bash -c '…resolve-python.sh…'` rather
  # than a matrix verify_cmd. Exact count, so a NEW unbounded probe site is a FAIL
  # rather than something a `-ge 2` threshold silently tolerates.
  # 3 sites post-6.13.0 dedup: §Probe contract exec probe, its `sh -c` wrapper
  # for compound verify_cmd, and the python3 resolver probe (the former Step-6
  # copy now routes to the same canonical block instead of repeating it).
  n_u=$(grep -cE '^[[:space:]]*\$BOUND ' "$ps_f")
  [ "$n_u" -eq 3 ]; ps_chk "bound-not-literal(sites=$n_u/3)" $?

  # A compound verify_cmd must be wrapped, or the shell parses `||` at the TOP level:
  # only the first limb is bounded, the fallback runs unbounded, and `||` returns the
  # LAST status — swallowing the 124/137 the bound just produced. Seven matrix rows
  # are compound (`tree-sitter --version || tree-sitter-cli --version`).
  grep -qF '$BOUND sh -c' "$ps_f"; ps_chk "compound-verify_cmd-wrapped" $?

  # anti-regression: no unescalated `timeout <n>` anywhere
  grep -qE 'timeout +[0-9]' "$ps_f"; [ $? -ne 0 ]; ps_chk "no-bare-timeout" $?

  grep -qi 'Pre-filter with .command -v. FIRST' "$ps_f"; ps_chk "prefilter" $?
  grep -q '124' "$ps_f"; ps_chk "code-124" $?

  n_137=$(grep -c '137' "$ps_f"); [ "$n_137" -ge 2 ]; ps_chk "code-137(sites=$n_137)" $?

  # THE macOS FIX: rc 127 — the bounding utility missing, or a probe layer that
  # could not run — may never yield `missing`/`unverified`, at either table.
  grep -qF 'Exit 127 → mark `present` with a `probe-inconclusive` note, NEVER `missing`' "$ps_f" \
    && grep -qF 'Exit 127 → `verified` with a `probe-inconclusive` note, never `unverified`' "$ps_f" \
    && grep -qF 'absence of the bounding utility must never itself produce a `missing` verdict' "$ps_f"
  ps_chk "code-127-not-missing" $?

  # the platform fact that makes the resolver load-bearing must be stated
  grep -qF 'stock macOS ships neither `timeout` nor `gtimeout`' "$ps_f"; ps_chk "macos-no-timeout" $?

  # catch-alls must name the excluded codes, 127 included
  grep -qF 'any OTHER code (not 124, 137, or 127)' "$ps_f" \
    && grep -qF 'any code other than 124/137/127' "$ps_f"
  ps_chk "catchall-excludes-124-137-127" $?

  return $ps_rc
}

if [ -f "$SKILL" ] && [ -f "$AV" ]; then
  while IFS= read -r line; do
    case "$line" in
      OK:*)  pass "SKILL∪audit-and-verify ${line#OK:}" ;;
      BAD:*) fail "SKILL∪audit-and-verify ${line#BAD:}" ;;
    esac
  done <<EOF
$(probe_skill "$UNION")
EOF
else
  fail "install-deps SKILL.md or references/audit-and-verify.md not found"
fi

# ── 4-CONTROL: every check above must go RED on its own targeted mutation ─────
# Without this a SKILL.md that stopped discussing bounds at all could satisfy the
# negative checks vacuously. Each mutation removes exactly one property and must
# be caught by exactly the check that owns it.
if [ -f "$SKILL" ] && [ -f "$AV" ]; then
  TMPS="$(mktemp -d)"
  # id @ sed program @ check-id prefix that MUST turn BAD  (@ separates fields
  # because the sed programs themselves use / and | as their own delimiters)
  while IFS='@' read -r mid mprog mexpect; do
    [ -n "$mid" ] || continue
    sed "$mprog" "$UNION" > "$TMPS/m.md"
    if cmp -s "$UNION" "$TMPS/m.md"; then
      fail "control[$mid]: mutation was a no-op — this control proves nothing"
      continue
    fi
    mout=$(probe_skill "$TMPS/m.md")
    if printf '%s\n' "$mout" | grep -q "^BAD:$mexpect"; then
      pass "control[$mid]: '$mexpect' fires on the mutation (check is not vacuous)"
    else
      fail "control[$mid]: expected BAD:$mexpect, got: $(printf '%s' "$mout" | grep '^BAD:' | tr '\n' ' ')"
    fi
  done <<'MUT'
strip-resolver-fallbacks@/BOUND="gtimeout -k 2 10"/d;/BOUND=""/d@bound-resolver
literal-at-probe-site@s/\$BOUND <verify_cmd>/timeout -k 2 10 <verify_cmd>/g@bound-not-literal
drop-k-escalation@s/timeout -k 2 10/timeout 10/g@no-bare-timeout
drop-127-verdict@/Exit 127 /d@code-127-not-missing
drop-macos-fact@s/stock macOS ships neither/most systems ship/@macos-no-timeout
widen-catchall@s|any OTHER code (not 124, 137, or 127)|any OTHER code|;s|124/137/127|124/137|@catchall-excludes-124-137-127
MUT
  rm -rf "$TMPS"
fi

# ── 5. CONTROL: the detector fires on the exact historical defect ────────────
# Without this, a matrix that stopped containing verify_cmd at all would pass 1-3
# silently. Replay the pre-2026-07-30 shape on a temp copy and require a catch.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$UNION_DIR"' EXIT
sed 's/verify_cmd: "jd --version"/verify_cmd: "command -v jd"/' "$MATRIX" > "$TMP/mutated.yaml"
if ! grep -q 'verify_cmd: "command -v jd"' "$TMP/mutated.yaml"; then
  fail "control: could not construct the mutation — this test proves nothing"
else
  caught=$(grep -E 'verify_cmd: *"(command -v|which |type )' "$TMP/mutated.yaml" | wc -l | tr -d ' ')
  if [ "$caught" -ge 1 ]; then
    pass "control: the check catches a reintroduced 'command -v' verify_cmd"
  else
    fail "control: mutation NOT caught — checks 1-3 are vacuous"
  fi
fi

echo
if [ $rc -eq 0 ]; then echo "PASS: verify_cmd usability invariant"; else echo "FAIL: verify_cmd usability invariant"; fi
exit $rc
