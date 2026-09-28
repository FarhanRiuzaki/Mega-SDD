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
#   execute-bolts   : needs units/U-*.md                           → FATAL if absent
#                     a fresh plan-coverage PASS entry for EVERY plan-born
#                     (layout-3, un-migrated) vault carrying units → FATAL lite_plan_coverage_pass
#   plan            : target vault is layout-2 (no context.md)     → FATAL (migrate-paths --vault-layout=3)
#   generate-intent / bind-codebase / generate-units / scan-codebase
#                   : removed in 9.0                               → FATAL (one line: use plan),
#                                                                    even with no .mega-sdd/
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

CWD="$CWD" CHAIN="$CHAIN" python3 <<'PYEOF'
import glob, json, os, re, shutil, subprocess, sys, time

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
try:
    import state_probes  # shared probe library — never duplicated
except Exception:
    state_probes = None

cwd = os.path.abspath(os.environ.get("CWD") or os.getcwd())
chain = [s.strip() for s in os.environ.get("CHAIN", "").split(",") if s.strip()]

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


def _rail_vaults():
    """Every canonical plan-born vault carrying units (context.md present, not migrated) — the dispatch twin's set."""
    import prd_headings
    return prd_headings.plan_vaults(cwd)


def c_plan_coverage_pass(_):
    """The PRD→units coverage rail: bolts may not start until every plan-born vault has a PASS entry in
    .mega-sdd/.plan-coverage-state.json whose digest still matches its PRD, context.md exclusions / OQs and units
    (written by validate-plan-coverage.sh, plan Step 5; prd_headings.coverage_verdict — pure reads)."""
    import prd_headings
    return prd_headings.coverage_verdict(cwd, _rail_vaults())[0]


def plan_coverage_exempt():
    """9.0: lite is the one pipeline, so the rail is ON by default — no config
    key switches it off. Exempt: a MIGRATED layout-2 vault (spec §7 #12 —
    classic-born units carry no prd_source), unless an un-migrated plan-born
    sibling (context.md) carries units: the vault sorting first never exempts it."""
    mig = lambda d: os.path.isdir(os.path.join(d, "_meta", "archive", "layout2"))
    return mig(VAULT) and not any(
        os.path.isfile(os.path.join(d, "context.md")) and not mig(d)
        and (glob.glob(os.path.join(d, "units", "U-*.md")) or glob.glob(os.path.join(d, "units", "U-*", "unit.md")))
        for d in glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*")))


PLAN_COVERAGE_CHECKS = [
    ("lite_plan_coverage_pass", True, c_plan_coverage_pass,
     ".mega-sdd/.plan-coverage-state.json is missing, FAIL or stale for a "
     "plan-born vault (plan_coverage_gap): every PRD anchor needs a decision "
     "BEFORE execute-bolts — a unit's prd_source, an open question carrying [covers: <ref>], "
     "or a line in the vault's context.md ## Coverage exclusions with a real "
     "reason. Run validate-plan-coverage.sh --cwd --prd --vault for each vault "
     "(plan Step 5; KB: --kb=<kb-dir>) and close the listed gaps; a missing "
     "state is a skipped census, not a pass, and an edit to the PRD, the "
     "exclusions, an OQ or a unit's prd_source makes it stale. A layout-2 "
     "vault: /mega-sdd:migrate-paths --vault-layout=3 first (a migrated vault "
     "is exempt)."),
]


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
    # ast-grep IS the AST engine (the tree-sitter lane is gone since v7.4.0).
    # A repo with no source needs no symbol index → pass (greenfield).
    if which_any("ast-grep"):
        return True
    return not state_probes.probe_code_files(cwd)["has_code_files"]


def c_units_dir(_):
    return bool(unit_files())


def c_vault_json(_):
    return os.path.isfile(os.path.join(VAULT, "vault.json"))


def c_binding_confirmed(_):
    # layout-3 (plan-born) vault: verdicts live per unit in bolts/U-XXX/binding.json,
    # there is no whole-vault binding.md (doc-audit v8 finding #16 — the check used
    # to FATAL every lite hop of detect-drift).
    if os.path.isfile(os.path.join(VAULT, "context.md")):
        return bool(glob.glob(os.path.join(VAULT, "bolts", "U-*", "binding.json")))
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
    # Layout-aware (leftover fix 7.29.1): OQs live in constraints.md (layout-2)
    # or 06-constraints.md (legacy 7-file); no layout ever produced
    # 03-open-questions.md, so the old predicate was fatal on EVERY real vault.
    # No vault but an extract-intelligence KB → resolve-oq KB mode (the
    # PRD-kontrak §6 OQs; same probe order as resolve-oq Step 0).
    if state_probes is not None and \
            not os.path.isfile(os.path.join(VAULT, "vault.json")) and \
            state_probes.probe_knowledge_base(cwd)["present"]:
        return True
    return (os.path.isfile(os.path.join(VAULT, "vault.json"))
            and any(os.path.isfile(os.path.join(VAULT, f))
                    for f in ("context.md",              # v8 P2 layout-3 (`## Open Questions`)
                              "constraints.md", "06-constraints.md",
                              "03-open-questions.md")))  # last: ancient hand-made vaults / fixtures


def c_oq_status_field(_):
    if not os.path.isfile(os.path.join(VAULT, "vault.json")):
        return True  # KB mode / no vault: vault_present_for_oq owns the absence
    v = load_vault_json()
    return any("status" in oq for oq in v.get("open_questions", []))


def c_oq_unresolved(_):
    if not os.path.isfile(os.path.join(VAULT, "vault.json")):
        return True  # KB mode / no vault: vault_present_for_oq owns the absence
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
    "execute-bolts": [
        ("units_directory_present", True, c_units_dir,
         "execute-bolts requires generated units. Run `plan <prd>` first (it "
         "writes units in the same phase; for a legacy KB use "
         "`plan --kb=<kb-dir>`; a plan-born vault with no units -> "
         "`plan <prd> --regenerate`)."),
    ],
    "plan": [
        # The <prd> positional and --kb=<kb-dir> are invisible to
        # --cwd/--chain, so the input check stays model-run from the catalog
        # (a root-only arm would false-fail positional PRDs — a fatal:yes
        # false halt).
        ("ast_engine_present", False, c_ast_engine,
         "ast-grep not installed; GROUND builds no symbol index "
         "(build-symbol-index.sh exit 3), so plan's brownfield task_type probe "
         "and the JIT bind lose symbol evidence. Install: brew/scoop install "
         "ast-grep or /mega-sdd:install-deps."),
    ],
    "detect-drift": [
        ("vault_present_for_drift", True, c_vault_json,
         "detect-drift requires a vault. Run `plan <prd>` first (legacy code: "
         "extract-intelligence -> `plan --kb=<kb-dir>`)."),
        ("binding_present_for_drift", True, c_binding_confirmed,
         "detect-drift compares against bound vault state. On a layout-3 vault "
         "the verdicts come from execute-bolts --all --lite (JIT bind per unit) "
         "or scripts/rebind-units.sh --units=all; a layout-2 vault with no "
         "binding.md: /mega-sdd:migrate-paths --vault-layout=3, then the full "
         "JIT re-bind."),
        ("clean_working_tree_for_drift", False, c_clean_tree,
         "detect-drift may conflate uncommitted user edits with actual "
         "drift. Commit or stash local changes first for clean drift "
         "report."),
    ],
    "diff-vault": [
        ("current_vault_present_for_diff", True, c_vault_json,
         "diff-vault requires current vault to compare new source against. "
         "Run `plan <prd>` first."),
        ("vault_version_parseable", True, c_vault_version,
         "current vault.json malformed OR missing vault_version field. "
         "diff-vault cannot determine version bump target."),
    ],
    "resolve-oq": [
        ("vault_present_for_oq", True, c_oq_inputs,
         "resolve-oq requires a vault with vault.json + the OQ doc (context.md on "
         "layout-3, constraints.md, or 06-constraints.md on the legacy layout). Run "
         "`plan <prd>` first."),
        ("oq_status_field_present", False, c_oq_status_field,
         "vault.json open_questions[] entries lack 'status' field (pre-v1.1 "
         "schema). resolve-oq cannot track Resolve/Out-of-Scope/Defer "
         "outcomes without status field. Run `derive-vault-json.sh --vault "
         "<dir>` (re-derives vault.json from the docs, any layout), or "
         "`plan <prd> --regenerate` on a plan-born vault."),
        ("unresolved_oqs_exist", False, c_oq_unresolved,
         "No open OQ is left in the vault — a plain resolve-oq walk is a no-op (`resolve-oq single-oq <OQ-ID>` still overrides an AI technical decision)."),
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
         "emit-agents-md requires a vault. Run `plan <prd>` first."),
        ("units_present_for_agents_md", False, c_units_for_agents,
         "emit-agents-md is unit-aware (lists units in AGENTS.md). Run "
         "`plan <prd>` first (it writes units in the same phase) OR pass "
         "--no-units for a vault-only AGENTS.md."),
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
         "emit-fsd requires a vault. Run `plan <prd>` first."),
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
     "`plan <prd> --regenerate` (validate-unit-spec.sh at plan Step 5 halts "
     "unit_underspecified)."),
    ("verify_units_have_no_target_files", True, c_verify_no_targets,
     "One or more task_type: verify units have non-empty target_files. "
     "execute-bolts will halt verify_unit_writable. Edit affected units "
     "to remove target_files (verify units only run acceptance tests, "
     "don't author code)."),
]


# ── chain-aware inputs (v8 P0 live finding, 2026-09-10) ──────────────────────
# A predictive run over a WHOLE chain (--chain=plan,execute-bolts) used to
# report FATAL for inputs that an EARLIER hop of the same chain produces
# (units/ and plan_coverage for bolts, produced by plan): a false fatal on every
# greenfield chain, and in the xs baseline arm the model had to work around it
# by re-running preflight per hop. An input that is missing NOW but produced by
# a hop that precedes this skill in --chain is satisfied by the chain itself →
# "ok" with the reason; the PreToolUse gate re-checks it at that hop anyway:
# the dispatch mode below refuses execute-bolts with no units
# (bolts_units_missing) and, on the plan-born vault that plan hop writes, with a
# missing/FAIL census (lite_plan_coverage_pass). Inputs no earlier hop produces
# stay fatal.
# plan = context.md + vault.json + units + coverage in ONE hop; plan Step 5
# writes .plan-coverage-state.json.
PRODUCES = {"plan": {"vault", "units", "plan_coverage"}}


def _missing_inputs(check_id):
    miss = set()
    if check_id == "units_directory_present":
        if not unit_files():
            miss.add("units")
    elif check_id == "lite_plan_coverage_pass":
        # produced by the plan hop that precedes bolts on the chain — a
        # missing state (or a vault entry missing / stale) at chain START is not a skipped census
        import prd_headings
        if prd_headings.coverage_verdict(cwd, _rail_vaults())[2]:
            miss.add("plan_coverage")
    elif check_id == None:
        if not os.path.isfile(os.path.join(VAULT, "vault.json")):
            miss.add("vault")
    return miss


def run_checks(skill, entries, earlier=()):
    produced = set()
    for s_ in earlier:
        produced |= PRODUCES.get(s_, set())
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
            miss = _missing_inputs(check_id)
            if fatal and miss and miss <= produced:
                emit(skill, check_id, "ok",
                     "chain-aware: %s produced by an earlier hop of this chain (%s); re-checked at that hop by the gate"
                     % ("/".join(sorted(miss)), ", ".join(s_ for s_ in earlier if PRODUCES.get(s_, set()) & miss)))
            else:
                emit(skill, check_id, "fatal" if fatal else "warn", hint)


REMOVED = state_probes.REMOVED_SKILLS if state_probes is not None else {}

for idx, skill in enumerate(chain):
    if skill in REMOVED:
        # a stale 8.x chain (e.g. a paused --resume) naming a removed skill
        emit(skill, "skill_removed_in_9", "fatal", REMOVED[skill])
        continue
    entries = CHECKS.get(skill)
    if entries is None:
        continue  # unknown skill → skip silently (forward-compat)
    run_checks(skill, entries, earlier=chain[:idx])
    if skill == "execute-bolts":
        run_checks(skill, COLD_HALT_CHECKS)
        if not plan_coverage_exempt():
            run_checks(skill, PLAN_COVERAGE_CHECKS, earlier=chain[:idx])

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
NO_PROJECT=0
if [ ! -d "${CWD}/.mega-sdd" ]; then
  # No project: never block, write nothing. The hook's names exit here (0 python);
  # any other name goes to python, which FATALs a skill in state_probes.REMOVED_SKILLS
  # (never a fall-through PASS) and prints this same PASS for the rest.
  case "${SKILL##*:}" in
    plan|execute-bolts|"")
      [ "$QUIET" -eq 0 ] && echo '{"status":"PASS","reason":"no .mega-sdd/ project"}'
      exit 0 ;;
  esac
  NO_PROJECT=1
fi

# P1 (v4.93.0, decision 8): the probe predicates live in the SHARED library
# scripts/_lib/state_probes.py — one probe set for preflight AND the routing
# digest (derive-state.sh), so the two surfaces can never re-diverge again.
# Semantics are IDENTICAL to the inline functions this script carried pre-P1.
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" SKILL="$SKILL" ARGS_B64="$ARGS_B64" QUIET="$QUIET" NO_PROJECT="$NO_PROJECT" python3 <<'PYEOF'
import base64, glob, json, os, re, shlex, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
from state_probes import (
    REMOVED_SKILLS,
    has_units as _has_units,
    probe_knowledge_base,
)

cwd = os.environ["CWD"]
skill = os.environ.get("SKILL", "")
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# `_args` = the decoded dispatch args, read by the --vault= / --kb= / <prd> resolution.
try:
    _args = base64.b64decode(os.environ.get("ARGS_B64", "")).decode(
        "utf-8", errors="replace")
except Exception:
    _args = ""


def has_units():
    return _has_units(cwd)


fatal = None          # {check_id, on_fail}
warnings = []
checks = []

name = skill.split(":")[-1] if skill else ""
no_project = os.environ.get("NO_PROJECT", "0") == "1"
if no_project and name not in REMOVED_SKILLS:
    # the bash no-project PASS, byte-identical, for a name the bash case let through
    if not quiet:
        print('{"status":"PASS","reason":"no .mega-sdd/ project"}')
    sys.exit(0)


def _kebab(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def _kb_slug(kb):
    """The --kb slug rule of derive-plan-pins.sh: basename of the census.json
    `legacy_root`, else the README H1 title (first segment), else "kb". None
    when <kb>/README.md is unreadable (derive-plan-pins exits 3; plan stops)."""
    try:
        with open(os.path.join(kb, "README.md"), encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return None
    legacy = ""
    census = os.path.join(kb, "census.json")
    if os.path.isfile(census):
        try:
            with open(census, encoding="utf-8") as f:
                legacy = str(json.load(f).get("legacy_root") or "")
        except Exception:
            legacy = ""
    title = next((m.group(1) for m in re.finditer(r"^#[ \t]+(.+?)\s*$", text, re.M)), "")
    title = re.split(r"\s+[—–|:-]\s+", title)[0]
    return _kebab(os.path.basename(legacy.rstrip("/\\"))) or _kebab(title) or "kb"


def _target_vault():
    """Resolve the dispatch's target vault dir the way derive-plan-pins.sh
    does: `--vault=<name|dir>` wins; else .mega-sdd/vaults/<slug> from
    `--kb=<kb-dir>` (the census/README slug rule), from the <prd> positional,
    or — no positional and no --reconcile — from the KB plan auto-detects
    (kb-input §KB auto-detection, the state_probes probe). None when nothing
    resolves — never every vault dir: a mixed project would false-FATAL."""
    root = os.path.join(cwd, ".mega-sdd", "vaults")
    try:
        toks = shlex.split(_args)
    except ValueError:
        toks = _args.split()
    vault = kb = None
    positional = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if t in ("--vault", "--kb") and i + 1 < len(toks) and not toks[i + 1].startswith("-"):
            v, i = toks[i + 1], i + 1
        elif t.startswith(("--vault=", "--kb=")):
            v = t.split("=", 1)[1]
        else:
            if not t.startswith("-"):
                positional.append(t)
            i += 1
            continue
        if t.startswith("--vault"):
            vault = v if vault is None else vault
        else:
            kb = v if kb is None else kb
        i += 1
    if vault is not None:
        for cand in (vault, os.path.join(cwd, vault), os.path.join(root, vault)):
            if vault and os.path.isdir(cand):
                return cand
        return None
    if kb is None and not positional and "--reconcile" not in toks:
        probe = probe_knowledge_base(cwd)
        if probe.get("present") and probe.get("path"):
            kb = os.path.dirname(probe["path"])
    if kb is not None:
        kb = os.path.expanduser(kb.rstrip("/\\"))
        if not kb:
            return None
        slug = _kb_slug(kb if os.path.isabs(kb) else os.path.join(cwd, kb))
        return os.path.join(root, slug) if slug else None
    for t in positional:
        p = t if os.path.isabs(t) else os.path.join(cwd, t)
        if not os.path.isfile(p):
            continue
        base = re.sub(r"\.[A-Za-z0-9]+$", "", os.path.basename(os.path.realpath(p)))
        base = re.sub(r"^(?i:prd)[-_ ]+", "", base)
        return os.path.join(root, _kebab(base) or "vault")
    return None


def _layout2(vdir):
    """layout-2 / legacy docs and no context.md (a migrated vault has one)."""
    if os.path.isfile(os.path.join(vdir, "context.md")):
        return False
    return (os.path.isfile(os.path.join(vdir, "vault.md"))
            or bool(glob.glob(os.path.join(vdir, "0[0-6]-*.md"))))


def _coverage_rail_vaults():
    """Every canonical plan-born vault carrying units: context.md present,
    `_meta/archive/layout2/` absent (a migrated vault is exempt, spec §7 #12; a
    layout-2/legacy vault has no census). No dispatch arg narrows it: execute-bolts
    has no --vault flag."""
    import prd_headings
    return prd_headings.plan_vaults(cwd)


def _coverage_census(rail):
    """(passed, why) READ from validate-plan-coverage.sh's state (plan Step 5) — the census is never recomputed here
    (no process): every rail vault needs a PASS entry whose digest still matches (prd_headings.coverage_verdict)."""
    import prd_headings
    passed, why, _ = prd_headings.coverage_verdict(cwd, rail)
    return passed, why


if name in REMOVED_SKILLS:
    fatal = {"check_id": "skill_removed_in_9", "on_fail": REMOVED_SKILLS[name]}
    checks.append({"check": "skill_removed_in_9", "status": "FAIL"})

elif name == "plan":
    # 9.0: plan is the only spec producer and writes layout-3 only, so it
    # refuses a layout-2 TARGET vault (a migrated vault has context.md and
    # stays open to --regenerate, spec §7 #12).
    tv = _target_vault()
    if tv and _layout2(tv):
        rel = os.path.relpath(tv, cwd)
        fatal = {"check_id": "plan_layout2_vault",
                 "on_fail": ("plan writes layout-3 only and the target vault %s is layout-2 (no context.md) — "
                             "run /mega-sdd:migrate-paths --vault-layout=3 --vault=%s first (a legacy 7-file vault "
                             "takes --vault-layout first; then the mandatory full JIT re-bind), or pass "
                             "--vault=<new-dir> for a separate plan-born vault." % (rel, rel))}
    checks.append({"check": "plan_target_layout", "status": "FAIL" if fatal else "PASS"})

elif name == "execute-bolts":
    if not has_units():
        fatal = {"check_id": "bolts_units_missing",
                 "on_fail": "execute-bolts needs units (.mega-sdd/vaults/<vault>/units/U-*.md) — run `plan <prd>` first "
                            "(legacy KB: `plan --kb=<kb-dir>`; a plan-born vault with no units: `plan <prd> --regenerate`)."}
    checks.append({"check": "units_directory_present", "status": "FAIL" if fatal else "PASS"})
    rail = [] if fatal else _coverage_rail_vaults()
    if rail:  # the dispatch twin of --predictive lite_plan_coverage_pass (V6, 2026-09-27 audit)
        passed, why = _coverage_census(rail)
        if not passed:
            fatal = {"check_id": "lite_plan_coverage_pass",
                     "on_fail": ("plan_coverage_gap — the plan-coverage census .mega-sdd/.plan-coverage-state.json is %s "
                                 "(plan-born vault(s) %s): every PRD anchor needs a decision BEFORE execute-bolts — a "
                                 "unit's prd_source, an open question carrying [covers: <ref>], or a line in that vault's context.md "
                                 "## Coverage exclusions with a real reason. Run "
                                 "scripts/validate-plan-coverage.sh --cwd=<root> --prd=<prd> --vault=<vault> for each (plan "
                                 "Step 5; KB: --kb=<kb-dir> instead of --prd) and close the listed gaps."
                                 % (why, ", ".join(os.path.relpath(v, cwd) for v in rail)))}
        checks.append({"check": "lite_plan_coverage_pass", "status": "PASS" if passed else "FAIL"})

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
if not no_project:  # a non-project gets no .mega-sdd/ written into it
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
