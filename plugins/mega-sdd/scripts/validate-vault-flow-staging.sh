#!/usr/bin/env bash
# validate-vault-flow-staging.sh — [HOOK-VALIDATE] staged-input non-loss across
# the KB → vault boundary (v3.71.0+, semantic-depth — staged-input walking skeleton).
#
# THE REGRESSION THIS CATCHES:
#   A legacy multi-step workflow (wizard / maker->checker / multi-page form) stages
#   its inputs (fields A,B,C at step 1; D,E,F at step 2). extract-intelligence captures
#   that staging in the KB workflow's `## 3a` `stages:` block. generate-intent is supposed
#   to PRESERVE it verbatim into the vault `04-flows.md` flow. When it instead FLATTENS to
#   one input list, the downstream bolt builds ONE form where the legacy had a multi-step
#   wizard. (The captured trade-finance regression.)
#
# DETERMINISTIC MATCH (no fuzzy title matching):
#   Each vault flow that derives from a KB workflow carries a `_kb_source: [20-workflows/<f>.md]`
#   back-reference (the OQ-ID-class stable identifier per vault-contract.md §stages-propagation).
#   This validator FOLLOWS that link:
#     - vault flow has `_kb_source` -> resolve the cited KB workflow file
#     - cited KB workflow HAS a `stages:` block AND the vault flow does NOT -> vault_flow_staging_drop
#   Single halt_type, single purpose -> status==FAIL gating is invariant-compliant (Iter-79 #4).
#
# BACKWARD-COMPATIBLE BY CONSTRUCTION (migration-safe):
#   - No KB present                  -> SKIP (nothing to compare).
#   - Vault flow has no `_kb_source`  -> SKIP that flow (legacy vault / PRD-only flow).
#   - KB workflow has no `stages:`    -> no drop (nothing to preserve).
#   Pre-staging vaults therefore NEVER trip this gate.
#
# Inputs:  --cwd=<project> [--quiet]
# Outputs: writes <cwd>/.mega-sdd/.vault-flow-staging-state.json (OVERWRITE-NOT-APPEND)
# Exit:    0=PASS/SKIP, 1=FAIL (>=1 drop), 2=error
# Gated by: PreToolUse Branch 14 (blocks mega-sdd:execute-bolts on status==FAIL).

set -uo pipefail

CWD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

# Resolve project root (walk UP to outermost .mega-sdd/ parent — same class-bug fix
# as sibling validators, so state files land canonically).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

[ -z "$CWD" ] && exit 2
[ ! -d "$CWD/.mega-sdd/vaults" ] && exit 0   # no vaults -> nothing to check (PASS-skip)

STATE_FILE="${CWD}/.mega-sdd/.vault-flow-staging-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 -W ignore::DeprecationWarning <<'PYEOF'
import json, os, re, sys, glob

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"


def read_text(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except Exception:
        return None


def has_stages_block(text):
    """Robust detection: requires BOTH a `stages:` line AND a `stage_id:` token,
    so prose that merely mentions the word 'stages' does not count."""
    if not text:
        return False
    return bool(re.search(r"^\s*stages:\s*$", text, re.MULTILINE)) and ("stage_id:" in text)


# ── Resolve the KB root (first existing, per knowledge-base-schema.md probe order) ──
KB_PROBE = [
    os.path.join(cwd, ".mega-sdd", "knowledge-base"),
    os.path.join(cwd, "docs", "knowledge-base"),
    os.path.join(cwd, "docs", "mega-sdd", "knowledge-base"),
    os.path.join(cwd, "old-reference", "knowledge-base"),
]
kb_root = next((d for d in KB_PROBE if os.path.isdir(d)), None)

issues = []
advisories = []   # v3.71.0: non-blocking vault-internal signal (never flips status)
vault_summary = {}
_DECISION_RE = re.compile(r"\b(approve|reject|review|confirm|verify|authorize|endorse)\b", re.IGNORECASE)
_MAKER_CHECKER_RE = re.compile(r"\bmaker\b.{0,80}\b(checker|approver|reviewer|confirmer)\b", re.IGNORECASE | re.DOTALL)

# A KB-source reference can be written several ways; extract any *.md path token that
# follows a `_kb_source` marker on a line.
KB_SOURCE_LINE = re.compile(r"_kb_source\b", re.IGNORECASE)
MD_TOKEN = re.compile(r"([\w./-]+\.md)")


def resolve_kb_path(token):
    """Resolve a `_kb_source` token (e.g. '20-workflows/foo.md') against the KB root.
    Falls back to a basename glob under the KB root if the relative path misses."""
    if not kb_root:
        return None
    cand = os.path.join(kb_root, token)
    if os.path.isfile(cand):
        return cand
    # token may already include 'knowledge-base/...' or be absolute-ish — try basename
    base = os.path.basename(token)
    hits = glob.glob(os.path.join(kb_root, "**", base), recursive=True)
    return hits[0] if hits else None


vault_dirs = sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*")))
vault_dirs = [d for d in vault_dirs
              if os.path.isdir(d) and not d.endswith("-bound") and "/.archived/" not in d]

for vault_dir in vault_dirs:
    vault_name = os.path.basename(vault_dir)
    flows_doc = os.path.join(vault_dir, "04-flows.md")
    if not os.path.isfile(flows_doc):
        continue
    content = read_text(flows_doc)
    if content is None:
        continue

    # Segment into flow entries: each starts at a `### F-...` heading and runs until
    # the next `### ` or `## ` heading.
    heads = [m for m in re.finditer(r"^###\s+(F-[A-Za-z]+-\d+[^\n]*)", content, re.MULTILINE)]
    flows_checked = 0
    flows_with_kb_source = 0
    drops_here = 0

    for i, h in enumerate(heads):
        start = h.start()
        # segment end = next ### OR next ## (section boundary), whichever comes first
        nxt_h = heads[i + 1].start() if i + 1 < len(heads) else len(content)
        sec_m = re.search(r"^##\s", content[h.end():], re.MULTILINE)
        nxt_sec = (h.end() + sec_m.start()) if sec_m else len(content)
        end = min(nxt_h, nxt_sec)
        seg = content[start:end]
        flow_label = h.group(1).strip()
        flow_id_m = re.match(r"(F-[A-Za-z]+-\d+)", flow_label)
        flow_id = flow_id_m.group(1) if flow_id_m else flow_label
        flows_checked += 1

        # find _kb_source token(s) in this segment
        kb_tokens = []
        for ln in seg.split("\n"):
            if KB_SOURCE_LINE.search(ln):
                kb_tokens.extend(MD_TOKEN.findall(ln))
        vault_flow_has_stages = has_stages_block(seg)
        # Advisory arm (v3.71.0): the DOMINANT flatten case — a flow that LOOKS like a multi-step
        # workflow (maker->checker / >=2 decision steps) but has NEITHER a stages: block NOR a
        # _kb_source back-reference (generate-intent ignored staging wholesale, OR a PRD-only
        # multi-step flow with no KB). The blocking arm below cannot see this (it needs _kb_source),
        # so surface it as WARN — never status-flipping. Vault-internal heuristic; simple flows
        # (no workflow signal) never trip it, so no false-stop.
        if not kb_tokens:
            _decisions = len(_DECISION_RE.findall(seg))
            # Language-invariant signal: a Mermaid stateDiagram IS a multi-step state
            # machine. The English _DECISION_RE / _MAKER_CHECKER_RE arms miss an
            # Indonesian workflow entirely (menyetujui/menolak, pembuat→pemeriksa), so a
            # flattened non-English workflow drawn as a stateDiagram would slip past —
            # keying on the frozen diagram-type name catches it regardless of language.
            _has_state_diagram = bool(re.search(r"\bstateDiagram(?:-v2)?\b", seg))
            if (_decisions >= 2 or bool(_MAKER_CHECKER_RE.search(seg)) or _has_state_diagram) and not vault_flow_has_stages:
                advisories.append({
                    "halt_type": "vault_flow_staging_missing",
                    "vault": vault_name, "flow_id": flow_id, "severity": "advisory",
                    "detail": ("vault flow looks like a multi-step workflow (maker->checker / >=2 decision "
                               "steps) but has no stages: block AND no _kb_source back-reference — staging "
                               "likely flattened wholesale (or PRD-only multi-step). Non-blocking signal."),
                    "suggested_fix": ("author a **Stages** block (+ _kb_source if KB-derived) per "
                                      "vault-contract.md §stages-propagation, or run enrich-semantics"),
                })
            continue  # no back-reference -> blocking drop-check N/A; advisory handled above
        flows_with_kb_source += 1

        # any cited KB workflow that HAS stages while the vault flow does NOT -> drop
        for tok in kb_tokens:
            kb_path = resolve_kb_path(tok)
            if not kb_path:
                continue  # cited KB file not found (KB absent / moved) -> skip (no false drop)
            kb_text = read_text(kb_path)
            if has_stages_block(kb_text) and not vault_flow_has_stages:
                drops_here += 1
                issues.append({
                    "halt_type": "vault_flow_staging_drop",
                    "vault": vault_name,
                    "flow_id": flow_id,
                    "kb_source": os.path.relpath(kb_path, cwd),
                    "detail": (f"vault flow {flow_id} cites KB workflow with a `stages:` block "
                               f"but dropped it — staging flattened (single-form risk)"),
                    "suggested_fix": ("copy the `stages:` block from the cited KB §3a verbatim into this "
                                      "flow's `**Stages**` block + emit the Mermaid stateDiagram "
                                      "(see vault-contract.md §stages-propagation), then re-save 04-flows.md"),
                    "severity": "blocking",
                })
                break  # one drop per flow is enough

    vault_summary[vault_name] = {
        "flows_checked": flows_checked,
        "flows_with_kb_source": flows_with_kb_source,
        "staging_drops": drops_here,
    }

status = "FAIL" if issues else "PASS"
report = {
    "status": status,
    "validator": "validate-vault-flow-staging.sh",
    "kb_root": os.path.relpath(kb_root, cwd) if kb_root else None,
    "summary": {
        "drop_count": len(issues),
        "advisory_count": len(advisories),
        "vaults": vault_summary,
    },
    "issues": issues,
    "advisories": advisories,   # v3.71.0 — non-blocking (flatten-without-backref / PRD-only)
    "next_action": (
        (f"{len(advisories)} flow(s) look multi-step but carry no staging AND no _kb_source "
         f"(advisory — likely wholesale flatten). Consider enrich-semantics."
         if advisories else
         "Staged-input preserved across KB->vault boundary (or no staged workflows present).")
        if status == "PASS"
        else f"{len(issues)} vault flow(s) dropped a `stages:` block that the cited KB workflow carried. "
             f"Restore the stages: block per vault-contract.md §stages-propagation, then re-save 04-flows.md."
    ),
}

try:
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
        f.write("\n")
except Exception:
    sys.exit(2)

if not quiet:
    print(json.dumps(report, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF
exit $?
