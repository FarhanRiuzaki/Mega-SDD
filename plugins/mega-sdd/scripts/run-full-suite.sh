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

# ── Locate the target bolts/ dir ─────────────────────────────────────────────
TARGET_DIR=""
if [ -n "$VAULT" ]; then
  for cand in "${CWD}/.mega-sdd/vaults/${VAULT}/bolts" "${CWD}/docs/mega-sdd/vaults/${VAULT}/bolts" "${CWD}/${VAULT}/bolts"; do
    if [ -d "$(dirname "$cand")" ]; then TARGET_DIR="$cand"; break; fi
  done
else
  # first existing vault (canonical layout first, then legacy)
  for v in "${CWD}/.mega-sdd/vaults"/*/ "${CWD}/docs/mega-sdd/vaults"/*/ "${CWD}"/*-bound/; do
    [ -d "$v" ] || continue
    TARGET_DIR="${v%/}/bolts"
    break
  done
fi
if [ -z "$TARGET_DIR" ]; then
  echo "ERROR: no vault found under ${CWD} — nothing to record the suite against (pass --vault=<name>)" >&2
  exit 2
fi

# ── Detect the runner ────────────────────────────────────────────────────────
if [ -z "$RUNNER" ]; then
  if [ -f "${CWD}/composer.json" ]; then
    if [ -x "${CWD}/vendor/bin/pest" ]; then RUNNER="vendor/bin/pest"
    elif [ -x "${CWD}/vendor/bin/phpunit" ]; then RUNNER="vendor/bin/phpunit"
    elif [ -f "${CWD}/artisan" ]; then RUNNER="php artisan test"
    fi
  fi
  if [ -z "$RUNNER" ] && [ -f "${CWD}/package.json" ]; then
    if HAS_TEST=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(1 if (d.get("scripts") or {}).get("test") else 0)' "${CWD}/package.json" 2>/dev/null) && [ "$HAS_TEST" = "1" ]; then
      if [ -f "${CWD}/yarn.lock" ]; then RUNNER="yarn test"
      elif [ -f "${CWD}/pnpm-lock.yaml" ]; then RUNNER="pnpm test"
      else RUNNER="npm test -s"
      fi
    fi
  fi
  if [ -z "$RUNNER" ]; then
    if [ -f "${CWD}/pytest.ini" ]; then
      RUNNER="python3 -m pytest -q"
    elif [ -f "${CWD}/setup.cfg" ] && grep -q "\[tool:pytest\]" "${CWD}/setup.cfg" 2>/dev/null; then
      RUNNER="python3 -m pytest -q"
    elif [ -f "${CWD}/pyproject.toml" ] && grep -qE "^\[tool\.pytest" "${CWD}/pyproject.toml" 2>/dev/null; then
      RUNNER="python3 -m pytest -q"
    fi
  fi
  if [ -z "$RUNNER" ] && [ -f "${CWD}/go.mod" ]; then RUNNER="go test ./..."; fi
  if [ -z "$RUNNER" ] && [ -f "${CWD}/Cargo.toml" ]; then RUNNER="cargo test"; fi
  if [ -z "$RUNNER" ] && [ -f "${CWD}/Gemfile" ] && grep -q "rspec" "${CWD}/Gemfile" 2>/dev/null; then RUNNER="bundle exec rspec"; fi
  if [ -z "$RUNNER" ] && [ -f "${CWD}/mix.exs" ]; then RUNNER="mix test"; fi
fi
if [ -z "$RUNNER" ]; then
  echo "ERROR: no test runner detected for ${CWD} — pass --runner=\"<command>\" explicitly" >&2
  exit 2
fi

# ── Run the FULL suite (no per-unit scope filter — that is the point of B2) ──
[ "$QUIET" = "1" ] || echo "run-full-suite: running \`${RUNNER}\` in ${CWD} …" >&2
LOG_FILE="${TMPDIR:-/tmp}/run-full-suite-$$.log"
( cd "$CWD" && eval "$RUNNER" ) >"$LOG_FILE" 2>&1
SUITE_EXIT=$?
TAIL_OUT=$(tail -20 "$LOG_FILE" 2>/dev/null || true)

STATUS="green"; [ "$SUITE_EXIT" -eq 0 ] || STATUS="red"
HEAD_SHA=$(git -C "$CWD" rev-parse HEAD)

mkdir -p "$TARGET_DIR" 2>/dev/null || { echo "ERROR: cannot create ${TARGET_DIR}" >&2; exit 2; }
TARGET_DIR="$TARGET_DIR" STATUS="$STATUS" HEAD_SHA="$HEAD_SHA" RUNNER="$RUNNER" SUITE_EXIT="$SUITE_EXIT" TAIL_OUT="$TAIL_OUT" python3 - <<'PYEOF'
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
tmp = target + ".tmp.%d" % os.getpid()
with open(tmp, "w") as f:
    json.dump(state, f, indent=1)
os.replace(tmp, target)
print(target)
PYEOF

if [ "$QUIET" = "1" ]; then :; else
  echo "run-full-suite: suite ${STATUS} (exit ${SUITE_EXIT}) — recorded at HEAD ${HEAD_SHA}" >&2
  [ "$STATUS" = "green" ] || { echo "--- last 20 lines ---" >&2; echo "$TAIL_OUT" >&2; }
fi
rm -f "$LOG_FILE" 2>/dev/null || true
[ "$STATUS" = "green" ] && exit 0 || exit 1
