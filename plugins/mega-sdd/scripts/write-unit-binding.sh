#!/usr/bin/env bash
# write-unit-binding.sh — SOLE writer of <vault>/bolts/U-XXX/binding.json (v8 P1,
# spec 2026-09-10 Appendix F3). The file is hook-guarded evidence (evidence-deny
# regex, like postflight/acceptance): Write/Edit/Bash writes are denied,
# only this script produces or amends it — so a verdict can never be typed in.
#
#   write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --claims=<bolts/U-XXX/_claims.json> [--verdicts=<json>]
#   write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --resolve=C-U005-01=KEEP_VAULT|KEEP_CODE|SPLIT|DEFER --by=<who>
#
# Verdicts (fail-closed, never CONFIRMED-by-absence):
#   fs_must_exist      path exists (and line range fits when `:N[-M]`) → CONFIRMED/IMPLEMENTED · else CONFLICT
#                      stale line-range (v8 P3, owner amendment #4 — research/2026-09-15-v8-p3-report.md §5): a range that
#                      no longer fits is REPAIRED only against the anchor's authoring snapshot (the commit that
#                      introduced that anchor token into the unit file) and only when the content is byte-identical:
#                        R1-shift  the authored lines are found verbatim (uniquely) at another offset → range moved
#                        R2-clamp  the file is unchanged since authoring AND the range overshoots EOF by exactly one
#                                  line (the trailing-newline miscount; the live P2 class) → range clamped to EOF
#                      anything else (content changed, no unique match, overshoot > 1, no snapshot) stays CONFLICT.
#                      A repair is recorded on the claim (`repair: {from,to,rule,reference,content_sha256}`) AND the
#                      unit's `## Anchors` line is rewritten to the repaired token (idempotent: the next bind sees it fit).
#   fs_must_not_exist  path absent → CONFIRMED/NEW · else CONFLICT (already exists)
#   symbol             symbol-index lookup: in the expected file → CONFIRMED/IMPLEMENTED (anchor file:line);
#                      only elsewhere → CONFLICT (collision; anchors listed); nowhere → OQ; index absent → OQ (reason)
#   text               OQ until `--verdicts` supplies the model ladder's verdict
#                      (skills/execute-bolts/references/jit-bind-and-quarantine.md §E3);
#                      a supplied CONFIRMED MUST carry an anchor, else the writer REFUSES (exit 3)
# State anchor (spec docs/superpowers/specs/2026-09-25-state-anchor-design.md §3, §9) — schema
# `unit-binding/2`: an HONEST stamp `based_on_sha` (the oldest evidence SHA, or null with a
# `null_cause`), `scope`, `own_targets`, `unit_sha256`, a `dirty` snapshot (one
# freshness.dirty_map()), `index_head`, per-claim `content_sha` / `absent_at`, the in-range
# content ladder, `claims_path` + `claims_sha256`, and `rebind_head` when a per-unit re-bind wrote
# it (--rebind). The run-start freshness check (derive-exec-plan.sh → _lib/freshness.gate_check) reads these.
# CONFLICT episodes (conflict_bypassed): a CONFLICT claim carries `conflict_since` (kept across re-binds by
# kind + expect) and `own_wip` when it is the unit's own uncommitted work (untracked, its provenance header);
# one a re-bind closes moves to `conflict_history` (since, closed_at); --resolve also decides a closed episode.
# The body lives in scripts/_lib/unit_binding.py (one python exec, as before).
# Exit 0 written · 2 usage/input · 3 refused (illegal verdict, CONFIRMED without anchor, resolve on a
# non-CONFLICT claim with no unresolved closed episode, claim set drifted since the capture, a git
# error while a .git exists).
set -u
CWD="."; VAULT=""; UNIT=""; CLAIMS=""; VERDICTS=""; RESOLVE=""; BY=""; REBIND=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --unit=*) UNIT="${arg#*=}" ;;
  --claims=*) CLAIMS="${arg#*=}" ;; --verdicts=*) VERDICTS="${arg#*=}" ;; --resolve=*) RESOLVE="${arg#*=}" ;; --by=*) BY="${arg#*=}" ;;
  --rebind) REBIND=1 ;;
  *) echo "usage: write-unit-binding.sh --cwd --vault --unit=U-XXX (--claims=<json> [--verdicts=<json>] [--rebind] | --resolve=C-id=ACTION --by=<who>)" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT" ] && [ -n "$UNIT" ] || { echo "usage: --vault=<dir> --unit=U-XXX required" >&2; exit 2; }
if [ -z "$RESOLVE" ]; then [ -n "$CLAIMS" ] && [ -f "$CLAIMS" ] || { echo "usage: --claims=<bolts/U-XXX/_claims.json> required (or --resolve)" >&2; exit 2; }; fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
V_CWD="$CWD" V_VAULT="$VAULT" V_UNIT="$UNIT" V_CLAIMS="$CLAIMS" V_VERDICTS="$VERDICTS" V_RESOLVE="$RESOLVE" V_BY="$BY" V_REBIND="$REBIND" \
  python3 "$SCRIPT_DIR/_lib/unit_binding.py"
