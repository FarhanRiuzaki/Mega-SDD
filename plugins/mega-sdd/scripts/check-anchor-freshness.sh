#!/usr/bin/env bash
# check-anchor-freshness.sh — pre-flight anchor freshness probe (P4 v4.96.0).
#
# v5 spec P4 row / research §7: a unit's `## Anchors` entries are the codebase
# evidence the bolt-implementer reads BEFORE writing code. A stale anchor
# (file deleted/renamed, or the cited line past the end of the file) sends the
# implementer to fiction — caught only after the damage, if at all. This probe
# resolves every `file:line` anchor against git-tracked ground truth BEFORE
# dispatch and halts `anchor_missing` when one is stale.
#
# DELIBERATELY A SEPARATE SCRIPT (documented choice): run-preflight-scan.sh is
# the Hard-rule BASELINE writer with a hook-guarded artifact and an
# anti-laundering lifecycle (immutable-after-bolt, exits 3-8). Anchor freshness
# is a READ-ONLY precondition probe — no artifact, no guard, no mint lifecycle —
# so folding it into the baseline writer would entangle two unrelated contracts.
#
# COMMIT-KEYED (legacy bolts never retro-block — B1 read-obligation-at-commit
# precedent, validate-bolt-artifacts.sh unit_text()): blocking applies only to a
# unit with NO bolt commits yet (a fresh v5 dispatch). Once bolt commits exist
# (same SHARED walk_unit_commits identity the B1/B3 gates use), a stale anchor
# is ADVISORY ONLY (WARN, exit 0) — re-running pre-flight over an already-bolted
# legacy unit must never retro-block it.
#
# Anchor grammar accepted (## Anchors bullet lines): any `path.ext:NN` token
# (optionally `:NN-MM` — the first line anchors). `<`-prefixed lines (template
# placeholders / HTML comments) are skipped, same as the B1 Hard-rule lexer.
#
# Usage:
#   check-anchor-freshness.sh --cwd=<project-root> --unit=U-XXX [--quiet]
#   check-anchor-freshness.sh --cwd=<project-root> --units=U-001,U-002,... [--quiet]
# Batch form (spec §4e tranche 4d): ONE spawn-chain amortizes the fixed costs
# (rev-parse prefix, `git ls-files`, walk_unit_commits — which already computes
# ALL units in one log walk) across every target unit. Read-only probe, so the
# batch processes EVERY unit and reports EVERY stale one in a single output.
# Exit: 0 = every anchor fresh / no anchors / advisory-only (bolted units)
#       1 = halt anchor_missing (≥1 stale anchor on a not-yet-bolted unit —
#           every offending unit listed)
#       2 = cannot run (usage / any unit not found / not a git repo)
set -uo pipefail

CWD=""
UNITS=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --unit=*|--units=*) UNITS="${UNITS:+${UNITS},}${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then echo "ERROR: --cwd=<project-root> required" >&2; exit 2; fi
if [ -z "$UNITS" ]; then echo "ERROR: --unit=U-XXX (or --units=U-001,U-002,...) required" >&2; exit 2; fi
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" UNITS="$UNITS" QUIET="$QUIET" python3 <<'PYEOF'
import os, re, subprocess, sys

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts
import postflight_rules

cwd = os.environ["CWD"]
# Comma-separated batch (spec tranche 4d); dedupe preserving order. The single
# --unit form arrives here as a one-element list — behavior byte-compatible.
unit_ids = list(dict.fromkeys(u.strip() for u in os.environ["UNITS"].split(",") if u.strip()))
quiet = os.environ.get("QUIET", "0") == "1"
if not unit_ids:
    print("ERROR: --unit/--units carried no unit id", file=sys.stderr)
    sys.exit(2)

def git(*a):
    # BOUNDED. Local git plumbing is low-risk, not zero-risk: an fsmonitor daemon,
    # a wedged index.lock, or a network-backed worktree can stall a read-only call
    # indefinitely, and this is an execute-bolts pre-flight probe — a path Claude
    # Code waits on. 60 s is 6x the repo's own rev-parse precedent
    # (refresh-doc-stamps.sh / validate-codebase-map.sh use timeout=10).
    try:
        return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True,
                              timeout=60)
    except subprocess.TimeoutExpired:
        # FAIL-CLOSED to exit 2 ("cannot run"), NEVER a synthetic empty result: an
        # empty `ls-files` (:114) would make EVERY anchor look untracked and report a
        # fabricated `anchor_missing` naming files that are perfectly fine — a wrong
        # halt is worse than an honest one. Exit 2 is the documented cannot-run code.
        print("ERROR: `git %s` exceeded 60s — cannot run (wedged git/fsmonitor?)."
              % " ".join(a), file=sys.stderr)
        sys.exit(2)

PREFIX = git("rev-parse", "--show-prefix").stdout.strip()

# Fail-fast BEFORE any probing: a unit id that resolves to nothing is a
# controller bug, not a freshness verdict — the whole batch is exit 2.
unit_files = {}
for unit_id in unit_ids:
    uf = vault_layouts.find_unit_file(cwd, unit_id)
    if not uf:
        print("ERROR: unit %s not found under any vault layout" % unit_id, file=sys.stderr)
        sys.exit(2)
    unit_files[unit_id] = uf

TOKEN = re.compile(r"(?<![\w:/])((?:[\w.\-]+/)*[\w.\-]+\.[A-Za-z][\w]{0,7}):(\d+)(?:-\d+)?\b")

# Fixed costs paid ONCE per batch (tranche 4d): the tracked-file set and — only
# when some unit is actually stale — the walk_unit_commits log walk (which
# already returns EVERY unit's commits in one pass).
tracked = None          # lazy: skipped entirely when no unit carries anchors
unit_commits = None     # lazy: skipped entirely when nothing is stale
blocking = []           # (unit_id, [lines]) for not-yet-bolted stale units

for unit_id in unit_ids:
    text = open(unit_files[unit_id]).read()

    # `## Anchors` section body — same heading tolerance as the B1 has_hard_rules
    # matcher (case-insensitive, trailing text on the heading line allowed).
    m = re.search(r"(?ims)^##[ \t]+Anchors\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", text)
    if not m:
        if not quiet:
            print("anchor-freshness %s: no ## Anchors section — nothing to verify" % unit_id)
        continue

    anchors = []
    for ln in m.group(1).splitlines():
        if ln.strip().startswith("<"):
            continue  # template placeholder / HTML comment — never a real anchor
        for tok in TOKEN.finditer(ln):
            anchors.append((tok.group(1), int(tok.group(2))))

    if not anchors:
        if not quiet:
            print("anchor-freshness %s: no file:line anchors — nothing to verify" % unit_id)
        continue

    if tracked is None:
        # git-tracked source set (repo names are prefix-relative in a monorepo).
        tracked = set()
        for n in git("ls-files", "--", ".").stdout.splitlines():
            n = n.strip()
            if PREFIX and n.startswith(PREFIX):
                n = n[len(PREFIX):]
            if n:
                tracked.add(n)

    stale = []
    for path, line in anchors:
        p = path[2:] if path.startswith("./") else path
        if p not in tracked:
            stale.append((p, line, "file_missing"))
            continue
        ap = os.path.join(cwd, p)
        try:
            n_lines = len(open(ap, errors="replace").read().splitlines())
        except OSError:
            stale.append((p, line, "file_missing"))
            continue
        if line < 1 or line > n_lines:
            stale.append((p, line, "line_out_of_range (file has %d lines)" % n_lines))

    if not stale:
        if not quiet:
            print("anchor-freshness %s: %d anchor(s) fresh" % (unit_id, len(anchors)))
        continue

    # Commit-keyed lane: bolt commits already exist → ADVISORY only (never
    # retro-block an already-bolted unit; B1 read-obligation-at-commit precedent).
    if unit_commits is None:
        unit_commits = postflight_rules.walk_unit_commits(git, PREFIX, 300)
    lines = ["%s:%d — %s" % (p, l, why) for p, l, why in stale]
    if unit_commits.get(unit_id, []):
        print("WARN (advisory — unit already bolted, never retro-blocked): %d stale "
              "anchor(s) in %s: %s. Refresh via /mega-sdd:sync or re-bind before the "
              "next re-execution." % (len(stale), unit_id, "; ".join(lines)), file=sys.stderr)
        continue
    blocking.append((unit_id, lines))

if not blocking:
    sys.exit(0)

for unit_id, lines in blocking:
    print("HALT anchor_missing: %d stale anchor(s) in %s ## Anchors:" % (len(lines), unit_id),
          file=sys.stderr)
    for l in lines:
        print("  - " + l, file=sys.stderr)
print("Keterangan: anchor di unit menunjuk file/baris yang sudah tidak ada di "
      "codebase (file terhapus/berpindah, atau baris bergeser melewati akhir "
      "file) — bolt-implementer akan membaca evidence yang salah. Perbaiki: "
      "jalankan /mega-sdd:sync (atau bind-codebase ulang) supaya "
      "anchors di-refresh dari kondisi kode terkini, ATAU edit baris ## Anchors "
      "unit yang tercantum ke path:line yang benar, lalu jalankan ulang "
      "execute-bolts.", file=sys.stderr)
sys.exit(1)
PYEOF
