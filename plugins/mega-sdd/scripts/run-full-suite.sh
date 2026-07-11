#!/usr/bin/env bash
# run-full-suite.sh — deterministic writer for <vault>/bolts/_batch-suite.json (B2).
#
# S6 EB-GATE-4: the batch-suite evidence artifact used to be agent-written on
# trust — the gate's own remediation text coached writing {status:green}, and a
# symbolic head_sha ("HEAD") voided the freshness anchor forever (EB-VAL-1).
# This wrapper is now the ONLY sanctioned write path (the artifact is
# Write/Edit-guarded by the PreToolUse hook): it RUNS the project's full test
# suite itself, then records the observed result with the pinned 40-hex HEAD.
#
# Usage:
#   run-full-suite.sh --cwd=<project-root> [--runner="<command>"] [--vault=<name>] [--quiet]
#
# Runner detection (manifest-based, first match wins; override with --runner):
#   composer.json            → vendor/bin/pest || vendor/bin/phpunit || php artisan test
#   package.json (scripts.test) → yarn/pnpm/npm test (by lockfile)
#   pyproject.toml/pytest.ini/setup.cfg → python3 -m pytest -q
#   go.mod                   → go test ./...
#   Cargo.toml               → cargo test
#   Gemfile (rspec)          → bundle exec rspec
#   mix.exs                  → mix test
#
# Exit: 0 = suite green (artifact written GREEN)
#       1 = suite red   (artifact written RED — B2 blocks until fixed + re-run)
#       2 = cannot run  (no runner detected / no vault / not a git repo) — nothing written
set -uo pipefail

CWD=""
RUNNER=""
VAULT=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --runner=*) RUNNER="${arg#*=}" ;;
    --vault=*) VAULT="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required" >&2; exit 2
fi
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo — B2 anchors on commit shas" >&2; exit 2; }

# ── Locate the target bolts/ dirs ────────────────────────────────────────────
# S7-SUITE-2/3: a candidate must be a SUBSTANTIVE vault (holds units/ or bolts/) —
# the same check the validator's _bound_vault_roots applies. `--vault=<any-dir>`
# used to write to a path shape the B2 reader (vault_layouts.batch_suite_files)
# never globs — exit 0 "recorded" while the gate stayed batch_suite_gate_missing —
# and a code dir merely NAMED *-bound (cpu-bound/) was adopted and littered with
# a bolts/ dir. S7-SUITE-4: with no --vault, write to EVERY discoverable vault —
# the artifact certifies a project-wide run, and refreshing only the first vault
# left stale RED artifacts elsewhere permanently blocking B2.
_substantive() { [ -d "$1/units" ] || [ -d "$1/bolts" ]; }
TARGET_DIRS=()
if [ -n "$VAULT" ]; then
  for cand in "${CWD}/.mega-sdd/vaults/${VAULT}" "${CWD}/docs/mega-sdd/vaults/${VAULT}" "${CWD}/${VAULT}"; do
    if [ -d "$cand" ] && _substantive "$cand"; then TARGET_DIRS+=("${cand}/bolts"); break; fi
  done
  if [ "${#TARGET_DIRS[@]}" -eq 0 ]; then
    echo "ERROR: --vault=${VAULT} does not name a substantive vault (no units/ or bolts/ inside) under ${CWD}" >&2
    exit 2
  fi
else
  # The pattern list mirrors the READER (vault_layouts.vault_prefixes) — S7-B r2-2:
  # the writer missing */*-bound left a nested vault's red artifact unrefreshable,
  # resurrecting the SUITE-4 permanent loop. Dependency dirs are never vaults.
  for v in "${CWD}/.mega-sdd/vaults"/*/ "${CWD}/docs/mega-sdd/vaults"/*/ "${CWD}"/*-bound/ "${CWD}"/*/*-bound/; do
    [ -d "$v" ] || continue
    case "$v" in */node_modules/*|*/vendor/*) continue ;; esac
    _substantive "${v%/}" || continue
    TARGET_DIRS+=("${v%/}/bolts")
  done
fi
if [ "${#TARGET_DIRS[@]}" -eq 0 ]; then
  echo "ERROR: no substantive vault found under ${CWD} — nothing to record the suite against (pass --vault=<name>)" >&2
  exit 2
fi

# ── Detect the runner (always — S7-SUITE-5 compares it against an override) ──
DETECTED=""
if [ -f "${CWD}/composer.json" ]; then
  if [ -x "${CWD}/vendor/bin/pest" ]; then DETECTED="vendor/bin/pest"
  elif [ -x "${CWD}/vendor/bin/phpunit" ]; then DETECTED="vendor/bin/phpunit"
  elif [ -f "${CWD}/artisan" ]; then DETECTED="php artisan test"
  fi
fi
if [ -z "$DETECTED" ] && [ -f "${CWD}/package.json" ]; then
  if HAS_TEST=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(1 if (d.get("scripts") or {}).get("test") else 0)' "${CWD}/package.json" 2>/dev/null) && [ "$HAS_TEST" = "1" ]; then
    if [ -f "${CWD}/yarn.lock" ]; then DETECTED="yarn test"
    elif [ -f "${CWD}/pnpm-lock.yaml" ]; then DETECTED="pnpm test"
    else DETECTED="npm test -s"
    fi
  fi
fi
if [ -z "$DETECTED" ]; then
  if [ -f "${CWD}/pytest.ini" ]; then
    DETECTED="python3 -m pytest -q"
  elif [ -f "${CWD}/setup.cfg" ] && grep -q "\[tool:pytest\]" "${CWD}/setup.cfg" 2>/dev/null; then
    DETECTED="python3 -m pytest -q"
  elif [ -f "${CWD}/pyproject.toml" ] && grep -qE "^\[tool\.pytest" "${CWD}/pyproject.toml" 2>/dev/null; then
    DETECTED="python3 -m pytest -q"
  fi
fi
if [ -z "$DETECTED" ] && [ -f "${CWD}/go.mod" ]; then DETECTED="go test ./..."; fi
if [ -z "$DETECTED" ] && [ -f "${CWD}/Cargo.toml" ]; then DETECTED="cargo test"; fi
if [ -z "$DETECTED" ] && [ -f "${CWD}/Gemfile" ] && grep -q "rspec" "${CWD}/Gemfile" 2>/dev/null; then DETECTED="bundle exec rspec"; fi
if [ -z "$DETECTED" ] && [ -f "${CWD}/mix.exs" ]; then DETECTED="mix test"; fi

# S7-SUITE-5: an explicit --runner that DIFFERS from the manifest-detected runner
# is recorded in the artifact (runner_overridden + detected_runner) and surfaced
# by the B2 gate state — the wrapper is the trust root, so "some command the
# agent picked exited 0" must never silently read as "the full suite ran".
RUNNER_OVERRIDDEN=0
if [ -n "$RUNNER" ] && [ -n "$DETECTED" ] && [ "$RUNNER" != "$DETECTED" ]; then
  RUNNER_OVERRIDDEN=1
  echo "WARN: --runner=\"${RUNNER}\" overrides the manifest-detected runner (\`${DETECTED}\`) — recording runner_overridden in the artifact" >&2
fi
[ -n "$RUNNER" ] || RUNNER="$DETECTED"
if [ -z "$RUNNER" ]; then
  echo "ERROR: no test runner detected for ${CWD} — pass --runner=\"<command>\" explicitly" >&2
  exit 2
fi

# ── Pin the commit BEFORE the run (S7-SUITE-1) ───────────────────────────────
# The artifact certifies a COMMIT, so what the suite tests must BE that commit:
# (a) HEAD is captured before the run and re-checked after — a commit landing
#     mid-run would be pinned as covered without ever being tested;
# (b) a working tree with uncommitted CODE changes is refused — the suite would
#     test the tree while the artifact green-stamps the (possibly broken) HEAD.
# .mega-sdd state, vault trees, and pure-docs edits do not affect test outcomes
# and are exempt from the dirty check.
HEAD_SHA=$(git -C "$CWD" rev-parse HEAD 2>/dev/null)
printf '%s' "$HEAD_SHA" | grep -qE '^[0-9a-f]{40}$' || {
  echo "ERROR: cannot resolve a 40-hex HEAD in ${CWD} (empty repo?) — B2 anchors on commit shas; nothing written" >&2; exit 2; }
# Review-hardened (S7-B r1-2/r1-3/r2-1/r2-3): porcelain paths are REPO-root-relative,
# so the exemptions strip the monorepo prefix first (the project's own .mega-sdd/
# state — written by hooks every turn — must never deadlock B2), the pathspec scopes
# out sibling projects, -uall expands collapsed untracked dirs, a rename is clean
# only when BOTH sides are exempt, and *-bound is exempt only for SUBSTANTIVE vault
# roots (a code dir merely NAMED cpu-bound/ is code — the S6 lesson). Untracked
# dependency dirs (node_modules/, vendor/) and tool junk (.DS_Store, caches) are
# exempt: they are never part of any commit, so refusing them is a permanent loop.
DIRTY=$(CWD="$CWD" python3 - <<'PY'
import glob, os, re, subprocess
cwd = os.environ["CWD"]
def git(*a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)
prefix = git("rev-parse", "--show-prefix").stdout.strip()
vault_roots = []
for pat in ("*-bound", os.path.join("*", "*-bound"), os.path.join("docs", "mega-sdd", "vaults", "*-bound")):
    for d in glob.glob(os.path.join(cwd, pat)):
        if os.path.isdir(d) and (os.path.isdir(os.path.join(d, "units"))
                                 or os.path.isdir(os.path.join(d, "bolts"))):
            vault_roots.append(os.path.relpath(d, cwd).replace(os.sep, "/").rstrip("/") + "/")
_DOC_EXT = (".md", ".markdown", ".rst", ".adoc")
_JUNK = re.compile(r"(^|/)(\.DS_Store$|__pycache__/|\.pytest_cache/|\.phpunit\.result\.cache$|node_modules/|vendor/)|\.pyc$")
def exempt(p):
    p = p.strip().strip('"')
    if prefix:
        if not p.startswith(prefix):
            return True   # outside this project subtree (belt — the pathspec already scopes)
        p = p[len(prefix):]
    if p.startswith(".mega-sdd/") or p.startswith("docs/mega-sdd/"):
        return True
    if any(p == r.rstrip("/") or p.startswith(r) for r in vault_roots):
        return True
    if os.path.splitext(p)[1].lower() in _DOC_EXT:
        return True
    return bool(_JUNK.search(p))
dirty = []
for ln in git("status", "--porcelain", "-uall", "--", ".").stdout.splitlines():
    if len(ln) < 4:
        continue
    pp = ln[3:]
    sides = pp.split(" -> ") if " -> " in pp else [pp]
    if not all(exempt(x) for x in sides):
        dirty.append(pp)
print("\n".join(dirty[:5]))
PY
)
if [ -n "$DIRTY" ]; then
  echo "ERROR: working tree has uncommitted code changes — the suite would test the TREE while the artifact certifies HEAD ${HEAD_SHA}; nothing written. Commit or stash the code changes; for untracked non-code litter (.env, caches, build output) add it to .gitignore instead — NEVER commit secrets to clear this gate. Dirty:" >&2
  echo "$DIRTY" | head -5 >&2
  exit 2
fi

# ── Run the FULL suite (no per-unit scope filter — that is the point of B2) ──
[ "$QUIET" = "1" ] || echo "run-full-suite: running \`${RUNNER}\` in ${CWD} …" >&2
LOG_FILE="${TMPDIR:-/tmp}/run-full-suite-$$.log"
( cd "$CWD" && eval "$RUNNER" ) >"$LOG_FILE" 2>&1
SUITE_EXIT=$?
TAIL_OUT=$(tail -20 "$LOG_FILE" 2>/dev/null || true)
STATUS="green"; [ "$SUITE_EXIT" -eq 0 ] || STATUS="red"

HEAD_AFTER=$(git -C "$CWD" rev-parse HEAD 2>/dev/null)
if [ "$HEAD_AFTER" != "$HEAD_SHA" ]; then
  echo "ERROR: HEAD moved during the suite run (${HEAD_SHA} → ${HEAD_AFTER}) — the result certifies neither commit; nothing written. Re-run at the new HEAD." >&2
  rm -f "$LOG_FILE" 2>/dev/null || true
  exit 2
fi

# ── Record the artifact in every target vault (write failure = exit 2, never
# a false "recorded" success — S7-SUITE-6) ────────────────────────────────────
for TARGET_DIR in "${TARGET_DIRS[@]}"; do
  mkdir -p "$TARGET_DIR" 2>/dev/null || { echo "ERROR: cannot create ${TARGET_DIR}" >&2; exit 2; }
  TARGET_DIR="$TARGET_DIR" STATUS="$STATUS" HEAD_SHA="$HEAD_SHA" RUNNER="$RUNNER" \
  DETECTED="$DETECTED" RUNNER_OVERRIDDEN="$RUNNER_OVERRIDDEN" QUIET="$QUIET" \
  SUITE_EXIT="$SUITE_EXIT" TAIL_OUT="$TAIL_OUT" python3 - <<'PYEOF' || { echo "ERROR: artifact write failed for ${TARGET_DIR} — result NOT recorded" >&2; exit 2; }
import json, os
from datetime import datetime, timezone
target = os.path.join(os.environ["TARGET_DIR"], "_batch-suite.json")
state = {
    "status": os.environ["STATUS"],
    "head_sha": os.environ["HEAD_SHA"],
    "ran_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "runner": os.environ["RUNNER"],
    "exit_code": int(os.environ["SUITE_EXIT"]),
    "output_tail": os.environ.get("TAIL_OUT", "")[-2000:],
    "written_by": "run-full-suite.sh",
}
if os.environ.get("RUNNER_OVERRIDDEN") == "1":
    state["runner_overridden"] = True
    state["detected_runner"] = os.environ.get("DETECTED", "")
tmp = target + ".tmp.%d" % os.getpid()
with open(tmp, "w") as f:
    json.dump(state, f, indent=1)
os.replace(tmp, target)
if os.environ.get("QUIET") != "1":
    print(target)
PYEOF
done

if [ "$QUIET" = "1" ]; then :; else
  echo "run-full-suite: suite ${STATUS} (exit ${SUITE_EXIT}) — recorded at HEAD ${HEAD_SHA} in ${#TARGET_DIRS[@]} vault(s)" >&2
  [ "$STATUS" = "green" ] || { echo "--- last 20 lines ---" >&2; echo "$TAIL_OUT" >&2; }
fi
rm -f "$LOG_FILE" 2>/dev/null || true
[ "$STATUS" = "green" ] && exit 0 || exit 1
