#!/usr/bin/env bash
# v7.5.0 Fase 7 №B — anchor-extraction parity golden.
#
# session-start's two awk programs (FULL core: after the 2nd ---, until the
# ANCHOR-CORE marker; SLIM core: from ^## Hard rule until the marker) became
# pure-bash read loops (0 forks). This test carries the ORIGINAL awk programs
# as the golden reference and requires the live hook's injected anchor to be
# BYTE-IDENTICAL to them against the real SKILL.md — the merge-parity doctrine
# (fold verbatim + parity-proof) applied to a hook rewrite.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$REPO/plugins/mega-sdd/hooks"
ANCHOR="$REPO/plugins/mega-sdd/skills/using-mega-sdd/SKILL.md"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

[ -f "$ANCHOR" ] || { bad "anchor skill missing"; exit 1; }

# Golden reference — the pre-№B awk programs, verbatim.
GOLD_FULL="$(awk 'BEGIN{dash=0;body=0}
    /^---[[:space:]]*$/{dash++; if(dash==2)body=1; next}
    body==0{next}
    /ANCHOR-CORE ends/{exit}
    {print}' "$ANCHOR")"
GOLD_SLIM="$(awk 'BEGIN{take=0}
    /^## Hard rule/{take=1}
    /ANCHOR-CORE ends/{exit}
    take==1{print}' "$ANCHOR")"
[ -n "$GOLD_FULL" ] || { bad "golden FULL extraction is empty — marker drift in SKILL.md?"; exit 1; }
[ -n "$GOLD_SLIM" ] || { bad "golden SLIM extraction is empty — '## Hard rule' heading moved?"; exit 1; }

# Live hook output, startup (FULL) and compact (SLIM). Fixture: SDD signal dir,
# no git/map/index → no staleness noise; wrapper pre-installed → no heal spawn.
SSHOME="$WORK/home"; mkdir -p "$SSHOME/.claude/commands"
printf '%s\n' '<!-- mega-sdd-front-door-wrapper v1 — managed by the mega-sdd plugin -->' \
  > "$SSHOME/.claude/commands/mega-sdd.md"
FIX="$WORK/proj"; mkdir -p "$FIX/.mega-sdd"
run_ss() { ( cd "$FIX" && printf '{"source":"%s","session_id":"s"}' "$1" \
  | HOME="$SSHOME" bash "$HOOKS/session-start" 2>/dev/null ); }

# Containment check: the golden extraction must appear VERBATIM inside the
# hook's injected envelope (bash substring match — no sed reshaping, which is
# exactly what broke the first draft of this test).
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

OUT_FULL="$(run_ss startup)"
if contains "$OUT_FULL" "$GOLD_FULL"; then
  ok "FULL core (startup) contains the awk-golden extraction verbatim ($(printf '%s' "$GOLD_FULL" | wc -c | tr -d ' ') bytes)"
else
  bad "FULL core (startup) does NOT contain the awk-golden extraction verbatim"
fi

OUT_SLIM="$(run_ss compact)"
if contains "$OUT_SLIM" "$GOLD_SLIM"; then
  ok "SLIM core (compact) contains the awk-golden extraction verbatim ($(printf '%s' "$GOLD_SLIM" | wc -c | tr -d ' ') bytes)"
else
  bad "SLIM core (compact) does NOT contain the awk-golden extraction verbatim"
fi
if contains "$OUT_SLIM" "Post-compaction routing anchor (slim)"; then
  ok "SLIM core keeps the post-compaction pointer line"
else
  bad "SLIM core lost the post-compaction pointer line"
fi

# resume: the anchor body must NOT be re-injected (a mid-body golden line as probe)
GOLD_PROBE="$(printf '%s\n' "$GOLD_FULL" | sed -n '2p')"
OUT_RESUME="$(run_ss resume)"
if [ -n "$GOLD_PROBE" ] && contains "$OUT_RESUME" "$GOLD_PROBE"; then
  bad "resume re-injected the anchor body (M-13 duplication regression)"
else
  ok "resume does not re-inject the anchor body"
fi

# The rewrite must actually be fork-free: no awk left in the hook.
if grep -qE '\$\(awk|[^#]\bawk[[:space:]]+.BEGIN' "$HOOKS/session-start"; then
  bad "session-start still invokes awk"
else
  ok "session-start carries no awk invocation (builtin extraction)"
fi

echo
if [ "$fail" -eq 0 ]; then echo "PASS session-start extraction parity"; exit 0
else echo "session-start extraction parity FAILED"; exit 1; fi
