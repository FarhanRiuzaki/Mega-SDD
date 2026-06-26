#!/usr/bin/env bash
# validate-bolt-artifacts.sh — Phase B slice B.2 [PostToolUse-validate].
#
# Validates 3 bolt-related artifact integrity halts in one pass:
#   - provenance_missing       (modified file lacks provenance trailer)
#   - self_assessment_missing  (bolt-report.md lacks bolt_self_report YAML block)
#   - pbt_citation_invalid     (unit PBT property cites nonexistent ADR)
#
# Per attestation: all 3 are C1 detection-only at hook layer (auto-fix needs
# bolt context which only skill body has). Hook detects + emits warning
# telemetry + chat notice. Skill body / human resolves.
#
# Inputs: --cwd=<project> --file-path=<written-file>
# Outputs: JSON report to stdout; writes .mega-sdd/.bolt-artifacts-state.json
# Exit codes: 0=PASS, 1=FAIL (one or more issues detected), 2=error.
#
# ORPHAN-SCAN mode (--orphan-scan, no --file-path): repo-wide deterministic check
# for the interactive-run gap (clinic-project audit 2026-06-12): bolt COMMITS
# exist (subject `*(bolt): U-XXX*`) but the unit's <vault>/bolts/U-XXX/
# bolt-report.md was never written — the prose-only Step-0/Step-5 obligation
# was skipped by a terse controller and no file-scoped validator ever fired
# (absence of an artifact is invisible to a written-file validator). Flags a
# unit ONLY when it still exists under some vault's units/ (no false positives
# from retired vaults). Writes .mega-sdd/.bolt-orphans-state.json; the
# PreToolUse gate blocks the NEXT execute-bolts on FAIL.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
ORPHAN_SCAN=0
BATCH_SUITE_GATE=0
POSTFLIGHT_SCAN=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --orphan-scan) ORPHAN_SCAN=1 ;;
    --batch-suite-gate) BATCH_SUITE_GATE=1 ;;
    --postflight-scan) POSTFLIGHT_SCAN=1 ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
# Resolve project root (Iter 71 — class-bug fix: if invoked from a sub-folder
# like .mega-sdd/knowledge-base/, walk UP to the outermost .mega-sdd/ parent
# so state files land in the canonical location, not nested .mega-sdd/.mega-sdd/).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi


if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required" >&2
  exit 2
fi

# ─── ORPHAN-SCAN mode ────────────────────────────────────────────────────────
if [ "$ORPHAN_SCAN" = "1" ]; then
  # Not a git repo (or no .mega-sdd) → nothing to scan; no state written.
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  [ -d "${CWD}/.mega-sdd" ] || exit 0
  ORPHAN_STATE="${CWD}/.mega-sdd/.bolt-orphans-state.json"
  CWD="$CWD" ORPHAN_STATE="$ORPHAN_STATE" QUIET="$QUIET" python3 <<'PYEOF'
import glob, json, os, re, subprocess, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["ORPHAN_STATE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# Bounded history walk: bolt commits carry `(bolt): U-XXX` in the subject
# (per the execute-bolts commit discipline).
r = subprocess.run(["git", "-C", cwd, "log", "--format=%H\t%s", "-200"],
                   capture_output=True, text=True)
bolted = {}  # unit_id -> first (newest) commit sha
for line in r.stdout.splitlines():
    sha, _, subj = line.partition("\t")
    m = re.search(r"\(bolt\):\s*(U-[A-Za-z0-9_-]+)", subj)
    if m:
        bolted.setdefault(m.group(1), sha)

# A unit is in scope only if it still exists under some vault's units/.
def unit_exists(uid):
    pats = [
        os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", uid + ".md"),
        os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", uid, "unit.md"),
    ]
    return any(glob.glob(p) for p in pats)

def report_exists(uid):
    return bool(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "bolts", uid, "bolt-report.md")))

orphans = []
for uid in sorted(bolted):
    if unit_exists(uid) and not report_exists(uid):
        orphans.append({
            "halt_type": "bolt_artifacts_missing",
            "unit_id": uid,
            "commit": bolted[uid],
            "detail": "bolt commit exists for %s but <vault>/bolts/%s/bolt-report.md was never written" % (uid, uid),
        })

state = {
    "ts": ts,
    "mode": "orphan-scan",
    "status": "FAIL" if orphans else "PASS",
    "bolt_commits_seen": len(bolted),
    "issues_count": len(orphans),
    "issues": orphans,
    "next_action": ("%d bolt commit(s) have no bolt-report.md — the audit trail is missing. "
                    "Backfill <vault>/bolts/U-XXX/bolt-report.md (mark retroactive: true) for each "
                    "listed unit, or re-run the unit; execute-bolts is gated until resolved."
                    % len(orphans)) if orphans else "Every bolt commit has its bolt-report.md.",
}
tmp = state_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(state, f, indent=1)
os.replace(tmp, state_file)
if not quiet:
    print(json.dumps(state, indent=1))
sys.exit(1 if orphans else 0)
PYEOF
  exit $?
fi

# ─── BATCH-SUITE-GATE mode (B2) ──────────────────────────────────────────────
# After a code-bearing bolt run, a green full-suite result must exist at HEAD
# covering the newest code-bearing bolt commit. Otherwise the NEXT execute-bolts
# is halted. The validator VERIFIES the artifact; it NEVER runs the suite itself
# (running 200s+ suites in a hook is exactly the inflation to avoid). Design:
# docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md
if [ "$BATCH_SUITE_GATE" = "1" ]; then
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  [ -d "${CWD}/.mega-sdd" ] || exit 0
  BSG_STATE="${CWD}/.mega-sdd/.batch-suite-gate-state.json"
  CWD="$CWD" BSG_STATE="$BSG_STATE" QUIET="$QUIET" python3 <<'PYEOF'
import glob, json, os, re, subprocess, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["BSG_STATE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def git(*a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)

# A "code" file = OUTSIDE .mega-sdd/ AND not a pure-docs file (a docs/markdown commit
# cannot break a test suite, so it must not force a re-run). Universal, not stack-specific.
_DOC_EXT = (".md", ".markdown", ".rst", ".adoc")
def code_files(names):
    out = []
    for n in names:
        n = n.strip()
        if not n or n.startswith(".mega-sdd/"):
            continue
        if os.path.splitext(n)[1].lower() in _DOC_EXT:
            continue
        out.append(n)
    return out

# Two anchors over the newest-first log:
#   newest_bolt  — newest `(bolt): U-XXX` commit touching code → ACTIVATES the gate
#                  (no code-bearing bolt yet ⇒ nothing to gate) + labels the failure.
#   newest_code  — newest commit touching code REGARDLESS of subject → the freshness
#                  anchor. Tracking only bolt commits left the OUT-OF-BAND half of the
#                  incident open: a hotfix / manual edit / git pull after a green suite
#                  still "covered" the (older) newest bolt and shipped green.
r = git("log", "--format=%H\t%s", "-300")
newest_bolt = None
newest_bolt_unit = None
newest_code = None
newest_code_is_bolt = False
for line in r.stdout.splitlines():
    sha, _, subj = line.partition("\t")
    is_bolt = bool(re.search(r"\(bolt\):\s*(U-[A-Za-z0-9_-]+)", subj))
    names = git("show", "--name-only", "--format=", sha).stdout.splitlines()
    code = code_files(names)
    if code and newest_code is None:
        newest_code = sha
        newest_code_is_bolt = is_bolt
    if is_bolt and code and newest_bolt is None:
        newest_bolt = sha
        m = re.search(r"\(bolt\):\s*(U-[A-Za-z0-9_-]+)", subj)
        newest_bolt_unit = m.group(1) if m else None
    if newest_code is not None and newest_bolt is not None:
        break  # log is newest-first

def emit(status, halt_type=None, detail=None, extra=None):
    state = {"ts": ts, "mode": "batch-suite-gate", "status": status,
             "newest_bolt_commit": newest_bolt, "newest_bolt_unit": newest_bolt_unit}
    if halt_type:
        state["halt_type"] = halt_type
        state["detail"] = detail
        state["next_action"] = (
            "Run the project's FULL test suite (no per-unit scope filter) at HEAD and write "
            "<vault>/bolts/_batch-suite.json {status:green, head_sha:<HEAD>}; execute-bolts is "
            "gated until a green full-suite result covers the newest bolt commit." )
    if extra:
        state.update(extra)
    try:
        tmp = state_file + ".tmp"
        with open(tmp, "w") as f:
            json.dump(state, f, indent=1)
        os.replace(tmp, state_file)
    except OSError:
        pass
    if not quiet:
        print(json.dumps(state, indent=1))
    sys.exit(1 if halt_type else 0)

# No code-bearing bolt commit → nothing to gate.
if not newest_bolt:
    emit("PASS")

# Collect all batch-suite gate artifacts across vaults.
gates = []
for p in glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "bolts", "_batch-suite.json")):
    try:
        with open(p) as f:
            g = json.load(f)
        g["_path"] = os.path.relpath(p, cwd)
        gates.append(g)
    except (OSError, ValueError):
        continue

# A known-RED suite blocks outright.
reds = [g for g in gates if str(g.get("status", "")).lower() == "red"]
if reds:
    emit("FAIL", "batch_suite_red",
         "the recorded full-suite result is RED (%s) — a cross-bolt/out-of-band regression is live; "
         "fix the failing tests and re-run the gate before any further bolt." % reds[0].get("_path", "?"),
         {"red_gate": reds[0].get("_path")})

# A green gate "covers" the tree iff the NEWEST CODE commit (bolt OR out-of-band) is an
# ancestor of (or equal to) the gate's head_sha — i.e., the suite ran at or after the
# last code change landed. Anchoring on newest_code (not newest_bolt) closes the
# out-of-band half: a non-bolt code commit after a green suite is no longer covered.
def covers(head_sha):
    if not head_sha:
        return False
    return git("merge-base", "--is-ancestor", newest_code, head_sha).returncode == 0

green_cover = [g for g in gates
               if str(g.get("status", "")).lower() == "green" and covers(g.get("head_sha"))]
if green_cover:
    emit("PASS", extra={"covered_by": green_cover[0].get("_path"),
                        "newest_code_commit": newest_code})

# Gate missing or stale (green but does not cover the newest code commit).
stale = any(str(g.get("status", "")).lower() == "green" for g in gates)
oob = not newest_code_is_bolt  # the uncovered change came in WITHOUT a bolt (out-of-band)
who = ("an OUT-OF-BAND code commit %s (no bolt provenance)" % newest_code[:9]) if oob \
      else ("bolt commit %s (%s)" % (newest_code[:9], newest_bolt_unit))
emit("FAIL", "batch_suite_gate_missing",
     ("a green full-suite result exists but is STALE — it does not cover %s; a code change "
      "landed after the last full-suite run." % who) if stale else
     ("no <vault>/bolts/_batch-suite.json records a full-suite run; %s shipped without a "
      "final full-suite gate." % who),
     {"stale": stale, "out_of_band": oob, "newest_code_commit": newest_code})
PYEOF
  exit $?
fi

# ─── POSTFLIGHT-SCAN mode (B1) ───────────────────────────────────────────────
# A committed create/extend/modify bolt whose unit has a non-empty ## Hard rules
# section must carry <vault>/bolts/U-XXX/postflight.json with all verdicts pass.
# The post-flight Hard-rule scan was prose-only ("HALT" that enforced nothing);
# this moves it to a hook gate. Verify units skip post-flight (no changes to validate).
# Design: docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md (§B1)
if [ "$POSTFLIGHT_SCAN" = "1" ]; then
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  [ -d "${CWD}/.mega-sdd" ] || exit 0
  PF_STATE="${CWD}/.mega-sdd/.bolt-postflight-state.json"
  CWD="$CWD" PF_STATE="$PF_STATE" QUIET="$QUIET" python3 <<'PYEOF'
import glob, json, os, re, subprocess, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["PF_STATE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

r = subprocess.run(["git", "-C", cwd, "log", "--format=%H\t%s", "-300"],
                   capture_output=True, text=True)
bolted = {}  # unit_id -> newest commit sha
for line in r.stdout.splitlines():
    sha, _, subj = line.partition("\t")
    m = re.search(r"\(bolt\):\s*(U-[A-Za-z0-9_-]+)", subj)
    if m:
        bolted.setdefault(m.group(1), sha)

def unit_file(uid):
    for p in [os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", uid + ".md"),
              os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", uid, "unit.md")]:
        g = glob.glob(p)
        if g:
            return g[0]
    return None

def task_type(text):
    fm = text.split("---", 2)
    front = fm[1] if len(fm) >= 3 else text
    m = re.search(r"(?m)^\s*task_type:\s*([A-Za-z_]+)", front)
    return (m.group(1).lower() if m else "")

def has_hard_rules(text):
    # body of the `## Hard rules` section (until the next `## ` heading).
    # Case-INSENSITIVE heading + tolerate trailing text on the heading line — the
    # canonical unit template emits `## Hard rules  (validated at bolt time ...)`
    # (unit-schema.md), and units may use `## Hard Rules`. Matching only the bare
    # `## Hard rules` left the B1 gate INERT on template-conformant units.
    m = re.search(r"(?ims)^##[ \t]+Hard[ \t]+rules\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", text)
    if not m:
        return False
    # A line is "empty" (no real rule) if, after stripping markdown decoration, it
    # is blank or a recognised no-op phrasing. Curated set (NOT a wildcard) so a real
    # rule phrased oddly is never silently exempted (that would fail OPEN).
    empties = {"none", "na", "n/a", "none.", "n/a.", "tbd", "todo", "nonfor",
               "nohardrules", "nohardrulesforthisunit", "nohardrulesapply",
               "notapplicable", "nonerequired", "noneapplicable", "nonefornow"}
    for ln in m.group(1).splitlines():
        s = re.sub(r"[`*_>\-\s]", "", ln).strip().lower()
        if s and s not in empties:
            return True
    return False

def postflight_ok(uid):
    """(found, ok) — found=postflight.json exists; ok=all verdicts pass."""
    g = glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "bolts", uid, "postflight.json"))
    if not g:
        return (False, False)
    try:
        d = json.load(open(g[0]))
    except (OSError, ValueError):
        return (True, False)  # present but unreadable = not valid evidence
    # Require POSITIVE evidence, never permissive defaults — an empty {} or an empty
    # rules[] must NOT pass (the constrained agent could satisfy the gate without ever
    # running the post-flight scan). status must be present + passing; rules must be
    # non-empty; every rule must carry a passing verdict (a missing verdict is NOT pass).
    if str(d.get("status", "")).lower() not in ("pass", "passed", "ok", "green"):
        return (True, False)
    rules = d.get("rules")
    if not isinstance(rules, list) or not rules:
        return (True, False)  # vacuous — no per-rule evidence
    for rule in rules:
        if str((rule or {}).get("verdict", "")).lower() not in ("pass", "passed", "ok"):
            return (True, False)
    return (True, True)

issues = []
for uid in sorted(bolted):
    uf = unit_file(uid)
    if not uf:
        continue
    try:
        text = open(uf).read()
    except OSError:
        continue
    if task_type(text) == "verify":
        continue  # verify units skip post-flight (no changes to validate)
    if not has_hard_rules(text):
        continue  # no Hard rules → nothing to post-validate
    found, ok = postflight_ok(uid)
    if not ok:
        issues.append({
            "halt_type": "postflight_evidence_missing",
            "unit_id": uid,
            "commit": bolted[uid],
            "detail": ("no <vault>/bolts/%s/postflight.json — the post-flight Hard-rule scan never ran "
                       "(prose-only gate skipped)" % uid) if not found else
                      ("<vault>/bolts/%s/postflight.json records a non-pass verdict — a Hard-rule "
                       "violation was committed" % uid),
        })

state = {
    "ts": ts, "mode": "postflight-scan",
    "status": "FAIL" if issues else "PASS",
    "bolt_commits_seen": len(bolted),
    "issues_count": len(issues), "issues": issues,
    "next_action": ("%d Hard-rule bolt(s) committed with no passing postflight.json — the post-flight "
                    "safety net was skipped. Re-run each unit (or write the postflight.json evidence) so "
                    "the Hard rules are validated; execute-bolts is gated until resolved." % len(issues))
                   if issues else "Every Hard-rule bolt has a passing postflight.json.",
}
try:
    tmp = state_file + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1)
    os.replace(tmp, state_file)
except OSError:
    pass
if not quiet:
    print(json.dumps(state, indent=1))
sys.exit(1 if issues else 0)
PYEOF
  exit $?
fi

# FILE_PATH is the written file. May or may not exist (Edit happens, then validator
# reads it). If missing → skip (write must have failed).
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  # No file to validate; emit a no-op state.
  exit 0
fi

STATE_FILE="${CWD}/.mega-sdd/.bolt-artifacts-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: cannot create state dir" >&2; exit 2; }

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json
import os
import re
import sys
import glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
rel_path = os.path.relpath(file_path, cwd)

# Determine which checks apply based on path
checks_to_run = []  # list of (check_name, callable)
issues = []  # list of {check, halt_type, detail}

def is_bolt_report(p):
    """Match: <vault>/bolts/U-*/bolt-report.md (under .mega-sdd/vaults or just vaults)"""
    return bool(re.search(r"(?:^|/)bolts/U-[^/]+/bolt-report\.md$", p))

def is_unit_path(p):
    """Match unit file (both file layouts: U-*.md OR U-*/unit.md) under any
    .../units/ — covers canonical <vault>/units/ AND legacy <vault>-bound/units/."""
    if re.search(r"/units/U-[^/]+\.md$", p):
        return True
    if re.search(r"/units/U-[^/]+/unit\.md$", p):
        return True
    return False

def find_unit_for_target(target_path):
    """
    Find any unit file whose target_files list contains target_path.
    Returns (unit_file_path, unit_id) or (None, None).
    Walks both unit layouts.
    """
    abs_target = os.path.abspath(target_path)
    # Make target_path relative variants (units may declare relative paths)
    rel_target_from_cwd = os.path.relpath(abs_target, cwd) if abs_target.startswith(cwd) else None

    unit_paths = sorted(
        # Widened *-bound → * — covers canonical <vault>/units AND legacy <vault>-bound/units.
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*.md")) +
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*", "unit.md"))
    )
    for up in unit_paths:
        try:
            body = open(up).read()
        except Exception:
            continue
        m = re.match(r"^---\n(.*?)\n---", body, re.DOTALL)
        if not m:
            continue
        fm = m.group(1)
        # Walk target_files block — line-based extraction (same pattern as session-start verify_unit_writable)
        fm_lines = fm.split("\n")
        in_block = False
        for ln in fm_lines:
            if ln.startswith("target_files:"):
                in_block = True
                continue
            if in_block:
                if ln and ln[0] not in " \t":
                    break
                # Look for `- path: X` or `path: X` lines
                pm = re.search(r"path:\s*(\S+)", ln)
                if pm:
                    candidate = pm.group(1).strip().strip("'\"")
                    # Compare against relative target
                    if rel_target_from_cwd and (
                        candidate == rel_target_from_cwd
                        or rel_target_from_cwd.endswith("/" + candidate)
                        or candidate.endswith("/" + rel_target_from_cwd)
                    ):
                        # Extract unit_id from frontmatter
                        uid_match = re.search(r"^(?:unit_id|id):\s*(\S+)", fm, re.MULTILINE)
                        uid = uid_match.group(1) if uid_match else os.path.basename(up).replace(".md", "")
                        return (up, uid)
    return (None, None)

# ─── Check 1: provenance_missing ────────────────────────────────────────────
# Triggers when written file is bolt-modified (i.e., listed in some unit's target_files).
# Provenance trailer format (per execute-bolts/references/bolt-dispatch-prompt.md):
#   Generated by mega-sdd execute-bolts <version>
#   Unit: U-XXX (vault sha256: <hash>)
#   Implements claim: C-NNN "..."
#   Anchors consulted: ...
#   Hard Rules active: ...
# We detect by looking for the marker line "Generated by mega-sdd execute-bolts" in
# the first 30 lines (top-of-file, comment-block-tolerant).
unit_file, unit_id = find_unit_for_target(file_path)
if unit_file is not None:
    try:
        with open(file_path) as f:
            head = "".join(f.readline() for _ in range(30))
    except Exception:
        head = ""
    if "Generated by mega-sdd execute-bolts" not in head:
        issues.append({
            "halt_type": "provenance_missing",
            "detail": f"bolt-modified file {rel_path} (unit {unit_id}) lacks provenance trailer in first 30 lines",
            "unit_id": unit_id,
            "unit_path": os.path.relpath(unit_file, cwd),
            "expected_marker": "Generated by mega-sdd execute-bolts",
        })

# ─── Check 2: self_assessment_missing ───────────────────────────────────────
# Triggers when written file is bolt-report.md. Looks for `bolt_self_report:` YAML key.
if is_bolt_report(file_path):
    try:
        content = open(file_path).read()
    except Exception:
        content = ""
    if "bolt_self_report:" not in content:
        # Extract unit_id from path
        m = re.search(r"bolts/(U-[^/]+)/bolt-report\.md", file_path)
        uid = m.group(1) if m else "unknown"
        issues.append({
            "halt_type": "self_assessment_missing",
            "detail": f"bolt-report.md for {uid} lacks bolt_self_report YAML block",
            "unit_id": uid,
            "bolt_report_path": rel_path,
            "expected_key": "bolt_self_report:",
        })

# ─── Check 3: pbt_citation_invalid ──────────────────────────────────────────
# Triggers when written file is a unit (PBT properties live in unit body).
# Format: `Cites: §Decision-D-NNN` or `Cites: §D-NNN`.
# Validates each cited D-NNN exists in <cwd>/.mega-sdd/vaults/*/decisions/<D-NNN>.md
# OR <cwd>/.mega-sdd/vaults/*-bound/decisions/<D-NNN>.md.
if is_unit_path(file_path):
    try:
        body = open(file_path).read()
    except Exception:
        body = ""
    # Find Cites references — match Cites: §Decision-D-NNN, Cites: §D-NNN, Cites: D-NNN
    cite_pattern = re.compile(r"Cites:\s*§?(?:Decision-)?(D-[A-Z0-9-]*\d+)", re.IGNORECASE)
    cited = set(cite_pattern.findall(body))
    if cited:
        # Build inventory of available decision IDs from vault decisions/
        available = set()
        for dec_dir in glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "decisions")) + \
                       glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "*", "decisions")):
            for f in glob.glob(os.path.join(dec_dir, "*.md")):
                # Filename pattern: D-NNN.md or D-P2-NNN.md etc.
                fname = os.path.basename(f).replace(".md", "")
                if fname.startswith("D-"):
                    available.add(fname)
        # Cross-check
        missing = sorted([c for c in cited if c not in available])
        if missing:
            uid_match = re.search(r"unit_id:\s*(\S+)|id:\s*(\S+)", body)
            uid = uid_match.group(1) or uid_match.group(2) if uid_match else "unknown"
            issues.append({
                "halt_type": "pbt_citation_invalid",
                "detail": f"unit {uid} PBT property cites ADR(s) not found in vault decisions/",
                "unit_id": uid,
                "unit_path": rel_path,
                "missing_decisions": missing,
                "available_decisions_count": len(available),
            })

# ─── Build state file ───────────────────────────────────────────────────────
status = "PASS" if not issues else "FAIL"
state = {
    "ts": ts,
    "checked_file": rel_path,
    "status": status,
    "issues_count": len(issues),
    "issues": issues,
    "next_action": (
        "Bolt artifacts pass integrity checks." if status == "PASS"
        else f"{len(issues)} integrity issue(s) detected. Each is detection-only (no auto-fix at hook layer); review listed issues and amend unit/bolt-report manually OR re-run execute-bolts with --strict-provenance flag."
    ),
}

# Read prior state to track retry/persistence (current-truth overwrite)
try:
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f"ERROR: cannot write state file: {e}", file=sys.stderr)
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF

exit $?
