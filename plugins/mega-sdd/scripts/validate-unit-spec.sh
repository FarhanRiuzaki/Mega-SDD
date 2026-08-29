#!/usr/bin/env bash
# validate-unit-spec.sh — Phase B slice B.3 [PostToolUse-validate].
#
# Validates 4 unit-spec integrity halts on Write|Edit of unit files:
#   - unit_underspecified         (required frontmatter fields missing)
#   - hard_rule_unparseable       (Hard Rule v1 grammar line unparseable)
#   - starterkit_rule_citation_missing (starterkit-derived rule lacks citation)
#   - acceptance_path_unowned      (acceptance_test runs a path no unit owns and
#                                   that does not exist — spec 2026-08-29 Fase 4;
#                                   gated in hooks/pre-tool-use, leg "acceptance-path")
#
# Per attestation:
#   #12 unit_underspecified: target_files re-derive C1; acceptance_test C2 escalate
#       (this validator detects target_files presence; acceptance_test missing for
#        non-trivial units flagged as escalate)
#   #13 hard_rule_unparseable: re-emit C1; DROP C2 escalate after 2 attempts
#       (this validator detects first attempt; retry tracking via state file)
#
# Detection-only at hook layer; auto-fix is generate-units's responsibility.
#
# S5 GU-HOOK-1: the state file reflects ALL units PROJECT-WIDE on every run —
# it was a single slot overwritten per unit write, so only the LAST-written
# unit was ever gated (last-writer-wins masked verify_grounding_untrusted and
# render_test_missing for N-1 units of every multi-unit run). --file-path now
# selects the FOCAL unit for stdout/exit-code purposes only; the state always
# merges every unit. Without --file-path the validator scans all units (the
# execute-bolts PreToolUse gate uses this as its re-derive entry point).
#
# Inputs: --cwd=<project> [--file-path=<unit-file>]
# Outputs: JSON report stdout; writes .mega-sdd/.unit-spec-state.json (merged)
# Exit: 0=PASS, 1=FAIL (focal file when --file-path given, else merged), 2=error.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
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


if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd required" >&2; exit 2
fi
if [ -n "$FILE_PATH" ]; then
  if [ ! -f "$FILE_PATH" ]; then
    exit 0
  fi
  # Quick path filter: only validate unit files. Accept the bound layout
  # (*-bound/units/...) AND the plain vault layout (*/vaults/*/units/U-*.md) so the
  # render-test check (slice D) reaches non-bound vaults too — consistent with the
  # PostToolUse dispatch broadening in commit e945991 (Task A).
  case "$FILE_PATH" in
    *-bound/units/U-*.md|*-bound/units/U-*/unit.md) ;;
    *.mega-sdd/vaults/*/units/U-*.md|*.mega-sdd/vaults/*/units/U-*/unit.md) ;;
    *) exit 0 ;;
  esac
fi

STATE_FILE="${CWD}/.mega-sdd/.unit-spec-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: state dir" >&2; exit 2; }

# ── Pack-driven render-test signatures (code-delivery slice D, tech-agnostic) ──
# The detail-view glob is read from the active framework pack `## Test patterns`
# section via the shared resolver — NEVER hardcoded. A pack that omits the section
# (or omits detail_view_glob) → the render check SKIPs gracefully; the other
# unit-spec checks still run. Adding a stack = adding a pack, never editing this.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
TEST_PATTERNS_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  TEST_PATTERNS_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Test patterns" --quiet 2>/dev/null) || TEST_PATTERNS_SECTION=""
fi

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" \
TEST_PATTERNS_SECTION="$TEST_PATTERNS_SECTION" python3 <<'PYEOF'
import glob
import json
import os
import re
import sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
focal_path = os.environ.get("FILE_PATH", "")
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
test_patterns_section = os.environ.get("TEST_PATTERNS_SECTION", "")
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# S5 GU-TASKTYPE-ENUM-1: closed enum + normalization. 'Verify', '"verify"' and
# 'modify' all silently disarmed the A1/per-type rails before.
VALID_TASK_TYPES = {"create", "verify", "extend"}

# B3 sanctioned-extra path predicate — byte-identical to the whitelist scan in
# scripts/validate-bolt-artifacts.sh. The implementer writes and commits the
# acceptance test even when the unit does not list it in target_files; B3
# sanctions that, so acceptance_path_unowned must not flag it.
SANCTIONED_RX = r"(?:^|/)(?:tests?|spec|specs|__tests__)/|_test\.go$|Test\.php$|(?:^|/)test_[^/]+\.py$|\.(?:spec|test)\.[jt]sx?$"


def _section_body(heading_pat, text):
    """Body of a `## <heading>` section up to the next h2, or None when absent.
    Round-2 (ATK-3): tolerate a decorated heading (`## Anchors (from binding)`) —
    HEAD accepted the suffix shape, so requiring end-of-line false-flagged
    existing vaults on every project-wide run."""
    m = re.search(rf"^##\s+{heading_pat}\b[^\n]*\n(.*?)(?=^##\s|\Z)",
                  text, re.MULTILINE | re.IGNORECASE | re.DOTALL)
    return m.group(1) if m else None


def validate_unit(file_path):
    """All unit-spec checks for ONE unit file. Returns the issue list (each issue
    tagged with the unit's repo-relative path)."""
    issues = []
    rel_path = os.path.relpath(file_path, cwd)
    try:
        body = open(file_path, errors="replace").read()
    except Exception as e:
        return [{"halt_type": "unit_underspecified", "file": rel_path,
                 "detail": f"cannot read unit file: {e}"}]

    # Extract frontmatter
    fm_match = re.match(r"^---\n(.*?)\n---\n?", body, re.DOTALL)
    if not fm_match:
        return [{"halt_type": "unit_underspecified", "file": rel_path,
                 "detail": "unit has no frontmatter YAML block (--- ... ---)",
                 "missing_fields": ["entire_frontmatter"]}]

    fm = fm_match.group(1)
    body_after_fm = body[fm_match.end():]

    # ─── Check 1: unit_underspecified — required frontmatter fields ──────────
    # Accept either Layout A (unit_id) or Layout B (id) for unit identifier.
    field_present = {}
    for f in ["unit_id", "id", "title", "task_type", "target_files", "vault_source", "vault_anchors"]:
        if re.search(rf"^{f}:", fm, re.MULTILINE):
            field_present[f] = True

    unit_id = None
    m = re.search(r"^(?:unit_id|id):\s*(\S+)", fm, re.MULTILINE)
    if m: unit_id = m.group(1)
    if not unit_id:
        if os.path.basename(file_path) == "unit.md":
            unit_id = os.path.basename(os.path.dirname(file_path))
        else:
            unit_id = os.path.basename(file_path).replace(".md", "")

    # S5 GU-TASKTYPE-ENUM-1: tolerate quoted scalars + normalize case, then
    # validate against the CLOSED enum — an unknown value is flagged, never
    # silently skipped past every per-type rail.
    task_type_match = re.search(r"^task_type:\s*[\"']?([A-Za-z_-]+)[\"']?", fm, re.MULTILINE)
    task_type_raw = task_type_match.group(1) if task_type_match else None
    task_type = task_type_raw.strip().lower() if task_type_raw else None
    if task_type is not None and task_type not in VALID_TASK_TYPES:
        issues.append({
            "halt_type": "unit_underspecified",
            "detail": (f"unit {unit_id} has invalid task_type '{task_type_raw}' — "
                       f"must be one of create|verify|extend (closed enum)"),
            "unit_id": unit_id,
            "task_type": task_type_raw,
            "invalid_fields": ["task_type"],
        })

    # Required fields (lenient: accept unit_id OR id)
    missing_fields = []
    if "unit_id" not in field_present and "id" not in field_present:
        missing_fields.append("unit_id|id")
    if "title" not in field_present:
        missing_fields.append("title")
    if "task_type" not in field_present:
        missing_fields.append("task_type")
    # vault_source OR vault_anchors (layout B uses vault_anchors)
    if "vault_source" not in field_present and "vault_anchors" not in field_present:
        missing_fields.append("vault_source|vault_anchors")
    # target_files presence (for verify, may be empty list; for create/extend, must have entries)
    if "target_files" not in field_present:
        missing_fields.append("target_files")

    if missing_fields:
        issues.append({
            "halt_type": "unit_underspecified",
            "detail": f"unit {unit_id} frontmatter missing required field(s): {missing_fields}",
            "unit_id": unit_id,
            "task_type": task_type,
            "missing_fields": missing_fields,
        })

    # S5 GU-VUS-AT-PRESENCE-1: acceptance_test presence (schema rail: every unit
    # MUST carry one — "No exceptions"). Structured key in frontmatter or body;
    # an empty list does not count. Detection-layer (not a PreToolUse gate read).
    at_m = re.search(r"^acceptance_test\s*:\s*(.*?)(?=^\S|\Z)", body, re.DOTALL | re.MULTILINE)
    at_region = at_m.group(1).strip() if at_m else ""
    if not at_m or not at_region or at_region in ("[]", "[ ]", "null", "~"):
        issues.append({
            "halt_type": "unit_underspecified",
            "detail": (f"unit {unit_id} has no non-empty `acceptance_test:` entry — every unit "
                       f"MUST carry one (unit-schema §acceptance_test, no exceptions)"),
            "unit_id": unit_id,
            "task_type": task_type,
            "missing_fields": ["acceptance_test"],
        })

    # ─── Check: acceptance_path_unowned (spec 2026-08-29 Fase 4) ──────────────
    # Field defect this closes: a unit whose acceptance_test command runs a file
    # that is in NO unit's target_files. Every branch then violates an Iron Rule
    # — committing the file trips B3 whitelist_violation, skipping it fails the
    # acceptance command — so the unit is unfinishable by construction and the
    # implementer only discovers it after a full dispatch has burned.
    #
    # Conservative by design (this gate BLOCKS): a token is only reported when
    # it is path-shaped AND declared by no unit AND absent from disk AND not a
    # B3 sanctioned extra. A path that already exists is pre-existing input; a
    # path a sibling unit declares is owned by the DAG; a TEST path is written
    # and committed by the implementer and B3 sanctions it precisely because
    # "units often do not list it". All three are silent.
    #
    # SANCTIONED_RX MUST stay byte-identical to the B3 predicate in
    # scripts/validate-bolt-artifacts.sh (§whitelist scan) — if this check is
    # stricter than the observer it gates on, it blocks the normal convention.
    # That divergence is exactly the 2026-08-29 field defect, from the other
    # side: the implementer contract omitted these extras and a bolt halted
    # with scope_creep_detected over a test file B3 would never have flagged.
    # Pinned by tests/acceptance-path/ (drift tripwire).
    at_cmds = re.findall(r"(?m)^\s*(?:-\s*)?command:\s*(?:\"([^\"]*)\"|'([^']*)'|(.+?))\s*$", body)
    unowned = []
    for tup in at_cmds:
        cmd = next((x for x in tup if x), "")
        for tok_raw in cmd.split():
            tok = tok_raw.strip("\"'`,;()")
            if "=" in tok and not tok.startswith("/"):
                tok = tok.split("=", 1)[1].strip("\"'")   # --config=path/to/x.json
            if not tok or tok.startswith("-") or tok.startswith("@"):
                continue
            if "/" not in tok or "://" in tok or tok.startswith("/"):
                continue
            if any(ch in tok for ch in "*?[]{}$"):
                continue                                   # a glob declares nothing
            if not re.search(r"\.[A-Za-z0-9]{1,6}$", tok):
                continue                                   # directories are not files
            norm = tok.lstrip("./")
            if norm.split("/")[0] in ("node_modules", "vendor", "dist", "build", ".mega-sdd"):
                continue
            if norm in OWNED_PATHS:
                continue
            if re.search(SANCTIONED_RX, norm):
                continue                                   # B3 sanctioned extra
            if os.path.exists(os.path.join(cwd, norm)):
                continue                                   # pre-existing input
            unowned.append(norm)
    if unowned:
        issues.append({
            "halt_type": "acceptance_path_unowned",
            "detail": (f"unit {unit_id} runs acceptance_test command(s) against "
                       f"{sorted(set(unowned))} — no unit declares these in target_files "
                       f"and they do not exist. The unit cannot be completed: committing "
                       f"the file trips the B3 whitelist observer, skipping it fails the "
                       f"acceptance command. Add the path to this unit's target_files "
                       f"(operation: create), or point the command at a path a unit owns."),
            "unit_id": unit_id,
            "task_type": task_type,
            "unowned_paths": sorted(set(unowned)),
        })

    # ─── Per-task_type section contracts (S5 GU-TTCONTRACT-1: content, not just
    # heading presence — an empty `## Anchors`/`## Migration notes` carried no
    # payload for the bolt; a create unit WITH Migration notes signals a
    # mis-assigned task_type per 12.5.d) ───────────────────────────────────────
    if task_type in ("verify", "extend"):
        anch = _section_body(r"Anchors?", body_after_fm)
        if anch is None:
            issues.append({
                "halt_type": "unit_underspecified",
                "detail": f"unit {unit_id} task_type={task_type} requires `## Anchors` section",
                "unit_id": unit_id, "task_type": task_type,
                "missing_sections": ["Anchors"],
            })
        elif not anch.strip():
            issues.append({
                "halt_type": "unit_underspecified",
                "detail": f"unit {unit_id} `## Anchors` section is EMPTY — {task_type} requires >=1 anchor entry (12.5.a)",
                "unit_id": unit_id, "task_type": task_type,
                "empty_sections": ["Anchors"],
            })

    mig = _section_body(r"Migration\s+notes?", body_after_fm)
    if task_type == "extend":
        if mig is None:
            issues.append({
                "halt_type": "unit_underspecified",
                "detail": f"unit {unit_id} task_type=extend requires `## Migration notes` section",
                "unit_id": unit_id, "task_type": task_type,
                "missing_sections": ["Migration notes"],
            })
        elif not mig.strip():
            issues.append({
                "halt_type": "unit_underspecified",
                "detail": f"unit {unit_id} `## Migration notes` section is EMPTY — extend requires the ADD/KEEP/REMOVE field plan (12.5.d)",
                "unit_id": unit_id, "task_type": task_type,
                "empty_sections": ["Migration notes"],
            })
        else:
            missing_sub = [t for t in ("ADD", "KEEP", "REMOVE") if not re.search(rf"\b{t}\b", mig)]
            if missing_sub:
                issues.append({
                    "halt_type": "unit_underspecified",
                    "detail": f"unit {unit_id} `## Migration notes` missing sub-list(s) {missing_sub} — all three of ADD/KEEP/REMOVE must be present (12.5.d)",
                    "unit_id": unit_id, "task_type": task_type,
                    "missing_sublists": missing_sub,
                })
    elif task_type in ("create", "verify") and mig is not None:
        issues.append({
            "halt_type": "unit_underspecified",
            "detail": f"unit {unit_id} task_type={task_type} MUST NOT have a `## Migration notes` section (12.5.d — Migration notes are extend-only; its presence signals a mis-assigned task_type)",
            "unit_id": unit_id, "task_type": task_type,
            "forbidden_sections": ["Migration notes"],
        })

    # ─── Check 1b (A1): verify_grounding_untrusted — per-AC source grounding ─
    # Root cause: grounding_confidence: HIGH meant only "anchors verified = file
    # exists + line valid" (symbol existence), NEVER per-acceptance-criterion source
    # grounding. A verify unit could be stamped HIGH while its LOCKED acceptance
    # criteria lived only in test stubs / the PRD — certifying UNBUILT behavior green.
    # The defect is PARTIAL grounding (one real source anchor + N ungrounded criteria),
    # so an "all anchors are test files" check structurally misses it. The unit of
    # measurement is the acceptance CRITERION: each criterion of a verify+HIGH unit
    # must carry a resolvable NON-TEST source anchor `[grounded: path:line]`.
    # Scope: enforced ONLY when grounding_confidence: HIGH (a MEDIUM/LOW verify unit
    # anchored thinly is honest, not blocked) AND the unit ADOPTS per-AC markers
    # (>=1 criterion carries `[grounded:]`/`[ungrounded]`). Legacy units with no
    # markers at all are tolerated/treated-as-MEDIUM, never retro-blocked.
    # S5 GU-TASKTYPE-ENUM-1: tolerate quoted scalars here too.
    gc_match = re.search(r"^grounding_confidence:\s*[\"']?([A-Za-z]+)[\"']?", fm, re.MULTILINE)
    grounding_conf = gc_match.group(1).upper() if gc_match else None
    if task_type == "verify" and grounding_conf == "HIGH":
        # Adoption is detected from the WHOLE body, not from a pre-located section — so
        # heading drift (`## Acceptance criteria:`, `### Acceptance tests`, a renamed
        # heading) and prose criteria cannot hide the opt-in. A verify+HIGH unit with NO
        # grounding markers anywhere is legacy (old symbol-existence semantics), tolerated.
        adopts = re.search(r"\[grounded:|\[ungrounded\]", body_after_fm, re.IGNORECASE) is not None
    else:
        adopts = False
    if task_type == "verify" and grounding_conf == "HIGH" and adopts:
        def _is_test_path(p):
            pl = p.lower()
            if re.search(r"(^|/)(tests?|specs?|__tests__|__mocks__|fixtures?)/", pl):
                return True
            base = pl.rsplit("/", 1)[-1]
            if re.search(r"[._](test|spec)s?\.[a-z0-9]+$", base):   # foo.test.ts, foo_spec.rb
                return True
            if re.match(r"^test_.*\.[a-z0-9]+$", base):             # test_foo.py
                return True
            base_orig = p.rsplit("/", 1)[-1]
            if re.search(r"(?:Test|Spec)s?\.[A-Za-z0-9]+$", base_orig):  # PascalCase: UserTest.php, FooSpec.rb
                return True
            return False

        def _is_doc_path(p):
            # S5 GU-VUS-A1-DOC-ANCHOR-1: the vault/PRD markdown itself is NOT
            # implementation evidence — "criteria live only in the PRD" is the
            # exact class A1 was built to block, yet a vault-doc anchor passed.
            # Round-2: lstrip("./") mangled the leading dot of ".mega-sdd/..."
            # (char-set strip), letting relative .mega-sdd anchors through —
            # strip a "./" PREFIX only. And the blanket *.md rejection is scoped:
            # spec/doc LOCATIONS (mega-sdd artifacts, docs/, specs/) and spec-doc
            # NAMES are rejected; other .md stays groundable (a docs-site's
            # implementation IS markdown).
            pl = p.lower()
            while pl.startswith("./"):
                pl = pl[2:]
            if pl.startswith(".mega-sdd/") or "/.mega-sdd/" in pl:
                return True
            if re.match(r"^(docs?|specs?|rfcs?)/", pl) or re.search(r"/(docs?|specs?|rfcs?)/", pl):
                if re.search(r"\.(md|markdown|rst|txt)$", pl):
                    return True
            base = pl.rsplit("/", 1)[-1]
            if re.match(r"^(readme|changelog|prd|brd|contributing|license)\b", base) and re.search(r"\.(md|markdown|rst|txt)$", base):
                return True
            return False

        def _anchor_resolves(spec):
            m = re.match(r"^(.+?):(\d+)$", spec)
            if not m:
                # S5 GU-VUS-A1-DOC-ANCHOR-1: a line-less anchor is not a
                # verifiable grounding — the line number IS the evidence pointer.
                return False
            path, ln = m.group(1), int(m.group(2))
            full = os.path.join(cwd, path)
            if not os.path.isfile(full):
                return False
            try:
                with open(full, errors="replace") as fh:
                    n = sum(1 for _ in fh)
            except Exception:
                return False
            if ln < 1 or ln > n:
                return False
            return True

        def _grounded_ok(line):
            m = re.search(r"\[grounded:\s*([^\]\s]+)\s*\]", line, re.IGNORECASE)
            if not m:
                return False
            spec = m.group(1)
            path = spec.split(":")[0]
            if _is_test_path(path) or _is_doc_path(path):
                return False
            return _anchor_resolves(spec)

        # Locate the acceptance-criteria section: tolerate h2-h4, the
        # criteria/criterion/test(s) synonyms, and a trailing colon.
        ac_match = re.search(
            r"(?im)^#{2,4}[ \t]+Acceptance[ \t]+(?:criteri(?:a|on)|tests?)\b[^\n]*\n(.*?)(?=^#{2,4}[ \t]|\Z)",
            body_after_fm, re.S,
        )
        ungrounded = None
        if not ac_match:
            # Fail CLOSED: the unit opted into per-AC grounding but no recognised
            # acceptance-criteria section parses — the criteria cannot be checked, so a
            # false-green verify unit must NOT slip through on a renamed/absent heading.
            ungrounded = ["<no parseable `## Acceptance criteria` section to ground>"]
        else:
            lines = ac_match.group(1).splitlines()

            def _indent(s):
                return len(s) - len(s.lstrip(" \t"))

            item_re = re.compile(r"^\s*(?:[-*]|\d+[.)])\s+\S")
            item_indents = [_indent(l) for l in lines if item_re.match(l)]
            min_ind = min(item_indents) if item_indents else 0
            # Group lines into criteria. A criterion HEAD is a top-level list item OR a
            # top-level prose assertion. A top-level prose line ending ':' is a lead-in
            # (not a criterion). Deeper-indented lines are detail of the current head —
            # so sub-bullets are NOT over-counted as separate criteria.
            criteria = []
            cur = None
            for l in lines:
                if not l.strip():
                    continue
                top = _indent(l) <= min_ind
                is_item = item_re.match(l) is not None
                if top and is_item:
                    cur = [l]; criteria.append(cur)
                elif top and not is_item:
                    if l.rstrip().endswith(":"):
                        cur = None            # intro / lead-in header
                    else:
                        cur = [l]; criteria.append(cur)   # prose criterion
                else:
                    if cur is not None:
                        cur.append(l)         # detail of the current criterion
                    else:
                        criteria.append([l])  # orphan detail with no head
            if not criteria:
                ungrounded = ["<acceptance criteria section is empty>"]
            else:
                # a criterion is grounded if its head OR any detail line carries a marker
                offending = [c[0].strip()[:120] for c in criteria
                             if not any(_grounded_ok(x) for x in c)]
                ungrounded = offending or None

        if ungrounded:
            issues.append({
                "halt_type": "verify_grounding_untrusted",
                "detail": (
                    f"unit {unit_id} is task_type=verify grounding_confidence=HIGH but "
                    f"{len(ungrounded)} acceptance criteri(on/a) lack a resolvable NON-TEST "
                    f"source anchor. A verify unit certifies EXISTING behavior — each criterion "
                    f"must cite a non-test implementation anchor `[grounded: path:line]`. "
                    f"Downgrade grounding_confidence, or split verify[built]+create[unbuilt]."
                ),
                "unit_id": unit_id,
                "task_type": task_type,
                "grounding_confidence": grounding_conf,
                "ungrounded_criteria": ungrounded[:10],
            })

    # ─── Check 2: hard_rule_unparseable (v1 grammar) — S5 GU-HR-GRAMMAR-1 ────
    # The 5 MACHINE-CHECKABLE productions:
    #   1. "DO NOT modify <path>"
    #   2. "DO NOT add new <manifest> dependencies"
    #   3. "<path-glob> MUST follow <case-style> naming"
    #   4. "function <name> MUST preserve signature: <type-sig>"
    #   5. "file <path> MUST exist after bolt"
    # Generic `- MUST/MUST NOT/DO NOT …` directives are ACCEPTED as rules but are
    # NOT machine-checkable at bolt time — they are now counted honestly
    # (hard_rules_directive_prose in the state summary) instead of being
    # laundered through undocumented catch-alls as "parseable". Rule-like lines
    # in NON-dash shapes (asterisk/numbered bullets, bare directive prose) were
    # silently skipped — invisible to the bolt-time snapshot — and are now
    # unparseable. Annotation sub-lines (Citation:/Source:/…), fenced ast-grep
    # YAML content, and indented continuations stay whitelisted.
    # S6 EB-GATE-12 (incidental): tolerate trailing text on the heading line —
    # the canonical template emits `## Hard rules  (validated at bolt time …)`;
    # requiring whitespace-only after "rules" silently skipped the WHOLE grammar
    # check on template-conformant units.
    hr_match = re.search(r"^##\s+Hard\s+rules?\b[^\n]*\n(.*?)(?=\n##\s|\Z)", body_after_fm, re.MULTILINE | re.IGNORECASE | re.DOTALL)
    n_machine = 0
    n_directive = 0
    if hr_match:
        hr_block = hr_match.group(1)
        # Mirrors postflight_rules.py STRICT (S7-A): modal synonyms are the same
        # mechanical intent; the object must be PATH-SHAPED (. or /) — a prose
        # object ("existing", "runtime") stays a directive, not a machine check.
        strict_productions = [
            re.compile(r"^-\s*(?:DO NOT|MUST NOT|NEVER) modify\s+\S*[./]\S*"),
            re.compile(r"^-\s*(?:DO NOT|MUST NOT|NEVER) add new\s+\S*\.\S+\s+dependencies"),
            re.compile(r"^-\s*\S+\s+MUST follow\s+(?:kebab-case|camelCase|snake_case|PascalCase)\s+naming"),
            re.compile(r"^-\s*function\s+\S+\s+MUST preserve signature:\s+.*"),
            re.compile(r"^-\s*file\s+\S+\s+MUST exist after bolt"),
        ]
        generic_directive = re.compile(r"^-\s*(?:MUST NOT|MUST|DO NOT|NEVER|ALWAYS)\b")
        unparseable_lines = []
        in_fence = False
        rule_open = False   # round-2 (ATK-2): a `- ` rule head is "open" until the
                            # next non-indented line — only THEN is an indented line
                            # a legitimate continuation. A leading space used to skip
                            # every check outright (one char defeated the grammar AND
                            # the evasion net; also a strictness regression vs HEAD,
                            # which validated stripped dash lines at any indent).
        for ln in hr_block.split("\n"):
            s = ln.strip()
            if not s:
                continue
            if s.startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue  # ast-grep YAML block content
            if s.startswith("#") or s.startswith("<"):
                continue  # comment / HTML marker
            if re.match(r"^(?:Citation|Source|Ref(?:erence)?|From)\s*:", s, re.IGNORECASE):
                continue  # annotation sub-line of the preceding rule
            indented = bool(re.match(r"^\s", ln))
            if indented and not s.startswith("- ") and rule_open:
                continue  # true continuation/detail of the open rule
            if not s.startswith("- "):
                rule_open = False
                # S5: bullet-evasion shapes — a rule-like line the snapshot never sees
                # (round-2: checked on the STRIPPED line, so indenting doesn't hide it)
                if (re.match(r"^(?:[*+]\s+|\d+[.)]\s+)", s) and re.search(r"\b(?:MUST|DO NOT|NEVER|ALWAYS)\b", s)) \
                        or re.match(r"^(?:MUST NOT|MUST|DO NOT|NEVER|ALWAYS)\b", s, re.IGNORECASE):
                    unparseable_lines.append(s)
                continue  # other non-dash prose stays tolerated
            # a dash line (any indent) is a rule head — validate its stripped form
            rule_open = True
            if any(p.match(s) for p in strict_productions):
                n_machine += 1
                continue
            if re.search(r"(rule|language|pattern):", s):
                n_machine += 1  # ast-grep v2 inline head
                continue
            if generic_directive.match(s):
                n_directive += 1  # accepted, snapshot-able, NOT machine-checked
                continue
            unparseable_lines.append(s)
        if unparseable_lines:
            issues.append({
                "halt_type": "hard_rule_unparseable",
                "detail": f"unit {unit_id} has {len(unparseable_lines)} unparseable Hard Rule line(s)",
                "unit_id": unit_id,
                "unparseable_lines": unparseable_lines[:5],  # cap at 5 for readability
            })
        # round-2 (ATK-4): the machine-checkable/directive split is an OBSERVABLE —
        # accumulate for the state summary (consumed by lint-units / analyze).
        hr_counts[0] += n_machine
        hr_counts[1] += n_directive

    # ─── Check 3: starterkit_rule_citation_missing ────────────────────────────
    # A Hard Rule line referencing starterkit-context.yaml MUST have a "Citation:" sub-line.
    # Pattern: rule mentions "starterkit" or references starterkit_relevance fields.
    # (Detection scope is honest: a starterkit-DERIVED rule whose text carries no
    # "starterkit" token is not machine-attributable — the derivation reference
    # mandates the Citation line as the attribution carrier.)
    sk_consumed_match = re.search(r"^starterkit_context_consumed:\s*(true|false)", fm, re.MULTILINE | re.IGNORECASE)
    if sk_consumed_match and sk_consumed_match.group(1).lower() == "true" and hr_match:
        hr_block = hr_match.group(1)
        lines = hr_block.split("\n")
        missing_citations = []
        # S5 GU-SK-CITE-2: accept BOTH documented citation shapes — `Citation:` and
        # the lowercase yaml-style `citation:` (the derivation template's own shape
        # was flagged missing-citation before).
        cite_re = re.compile(r"(?i)citation\s*:\s*[\"']?starterkit-context")
        i = 0
        while i < len(lines):
            ln = lines[i].strip()
            if ln.startswith("- ") and "starterkit" in ln.lower():
                found_citation = False
                for j in range(i, min(i + 6, len(lines))):
                    if cite_re.search(lines[j]):
                        found_citation = True
                        break
                if not found_citation:
                    missing_citations.append(ln[:100])
            i += 1
        if missing_citations:
            issues.append({
                "halt_type": "starterkit_rule_citation_missing",
                "detail": f"unit {unit_id} has starterkit-derived Hard Rule(s) without `Citation: starterkit-context.yaml §<path>` annotation",
                "unit_id": unit_id,
                "missing_citations_excerpts": missing_citations[:5],
            })

    # ─── Check 4 (slice 3 v3.58.0+): Hard Rule citation trace ────────────────
    # Every Hard Rule SHOULD have a traceable source: starterkit-context.yaml (already
    # checked above), OR binding.md "## Suggested Unit Hard Rules" section, OR KB
    # anti-pattern reference. This check is advisory — Hard Rules without citation
    # get a "trace_missing" flag for review.
    if hr_match:
        hr_block = hr_match.group(1)
        untraced_rules = []
        lines = hr_block.split("\n")
        i = 0
        while i < len(lines):
            ln = lines[i].strip()
            if ln.startswith("- ") and not ln.startswith("- #"):
                # Check next 5 lines for ANY Citation: or Source: or Ref: annotation
                found_trace = False
                for j in range(i, min(i + 6, len(lines))):
                    ck = lines[j]
                    if re.search(r"(?:Citation|Source|Ref(?:erence)?|From):", ck, re.IGNORECASE):
                        found_trace = True
                        break
                    # Inline mention of binding/KB/starterkit/constitution = also count as trace
                    if re.search(r"\b(?:binding\.md|knowledge-base|starterkit-context|constitution\.md|D-\d+|C-\d+|CONFLICT-)", ck, re.IGNORECASE):
                        found_trace = True
                        break
                if not found_trace:
                    untraced_rules.append(ln[:120])
            i += 1
        if untraced_rules:
            # Advisory-level — NOT a hard halt. Flag with low severity.
            issues.append({
                "halt_type": "hard_rule_trace_missing",
                "detail": f"unit {unit_id} has {len(untraced_rules)} Hard Rule(s) without traceable source (advisory; rules should cite binding/KB/starterkit/constitution)",
                "unit_id": unit_id,
                "untraced_rules": untraced_rules[:5],
                "severity": "advisory",
            })

    # ─── Check 5 (code-delivery slice D): render_test_missing ────────────────
    # Any unit whose target_files include a DETAIL/SHOW view (matching the active
    # framework pack `## Test patterns` -> detail_view_glob) MUST carry a structured
    # acceptance_test entry of type/kind `render`.
    if detail_glob:
        targets = _collect_target_files(fm, body_after_fm)
        rx = _glob_to_regex(detail_glob)
        detail_views = [t for t in targets if _glob_match(t, rx)]
        if detail_views and not _has_render_acceptance_test(body):
            issues.append({
                "halt_type": "render_test_missing",
                "detail": (
                    f"unit {unit_id} ships detail view(s) {detail_views[:3]} but has no "
                    f"acceptance_test of type `render` (pack detail_view_glob={detail_glob}). "
                    f"A route-200 smoke test misses empty-model / null-field render crashes."
                ),
                "unit_id": unit_id,
                "detail_views": detail_views[:5],
                "detail_view_glob": detail_glob,
                "expected": "one acceptance_test entry with `type: render` (or `kind: render`), per pack `## Test patterns` -> detail_view_render template",
            })

    for i in issues:
        i.setdefault("file", rel_path)
    return issues

# ─── Check 5 (code-delivery slice D): render_test_missing ────────────────────
# Any unit whose target_files include a DETAIL/SHOW view (matching the active
# framework pack `## Test patterns` -> detail_view_glob) MUST carry a structured
# acceptance_test entry of type/kind `render`. Detection is STRUCTURED, never a
# fuzzy grep-for-"render": a prose `## Tests` bullet named "...renders..." does NOT
# satisfy this (that was the false-negative trap). The detail-view glob is
# PACK-DECLARED — no `## Test patterns` section / no detail_view_glob => this check
# SKIPs (the stack declared no detail-view convention); the checks above still run.
def _glob_to_regex(pat):
    """Translate a pack glob (with `**` = any-depth) into a compiled regex. Mirrors
    validate-flow-coverage.sh so the same `resources/views/**/show.blade.php` shape
    matches both nested and direct paths."""
    i, out, n = 0, ["(?s:"], len(pat)
    while i < n:
        c = pat[i]
        if c == "*":
            if pat[i:i + 3] == "**/":
                out.append("(?:.*/)?"); i += 3; continue
            if pat[i:i + 2] == "**":
                out.append(".*"); i += 2; continue
            out.append("[^/]*"); i += 1; continue
        if c == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(c))
        i += 1
    out.append(r")\Z")
    return re.compile("".join(out))


def _glob_match(path, rx):
    if rx.match(path):
        return True
    # also try suffix match (a target path may carry leading dirs the glob omits)
    return rx.match(path.split("/", 1)[-1]) is not None if "/" in path else False


def _parse_detail_view_glob(section_text):
    """Pull `detail_view_glob:` from the FIRST yaml fence of the resolver section dump
    (most-specific pack wins). Returns the glob string or None. We ONLY parse inside a
    real ```yaml fence — a pack that declares the §Test patterns PRINCIPLE in prose but
    no concrete yaml (e.g. _universal) yields None => the render check SKIPs (the stack
    declared no detail-view convention)."""
    if not section_text or not section_text.strip():
        return None
    m = re.search(r"```ya?ml\s*\n(.*?)```", section_text, re.DOTALL)
    if not m:
        return None
    gm = re.search(r"^\s*detail_view_glob\s*:\s*(.+?)\s*$", m.group(1), re.MULTILINE)
    if not gm:
        return None
    return gm.group(1).strip().strip('"').strip("'") or None


def _expand_braces(p):
    """Expand a single {a,b} brace group (e.g. views/x/{index,show}.blade.php)."""
    m = re.search(r"\{([^{}]*)\}", p)
    if not m:
        return [p]
    pre, post = p[:m.start()], p[m.end():]
    out = []
    for opt in m.group(1).split(","):
        out.extend(_expand_braces(pre + opt.strip() + post))
    return out


def _collect_target_files(frontmatter, body_text):
    """Union of target-file paths from BOTH the frontmatter `target_files:` list AND
    the `## Target files` body block. TF units carry paths ONLY in the body block
    (with ` (edit)`/` (new)` annotations), so reading frontmatter alone misses them."""
    paths = []
    # (a) frontmatter list: `target_files:` followed by `- path` items, or inline []
    # S5 GU-VUS-TF-SWALLOW-1: [ \t]* (NOT \s*) — \s* matched the NEWLINE, so the
    # first block-list item landed in group(1) and was silently discarded; a unit
    # whose detail view was the FIRST/only target file never fired render_test_missing.
    fm_tf = re.search(r"^target_files[ \t]*:[ \t]*(.*)$", frontmatter, re.MULTILINE)
    if fm_tf:
        inline = fm_tf.group(1).strip()
        if inline.startswith("["):
            for item in re.findall(r"[^\[\],\s'\"][^\[\],]*", inline):
                paths.append(item.strip().strip('"').strip("'"))
        # indented `- path` / `- path: x` items after the key
        after = frontmatter[fm_tf.end():]
        for ln in after.splitlines():
            if re.match(r"^[A-Za-z_]", ln):  # next top-level key ends the list
                break
            mm = re.match(r"^\s*-\s*(?:path\s*:\s*)?(.+?)\s*$", ln)
            if mm:
                paths.append(mm.group(1).strip().strip('"').strip("'"))
    # (b) `## Target files` body block (fenced or raw)
    tm = re.search(r"^##\s+Target files\s*\n(.*?)(?:\n##\s|\Z)", body_text, re.DOTALL | re.MULTILINE)
    if tm:
        block = tm.group(1)
        fence = re.search(r"```[^\n]*\n(.*?)```", block, re.DOTALL)
        blk = fence.group(1) if fence else block
        for ln in blk.splitlines():
            ln = ln.strip().lstrip("-").strip()
            if not ln:
                continue
            path_only = re.split(r"\s+\(", ln, maxsplit=1)[0].strip()
            if path_only:
                paths.append(path_only)
    # expand brace groups; drop empties
    expanded = []
    for p in paths:
        if p:
            expanded.extend(_expand_braces(p))
    return expanded


def _has_render_acceptance_test(full_text):
    """True iff the unit has a STRUCTURED acceptance_test entry whose type/kind is
    literally `render`. Only inspects the `acceptance_test:` YAML region (frontmatter
    or a body `acceptance_test:` block) — never a prose `## Tests` bullet."""
    # ADV-07: capture inline content on the same line AND any following indented block,
    # so both block form (`acceptance_test:\n  - type: render`) and inline-list form
    # (`acceptance_test: [{type: render}]` / `acceptance_test: [render]`) are accepted.
    at = re.search(r"^acceptance_test\s*:\s*(.*?)(?:^\S|\Z)", full_text, re.DOTALL | re.MULTILINE)
    if not at:
        return False
    region = at.group(1)
    if re.search(r"(?:type|kind)\s*:\s*[\"']?render[\"']?\b", region):
        return True
    if "[" in region and re.search(r"[\[,]\s*[\"']?render[\"']?\s*[,\]]", region):
        return True
    return False


detail_glob = _parse_detail_view_glob(test_patterns_section)


# ─── Main (S5 GU-HOOK-1): validate ALL units, merge into ONE project-wide state ─
def discover_units():
    # Round-2 (S5R-3): the project sweep must cover every layout the focal
    # path-filter accepts — the legacy docs/mega-sdd/vaults/** tree and nested
    # *-bound dirs were focal-validated but invisible to the project scan, so a
    # project-mode re-derive ERASED their recorded FAILs.
    got = []
    for pat in (
        os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*.md"),
        os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*", "unit.md"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*", "units", "U-*.md"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*", "units", "U-*", "unit.md"),
        os.path.join(cwd, "*-bound", "units", "U-*.md"),
        os.path.join(cwd, "*-bound", "units", "U-*", "unit.md"),
        os.path.join(cwd, "*", "*-bound", "units", "U-*.md"),
        os.path.join(cwd, "*", "*-bound", "units", "U-*", "unit.md"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*-bound", "units", "U-*.md"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*-bound", "units", "U-*", "unit.md"),
    ):
        got.extend(glob.glob(pat))
    return sorted({os.path.realpath(p) for p in got})


def _tf_paths(fm_text):
    """target_files paths from one unit's frontmatter — block-mapping, scalar-list,
    and inline-flow shapes (same three shapes resolve-review-tier.sh parses)."""
    out = []
    m = re.search(r"(?ms)^target_files:\s*\n((?:[ \t]+.*\n?)*)", fm_text)
    blk = m.group(1) if m else ""
    for rx in (r"(?m)^[ \t]*-?[ \t]*path:\s*(?:\"([^\"]+)\"|'([^']+)'|([^\s#]+))",
               r"(?m)^[ \t]*-[ \t]+(?:\"([^\"]+)\"|'([^']+)'|([^\s#:]+))[ \t]*$"):
        for g in re.findall(rx, blk):
            v = next((x for x in g if x), "")
            if v:
                out.append(v)
        if out:
            break
    if not out:
        inl = re.search(r"(?m)^target_files:\s*\[([^\]]*)\]", fm_text)
        if inl:
            out = [p.strip().strip("\"'") for p in inl.group(1).split(",") if p.strip()]
    return [p.lstrip("./") for p in out]


def build_owned_paths(unit_paths):
    """Union of every unit's declared target_files — the DAG-wide ownership set.
    Built once, before per-unit validation, because acceptance_path_unowned is a
    CROSS-unit question: a path this unit does not declare is fine when a sibling
    unit creates it, and only a defect when NO unit does."""
    owned = set()
    for up in unit_paths:
        try:
            t = open(up, encoding="utf-8", errors="replace").read().lstrip("﻿")
        except OSError:
            continue
        if not t.startswith("---"):
            continue
        end = t.find("\n---", 3)
        if end <= 0:
            continue
        owned.update(_tf_paths(t[3:end]))
    return owned


all_units = discover_units()
if focal_path:
    known = {os.path.abspath(p) for p in all_units}
    if os.path.abspath(focal_path) not in known:
        all_units.append(focal_path)  # unusual layout — still validate the focal file

OWNED_PATHS = build_owned_paths(all_units)

merged = []
checked_files = []
hr_counts = [0, 0]  # [machine_checkable, directive_prose] across all units (ATK-4)
for up in sorted(all_units):
    checked_files.append(os.path.relpath(up, cwd))
    merged.extend(validate_unit(up))

status = "PASS" if not merged else "FAIL"
focal_rel = os.path.relpath(focal_path, cwd) if focal_path else None
state = {
    "ts": ts,
    "mode": "single" if focal_path else "project",
    "checked_file": focal_rel,        # back-compat: the focal unit on single dispatch
    "checked_files": checked_files,   # S5: the state ALWAYS covers every unit
    "status": status,
    "issues_count": len(merged),
    "hard_rules_machine_checkable": hr_counts[0],
    "hard_rules_directive_prose": hr_counts[1],
    "issues": merged,
    "next_action": (
        "Unit spec passes integrity checks."
        if status == "PASS"
        else f"{len(merged)} unit-spec issue(s) detected. Detection-only at hook layer; re-emit unit via generate-units --regenerate or amend manually."
    ),
}

try:
    _tmp = state_file + ".tmp.%d" % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace) — no torn read under concurrent bolts
    with open(_tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(_tmp, state_file)
except Exception as e:
    print(f"ERROR: state write: {e}", file=sys.stderr)
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

# Exit code: focal file's verdict on single dispatch (PostToolUse semantics);
# merged verdict in project mode (the gate's re-derive entry point).
if focal_rel is not None:
    sys.exit(1 if any(i.get("file") == focal_rel for i in merged) else 0)
sys.exit(0 if status == "PASS" else 1)
PYEOF

exit $?
