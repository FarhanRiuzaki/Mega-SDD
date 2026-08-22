#!/usr/bin/env bash
# run-analyze.sh — R1: unified cross-artifact consistency analyzer.
#
# TWO modes:
#   FULL (default / manual): re-run all validators + vault checks → aggregate → report.
#   AGGREGATE-ONLY (--aggregate-only): read existing state files written by PostToolUse
#     validators during the chain → aggregate → report. Cheap; no re-run. Used by
#     Stop hook for auto-chain reporting.
#
# FULL mode is SEMANTIC-SCOPED by default (S1, spec
# 2026-08-03-semantic-scoped-validation.md): per-file validators re-run only for
# files whose reuse key no longer matches .mega-sdd/.analyze-freshness.json
# (pure families: file sha + plugin version; env-coupled vault_oqs additionally
# the code fingerprint + sibling vault.json sha); unchanged files fold their
# recorded verdict without a spawn. unit_spec collapsed to ONE project-wide
# invocation (the validator scans all units per call — S5 GU-HOOK-1). --fresh
# forces a full re-run. Report-only surface: no gate reads any of this.
#
# Inputs: --cwd=<project-root> [--quiet] [--aggregate-only] [--fresh]
# Outputs:
#   <cwd>/.mega-sdd/.analyze-state.json (machine-readable aggregate)
#   <cwd>/.mega-sdd/CONSISTENCY-REPORT.md (human-readable report)
#   <cwd>/.mega-sdd/.analyze-freshness.json (FULL mode — the reuse ledger)
# Exit: 0 = all PASS/WARN, 1 = any FAIL, 2 = error.

set -uo pipefail

CWD=""
QUIET=0
AGGREGATE_ONLY=0
FRESH=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --quiet) QUIET=1 ;;
    --aggregate-only) AGGREGATE_ONLY=1 ;;
    --fresh) FRESH=1 ;;
  esac
done
# Resolve project root (Iter 71 — class-bug fix: if invoked from a sub-folder
# like .mega-sdd/knowledge-base/, walk UP to the outermost .mega-sdd/ parent
# so state files land in the canonical location, not nested .mega-sdd/.mega-sdd/).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi


if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi

if [ ! -d "${CWD}/.mega-sdd" ]; then
  echo "ERROR: no .mega-sdd/ directory in ${CWD}" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown-ts")

# ── S1 semantic-scoped defaults (spec 2026-08-03-semantic-scoped-validation.md).
# Populated by the FULL-mode freshness decision phase; aggregate-only never touches
# the ledger and reports scope_mode=aggregate with zero counters.
SCOPE_MODE="aggregate"; REUSED_FILES=0; RERUN_FILES=0; LEDGER_TS=""
V3_ST=""; V4_ST=""; V5_ST=""; V7_ST=""; V7M_ST=""; V7F_ST=""; V7VF_ST=""; V7C_ST=""

if [ "$AGGREGATE_ONLY" -eq 1 ]; then
  # ─── AGGREGATE-ONLY MODE ──────────────────────────────────────────────
  # Skip Phase 1 (validator invocation) and Phase 2 (vault internal checks).
  # Read existing state files written by PostToolUse validators during chain.
  # Jump to Phase 3 aggregation. Each V*_RC defaults to the "STATE_FILE" sentinel
  # (aggregator reads the state file status directly instead of an exit code).
  #
  # R3-11: the discovery-gated validators (unit_spec, bolt_artifacts, fsd_slots, the KB
  # validators) are reported SKIP by FULL mode when no in-scope files exist. Reading their
  # state file blindly here would surface a STALE FAIL — left by a prior chain whose source
  # files are now gone/archived — as a live FAIL, contradicting what FULL reports (SKIP) on
  # the SAME tree. So we replicate FULL's existence check and force SKIP when there are no
  # files; the on-disk status is trusted only when files actually exist. This path is
  # REPORT-ONLY (the moat reads .validation-blockers.json directly, never this aggregate),
  # so computing SKIP here cannot weaken any gate. vault_oqs (V4) has NO existence-SKIP in
  # FULL — it defaults to PASS — so it stays STATE_FILE here too; do NOT add a SKIP for it.

  # find-any helper: 0 if at least one path matches, 1 otherwise (missing dir => no match).
  _has() { find "$@" 2>/dev/null | grep -q .; }

  # Validators FULL runs unconditionally (no file-existence SKIP) → always read from disk.
  V1_RC="STATE_FILE"; V4_RC="STATE_FILE"; V3B_RC="STATE_FILE"
  V7S_RC="STATE_FILE"; V10_RC="STATE_FILE"
  V11_RC="STATE_FILE"; V12_RC="STATE_FILE"

  # Discovery-gated validators — mirror FULL's SKIP-when-no-files (globs match FULL exactly).
  _has "${CWD}/.mega-sdd/vaults" -path "*/units/U-*.md" -not -path "*/.archived/*" \
    && V2_RC="STATE_FILE" || V2_RC="SKIP"
  _has "${CWD}/.mega-sdd/vaults" -path "*/bolts/U-*/bolt-report.md" -not -path "*/.archived/*" \
    && V3_RC="STATE_FILE" || V3_RC="SKIP"
  _has "${CWD}/.mega-sdd/vaults" -name "FSD.md" -not -path "*/.archived/*" \
    && V5_RC="STATE_FILE" || V5_RC="SKIP"
  { _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    || _has "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*" \
    || _has "${CWD}/.mega-sdd/knowledge-base/40-business-rules" -name "*.md" -not -path "*/.archived/*"; } \
    && V7_RC="STATE_FILE" || V7_RC="SKIP"
  _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    && V7M_RC="STATE_FILE" || V7M_RC="SKIP"
  { _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    || _has "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*"; } \
    && V7F_RC="STATE_FILE" || V7F_RC="SKIP"
  _has "${CWD}/.mega-sdd/vaults" \( -name "04-flows.md" -o -name "flows.md" \) -not -path "*/.archived/*" \
    && V7VF_RC="STATE_FILE" || V7VF_RC="SKIP"
  _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    && V7C_RC="STATE_FILE" || V7C_RC="SKIP"

  # Advisory checks not re-run in aggregate-only mode
  REUSE_DUP_OUTPUT=""

  # Vault internal consistency: run inline (cheap, pure reads, no validators)
  VAULT_CONSISTENCY="[]"

  # Skip directly to Phase 3
else
  # ─── FULL MODE (default) ──────────────────────────────────────────────

# ── S1: freshness decision phase (spec 2026-08-03-semantic-scoped-validation.md) ──
# Default = SCOPED: per-file validators re-run only for files whose reuse key no
# longer matches .mega-sdd/.analyze-freshness.json; unchanged files fold their
# recorded verdict in without a spawn. --fresh forces a full re-run. The ledger
# is REPORT-ONLY plumbing: no gate reads it (the execute-bolts gate re-derives
# from ground truth regardless), so a stale/forged ledger can only mislead this
# report, never open a gate. Single writer: this script, FULL mode, end of run.
SCOPE_MODE=$( [ "$FRESH" -eq 1 ] && echo "fresh" || echo "scoped" )
TMPD=$(mktemp -d 2>/dev/null || mktemp -d -t analyze)
trap 'rm -rf "$TMPD"' EXIT

PLUGIN_VERSION=""
_PJ="${SCRIPT_DIR%/scripts}/.claude-plugin/plugin.json"
if [ -f "$_PJ" ]; then
  _PJC=$(<"$_PJ")
  [[ "$_PJC" =~ \"version\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && PLUGIN_VERSION="${BASH_REMATCH[1]}"
fi

# Per-family candidate lists (globs byte-identical to the pre-S1 loop finds).
find "${CWD}/.mega-sdd/vaults" \( -name "0[0-6]-*.md" -o -name "vault.md" -o -name "model.md" -o -name "flows.md" -o -name "constraints.md" \) -not -path "*/bound/*" -not -path "*/.archived/*" 2>/dev/null > "${TMPD}/files.vault_oqs"
find "${CWD}/.mega-sdd/vaults" -name "FSD.md" -not -path "*/.archived/*" 2>/dev/null > "${TMPD}/files.fsd_slots"
{ find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; \
  find "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; \
  find "${CWD}/.mega-sdd/knowledge-base/40-business-rules" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; } > "${TMPD}/files.kb_output"
find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null > "${TMPD}/files.kb_markers"
{ find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; \
  find "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; } > "${TMPD}/files.kb_flows"
find "${CWD}/.mega-sdd/vaults" \( -name "04-flows.md" -o -name "flows.md" \) -not -path "*/.archived/*" 2>/dev/null > "${TMPD}/files.vault_flows"
# unit_baseline drives NO reuse in analyze (unit_spec always re-runs, single
# invocation below) — it is the changed-set baseline for lint-units --changed-only.
find "${CWD}/.mega-sdd/vaults" -path "*/units/U-*.md" -not -path "*/.archived/*" 2>/dev/null > "${TMPD}/files.unit_baseline"

if ! TMPD="$TMPD" CWD="$CWD" FRESH="$FRESH" PLUGIN_VERSION="$PLUGIN_VERSION" python3 <<'PYEOF'
import hashlib, json, os, subprocess

tmpd = os.environ["TMPD"]; cwd = os.environ["CWD"]
fresh = os.environ.get("FRESH", "0") == "1"
pv = os.environ.get("PLUGIN_VERSION", "")
ledger_path = os.path.join(cwd, ".mega-sdd", ".analyze-freshness.json")

def sha_file(p):
    h = hashlib.sha256()
    try:
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return ""

def code_fingerprint():
    """HEAD + code-tree dirty content (outside .mega-sdd/). Content-hashed, never
    mtime. -z: NUL-separated, unquoted paths (a quoted name would otherwise never
    content-hash). -uall: files INSIDE untracked directories are enumerated (a bare
    "?? dir/" line is blind to content churn within). Paths in porcelain output are
    REPO-ROOT-relative, so they resolve against --show-toplevel, never against cwd
    (the mega-sdd root may be a subdirectory of the git repo). Fail-closed: any
    doubt (no git, timeout, >200 dirty paths) -> "unreusable" -> env-coupled
    families re-run."""
    try:
        head = subprocess.run(["git", "-C", cwd, "rev-parse", "HEAD"],
                              capture_output=True, text=True, timeout=30)
        if head.returncode != 0:
            return "unreusable"
        top = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=30)
        if top.returncode != 0:
            return "unreusable"
        toplevel = top.stdout.strip()
        st = subprocess.run(["git", "-C", cwd, "status", "--porcelain", "-z", "-uall",
                             "--", ".", ":!.mega-sdd"],
                            capture_output=True, text=True, timeout=30)
        if st.returncode != 0:
            return "unreusable"
        items = st.stdout.split("\0")
        pairs = []  # (hash label, repo-root-relative path)
        i = 0
        while i < len(items):
            e = items[i]
            i += 1
            if not e:
                continue
            xy, p = e[:2], e[3:]
            pairs.append((e, p))
            if "R" in xy or "C" in xy:
                # -z renames/copies carry the ORIGIN path as the next NUL field
                if i < len(items) and items[i]:
                    pairs.append(("orig:" + items[i], items[i]))
                i += 1
        if len(pairs) > 200:
            return "unreusable"
        h = hashlib.sha256()
        h.update(head.stdout.strip().encode())
        for label, p in sorted(pairs):
            h.update(b"\x00"); h.update(label.encode())
            fp_abs = os.path.join(toplevel, p)
            if os.path.isfile(fp_abs):
                h.update(b"\x01"); h.update(sha_file(fp_abs).encode())
        return h.hexdigest()
    except (subprocess.TimeoutExpired, OSError):
        return "unreusable"

def kb_fingerprint():
    """The whole .mega-sdd/knowledge-base/ md tree (relpath + content sha, sorted).
    vault_oqs resolves OQ citations + its KB inventory there, and kb_output
    resolves depends_on against sibling KB files — a KB delete/rename/archival
    must invalidate their reuse even though the validated doc itself is
    unchanged (round finding: sha-only keys laundered a stale PASS). Pure fs
    walk, no git — untracked KB files count the same as tracked ones."""
    base = os.path.join(cwd, ".mega-sdd", "knowledge-base")
    pairs = []
    for root, _dirs, files in os.walk(base):
        for fn in files:
            if fn.endswith(".md"):
                fp_abs = os.path.join(root, fn)
                pairs.append((os.path.relpath(fp_abs, base), sha_file(fp_abs)))
    h = hashlib.sha256()
    for rel, s in sorted(pairs):
        h.update(b"\x00"); h.update(rel.encode()); h.update(b"\x01"); h.update(s.encode())
    return h.hexdigest()

fp = code_fingerprint()
kbfp = kb_fingerprint()

ledger = None
if not fresh:
    try:
        d = json.load(open(ledger_path, encoding="utf-8"))
        if isinstance(d, dict) and d.get("schema") == 1 and d.get("plugin_version") == pv \
                and isinstance(d.get("families"), dict):
            ledger = d
    except (OSError, ValueError):
        ledger = None

lfp = (ledger or {}).get("code_fingerprint", "")
lkbfp = (ledger or {}).get("kb_fingerprint", "")
fams = (ledger or {}).get("families", {})

# Purity classes (round-corrected): kb_output resolves depends_on against
# SIBLING KB files, so it keys on the KB-tree fingerprint too; vault_oqs reads
# the KB inventory + cited paths + sibling vault.json + (defensively) the code
# tree. Only the four families below are verdict = f(file bytes) alone.
PURE = ["kb_markers", "kb_flows", "vault_flows", "fsd_slots"]
KB_COUPLED = ["kb_output"]
ENV_COUPLED = ["vault_oqs"]

# TAB is IFS-whitespace in bash, so consecutive tabs COLLAPSE under `read` and
# empty middle fields would shift later columns left (round finding: the
# sibling sha landed in the rc column and reuse died). "-" is the explicit
# empty-field placeholder; no cell is ever the empty string.
def cell(v):
    return v if v else "-"

for fam in PURE + KB_COUPLED + ENV_COUPLED:
    try:
        files = [l for l in open(os.path.join(tmpd, "files." + fam), encoding="utf-8").read().split("\n") if l.strip()]
    except OSError:
        files = []
    known = fams.get(fam, {}) if isinstance(fams.get(fam, {}), dict) else {}
    with open(os.path.join(tmpd, "decisions." + fam), "w", encoding="utf-8") as out:
        for p in files:
            sha = sha_file(p)
            rel = os.path.relpath(p, cwd)
            sib = sha_file(os.path.join(os.path.dirname(p), "vault.json")) if fam in ENV_COUPLED else ""
            ent = known.get(rel)
            ok = (ledger is not None and isinstance(ent, dict) and bool(sha)
                  and ent.get("sha") == sha
                  and str(ent.get("rc")) in ("0", "1")
                  and str(ent.get("status", "")) in ("PASS", "WARN", "FAIL"))
            if ok and fam in (KB_COUPLED + ENV_COUPLED):
                ok = (lkbfp == kbfp)
            if ok and fam in ENV_COUPLED:
                ok = (fp != "unreusable" and lfp == fp and ent.get("sibling_sha", "") == sib)
            if ok:
                out.write("\t".join([p, sha, "REUSE", str(ent["rc"]), str(ent["status"]), cell(sib)]) + "\n")
            else:
                out.write("\t".join([p, sha, "RUN", "-", "-", cell(sib)]) + "\n")

with open(os.path.join(tmpd, "meta.json"), "w", encoding="utf-8") as f:
    json.dump({"code_fingerprint": fp, "kb_fingerprint": kbfp,
               "ledger_written_at": (ledger or {}).get("written_at", "")}, f)
PYEOF
then
  # Decision phase failed -> fail CLOSED toward re-running everything: rebuild
  # every decisions file as all-RUN rows ("-" placeholder cells; the "-" sha
  # decodes to empty in the ledger writer, keeping fallback rows unledgered).
  for _fam in vault_oqs fsd_slots kb_output kb_markers kb_flows vault_flows; do
    : > "${TMPD}/decisions.${_fam}"
    while IFS= read -r _p; do
      [ -n "$_p" ] && printf '%s\t-\tRUN\t-\t-\t-\n' "$_p" >> "${TMPD}/decisions.${_fam}"
    done < "${TMPD}/files.${_fam}"
  done
fi
if [ -f "${TMPD}/meta.json" ]; then
  _MC=$(<"${TMPD}/meta.json")
  [[ "$_MC" =~ \"ledger_written_at\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && LEDGER_TS="${BASH_REMATCH[1]}"
fi

# Severity lattice for the per-file worst-of (fixes the last-writer-wins slot
# masking in THIS truth pass; aggregate-only keeps its documented slot-read).
_sev() { case "$1" in FAIL|ERROR) echo 3 ;; WARN) echo 2 ;; PASS) echo 1 ;; *) echo 0 ;; esac; }
_slot_status() { # zero-spawn status read from a state slot just written
  local c=""
  [ -f "$1" ] && c=$(<"$1")
  if [[ "$c" =~ \"status\"[[:space:]]*:[[:space:]]*\"([A-Z_]+)\" ]]; then echo "${BASH_REMATCH[1]}"; else echo ""; fi
}
# run_family <family> <validator-script> <state-slot-basename> [<extra-flag>]
# Iterates the family's decision rows; REUSE folds the recorded verdict (no
# spawn), RUN invokes the validator and captures the fresh slot status. Sets
# FAM_RC (worst numeric rc), FAM_ST (severity-max status), FAM_HAS (0/1), and
# appends result rows for the ledger writer.
run_family() {
  local fam="$1" script="$2" slot="$3" extra="${4:-}"
  local p sha dec rc st sib
  FAM_RC=0; FAM_ST=""; FAM_HAS=0
  [ -f "${TMPD}/decisions.${fam}" ] || return 0
  while IFS=$'\t' read -r p sha dec rc st sib; do
    [ -n "$p" ] || continue
    # decode the "-" empty-cell placeholder (TAB-collapse guard — see the
    # decision phase): no decisions cell is ever the empty string on disk.
    [ "$sha" = "-" ] && sha=""
    [ "$rc" = "-" ] && rc=""
    [ "$st" = "-" ] && st=""
    [ "$sib" = "-" ] && sib=""
    FAM_HAS=1
    if [ "$dec" = "REUSE" ]; then
      REUSED_FILES=$((REUSED_FILES + 1))
    else
      # shellcheck disable=SC2086
      rc=$(run_validator "$script" $extra --cwd="$CWD" --file-path="$p" --quiet)
      [ "$rc" = "SKIP" ] && continue
      RERUN_FILES=$((RERUN_FILES + 1))
      st=$(_slot_status "${CWD}/.mega-sdd/${slot}")
      if [ -z "$st" ]; then
        # non-zero -> FAIL (parity with the pre-S1 int(rc)!=0 mapping — an
        # "ERROR" here would not flip overall the way a FAIL always did)
        if [ "$rc" = "0" ]; then st="PASS"; else st="FAIL"; fi
      fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$p" "${sha:--}" "${rc:--}" "${st:--}" "${sib:--}" >> "${TMPD}/results.${fam}"
    case "$rc" in
      *[!0-9]*|"") ;;
      *) [ "$rc" -gt "$FAM_RC" ] && FAM_RC=$rc ;;
    esac
    if [ "$(_sev "$st")" -gt "$(_sev "$FAM_ST")" ]; then FAM_ST="$st"; fi
  done < "${TMPD}/decisions.${fam}"
  return 0
}

# --- Phase 1: Run existing validators ---
# Each validator writes its own state file under <cwd>/.mega-sdd/
# We invoke each with --cwd and --quiet, capturing exit codes.
# Validators excluded:
#   validate-scope-flag.sh    — needs user-message stdin (not batch-able)
#   validate-starterkit-metrics.sh — needs transcript context
#   validate-handoff-yaml.sh  — needs chat output text (Stop-hook context)

run_validator() {
  local script="$1"
  local script_path="${SCRIPT_DIR}/${script}"
  shift
  if [ ! -x "$script_path" ]; then
    echo "SKIP"
    return 0
  fi
  bash "$script_path" "$@" >/dev/null 2>&1
  echo $?
}

# 1a. Project-wide validators (no --file-path needed)
V1_RC=$(run_validator "validate-handoff-binding-units.sh" --cwd="$CWD" --quiet)

# 1b. Unit-spec validator — ONE project-wide invocation (S1). The validator
# already scans ALL units on every call (S5 GU-HOOK-1; --file-path only picks
# the focal unit for the exit code), so the old per-unit loop was N invocations
# x N units each = O(n^2). Without --file-path the merged exit code IS the
# worst-of that loop reconstructed. Never ledger-reused: it is env-coupled
# (A1 anchors resolve against the code tree) and O(1) spawns needs no ledger.
if [ -s "${TMPD}/files.unit_baseline" ]; then
  V2_RC=$(run_validator "validate-unit-spec.sh" --cwd="$CWD" --quiet)
  [ "$V2_RC" != "SKIP" ] && RERUN_FILES=$((RERUN_FILES + 1))
else
  V2_RC="SKIP"
fi

# 1c. Per-bolt-report validator (never ledger-reused: git-history-dependent).
# Round fold DL-I1: same severity-max masking fix as the ledgered families —
# the single-slot state file only holds the LAST report's verdict.
V3_WORST=0
V3_HAS_FILES=0
for bf in $(find "${CWD}/.mega-sdd/vaults" -path "*/bolts/U-*/bolt-report.md" -not -path "*/.archived/*" 2>/dev/null); do
  V3_HAS_FILES=1
  rc=$(run_validator "validate-bolt-artifacts.sh" --cwd="$CWD" --file-path="$bf" --quiet)
  [ "$rc" = "SKIP" ] && continue
  RERUN_FILES=$((RERUN_FILES + 1))
  [ "$rc" -gt "$V3_WORST" ] 2>/dev/null && V3_WORST=$rc
  st=$(_slot_status "${CWD}/.mega-sdd/.bolt-artifacts-state.json")
  if [ -z "$st" ]; then [ "$rc" = "0" ] && st="PASS" || st="FAIL"; fi
  if [ "$(_sev "$st")" -gt "$(_sev "$V3_ST")" ]; then V3_ST="$st"; fi
done
V3_RC=$( [ "$V3_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V3_WORST" )

# 1c2. Orphan-bolt-commit scan (repo-wide; catches bolt commits whose
# bolt-report.md was never written — the per-file loop above cannot see a
# file that does not exist). Writes .bolt-orphans-state.json.
V3B_RC=$(run_validator "validate-bolt-artifacts.sh" --cwd="$CWD" --orphan-scan --quiet)

# 1d. Per-vault-doc OQ validator (S1: decision-driven; env-coupled family —
# reuse requires the code fingerprint + sibling vault.json sha to match too).
# No SKIP-on-empty here (pre-S1 semantics: defaults to rc 0 with no files).
run_family "vault_oqs" "validate-vault-oqs.sh" ".vault-oqs-state.json"
V4_RC=$FAM_RC; V4_ST=$FAM_ST

# 1e. Per-FSD-file slot validator (S1: decision-driven, pure family)
run_family "fsd_slots" "validate-fsd-slots.sh" ".fsd-slots-state.json"
V5_RC=$( [ "$FAM_HAS" -eq 0 ] && echo "SKIP" || echo "$FAM_RC" ); V5_ST=$FAM_ST

# 1f. Per-KB-domain-file validator (R2) (S1: decision-driven, pure family)
run_family "kb_output" "validate-kb.sh" ".kb-output-state.json" "--surface=output"
V7_RC=$( [ "$FAM_HAS" -eq 0 ] && echo "SKIP" || echo "$FAM_RC" ); V7_ST=$FAM_ST

# 1f2. Per-KB-domain-file marker-accuracy validator (Track 1) (S1: pure family)
run_family "kb_markers" "validate-kb.sh" ".kb-markers-state.json" "--surface=markers"
V7M_RC=$( [ "$FAM_HAS" -eq 0 ] && echo "SKIP" || echo "$FAM_RC" ); V7M_ST=$FAM_ST

# 1f3. Per-KB-domain-file flow format validator (Mermaid consistency) (S1: pure)
run_family "kb_flows" "validate-kb.sh" ".kb-flows-state.json" "--surface=flows"
V7F_RC=$( [ "$FAM_HAS" -eq 0 ] && echo "SKIP" || echo "$FAM_RC" ); V7F_ST=$FAM_ST

# 1f3b. Per-vault-flows Mermaid mandate (04-flows.md bodies) (S1: pure family)
run_family "vault_flows" "validate-kb.sh" ".vault-flows-state.json" "--surface=vault-flows"
V7VF_RC=$( [ "$FAM_HAS" -eq 0 ] && echo "SKIP" || echo "$FAM_RC" ); V7VF_ST=$FAM_ST

# 1f4. Starterkit pattern conformance validator
V7S_RC=$(run_validator "validate-starterkit-conformance.sh" --cwd="$CWD" --quiet)

# 1f5. Per-KB-domain-file citation resolution validator (Track 1 expansion)
V7C_WORST=0
V7C_HAS_FILES=0
# Legacy-root detection is DELEGATED to the validator: it carries the richer M4
# auto-detect (every §8.5 manifest + _source/ / legacy/ probes). Passing an empty
# --legacy-root lets that run instead of a narrower duplicate here shadowing it.
for kf in $(find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null); do
  V7C_HAS_FILES=1
  rc=$(run_validator "validate-kb.sh" --surface=citations --cwd="$CWD" --file-path="$kf" --legacy-root="" --quiet)
  [ "$rc" = "SKIP" ] && continue
  RERUN_FILES=$((RERUN_FILES + 1))
  [ "$rc" -gt "$V7C_WORST" ] 2>/dev/null && V7C_WORST=$rc
  # Round fold DL-I1: severity-max across files (single-slot masking fix)
  st=$(_slot_status "${CWD}/.mega-sdd/.kb-citations-state.json")
  if [ -z "$st" ]; then [ "$rc" = "0" ] && st="PASS" || st="FAIL"; fi
  if [ "$(_sev "$st")" -gt "$(_sev "$V7C_ST")" ]; then V7C_ST="$st"; fi
done
V7C_RC=$( [ "$V7C_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V7C_WORST" )

# 1i. Constitution enforcement validator (R5)
V10_RC=$(run_validator "validate-constitution.sh" --cwd="$CWD" --quiet)

# 1j. Constitution clause propagation (C — finding-driven enforcement)
V11_RC=$(run_validator "validate-constitution-propagation.sh" --cwd="$CWD" --quiet)

# 1k. Codebase-map schema validation (R6)
V12_RC=$(run_validator "validate-codebase-map.sh" --cwd="$CWD" --quiet)

# 1l. Reuse-duplication advisory heuristic (R8 — ADVISORY; never blocks; NOT in PreToolUse)
REUSE_DUP_OUTPUT=""
if [ -x "${SCRIPT_DIR}/validate-reuse-duplication.sh" ]; then
  REUSE_DUP_OUTPUT=$(bash "${SCRIPT_DIR}/validate-reuse-duplication.sh" "$CWD" 2>&1 || true)
fi

# --- Phase 2: Vault internal consistency checks (NEW — R7 folded into R1) ---
VAULT_CONSISTENCY=$(CWD="$CWD" python3 <<'PYEOF'
import json
import os
import re
import glob

cwd = os.environ["CWD"]
results = []

for vj_path in sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "vault.json"))):
    if "/.archived/" in vj_path:
        continue
    vault_dir = os.path.dirname(vj_path)
    vault_name = os.path.basename(vault_dir)

    try:
        with open(vj_path) as f:
            vj = json.load(f)
    except Exception as e:
        results.append({"vault": vault_name, "checks": [
            {"check": "vault_json_parse", "status": "FAIL", "detail": str(e)}
        ]})
        continue

    checks = []

    # NOTE (W5): the entities/OQ count-sync checks below are INTENTIONAL
    # independent cross-checks of derive-vault-json.sh — they parse the md
    # with a DIFFERENT, looser grammar than _lib/vault_md.py and are the
    # detectors for deriver-parser bugs. Do NOT cull them as "tautological
    # now that vault.json is script-derived".
    # v7 Fase 3 dual-layout read (one minor cycle): layout-2 file first.
    def _vdoc(v2_name, legacy_name):
        p2 = os.path.join(vault_dir, v2_name)
        return p2 if os.path.isfile(p2) else os.path.join(vault_dir, legacy_name)
    LAYOUT2 = os.path.isfile(os.path.join(vault_dir, "vault.md"))

    # Check 1: vault.json entities count vs data-model doc entity blocks
    dm_path = _vdoc("model.md", "03-data-model.md")
    if os.path.isfile(dm_path):
        dm_content = open(dm_path).read()
        entity_patterns = len(re.findall(
            r"^(?:Table|table)\s+\w|^##\s+(?:Entity|entity):?\s+\w",
            dm_content, re.MULTILINE
        ))
        vj_entities = len(vj.get("entities", []))
        if entity_patterns > 0 and abs(vj_entities - entity_patterns) > 2:
            checks.append({"check": "entities_count_sync", "status": "WARN",
                          "detail": f"vault.json={vj_entities} entities; {os.path.basename(dm_path)}~={entity_patterns} (delta>{2})"})
        else:
            checks.append({"check": "entities_count_sync", "status": "PASS",
                          "detail": f"vault.json={vj_entities}, md~={entity_patterns}"})
    else:
        checks.append({"check": "entities_count_sync", "status": "SKIP",
                       "detail": "data-model doc (model.md / 03-data-model.md) not found"})

    # Check 2: OQ count in vault.json vs the authored OQ surface's tag count
    # (legacy: the 00-index roll-up; layout-2: constraints.md, the sole home)
    idx_path = _vdoc("constraints.md", "00-index.md")
    if os.path.isfile(idx_path):
        idx_content = open(idx_path).read()
        oq_tags = set(re.findall(r"\bOQ-[A-Z]+-(?:P\d+-)?(?:\d+)\b", idx_content))
        vj_oqs = len(vj.get("open_questions", []))
        if len(oq_tags) > 0 and abs(vj_oqs - len(oq_tags)) > 3:
            checks.append({"check": "oq_count_sync", "status": "WARN",
                          "detail": f"vault.json={vj_oqs} OQs; {os.path.basename(idx_path)}={len(oq_tags)} unique tags (delta>{3})"})
        else:
            checks.append({"check": "oq_count_sync", "status": "PASS",
                          "detail": f"vault.json={vj_oqs}, idx_tags={len(oq_tags)}"})

    # Check 3: required vault files present (per layout)
    if LAYOUT2:
        expected_files = ["vault.md", "model.md", "flows.md",
                          "constraints.md", "vault.json"]
    else:
        expected_files = ["00-index.md", "01-overview.md", "02-architecture.md",
                          "03-data-model.md", "04-flows.md", "05-decisions.md",
                          "06-constraints.md", "vault.json"]
    missing = [ef for ef in expected_files if not os.path.isfile(os.path.join(vault_dir, ef))]
    if missing:
        checks.append({"check": "vault_files_complete", "status": "FAIL",
                       "detail": f"missing: {', '.join(missing)}"})
    else:
        checks.append({"check": "vault_files_complete", "status": "PASS",
                       "detail": f"all {len(expected_files)} files present"})

    # Check 4: source_documents paths exist (WARN only — paths may be relative to project root)
    for sd in vj.get("source_documents", []):
        sd_path = sd.get("path", "")
        if sd_path:
            abs1 = os.path.join(cwd, sd_path)
            if not os.path.exists(abs1) and not os.path.exists(sd_path):
                checks.append({"check": "source_doc_exists", "status": "WARN",
                               "detail": f"source_documents path not found: {sd_path}"})

    # Check 5: flows count sync
    flows_path = _vdoc("flows.md", "04-flows.md")
    if os.path.isfile(flows_path):
        flows_content = open(flows_path).read()
        flow_ids = set(re.findall(r"\bF-[A-Z]-\d{3}\b", flows_content))
        vj_flows = len(vj.get("flows", []))
        if len(flow_ids) > 0 and abs(vj_flows - len(flow_ids)) > 2:
            checks.append({"check": "flows_count_sync", "status": "WARN",
                          "detail": f"vault.json={vj_flows} flows; {os.path.basename(flows_path)}={len(flow_ids)} flow IDs"})
        else:
            checks.append({"check": "flows_count_sync", "status": "PASS",
                          "detail": f"vault.json={vj_flows}, md_ids={len(flow_ids)}"})

    results.append({"vault": vault_name, "checks": checks})

print(json.dumps(results))
PYEOF
)

fi  # end of FULL vs AGGREGATE_ONLY branch

# --- Phase 3: Aggregate and write report ---
ANALYZE_OUTPUT=$(CWD="$CWD" TS="$TS" VAULT_CONSISTENCY="$VAULT_CONSISTENCY" REUSE_DUP_OUTPUT="$REUSE_DUP_OUTPUT" \
  V1_RC="$V1_RC" V2_RC="$V2_RC" V3_RC="$V3_RC" V3B_RC="$V3B_RC" V4_RC="$V4_RC" V5_RC="$V5_RC" V7_RC="$V7_RC" \
  V7M_RC="$V7M_RC" V7F_RC="$V7F_RC" V7VF_RC="$V7VF_RC" V7S_RC="$V7S_RC" V7C_RC="$V7C_RC" V10_RC="$V10_RC" V11_RC="$V11_RC" V12_RC="$V12_RC" \
  V3_ST="$V3_ST" V4_ST="$V4_ST" V5_ST="$V5_ST" V7_ST="$V7_ST" V7M_ST="$V7M_ST" V7F_ST="$V7F_ST" V7VF_ST="$V7VF_ST" V7C_ST="$V7C_ST" \
  SCOPE_MODE="$SCOPE_MODE" REUSED_FILES="$REUSED_FILES" RERUN_FILES="$RERUN_FILES" LEDGER_TS="$LEDGER_TS" \
  python3 <<'PYEOF'
import json
import os

cwd = os.environ["CWD"]
ts = os.environ["TS"]

try:
    vault_consistency = json.loads(os.environ.get("VAULT_CONSISTENCY", "[]"))
except Exception:
    vault_consistency = []

# Advisory: reuse-duplication heuristic output (plain text; never flips overall)
reuse_dup_output = os.environ.get("REUSE_DUP_OUTPUT", "").strip()

# S1 scope metadata (spec 2026-08-03-semantic-scoped-validation.md)
scope_mode = os.environ.get("SCOPE_MODE", "aggregate")
reused_files = int(os.environ.get("REUSED_FILES", "0") or 0)
rerun_files = int(os.environ.get("RERUN_FILES", "0") or 0)
ledger_ts = os.environ.get("LEDGER_TS", "")

# Map validator results. "st" = the per-file severity-max computed by the FULL-mode
# family loops (fresh + reused files) — when present it DRIVES the boundary status
# (fixes the last-writer-wins state-slot masking); the slot then supplies detail only.
validator_results = {
    "binding_units_handoff": {"rc": os.environ["V1_RC"], "state_file": ".validation-blockers.json"},
    "unit_spec": {"rc": os.environ["V2_RC"], "state_file": ".unit-spec-state.json"},
    "bolt_artifacts": {"rc": os.environ["V3_RC"], "state_file": ".bolt-artifacts-state.json", "st": os.environ.get("V3_ST", "")},
    "bolt_orphans": {"rc": os.environ.get("V3B_RC", "STATE_FILE"), "state_file": ".bolt-orphans-state.json"},
    "vault_oqs": {"rc": os.environ["V4_RC"], "state_file": ".vault-oqs-state.json", "st": os.environ.get("V4_ST", "")},
    "fsd_slots": {"rc": os.environ["V5_RC"], "state_file": ".fsd-slots-state.json", "st": os.environ.get("V5_ST", "")},
    "kb_output": {"rc": os.environ["V7_RC"], "state_file": ".kb-output-state.json", "st": os.environ.get("V7_ST", "")},
    "kb_markers": {"rc": os.environ["V7M_RC"], "state_file": ".kb-markers-state.json", "st": os.environ.get("V7M_ST", "")},
    "kb_flows": {"rc": os.environ["V7F_RC"], "state_file": ".kb-flows-state.json", "st": os.environ.get("V7F_ST", "")},
    "vault_flows": {"rc": os.environ["V7VF_RC"], "state_file": ".vault-flows-state.json", "st": os.environ.get("V7VF_ST", "")},
    "starterkit_conformance": {"rc": os.environ["V7S_RC"], "state_file": ".starterkit-conformance-state.json"},
    "kb_citations": {"rc": os.environ["V7C_RC"], "state_file": ".kb-citations-state.json", "st": os.environ.get("V7C_ST", "")},
    "constitution": {"rc": os.environ["V10_RC"], "state_file": ".constitution-state.json"},
    "constitution_propagation": {"rc": os.environ["V11_RC"], "state_file": ".constitution-propagation-state.json"},
    "codebase_map": {"rc": os.environ["V12_RC"], "state_file": ".codebase-map-state.json"},
    # v4 — KEPT hard-block code-delivery gates (enforced at PreToolUse on execute-bolts);
    # surfaced here read-only from their PostToolUse state files so /analyze is a true
    # pre-flight of what WILL block bolts (a FAIL here flips overall, as it should).
    "flow_coverage": {"rc": "STATE_FILE", "state_file": ".flow-coverage-state.json"},
    "sibling_consistency": {"rc": "STATE_FILE", "state_file": ".sibling-consistency-state.json"},
    "cross_cutting_registration": {"rc": "STATE_FILE", "state_file": ".cross-cutting-state.json"},
    "ui_quality": {"rc": "STATE_FILE", "state_file": ".ui-quality-blockers.json"},
    # v4 Phase 2 (Hybrid) — code-delivery checks DEMOTED from PreToolUse hard-block to
    # advisory. Surfaced here read-only from their PostToolUse-written state files (no
    # re-run); "NOT_RUN" until a real chain writes them. They no longer block execute-bolts.
    "dispatch_prompt (advisory)": {"rc": "STATE_FILE", "state_file": ".dispatch-prompt-state.json"},
    "fanout_parity (advisory)": {"rc": "STATE_FILE", "state_file": ".fanout-parity-state.json"},
    "ui_deferral (advisory)": {"rc": "STATE_FILE", "state_file": ".ui-deferral-state.json"},
    "vault_flow_staging (advisory)": {"rc": "STATE_FILE", "state_file": ".vault-flow-staging-state.json"},
}

# Read state files for detail
boundaries = {}
for name, vr in validator_results.items():
    rc = vr["rc"]
    sf = vr["state_file"]
    sf_path = os.path.join(cwd, ".mega-sdd", sf)

    if rc == "SKIP":
        boundaries[name] = {"status": "SKIP", "state_file": sf, "detail": "no applicable files found"}
        continue

    # AGGREGATE-ONLY mode: rc == "STATE_FILE" → read status from state file, not exit code
    if rc == "STATE_FILE":
        if not os.path.isfile(sf_path):
            boundaries[name] = {"status": "NOT_RUN", "state_file": sf, "detail": "no state file (validator not yet run this chain)"}
            continue
        try:
            with open(sf_path) as f:
                data = json.load(f)
            status = data.get("status", "UNKNOWN")
            summary = data.get("summary", {})
            detail = ("; ".join(f"{k}={v}" for k, v in list(summary.items())[:4])
                      if isinstance(summary, dict) else str(summary)[:120] if isinstance(summary, str)
                      else str(data.get("halt_type", ""))[:120])
        except Exception as e:
            status = "ERROR"
            detail = f"state file parse error: {e}"
        boundaries[name] = {"status": status, "state_file": sf, "detail": detail}
        continue

    status = "PASS" if int(rc) == 0 else "FAIL"
    st_override = vr.get("st", "")

    detail = ""
    if os.path.isfile(sf_path):
        try:
            with open(sf_path) as f:
                data = json.load(f)
            sf_status = data.get("status", status)
            if st_override:
                # S1: the family loop's per-file severity-max is authoritative —
                # the single-slot state file only holds the LAST-validated file's
                # verdict, which masked any earlier FAIL/WARN in the family.
                status = st_override
            else:
                status = sf_status
            summary = data.get("summary", {})
            if isinstance(summary, dict):
                detail = "; ".join(f"{k}={v}" for k, v in list(summary.items())[:4])
            elif isinstance(summary, str):
                detail = summary[:120]
            else:
                detail = str(data.get("halt_type", ""))[:120]
        except Exception as e:
            detail = f"state file parse error: {e}"
    elif st_override:
        status = st_override
        detail = "per-file worst-of (state slot absent — files reused)"
    else:
        detail = f"validator ran (exit={rc}) but no state file written"

    boundaries[name] = {"status": status, "state_file": sf, "detail": detail}

# Compute overall. Advisory (v4 Phase 2 Hybrid) boundaries are surfaced in the report
# but never flip overall to a blocking FAIL — an advisory FAIL contributes WARN at most.
all_statuses = [b["status"] for name, b in boundaries.items() if b["status"] != "SKIP" and "(advisory)" not in name]
advisory_statuses = [b["status"] for name, b in boundaries.items() if "(advisory)" in name and b["status"] not in ("SKIP", "NOT_RUN")]
vault_statuses = []
for vc in vault_consistency:
    for chk in vc.get("checks", []):
        if chk["status"] != "SKIP":
            vault_statuses.append(chk["status"])

has_fail = "FAIL" in all_statuses or "FAIL" in vault_statuses
# `or "WARN" in all_statuses` so a KB-grounding WARN (the kb citations
# surface, 0-cites) also flips the overall banner to WARN — it was
# only rendered in the per-boundary row, not the summary. Never escalates a FAIL.
has_warn = ("WARN" in vault_statuses) or ("FAIL" in advisory_statuses) \
    or ("WARN" in advisory_statuses) or ("WARN" in all_statuses)
overall = "FAIL" if has_fail else ("WARN" if has_warn else "PASS")

# Write .analyze-state.json
state = {
    "status": overall,
    "analyzed_at": ts,
    "scope_mode": scope_mode,
    "reused_files": reused_files,
    "rerun_files": rerun_files,
    "boundaries": boundaries,
    "vault_consistency": vault_consistency,
    "validators_run": len([s for s in all_statuses]),
    "validators_total": len(validator_results),
    "validators_pass": all_statuses.count("PASS"),
    "validators_fail": all_statuses.count("FAIL"),
    "validators_skip": len([b for b in boundaries.values() if b["status"] == "SKIP"]),
}

state_path = os.path.join(cwd, ".mega-sdd", ".analyze-state.json")
with open(state_path, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

# Write CONSISTENCY-REPORT.md
lines = []
lines.append(f"# Consistency Report — {ts}")
lines.append("")
lines.append(f"**Overall: {overall}**")
lines.append(f"**Validators: {state['validators_pass']} PASS / {state['validators_fail']} FAIL / {state['validators_skip']} SKIP of {state['validators_total']}**")
if scope_mode == "scoped":
    since = f" (unchanged since {ledger_ts})" if ledger_ts else ""
    lines.append(f"**Scope: per-file validators — {rerun_files} re-run, {reused_files} reused{since}; "
                 f"project-wide validators always re-run. `--fresh` forces a full re-run.**")
elif scope_mode == "fresh":
    lines.append("**Scope: full re-run (`--fresh`).**")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Boundary Checks (existing validators)")
lines.append("")
lines.append("| Boundary | Status | State File | Detail |")
lines.append("|---|---|---|---|")
for name, b in sorted(boundaries.items()):
    lines.append(f"| {name} | **{b['status']}** | `{b['state_file']}` | {b['detail']} |")
lines.append("")
lines.append("## Vault Internal Consistency")
lines.append("")
for vc in vault_consistency:
    vault_name = vc.get("vault", "unknown")
    lines.append(f"### Vault: `{vault_name}`")
    lines.append("")
    checks = vc.get("checks", [])
    if checks:
        lines.append("| Check | Status | Detail |")
        lines.append("|---|---|---|")
        for chk in checks:
            lines.append(f"| {chk['check']} | **{chk['status']}** | {chk['detail']} |")
    lines.append("")

lines.append("## Advisory: Reuse-Duplication Heuristic")
lines.append("")
lines.append("*Non-blocking. Surfaced for review only — does not affect overall status.*")
lines.append("")
if reuse_dup_output:
    for dup_line in reuse_dup_output.splitlines():
        lines.append(f"    {dup_line}")
else:
    lines.append("    [reuse-dup] not run (aggregate-only mode or validator absent)")
lines.append("")
lines.append("---")
lines.append("")
lines.append(f"*Generated by mega-sdd analyze at {ts}*")

report_path = os.path.join(cwd, ".mega-sdd", "CONSISTENCY-REPORT.md")
with open(report_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print(json.dumps({"state_path": state_path, "report_path": report_path, "overall": overall}))
PYEOF
)

if [ "$QUIET" -eq 0 ]; then
  echo "$ANALYZE_OUTPUT"
fi

# ── S1: ledger write (FULL mode only — the single writer; aggregate-only never
# touches it). Records every per-file verdict computed or legitimately reused
# this run + the unit_baseline shas for lint-units --changed-only. ─────────────
if [ "$AGGREGATE_ONLY" -eq 0 ] && [ -n "${TMPD:-}" ]; then
  TMPD="$TMPD" CWD="$CWD" TS="$TS" PLUGIN_VERSION="$PLUGIN_VERSION" python3 <<'PYEOF' || true
import hashlib, json, os

tmpd = os.environ["TMPD"]; cwd = os.environ["CWD"]
ts = os.environ["TS"]; pv = os.environ.get("PLUGIN_VERSION", "")

def sha_file(p):
    h = hashlib.sha256()
    try:
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return ""

try:
    meta = json.load(open(os.path.join(tmpd, "meta.json"), encoding="utf-8"))
except (OSError, ValueError):
    meta = {}

FAMS = ["kb_output", "kb_markers", "kb_flows", "vault_flows", "fsd_slots", "vault_oqs"]
families = {}
for fam in FAMS:
    m = {}
    try:
        rows = open(os.path.join(tmpd, "results." + fam), encoding="utf-8").read().split("\n")
    except OSError:
        rows = []
    for row in rows:
        if not row.strip():
            continue
        parts = row.split("\t")
        if len(parts) < 5:
            continue
        # "-" is the empty-cell placeholder (TAB-collapse guard)
        p, sha, rc, st, sib = ("" if x == "-" else x for x in parts[:5])
        if not sha:
            continue  # decision-phase fallback rows carry no sha -> never ledgered
        try:
            rci = int(rc)
        except ValueError:
            continue
        ent = {"sha": sha, "rc": rci, "status": st}
        if fam == "vault_oqs":
            ent["sibling_sha"] = sib
        m[os.path.relpath(p, cwd)] = ent
    families[fam] = m

unit_baseline = {}
try:
    ufiles = [l for l in open(os.path.join(tmpd, "files.unit_baseline"), encoding="utf-8").read().split("\n") if l.strip()]
except OSError:
    ufiles = []
for p in ufiles:
    h = sha_file(p)
    if h:
        unit_baseline[os.path.relpath(p, cwd)] = h

ledger = {
    "schema": 1,
    "plugin_version": pv,
    "code_fingerprint": meta.get("code_fingerprint", "unreusable"),
    "kb_fingerprint": meta.get("kb_fingerprint", ""),
    "written_at": ts,
    "families": families,
    "unit_baseline": unit_baseline,
}
with open(os.path.join(cwd, ".mega-sdd", ".analyze-freshness.json"), "w", encoding="utf-8") as f:
    json.dump(ledger, f, indent=2)
    f.write("\n")
PYEOF
fi

OVERALL=$(echo "$ANALYZE_OUTPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('overall','ERROR'))" 2>/dev/null)
case "$OVERALL" in
  PASS|WARN) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
