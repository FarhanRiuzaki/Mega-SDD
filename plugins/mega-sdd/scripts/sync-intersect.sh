#!/usr/bin/env bash
# sync-intersect.sh — the sync-lane claim-intersection short-circuit gate
# (spec 2026-08-11-audit-phase2b-scripts-and-owners.md §S4).
#
#   sync-intersect.sh --cwd=<root> --vault=<vault-dir> [--paths=@<file>|<csv>]
#
# Intersects the changed set against the verification surface:
#   changed paths ∩ ( binding.json claims[].anchor paths
#                   ∪ every unit's target_files[].path from <vault>/units/U-*.md )
# and prints ONE JSON line:
#   {"changed": N, "intersecting": M, "verdict": "in_sync"|"reconcile_needed",
#    "intersect_paths": [...<=20]}
#
# Exit codes (the caller keys the chain on these — nothing else):
#   0 = in_sync          (M == 0: nothing the binding/units verified was touched)
#   4 = reconcile_needed (M  > 0: the full sync chain must run)
#   2 = FAIL-CLOSED      (ANY read/parse failure: missing vault, unreadable or
#       malformed binding.json, malformed unit frontmatter, unreadable paths
#       file, changed-set derivation failure — the caller MUST run the full
#       chain; this script never converts uncertainty into exit 0)
#
# WHY fail-closed: the short-circuit is a proportional-verification lever — an
# EMPTY intersection is a deterministic proof that there is nothing to
# re-verdict (no binding anchor and no unit target moved), so skipping the
# 4-hop reconcile loses zero verification. That proof only holds when every
# input parsed cleanly; the moment binding.json or a unit spec is unreadable
# we can no longer prove the intersection is empty, so the ONLY safe answer is
# "run the full chain" (exit 2), never a silent in_sync. Verification is cut
# proportionally to what provably did not change — never cut on a guess.
#
# Changed-set resolution:
#   --paths=@<file>  path-list file, one repo-relative path per line (the same
#                    consumer contract as <vault>/.sync-changed-paths.txt)
#   --paths=<csv>    comma-separated repo-relative paths
#   (absent)         REUSE scripts/derive-changed-paths.sh by invocation (never
#                    duplicated here), then read <vault>/.sync-changed-paths.txt.
#                    NOTE: that delegated hop writes the durable set file — its
#                    own contract; sync-intersect itself writes nothing.
#
# Comparison is conservative: paths are normalized repo-relative, and a match
# is exact OR ancestor-dir (a changed file UNDER an anchored/target directory
# counts as intersecting, in both directions). A slash-less anchor piece (the
# canonical schema example "UserController.php:45") can never equal a
# repo-relative changed path, so it matches by BASENAME — a changed path
# whose final component equals the piece intersects (conservative
# over-trigger is the safe direction; a false in_sync is verification loss).
#
# Evidence trail (reused shapes, never reinvented):
#   - binding.json schema: skills/bind-codebase/references/binding-json-schema.md
#     (claims[].anchor: "UserController.php:45 + routes/api.php:12" | null)
#   - anchor parse: scripts/build-graph.sh claims[].anchor reader — split on
#     `\s*\+\s*`, strip the :line suffix (anchor_id). The file-like filter is
#     WIDENED here vs build-graph.sh's extension whitelist: any piece with a
#     '/', a ':', or a dot-extension of any letters/digits is file-like
#     (slash-less pieces basename-matched); pieces with none of those are
#     prose words and stay dropped.
#   - target_files parse: scripts/analyze-parallelism.sh target_paths() —
#     literal `path:` values inside the frontmatter `target_files:` block;
#     inline `target_files: []` = empty. python3 stdlib only, like siblings.
set -u
CWD="."
VAULT=""
PATHS=""
while [ $# -gt 0 ]; do case "$1" in
  --cwd) CWD="$2"; shift 2;;
  --cwd=*) CWD="${1#*=}"; shift;;
  --vault) VAULT="$2"; shift 2;;
  --vault=*) VAULT="${1#*=}"; shift;;
  --paths) PATHS="$2"; shift 2;;
  --paths=*) PATHS="${1#*=}"; shift;;
  *) echo "usage: sync-intersect.sh --cwd=<root> --vault=<dir> [--paths=@<file>|<csv>]" >&2; exit 2;;
esac; done
[ -n "$VAULT" ] || { echo "FAIL: --vault is required (fail-closed: run the full sync chain)" >&2; exit 2; }
[ -d "$CWD" ]   || { echo "FAIL: cwd not found: $CWD (fail-closed: run the full sync chain)" >&2; exit 2; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT (fail-closed: run the full sync chain)" >&2; exit 2; }

# No --paths → derive via the sync lane's own channel (reuse by invocation).
if [ -z "$PATHS" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if ! "$SCRIPT_DIR/derive-changed-paths.sh" --cwd="$CWD" --vault="$VAULT" >/dev/null 2>&1; then
    echo "FAIL: changed-set derivation failed (derive-changed-paths.sh) — fail-closed: run the full sync chain." >&2
    exit 2
  fi
  PATHS="@$VAULT/.sync-changed-paths.txt"
fi

V_CWD="$CWD" V_VAULT="$VAULT" V_PATHS="$PATHS" python3 <<'PYEOF'
import glob, json, os, re, sys

cwd = os.path.abspath(os.environ["V_CWD"])
vault = os.environ["V_VAULT"]
raw = os.environ["V_PATHS"]


def die(msg):
    # Fail-closed: ANY read/parse failure -> exit 2, never a silent in_sync.
    print("FAIL: %s (fail-closed: run the full sync chain)" % msg, file=sys.stderr)
    sys.exit(2)


def norm(p):
    """Repo-relative normal form: forward slashes, no ./, no trailing /."""
    p = str(p).strip().strip("'\"").replace("\\", "/")
    if not p:
        return None
    if re.match(r"^[A-Za-z]:/", p) or os.path.isabs(p):
        rel = os.path.relpath(p, cwd).replace("\\", "/")
        if rel == ".." or rel.startswith("../"):
            return None  # escapes the repo — not comparable
        p = rel
    while p.startswith("./"):
        p = p[2:]
    return p.rstrip("/") or None


# 1. Changed set — @file (one path per line) or CSV, exactly as the sync lane
# passes it (same contract as <vault>/.sync-changed-paths.txt).
if raw.startswith("@"):
    try:
        with open(raw[1:], encoding="utf-8", errors="replace") as f:
            entries = [ln for ln in f.read().splitlines()]
    except OSError as e:
        die("cannot read paths file %s (%s)" % (raw[1:], e))
else:
    entries = raw.split(",")
changed = sorted({q for q in (norm(e) for e in entries) if q})

# 2a. Binding anchor paths — <vault>/binding.json claims[].anchor, parsed the
# way scripts/build-graph.sh parses the same field (split on '+', keep
# code-ish pieces, strip the :line suffix).
bj_path = os.path.join(vault, "binding.json")
try:
    with open(bj_path, encoding="utf-8") as f:
        bj = json.load(f)
except (OSError, ValueError) as e:
    die("unreadable/unparseable binding.json at %s (%s)" % (bj_path, e))
if not isinstance(bj, dict) or not isinstance(bj.get("claims"), list):
    die("binding.json has no claims[] list (%s)" % bj_path)

targets = set()
basenames = set()  # slash-less anchor pieces — matched by basename (header)
for c in bj["claims"]:
    if not isinstance(c, dict):
        die("binding.json claims[] entry is not an object (%s)" % bj_path)
    anc = c.get("anchor")
    if not anc or anc in ("—", "n/a"):
        continue
    for piece in re.split(r"\s*\+\s*", str(anc)):
        piece = piece.strip()
        if not piece:
            continue
        # File-like filter (WIDENED vs build-graph.sh's extension whitelist):
        # a '/', a ':', or a dot-extension of any letters/digits marks the
        # piece file-like; pieces with none of those are prose words
        # ("verified against spec") and stay dropped.
        if ":" in piece or "/" in piece or re.search(
                r"\.[A-Za-z0-9]+$", piece):
            p = norm(re.sub(r":\d+(-\d+)?$", "", piece))  # anchor_id()
            if not p:
                continue
            if "/" in p:
                targets.add(p)
            else:
                # Slash-less piece (canonical schema example
                # "UserController.php:45"): never equals a repo-relative
                # changed path — match by BASENAME instead (conservative
                # over-trigger is the safe direction).
                basenames.add(p)

# 2b. Unit target_files[].path — <vault>/units/U-*.md frontmatter, block
# list-of-maps per analyze-parallelism.sh target_paths(); inline `[]` = empty.
for up in sorted(glob.glob(os.path.join(vault, "units", "U-*.md"))):
    try:
        with open(up, encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError as e:
        die("cannot read unit %s (%s)" % (up, e))
    m = re.match(r"\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\Z)", text, re.S)
    if not m:
        die("unit %s has no YAML frontmatter block" % up)
    fm = m.group(1)
    key = re.search(r"(?m)^target_files[ \t]*:[ \t]*(.*)$", fm)
    if not key:
        die("unit %s frontmatter has no target_files key" % up)
    inline = key.group(1).strip()
    if inline and inline != "[]":
        if inline.startswith("[") and inline.endswith("]"):
            for item in inline[1:-1].split(","):
                p = norm(item)
                if p:
                    targets.add(p)
        else:
            die("unit %s target_files is neither a block list nor []" % up)
    elif not inline:
        # Block list-of-maps: indented lines until dedent; take `path:` values.
        for line in fm[key.end():].split("\n"):
            if line.strip() == "" or re.match(r"^[ \t]", line):
                pm = re.search(r"path:[ \t]*(.+?)[ \t]*$", line)
                if pm:
                    p = norm(pm.group(1))
                    if p:
                        targets.add(p)
            else:
                break  # dedent ends the block

# 3. Intersect — exact match OR ancestor-dir containment (both directions:
# a changed file under a target dir counts, and a changed dir over a target
# file counts — conservative by construction). Slash-less anchor pieces
# match any changed path whose final component equals them (basename lane).
hits = []
for c in changed:
    hit = any(c == t or c.startswith(t + "/") or t.startswith(c + "/")
              for t in targets)
    if not hit and c.rsplit("/", 1)[-1] in basenames:
        hit = True
    if hit:
        hits.append(c)
hits = sorted(set(hits))

verdict = "reconcile_needed" if hits else "in_sync"
print(json.dumps({
    "changed": len(changed),
    "intersecting": len(hits),
    "verdict": verdict,
    "intersect_paths": hits[:20],
}, sort_keys=False))
sys.exit(4 if hits else 0)
PYEOF
