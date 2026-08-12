#!/usr/bin/env bash
# uat-run.sh — the SOLE sanctioned writer of <vault>/uat/evidence/**/result.json
# (spec 2026-08-12-playwright-embed-design.md §D2; run-acceptance-tests.sh
# precedent: bounded, </dev/null, atomic, written_by-stamped; the anti-self-
# bypass hook guards the artifact — this script's invocation never NAMES it).
#
# Runs the generated Playwright specs under <vault>/uat/e2e/ against an
# OPERATOR-owned dev server and captures the auditor evidence pack:
#   <vault>/uat/evidence/<UAT-id>/<run-ts>/{result.json, screenshots/, trace.zip}
# Run dirs are UTC-timestamped and NEVER overwritten (audit trail).
#
# Prereq ladder — EVERY missing rung is a graceful SKIP (exit 0, JSON reason):
# no specs → no node/npx → no URL (--url= else .mega-sdd/config.yaml
# preview_url:) → URL unreachable → browser cache absent. The run itself is
# wall-clock bounded (default 120s, --timeout=<sec>); a hang is impossible —
# timeout is reported as a SKIP reason, never a partial-green artifact.
# Flags: --vault=<dir> --cwd=<root> [--url=<preview>] [--timeout=<sec>] [--spec=<UAT-id>]
# Exit: 0 ran-or-skipped · 2 usage.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/_lib/resolve-python.sh" 2>/dev/null || PYBIN=python3
PY="${PYBIN:-python3}"

VAULT=""; CWD=""; URL=""; TIMEOUT=120; SPEC_FILTER=""
for arg in "$@"; do
  case "$arg" in
    --vault=*)   VAULT="${arg#--vault=}" ;;
    --cwd=*)     CWD="${arg#--cwd=}" ;;
    --url=*)     URL="${arg#--url=}" ;;
    --timeout=*) TIMEOUT="${arg#--timeout=}" ;;
    --spec=*)    SPEC_FILTER="${arg#--spec=}" ;;
    *) echo "usage: uat-run.sh --vault=<dir> --cwd=<root> [--url=] [--timeout=<sec>] [--spec=<UAT-id>]" >&2; exit 2 ;;
  esac
done
[ -n "$VAULT" ] && [ -d "$VAULT/uat" ] || { echo "usage: --vault=<dir> with an uat/ tree required" >&2; exit 2; }
case "$TIMEOUT" in ''|*[!0-9]*) echo "usage: --timeout must be an integer (seconds)" >&2; exit 2 ;; esac
[ -n "$CWD" ] || CWD="$(pwd)"

skip() { printf '{"skipped":true,"reason":"%s"}\n' "$1"; exit 0; }

E2E="$VAULT/uat/e2e"
ls "$E2E"/*.spec.ts >/dev/null 2>&1 || skip "no e2e specs — run build-uat-e2e.sh (via /mega-sdd:emit uat) first"

command -v node >/dev/null 2>&1 || skip "node not found — the run needs Node >=18"
command -v npx  >/dev/null 2>&1 || skip "npx not found"

# URL: flag > .mega-sdd/config.yaml preview_url:
if [ -z "$URL" ] && [ -f "$CWD/.mega-sdd/config.yaml" ]; then
  URL=$(grep -E '^preview_url:' "$CWD/.mega-sdd/config.yaml" | head -1 | sed 's/^preview_url:[[:space:]]*//')
fi
[ -n "$URL" ] || skip "no preview URL — pass --url= or set preview_url: in .mega-sdd/config.yaml (the dev server is operator-owned; this script never starts one)"

probe() {
  if command -v curl >/dev/null 2>&1; then curl -fsS -o /dev/null --max-time 5 "$1" 2>/dev/null; return $?; fi
  if command -v wget >/dev/null 2>&1; then wget -q -O /dev/null --timeout=5 "$1" 2>/dev/null; return $?; fi
  return 2
}
probe "$URL" || skip "dev server not reachable at $URL — start it, then re-run"

# browser cache (detect-only — install-deps offers the download, never here)
BROWSER_OK=0
for c in "$HOME/Library/Caches/ms-playwright" "$HOME/.cache/ms-playwright" "${LOCALAPPDATA:-$HOME/AppData/Local}/ms-playwright"; do
  [ -d "$c" ] && [ -n "$(ls -A "$c" 2>/dev/null)" ] && BROWSER_OK=1 && break
done
[ "$BROWSER_OK" -eq 1 ] || skip "playwright browser cache absent — run: npx playwright install chromium (~130MB; offered by /mega-sdd:install-deps)"

# self-contained deps: e2e/ has its own package.json (written by build-uat-e2e.sh);
# a dep-less target repo cannot resolve @playwright/test from the npx cache
# (live-proven), so first run provisions node_modules HERE — bounded, skip on fail.
if [ -f "$E2E/package.json" ] && [ ! -d "$E2E/node_modules" ]; then
  if ! ( cd "$E2E" && npm install --no-audit --no-fund --loglevel=error </dev/null >/dev/null 2>&1 ) ; then
    skip "npm install failed in uat/e2e (registry blocked / offline?) — provision @playwright/test manually, then re-run"
  fi
fi

export _UAT_RUN_VAULT="$VAULT" _UAT_RUN_URL="$URL" _UAT_RUN_TIMEOUT="$TIMEOUT" _UAT_RUN_SPEC="$SPEC_FILTER"

exec "$PY" - <<'PYEOF'
import datetime, hashlib, json, os, re, shutil, subprocess, sys, tempfile

vault = os.environ["_UAT_RUN_VAULT"]
url = os.environ["_UAT_RUN_URL"]
timeout_s = int(os.environ["_UAT_RUN_TIMEOUT"])
spec_filter = os.environ["_UAT_RUN_SPEC"]

e2e = os.path.join(vault, "uat", "e2e")
uat_md = os.path.join(vault, "uat", "UAT.md")

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def header_sha(spec_path, key):
    rx = re.compile(r"^//\s*" + key + r":\s*([0-9a-f]{64})")
    for line in open(spec_path, encoding="utf-8"):
        m = rx.match(line)
        if m:
            return m.group(1)
    return None

run_ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
uat_sha_now = sha256_file(uat_md) if os.path.isfile(uat_md) else None

specs = sorted(f for f in os.listdir(e2e) if f.endswith(".spec.ts"))
if spec_filter:
    specs = [f for f in specs if f.startswith(spec_filter)]
if not specs:
    print(json.dumps({"skipped": True, "reason": "no spec matches --spec=" + spec_filter}))
    sys.exit(0)

env = dict(os.environ, PREVIEW_URL=url, CI="1")
t0 = datetime.datetime.now()
try:
    proc = subprocess.run(
        ["npx", "--yes", "playwright", "test", "--reporter=json"],
        cwd=e2e, env=env, stdin=subprocess.DEVNULL,
        capture_output=True, text=True, timeout=timeout_s,
    )
    pw_exit = proc.returncode
    report_raw = proc.stdout
except subprocess.TimeoutExpired:
    print(json.dumps({"skipped": True, "reason": "TIMEOUT after %ds — raise --timeout= or check the server" % timeout_s}))
    sys.exit(0)
except OSError as e:
    print(json.dumps({"skipped": True, "reason": "npx spawn failed: %s (registry blocked / offline?)" % e}))
    sys.exit(0)
duration = (datetime.datetime.now() - t0).total_seconds()

# Provisioning failure ≠ test result: a browser-build mismatch (installed
# @playwright/test needs a build the cache lacks) must SKIP, never mint
# fail-count evidence (live-proven failure class, 2026-08-12).
if pw_exit != 0 and "Executable doesn't exist" in (report_raw + proc.stderr):
    print(json.dumps({"skipped": True, "reason": "browser build mismatch — run: cd %s && npx playwright install chromium, then re-run" % os.path.relpath(e2e)}))
    sys.exit(0)

# parse the JSON reporter; per-scenario counts keyed by spec file name
per = {}
try:
    rep = json.loads(report_raw)
    def walk(suites):
        for s in suites or []:
            fname = os.path.basename(s.get("file") or s.get("title") or "")
            for sub in s.get("suites") or []:
                sub.setdefault("file", s.get("file"))
            walk(s.get("suites"))
            for spec in s.get("specs") or []:
                sid = os.path.basename(spec.get("file") or fname or "").replace(".spec.ts", "")
                d = per.setdefault(sid, {"pass": 0, "fail": 0, "skip": 0})
                for t in spec.get("tests") or []:
                    status = t.get("status") or ""
                    if status in ("expected", "passed"):
                        d["pass"] += 1
                    elif status in ("skipped", "fixme"):
                        d["skip"] += 1
                    else:
                        d["fail"] += 1
    walk(rep.get("suites"))
except ValueError:
    pass  # empty per → recorded below with playwright_exit as the only signal

wrote = []
for spec_name in specs:
    sid = spec_name.replace(".spec.ts", "")
    counts = per.get(sid, {"pass": 0, "fail": 0, "skip": 0})
    ev_dir = os.path.join(vault, "uat", "evidence", sid, run_ts)
    n = 1
    while os.path.isdir(ev_dir):  # never overwrite a prior run dir
        n += 1
        ev_dir = os.path.join(vault, "uat", "evidence", sid, run_ts + "-%d" % n)
    os.makedirs(ev_dir)
    spec_path = os.path.join(e2e, spec_name)
    result = {
        "written_by": "uat-run.sh",
        "run_ts": os.path.basename(ev_dir),
        "status": counts,
        "spec_sha256": sha256_file(spec_path),
        "uat_md_sha256": uat_sha_now or header_sha(spec_path, "uat_md_sha256"),
        "scaffold_sha256": header_sha(spec_path, "scaffold_sha256"),
        "preview_url": url,
        "duration_s": round(duration, 1),
        "playwright_exit": pw_exit,
    }
    fd, tmp = tempfile.mkstemp(dir=ev_dir, prefix=".tmp-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, sort_keys=True)
    os.replace(tmp, os.path.join(ev_dir, "result.json"))
    # copy artifacts playwright produced (best-effort)
    tr = os.path.join(e2e, "test-results")
    if os.path.isdir(tr):
        shots = os.path.join(ev_dir, "screenshots")
        for root, _dirs, files in os.walk(tr):
            for fn in files:
                if fn.endswith(".png"):
                    os.makedirs(shots, exist_ok=True)
                    shutil.copy2(os.path.join(root, fn), os.path.join(shots, fn))
                elif fn == "trace.zip" and not os.path.isfile(os.path.join(ev_dir, "trace.zip")):
                    shutil.copy2(os.path.join(root, fn), os.path.join(ev_dir, "trace.zip"))
    wrote.append(os.path.basename(ev_dir))
    print("EVIDENCE {} → {} (pass {} / fail {} / skip {})".format(
        sid, os.path.relpath(ev_dir, vault), counts["pass"], counts["fail"], counts["skip"]))

print(json.dumps({"skipped": False, "runs": len(wrote), "playwright_exit": pw_exit, "duration_s": round(duration, 1)}))
sys.exit(0)
PYEOF
