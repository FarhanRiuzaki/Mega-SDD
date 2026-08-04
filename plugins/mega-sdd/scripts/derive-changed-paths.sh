#!/usr/bin/env bash
# derive-changed-paths.sh — the express-born Mode D changed-set producer.
# Map-bearing projects keep `scan-codebase --changed-only` (which refreshes
# the map AND writes this file); projects that never grew a map (express
# spine) derive the durable changed set deterministically instead:
#   changed = git diff --name-only <symbol-index head_commit>..HEAD
#           ∪ git status --porcelain (working tree — uncommitted/untracked;
#             half of sync's purpose, round P2 blocker 1a)
#           ∪ dirty-journal rows + leftover .consumed-* files (crashed prior
#             runs re-unioned — round P2 blocker 1b)
#           ∪ the existing .sync-changed-paths.txt (re-entry while the stamp
#             is unadvanced must never NARROW the durable set — blocker 1c)
# Baseline honesty (round F1): the stamp is read from state.json's probe-time
# snapshot FIRST — ground.sh rebuilds the live index AFTER derive-state, so
# the live file's head_commit may already equal HEAD by the time this hop
# runs; the probe-time stamp is the true baseline. Live index is fallback.
# git runs with -c core.quotepath=false (round F5 — the repo's own lesson:
# unicode paths must never enter the set C-quoted).
# The journal is rotated to .consumed-<ts> ONLY AFTER the output write
# succeeds (round F6 — a failed write must not consume the hints); consumed
# files are deleted after their rows land in a successful write.
# Output: <vault>/.sync-changed-paths.txt (one path per line, repo-relative,
# sorted, deduped) — the SAME consumer contract detect-drift --scope=@ and
# bind-codebase --paths=@ already read.
# Exit 0 = written; 2 = usage; 3 = no baseline stamp / git unavailable /
# write failed — the caller falls back to a full re-bind, never guesses.
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
import glob, json, os, re, subprocess, sys, time

cwd = os.path.abspath(os.environ["V_CWD"])
vault = os.environ["V_VAULT"]

# 1. Baseline stamp: state.json probe-time snapshot first (pre-GROUND-rebuild
# truth), live index envelope as fallback.
stamp = None
try:
    st = json.load(open(os.path.join(cwd, ".mega-sdd", "state.json"),
                        encoding="utf-8"))
    stamp = ((st.get("probes") or {}).get("symbol_index") or {}).get("head_commit")
except Exception:
    pass
if not stamp:
    try:
        idx = os.path.join(cwd, ".mega-sdd", "codebase", "symbol-index.json")
        with open(idx, encoding="utf-8", errors="replace") as f:
            m = re.search(r'"head_commit"\s*:\s*"([0-9a-f]{7,40})"', f.read(512))
        stamp = m.group(1) if m else None
    except OSError:
        pass
if not stamp:
    print("FAIL: no symbol-index head_commit baseline (state.json or live "
          "index) — cannot derive a changed set; fall back to a full re-bind "
          "(bind-codebase <vault> --auto).", file=sys.stderr)
    sys.exit(3)

def _git(*args):
    return subprocess.run(
        ["git", "-C", cwd, "-c", "core.quotepath=false"] + list(args),
        capture_output=True, text=True, timeout=30)

# 2a. Committed movement: stamp..HEAD.
try:
    r = _git("diff", "--name-only", "%s..HEAD" % stamp)
    if r.returncode != 0:
        print("FAIL: git diff %s..HEAD failed: %s" % (stamp, r.stderr.strip()[:200]),
              file=sys.stderr)
        sys.exit(3)
    changed = {p.strip() for p in r.stdout.splitlines() if p.strip()}
except Exception as e:
    print("FAIL: git unavailable (%s)" % e, file=sys.stderr)
    sys.exit(3)

# 2b. Working tree (uncommitted + untracked) — porcelain, rename-aware.
try:
    r = _git("status", "--porcelain")
    if r.returncode == 0:
        for ln in r.stdout.splitlines():
            if len(ln) > 3:
                p = ln[3:]
                if " -> " in p:
                    p = p.split(" -> ", 1)[1]
                p = p.strip().strip('"')
                if p:
                    changed.add(p)
except Exception:
    pass  # porcelain is additive; the diff leg already succeeded

# 3. Union the dirty journal + leftover consumed files (crashed prior runs).
# Rotation/deletion is DEFERRED to after the successful write.
jdir = os.path.join(cwd, ".mega-sdd", "codebase")
journal = os.path.join(jdir, ".dirty-paths.jsonl")
sources = ([journal] if os.path.isfile(journal) else []) + \
    sorted(glob.glob(os.path.join(jdir, ".dirty-paths.consumed-*")))
rows = 0
for src in sources:
    try:
        with open(src, encoding="utf-8", errors="replace") as f:
            for ln in f:
                ln = ln.strip()
                if not ln:
                    continue
                try:
                    p = json.loads(ln).get("path")
                except Exception:
                    p = None
                if p:
                    p = str(p).replace("\\", "/")
                    # 6.0.1 F1: a Windows drive path is absolute even when this
                    # runs on POSIX (os.path.isabs says no there) — a pre-fix
                    # poisoned row must never become a phantom changed path
                    if re.match(r"^[A-Za-z]:/", p):
                        continue
                    rel = os.path.relpath(p, cwd) if os.path.isabs(p) else p
                    if rel != ".." and not rel.startswith("../"):
                        changed.add(rel)
                        rows += 1
    except OSError:
        continue

# 4. Re-entry safety: union the EXISTING durable set (never narrow it while
# the stamp is unadvanced), drop mega-sdd state paths, write atomically.
out = os.path.join(vault, ".sync-changed-paths.txt")
try:
    with open(out, encoding="utf-8", errors="replace") as f:
        changed |= {ln.strip() for ln in f if ln.strip()}
except OSError:
    pass
changed = sorted(p for p in changed
                 if not p.startswith(".mega-sdd/") and "/.mega-sdd/" not in p)
tmp = out + ".tmp"
try:
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(changed) + ("\n" if changed else ""))
    os.replace(tmp, out)
except OSError as e:
    print("FAIL: cannot write %s (%s) — journal NOT consumed; fall back to a "
          "full re-bind." % (out, e), file=sys.stderr)
    sys.exit(3)

# 5. NOW consume: rotate the live journal; delete consumed files whose rows
# are safely inside the just-written set (scan --changed-only parity).
for src in sources:
    try:
        if src == journal:
            os.replace(src, os.path.join(
                jdir, ".dirty-paths.consumed-%d" % int(time.time())))
        else:
            os.remove(src)
    except OSError:
        pass

print("PASS: %d changed path(s) (%d from journal/consumed) -> %s"
      % (len(changed), rows, out))
sys.exit(0)
PYEOF
