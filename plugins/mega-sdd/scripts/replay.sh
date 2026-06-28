#!/usr/bin/env bash
# replay.sh — capture a bolt-state snapshot for one unit + classify divergence
# vs the latest prior snapshot. Read-only diagnostic (audit batch E / finding F4,
# extracted from commands/replay.md Steps 2-5 — self-labeled DETERMINISTIC).
#
# The genuine LLM-judgment / hand-off interpretation (Step 6 table) stays in the
# command; this script does ONLY the deterministic part: read bolt artifacts →
# build a snapshot → diff vs prior → classify by the fixed severity table → render.
#
# GROUNDING (moat invariant #5 — no fabrication). Snapshot fields are sourced
# ONLY from artifacts execute-bolts actually writes:
#   - <vault>/bolts/<unit>/bolt-report.md  → frontmatter `status:` + `target_hashes:`
#   - <vault>/bolts/<unit>/postflight.json → `status` + `rules[].{type,verdict,evidence}`
#   - <vault>/bolts/<unit>/preflight.json  → `rules[]`
#   - target files (from target_hashes keys) → live sha256, recomputed each run
# Fields the command illustrates but NO artifact records (test_exit_code,
# test_duration_ms, git_sha_before/after, lines_changed) are NOT fabricated:
# they are captured-if-present and classified ONLY when present on BOTH snapshots.
# Cosmetic timestamp keys are excluded from the diff (cosmetic→LOW→ignore is
# realized by NOT comparing them, not by post-hoc judgment).
#
# Usage:
#   replay.sh <unit-id> [--vault=<path>] [--cwd=<path>] [--capture-only]
#             [--diff-against=<replay-id>] [--format=table|json]
#   <unit-id>              Required positional, e.g. U-001.
#   --vault=<path>         Vault dir (default: auto-probe under --cwd).
#   --cwd=<path>           Project root (default: current dir). cd'd once at top.
#   --capture-only         Snapshot only; skip the diff/classify step.
#   --diff-against=<id>    Diff vs a specific historical snapshot basename stem
#                          (e.g. U-001-2026-05-21T11-45-00Z) instead of latest prior.
#   --format=table|json    Output format (default table).
#
# Exit: 0 = captured ok (incl. first-run baseline, --capture-only, no/low/medium divergence)
#       1 = HIGH-severity divergence detected (regression — serves CI use-case)
#       2 = usage error | unit/vault not found
set -euo pipefail

UNIT=""
VAULT=""
CWD="."
CAPTURE_ONLY=0
DIFF_AGAINST=""
FORMAT="table"

for arg in "$@"; do
  case "$arg" in
    --vault=*)        VAULT="${arg#*=}" ;;
    --cwd=*)          CWD="${arg#*=}" ;;
    --capture-only)   CAPTURE_ONLY=1 ;;
    --diff-against=*) DIFF_AGAINST="${arg#*=}" ;;
    --format=*)       FORMAT="${arg#*=}" ;;
    -h|--help)        sed -n '2,40p' "$0"; exit 0 ;;
    --*)              echo "replay: unknown argument: $arg" >&2; exit 2 ;;
    *)
      if [ -z "$UNIT" ]; then UNIT="$arg"
      else echo "replay: unexpected extra positional: $arg" >&2; exit 2; fi
      ;;
  esac
done

[ -n "$UNIT" ] || { echo "replay: <unit-id> is required (e.g. U-001)" >&2; exit 2; }
case "$FORMAT" in table|json) ;; *) echo "replay: --format must be table|json" >&2; exit 2 ;; esac
[ -d "$CWD" ] || { echo "replay: --cwd is not a directory: $CWD" >&2; exit 2; }
cd "$CWD"

# --------------------------------------------------------------------------
# Resolve vault (canonical first, then legacy) unless --vault given explicitly.
# --------------------------------------------------------------------------
if [ -z "$VAULT" ]; then
  for cand in ./.mega-sdd/vaults/*/ ./docs/mega-sdd/vaults/*/; do
    [ -e "$cand" ] || continue
    [ -f "${cand}vault.json" ] || continue
    if [ -d "${cand}bolts/$UNIT" ]; then VAULT="${cand%/}"; break; fi
    [ -z "$VAULT" ] && VAULT="${cand%/}"  # fallback: first vault that exists
  done
fi
[ -n "$VAULT" ] && [ -d "$VAULT" ] || {
  echo "replay: no vault found (looked under .mega-sdd/vaults/ + docs/mega-sdd/vaults/). Pass --vault=<path>." >&2
  exit 2
}

BOLT_DIR="$VAULT/bolts/$UNIT"
[ -d "$BOLT_DIR" ] || {
  echo "replay: no bolt artifacts for $UNIT at $BOLT_DIR — has execute-bolts run for this unit?" >&2
  exit 2
}

REPLAY_DIR="$VAULT/.internal/replays"
mkdir -p "$REPLAY_DIR"

# Unique per-run stem: timestamp + PID so two runs in the same second don't
# collide (the command's Step 3 selects one file PER run via `ls -t … 2p`).
TS="$(date -u +%Y-%m-%dT%H-%M-%SZ 2>/dev/null || echo unknown)"
STEM="${UNIT}-${TS}-$$"
CURRENT="$REPLAY_DIR/${STEM}.json"

# --------------------------------------------------------------------------
# Step 2 — capture current bolt state. python3 (no YAML/JSON lib deps beyond
# stdlib) reads bolt-report frontmatter + preflight/postflight JSON + live
# target sha256. Mirrors the read-only precedent in compute-unit-staleness.sh.
# --------------------------------------------------------------------------
python3 - "$VAULT" "$UNIT" "$BOLT_DIR" "$TS" > "$CURRENT" <<'PYEOF'
import glob, hashlib, json, os, re, sys

vault, unit, bolt_dir, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
project = os.getcwd()

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None

def load_json(path):
    txt = read(path)
    if txt is None:
        return None
    try:
        return json.loads(txt)
    except (ValueError, TypeError):
        return None

# --- bolt-report.md frontmatter: status + target_hashes (tolerant line parse,
#     same approach as compute-unit-staleness.sh — no YAML dependency) ---
def parse_bolt_report(path):
    txt = read(path)
    if txt is None:
        return None, {}, {}
    m = re.match(r"\A---\n(.*?)\n---\n", txt, re.S)
    fm = m.group(1) if m else ""
    status = None
    extras = {}            # capture-if-present aspirational scalar fields
    hashes = {}
    in_hashes = False
    for line in fm.split("\n"):
        sm = re.match(r"^status:\s*(.+?)\s*(#.*)?$", line)
        if sm and status is None:
            status = sm.group(1).strip().strip('"\'')
        # capture-if-present (NOT fabricated): only recorded if the artifact has them
        for key in ("git_sha_before", "git_sha_after", "test_command",
                    "test_exit_code", "test_duration_ms"):
            km = re.match(r"^%s:\s*(.+?)\s*(#.*)?$" % re.escape(key), line)
            if km and key not in extras:
                extras[key] = km.group(1).strip().strip('"\'')
        if re.match(r"^target_hashes:\s*(#.*)?$", line):
            in_hashes = True
            continue
        if in_hashes:
            hm = re.match(r"^\s+([^\s:][^:]*):\s*([0-9a-f]{64})\s*(#.*)?$", line)
            if hm:
                hashes[hm.group(1).strip()] = hm.group(2)
            elif line.strip() and not line.startswith((" ", "\t")):
                in_hashes = False
    return status, hashes, extras

bolt_status, recorded_hashes, extras = parse_bolt_report(os.path.join(bolt_dir, "bolt-report.md"))

# --- live target-file sha256 (recomputed every run; the real reproducibility
#     signal). Missing file is recorded, never crashes the capture. ---
target_files = []
for rel in sorted(recorded_hashes.keys()):
    p = os.path.join(project, rel)
    entry = {"path": rel, "recorded_sha256": recorded_hashes[rel]}
    if os.path.isfile(p):
        entry["live_sha256"] = sha256_file(p)
    else:
        entry["live_sha256"] = None
        entry["missing"] = True
    target_files.append(entry)

# --- postflight.json: status + per-rule verdicts ---
post = load_json(os.path.join(bolt_dir, "postflight.json"))
hard_rules = []
postflight_status = None
if isinstance(post, dict):
    postflight_status = post.get("status")
    for r in post.get("rules", []) or []:
        if isinstance(r, dict):
            rid = r.get("function") or r.get("path") or r.get("type") or "?"
            hard_rules.append({"rule_id": rid, "type": r.get("type"),
                               "verdict": r.get("verdict")})

# --- preflight.json: rule snapshot (presence/count only — the sha snapshots
#     are an execute-bolts internal, not a divergence signal here) ---
pre = load_json(os.path.join(bolt_dir, "preflight.json"))
preflight_rule_count = len(pre.get("rules", [])) if isinstance(pre, dict) else 0

# halt = bolt-report status that begins halted_* (partial snapshot per command)
halt = bolt_status if (bolt_status and bolt_status.startswith("halted")) else None

snapshot = {
    "replay_schema": 1,
    "unit_id": unit,
    "captured_at": ts,                 # cosmetic — excluded from diff
    "bolt_status": bolt_status,
    "halt": halt,
    "target_files": target_files,
    "hard_rules_validated": hard_rules,
    "postflight_status": postflight_status,
    "preflight_rule_count": preflight_rule_count,
}
# capture-if-present aspirational fields (only when the artifact actually had them)
for k, v in extras.items():
    snapshot[k] = v

print(json.dumps(snapshot, indent=2))
PYEOF

echo "replay: captured $UNIT snapshot → ${CURRENT#./}"

# --------------------------------------------------------------------------
# Step 3 — select prior snapshot.
#   default: latest snapshot strictly OLDER than the one just written.
#   --diff-against=<stem>: a specific historical basename stem.
# --------------------------------------------------------------------------
PRIOR=""
if [ -n "$DIFF_AGAINST" ]; then
  cand="$REPLAY_DIR/${DIFF_AGAINST}.json"
  if [ -f "$cand" ] && [ "$cand" != "$CURRENT" ]; then
    PRIOR="$cand"
  else
    echo "replay: --diff-against snapshot not found: ${DIFF_AGAINST}.json" >&2
    exit 2
  fi
else
  # newest-first listing of THIS unit's snapshots; skip CURRENT, take next.
  # EXCLUDE the `${UNIT}-divergence.json` diff-result artifact — it shares the
  # `${UNIT}-` prefix + `.json` suffix but is NOT a snapshot; selecting it as a
  # prior yields garbage diffs across repeated runs (it accumulates in the dir).
  while IFS= read -r f; do
    [ -e "$f" ] || continue
    [ "$f" = "$CURRENT" ] && continue
    case "$f" in *-divergence.json) continue ;; esac
    PRIOR="$f"; break
  done < <(ls -t "$REPLAY_DIR/${UNIT}-"*.json 2>/dev/null)
fi

if [ "$CAPTURE_ONLY" -eq 1 ]; then
  echo "replay: --capture-only — baseline saved, diff skipped."
  exit 0
fi

if [ -z "$PRIOR" ]; then
  echo "replay: no prior snapshot for $UNIT — baseline captured. Re-run after the next bolt to compare."
  exit 0
fi

# --------------------------------------------------------------------------
# Steps 4 + 5 — classify divergence by the FIXED severity table, render.
# Severity rules (from commands/replay.md Step 4), gated on field presence so
# aspirational fields only count when present on BOTH snapshots:
#   HIGH  : target sha differs on same path | hard-rule verdict changed |
#           halt null<->populated | postflight_status changed |
#           test_exit_code changed (if present both)
#   MEDIUM: test_duration_ms change >50% (if present both)
#   LOW   : cosmetic (timestamps) — excluded from comparison entirely
# Exit 1 iff any HIGH; else 0.
# --------------------------------------------------------------------------
# Stable divergence-artifact path the command's Step 6 hand-off references.
DIVERGENCE_JSON="$REPLAY_DIR/${UNIT}-divergence.json"

HIGH_FOUND=0
if python3 - "$PRIOR" "$CURRENT" "$FORMAT" "$DIVERGENCE_JSON" <<'PYEOF'
import json, sys

prior_p, current_p, fmt, divergence_out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    prior = json.load(open(prior_p))
except (ValueError, OSError) as e:
    print("replay: prior snapshot unreadable (%s) — treating as divergent." % e, file=sys.stderr)
    prior = {"_unreadable": True}
current = json.load(open(current_p))

COSMETIC = {"captured_at"}   # excluded from comparison (cosmetic→LOW→ignore)
high, medium, low, same = [], [], [], []

if prior.get("_unreadable"):
    # A corrupt/unreadable prior is itself a HIGH signal — never silently "clean".
    high.append("prior snapshot unreadable — cannot confirm reproducibility")

def tf_map(snap):
    return {e["path"]: e for e in snap.get("target_files", [])}

# target files: compare live sha on shared paths (real reproducibility signal)
pf, cf = tf_map(prior), tf_map(current)
for path in sorted(set(pf) | set(cf)):
    if path in pf and path in cf:
        a = pf[path].get("live_sha256")
        b = cf[path].get("live_sha256")
        if a == b:
            same.append("target_files.%s (sha unchanged)" % path)
        else:
            high.append("target_files.%s: live sha256 %s -> %s" %
                        (path, str(a)[:12], str(b)[:12]))
    else:
        high.append("target_files set changed: %s %s" %
                    ("+" if path in cf else "-", path))

# postflight status
if prior.get("postflight_status") != current.get("postflight_status"):
    high.append("postflight_status: %s -> %s" %
                (prior.get("postflight_status"), current.get("postflight_status")))
else:
    same.append("postflight_status (%s)" % current.get("postflight_status"))

# hard-rule verdicts (by rule_id)
def hr_map(snap):
    return {r.get("rule_id"): r.get("verdict") for r in snap.get("hard_rules_validated", [])}
ph, ch = hr_map(prior), hr_map(current)
for rid in sorted(set(ph) | set(ch)):
    if ph.get(rid) != ch.get(rid):
        high.append("hard_rule[%s].verdict: %s -> %s" % (rid, ph.get(rid), ch.get(rid)))
if ph == ch:
    same.append("hard_rules_validated (%d rule(s) unchanged)" % len(ch))

# halt: null <-> populated is HIGH (pipeline behavior changed)
if bool(prior.get("halt")) != bool(current.get("halt")):
    high.append("halt: %r -> %r" % (prior.get("halt"), current.get("halt")))

# aspirational, classify-only-when-present-on-BOTH (never fabricated)
if "test_exit_code" in prior and "test_exit_code" in current:
    if prior["test_exit_code"] != current["test_exit_code"]:
        high.append("test_exit_code: %s -> %s" % (prior["test_exit_code"], current["test_exit_code"]))
if "test_duration_ms" in prior and "test_duration_ms" in current:
    try:
        a = float(prior["test_duration_ms"]); b = float(current["test_duration_ms"])
        if a > 0 and abs(b - a) / a > 0.5:
            medium.append("test_duration_ms: %s -> %s (>50%%)" % (a, b))
    except (ValueError, TypeError):
        pass

# cosmetic-only timestamp delta -> LOW (informational; never a violation)
for k in COSMETIC:
    if prior.get(k) != current.get(k):
        low.append("%s (timestamp only — ignored)" % k)

verdict_high = len(high) > 0
result = {
    "unit_id": current.get("unit_id"),
    "prior": prior_p, "current": current_p,
    "high": high, "medium": medium, "low": low, "unchanged": same,
    "verdict": "REGRESSION" if verdict_high else ("VARIANCE" if medium else "REPRODUCIBLE"),
}

# Persist the divergence artifact the command's Step 6 hand-off points reviewers
# at. Always written (stable path) so a HIGH verdict has an inspectable file.
try:
    with open(divergence_out, "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=2)
except OSError:
    pass  # advisory artifact; never fail the run on a write hiccup

if fmt == "json":
    print(json.dumps(result, indent=2))
else:
    print("")
    print("Replay analysis: %s" % result["unit_id"])
    print("  prior:   %s" % prior_p)
    print("  current: %s" % current_p)
    print("")
    if same:
        print("  [no divergence]")
        for s in same: print("     - %s" % s)
    if medium:
        print("  [MEDIUM]")
        for m in medium: print("     - %s" % m)
    if low:
        print("  [LOW]")
        for l in low: print("     - %s" % l)
    if high:
        print("  [HIGH]")
        for h in high: print("     - %s" % h)
    else:
        print("  [HIGH] none.")
    print("")
    print("Verdict: %s" % result["verdict"])

sys.exit(1 if verdict_high else 0)
PYEOF
then
  HIGH_FOUND=0
else
  HIGH_FOUND=1
fi

# Optional canonical field-level patch (only if `jd` is installed — never a hard
# dep, per the command's "zero new runtime deps"). The .json artifact above is
# the always-present one the hand-off relies on; this .patch is a bonus.
if command -v jd >/dev/null 2>&1; then
  jd "$PRIOR" "$CURRENT" > "$REPLAY_DIR/${UNIT}-divergence.patch" 2>/dev/null || true
fi

exit "$HIGH_FOUND"
