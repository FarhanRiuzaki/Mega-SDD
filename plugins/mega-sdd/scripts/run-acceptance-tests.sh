#!/usr/bin/env bash
# run-acceptance-tests.sh — deterministic writer for <vault>/bolts/U-XXX/acceptance.json (B4).
#
# P4 v4.96.0 (v5 spec P4 row; research §7 — the WAJIB accuracy bar): the unit's
# `acceptance_test[]` entries were executed only inside the implementer's own
# loop and left NO evidence artifact — "tests passed" was a self-report. This
# wrapper is the ONLY sanctioned write path for acceptance.json (the artifact is
# Write/Edit- and Bash-verb-guarded by the PreToolUse hook, exactly like
# preflight.json / postflight.json / _batch-suite.json): it RE-EXECUTES each
# acceptance_test entry against the committed tree and records per-entry
# verdicts itself. SIT's executed-evidence column (P5) reads this artifact.
#
# L0 SYNTAX FLOOR (deterministic home — documented choice): the zero-config
# syntax rung runs INSIDE this writer as a pre-rung, NOT as a separate script,
# so the evidence lands in the same hook-guarded acceptance.json and stays
# auditable next to the acceptance verdicts (one writer, one artifact, one
# guard). Over the union of files the unit's bolt commits touched (the SHARED
# walk_unit_commits walk — same identity grammar as the B1/B3 gates):
#   .php → php -l · .py → python3 -m py_compile · .js/.mjs/.cjs → node --check
#   · .rb → ruby -c
# Interpreter absent → the check is SKIPPED and recorded in `syntax_skipped`
# (detect-never-impose — the rung never installs or requires a toolchain).
# A syntax failure is recorded with NO retry (syntax is deterministic) and maps
# to halt `build_broken` at the gate/skill layer.
#
# ACCEPTANCE ENTRIES (structured authority = the unit frontmatter, parsed with
# the SAME `^acceptance_test\s*:` region extraction validate-unit-spec.sh uses):
#   - an entry WITH a `command:` (types test/lint/typecheck/render) is EXECUTED:
#     </dev/null, bounded timeout (default 120s, --timeout=<sec>), cwd=project
#     root. PASS = exit 0 AND (expects empty OR expects substring present in the
#     combined stdout+stderr). DECISION 9 (locked): exactly ONE bounded
#     auto-retry on failure, then the result is recorded (`retried: true`).
#   - an entry WITHOUT a command (type manual / desc-only) is recorded as
#     `pending_manual` — never executed, never fails the gate (SIT surfaces it).
#
# COMMIT-KEYING (migration guarantee — legacy bolts never retro-block): this
# writer always runs when invoked, but the B4 GATE
# (validate-bolt-artifacts.sh --acceptance-scan) only BLOCKS units whose bolt
# commits carry the `SDD-Acceptance: v5` trailer — the v5 contract stamped into
# the commit at commit time, mirroring the B1 read-obligation-at-commit
# precedent (validate-bolt-artifacts.sh unit_text(): obligation read from
# ground truth AT the bolt commit; EB-GATE-8 stickiness). Pre-v5 bolts lack the
# trailer and are advisory-only at the gate, forever.
#
# Usage:
#   run-acceptance-tests.sh --cwd=<project-root> --unit=U-XXX \
#       [--timeout=<seconds>] [--quiet]
# Exit: 0 = all executed entries pass (or pending-manual-only) — artifact written
#       1 = ≥1 executed entry failed (incl. the L0 syntax rung) — artifact written
#       2 = cannot run (usage / unit not found / not a git repo)
set -uo pipefail

CWD=""
UNIT=""
TIMEOUT=120
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --unit=*) UNIT="${arg#*=}" ;;
    --timeout=*) TIMEOUT="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then echo "ERROR: --cwd=<project-root> required" >&2; exit 2; fi
if [ -z "$UNIT" ]; then echo "ERROR: --unit=U-XXX required" >&2; exit 2; fi
case "$TIMEOUT" in ''|*[!0-9]*) echo "ERROR: --timeout must be an integer (seconds)" >&2; exit 2 ;; esac
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" UNIT="$UNIT" TIMEOUT="$TIMEOUT" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, shutil, subprocess, sys, time
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts
import postflight_rules
import plugin_meta
_T0 = time.time()

cwd = os.environ["CWD"]
unit_id = os.environ["UNIT"]
timeout_s = int(os.environ["TIMEOUT"])
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def git(*a):
    # BOUNDED. Note this is the REPO-METADATA helper, not the test runner — the
    # user-supplied acceptance commands below keep their own `--timeout` budget and
    # are deliberately left on it. Local git plumbing is low-risk, not zero-risk: an
    # fsmonitor daemon, a wedged index.lock, or a network-backed worktree can stall a
    # read-only call indefinitely, in a path Claude Code waits on. 60 s is 6x the
    # repo's own rev-parse precedent (refresh-doc-stamps.sh uses timeout=10).
    try:
        return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True,
                              timeout=60)
    except subprocess.TimeoutExpired:
        # FAIL-CLOSED to exit 2 ("cannot run"), NEVER a synthetic empty result: the
        # changed-file walk feeds the L0 syntax floor, and an empty result reads as
        # "nothing changed" — a silently EMPTY acceptance run that still writes a
        # green-looking artifact. Exit 2 is this script's documented cannot-run code.
        print("ERROR: `git %s` exceeded 60s — cannot run (wedged git/fsmonitor?). "
              "No artifact written." % " ".join(a), file=sys.stderr)
        sys.exit(2)

PREFIX = git("rev-parse", "--show-prefix").stdout.strip()

uf = vault_layouts.find_unit_file(cwd, unit_id)
if not uf:
    print("ERROR: unit %s not found under any vault layout" % unit_id, file=sys.stderr)
    sys.exit(2)
# vault root: <vault>/units/U-X.md → up 2; <vault>/units/U-X/unit.md → up 3
d = os.path.dirname(uf)
vault_root = os.path.dirname(d) if os.path.basename(d) == "units" else os.path.dirname(os.path.dirname(d))
bolt_dir = os.path.join(vault_root, "bolts", unit_id)

text = open(uf).read()

# ── Parse acceptance_test[] — the SAME region extraction validate-unit-spec.sh
# uses (^acceptance_test\s*: up to the next top-level key), then line-based
# entry collection in the targets_of() house style. REUSE, never a new YAML dep.
def parse_acceptance_entries(full_text):
    at = re.search(r"^acceptance_test\s*:\s*(.*?)(?=^\S|\Z)", full_text, re.DOTALL | re.MULTILINE)
    if not at:
        return []
    entries = []
    cur = None
    for ln in at.group(1).splitlines():
        if re.match(r"^\s*-\s", ln):
            if cur:
                entries.append(cur)
            cur = {}
            ln = re.sub(r"^\s*-\s*", "", ln)
        if cur is None:
            continue
        m = re.match(r"^\s*([A-Za-z_]+)\s*:\s*(.*)$", ln)
        if m:
            k = m.group(1).strip().lower()
            v = m.group(2).strip().strip("'\"")
            if k in ("type", "kind", "command", "expects", "desc", "ears"):
                cur.setdefault("type" if k == "kind" else k, v)
    if cur:
        entries.append(cur)
    return entries

acc_entries = parse_acceptance_entries(text)

# ── The bolt's changed files (SHARED walk — same commit identity as B1/B3) ───
unit_commits = postflight_rules.walk_unit_commits(git, PREFIX, 300).get(unit_id, [])
changed = []
seen = set()
for _sha, files in unit_commits:
    for st, p in files:
        if st[:1] == "D" or p in seen:
            continue
        seen.add(p)
        changed.append(p)

# ── L0 syntax floor pre-rung (zero-config; detect-never-impose; NO retry) ────
SYNTAX_CMDS = {
    ".php": ("php", ["php", "-l"]),
    ".py": ("python3", ["python3", "-m", "py_compile"]),
    ".js": ("node", ["node", "--check"]),
    ".mjs": ("node", ["node", "--check"]),
    ".cjs": ("node", ["node", "--check"]),
    ".rb": ("ruby", ["ruby", "-c"]),
}
def head_bytes(s, n=500):
    return s.encode("utf-8", errors="replace")[:n].decode("utf-8", errors="replace")
def tail_bytes(s, n=500):
    # F-18: the pass/fail summary is the LAST thing a runner prints; on the field
    # run a 500 B head was eaten by log noise on ≥6 entries and the counts were lost.
    b = s.encode("utf-8", errors="replace")
    return b[-n:].decode("utf-8", errors="replace") if len(b) > n else ""

results = []
syntax_skipped = []
for p in changed:
    ext = os.path.splitext(p)[1].lower()
    tool = SYNTAX_CMDS.get(ext)
    if not tool:
        continue
    ap = os.path.join(cwd, p)
    if not os.path.isfile(ap):
        continue
    binname, argv = tool
    if not shutil.which(binname):
        if binname not in syntax_skipped:
            syntax_skipped.append(binname)
        continue
    cmd_str = " ".join(argv + [p])
    try:
        r = subprocess.run(argv + [p], cwd=cwd, stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=timeout_s)
        rc, out = r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        rc, out = 124, "TIMEOUT after %ds" % timeout_s
    results.append({"type": "syntax", "command": cmd_str, "expects": "",
                    "rc": rc, "retried": False, "pass": rc == 0,
                    "output_head": head_bytes(out), "output_tail": tail_bytes(out)})

# ── Acceptance entries (executable = has a command; else pending_manual) ─────
def run_once(cmd):
    try:
        r = subprocess.run(cmd, shell=True, cwd=cwd, stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=timeout_s)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        return 124, "TIMEOUT after %ds" % timeout_s

for e in acc_entries:
    etype = (e.get("type") or "test").lower()
    cmd = e.get("command", "")
    if not cmd:
        # type manual (or any desc-only entry): recorded, never executed, never
        # fails the gate — SIT (P5) surfaces the pending column.
        results.append({"type": etype or "manual", "desc": e.get("desc", ""),
                        "pending_manual": True})
        continue
    expects = e.get("expects", "")
    rc, out = run_once(cmd)
    passed = (rc == 0) and ((not expects) or (expects in out))
    retried = False
    if not passed:
        # DECISION 9 (locked): exactly ONE bounded auto-retry, then record.
        retried = True
        rc, out = run_once(cmd)
        passed = (rc == 0) and ((not expects) or (expects in out))
    results.append({"type": etype, "command": cmd, "expects": expects,
                    "rc": rc, "retried": retried, "pass": passed,
                    "output_head": head_bytes(out), "output_tail": tail_bytes(out)})

executed = [r for r in results if "pass" in r]
pending = [r for r in results if r.get("pending_manual")]
if any(not r["pass"] for r in executed):
    status = "fail"
elif not executed and pending:
    status = "pending_manual_only"
else:
    status = "pass"

head_sha = git("rev-parse", "HEAD").stdout.strip()
artifact = {
    "unit_id": unit_id,
    "executed_at": ts,
    "status": status,
    "head_sha": head_sha,
    "written_by": "run-acceptance-tests.sh",
    "timeout_seconds": timeout_s,
    "entries": results,
    # F-18: how many executed `type: test` entries measured only rc==0 (no
    # `expects` substring) — 69/69 on the field run. Gated per unit at dispatch
    # (acceptance_expects_missing); recorded here so the evidence says so.
    "expects_missing": len([r for r in results if r.get("type") == "test"
                            and "pass" in r and not (r.get("expects") or "")]),
}
artifact.update(plugin_meta.stamp(os.environ["MEGA_SDD_LIB_DIR"],
                                  duration_ms=(time.time() - _T0) * 1000))
if syntax_skipped:
    artifact["syntax_skipped"] = syntax_skipped
os.makedirs(bolt_dir, exist_ok=True)
target = os.path.join(bolt_dir, "acceptance.json")
tmp = target + ".tmp.%d" % os.getpid()
with open(tmp, "w") as f:
    json.dump(artifact, f, indent=1)
os.replace(tmp, target)
if not quiet:
    # Quiet-gates discipline (M-05 parity): the B4 gate reads the ARTIFACT,
    # never stdout — one line on pass; the full artifact only on fail.
    if status != "fail":
        print("acceptance %s: %s (%d executed, %d pending manual%s) -> %s"
              % (unit_id, status, len(executed), len(pending),
                 ", syntax tools skipped: " + ",".join(syntax_skipped) if syntax_skipped else "",
                 target))
    else:
        print(json.dumps(artifact, indent=1))
sys.exit(0 if status != "fail" else 1)
PYEOF
ACC_EXIT=$?

# Refresh the B4 gate state immediately (READ-only refresh — the artifact was
# just written above; mirrors the run-postflight-scan.sh tail).
bash "${SCRIPT_DIR}/validate-bolt-artifacts.sh" --cwd="$CWD" --acceptance-scan --quiet >/dev/null 2>&1 || true
exit $ACC_EXIT
