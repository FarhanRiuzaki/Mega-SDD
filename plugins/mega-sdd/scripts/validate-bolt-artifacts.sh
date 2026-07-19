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
# exist but the unit's <vault>/bolts/U-XXX/bolt-report.md was never written — the
# prose-only Step-0/Step-5 obligation was skipped by a terse controller and no
# file-scoped validator ever fired (absence of an artifact is invisible to a
# written-file validator). Flags a unit ONLY when it still exists under some
# vault's units/ (no false positives from retired vaults). Writes
# .mega-sdd/.bolt-orphans-state.json; the PreToolUse gate blocks the NEXT
# execute-bolts on FAIL.
#
# COMMIT IDENTITY (S6 EB-GATE-2): a bolt commit is recognized by ANY of —
#   1. conventional-commit scope   `<type>(U-XXX): …`   (the canonical contract
#      format per execute-bolts/references/bolt-contract.md §Commit message format)
#   2. legacy subject grammar      `… (bolt): U-XXX …`
#   3. git trailer                 `Unit: U-XXX`         (bolt-implementer.md step 6)
# The old validators keyed ONLY on shape 2, which no producer contract ever
# emitted — every doc-conformant bolt run shipped with the B1/B2/orphan gates
# silently dormant (bolt_commits_seen: 0 → PASS).

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
ORPHAN_SCAN=0
BATCH_SUITE_GATE=0
POSTFLIGHT_SCAN=0
WHITELIST_SCAN=0
ACCEPTANCE_SCAN=0
RECOMPUTE=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --orphan-scan) ORPHAN_SCAN=1 ;;
    --batch-suite-gate) BATCH_SUITE_GATE=1 ;;
    --postflight-scan) POSTFLIGHT_SCAN=1 ;;
    --recompute) RECOMPUTE=1 ;;
    --whitelist-scan) WHITELIST_SCAN=1 ;;
    --acceptance-scan) ACCEPTANCE_SCAN=1 ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
# Resolve project root (Iter 71; S6 EB-GATE-6: nearest SUBSTANTIVE root — a
# litter .mega-sdd/ minted by a past misdirected state write never shadows the
# true project root above it).
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR_HELPER="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"


if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required" >&2
  exit 2
fi

# S7-VAL-1: gate ACTIVATION = any discoverable vault layout, not only .mega-sdd/.
# vault_layouts.py exists (EB-VAL-2) precisely to cover legacy layouts
# (docs/mega-sdd/vaults/*, *-bound siblings), but every gate mode short-circuited
# on the .mega-sdd/ dir — a pure-legacy project (pre-migrate-paths) got ZERO
# B1/B2/B3/orphan coverage, failing OPEN. A vault discoverable via any layout
# makes the project provably mega-sdd, so creating .mega-sdd/ for the state file
# is NOT root-minting (EB-GATE-6 forbids phantom roots with no vault at all).
_gate_active() {
  [ -d "${CWD}/.mega-sdd" ] && return 0
  CWD="$CWD" python3 - <<'PY'
import glob, os, sys
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts
cwd = os.environ["CWD"]
for pre in vault_layouts.vault_prefixes(cwd):
    for d in glob.glob(pre):
        # a dependency dir is never a vault (node_modules/foo-bound/bolts must
        # not activate the gates — and mint .mega-sdd — on a FOREIGN repo)
        segs = os.path.relpath(d, cwd).replace(os.sep, "/").split("/")
        if any(s in ("node_modules", "vendor") for s in segs):
            continue
        if os.path.isdir(d) and (os.path.isdir(os.path.join(d, "units"))
                                 or os.path.isdir(os.path.join(d, "bolts"))):
            sys.exit(0)
sys.exit(1)
PY
}

# ─── Shared python prologue (commit identity + layout discovery) ─────────────
# Injected at the top of each mode's heredoc via $PY_COMMON. One git call
# (`log --name-only`, pathspec-scoped to the project prefix in a monorepo —
# S6 EB-VAL-5) replaces the per-commit `git show` loop (300 subprocesses at
# gate time). Layout lookups come from _lib/vault_layouts.py (S6 EB-VAL-2).
PY_COMMON='
import glob, json, os, re, subprocess, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts

cwd = os.environ["CWD"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def git(*a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)

# Monorepo scoping (S6 EB-VAL-5): git names are repo-root-relative; the project
# may live at a prefix. All log walks are pathspec-scoped to the prefix so
# sibling projects never activate/starve this project'"'"'s gates.
PREFIX = git("rev-parse", "--show-prefix").stdout.strip()

UNIT_LEGACY = re.compile(r"\(bolt\):\s*(U-[A-Za-z0-9_-]+)")
UNIT_SCOPE = re.compile(r"^[A-Za-z]+!?\((U-[A-Za-z0-9_-]+)\)!?:")
UNIT_ANY = re.compile(r"(U-[A-Za-z0-9_-]+)")

def unit_of(subj, trailers):
    m = UNIT_LEGACY.search(subj) or UNIT_SCOPE.match(subj)
    if m:
        return m.group(1)
    if trailers:
        m = UNIT_ANY.search(trailers)
        if m:
            return m.group(1)
    return None

# Trailers atom (%(trailers:key=...)) needs git >= 2.23; on older git the whole log
# errors -> empty walk -> every gate fails OPEN. Probe once and fall back to a
# portable subject-only format (canonical scoped commits type(U-XXX): and legacy
# (bolt): U-XXX stay identified by subject).
def _git_ge(major, minor):
    try:
        p = git("--version").stdout.split()[2].split(".")
        return (int(p[0]), int(p[1])) >= (major, minor)
    except Exception:
        return False
_HAS_TRAILER_ATOM = _git_ge(2, 23)
WALK_FMT = ("%x01%H%x02%s%x02%(trailers:key=Unit,valueonly,separator=%x2C)"
            if _HAS_TRAILER_ATOM else "%x01%H%x02%s%x02")

def walk_args(n=300):
    # A git pathspec is relative to git cwd (the -C dir = the resolved project root),
    # so "-- ." scopes the walk to THIS project subtree AND still emits repo-root-
    # relative names. S6 EB-VAL-5 regression fix: a repo-root-relative PREFIX pathspec
    # (from --show-prefix) was resolved as PREFIX/PREFIX under the subproject and
    # matched nothing, silently disabling B1/B2/B3/orphan for every monorepo project.
    a = ["log", "--format=" + WALK_FMT, "--name-only", "-%d" % n]
    if PREFIX:
        a += ["--", "."]
    return a

# Real legacy *-bound vault roots (dirs that ACTUALLY hold units/ or bolts/). A code
# dir merely NAMED *-bound (io-bound, data-bound, cpu-bound) is NOT a vault. S6 fix:
# the old blanket (?:^|/)[^/]+-bound/ regex dropped such code dirs from the code set
# (B2 dormant) and sanctioned scope-escapes there (B3 blind).
def _bound_vault_roots():
    roots = set()
    for pat in (os.path.join(cwd, "*-bound"),
                os.path.join(cwd, "*", "*-bound"),
                os.path.join(cwd, "docs", "mega-sdd", "vaults", "*-bound")):
        for d in glob.glob(pat):
            if os.path.isdir(d) and (os.path.isdir(os.path.join(d, "units"))
                                     or os.path.isdir(os.path.join(d, "bolts"))):
                roots.add(os.path.relpath(d, cwd).replace(os.sep, "/").rstrip("/") + "/")
    return roots
_BOUND_ROOTS = _bound_vault_roots()
def _in_bound_vault(n):
    return any(n == r.rstrip("/") or n.startswith(r) for r in _BOUND_ROOTS)

def walk_log(n=300):
    """Newest-first [(sha, subject, unit_id_or_None, [repo-rel files])] in ONE git
    call. files lists are pathspec-scoped to THIS project subtree in a monorepo."""
    args = walk_args(n)
    r = git(*args)
    out = []
    for chunk in r.stdout.split("\x01"):
        if not chunk.strip():
            continue
        head, _, tail = chunk.partition("\n")
        parts = head.split("\x02")
        sha = parts[0].strip()
        subj = parts[1] if len(parts) > 1 else ""
        trailers = parts[2] if len(parts) > 2 else ""
        files = [l.strip() for l in tail.splitlines() if l.strip()]
        out.append((sha, subj, unit_of(subj, trailers), files))
    return out

# A "code" file = inside the project prefix, OUTSIDE .mega-sdd/ and the legacy
# vault trees (docs/mega-sdd/**, *-bound/** carry specs + bolt artifacts, not
# runnable code), and not a pure-docs file.
_DOC_EXT = (".md", ".markdown", ".rst", ".adoc")
def code_files(names):
    out = []
    for n in names:
        n = n.strip()
        if not n:
            continue
        if PREFIX:
            if not n.startswith(PREFIX):
                continue
            n = n[len(PREFIX):]
        if n.startswith(".mega-sdd/") or n.startswith("docs/mega-sdd/"):
            continue
        if _in_bound_vault(n):
            continue
        if os.path.splitext(n)[1].lower() in _DOC_EXT:
            continue
        out.append(n)
    return out
'

# ─── ORPHAN-SCAN mode ────────────────────────────────────────────────────────
if [ "$ORPHAN_SCAN" = "1" ]; then
  # Not a git repo (or no vault layout at all) → nothing to scan; no state written.
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  _gate_active || exit 0
  mkdir -p "${CWD}/.mega-sdd" 2>/dev/null || exit 0
  ORPHAN_STATE="${CWD}/.mega-sdd/.bolt-orphans-state.json"
  CWD="$CWD" ORPHAN_STATE="$ORPHAN_STATE" QUIET="$QUIET" python3 <<PYEOF
$PY_COMMON
state_file = os.environ["ORPHAN_STATE"]

bolted = {}  # unit_id -> first (newest) commit sha
for sha, subj, uid, _files in walk_log(300):  # S7-VAL-2: same window as B1/B2/B3
    if uid:
        bolted.setdefault(uid, sha)

orphans = []
for uid in sorted(bolted):
    if vault_layouts.find_unit_file(cwd, uid) and not vault_layouts.find_bolt_artifact(cwd, uid, "bolt-report.md"):
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
# (running 200s+ suites in a hook is exactly the inflation to avoid). The
# artifact is produced by scripts/run-full-suite.sh (S6 EB-GATE-4: the wrapper
# is the ONLY sanctioned write path — the artifact is Write/Edit-guarded).
# Design: docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md
if [ "$BATCH_SUITE_GATE" = "1" ]; then
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  _gate_active || exit 0
  mkdir -p "${CWD}/.mega-sdd" 2>/dev/null || exit 0
  BSG_STATE="${CWD}/.mega-sdd/.batch-suite-gate-state.json"
  CWD="$CWD" BSG_STATE="$BSG_STATE" QUIET="$QUIET" python3 <<PYEOF
$PY_COMMON
state_file = os.environ["BSG_STATE"]

# Two anchors over the newest-first log:
#   newest_bolt  — newest bolt commit touching code → ACTIVATES the gate
#                  (no code-bearing bolt yet ⇒ nothing to gate) + labels the failure.
#   newest_code  — newest commit touching code REGARDLESS of subject → the freshness
#                  anchor. Tracking only bolt commits left the OUT-OF-BAND half of the
#                  incident open: a hotfix / manual edit / git pull after a green suite
#                  still "covered" the (older) newest bolt and shipped green.
newest_bolt = None
newest_bolt_unit = None
newest_code = None
newest_code_is_bolt = False
for sha, subj, uid, files in walk_log(300):
    code = code_files(files)
    if code and newest_code is None:
        newest_code = sha
        newest_code_is_bolt = bool(uid)
    if uid and code and newest_bolt is None:
        newest_bolt = sha
        newest_bolt_unit = uid
    if newest_code is not None and newest_bolt is not None:
        break  # log is newest-first

RUN_HINT = ("Run \`bash <plugin>/scripts/run-full-suite.sh --cwd=<project-root>\` — it runs the "
            "project's FULL test suite (no per-unit scope filter) and records "
            "<vault>/bolts/_batch-suite.json with the pinned HEAD sha itself. The artifact is "
            "hook-guarded; direct writes are denied.")

def emit(status, halt_type=None, detail=None, extra=None):
    state = {"ts": ts, "mode": "batch-suite-gate", "status": status,
             "newest_bolt_commit": newest_bolt, "newest_bolt_unit": newest_bolt_unit}
    if halt_type:
        state["halt_type"] = halt_type
        state["detail"] = detail
        state["next_action"] = RUN_HINT + " execute-bolts is gated until a green full-suite result covers the newest code commit."
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

# Collect all batch-suite gate artifacts across vaults (all layouts — EB-VAL-2).
gates = []
for p in vault_layouts.batch_suite_files(cwd):
    try:
        with open(p) as f:
            g = json.load(f)
        g["_path"] = os.path.relpath(p, cwd)
        gates.append(g)
    except (OSError, ValueError):
        continue

# A RED suite blocks — but only a red that COVERS the newest code commit
# (same freshness anchor as green). S7-SUITE-4: a stale red (older sha, or a
# secondary vault's leftover) blocked FOREVER with a remediation that could
# never clear it — "fix the failing tests" when the tests are green, and
# run-full-suite used to rewrite only the first vault. A stale red is recorded
# for transparency and superseded by fresh evidence; with NO fresh evidence at
# all the gate still fails closed below (batch_suite_gate_missing).
def covers(head_sha):
    if not head_sha or not re.fullmatch(r"[0-9a-f]{40}", str(head_sha).lower()):
        return False
    return git("merge-base", "--is-ancestor", newest_code, str(head_sha)).returncode == 0

reds = [g for g in gates if str(g.get("status", "")).lower() == "red"]
red_fresh = [g for g in reds if covers(g.get("head_sha"))]
stale_reds = [g.get("_path") for g in reds if g not in red_fresh]
if red_fresh:
    emit("FAIL", "batch_suite_red",
         "the recorded full-suite result is RED (%s) — a cross-bolt/out-of-band regression is live; "
         "fix the failing tests and re-run run-full-suite.sh (it refreshes EVERY discovered vault's "
         "artifact; use --vault=<name> to target one) before any further bolt." % red_fresh[0].get("_path", "?"),
         {"red_gate": red_fresh[0].get("_path"), "stale_reds": stale_reds})

# A green gate "covers" the tree iff the NEWEST CODE commit (bolt OR out-of-band) is an
# ancestor of (or equal to) the gate's head_sha — i.e., the suite ran at or after the
# last code change landed (covers() above, shared with the red check). Anchoring on
# newest_code (not newest_bolt) closes the out-of-band half: a non-bolt code commit
# after a green suite is no longer covered. S6 EB-VAL-1: head_sha MUST be a full
# 40-hex sha — a symbolic rev ("HEAD", a branch name, "@") resolves at VALIDATION
# time, so one artifact would cover every future commit forever.
green_cover = [g for g in gates
               if str(g.get("status", "")).lower() == "green" and covers(g.get("head_sha"))]
if green_cover:
    # S7-SUITE-5: echo the runner into the gate state — the artifact records what
    # command actually produced the evidence, and an explicit --runner override is
    # surfaced (runner_overridden) so "some command exited 0" is never mistaken
    # for "the project's detected full suite ran".
    emit("PASS", extra={"covered_by": green_cover[0].get("_path"),
                        "newest_code_commit": newest_code,
                        "runner": green_cover[0].get("runner"),
                        "runner_overridden": bool(green_cover[0].get("runner_overridden")),
                        "stale_reds": stale_reds})

# Gate missing or stale (green but does not cover the newest code commit).
stale = any(str(g.get("status", "")).lower() == "green" for g in gates)
symbolic = [g.get("_path") for g in gates
            if str(g.get("status", "")).lower() == "green"
            and g.get("head_sha") and not re.fullmatch(r"[0-9a-f]{40}", str(g.get("head_sha")).lower())]
oob = not newest_code_is_bolt  # the uncovered change came in WITHOUT a bolt (out-of-band)
who = ("an OUT-OF-BAND code commit %s (no bolt provenance)" % newest_code[:9]) if oob \
      else ("bolt commit %s (%s)" % (newest_code[:9], newest_bolt_unit))
if stale:
    detail = ("a green full-suite result exists but is STALE — it does not cover %s; a code change "
              "landed after the last full-suite run." % who)
elif stale_reds:
    # S7-B r1-8: honest wording when the ONLY recorded evidence is a stale red —
    # it is too old to block, but nothing fresh covers the tree either.
    detail = ("the only recorded full-suite result(s) are STALE RED (%s) — too old to block, "
              "and nothing fresh covers %s." % (", ".join(stale_reds), who))
else:
    detail = ("no <vault>/bolts/_batch-suite.json records a full-suite run; %s shipped without a "
              "final full-suite gate." % who)
if symbolic:
    detail += (" NOTE: %s carries a symbolic head_sha (e.g. \"HEAD\") — rejected; the artifact "
               "must pin the full 40-hex sha (run-full-suite.sh records it correctly)." % symbolic[0])
emit("FAIL", "batch_suite_gate_missing", detail,
     {"stale": stale, "out_of_band": oob, "newest_code_commit": newest_code,
      "stale_reds": stale_reds})
PYEOF
  exit $?
fi

# ─── POSTFLIGHT-SCAN mode (B1) ───────────────────────────────────────────────
# A committed create/extend bolt whose unit has a non-empty ## Hard rules
# section must carry <vault>/bolts/U-XXX/postflight.json with all verdicts pass.
# The post-flight Hard-rule scan was prose-only ("HALT" that enforced nothing);
# this moves it to a hook gate. Verify units skip post-flight (no changes to validate).
# The evidence artifact is produced by scripts/run-postflight-scan.sh (S6
# EB-GATE-4: the wrapper is the ONLY sanctioned write path — Write/Edit-guarded).
# Design: docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md (§B1)
if [ "$POSTFLIGHT_SCAN" = "1" ]; then
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  _gate_active || exit 0
  mkdir -p "${CWD}/.mega-sdd" 2>/dev/null || exit 0
  PF_STATE="${CWD}/.mega-sdd/.bolt-postflight-state.json"
  CWD="$CWD" PF_STATE="$PF_STATE" QUIET="$QUIET" RECOMPUTE="$RECOMPUTE" python3 <<PYEOF
$PY_COMMON
import postflight_rules
state_file = os.environ["PF_STATE"]
recompute = os.environ.get("RECOMPUTE", "0") == "1"

# RECOMPUTE (B1 recompute-at-gate): reuse ONE --name-status walk for BOTH the bolted
# enumeration and per-unit Hard-rule re-execution. A forged/stale postflight.json is
# OVERWRITTEN with ground truth BEFORE postflight_ok reads it — the same "re-derive
# from ground truth at the gate" doctrine as the six state files, now extended to the
# evidence ARTIFACT itself (the gate used to trust its recorded status). Mechanical
# rules recompute fresh; directives carry their prior --attest-directives forward
# (an attacker cannot relabel a mechanical rule as a directive — scan_unit reclassifies
# from the rule TEXT). B2 (full suite, ~minutes) is NOT recomputed here — too expensive
# for the hot path — so it stays evidence-based. Design + measurement + honest ceiling:
# docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md §B1 amendment.
all_commits = postflight_rules.walk_unit_commits(git, PREFIX, 300) if recompute else None
_HEAD = git("rev-parse", "HEAD").stdout.strip() if recompute else ""

if recompute:
    bolted = {uid: cl[0][0] for uid, cl in all_commits.items() if cl}
else:
    bolted = {}  # unit_id -> newest commit sha
    for sha, subj, uid, _files in walk_log(300):
        if uid:
            bolted.setdefault(uid, sha)

def unit_text(uid, sha):
    """The unit's text — preferring its content AT the bolt commit (S6 EB-GATE-8:
    a retroactive unit edit — task_type flipped to verify, ## Hard rules blanked —
    must not erase an already-incurred B1 obligation). Falls back to the working
    tree when the vault is untracked or the unit is absent at that sha."""
    uf = vault_layouts.find_unit_file(cwd, uid)
    if not uf:
        return None
    rel = os.path.relpath(uf, cwd)
    if not rel.startswith(".."):
        r = git("show", "%s:%s" % (sha, (PREFIX + rel) if PREFIX else rel))
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout
    try:
        return open(uf).read()
    except OSError:
        return None

def task_type(text):
    fm = text.split("---", 2)
    front = fm[1] if len(fm) >= 3 else text
    m = re.search(r"(?m)^\s*task_type:\s*([A-Za-z_]+)", front)
    return (m.group(1).lower() if m else "")

def has_hard_rules(text):
    # body of the \`## Hard rules\` section (until the next \`## \` heading).
    # Case-INSENSITIVE heading + tolerate trailing text on the heading line — the
    # canonical unit template emits \`## Hard rules  (validated at bolt time ...)\`
    # (unit-schema.md), and units may use \`## Hard Rules\`. Matching only the bare
    # \`## Hard rules\` left the B1 gate INERT on template-conformant units.
    m = re.search(r"(?ims)^##[ \t]+Hard[ \t]+rules\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", text)
    if not m:
        return False
    # A line is "empty" (no real rule) if, after stripping markdown decoration, it
    # is blank or a recognised no-op phrasing. Curated set (NOT a wildcard) so a real
    # rule phrased oddly is never silently exempted (that would fail OPEN).
    # S6 EB-VAL-8: skip \`<\`-prefixed lines (HTML comments / placeholders) — the
    # unit-stage lexer (validate-unit-spec.sh) skips them, so counting them here
    # made a schema-conformant no-rules unit FAIL B1 with nothing to scan.
    # S7-B1-1: strip trailing punctuation before the lookup ("No hard rules apply."
    # normalized to "nohardrulesapply." ∉ set → bogus B1 obligation) and cover the
    # natural "None for this unit" phrasing (the old set carried the typo "nonfor").
    empties = {"none", "na", "n/a", "tbd", "todo", "nonefor", "noneforthisunit",
               "nohardrules", "nohardrulesforthisunit", "nohardrulesapply",
               "notapplicable", "nonerequired", "noneapplicable", "nonefornow"}
    for ln in m.group(1).splitlines():
        if ln.strip().startswith("<"):
            continue
        s = re.sub(r"[\`*_>\-\s]", "", ln).strip().lower().rstrip(".,;:!?")
        if s and s not in empties:
            return True
    return False

def postflight_ok(uid):
    """(found, ok) — found=postflight.json exists; ok=all verdicts pass."""
    p = vault_layouts.find_bolt_artifact(cwd, uid, "postflight.json")
    if not p:
        return (False, False)
    try:
        d = json.load(open(p))
    except (OSError, ValueError):
        return (True, False)  # present but unreadable = not valid evidence
    # Require POSITIVE evidence, never permissive defaults — an empty {} or an empty
    # rules[] must NOT pass (the constrained agent could satisfy the gate without ever
    # running the post-flight scan). status must be present + passing; rules must be
    # non-empty; every rule must carry a passing verdict (a missing verdict is NOT pass).
    # S6 EB-GATE-12: a \`directive\`-typed rule (generic MUST/DO NOT prose — not
    # machine-checkable by construction) may carry verdict "attested" (recorded by
    # run-postflight-scan.sh --attest-directives after controller/panel review).
    if str(d.get("status", "")).lower() not in ("pass", "passed", "ok", "green"):
        return (True, False)
    rules = d.get("rules")
    if not isinstance(rules, list) or not rules:
        return (True, False)  # vacuous — no per-rule evidence
    for rule in rules:
        v = str((rule or {}).get("verdict", "")).lower()
        if v in ("pass", "passed", "ok"):
            continue
        if v == "attested" and str((rule or {}).get("type", "")).lower() in ("directive", "directive_prose"):
            continue
        return (True, False)
    return (True, True)

def _bolt_dir(uid):
    """<vault>/bolts/<uid> — same derivation as run-postflight-scan.sh (writer)."""
    uf = vault_layouts.find_unit_file(cwd, uid)
    if not uf:
        return None
    d = os.path.dirname(uf)
    vr = os.path.dirname(d) if os.path.basename(d) == "units" else os.path.dirname(os.path.dirname(d))
    return os.path.join(vr, "bolts", uid)

def recompute_unit(uid, text):
    """Re-execute uid's Hard rules from ground truth and OVERWRITE its postflight.json.
    Uses the unit text AT THE BOLT COMMIT (the text the gate already resolved — obligation
    stickiness EB-GATE-8: a retroactive unit edit that blanks the Hard rules must not erase
    the incurred obligation, nor let a recompute find no-rules and pass). Scans with the
    SHARED engine (scan_unit) so the verdict is byte-identical to what the writer would produce;
    passes the prior artifact so a human --attest-directives review is carried forward."""
    bd = _bolt_dir(uid)
    if bd is None:
        return
    preflight = {}
    pf = os.path.join(bd, "preflight.json")
    if os.path.isfile(pf):
        try:
            preflight = json.load(open(pf))
        except (OSError, ValueError):
            preflight = {}
    target = os.path.join(bd, "postflight.json")
    prior = None
    if os.path.isfile(target):
        try:
            prior = json.load(open(target))
        except (OSError, ValueError):
            prior = None
    results, ok_all = postflight_rules.scan_unit(
        cwd, git, uid, text, all_commits.get(uid, []), preflight, "", prior_artifact=prior)
    artifact = {
        "unit_id": uid, "scanned_at": ts, "status": "pass" if ok_all else "fail",
        "head_sha": _HEAD, "written_by": "validate-bolt-artifacts.sh --recompute",
        "rules": results,
    }
    os.makedirs(bd, exist_ok=True)
    tmp = target + ".tmp.%d" % os.getpid()
    with open(tmp, "w") as f:
        json.dump(artifact, f, indent=1)
    os.replace(tmp, target)

issues = []
for uid in sorted(bolted):
    text = unit_text(uid, bolted[uid])
    if text is None:
        continue
    if task_type(text) == "verify":
        continue  # verify units skip post-flight (no changes to validate)
    if not has_hard_rules(text):
        continue  # no Hard rules → nothing to post-validate
    if recompute:
        recompute_unit(uid, text)  # overwrite forged/stale evidence with ground truth
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
                    "safety net was skipped. Run \`bash <plugin>/scripts/run-postflight-scan.sh "
                    "--cwd=<project-root> --unit=U-XXX\` for each listed unit (it executes the unit's "
                    "Hard rules deterministically and records the evidence itself; direct writes to "
                    "postflight.json are hook-denied). A recorded VIOLATION means the committed code "
                    "must be fixed first; execute-bolts is gated until resolved." % len(issues))
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

# ─── ACCEPTANCE-SCAN mode (B4 — P4 v4.96.0, the WAJIB accuracy floor) ────────
# A v5-keyed bolt (its commit carries the `SDD-Acceptance: v5` trailer stamped
# at commit time per bolt-contract.md) must carry <vault>/bolts/U-XXX/
# acceptance.json written by scripts/run-acceptance-tests.sh, fresh (its pinned
# head_sha covers the unit's newest bolt commit — the B2 covers() ancestry
# anchor) and non-red. COMMIT-KEYED so legacy bolts NEVER retro-block: the key
# is read from the bolt commit itself (git ground truth at commit time — the
# same read-obligation-at-commit precedent as B1's unit_text(), EB-GATE-8
# stickiness; a retro edit cannot add or erase it without rewriting history).
# Pre-v5 bolts lack the trailer → advisory note in the state, never a FAIL.
# Like B2 (and unlike B1) the artifact is READ, not recomputed — re-running
# acceptance tests inside a PreToolUse hook is the inflation the doctrine
# forbids; the write guard + the deterministic writer are the trust root.
if [ "$ACCEPTANCE_SCAN" = "1" ]; then
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  _gate_active || exit 0
  mkdir -p "${CWD}/.mega-sdd" 2>/dev/null || exit 0
  ACC_STATE="${CWD}/.mega-sdd/.bolt-acceptance-state.json"
  CWD="$CWD" ACC_STATE="$ACC_STATE" QUIET="$QUIET" python3 <<PYEOF
$PY_COMMON
state_file = os.environ["ACC_STATE"]

# unit -> all bolt commit shas (newest first) — commit identity per PY_COMMON.
per_unit = {}
for sha, subj, uid, _files in walk_log(300):
    if uid:
        per_unit.setdefault(uid, []).append(sha)

V5_TRAILER = re.compile(r"(?im)^SDD-Acceptance:\s*v5\b")
def v5_keyed(shas):
    """True iff ANY of the unit's bolt commits was stamped with the v5
    acceptance contract at commit time (a later v5 re-execution of a legacy
    unit re-keys it — that run DID owe acceptance evidence)."""
    for s in shas:
        if V5_TRAILER.search(git("show", "-s", "--format=%B", s).stdout or ""):
            return True
    return False

def covers(head_sha, newest):
    if not head_sha or not re.fullmatch(r"[0-9a-f]{40}", str(head_sha).lower()):
        return False  # symbolic sha rejected (S6 EB-VAL-1 parity)
    return git("merge-base", "--is-ancestor", newest, str(head_sha)).returncode == 0

RUN_HINT = ("Run \`bash <plugin>/scripts/run-acceptance-tests.sh --cwd=<project-root> "
            "--unit=U-XXX\` — it re-executes the unit's acceptance_test entries (plus the "
            "L0 syntax floor over the bolt's changed files) and records the evidence "
            "itself; the artifact is hook-guarded, direct writes are denied.")

issues = []
legacy_advisory = []
v5_count = 0
for uid in sorted(per_unit):
    shas = per_unit[uid]
    if vault_layouts.find_unit_file(cwd, uid) is None:
        continue  # retired unit — orphan-scan owns that case
    keyed = v5_keyed(shas)
    art_path = vault_layouts.find_bolt_artifact(cwd, uid, "acceptance.json")
    if not keyed:
        # LEGACY bolt: never blocked — advisory note at most (migration guarantee).
        if art_path is None:
            legacy_advisory.append(uid)
        continue
    v5_count += 1
    art = None
    if art_path:
        try:
            art = json.load(open(art_path))
        except (OSError, ValueError):
            art = None  # present but unreadable = not valid evidence
    if art is None:
        issues.append({
            "halt_type": "acceptance_evidence_missing", "unit_id": uid,
            "commit": shas[0],
            "detail": ("no readable <vault>/bolts/%s/acceptance.json — the bolt is v5-keyed "
                       "(SDD-Acceptance trailer) but the acceptance evidence was never "
                       "recorded" % uid),
        })
        continue
    if not covers(art.get("head_sha"), shas[0]):
        issues.append({
            "halt_type": "acceptance_evidence_missing", "unit_id": uid,
            "commit": shas[0],
            "detail": ("<vault>/bolts/%s/acceptance.json is STALE — its head_sha does not "
                       "cover the newest bolt commit %s (or is not a full 40-hex sha); "
                       "re-run run-acceptance-tests.sh at the current HEAD" % (uid, shas[0][:9])),
        })
        continue
    entries = art.get("entries") or []
    failing = [e for e in entries if isinstance(e, dict) and e.get("pass") is False]
    status = str(art.get("status", "")).lower()
    # Positive-evidence discipline (B1 postflight_ok parity): a recorded pass
    # with a failing entry inside is NOT pass.
    if status in ("pass", "pending_manual_only") and not failing:
        continue
    if failing and all(str(e.get("type", "")).lower() == "syntax" for e in failing):
        issues.append({
            "halt_type": "build_broken", "unit_id": uid, "commit": shas[0],
            "failing": [e.get("command", "") for e in failing][:5],
            "detail": ("<vault>/bolts/%s/acceptance.json records L0 SYNTAX failures — a "
                       "committed file fails its language's own syntax check (php -l / "
                       "py_compile / node --check / ruby -c); the build is broken at the "
                       "floor" % uid),
        })
    else:
        issues.append({
            "halt_type": "acceptance_red", "unit_id": uid, "commit": shas[0],
            "failing": [e.get("command", "") for e in failing][:5],
            "detail": ("<vault>/bolts/%s/acceptance.json records a non-pass result — an "
                       "acceptance_test entry failed against the committed code (after the "
                       "single bounded auto-retry)" % uid),
        })

state = {
    "ts": ts, "mode": "acceptance-scan",
    "status": "FAIL" if issues else "PASS",
    "bolt_units_seen": len(per_unit),
    "v5_keyed_units": v5_count,
    "legacy_advisory": legacy_advisory,
    "issues_count": len(issues), "issues": issues,
    "next_action": ("%d v5-keyed bolt(s) lack passing acceptance evidence. %s Fix the "
                    "committed code where the recorded result is red; execute-bolts is "
                    "gated until resolved." % (len(issues), RUN_HINT))
                   if issues else
                   ("Every v5-keyed bolt carries passing acceptance evidence."
                    + (" (%d legacy pre-v5 bolt(s) without acceptance.json — advisory only, "
                       "never blocked.)" % len(legacy_advisory) if legacy_advisory else "")),
}
tmp = state_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(state, f, indent=1)
os.replace(tmp, state_file)
if not quiet:
    print(json.dumps(state, indent=1))
sys.exit(1 if issues else 0)
PYEOF
  exit $?
fi

# ─── WHITELIST-SCAN mode (B3 — S6 EB-GATE-11) ────────────────────────────────
# The target_files whitelist was prompt-tier only ("honored", honestly worded in
# v4.58) — a scope-escaping bolt write shipped undetected: post-flight is
# path-scoped to the unit's own rules and no observer ever diffed the COMMITTED
# paths against the whitelist. This mode closes the invited gap: for each bolted
# unit, the union of paths its bolt commits touched must be ⊆ target_files ∪
# sanctioned extras (vault/bolt artifacts, .mega-sdd state, and test files —
# the implementer writes the acceptance test, which units often do not list).
# Writes .mega-sdd/.bolt-whitelist-state.json; the PreToolUse aggregator blocks
# the NEXT execute-bolts on FAIL.
if [ "$WHITELIST_SCAN" = "1" ]; then
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  _gate_active || exit 0
  mkdir -p "${CWD}/.mega-sdd" 2>/dev/null || exit 0
  WL_STATE="${CWD}/.mega-sdd/.bolt-whitelist-state.json"
  CWD="$CWD" WL_STATE="$WL_STATE" QUIET="$QUIET" python3 <<PYEOF
$PY_COMMON
import postflight_rules
state_file = os.environ["WL_STATE"]

# unit -> union of files its bolt commits touched (newest 300, subtree-scoped)
r = git(*walk_args(300))
per_unit = {}
for chunk in r.stdout.split("\x01"):
    if not chunk.strip():
        continue
    head, _, tail = chunk.partition("\n")
    parts = head.split("\x02")
    subj = parts[1] if len(parts) > 1 else ""
    trailers = parts[2] if len(parts) > 2 else ""
    uid = unit_of(subj, trailers)
    if not uid:
        continue
    files = []
    for l in tail.splitlines():
        l = l.strip()
        if not l:
            continue
        if PREFIX and l.startswith(PREFIX):
            l = l[len(PREFIX):]
        files.append(l)
    per_unit.setdefault(uid, {"sha": parts[0].strip(), "files": set()})["files"] |= set(files)

# Sanctioned extras: mega-sdd state/artifacts, vault trees, and test files.
_TEST_PAT = re.compile(
    r"(?:^|/)(?:tests?|spec|specs|__tests__)/|_test\.go$|Test\.php$|(?:^|/)test_[^/]+\.py$|\.(?:spec|test)\.[jt]sx?$")
def sanctioned(p):
    if p.startswith(".mega-sdd/") or p.startswith("docs/mega-sdd/"):
        return True
    if _in_bound_vault(p):
        return True
    if _TEST_PAT.search(p):
        return True
    return False

def targets_of(uid):
    uf = vault_layouts.find_unit_file(cwd, uid)
    if not uf:
        return None
    try:
        body = open(uf).read()
    except OSError:
        return None
    m = re.match(r"^---\n(.*?)\n---", body, re.DOTALL)
    if not m:
        return []
    out = []
    in_block = False
    for ln in m.group(1).split("\n"):
        if re.match(r"^target_files[ \t]*:", ln):
            in_block = True
            continue
        if in_block:
            if ln and ln[0] not in " \t":
                break
            pm = re.search(r"path:\s*(\S+)", ln)
            if pm:
                out.append(pm.group(1).strip().strip("'\""))
            elif re.match(r"^\s*-\s+[^:\s]+\s*$", ln):
                out.append(ln.strip().lstrip("-").strip().strip("'\""))
    # S7-B r2-4: a ./-prefixed declaration names the SAME file — strip it (the
    # anchored match would otherwise false-block a legit same-file commit).
    return [t[2:] if t.startswith("./") else t for t in out]

issues = []
units_checked = 0
for uid, info in sorted(per_unit.items()):
    targets = targets_of(uid)
    if targets is None:
        continue  # unit retired/not locatable — orphan-scan owns that case
    units_checked += 1
    escaped = []
    for p in sorted(info["files"]):
        if sanctioned(p):
            continue
        # S7-B3-1/2: exact path or ANCHORED segment-scoped glob, nothing looser.
        # The old suffix tolerances sanctioned DIFFERENT files (target app/config.py
        # blessed legacy/app/config.py; and the reverse blessed root config.py), and
        # raw fnmatch let * eat '/' (target src/*.py blessed src/a/b/evil.py) — the
        # exact defect the sibling B1 engine's _glob_match already fixed. Targets are
        # project-root-relative (generate-units emits them that way); the basename
        # fallback is OFF so a bare filename never sanctions a same-named file in a
        # different directory.
        ok = any(
            p == t or postflight_rules._glob_match(p, t, basename_fallback=False)
            for t in targets
        )
        if not ok:
            escaped.append(p)
    if escaped:
        issues.append({
            "halt_type": "whitelist_violation",
            "unit_id": uid,
            "commit": info["sha"],
            "escaped_files": escaped[:10],
            "detail": "bolt commit(s) for %s touched %d file(s) outside target_files: %s" % (
                uid, len(escaped), ", ".join(escaped[:5])),
        })

state = {
    "ts": ts, "mode": "whitelist-scan",
    "status": "FAIL" if issues else "PASS",
    "bolt_units_seen": len(per_unit),
    "units_checked": units_checked,
    "issues_count": len(issues), "issues": issues,
    "next_action": ("%d unit(s) committed files OUTSIDE their target_files whitelist. Either the "
                    "change is wrong (revert the escaped paths) or the unit under-declares its "
                    "scope (add the paths to target_files with the right operation and re-save); "
                    "execute-bolts is gated until resolved." % len(issues))
                   if issues else "Every bolt commit stayed inside its unit's target_files whitelist.",
}
tmp = state_file + ".tmp"
with open(tmp, "w") as f:
    json.dump(state, f, indent=1)
os.replace(tmp, state_file)
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

# S6 EB-GATE-6: never MINT a project root — this mode fires on EVERY Write via
# PostToolUse, and an unconditional mkdir created phantom .mega-sdd/ dirs under
# whatever cwd the session happened to resolve (state litter that then forked
# gate truth). No .mega-sdd/ at the resolved root → nothing to validate against.
[ -d "${CWD}/.mega-sdd" ] || exit 0
STATE_FILE="${CWD}/.mega-sdd/.bolt-artifacts-state.json"

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json
import os
import re
import sys
import glob
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts

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
    Walks every vault layout (S6 EB-VAL-2: shared discovery via vault_layouts).
    """
    abs_target = os.path.abspath(target_path)
    # Make target_path relative variants (units may declare relative paths)
    rel_target_from_cwd = os.path.relpath(abs_target, cwd) if abs_target.startswith(cwd) else None

    unit_paths = vault_layouts.unit_files(cwd)
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
# Provenance trailer format (per agents/bolt-implementer.md §Provenance trailer; values injected per-dispatch):
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
# Validates each cited D-NNN exists in some vault's decisions/ dir (all layouts).
if is_unit_path(file_path):
    try:
        body = open(file_path).read()
    except Exception:
        body = ""
    # Find Cites references — match Cites: §Decision-D-NNN, Cites: §D-NNN, Cites: D-NNN
    cite_pattern = re.compile(r"Cites:\s*§?(?:Decision-)?(D-[A-Z0-9-]*\d+)", re.IGNORECASE)
    # S6 EB-VAL-9: the finder is IGNORECASE but the compare was case-sensitive —
    # a lowercase cite (`§d-001`) matched the finder yet could never match the
    # filename inventory. Normalize BOTH sides to upper.
    cited = {c.upper() for c in cite_pattern.findall(body)}
    if cited:
        # Build inventory of available decision IDs from vault decisions/ (all layouts)
        available = set()
        for dec_dir in vault_layouts.decision_dirs(cwd):
            for f in glob.glob(os.path.join(dec_dir, "*.md")):
                # Filename pattern: D-NNN.md or D-P2-NNN.md etc.
                fname = os.path.basename(f).replace(".md", "")
                if fname.startswith("D-"):
                    available.add(fname.upper())
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
        else f"{len(issues)} integrity issue(s) detected. Each is detection-only (no auto-fix at hook layer); review listed issues and amend the unit / bolt-report manually, then re-save (PostToolUse re-validates)."
    ),
}

# Telemetry-only single-slot state (the PreToolUse aggregator never reads it —
# /mega-sdd:analyze surfaces it); current-truth overwrite per written file.
try:
    _tmp = state_file + ".tmp.%d" % os.getpid()
    with open(_tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(_tmp, state_file)
except Exception as e:
    print(f"ERROR: cannot write state file: {e}", file=sys.stderr)
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF

exit $?
