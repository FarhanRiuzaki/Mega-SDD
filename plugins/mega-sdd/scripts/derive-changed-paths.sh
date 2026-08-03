#!/usr/bin/env bash
# derive-changed-paths.sh — the express-born Mode D changed-set producer.
# Map-bearing projects keep `scan-codebase --changed-only` (which refreshes
# the map AND writes this file); projects that never grew a map (express
# spine) derive the durable changed set deterministically instead:
#   changed = git diff --name-only <symbol-index head_commit>..HEAD
#           ∪ dirty-journal rows (.mega-sdd/codebase/.dirty-paths.jsonl —
#             in-session edits not yet committed)
# Output: <vault>/.sync-changed-paths.txt (one path per line, repo-relative,
# sorted, deduped) — the SAME consumer contract detect-drift --scope=@ and
# bind-codebase --paths=@ already read. The journal is rotated to
# .consumed-<ts> exactly like scan --changed-only does (never truncated).
# Exit 0 = written; 2 = usage; 3 = no freshness stamp (index absent/unreadable
# or not a git repo) — the caller falls back to a full re-bind, never guesses.
set -u
CWD="."
VAULT=""
while [ $# -gt 0 ]; do case "$1" in
  --cwd) CWD="$2"; shift 2;;
  --cwd=*) CWD="${1#*=}"; shift;;
  --vault) VAULT="$2"; shift 2;;
  --vault=*) VAULT="${1#*=}"; shift;;
  *) echo "usage: derive-changed-paths.sh [--cwd=<root>] --vault <dir>" >&2; exit 2;;
esac; done
[ -n "$VAULT" ] || { echo "usage: derive-changed-paths.sh [--cwd=<root>] --vault <dir>" >&2; exit 2; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT" >&2; exit 2; }

V_CWD="$CWD" V_VAULT="$VAULT" python3 <<'PYEOF'
import json, os, re, subprocess, sys, time

cwd = os.path.abspath(os.environ["V_CWD"])
vault = os.environ["V_VAULT"]
idx_path = os.path.join(cwd, ".mega-sdd", "codebase", "symbol-index.json")

# 1. Freshness stamp from the index envelope.
stamp = None
try:
    with open(idx_path, encoding="utf-8", errors="replace") as f:
        m = re.search(r'"head_commit"\s*:\s*"([0-9a-f]{7,40})"', f.read(512))
    stamp = m.group(1) if m else None
except OSError:
    pass
if not stamp:
    print("FAIL: no symbol-index head_commit stamp — cannot derive a changed "
          "set; fall back to a full re-bind (bind-codebase <vault> --auto).",
          file=sys.stderr)
    sys.exit(3)

# 2. git diff stamp..HEAD (committed movement).
try:
    r = subprocess.run(
        ["git", "-C", cwd, "diff", "--name-only", "%s..HEAD" % stamp],
        capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        print("FAIL: git diff %s..HEAD failed: %s" % (stamp, r.stderr.strip()[:200]),
              file=sys.stderr)
        sys.exit(3)
    changed = {p.strip() for p in r.stdout.splitlines() if p.strip()}
except Exception as e:
    print("FAIL: git unavailable (%s)" % e, file=sys.stderr)
    sys.exit(3)

# 3. Union the dirty journal (uncommitted in-session edits), then rotate it —
# same consume semantics as scan --changed-only (rotate, never truncate).
journal = os.path.join(cwd, ".mega-sdd", "codebase", ".dirty-paths.jsonl")
rows = 0
if os.path.isfile(journal):
    try:
        with open(journal, encoding="utf-8", errors="replace") as f:
            for ln in f:
                ln = ln.strip()
                if not ln:
                    continue
                try:
                    d = json.loads(ln)
                    p = d.get("path")
                except Exception:
                    p = None
                if p:
                    rel = os.path.relpath(p, cwd) if os.path.isabs(p) else p
                    if not rel.startswith(".."):
                        changed.add(rel)
                        rows += 1
    except OSError:
        pass
    else:
        try:
            os.replace(journal, journal.replace(
                ".dirty-paths.jsonl",
                ".dirty-paths.consumed-%d" % int(time.time())))
        except OSError:
            pass

# 4. Drop mega-sdd state paths (never sync-relevant) + write atomically.
changed = sorted(p for p in changed
                 if not p.startswith(".mega-sdd/") and "/.mega-sdd/" not in p)
out = os.path.join(vault, ".sync-changed-paths.txt")
tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write("\n".join(changed) + ("\n" if changed else ""))
os.replace(tmp, out)
print("PASS: %d changed path(s) (%d from journal) -> %s" % (len(changed), rows, out))
sys.exit(0)
PYEOF
