#!/usr/bin/env bash
# validate-preflight.sh — pipeline-intelligence, Iter-79 O-1 (orchestrator, F2 closure).
#
# Per docs/superpowers/audits/2026-06-02-intelligence-e2e/01-orchestrator-baseline.md §O-1
# and the predictive-checks.md catalog (which was prose-only — the model could skip it).
#
# Predictive PRE-flight: detect a KNOWN, knowable-in-advance input precondition for the
# skill about to run, BEFORE it burns minutes and halts mid-way. Fork-A enforcement of the
# F2 "predictive halt" theme: a deterministic runner the PreToolUse hook invokes, instead
# of SKILL.md Step 3.5 prose. Conservative — only GENUINELY-FATAL preconditions block
# (a skill that cannot do anything useful without the missing input); softer signals are
# advisory warnings. This avoids the false-stop risk the audit flagged for over-eager gates.
#
# Checks (highest-signal subset of the catalog):
#   bind-codebase   : needs a vault AND a codebase-map.md         → FATAL if absent
#   generate-units  : needs a (bound) vault                        → FATAL if absent
#   execute-bolts   : needs units/U-*.md                           → FATAL if absent
#   scan-codebase   : tree-sitter present (else regex fallback)    → WARN
#
# Usage: validate-preflight.sh --cwd=<root> --skill=<mega-sdd:NAME> [--quiet]
# Output: stdout JSON (suppressed by --quiet); OVERWRITE <cwd>/.mega-sdd/.preflight-state.json
# Exit: 0 = PASS / WARN / not-applicable; 1 = FATAL precondition unmet; 2 = error

set -uo pipefail

# ─── v7 Fase 2 merge group 10: the chain-level PREDICTIVE preflight lives here
# as the --predictive mode (merged verbatim from predictive-preflight.sh).
#   validate-preflight.sh --predictive --cwd=<root> --chain=<skill,skill,…>
# Catalog source of truth: skills/orchestrate-flow/references/predictive-checks.md.
# JSON line per check + a PREFLIGHT summary; exit 0 clean/warn-only · 3 fatal.
# No flag = the dispatch-time preflight below, byte-for-byte as before.
_VP_PRED=0
_VP_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --predictive) _VP_PRED=1 ;;
    *) _VP_ARGS+=("$arg") ;;
  esac
done
if [ "${#_VP_ARGS[@]}" -gt 0 ]; then set -- "${_VP_ARGS[@]}"; else set --; fi

if [ "$_VP_PRED" -eq 1 ]; then
# ═══ mode: predictive (merged predictive-preflight.sh) ═══

CWD=""
CHAIN=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --chain=*) CHAIN="${arg#*=}" ;;
  esac
done
if [ -z "$CWD" ]; then CWD="$(pwd)"; fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"
MEGA_SDD_PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd)"
export MEGA_SDD_PLUGIN_ROOT

CWD="$CWD" CHAIN="$CHAIN" python3 <<'PYEOF'
import glob, json, os, re, shutil, subprocess, sys, time

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
try:
    import state_probes  # shared probe library — never duplicated
except Exception:
    state_probes = None

cwd = os.path.abspath(os.environ.get("CWD") or os.getcwd())
chain = [s.strip() for s in os.environ.get("CHAIN", "").split(",") if s.strip()]
plugin_root = os.environ.get("MEGA_SDD_PLUGIN_ROOT", "")

counts = {"ok": 0, "warn": 0, "fatal": 0}


def emit(skill, check, status, hint):
    counts[status] += 1
    print(json.dumps({"skill": skill, "check": check,
                      "status": status, "hint": hint}))


def resolve_vault():
    """Canonical vault dir (paths.md nested layout, mirrored from
    state_probes._canonical_vault_root), legacy fallback, else a nominal
    path so file probes fail exactly like the missing vault they predict."""
    roots = [os.path.join(cwd, ".mega-sdd", "vaults"),
             os.path.join(cwd, "docs", "mega-sdd", "vaults")]
    for root in roots:
        hits = sorted(glob.glob(os.path.join(root, "*", "vault.json")))
        if hits:
            return os.path.dirname(hits[0])
    return os.path.join(cwd, ".mega-sdd", "vaults", "main")


VAULT = resolve_vault()


def which_any(*names):
    return any(shutil.which(n) for n in names)


def load_vault_json():
    with open(os.path.join(VAULT, "vault.json"), encoding="utf-8") as f:
        return json.load(f)


def writable_target(path):
    """Read-only writability probe: deepest EXISTING ancestor must be a
    writable directory (replaces the catalog's mkdir/rmdir probe — this
    script never writes)."""
    p = os.path.abspath(path)
    while not os.path.exists(p):
        parent = os.path.dirname(p)
        if parent == p:
            break
        p = parent
    return os.path.isdir(p) and os.access(p, os.W_OK)


def spine():
    """derived.spine from state.json; absent/unreadable → 'express', the
    same default state_probes.py applies (probes.get('spine', 'express'))."""
    try:
        with open(os.path.join(cwd, ".mega-sdd", "state.json"),
                  encoding="utf-8") as f:
            d = json.load(f)
        return (d.get("derived", {}).get("spine")
                or d.get("probes", {}).get("spine") or "express")
    except Exception:
        return "express"


# ── unit frontmatter helpers (cold-halt checks) ──────────────────────────────

def unit_files():
    return sorted(glob.glob(os.path.join(VAULT, "units", "U-*.md")))


def parse_frontmatter(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        return {}
    if not lines or lines[0].strip() != "---":
        return {}
    fm, key = {}, None
    for ln in lines[1:]:
        if ln.strip() == "---":
            break
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$", ln)
        if m:
            key = m.group(1)
            fm[key] = m.group(2).strip()
        elif key is not None and re.match(r"^\s*-\s+", ln):
            if not isinstance(fm.get(key), list):
                fm[key] = [] if fm.get(key, "") == "" else [fm[key]]
            fm[key].append(re.sub(r"^\s*-\s+", "", ln).strip())
    return fm


def as_list(val):
    if isinstance(val, list):
        return [v for v in val if v]
    if not isinstance(val, str) or val == "":
        return []
    v = val.strip()
    if v.startswith("[") and v.endswith("]"):
        inner = v[1:-1].strip()
        return [x.strip().strip("'\"") for x in inner.split(",") if x.strip()]
    return [v.strip("'\"")]


# ── check functions: return True (pass) / False (mismatch); raise = probe err ─

def c_ast_engine(_):
    return which_any("tree-sitter", "tree-sitter-cli", "ast-grep")


def c_framework_pack(_):
    # <detected-framework> is a runtime value; the statically checkable
    # invariant is the guaranteed _universal.md fallback the on_fail names.
    return os.path.isfile(os.path.join(
        plugin_root, "references", "framework-conventions", "_universal.md"))


def c_binding_input(_):
    vault_ok = os.path.isfile(os.path.join(VAULT, "vault.json"))
    if spine() != "classic":
        return vault_ok  # express carve-out: vault.json arm only
    if state_probes is not None:
        return vault_ok and state_probes.has_codebase_map(cwd)
    return vault_ok and (
        os.path.isfile(os.path.join(cwd, ".mega-sdd", "codebase",
                                    "codebase-map.md"))
        or os.path.isfile(os.path.join(cwd, "codebase-map.md")))


def c_units_dir(_):
    return bool(unit_files())


def c_superpowers(_):
    return os.path.isdir(os.path.join(plugin_root, "skills", "_vendored"))


def c_vault_json(_):
    return os.path.isfile(os.path.join(VAULT, "vault.json"))


def c_binding_confirmed(_):
    p = os.path.join(VAULT, "binding.md")
    if not os.path.isfile(p):
        return False
    with open(p, encoding="utf-8", errors="replace") as f:
        return bool(re.search(r"^## Confirmed Claims", f.read(), re.M))


def c_clean_tree(_):
    r = subprocess.run(["git", "-C", cwd, "status", "--porcelain"],
                       capture_output=True, text=True, timeout=10)
    if r.returncode != 0:
        raise RuntimeError("git status failed: %s" % r.stderr.strip()[:120])
    return not r.stdout.strip()


def c_vault_version(_):
    try:
        v = load_vault_json()
    except Exception:
        return False  # malformed / absent IS the mismatch the check predicts
    return bool(v.get("vault_version"))


def c_oq_inputs(_):
    return (os.path.isfile(os.path.join(VAULT, "vault.json"))
            and os.path.isfile(os.path.join(VAULT, "03-open-questions.md")))


def c_oq_status_field(_):
    v = load_vault_json()
    return any("status" in oq for oq in v.get("open_questions", []))


def c_oq_unresolved(_):
    v = load_vault_json()
    return any(oq.get("status") != "resolved"
               for oq in v.get("open_questions", []))


def c_legacy_path(_):
    # <legacy-path> defaults to the chain's --cwd (the codebase under
    # extraction) when no positional is visible to this script.
    return os.path.isdir(cwd) and bool(os.listdir(cwd))


def c_kb_writable(_):
    return writable_target(os.path.join(cwd, ".mega-sdd", "knowledge-base"))


def c_units_for_agents(_):
    return bool(unit_files())


def c_pkg_mgr(_):
    return which_any("brew", "apt", "dnf", "pacman", "apk", "winget",
                     "scoop", "cargo", "npm", "go")


def c_network(_):
    if shutil.which("curl"):
        r = subprocess.run(["curl", "-fsS", "--max-time", "5",
                            "https://github.com"],
                           capture_output=True, timeout=15)
        if r.returncode == 0:
            return True
    if shutil.which("ping"):
        r = subprocess.run(["ping", "-c", "1", "-W", "2", "github.com"],
                           capture_output=True, timeout=15)
        return r.returncode == 0
    return False


def c_pandoc(_):
    return which_any("pandoc")


def c_chrome_mmdc(_):
    chrome = which_any("google-chrome", "google-chrome-stable", "chromium",
                       "chromium-browser", "chrome") or any(
        os.path.isfile(p) for p in (
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium"))
    return chrome and which_any("mmdc")


def c_dag_acyclic(_):
    graph, WHITE, GRAY, BLACK = {}, 0, 1, 2
    for f in unit_files():
        fm = parse_frontmatter(f)
        uid = fm.get("id") or os.path.splitext(os.path.basename(f))[0]
        if isinstance(uid, list):
            uid = uid[0] if uid else os.path.basename(f)
        graph[str(uid)] = [str(d) for d in as_list(fm.get("depends_on", []))]
    color = {n: 0 for n in graph}
    for start in graph:
        if color[start] != WHITE:
            continue
        stack = [(start, iter(graph[start]))]
        color[start] = GRAY
        while stack:
            node, it = stack[-1]
            advanced = False
            for dep in it:
                if dep not in graph:
                    continue  # edge to an unknown id cannot close a cycle
                if color[dep] == GRAY:
                    return False  # cycle
                if color[dep] == WHITE:
                    color[dep] = GRAY
                    stack.append((dep, iter(graph[dep])))
                    advanced = True
                    break
            if not advanced:
                color[node] = BLACK
                stack.pop()
    return True


def c_partial_state(_):
    for f in glob.glob(os.path.join(VAULT, "bolts", "U-*",
                                    "partial-state.json")):
        try:
            with open(f, encoding="utf-8") as fh:
                json.load(fh)
        except Exception:
            return False
    return True


def c_acceptance_tests(_):
    for f in unit_files():
        with open(f, encoding="utf-8", errors="replace") as fh:
            if not re.search(r"^acceptance_test:", fh.read(), re.M):
                return False
    return True


def c_verify_no_targets(_):
    for f in unit_files():
        fm = parse_frontmatter(f)
        tt = fm.get("task_type", "")
        if isinstance(tt, list):
            tt = tt[0] if tt else ""
        if str(tt).strip() != "verify":
            continue
        if as_list(fm.get("target_files", [])):
            return False
    return True


# ── registry: skill → [(check_id, fatal, fn, on_fail hint)] ─────────────────

CHECKS = {
    "scan-codebase": [
        ("ast_engine_present", False, c_ast_engine,
         "no AST engine installed (tree-sitter AND ast-grep both absent); "
         "scan-codebase will fall back to the regex engine (lower precision). "
         "Install: brew install ast-grep (zero-compilation tier) / brew "
         "install tree-sitter-cli — OR run `/mega-sdd:install-deps` for "
         "auto-install. tree-sitter absent with ast-grep present is the "
         "NORMAL D2 state (no warning): auto extraction runs at the ast-grep "
         "tier, precision stays ast; tree-sitter is an explicit --engine "
         "opt-in."),
        ("framework_pack_present", False, c_framework_pack,
         "no framework pack for <framework>; scan-codebase will use "
         "_universal.md fallback patterns (lower starterkit detection "
         "precision)"),
    ],
    "bind-codebase": [
        ("binding_input_complete", True, c_binding_input,
         "bind-codebase requires both vault.json AND codebase-map.md. Run "
         "scan-codebase first if codebase-map.md absent; run generate-intent "
         "first if vault.json absent."),
    ],
    "execute-bolts": [
        ("units_directory_present", True, c_units_dir,
         "execute-bolts requires generated units. Run generate-units first."),
        ("superpowers_available", False, c_superpowers,
         "execute-bolts dispatches via superpowers.executing-plans; "
         "superpowers plugin not available"),
    ],
    "generate-intent": [
        # prd_or_kb_input_present is flag/positional-dependent (header
        # skip-list): the <prd-path> positional is invisible to
        # --cwd/--chain, and the root-only arm false-fails positional PRDs
        # — a fatal:yes false halt. The model runs it from the catalog when
        # it knows the positional.
    ],
    "detect-drift": [
        ("vault_present_for_drift", True, c_vault_json,
         "detect-drift requires a vault. Run generate-intent first."),
        ("binding_present_for_drift", True, c_binding_confirmed,
         "detect-drift compares against bound vault state. Run bind-codebase "
         "first to establish binding."),
        ("clean_working_tree_for_drift", False, c_clean_tree,
         "detect-drift may conflate uncommitted user edits with actual "
         "drift. Commit or stash local changes first for clean drift "
         "report."),
    ],
    "diff-vault": [
        ("current_vault_present_for_diff", True, c_vault_json,
         "diff-vault requires current vault to compare new source against. "
         "Run generate-intent first."),
        ("vault_version_parseable", True, c_vault_version,
         "current vault.json malformed OR missing vault_version field. "
         "diff-vault cannot determine version bump target."),
    ],
    "resolve-oq": [
        ("vault_present_for_oq", True, c_oq_inputs,
         "resolve-oq requires a vault with 03-open-questions.md. Run "
         "generate-intent first."),
        ("oq_status_field_present", False, c_oq_status_field,
         "vault.json open_questions[] entries lack 'status' field (pre-v1.1 "
         "schema). resolve-oq cannot track Resolve/Out-of-Scope/Defer "
         "outcomes without status field. Regenerate vault via "
         "generate-intent --refresh."),
        ("unresolved_oqs_exist", False, c_oq_unresolved,
         "All OQs in vault are already resolved. resolve-oq is a no-op."),
    ],
    "extract-intelligence": [
        ("legacy_codebase_path_present", True, c_legacy_path,
         "extract-intelligence requires a non-empty legacy codebase path."),
        ("kb_target_writable", True, c_kb_writable,
         "extract-intelligence cannot write to the knowledge-base output "
         "dir. Check permissions OR change --output."),
    ],
    "emit-agents-md": [
        ("vault_present_for_agents_md", True, c_vault_json,
         "emit-agents-md requires a vault. Run generate-intent first."),
        ("units_present_for_agents_md", False, c_units_for_agents,
         "emit-agents-md is unit-aware (lists units in AGENTS.md). Run "
         "generate-units first OR pass --no-units for vault-only "
         "AGENTS.md."),
    ],
    "install-deps": [
        ("pkg_mgr_detected", True, c_pkg_mgr,
         "install-deps requires a compatible package manager "
         "(brew/apt/dnf/pacman/apk/winget/scoop) or cross-platform fallback "
         "(cargo/npm/go). None detected on PATH. macOS: install brew via "
         "https://brew.sh. Linux: verify apt/dnf is on PATH. Windows "
         "native: install WSL Ubuntu + re-run."),
        ("network_reachable", False, c_network,
         "Network unreachable; package manager install will fail. Check "
         "connectivity OR set --manual to skip install (print commands "
         "only)."),
    ],
    "emit-fsd": [
        ("vault_present_for_fsd", True, c_vault_json,
         "emit-fsd requires a vault. Run generate-intent first."),
        ("pandoc_installed", False, c_pandoc,
         "pandoc not installed; emit-fsd will produce FSD.md only (no PDF "
         "render). Install: brew install pandoc (macOS) / apt install "
         "pandoc (Debian/Ubuntu) / dnf install pandoc (Fedora) — OR run "
         "`/mega-sdd:install-deps` for auto-install."),
        ("chrome_mmdc_present", False, c_chrome_mmdc,
         "Chrome absent -> md2pdf emits GitHub-styled HTML (print-to-PDF "
         "from a browser) instead of PDF; mmdc absent -> mermaid stays "
         "code. Install Chrome (detect-only) + run /mega-sdd:install-deps "
         "--tools=mmdc. PDF is NEVER LaTeX."),
    ],
}

COLD_HALT_CHECKS = [
    ("units_depends_on_dag_acyclic", True, c_dag_acyclic,
     "Cycle detected in unit depends_on graph. Inspect "
     "<vault>/units/U-*.md frontmatter; resolve cycle BEFORE running "
     "execute-bolts."),
    ("partial_state_loads_cleanly", False, c_partial_state,
     "One or more partial-state.json files have JSON parse errors. "
     "execute-bolts --resume will halt partial_state_corrupt. Rename "
     ".corrupt-<timestamp> and re-run without --resume OR fix the JSON "
     "manually."),
    ("units_have_acceptance_tests", True, c_acceptance_tests,
     "One or more units lack acceptance_test field. execute-bolts will "
     "halt unit_underspecified. Edit affected units OR re-run "
     "generate-units --strict."),
    ("verify_units_have_no_target_files", True, c_verify_no_targets,
     "One or more task_type: verify units have non-empty target_files. "
     "execute-bolts will halt verify_unit_writable. Edit affected units "
     "to remove target_files (verify units only run acceptance tests, "
     "don't author code)."),
]


def run_checks(skill, entries):
    for check_id, fatal, fn, hint in entries:
        try:
            passed = fn(None)
        except Exception as e:  # probe could not run → fail-open warn
            emit(skill, check_id, "warn",
                 "probe error (fail-open): %s" % str(e)[:200])
            continue
        if passed:
            emit(skill, check_id, "ok", "")
        else:
            emit(skill, check_id, "fatal" if fatal else "warn", hint)


for skill in chain:
    entries = CHECKS.get(skill)
    if entries is None:
        continue  # unknown skill → skip silently (forward-compat)
    run_checks(skill, entries)
    if skill == "execute-bolts":
        run_checks(skill, COLD_HALT_CHECKS)

print("PREFLIGHT: %d ok, %d warn, %d fatal"
      % (counts["ok"], counts["warn"], counts["fatal"]))
sys.exit(3 if counts["fatal"] > 0 else 0)
PYEOF
exit $?
fi


CWD=""
SKILL=""
QUIET=0
ARGS_B64=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --skill=*) SKILL="${arg#*=}" ;;
    --args-b64=*) ARGS_B64="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR_HELPER="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi
if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ ! -d "${CWD}/.mega-sdd" ]; then
  # no project — nothing to preflight; never block
  [ "$QUIET" -eq 0 ] && echo '{"status":"PASS","reason":"no .mega-sdd/ project"}'
  exit 0
fi

# Probe AST-engine availability for the scan warn-check (cheap; no file scan).
# D2 ladder: auto = ast-grep -> regex (tree-sitter is an explicit opt-in lane);
# the warn fires only when NO AST engine is present at all.
TS_PRESENT=0
if command -v tree-sitter >/dev/null 2>&1 || command -v tree-sitter-cli >/dev/null 2>&1; then
  TS_PRESENT=1
fi
AG_PRESENT=0
command -v ast-grep >/dev/null 2>&1 && AG_PRESENT=1

# P1 (v4.93.0, decision 8): the probe predicates live in the SHARED library
# scripts/_lib/state_probes.py — one probe set for preflight AND the routing
# digest (derive-state.sh), so the two surfaces can never re-diverge again.
# Semantics are IDENTICAL to the inline functions this script carried pre-P1
# (incl. S4 BC-PREFLIGHT-LEGACY: the map probe accepts the legacy repo-root
# location; probing only the canonical path FATAL-blocked every bind on a
# pre-migration project whose map bind would happily consume).
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" SKILL="$SKILL" ARGS_B64="$ARGS_B64" TS_PRESENT="$TS_PRESENT" AG_PRESENT="$AG_PRESENT" QUIET="$QUIET" python3 <<'PYEOF'
import base64, json, os, re, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
from state_probes import (
    has_vault as _has_vault,
    has_bound_or_vault as _has_bound_or_vault,
    has_units as _has_units,
    has_codebase_map as _has_codebase_map,
    probe_spine as _probe_spine,
)

cwd = os.environ["CWD"]
skill = os.environ.get("SKILL", "")
ts_present = os.environ.get("TS_PRESENT", "0") == "1"
ag_present = os.environ.get("AG_PRESENT", "0") == "1"
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# P2: the express lane reads NO codebase-map — the map arm of the bind check
# must not falsely FATAL a valid express dispatch. Express is detected from
# the dispatch args (--express token, word-boundary; --no-express/--classic
# override it off) falling back to the config spine (express is the P2
# default). The vault arm stays FATAL either way.
try:
    _args = base64.b64decode(os.environ.get("ARGS_B64", "")).decode(
        "utf-8", errors="replace")
except Exception:
    _args = ""
if re.search(r"(?:^|\s)--(?:no-express|classic)(?:\s|$)", _args):
    express = False
elif re.search(r"(?:^|\s)--express(?:\s|$|=)", _args):
    express = True
else:
    express = _probe_spine(cwd) == "express"


def has_vault():
    return _has_vault(cwd)


def has_bound_or_vault():
    return _has_bound_or_vault(cwd)


def has_units():
    return _has_units(cwd)


def has_codebase_map():
    return _has_codebase_map(cwd)


fatal = None          # {check_id, on_fail}
warnings = []
checks = []

name = skill.split(":")[-1] if skill else ""

if name == "bind-codebase":
    if not has_vault():
        fatal = {"check_id": "binding_input_vault_missing",
                 "on_fail": "bind-codebase needs a vault (.mega-sdd/vaults/<vault>/) — run generate-intent first."}
    elif not express and not has_codebase_map():
        # classic lane only: express reads no map (express-bind.md), so a
        # map-missing FATAL here would falsely block the default P2 spine.
        fatal = {"check_id": "binding_input_map_missing",
                 "on_fail": "bind-codebase needs a codebase-map.md (.mega-sdd/codebase/codebase-map.md) — run scan-codebase first."}
    checks.append({"check": "binding_input_complete", "status": "FAIL" if fatal else "PASS",
                   "lane": "express" if express else "classic"})

elif name == "generate-units":
    if not has_bound_or_vault():
        fatal = {"check_id": "units_input_vault_missing",
                 "on_fail": "generate-units needs a (bound-)vault — run generate-intent (and bind-codebase) first."}
    checks.append({"check": "units_input_complete", "status": "FAIL" if fatal else "PASS"})

elif name == "execute-bolts":
    if not has_units():
        fatal = {"check_id": "bolts_units_missing",
                 "on_fail": "execute-bolts needs units (.mega-sdd/vaults/<vault>/units/U-*.md) — run generate-units first."}
    checks.append({"check": "units_directory_present", "status": "FAIL" if fatal else "PASS"})

elif name == "scan-codebase":
    if not ts_present and not ag_present:
        warnings.append({"check_id": "ast_engine_present",
                         "detail": "no AST engine installed (tree-sitter AND ast-grep both absent); "
                                   "scan-codebase falls back to the regex engine (lower precision; "
                                   "bind-codebase field-level diff will degrade). Install via "
                                   "/mega-sdd:install-deps or `brew install ast-grep` (zero-compilation "
                                   "tier) / `brew install tree-sitter-cli`."})
    # tree-sitter absence is the NORMAL D2 happy path (auto = ast-grep -> regex;
    # tree-sitter is an explicit opt-in lane) — not warn-worthy.
    checks.append({"check": "ast_engine_present", "status": "WARN" if warnings else "PASS"})

status = "FATAL" if fatal else ("WARN" if warnings else "PASS")
report = {
    "status": status,
    "validator": "preflight",
    "ts": ts,
    "skill": skill,
    "fatal_check_id": fatal["check_id"] if fatal else None,
    "fatal_on_fail": fatal["on_fail"] if fatal else None,
    "warnings": warnings,
    "checks": checks,
    "summary": (
        f"FATAL precondition unmet for {skill}: {fatal['on_fail']}" if fatal
        else (f"{len(warnings)} preflight warning(s) for {skill}" if warnings
              else f"preflight clean for {skill or '(no skill)'}")
    ),
}

state_file = os.path.join(cwd, ".mega-sdd", ".preflight-state.json")
try:
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
        f.write("\n")
except Exception:
    pass

if not quiet:
    print(json.dumps(report))
sys.exit(1 if status == "FATAL" else 0)
PYEOF
