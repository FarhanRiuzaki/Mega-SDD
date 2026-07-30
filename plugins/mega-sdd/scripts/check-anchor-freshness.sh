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
# Exit: 0 = every anchor fresh / no anchors / advisory-only (bolted unit)
#       1 = halt anchor_missing (≥1 stale anchor on a not-yet-bolted unit)
#       2 = cannot run (usage / unit not found / not a git repo)
set -uo pipefail

CWD=""
UNIT=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --unit=*) UNIT="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then echo "ERROR: --cwd=<project-root> required" >&2; exit 2; fi
if [ -z "$UNIT" ]; then echo "ERROR: --unit=U-XXX required" >&2; exit 2; fi
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" UNIT="$UNIT" QUIET="$QUIET" python3 <<'PYEOF'
import os, re, subprocess, sys

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts
import postflight_rules

cwd = os.environ["CWD"]
unit_id = os.environ["UNIT"]
quiet = os.environ.get("QUIET", "0") == "1"

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

uf = vault_layouts.find_unit_file(cwd, unit_id)
if not uf:
    print("ERROR: unit %s not found under any vault layout" % unit_id, file=sys.stderr)
    sys.exit(2)
text = open(uf).read()

# `## Anchors` section body — same heading tolerance as the B1 has_hard_rules
# matcher (case-insensitive, trailing text on the heading line allowed).
m = re.search(r"(?ims)^##[ \t]+Anchors\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", text)
if not m:
    if not quiet:
        print("anchor-freshness %s: no ## Anchors section — nothing to verify" % unit_id)
    sys.exit(0)

TOKEN = re.compile(r"(?<![\w:/])((?:[\w.\-]+/)*[\w.\-]+\.[A-Za-z][\w]{0,7}):(\d+)(?:-\d+)?\b")
anchors = []
for ln in m.group(1).splitlines():
    if ln.strip().startswith("<"):
        continue  # template placeholder / HTML comment — never a real anchor
    for tok in TOKEN.finditer(ln):
        anchors.append((tok.group(1), int(tok.group(2))))

if not anchors:
    if not quiet:
        print("anchor-freshness %s: no file:line anchors — nothing to verify" % unit_id)
    sys.exit(0)

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
    sys.exit(0)

# Commit-keyed lane: bolt commits already exist → ADVISORY only (never
# retro-block an already-bolted unit; B1 read-obligation-at-commit precedent).
bolted = bool(postflight_rules.walk_unit_commits(git, PREFIX, 300).get(unit_id, []))
lines = ["%s:%d — %s" % (p, l, why) for p, l, why in stale]
if bolted:
    print("WARN (advisory — unit already bolted, never retro-blocked): %d stale "
          "anchor(s) in %s: %s. Refresh via /mega-sdd:sync or re-bind before the "
          "next re-execution." % (len(stale), unit_id, "; ".join(lines)), file=sys.stderr)
    sys.exit(0)

print("HALT anchor_missing: %d stale anchor(s) in %s ## Anchors:" % (len(stale), unit_id),
      file=sys.stderr)
for l in lines:
    print("  - " + l, file=sys.stderr)
print("Keterangan: anchor di unit menunjuk file/baris yang sudah tidak ada di "
      "codebase (file terhapus/berpindah, atau baris bergeser melewati akhir "
      "file) — bolt-implementer akan membaca evidence yang salah. Perbaiki: "
      "jalankan /mega-sdd:sync (atau /mega-sdd:bind-codebase ulang) supaya "
      "anchors di-refresh dari kondisi kode terkini, ATAU edit baris ## Anchors "
      "unit ini ke path:line yang benar, lalu jalankan ulang execute-bolts.",
      file=sys.stderr)
sys.exit(1)
PYEOF
