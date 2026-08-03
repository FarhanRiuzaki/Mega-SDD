#!/usr/bin/env bash
# audit-domain-rules.sh — R4: domain-rule GAP detector (Mode B — KB-sourced only).
#
# Compares KB regulatory/operational rules against vault 06-constraints.md
# to detect MISSING compliance rules the vault doesn't address.
#
# Scope: ONLY runs when KB 40-business-rules/ exists. No KB → exit 0 skip.
# Walking-skeleton: extract [VERIFIED] regulatory rule headings from KB,
# check each against vault constraints for keyword overlap.
#
# Inputs: --cwd=<project> [--quiet]
# Outputs:
#   <cwd>/.mega-sdd/.domain-rules-state.json
#   <cwd>/.mega-sdd/RULE-GAP-REPORT.md (when gaps found)
# Exit: 0=no gaps/skip, 1=gaps found, 2=error

set -uo pipefail

CWD=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --quiet) QUIET=1 ;;
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


if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ ! -d "${CWD}/.mega-sdd" ]; then exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.domain-rules-state.json"
REPORT_FILE="${CWD}/.mega-sdd/RULE-GAP-REPORT.md"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown-ts")

RESULT=$(CWD="$CWD" TS="$TS" python3 <<'PYEOF'
import json
import os
import re
import glob

cwd = os.environ["CWD"]
ts = os.environ["TS"]

# Check KB exists
kb_rules_dir = os.path.join(cwd, ".mega-sdd", "knowledge-base", "40-business-rules")
if not os.path.isdir(kb_rules_dir):
    print(json.dumps({"status": "SKIP", "detail": "no KB 40-business-rules/ directory", "gaps": [], "rules_checked": 0}))
    raise SystemExit(0)

# Read regulatory rules + operational rules
rule_files = sorted(glob.glob(os.path.join(kb_rules_dir, "*.md")))
if not rule_files:
    print(json.dumps({"status": "SKIP", "detail": "no rule files in 40-business-rules/", "gaps": [], "rules_checked": 0}))
    raise SystemExit(0)

# Extract regulatory rule entries from KB
# Strategy: find section headers (## N.) and [VERIFIED] lines with rule descriptions
kb_rules = []
saw_reg_content = False
for rf in rule_files:
    try:
        content = open(rf).read()
    except Exception:
        continue

    # Regulatory signal must come from RULE CONTENT, not the file's own heading
    # ("# Regulatory Rules" is the always-emitted stub title) nor an N/A placeholder.
    _reg_re = re.compile(r"\bregulat|\bcompliance\b|mandated by|\bstatutory\b|\bHIPAA\b|"
                         r"\bGDPR\b|\bPCI(?:[- ]?DSS)?\b|\bSOX\b|\bBasel\b|\bMiFID\b|"
                         r"\bFERPA\b|\bCCPA\b|\bAML\b|\bKYC\b", re.IGNORECASE)
    for _ln in content.split("\n"):
        _s = _ln.strip()
        if not _s or _s.startswith("#") or _s.startswith("_None") or _s.startswith("_N/A"):
            continue
        if _reg_re.search(_ln):
            saw_reg_content = True
            break

    rf_name = os.path.basename(rf)

    # Extract table rows with regulatory identifiers (e.g., PBI, POJK, UCP, SLIK, SIMODIS)
    # These are the key regulatory terms to check against vault constraints
    reg_patterns = [
        r"(?:PBI|POJK|UCP|URR|SLIK|SIMODIS|SIUL|SKBDN|Normatif|OJK|BI\s+(?:Antasena|regulation))",
    ]

    # Find [VERIFIED] lines that mention regulatory frameworks
    for line in content.split("\n"):
        if "[VERIFIED]" not in line and "[LOCKED]" not in line:
            continue
        for pat in reg_patterns:
            m = re.search(pat, line, re.IGNORECASE)
            if m:
                # Extract the regulatory identifier and surrounding context
                # Take up to 100 chars around the match for context
                start = max(0, m.start() - 50)
                end = min(len(line), m.end() + 50)
                context = line[start:end].strip()
                # Extract key terms (nouns/identifiers of 3+ chars)
                key_terms = set(re.findall(r"\b[A-Z][A-Za-z]{2,}\b|\b[A-Z]{2,}\b", context))
                # Filter out common stop words
                stop = {"The", "This", "That", "For", "And", "Not", "But", "Are", "Was", "Has", "VERIFIED", "INFERRED", "LOCKED", "OPEN"}
                key_terms -= stop
                if key_terms:
                    kb_rules.append({
                        "source_file": rf_name,
                        "regulatory_id": m.group(0),
                        "key_terms": sorted(key_terms),
                        "context": context[:120],
                    })
                break  # one match per line is enough

# Deduplicate by regulatory_id
seen_reg_ids = set()
unique_rules = []
for r in kb_rules:
    rid = r["regulatory_id"]
    if rid not in seen_reg_ids:
        seen_reg_ids.add(rid)
        unique_rules.append(r)

# Honesty-fix (M5): the built-in reg_patterns are ID-banking-specific (PBI/POJK/
# OJK/UCP/…). If they parse 0 rules from a KB that plainly carries regulatory
# content, do NOT emit a green PASS — that is false compliance assurance for every
# non-ID-banking domain (GDPR/HIPAA/PCI/…). Emit WARN and point at supplying a
# regulatory pack. WARN, not FAIL: nothing is proven missing; the detector simply
# does not cover this domain.
# Gate on regulatory CONTENT, not the FILENAME: `regulatory-rules.md` is emitted as
# a stub for every KB, so keying on its presence cry-wolf WARNs on non-regulatory
# domains. saw_reg_content requires an actual regulatory signal in the rule text.
if not unique_rules and saw_reg_content:
    print(json.dumps({
        "status": "WARN",
        "rules_checked": 0,
        "rules_covered": 0,
        "rules_gap": 0,
        "gaps": [],
        "detail": ("0 regulatory rules parsed, but the KB carries regulatory content — the "
                   "built-in acronym set (PBI/POJK/OJK/UCP/…) is ID-banking-specific; supply a "
                   "regulatory pack for this domain"),
        "summary": "0 rules parsed from a KB with regulatory content — acronym set is domain-specific; no false 'all clear'",
    }))
    raise SystemExit(0)

# Read ALL vault content (not just 06-constraints — R4 hardening)
# Regulatory terms may be addressed in decisions (05), architecture (02),
# flows (04), constitution, or overview (01). Limiting to 06 causes false gaps.
vault_content = ""
vault_file_patterns = [
    os.path.join(cwd, ".mega-sdd", "vaults", "*", "0[0-6]-*.md"),
    os.path.join(cwd, ".mega-sdd", "vaults", "*", "constitution.md"),
    # Widened from *-bound to * — covers canonical <vault>/ AND legacy <vault>-bound/.
    os.path.join(cwd, ".mega-sdd", "vaults", "*", "0[0-6]-*.md"),
    os.path.join(cwd, ".mega-sdd", "vaults", "*", "constitution.md"),
    os.path.join(cwd, ".mega-sdd", "vaults", "*", "binding.md"),
    os.path.join(cwd, ".mega-sdd", "vaults", "binding*.md"),
]
vault_files_read = set()
for pattern in vault_file_patterns:
    for vf in sorted(glob.glob(pattern)):
        if "/.archived/" in vf:
            continue
        if vf in vault_files_read:
            continue
        vault_files_read.add(vf)
        try:
            vault_content += open(vf).read() + "\n"
        except Exception:
            continue

# Check each KB rule against vault constraints
gaps = []
covered = []
for rule in unique_rules:
    terms = rule["key_terms"]
    if not terms:
        continue
    # Count how many key terms appear in vault constraints
    matches = sum(1 for t in terms if re.search(r"\b" + re.escape(t) + r"\b", vault_content, re.IGNORECASE))
    coverage = matches / len(terms) if terms else 0

    if coverage < 0.3:  # Less than 30% key term overlap → gap
        gaps.append({
            "rule_id": f"RULE-GAP-{len(gaps) + 1}",
            "regulatory_id": rule["regulatory_id"],
            "source_file": rule["source_file"],
            "key_terms": rule["key_terms"],
            "terms_matched": matches,
            "terms_total": len(terms),
            "coverage": round(coverage, 2),
            "context": rule["context"],
        })
    else:
        covered.append({
            "regulatory_id": rule["regulatory_id"],
            "coverage": round(coverage, 2),
        })

status = "FAIL" if gaps else "PASS"
result = {
    "status": status,
    "rules_checked": len(unique_rules),
    "rules_covered": len(covered),
    "rules_gap": len(gaps),
    "gaps": gaps[:20],  # cap at 20 for readability
    "summary": f"{len(covered)}/{len(unique_rules)} regulatory rules addressed in vault; {len(gaps)} candidate gaps for review (may be covered in sections the keyword scan missed)",
}

# Write RULE-GAP-REPORT.md if gaps exist
if gaps:
    report_path = os.path.join(cwd, ".mega-sdd", "RULE-GAP-REPORT.md")
    lines = [
        f"# Domain Rule Gap Report — {ts}",
        "",
        f"**Status: {len(gaps)} candidate gaps for review** ({len(covered)} of {len(unique_rules)} regulatory rules addressed in vault)",
        "",
        "> **Note:** gaps are candidates, not confirmed missing rules. The keyword scan may miss",
        "> coverage expressed in different terminology. Review each gap against the full vault.",
        "",
        "---",
        "",
        "## Candidate Gaps (KB rules with <30% keyword overlap in vault)",
        "",
        "| # | Regulatory ID | Source | Key Terms | Coverage | Context |",
        "|---|---|---|---|---|---|",
    ]
    for g in gaps:
        terms_str = ", ".join(g["key_terms"][:5])
        lines.append(f"| {g['rule_id']} | {g['regulatory_id']} | {g['source_file']} | {terms_str} | {g['coverage']:.0%} | {g['context'][:60]}... |")
    lines.append("")
    lines.append("## Covered Rules")
    lines.append("")
    lines.append(f"{len(covered)} rules have ≥30% key term overlap with vault constraints.")
    lines.append("")
    lines.append("---")
    lines.append(f"*Generated by mega-sdd audit-domain-rules.sh at {ts}*")

    with open(report_path, "w") as f:
        f.write("\n".join(lines) + "\n")
    result["report_path"] = report_path

print(json.dumps(result))
PYEOF
)

echo "$RESULT" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null

if [ "$QUIET" -eq 0 ]; then echo "$RESULT"; fi

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)
case "$STATUS" in
  PASS|SKIP|WARN) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
