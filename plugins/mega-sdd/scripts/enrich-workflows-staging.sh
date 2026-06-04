#!/usr/bin/env bash
# enrich-workflows-staging.sh — semantic-depth enrichment helper (v3.71.0+).
#
# WHY: a vault is already in flight (phase 3) and its KB workflows were extracted
# BEFORE staged-input capture existed — they flattened multi-step wizards into one
# input list. A full re-extract is expensive. This helper retro-fits the staged-input
# semantic on the CURRENT KB without re-running extraction: it re-reads the cited
# legacy `_source` files, detects the staged-input (wizard / maker->checker) pattern,
# and PROPOSES a `## 3a` `stages:` block per workflow for human review.
#
# WALKING-SKELETON SCOPE: --semantic=staged-input ONLY (the one dimension proven this
# iter). conditional / role-matrix / transition-guard dimensions follow later.
#
# TWO-PHASE (never auto-apply — per discipline "jangan auto-apply tanpa konfirmasi"):
#   propose (default): write <vault>/ENRICHMENT-PROPOSALS.md with a candidate stages:
#                      block per workflow. Nothing is mutated.
#   --apply:           patch each accepted KB workflow file in-place (insert ## 3a +
#                      stages:) AND propagate into any vault 04-flows flow whose
#                      `_kb_source` already cites that KB file (deterministic match).
#
# CONSUMES the kb_flow_staging_missing advisory: when .kb-flows-state.json carries it,
# the helper surfaces "validator pre-flagged" in the report (the advisory drives action).
#
# Usage:
#   enrich-workflows-staging.sh --vault=<path> --legacy-root=<path> --semantic=staged-input [--kb=<path>] [--apply] [--quiet]
# Exit: 0 = ok (proposals written / applied), 2 = error/bad args.

set -uo pipefail

VAULT=""
LEGACY_ROOT=""
SEMANTIC="staged-input"
KB=""
APPLY=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT="${arg#*=}" ;;
    --legacy-root=*) LEGACY_ROOT="${arg#*=}" ;;
    --semantic=*) SEMANTIC="${arg#*=}" ;;
    --kb=*) KB="${arg#*=}" ;;
    --apply) APPLY=1 ;;
    --quiet) QUIET=1 ;;
  esac
done

if [ -z "$VAULT" ]; then echo '{"status":"ERROR","detail":"--vault=<path> required"}' >&2; exit 2; fi
if [ "$SEMANTIC" != "staged-input" ]; then
  echo "{\"status\":\"ERROR\",\"detail\":\"--semantic=$SEMANTIC not supported; walking-skeleton supports only staged-input\"}" >&2
  exit 2
fi

VAULT="$VAULT" LEGACY_ROOT="$LEGACY_ROOT" KB="$KB" APPLY="$APPLY" QUIET="$QUIET" python3 -W ignore::DeprecationWarning <<'PYEOF'
import json, os, re, sys, glob

vault = os.environ["VAULT"]
legacy_root = os.environ.get("LEGACY_ROOT", "")
kb_override = os.environ.get("KB", "")
apply = os.environ.get("APPLY", "0") == "1"
quiet = os.environ.get("QUIET", "0") == "1"


def read_text(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except Exception:
        return None


def has_stages_block(text):
    if not text:
        return False
    return bool(re.search(r"^\s*stages:\s*$", text, re.MULTILINE)) and ("stage_id:" in text)


# ── Resolve project root from the vault path, then the KB root ────────────────
# vault is .../.mega-sdd/vaults/<slug>[ -bound]; project root is the dir holding .mega-sdd/
def project_root_of(vp):
    p = os.path.abspath(vp)
    while p and p != "/":
        if os.path.basename(os.path.dirname(p)) == ".mega-sdd" and os.path.basename(p) == "vaults":
            return os.path.dirname(os.path.dirname(p))
        p = os.path.dirname(p)
    # fallback: walk up until a .mega-sdd/ is found
    p = os.path.abspath(vp)
    while p and p != "/":
        if os.path.isdir(os.path.join(p, ".mega-sdd")):
            return p
        p = os.path.dirname(p)
    return os.path.abspath(os.path.join(vp, "..", "..", ".."))


proj = project_root_of(vault)
kb_root = kb_override
if not kb_root:
    for cand in (
        os.path.join(proj, ".mega-sdd", "knowledge-base"),
        os.path.join(proj, "docs", "knowledge-base"),
        os.path.join(proj, "docs", "mega-sdd", "knowledge-base"),
        os.path.join(proj, "old-reference", "knowledge-base"),
    ):
        if os.path.isdir(cand):
            kb_root = cand
            break

result = {"status": "OK", "semantic": "staged-input", "mode": "apply" if apply else "propose",
          "kb_root": kb_root, "legacy_root": legacy_root, "validator_preflagged": [],
          "candidates": [], "proposals_file": None, "applied": []}

if not kb_root or not os.path.isdir(kb_root):
    result["status"] = "ERROR"
    result["detail"] = "no knowledge-base found (probe .mega-sdd/knowledge-base/ etc.); pass --kb=<path>"
    print(json.dumps(result, indent=2))
    sys.exit(2)

# ── Auto-discover the legacy root when --legacy-root is omitted (for /mega-sdd:auto) ──
# Probe order: (1) the KB README's recorded "source codebase path", (2) common legacy dirs
# under the project root. Lets orchestrate-flow call this without hand-feeding the path.
if not legacy_root:
    probes = []
    readme = os.path.join(kb_root, "README.md")
    rt = read_text(readme) or ""
    if rt:
        m = re.search(r"source\s+codebase\s+path[:\s*]+`?([^\s`\n]+)`?", rt, re.IGNORECASE)
        if m:
            cand = m.group(1)
            probes.append(cand if os.path.isabs(cand) else os.path.join(proj, cand))
    probes += [os.path.join(proj, d) for d in ("old-reference", "legacy", "legacy-src", "src-legacy", "_legacy")]
    legacy_root = next((p for p in probes if os.path.isdir(p)), "")
    result["legacy_root"] = legacy_root
    result["legacy_root_auto_discovered"] = bool(legacy_root)

# ── Consume the kb_flow_staging_missing advisory (advisory drives action) ─────
adv_state = os.path.join(proj, ".mega-sdd", ".kb-flows-state.json")
if os.path.isfile(adv_state):
    try:
        st = json.load(open(adv_state))
        for a in st.get("advisories", []):
            if a.get("halt_type") == "kb_flow_staging_missing":
                result["validator_preflagged"].append(st.get("checked_file"))
    except Exception:
        pass


# ── Legacy staged-input (wizard) detection ────────────────────────────────────
# Tech-agnostic-leaning signals for server-rendered multi-step forms. Returns
# (is_staged, [(step_label, [fields...]), ...], signals[]).
STEP_COND_RE = re.compile(
    r"""(?:if|elseif|else\s+if|case|when)\b[^\n{:]*?\b(?:step|stage|page|wizard_step|current_step)\b[^\n{:]*?
        (?:==|===|:|=>|\bis\b)?\s*['"]?(?P<val>[\w-]+)['"]?""",
    re.IGNORECASE | re.VERBOSE,
)
HIDDEN_STEP_RE = re.compile(r"""name\s*=\s*['"](?:step|stage|page|wizard_step)['"]""", re.IGNORECASE)
REQ_STEP_RE = re.compile(r"""\$?_?(?:POST|GET|REQUEST|request|params|input)\b\s*[\[\(]\s*['"](?:step|stage|page)['"]""", re.IGNORECASE)
FIELD_READ_RE = re.compile(r"""\$?_?(?:POST|GET|REQUEST|request|params|input)\b\s*[\[\(]\s*['"](?P<f>[\w]+)['"]""", re.IGNORECASE)
FORM_RE = re.compile(r"<form\b", re.IGNORECASE)


def detect_staging(text):
    signals = []
    if HIDDEN_STEP_RE.search(text):
        signals.append("hidden step/stage field")
    if REQ_STEP_RE.search(text):
        signals.append("step/stage request param")
    n_forms = len(FORM_RE.findall(text))
    if n_forms >= 2:
        signals.append(f"{n_forms} <form> blocks")
    step_conds = list(STEP_COND_RE.finditer(text))
    if len(step_conds) >= 2:
        signals.append(f"{len(step_conds)} stage-conditional branches")

    is_staged = bool(signals) and (len(step_conds) >= 2 or n_forms >= 2 or
                                   (HIDDEN_STEP_RE.search(text) and REQ_STEP_RE.search(text)))
    if not is_staged:
        return False, [], signals

    # Segment by step-conditional positions; allocate fields read within each segment.
    stages = []
    if len(step_conds) >= 2:
        bounds = [m.start() for m in step_conds] + [len(text)]
        for i in range(len(step_conds)):
            seg = text[bounds[i]:bounds[i + 1]]
            label = step_conds[i].group("val") or str(i + 1)
            fields = []
            for fm in FIELD_READ_RE.finditer(seg):
                f = fm.group("f")
                if f.lower() in ("step", "stage", "page", "wizard_step", "current_step"):
                    continue
                if f not in fields:
                    fields.append(f)
            stages.append((label, fields))
    else:
        # forms-only signal: can't segment fields confidently -> single best-effort 2-stage skeleton
        stages = [("1", []), ("2", [])]
    return True, stages, signals


# ── Citation extraction: file:line tokens in the KB workflow file ─────────────
CITE_RE = re.compile(r"`?([\w./-]+\.(?:php|inc|phtml|js|jsx|ts|tsx|vue|py|rb|java|go|cs|blade\.php|html|twig|erb))`?\s*:\s*\d+")


def cited_legacy_files(kb_text):
    files = []
    for m in CITE_RE.finditer(kb_text):
        f = m.group(1)
        if f not in files:
            files.append(f)
    return files


def resolve_legacy(token):
    cands = []
    if legacy_root:
        cands.append(os.path.join(legacy_root, token))
        cands.append(os.path.join(legacy_root, os.path.basename(token)))
    cands.append(token)
    for c in cands:
        if os.path.isfile(c):
            return c
    # last resort: basename glob under legacy_root
    if legacy_root and os.path.isdir(legacy_root):
        hits = glob.glob(os.path.join(legacy_root, "**", os.path.basename(token)), recursive=True)
        if hits:
            return hits[0]
    return None


def build_stages_yaml(stages, legacy_disp):
    lines = ["stages:"]
    role_guess = ["Maker", "Checker", "Approver", "Operator"]
    for i, (label, fields) in enumerate(stages):
        sid = f"S{i + 1}"
        nxt = f"S{i + 2}" if i + 1 < len(stages) else "DONE"
        role = role_guess[i] if i < len(role_guess) else f"Stage{i + 1}"
        fl = ", ".join(f'"{f}"' for f in fields) if fields else ""
        lines.append(f'  - stage_id: "{sid}"')
        lines.append(f'    stage_name: "Stage {label}"')
        lines.append(f'    actor_role: "{role}"   # REVIEW: confirm the actual role')
        lines.append(f'    input_fields: [{fl}]   # REVIEW: confirm field-to-stage allocation')
        lines.append(f'    transitions: [{{ to: "{nxt}", trigger: "submit", conditions: [] }}]   # REVIEW: confirm trigger/guards')
        lines.append(f'    _source: ["{legacy_disp}"]')
    return "\n".join(lines)


# ── Scan KB workflows lacking a stages: block ─────────────────────────────────
kb_workflow_files = sorted(glob.glob(os.path.join(kb_root, "20-workflows", "*.md")))
# also workflow-classified 10-domains
for d in sorted(glob.glob(os.path.join(kb_root, "10-domains", "*.md"))):
    t = read_text(d) or ""
    if re.search(r"^classification:\s*workflow", t, re.MULTILINE):
        kb_workflow_files.append(d)

proposals = []
for kb_file in kb_workflow_files:
    kb_text = read_text(kb_file)
    if kb_text is None or has_stages_block(kb_text):
        continue  # already staged
    legacy_tokens = cited_legacy_files(kb_text)
    staged_any = False
    all_stages = []
    all_signals = []
    used_legacy = []
    for tok in legacy_tokens:
        lp = resolve_legacy(tok)
        if not lp:
            continue
        ltext = read_text(lp)
        if not ltext:
            continue
        is_staged, stages, signals = detect_staging(ltext)
        if is_staged:
            staged_any = True
            all_signals.extend(signals)
            used_legacy.append(tok)
            if len(stages) > len(all_stages):
                all_stages = stages
    cand = {
        "kb_file": os.path.relpath(kb_file, proj),
        "kb_workflow_ref": os.path.relpath(kb_file, kb_root),
        "staged_detected": staged_any,
        "signals": sorted(set(all_signals)),
        "legacy_cited": legacy_tokens,
        "legacy_used": used_legacy,
    }
    if staged_any:
        cand["proposed_stages_yaml"] = build_stages_yaml(all_stages, used_legacy[0] if used_legacy else "<legacy file:line>")
        proposals.append(cand)
    result["candidates"].append(cand)

# ── PROPOSE: write ENRICHMENT-PROPOSALS.md ────────────────────────────────────
proposals_path = os.path.join(vault, "ENRICHMENT-PROPOSALS.md")
if not apply:
    os.makedirs(vault, exist_ok=True)
    out = []
    out.append("# Staged-input enrichment proposals\n")
    out.append("> Generated by `mega-sdd:enrich-semantics --semantic=staged-input`. "
               "These are CANDIDATES for human review — nothing has been applied. "
               "Edit field-to-stage allocation / roles / triggers, then re-run with `--apply`.\n")
    if result["validator_preflagged"]:
        out.append(f"> `validate-kb-flows.sh` pre-flagged staging-missing: "
                   f"{', '.join(p for p in result['validator_preflagged'] if p)}\n")
    if not proposals:
        out.append("\n_No staged-input pattern detected in cited legacy `_source` files. "
                   "Either the workflows are genuinely single-step, the `--legacy-root` is wrong, "
                   "or the legacy uses an unrecognized multi-step idiom (extend detect_staging())._\n")
    for p in proposals:
        out.append(f"\n## {p['kb_workflow_ref']}\n")
        out.append(f"**Signals:** {', '.join(p['signals'])}")
        out.append(f"**Legacy source(s):** {', '.join(p['legacy_used'])}\n")
        out.append("**Proposed `## 3a. Staged inputs` block** (review + edit before `--apply`):\n")
        out.append("```yaml")
        out.append(p["proposed_stages_yaml"])
        out.append("```\n")
    content = "\n".join(out) + "\n"
    try:
        with open(proposals_path, "w") as f:
            f.write(content)
        result["proposals_file"] = os.path.relpath(proposals_path, proj)
    except Exception as e:
        result["status"] = "ERROR"
        result["detail"] = f"could not write proposals: {e}"
    result["proposal_count"] = len(proposals)
    result["next_action"] = (
        f"Review {result.get('proposals_file')}, edit each stages: block (roles, field allocation, "
        f"triggers), then re-run with --apply to patch the KB + propagate to vault 04-flows."
        if proposals else
        "No staged workflows proposed. Confirm --legacy-root and that the workflows are truly multi-step."
    )
    if not quiet:
        print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "OK" else 2)

# ── APPLY: patch KB in-place + propagate to vault flows by _kb_source ──────────
applied = []
for p in proposals:
    kb_file = os.path.join(proj, p["kb_file"])
    kb_text = read_text(kb_file)
    if kb_text is None or has_stages_block(kb_text):
        continue
    block = ("## 3a. Staged inputs (multi-step workflows)\n\n"
             "<!-- enriched by mega-sdd:enrich-semantics --apply; REVIEW roles/fields/triggers -->\n\n"
             "```yaml\n" + p["proposed_stages_yaml"] + "\n```\n\n")
    # insert before `## 4. ` if present, else before `## 8. `, else append
    m4 = re.search(r"^## 4\.\s", kb_text, re.MULTILINE)
    m8 = re.search(r"^## 8\.\s", kb_text, re.MULTILINE)
    anchor = m4 or m8
    if anchor:
        new_text = kb_text[:anchor.start()] + block + kb_text[anchor.start():]
    else:
        new_text = kb_text.rstrip() + "\n\n" + block
    try:
        with open(kb_file, "w") as f:
            f.write(new_text)
        applied.append({"kb_file": p["kb_file"], "patched": True})
    except Exception as e:
        applied.append({"kb_file": p["kb_file"], "patched": False, "error": str(e)})
        continue

    # propagate: any vault 04-flows flow whose `_kb_source` cites this KB workflow
    wf_ref = p["kb_workflow_ref"]
    for flows_doc in glob.glob(os.path.join(proj, ".mega-sdd", "vaults", "*", "04-flows.md")):
        ftext = read_text(flows_doc)
        if not ftext or wf_ref not in ftext:
            continue
        if has_stages_block(ftext):
            continue  # already has staging somewhere; leave for human review
        # naive propagation: append a Stages block note near the _kb_source line's flow.
        # Conservative — we annotate rather than surgically insert, to avoid corrupting flows.
        stages_note = ("\n\n<!-- enrich-semantics: staged-input proposed for " + wf_ref +
                       " — verify placement under the correct flow, then remove this note -->\n"
                       "**Stages**:\n```yaml\n" + p["proposed_stages_yaml"] + "\n```\n")
        try:
            with open(flows_doc, "a") as f:
                f.write(stages_note)
            applied.append({"vault_flows": os.path.relpath(flows_doc, proj), "propagated": True})
        except Exception as e:
            applied.append({"vault_flows": os.path.relpath(flows_doc, proj), "propagated": False, "error": str(e)})

result["applied"] = applied
result["applied_count"] = len([a for a in applied if a.get("patched") or a.get("propagated")])
result["next_action"] = ("KB patched + propagated where _kb_source matched. Re-run "
                         "/mega-sdd:generate-units only after reviewing the inserted stages: blocks. "
                         "Re-save 04-flows.md to let validate-vault-flow-staging confirm non-loss.")
if not quiet:
    print(json.dumps(result, indent=2))
sys.exit(0)
PYEOF
exit $?
