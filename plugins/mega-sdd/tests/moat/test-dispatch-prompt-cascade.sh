#!/usr/bin/env bash
# test-dispatch-prompt-cascade.sh — the MOAT-surface suite for the T2 truncation
# cascade of scripts/build-dispatch-prompt.sh.
#
# WHAT THIS PINS (and why "it emits all sections and stays under 12KB" is NOT it)
# ------------------------------------------------------------------------------
# skills/execute-bolts/references/context-enrichment.md §"T2 section priority +
# truncation cascade" is a 9-row contract: WHICH section gives way FIRST, and
# WHERE each one is allowed to stop. Tranche 2b moved that assembly from the
# model's head into a script; the cascade is the part a re-implementation gets
# subtly wrong, and a wrong cascade is invisible (the prompt still "looks fine",
# it has just silently starved the security-bearing sections).
#
# The suite therefore drives the cascade RUNG BY RUNG and asserts the documented
# drop floor at every priority, plus the halt conjunction in BOTH directions.
#
# HOW THE RUNG WALK WORKS (no hardcoded byte constants — deliberate)
# ------------------------------------------------------------------
# The reference files that feed T2 (ui-design-heuristics.md, modern-baseline.md,
# ux-rules.md, style-principles.md, the packs) are hand-authored and WILL be
# edited. A suite with byte literals in it would then fail as a phantom "cascade
# regression". So every threshold here is MEASURED at runtime:
#
#   the only ballast knob is a constitution clause body of exactly N bytes
#   (priority 9 — never truncated, always emitted), so pre-truncation
#   t2 grows by exactly 1 byte per ballast byte. After a probe reports
#   consumed_t2 (POST-truncation), the ballast that fires EXACTLY ONE MORE rung
#   is  N' = N + (cap_t2 - consumed_t2) + 1.  One probe per rung, exactly.
#
# Ballast is grown by CLAUSE BODY LENGTH, never by clause COUNT: clause ids are
# cited from the unit file, which is emitted verbatim into T1, so growing ballast
# by id count would move t1 and t2 at once and confound the halt tests.
#
# Conventions: fixture-in-temp-dir, assertion counter, PASS/FAIL summary, every
# builder invocation `</dev/null` (the suite must never donate its stdin).
#
# THE BUDGET RAILS (sections I–M), added after the tranche-2b review
# ------------------------------------------------------------------
# The cap constants stopped being a guess on 2026-07-31 and became a MEASUREMENT
# (context-enrichment.md ## AMENDMENT — 123 builder runs; cap_t1 2048 -> 12288).
# A cap amendment's failure mode is NOT "too tight" — it is a cap that can never
# fire, which is why the amendment refused to raise cap_hard. These sections pin
# the amendment in BOTH directions, and each was falsified against a deliberately
# broken builder before being trusted:
#
#   I  halt REACHABILITY + non-vacuity. Bisects the constitution payload that
#      flips the halt and asserts halt at B, no halt at B-64. The discriminating
#      assertion is NOT "a halt exists" (trivially true of any cap — the
#      constitution is never truncated, so T2 grows without bound) but WHERE the
#      boundary sits: at the boundary T2 must be just past its own exhausted cap.
#      Caught cap_hard=22528 (t2 had to balloon 10 475 B past cap_t2).
#   J  the INVERSE, asserted just as hard: a unit driven onto the measured MEDIAN
#      T1 (4741) must exit 0 with no halt, no truncation, no budget warning, and
#      every T2 section at FULL fidelity. Caught cap_t1 reverted to 2048.
#   K  tier 8b `map_patterns` — the row the amendment added. Position + floor.
#   L  the DEFAULT stdout shape (the only section that does NOT pass --explain)
#      and the provenance appendix that `sections_omitted[]` moved into. Caught
#      the forensic keys being restored to default stdout, and the design-slice
#      key emitted as "" instead of absent. Also pins `file_bytes` against
#      `total_bytes` — two numbers with two meanings, neither renamable into the
#      other (the reported-vs-actual gap was filed twice).
#   M  invariant #5 both ways: absent design_system sub-keys are DROPPED and
#      RECORDED (never `palette=None`), and the builder's absent-value smoke
#      alarm stays SILENT on a unit body that says "None" in prose or code.
#   N  the halt's VACUITY rail. `all_1_to_8_at_floor` is vacuously true on a unit
#      that has no priority-1..8 section at all, so term (a) alone proves
#      nothing. Both directions on ONE such unit: under cap_hard it must NOT
#      halt (term (b) is doing the discriminating work), over it — driven there
#      by constitution_clauses alone — it MUST. This is the rail against
#      executing the "drop the redundant `total > cap_hard` term" backlog item,
#      which under vacuity would halt any unit that cites a single clause.
#   O  the design-slice CHANNEL. The lens's copy moved to a neutral lens-input
#      FILE (`<vault>/lens-inputs/U-XXX/design-slice.md`, a SIBLING of bolts/)
#      and stdout carries its PATH. The bolt must lose nothing: the same bytes
#      are still injected into the dispatch prompt itself.
#
# DO NOT "fix" the script if one of these fails — they are documented behavior:
#   * total > cap_hard with zero truncations and exit 0 (context-enrichment.md
#     §Size check — `total > cap_hard` ALONE is not a halt trigger; the
#     three-way conjunction is. Sections F and J both rest on this.)
#   * framework_pack_rules OMITTED on an empty filtered set despite the
#     "keep top 1" floor (the floor is vacuous on an empty set)
#   * kb_anti_patterns always omitted ("domain tags" is a phantom field)
#   * the `Design system:` marker spelling (byte-compatible with the live gate)
#   * `map_patterns` never appearing in truncations[] (8b has zero rungs by
#     contract — a no-op pass, not a missing ladder)

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "${HERE}/../.." && pwd)"
BUILDER="${PLUGIN}/scripts/build-dispatch-prompt.sh"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); echo "PASS ($1)"; }
nok() { FAIL=$((FAIL + 1)); echo "FAIL ($1)"; }
chk() { if [ "$1" = "1" ] || [ "$1" = "true" ]; then ok "$2"; else nok "$2 — $3"; fi; }
eq()  { if [ "$1" = "$2" ]; then ok "$3"; else nok "$3 — expected '$2', got '$1'"; fi; }
has() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

if [ ! -x "$BUILDER" ] && [ ! -f "$BUILDER" ]; then
  echo "FAIL (builder missing at $BUILDER)"; exit 1
fi

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t dpcascade)"
trap 'rm -rf "$WORK"' EXIT

# INTERPRETER — the same fail-closed probe the builder itself uses. `command -v
# python3` is a documented FALSE POSITIVE on the target Windows machine class:
# the WindowsApps App Execution Alias stub is on PATH, answers `command -v`,
# writes to stderr and exits 49. A suite that resolved `python3` that way would
# get an EMPTY vars.sh from every summarizer call, every J_* variable would stay
# unset, and the whole run would report PASSes for assertions that never
# executed — the exact silent-green failure this suite exists to prevent.
# $PY is expanded UNQUOTED at every call site: the Windows fallback is `py -3`,
# two words.
if [ -f "${PLUGIN}/scripts/_lib/resolve-python.sh" ]; then
  # shellcheck disable=SC1091
  . "${PLUGIN}/scripts/_lib/resolve-python.sh"
  if mega_sdd_python; then
    PY="$MEGA_SDD_PY"
  else
    echo "FAIL (no usable python interpreter — the suite cannot summarize builder JSON)"
    mega_sdd_python_remedy
    echo
    exit 1
  fi
else
  PY="python3"
  command -v python3 >/dev/null 2>&1 || PY="python"
fi

# ══════════════════════════════════════════════════════════════════════════════
# summarizer — ONE python call per probe turns the builder JSON + the emitted
# prompt into shell variables. Keeps the probe loop at 2 spawns.
# ══════════════════════════════════════════════════════════════════════════════
cat > "${WORK}/summarize.py" <<'PYEOF'
# -*- coding: utf-8 -*-
import json
import os
import re
import sys

jf, fallback_prompt, varf, rulef = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

# The 9-row priority table of context-enrichment.md, transcribed HERE rather than
# imported from the builder: if the builder's own priorities drift, the monotone
# assertion below must fail loudly instead of silently agreeing with the drift.
PRI = {
    "validation_hints": 1, "historical_memory": 2, "reuse_slice": 3,
    "symbol_slice": 3,  # tier 3 enumerated 3a/3b (R2 amendment 2026-08-02)
    "kb_anti_patterns": 4, "confidence_labels": 5, "depends_on_summaries": 6,
    "framework_pack_rules": 7, "starterkit_slice": 8, "map_patterns": 8,
    "design_slice": 8, "constitution_clauses": 9,
}

out = []


def put(k, v):
    out.append("%s='%s'" % (k, str(v).replace("'", "'\\''")))


d = None
try:
    with open(jf, encoding="utf-8") as f:
        raw = f.read().strip()
    if raw:
        d = json.loads(raw)
except Exception:
    d = None

if not isinstance(d, dict):
    put("J_JSON", 0)
    with open(varf, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    open(rulef, "w").close()
    sys.exit(0)

put("J_JSON", 1)
put("J_STATUS", d.get("status", ""))
put("J_T1", d.get("t1_bytes", -1))
put("J_T2", d.get("t2_bytes", -1))
put("J_TOTAL", d.get("total_bytes", -1))
# `total_bytes` = T1+T2, the BUDGETED tiers the cascade truncates and the halt
# reasons about. `file_bytes` = the whole artifact on disk. They are two numbers
# with two meanings and the gap between them (tier banners + tracker + the TIER 3
# pointer list + the PROVENANCE appendix) is un-budgeted and never truncated.
# Reported separately here so a "simplification" that collapses one into the
# other is caught rather than silently re-opening the understated-artifact class.
put("J_FILE_BYTES", d.get("file_bytes", -1))
caps = d.get("caps") or {}
put("J_CAP_HARD", caps.get("cap_hard", -1))
put("J_CAP_T2", caps.get("cap_t2", -1))
put("J_CAP_T1", caps.get("cap_t1", -1))
put("J_CAP_TARGET", caps.get("cap_target", -1))
halt = d.get("halt")
put("J_HALT", (halt or {}).get("halt", "none") if isinstance(halt, dict) else "none")
if isinstance(halt, dict):
    put("J_HALT_KEYS", " ".join(sorted(halt.keys())))
    put("J_HALT_TOTAL", halt.get("total", -1))
    put("J_HALT_T1", halt.get("t1_bytes", -1))
    put("J_HALT_T2", halt.get("t2_bytes", -1))
    put("J_HALT_CAP", halt.get("cap_hard", -1))
    put("J_HALT_EXH", halt.get("truncation_exhausted", ""))
    put("J_HALT_NWARN", len(halt.get("warnings") or []))
else:
    put("J_HALT_KEYS", "")
    put("J_HALT_NWARN", -1)

trunc = d.get("truncations") or []
put("J_NTRUNC", len(trunc))
keys = [str(t.get("section", "?")) for t in trunc]
put("J_TRUNC_KEYS", " ".join(keys))
pris = [PRI.get(k, 99) for k in keys]
put("J_MAXPRI", max(pris) if pris else 0)
put("J_MONOTONE", 1 if all(pris[i] <= pris[i + 1] for i in range(len(pris) - 1)) else 0)
put("J_CONST_TRUNCATED", 1 if "constitution_clauses" in keys else 0)
put("J_UNKNOWN_SECTION", 1 if any(p == 99 for p in pris) else 0)
put("J_FIRST_SK", keys.index("starterkit_slice") if "starterkit_slice" in keys else -1)
put("J_FIRST_DS", keys.index("design_slice") if "design_slice" in keys else -1)
put("J_SK_RULES", " || ".join(str(t.get("rule_applied")) for t in trunc
                              if t.get("section") == "starterkit_slice"))
put("J_SUM_SAVED", sum(int(t.get("bytes_saved") or 0) for t in trunc))
put("J_ZERO_SAVE", 1 if any(int(t.get("bytes_saved") or 0) <= 0 for t in trunc) else 0)

emitted = d.get("sections_emitted") or []
omitted = [str(o.get("section", "?")) for o in (d.get("sections_omitted") or [])]
put("J_EMITTED", " ".join(str(x) for x in emitted))
put("J_OMITTED", " ".join(omitted))
kb = [o for o in (d.get("sections_omitted") or []) if o.get("section") == "kb_anti_patterns"]
put("J_KB_REASON", kb[0].get("reason", "") if kb else "")
warns = d.get("warnings") or []
put("J_NWARN", len(warns))
put("J_WARNINGS", " ||| ".join(str(w) for w in warns))
put("J_NSOFT", len(d.get("soft_halts") or []))
put("J_INLINE_BYTES", d.get("inline_core_bytes", -1))
put("J_INLINE", (d.get("inline_core") or "")[:400])

with open(rulef, "w", encoding="utf-8") as f:
    for t in trunc:
        f.write("%s\t%s\t%s\n" % (t.get("section", "?"), t.get("rule_applied", "?"),
                                  t.get("bytes_saved", "?")))

# ── the emitted artifact (the thing the subagent actually reads) ──────────────
ppath = d.get("prompt_path") or fallback_prompt
put("J_PROMPT_PATH", ppath)
try:
    with open(ppath, encoding="utf-8") as f:
        P = f.read()
except Exception:
    P = ""
put("P_EXISTS", 1 if P else 0)
put("P_BYTES", len(P.encode("utf-8")))
L = P.splitlines()


def sect(header):
    """Lines of the block starting at `header` up to the next '## '/'### ' line."""
    for i, ln in enumerate(L):
        if ln.strip() == header or ln.startswith(header):
            body = []
            for j in range(i + 1, len(L)):
                if L[j].startswith("## ") or L[j].startswith("### ") or \
                   L[j].startswith("═══"):
                    break
                body.append(L[j])
            return body
    return None


put("P_HAS_VALIDATION", 1 if "## Validation hints" in P else 0)
put("P_HAS_MEMORY", 1 if "## Historical memory" in P else 0)
put("P_HAS_CONFIDENCE", 1 if "## Confidence labels per claim" in P else 0)
put("P_HAS_UPSTREAM", 1 if "## Upstream bolts" in P else 0)
put("P_HAS_PACKRULES", 1 if "## Framework pack rules" in P else 0)
put("P_HAS_CONST", 1 if "## Constitution clauses" in P else 0)
put("P_HAS_STARTERKIT", 1 if "### Starterkit context" in P else 0)
put("P_HAS_DESIGN", 1 if "## Design system (UI-bearing unit" in P else 0)
put("P_HAS_MAPPAT", 1 if "Codebase patterns:" in P else 0)
put("P_HAS_TRACKER", 1 if "### T2 budget tracker" in P else 0)
put("P_HAS_TOKENS", 1 if re.search(r"(?m)^Design tokens:", P) else 0)
put("P_HAS_DESIGNSYS_LINE", 1 if re.search(r"(?m)^Design system:", P) else 0)
put("P_HAS_EXAMPLE", 1 if "### Reference code example" in P else 0)
put("P_HAS_UIHEUR", 1 if "### UI design quality heuristics" in P else 0)
put("P_HAS_KB", 1 if "## KB anti-patterns" in P else 0)
put("P_HAS_TRACE", 1 if "mega-sdd-trace:execute-bolts:" in P else 0)

# T2 EMIT order is the TEMPLATE's order and is deliberately NOT the cascade's
# priority order (build-dispatch-prompt.sh EMIT_ORDER). Conflating the two is the
# exact mistake this suite exists to catch, so the emitted sequence is pinned.
ORDER_MARK = [
    ("## Upstream bolts", "depends_on"), ("## Framework pack rules", "pack"),
    ("## Constitution clauses", "constitution"), ("## Historical memory", "memory"),
    ("### Reuse index (filtered slice)", "reuse"), ("Codebase patterns:", "map"),
    ("### Starterkit context", "starterkit"),
    ("## Design system (UI-bearing unit", "design"),
    ("## Confidence labels per claim", "confidence"),
    ("## Validation hints", "validation"),
]
seq = []
for ln in L:
    for mark, tok in ORDER_MARK:
        if ln.startswith(mark):
            seq.append(tok)
            break
put("P_SECTION_ORDER", " ".join(seq))

# reuse slice — floor is the literal hint line, NEVER an empty section
rb = sect("### Reuse index (filtered slice)")
put("P_REUSE_HEADER", 1 if rb is not None else 0)
if rb is None:
    put("P_REUSE_ENTRIES", -1)
    put("P_REUSE_SENTINEL", 0)
else:
    put("P_REUSE_ENTRIES", sum(1 for x in rb if x.startswith("- ")))
    put("P_REUSE_SENTINEL",
        1 if any(re.match(r"^\+\d+ more — read reuse-index\.yaml directly$", x) for x in rb) else 0)

ub = sect("## Upstream bolts")
put("P_UPSTREAM_ENTRIES", sum(1 for x in (ub or []) if re.match(r"^- U-", x)))
put("P_PACK_IDS", len(re.findall(r"framework-pack-[a-z0-9-]+-\d{3}", P)))
put("P_CLAUSE_IDS", " ".join(re.findall(r"(?m)^- §([A-F]-\d{3}):", P)))
# A-001 carries the ballast body. Its LENGTH in the emitted prompt is the direct
# "priority 9 is never truncated" probe: an id list alone would still pass if a
# future ladder clipped clause BODIES instead of dropping whole clauses.
m = re.search(r"(?m)^- §A-001: (.*)$", P)
put("P_CONST_A001_LEN", len(m.group(1)) if m else -1)

cb = sect("## Confidence labels per claim")
agg = 0
if cb:
    for x in cb:
        if re.match(r"^(?:HIGH|MEDIUM|LOW|OQ)×\d+(?: / (?:HIGH|MEDIUM|LOW|OQ)×\d+)*$", x.strip()):
            agg = 1
put("P_CONF_AGG", agg)
put("P_CONF_PERCLAIM", 1 if re.search(r"(?m)^- \[(?:HIGH|MEDIUM|LOW|OQ)\] ", P) else 0)

m = re.search(r"(?m)^Design tokens:.*?spacing=([^;]*);", P)
put("P_TOKENS_SPACING", (m.group(1).strip() if m else ""))
m = re.search(r"(?m)^UI/UX:.*idioms=\[(.*)\]\s*$", P)
put("P_IDIOMS", len([x for x in m.group(1).split(";") if x.strip()]) if m else -1)
m = re.search(r"(?m)^Libs in scope: (.*)$", P)
put("P_LIBS", len(re.findall(r"\(used in: ", m.group(1))) if m else -1)

tb = None
for i, ln in enumerate(L):
    if ln.strip() == "### T2 budget tracker":
        tb = L[i:i + 400]
        break
if tb is None:
    put("P_TRACKER_ROWS", -1)
    put("P_TRACKER_T1", -1)
    put("P_TRACKER_T2", -1)
    put("P_TRACKER_NONE", 0)
    put("P_TRACKER_INSTR", 0)
else:
    rows = [x for x in tb if re.match(r"^  - \S+: .* \(saved -?\d+ bytes\)$", x)]
    put("P_TRACKER_ROWS", len(rows))
    put("P_TRACKER_NONE", 1 if any(x.strip() == "- (none)" for x in tb) else 0)
    put("P_TRACKER_INSTR", 1 if any(x.startswith("instruction_to_subagent:") for x in tb) else 0)
    m1 = re.search(r"consumed_t1: (\d+) bytes", "\n".join(tb))
    m2 = re.search(r"consumed_t2: (\d+) bytes", "\n".join(tb))
    put("P_TRACKER_T1", m1.group(1) if m1 else -1)
    put("P_TRACKER_T2", m2.group(1) if m2 else -1)
    # entry-for-entry parity with truncations[]
    parity = 1 if len(rows) == len(trunc) else 0
    if parity:
        for row, t in zip(rows, trunc):
            want = "  - %s: %s (saved %s bytes)" % (t.get("section"), t.get("rule_applied"),
                                                    t.get("bytes_saved"))
            if row != want:
                parity = 0
                break
    put("P_TRACKER_PARITY", parity)

if "P_TRACKER_PARITY" not in "\n".join(out):
    put("P_TRACKER_PARITY", 0)

with open(varf, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
PYEOF

# ══════════════════════════════════════════════════════════════════════════════
# keys.py — the DEFAULT-stdout shape probe (section L). Deliberately separate
# from summarize.py: summarize.py reads the --explain shape and would report -1
# for a missing key, which cannot distinguish "absent" from "present and -1".
# This one prints the literal top-level key SET.
# ══════════════════════════════════════════════════════════════════════════════
cat > "${WORK}/keys.py" <<'PYEOF'
# -*- coding: utf-8 -*-
import json
import os
import sys

jf, varf = sys.argv[1], sys.argv[2]
out = []


def put(k, v):
    out.append("%s='%s'" % (k, str(v).replace("'", "'\\''")))


try:
    with open(jf, encoding="utf-8") as f:
        d = json.loads(f.read())
except Exception:
    d = None

if isinstance(d, dict):
    put("K_JSON", 1)
    put("K_KEYS", " ".join(sorted(d.keys())))
    put("K_NKEYS", len(d))
    put("K_INLINE_LEN", len(d.get("inline_core") or ""))
    # The design lens's rubric travels as a PATH to a neutral lens-input file,
    # not as a pasted string. Both are probed: the path key that ships, and the
    # retired TEXT key — a suite that only knew about the new name would let the
    # 9.6 KB/bolt string return to the input channel unnoticed.
    put("K_HAS_DSP", 1 if "design_slice_path" in d else 0)
    put("K_DSP", d.get("design_slice_path") or "")
    put("K_DSP_EMPTY", 1 if d.get("design_slice_path") == "" else 0)
    put("K_HAS_DSTEXT", 1 if "design_slice_text" in d else 0)
    put("K_T1", d.get("t1_bytes", -1))
    put("K_T2", d.get("t2_bytes", -1))
    put("K_TOTAL_BYTES", d.get("total_bytes", -1))
    put("K_FILE_BYTES", d.get("file_bytes", -1))
    # The artifact as it exists on disk — the ONLY honest check of `file_bytes`.
    try:
        put("K_PROMPT_BYTES", os.path.getsize(d.get("prompt_path") or ""))
    except OSError:
        put("K_PROMPT_BYTES", -1)
    put("K_BYTES", len(json.dumps(d, ensure_ascii=False, indent=2)))
else:
    put("K_JSON", 0)
    put("K_KEYS", "")
    put("K_NKEYS", -1)
    put("K_INLINE_LEN", -1)
    put("K_HAS_DSP", -1)
    put("K_DSP", "")
    put("K_DSP_EMPTY", -1)
    put("K_HAS_DSTEXT", -1)
    put("K_T1", -1)
    put("K_T2", -1)
    put("K_TOTAL_BYTES", -1)
    put("K_FILE_BYTES", -1)
    put("K_PROMPT_BYTES", -1)
    put("K_BYTES", -1)

with open(varf, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
PYEOF

# ══════════════════════════════════════════════════════════════════════════════
# slice.py — section O only. Compares the lens-input FILE against the dispatch
# prompt BYTE FOR BYTE. Deliberately not a grep: the claim is "the same bytes are
# still in the prompt", and a line-oriented tool cannot distinguish a verbatim
# block from a coincidentally similar one.
# ══════════════════════════════════════════════════════════════════════════════
cat > "${WORK}/slice.py" <<'PYEOF'
# -*- coding: utf-8 -*-
import os
import sys

slicef, promptf, varf = sys.argv[1], sys.argv[2], sys.argv[3]
out = []


def put(k, v):
    out.append("%s='%s'" % (k, str(v).replace("'", "'\\''")))


try:
    with open(slicef, encoding="utf-8") as f:
        S = f.read()
except Exception:
    S = ""
try:
    with open(promptf, encoding="utf-8") as f:
        P = f.read()
except Exception:
    P = ""

put("S_EXISTS", 1 if os.path.exists(slicef) else 0)
put("S_BYTES", len(S.encode("utf-8")))
put("P2_BYTES", len(P.encode("utf-8")))
# The file is written as `<slice text>\n`; the prompt holds the slice text
# itself. Compare the stripped body, and only when there IS a body — an empty
# string is a substring of everything and would make the claim vacuous.
body = S.rstrip("\n")
put("S_BODY_BYTES", len(body.encode("utf-8")))
put("S_IN_PROMPT", 1 if (body and body in P) else 0)
put("S_HAS_MARKER", 1 if any(x.startswith("Design system:") for x in body.splitlines()) else 0)
with open(varf, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
PYEOF

# ══════════════════════════════════════════════════════════════════════════════
# FIXTURE BUILDERS
# ══════════════════════════════════════════════════════════════════════════════

pad_file() {  # pad_file <path> <nbytes>
  if [ "$2" -le 0 ]; then : > "$1"; return; fi
  printf '%*s' "$2" '' | tr ' ' 'x' > "$1"
}

# A CONTROLLED plugin root for the WALK fixture. Two reasons, both structural:
#
#  1. `references/ui-design-heuristics.md` is ~4.8KB and — per
#     starterkit-enrichment.md §"Un-budgeted by this ladder" — has NO truncation
#     rung. With the shipped file the rich fixture's T2 starts far ABOVE cap_t2,
#     so the cascade is already at priority 8 before the walk begins (measured:
#     21 rungs at zero ballast) and priorities 1..7 are unreachable.
#  2. The shipped pack bodies are hand-authored prose that will be edited; a walk
#     whose starting point depends on their byte count is a suite that fails as a
#     phantom "cascade regression" the next time someone rewords a rationale.
#
# The pack CHAIN is still resolved by the real resolver (starterkit-context.yaml
# `framework_pack: laravel` -> `laravel.md _universal.md`); only the BODIES are
# fixture-controlled. A consequence worth stating: the WALK fixture's T2 is then
# 100% fixture-controlled (packs, heuristics, constitution, starterkit, reuse,
# memory, binding, upstreams — no shipped reference file feeds it), which is what
# makes the A0 "starts under cap_t2" headroom stable rather than lucky. Do not
# undo that by pointing the walk at the real plugin root.
#
# The SHIPPED packs and the shipped design-intelligence bodies are still
# exercised: sections E, F and G run against the real plugin root, and E3
# explicitly asserts the shipped pack chain produces priority-7 rules and honors
# the "keep top 1" floor — so that floor is never proven by the fixture pack alone.
# The `view`/`component` exemplar categories are covered by the sibling shape
# suite (tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh §A, which
# runs the live validator and asserts exemplar_missing == 0); this suite carries
# ONE wide controller exemplar because the rung economics below demand it.
mk_miniplugin() {  # mk_miniplugin <dir>
  local M="$1"
  mkdir -p "$M/references/framework-conventions" "$M/.claude-plugin"
  cp "${PLUGIN}/.claude-plugin/plugin.json" "$M/.claude-plugin/" 2>/dev/null
  printf '# UI design quality heuristics\n\n- Prefer real hierarchy over uniform blocks.\n' \
    > "$M/references/ui-design-heuristics.md"
  # SIX distinct path_glob records, one per fixture target file, so the
  # priority-7 ladder (all -> top 5 -> top 3 -> top 1) is fully non-degenerate.
  cat > "$M/references/framework-conventions/laravel.md" <<'EOF'
---
framework: laravel
extends: _universal
---

# Fixture convention pack

## Hard Rules emitted

```
HARD_RULE: Migrations use timestamp naming
  path_glob: database/migrations/*.php
  rule_type: NAMING_RULE
HARD_RULE: Models are PascalCase singular
  path_glob: app/Models/*.php
  rule_type: NAMING_RULE
HARD_RULE: Controllers end with Controller
  path_glob: app/Http/Controllers/**/*.php
  rule_type: NAMING_RULE
HARD_RULE: Requests end with Request
  path_glob: app/Http/Requests/*.php
  rule_type: NAMING_RULE
HARD_RULE: Routes carry no business logic
  path_glob: routes/*.php
  rule_type: CUSTOM
HARD_RULE: Views live under resources/views
  path_glob: resources/views/**/*.blade.php
  rule_type: NAMING_RULE
```
EOF
  printf '# universal fixture overlay\n\n## Hard Rules emitted\n\n```\n```\n' \
    > "$M/references/framework-conventions/_universal.md"
}

mk_source_tree() {  # the repo files anchors / exemplars / globs point at
  local P="$1" i
  mkdir -p "$P/app/Http/Controllers" "$P/app/Http/Requests" "$P/app/Models" \
           "$P/database/migrations" "$P/routes" "$P/resources/views/orders"
  # ONE exemplar, 91 lines. Two constraints make this size load-bearing:
  #   * >50 lines AND the 41 trimmed lines must save MORE than the ~105 bytes the
  #     trim ADDS (a "# ... (truncated at 50 lines …)" marker plus a
  #     "(truncated — full file available via Read tool)" notice). With shorter
  #     lines the level-2 candidate is LONGER than level 1, the builder skips the
  #     rung (`if len(cand) < len(_lv[-1])`), and the D-section order assertion
  #     silently tests nothing. A single wide exemplar buys the rung inside the
  #     T2 budget where two narrow ones did not.
  #   * <3072 bytes, so the builder's own 100-line pre-cap does not pre-empt it.
  { echo "<?php"; for i in $(seq 1 90); do echo "// ctrl line $i"; done
  } > "$P/app/Http/Controllers/OrderController.php"
  { echo "<?php"; for i in $(seq 1 40); do echo "// Order model line $i"; done
  } > "$P/app/Models/Order.php"
  printf "@extends('layouts.app')\n@section('content')\n@endsection\n" \
    > "$P/resources/views/orders/show.blade.php"
  echo "<?php // routes" > "$P/routes/web.php"
  echo "<?php // request" > "$P/app/Http/Requests/StoreOrderRequest.php"
  echo "<?php // migration" > "$P/database/migrations/2026_01_01_000000_create_orders_table.php"
}

mk_unit() {  # mk_unit <vault> <starterkit_relevance-flow-list> <body-pad-bytes>
  local V="$1" REL="$2" BODYPAD="${3:-0}"
  mkdir -p "$V/units"
  cat > "$V/units/U-050.md" <<UNITEOF
---
id: U-050
title: Render the order detail view
task_type: create
module: orders
risk: medium
status: pending
scope: S-01
scope_name: Orders
depends_on: [U-001, U-002, U-003, U-004, U-005]
binding_refs: [C-001, C-002, C-003, C-004]
starterkit_relevance: ${REL}
reuse_candidates:
  - name: formatCurrency
    path: app/Support/Money.php
    signature: formatCurrency(int \$cents): string
    purpose: render money for display
target_files:
  - path: resources/views/orders/show.blade.php
    operation: create
  - path: app/Http/Controllers/OrderController.php
    operation: modify
  - path: app/Models/Order.php
    operation: modify
  - path: app/Http/Requests/StoreOrderRequest.php
    operation: create
  - path: database/migrations/2026_01_01_000000_create_orders_table.php
    operation: create
  - path: routes/web.php
    operation: modify
acceptance_test:
  - type: command
    command: ./vendor/bin/phpunit --filter OrderDetailTest
    expects: OK (3 tests, 7 assertions)
    desc: order detail renders totals and the tax breakdown block
  - type: command
    command: ./vendor/bin/pint --test app/Http/Controllers/OrderController.php
    expects: PASS
    desc: controller passes the formatter
  - type: manual
    desc: visually verify the totals block at mobile width
  _authored_by: same-pass
properties:
  - id: PROP-001
    severity: error
    invariant: order total equals the sum of line items plus tax
    cites: 03-data-model.md:12
---

## Goal

Render the order detail view with a tax breakdown.

## Governing clauses

This unit is governed by A-001, A-002, A-003 and B-001.
(Heading deliberately NOT "## Constitution clauses": the unit body is emitted
verbatim into T1, and that spelling would collide with the T2 section marker.)

## Anchors

- app/Http/Controllers/OrderController.php:12
- app/Models/Order.php:5

## Hard rules

- DO NOT modify database/migrations/2026_01_01_000000_create_orders_table.php
- MUST route authorization through the existing OrderPolicy

## Notes

UNITEOF
  if [ "$BODYPAD" -gt 0 ]; then
    pad_file "${WORK}/.bodypad" "$BODYPAD"
    printf 'PADDING: ' >> "$V/units/U-050.md"
    cat "${WORK}/.bodypad" >> "$V/units/U-050.md"
    printf '\n' >> "$V/units/U-050.md"
  fi
}

# A SECOND unit shape, for section J only: the rich U-050 above is deliberately
# maximal (6 target_files, 5 depends_on, a 3-entry acceptance_test, a properties
# block) and its T1 lands at p75 of the measured distribution — it cannot be
# padded DOWN to the median. This one is trimmed to the middle of
# `unit-schema.md`'s range so section J can drive T1 onto the median by padding
# UP. `_authored_by: adversarial-reviewed` is load-bearing twice: it is the
# strong-provenance value (so the ~689-byte acceptance-test NOTE is correctly
# NOT emitted — the F7 region-asymmetry fix), and dropping that block is what
# buys the headroom to reach the median.
mk_normal_unit() {  # mk_normal_unit <vault> <body-pad-bytes>
  local V="$1" BODYPAD="${2:-0}"
  mkdir -p "$V/units"
  cat > "$V/units/U-050.md" <<UNITEOF
---
id: U-050
title: Render the order detail view
task_type: modify
module: orders
risk: medium
status: pending
scope: S-01
scope_name: Orders
depends_on: [U-001, U-002]
binding_refs: [C-001, C-002]
starterkit_relevance: [auth, authz, ui_ux, libs]
reuse_candidates:
  - name: formatCurrency
    path: app/Support/Money.php
    signature: formatCurrency(int \$cents): string
    purpose: render money for display
target_files:
  - path: resources/views/orders/show.blade.php
    operation: create
  - path: app/Http/Controllers/OrderController.php
    operation: modify
  - path: app/Models/Order.php
    operation: modify
acceptance_test:
  - type: command
    command: ./vendor/bin/phpunit --filter OrderDetailTest
    expects: OK (3 tests, 7 assertions)
    desc: order detail renders totals and the tax breakdown block
  _authored_by: adversarial-reviewed (+2 gaps merged)
---

## Goal

Render the order detail view with a tax breakdown. Governed by A-001.

## Anchors

- app/Http/Controllers/OrderController.php:12

## Hard rules

- MUST route authorization through the existing OrderPolicy

## Notes

UNITEOF
  if [ "$BODYPAD" -gt 0 ]; then
    pad_file "${WORK}/.bodypad" "$BODYPAD"
    printf 'PADDING: ' >> "$V/units/U-050.md"
    cat "${WORK}/.bodypad" >> "$V/units/U-050.md"
    printf '\n' >> "$V/units/U-050.md"
  fi
}

mk_vault_json() {  # mk_vault_json <vault>
  cat > "$1/vault.json" <<'EOF'
{
  "vault": "v1",
  "scope_metadata": {"id": "S-01", "name": "Orders"},
  "design_system": {
    "style": "minimalism",
    "palette": "trust-blue",
    "typography": "Inter",
    "a11y_level": "AA",
    "source": "scanned-template",
    "provenance": "audit-only, must never be injected"
  }
}
EOF
}

mk_binding() {  # mk_binding <vault>
  cat > "$1/binding.md" <<'EOF'
# Binding Manifest

## Confirmed Claims
- C-001 | 03-data-model.md:12 | app/Models/Order.php:5 | Order carries a total_cents integer column
- C-002 | 04-flows.md:8 | app/Http/Controllers/OrderController.php:12 | Detail view shows the tax breakdown
- C-003 | 03-data-model.md:30 | app/Models/Order.php:20 | Orders are soft-deletable
- C-004 | 04-flows.md:20 | routes/web.php:1 | Order detail is reachable at /orders/{order}

## Implementation State Map (4)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | app/Models/Order.php:5 | high | n/a |
| C-002 | CONFIRMED | IMPLEMENTED | app/Http/Controllers/OrderController.php:12 | medium | n/a |
| C-003 | CONFIRMED | PARTIAL | app/Models/Order.php:20 | low | n/a |
| C-004 | CONFIRMED | IMPLEMENTED | routes/web.php:1 | high | n/a |
EOF
}

mk_upstreams() {  # mk_upstreams <vault> — 5 upstreams so all->3->1 is non-degenerate
  local V="$1" i
  for i in 1 2 3 4 5; do
    mkdir -p "$V/bolts/U-00$i"
    cat > "$V/bolts/U-00$i/bolt-report.md" <<EOF
---
unit_id: U-00$i
status: completed
attempted_at: 2026-07-0${i}T09:00:00Z
retries: 0
commits: [abc123def456789${i}]
---

## Summary

Upstream bolt number $i finished its slice of the orders module.

bolt_self_report:
  confidence: 0.9
  certain_decisions:
    - Reused OrderPolicy for bolt $i
  uncertain_decisions: []
EOF
    mkdir -p "$V/units"
    printf -- '---\nid: U-00%s\ntitle: Upstream %s\n---\n' "$i" "$i" \
      > "$V/units/U-00$i.md"
  done
}

mk_reuse_index() {  # mk_reuse_index <project>
  mkdir -p "$1/.mega-sdd/codebase"
  cat > "$1/.mega-sdd/codebase/reuse-index.yaml" <<'EOF'
truncated: {helpers: false, services: false}
helpers:
  - name: formatCurrency
    path: app/Models/Order.php
    purpose: format cents
    _source: app/Models/Order.php:14
  - name: taxFor
    path: app/Models/Order.php
    purpose: compute tax
    _source: app/Models/Order.php:22
model_api:
  - model: Order
    path: app/Models/Order.php
    methods: ["total(): int   @44"]
    _source: app/Models/Order.php:1
  - model: OrderLine
    path: app/Models
    methods: ["order(): BelongsTo"]
    _source: app/Models/OrderLine.php:1
services:
  - class: OrderTotalsService
    path: app/Http/Controllers/OrderController.php
    purpose: assemble totals
    _source: app/Http/Controllers/OrderController.php:60
commands:
  - signature: orders:recalculate {order}
    path: routes/web.php
    purpose: recompute totals
    _source: routes/web.php:1
EOF
}

mk_memory() {  # mk_memory <project> — 5 runs: the minimum that keeps 5->3->1 non-degenerate
  local P="$1" i
  mkdir -p "$P/.mega-sdd/memory"
  : > "$P/.mega-sdd/memory/outcomes.md"
  echo "# Outcomes" >> "$P/.mega-sdd/memory/outcomes.md"
  for i in 1 2 3 4 5; do
    cat >> "$P/.mega-sdd/memory/outcomes.md" <<EOF

## Run #$i
- bolt U-00$i touched OrderController.php, green
EOF
  done
}

mk_starterkit() {  # mk_starterkit <project>
  local P="$1" i
  mkdir -p "$P/.mega-sdd/codebase"
  cat > "$P/.mega-sdd/codebase/starterkit-context.yaml" <<'EOF'
framework_pack: laravel
auth:
  lib: laravel/sanctum
  mechanism: session
  user_model: App\Models\User
authz:
  lib: spatie/laravel-permission
  mechanism: gate
  declarations:
    - name: orders.view
    - name: orders.update
ui_ux:
  layout_extends: layouts.app
  notification_lib: sweetalert2
  idioms:
    - "toast on success"
    - "modal confirm"
    - "inline field errors"
    - "sticky table header"
    - "empty-state art"
  design_tokens:
    colors:
      primary: "#2563EB"
      surface: "#F8FAFC"
      danger: "#DC2626"
    spacing: "4px, 8px, 12px, 16px, 24px, 32px, 48px"
    fonts:
      - Inter
      - JetBrains Mono
patterns:
  controller:
    location: app/Http/Controllers
    naming: "{Model}Controller"
    extension: php
    extras:
      base_class: Controller
      middleware: auth
    _source:
      - app/Http/Controllers/OrderController.php:1
libs:
EOF
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    cat >> "$P/.mega-sdd/codebase/starterkit-context.yaml" <<EOF
  - name: pkg$i
    version: 1.$i.0
    usage_hint:
      - app/Http/Controllers
EOF
  done
}

mk_constitution() {  # mk_constitution <vault> <pad-bytes>
  local V="$1" N="$2"
  pad_file "${WORK}/.cpad" "$N"
  {
    echo "# Constitution"
    echo
    echo "## Section A — data + audit"
    echo
    printf -- '- A-001: audit log every order write '
    cat "${WORK}/.cpad"
    printf '\n'
    echo "- A-002: retain audit records"
    echo "- A-003: mask PII in views"
    echo
    echo "## Section B — write endpoints"
    echo
    echo "- B-001: writes are idempotent"
  } > "$V/constitution.md"
}

mk_codebase_map() {  # mk_codebase_map <project> <framework-or-empty> <ballast-rows>
  local P="$1" FW="$2" ROWS="${3:-0}" i
  mkdir -p "$P/.mega-sdd/codebase"
  {
    echo "---"
    [ -n "$FW" ] && echo "framework: $FW"
    echo "---"
    echo
    echo "## 6. Pattern signatures"
    echo
    echo "- auth pattern: session guard via the framework auth middleware"
    echo "- error handling: a single exception renderer maps domain errors to responses"
    echo "- state: server-rendered views, no client store"
    echo "- view/component pattern: layout inheritance with named sections"
    for i in $(seq 1 "$ROWS"); do
      echo "- ballast signature $i: a verbatim pattern-signature row carried from the codebase map scan pass"
    done
    echo
    echo "## 7. Something else"
  } > "$P/.mega-sdd/codebase/codebase-map.md"
}

# ══════════════════════════════════════════════════════════════════════════════
# PROBE
# ══════════════════════════════════════════════════════════════════════════════
FIX_P=""; FIX_V=""; FIX_UNIT="U-050"; FIX_PLUGIN=""
BALLAST_MODE="const"

set_ballast() {
  case "$BALLAST_MODE" in
    const) mk_constitution "$FIX_V" "$1" ;;
    map)   mk_codebase_map "$FIX_P" "${MAP_FW:-}" "$1" ;;
    none)  : ;;
  esac
}

RC=0
# --explain IS LOAD-BEARING FOR THE WALK, not a convenience. Default stdout is
# the SLIM controller shape (context-enrichment.md §stdout JSON): no `caps`, no
# `sections_emitted`, no `sections_omitted`. The rung walk's step size is
# `N + (cap_t2 - consumed_t2) + 1` and its continue-guard is `t2 > cap_t2`, so
# without `caps.cap_t2` the guard compares against -1, breaks on iteration 0, and
# the whole cascade walk silently tests NOTHING while still reporting PASSes.
# No other channel carries cap_t2 (the in-prompt tracker prints it inside a prose
# line the suite would have to re-parse). Do NOT "simplify" this flag away.
# Section L asserts the DEFAULT (no --explain) shape, so the slimming itself
# stays covered.
probe() {  # probe <ballast>
  set_ballast "$1"
  local extra=""
  [ -n "$FIX_PLUGIN" ] && extra="--plugin-root=$FIX_PLUGIN"
  # shellcheck disable=SC2086
  bash "$BUILDER" --cwd="$FIX_P" --vault="$FIX_V" --unit="$FIX_UNIT" $extra --explain \
    </dev/null >"${WORK}/out.json" 2>"${WORK}/err.txt"
  RC=$?
  # shellcheck disable=SC2086
  $PY "${WORK}/summarize.py" "${WORK}/out.json" \
        "${FIX_V}/bolts/${FIX_UNIT}/dispatch-prompt.md" \
        "${WORK}/vars.sh" "${WORK}/rules.txt"
  # shellcheck disable=SC1090
  . "${WORK}/vars.sh"
}

sk_rules() { awk -F'\t' '$1=="starterkit_slice"{print $2}' "${WORK}/rules.txt"; }
sk_rule_idx() { awk -F'\t' -v want="$1" '$1=="starterkit_slice"{n++; if ($2==want) {print n; exit}}' "${WORK}/rules.txt"; }

# ── floor predicates, one per documented drop floor ──────────────────────────
floor_ok() {  # floor_ok <priority> -> 0 when that priority sits at its DOCUMENTED floor
  case "$1" in
    1) [ "$P_HAS_VALIDATION" = "0" ] && has "$J_OMITTED" validation_hints ;;
    # NEVER fully dropped: header + the literal hint line survive, zero entries
    3) [ "$P_REUSE_HEADER" = "1" ] && [ "$P_REUSE_SENTINEL" = "1" ] \
       && [ "$P_REUSE_ENTRIES" = "0" ] && ! has "$J_OMITTED" reuse_slice ;;
    5) [ "$P_HAS_CONFIDENCE" = "0" ] && has "$J_OMITTED" confidence_labels ;;
    6) [ "$P_HAS_UPSTREAM" = "1" ] && [ "$P_UPSTREAM_ENTRIES" = "1" ] ;;   # keep >=1
    7) [ "$P_HAS_PACKRULES" = "1" ] && [ "$P_PACK_IDS" = "1" ] ;;          # keep top 1
    8) [ "$P_HAS_STARTERKIT" = "1" ] && [ "$P_HAS_TOKENS" = "0" ] \
       && [ "$P_HAS_EXAMPLE" = "0" ] ;;
    *) return 1 ;;
  esac
}

floor_label() {
  case "$1" in
    1) echo "validation_hints -> section dropped" ;;
    3) echo "reuse_slice -> hint line only, NEVER dropped" ;;
    5) echo "confidence_labels -> section dropped" ;;
    6) echo "depends_on_summaries -> >=1 upstream kept" ;;
    7) echo "framework_pack_rules -> top 1 kept" ;;
    8) echo "starterkit_slice -> tokens+examples dropped, slice survives" ;;
  esac
}

# The SIX rung labels of starterkit-enrichment.md §Slice truncation order,
# verbatim — they are the strings the builder logs as `rule_applied`.
R_LIBS="libs -> top 10 by target_files overlap"
R_EX50="code_examples -> first 50 lines"
R_IDIOM="ui_ux.idioms -> top 3"
R_TOKC="design_tokens compacted (keep colors+fonts; spacing -> scale name)"
R_EXDROP="drop code_examples (patterns metadata preserved)"
R_TOKDROP="drop the remaining design_tokens line (drop floor)"

echo "════════════════════════════════════════════════════════════════"
echo "  A. RICH FIXTURE — rung-by-rung cascade walk (priorities 1..8)"
echo "════════════════════════════════════════════════════════════════"

MINI="${WORK}/miniplugin"
mk_miniplugin "$MINI"

RICH="${WORK}/rich"
FIX_P="$RICH"; FIX_V="${RICH}/.mega-sdd/vaults/v1"; BALLAST_MODE="const"; FIX_PLUGIN="$MINI"
mkdir -p "$FIX_V/units" "$FIX_V/bolts"
mk_source_tree "$RICH"
mk_unit "$FIX_V" "[auth, authz, ui_ux, libs]" 0
mk_vault_json "$FIX_V"
mk_binding "$FIX_V"
mk_upstreams "$FIX_V"
mk_reuse_index "$RICH"
mk_memory "$RICH"
mk_starterkit "$RICH"

probe 0
eq "$J_JSON" "1" "A0 builder emitted parseable JSON on stdout (no --quiet)"
eq "$RC" "0" "A0 exit 0 at minimum ballast"
eq "$J_CAP_HARD" "12288" "A0 cap_hard is the canonical 12288"
eq "$J_CAP_T2" "10240" "A0 cap_t2 is the canonical 10240"
# cap_t1 was AMENDED 2026-07-31 from 2048 to 12288 (context-enrichment.md
# ## AMENDMENT — 123 measured runs). It is a REPORTING THRESHOLD, not a budget:
# T1 is never truncated and the unit body is verbatim, so no value of cap_t1
# bounds T1. At 2048 the warning fired on 123/123 runs — the builder's own
# NON-BODY scaffolding floors at 2385 B, so 2048 was satisfiable only when pack
# content was MISSING (the Windows App-Execution-Alias failure state).
eq "$J_CAP_T1" "12288" "A0 cap_t1 is the AMENDED 12288 reporting threshold"
eq "$J_CAP_TARGET" "9216" "A0 cap_target is the canonical 9216"

for s in validation_hints reuse_slice confidence_labels \
         depends_on_summaries framework_pack_rules starterkit_slice constitution_clauses; do
  if has "$J_EMITTED" "$s"; then ok "A0 fixture supplies $s"; else
    nok "A0 fixture supplies $s — MISSING, the cascade walk below would be vacuous (emitted: $J_EMITTED)"; fi
done
eq "$J_NTRUNC" "0" "A0 minimum ballast starts UNDER cap_t2 — cascade has room to be walked"
# EMIT order is the template's, NOT the cascade's — pinned so a "simplification"
# that emits in priority order is caught even though byte totals would not move.
eq "$P_SECTION_ORDER" \
   "depends_on pack constitution reuse starterkit confidence validation" \
   "A0 T2 sections are emitted in TEMPLATE order, not cascade-priority order"
chk "$P_HAS_TRACE" \
    "A0 emitted prompt carries the mega-sdd-trace gateway marker (v7.3.1 contract)" "gateway tag missing"

# priority 4 is contractually always-omitted (phantom join key)
if has "$J_OMITTED" kb_anti_patterns && ! has "$J_EMITTED" kb_anti_patterns; then
  ok "A0 priority 4 kb_anti_patterns OMITTED (phantom join key), never emitted"
else
  nok "A0 priority 4 kb_anti_patterns must be omitted and never emitted"
fi
case "$J_KB_REASON" in *"domain tags"*) ok "A0 kb_anti_patterns omission cites the phantom field" ;;
  *) nok "A0 kb_anti_patterns omission reason must name 'domain tags' — got '$J_KB_REASON'" ;; esac
eq "$P_HAS_KB" "0" "A0 no '## KB anti-patterns' section in the emitted prompt"

# ── the walk: N' = N + (cap_t2 - consumed_t2) + 1 fires EXACTLY one more rung ──
N=0
TOKC_N=""
PREV_KEYS=""
PREV_NTRUNC=-1
SEEN=""
MONO_OK=1
PREFIX_OK=1
CONST_OK=1
STEP=0
WALK_MAX=60
while [ "$STEP" -lt "$WALK_MAX" ]; do
  [ "$J_MONOTONE" = "1" ] || MONO_OK=0
  [ "$J_CONST_TRUNCATED" = "0" ] || CONST_OK=0
  case "$J_TRUNC_KEYS" in "$PREV_KEYS"*) : ;; *) PREFIX_OK=0 ;; esac

  if [ "$J_NTRUNC" -gt 0 ] && [ "$J_MAXPRI" -gt 0 ]; then
    p="$J_MAXPRI"
    if ! has "$SEEN" "$p"; then
      SEEN="$SEEN $p"
      # every LOWER priority present in this fixture must already be at its floor
      allfloor=1; why=""
      for q in 1 3 5 6 7 8; do
        [ "$q" -lt "$p" ] || continue
        if ! floor_ok "$q"; then allfloor=0; why="$why  p$q expected [$(floor_label "$q")]"; fi
      done
      if [ "$allfloor" = "1" ]; then
        ok "A1.$p first truncation at priority $p — all lower priorities already at their drop floor"
      else
        nok "A1.$p first truncation at priority $p but these are NOT at their drop floor —$why (ballast=$N, truncs=$J_TRUNC_KEYS)"
      fi
    fi
  fi

  # remember the pressure where design_tokens are COMPACTED but not yet DROPPED
  # — section D re-probes that exact point instead of walking a second time.
  if [ -z "$TOKC_N" ]; then
    case "$J_SK_RULES" in
      *"$R_TOKDROP"*) : ;;
      *"$R_TOKC"*) TOKC_N="$N" ;;
    esac
  fi

  PREV_KEYS="$J_TRUNC_KEYS"
  if [ "$J_T2" -lt 0 ]; then break; fi
  if [ "$J_T2" -gt "$J_CAP_T2" ]; then break; fi        # nothing left to truncate
  if [ "$J_NTRUNC" = "$PREV_NTRUNC" ] && [ "$STEP" -gt 0 ]; then break; fi
  PREV_NTRUNC="$J_NTRUNC"
  N=$(( N + (J_CAP_T2 - J_T2) + 1 ))
  STEP=$((STEP + 1))
  probe "$N"
done

chk "$MONO_OK" "A2 truncations[] priority sequence is NON-DECREASING at every rung" \
    "cascade truncated a higher-priority section before a lower one"
chk "$PREFIX_OK" "A2 truncation trail grows as a PREFIX as pressure rises" \
    "a rung already applied at lower pressure disappeared at higher pressure"
chk "$CONST_OK" "A2 constitution_clauses NEVER appears in truncations[] (priority 9)" \
    "priority 9 was truncated"
eq "$J_UNKNOWN_SECTION" "0" "A2 every truncated section is a row of the documented 9-row table"
eq "$J_ZERO_SAVE" "0" "A2 every logged rung saved >0 bytes (no no-op rung in the ladder)"

for p in 1 3 5 6 7 8; do
  if has "$SEEN" "$p"; then ok "A3 priority $p truncation level was reached and asserted"
  else nok "A3 priority $p was NEVER the deepest-truncated priority — its ladder is untested"; fi
done
if has "$SEEN" 4; then nok "A3 priority 4 fired — kb_anti_patterns must never be emitted"
else ok "A3 priority 4 never fires (section is contractually omitted)"; fi
if has "$SEEN" 2; then nok "A3 priority 2 fired — historical_memory was removed v7.3.0 and must never emit"
else ok "A3 priority 2 never fires (memory lane removed v7.3.0; always sections_omitted)"; fi
if has "$J_OMITTED" historical_memory; then ok "A3 historical_memory recorded in sections_omitted (v7.3.0 contract)"
else nok "A3 historical_memory missing from sections_omitted"; fi
if has "$SEEN" 9; then nok "A3 priority 9 fired — constitution must never truncate"
else ok "A3 priority 9 never fires"; fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  B. MAXIMUM PRESSURE — drop floors + the halt conjunction (+)"
echo "════════════════════════════════════════════════════════════════"

MAXBALLAST=400000
probe "$MAXBALLAST"
eq "$RC" "1" "B1 exit 1 at extreme pressure (dispatch_prompt_too_large)"
eq "$J_HALT" "dispatch_prompt_too_large" "B1 halt name"
eq "$J_STATUS" "halt" "B1 status=halt"
eq "$J_HALT_KEYS" "cap_hard halt t1_bytes t2_bytes total truncation_exhausted warnings" \
   "B1 halt payload carries exactly the documented §Size check fields"
eq "$J_HALT_EXH" "True" "B1 truncation_exhausted: true"
eq "$J_HALT_CAP" "12288" "B1 halt payload cap_hard"
chk "$([ "$J_HALT_TOTAL" -gt 12288 ] && echo 1 || echo 0)" \
    "B1 halt payload total exceeds cap_hard" "total=$J_HALT_TOTAL"
# SCOPE, because the next reader will be tempted to promote this into a
# builder-side invariant and that would be a chain-killer: non-empty is a
# property of THIS FIXTURE (a rich unit whose cascade genuinely spent every
# rung), NOT of the halt. On a unit with no priority-1..8 section at all the
# cascade spends nothing, the payload's warnings[] is legitimately EMPTY, and the
# halt is still correct — section N asserts exactly that arm. The two are only
# consistent because `truncation_exhausted` is DERIVED from term (a) rather than
# asserted as a literal; do not re-tighten either one against the other.
chk "$([ "$J_HALT_NWARN" -gt 0 ] && echo 1 || echo 0)" \
    "B1 halt payload warnings[] IS the truncation-event list (non-empty ON THIS RICH FIXTURE)" \
    "warnings empty — this fixture's cascade should have spent rungs before halting"
# the halt must be EARNED: priorities 1..8 must actually have been walked
eq "$J_MAXPRI" "8" "B1 halt fired only after the cascade reached priority 8"
allp=1
for k in validation_hints reuse_slice confidence_labels \
         depends_on_summaries framework_pack_rules starterkit_slice; do
  has "$J_TRUNC_KEYS" "$k" || { allp=0; echo "   (missing rung: $k)"; }
done
chk "$allp" "B1 halt state covers a rung from EVERY truncatable priority (2 removed v7.3.0; 4/9 never fire)" \
    "all_1_to_8_at_floor was vacuously true over a thin section set"
eq "$P_EXISTS" "1" "B1 dispatch-prompt.md is STILL WRITTEN on exit 1 (forensic evidence)"

# ── the four never-drop floors, asserted against the FILE at max pressure ──
eq "$P_REUSE_HEADER" "1" "B2 priority 3 reuse slice survives maximum pressure (header present)"
eq "$P_REUSE_SENTINEL" "1" "B2 priority 3 floor is the literal '+N more — read reuse-index.yaml directly'"
eq "$P_REUSE_ENTRIES" "0" "B2 priority 3 floor keeps NO entries — hint line only"
if has "$J_OMITTED" reuse_slice; then
  nok "B2 priority 3 must NEVER be recorded as dropped"
else ok "B2 priority 3 never recorded as dropped"; fi

eq "$P_HAS_PACKRULES" "1" "B3 priority 7 framework_pack_rules section survives"
eq "$P_PACK_IDS" "1" "B3 priority 7 floor keeps EXACTLY top 1 rule"

eq "$P_HAS_UPSTREAM" "1" "B4 priority 6 depends_on section survives"
eq "$P_UPSTREAM_ENTRIES" "1" "B4 priority 6 floor keeps exactly 1 upstream"

eq "$P_HAS_CONST" "1" "B5 priority 9 constitution section present at maximum pressure"
eq "$P_CLAUSE_IDS" "A-001 A-002 A-003 B-001" \
   "B5 priority 9 EVERY cited clause survives verbatim, in constitution file order"
chk "$([ "$P_CONST_A001_LEN" -ge "$MAXBALLAST" ] && echo 1 || echo 0)" \
    "B5 priority 9 clause BODIES are never clipped either (A-001 body >= ${MAXBALLAST}B)" \
    "A-001 body is $P_CONST_A001_LEN bytes — the clause was truncated"
# the shipped selector's [A-F]-NNN net also matches binding CLAIM ids; a
# binding_refs id must not mint a phantom '[clause not found]' marker
for c in C-001 C-002 C-003 C-004; do
  if has "$J_OMITTED" "constitution.$c"; then ok "B5 $c suppressed as a binding claim ref, not a clause"
  else nok "B5 $c must be recorded as a binding-claim-ref omission, not emitted as a clause"; fi
done

eq "$P_HAS_STARTERKIT" "1" "B6 priority 8 starterkit slice survives (floor is not empty)"
eq "$P_HAS_VALIDATION" "0" "B6 priority 1 floor IS an empty section"
eq "$P_HAS_MEMORY" "0" "B6 priority 2 floor IS an empty section"
eq "$P_HAS_CONFIDENCE" "0" "B6 priority 5 floor IS an empty section"

# ── B7: EVERY documented drop floor, through the ONE shared predicate ─────────
# B2..B6 above assert the floors one file-fact at a time. This sweep re-asserts
# all seven through `floor_ok` — the same predicate the section-A rung walk uses
# to decide "all lower priorities are already at their floor" — so the walk's
# verdict and the maximum-pressure verdict can never disagree about what a floor
# IS. It adds the half B2..B6 do not carry: for priorities 1/2/5 a dropped
# section must also be RECORDED in sections_omitted (silently vanishing is
# invariant #5's own failure mode), and for priority 3 the absence of such a
# record is itself the assertion.
#
# Re-asserted HERE, against the caps this run reported, because the caps stopped
# being a guess and became a measurement (cap_t1 2048 -> 12288): a cap move
# changes WHEN the cascade runs, and these floors are WHERE it is allowed to
# stop. They are independent contracts and a cap amendment must not quietly move
# a floor. No extra builder run — this reads section B's max-pressure probe.
for p in 1 3 5 6 7 8; do
  if floor_ok "$p"; then
    ok "B7 priority $p is at its documented drop floor at maximum pressure [$(floor_label "$p")] (caps: hard=$J_CAP_HARD t2=$J_CAP_T2 t1=$J_CAP_T1)"
  else
    nok "B7 priority $p is NOT at its documented drop floor [$(floor_label "$p")] — omitted: $J_OMITTED"
  fi
done

echo
echo "════════════════════════════════════════════════════════════════"
echo "  C. T2 BUDGET TRACKER — the subagent's self-reporting rail"
echo "════════════════════════════════════════════════════════════════"
eq "$P_HAS_TRACKER" "1" "C1 '### T2 budget tracker' block is emitted under truncation"
eq "$P_TRACKER_PARITY" "1" \
   "C1 truncations_applied names each truncated section + rule + bytes_saved, entry-for-entry"
chk "$([ "$P_TRACKER_ROWS" = "$J_NTRUNC" ] && echo 1 || echo 0)" \
    "C1 tracker row count == truncations[] length" "rows=$P_TRACKER_ROWS json=$J_NTRUNC"
eq "$P_TRACKER_T1" "$J_T1" "C1 tracker consumed_t1 matches the JSON"
eq "$P_TRACKER_T2" "$J_T2" "C1 tracker consumed_t2 matches the JSON"
eq "$P_TRACKER_INSTR" "1" "C1 tracker carries instruction_to_subagent (confidence downgrade rail)"

probe 0
eq "$P_HAS_TRACKER" "1" "C2 tracker is emitted even with ZERO truncations"
eq "$P_TRACKER_NONE" "1" "C2 zero-truncation tracker says '- (none)', never omits the block"
eq "$P_TRACKER_ROWS" "0" "C2 zero-truncation tracker lists no rows"

echo
echo "════════════════════════════════════════════════════════════════"
echo "  D. STARTERKIT SLICE — its own 7-step ladder (tier 8, nested)"
echo "════════════════════════════════════════════════════════════════"
probe "$MAXBALLAST"
allrungs=1
for r in "$R_LIBS" "$R_EX50" "$R_IDIOM" "$R_TOKC" "$R_EXDROP" "$R_TOKDROP"; do
  if sk_rules | grep -qxF "$r"; then :; else allrungs=0; echo "   (rung never materialized: $r)"; fi
done
chk "$allrungs" "D1 all SIX documented starterkit rungs materialize (fixture is not vacuous)" \
    "a missing input silently deleted a rung — the order assertion below would test nothing"

i_libs="$(sk_rule_idx "$R_LIBS")";     i_ex50="$(sk_rule_idx "$R_EX50")"
i_idi="$(sk_rule_idx "$R_IDIOM")";     i_tokc="$(sk_rule_idx "$R_TOKC")"
i_exd="$(sk_rule_idx "$R_EXDROP")";    i_tokd="$(sk_rule_idx "$R_TOKDROP")"
if [ -n "$i_libs" ] && [ -n "$i_idi" ] && [ -n "$i_tokc" ] && [ -n "$i_exd" ] && [ -n "$i_tokd" ]; then
  chk "$([ "$i_libs" -lt "$i_tokc" ] && echo 1 || echo 0)" \
      "D2 design_tokens compacted AFTER libs" "libs@$i_libs tokens@$i_tokc"
  chk "$([ "$i_idi" -lt "$i_tokc" ] && echo 1 || echo 0)" \
      "D2 design_tokens compacted AFTER ui_ux.idioms" "idioms@$i_idi tokens@$i_tokc"
  chk "$([ "$i_tokc" -lt "$i_exd" ] && echo 1 || echo 0)" \
      "D2 design_tokens compacted BEFORE code_examples are dropped (step 5)" \
      "tokens@$i_tokc drop-examples@$i_exd"
  chk "$([ "$i_exd" -lt "$i_tokd" ] && echo 1 || echo 0)" \
      "D2 the Design tokens LINE is dropped LAST, after code_examples" \
      "drop-examples@$i_exd drop-tokens@$i_tokd"
  chk "$([ "$i_libs" -lt "$i_ex50" ] && echo 1 || echo 0)" \
      "D2 libs cap is rung 1, before the code_examples 50-line trim" "libs@$i_libs ex50@$i_ex50"
else
  nok "D2 starterkit rung order — one or more rungs absent, order untestable"
fi
eq "$P_HAS_TOKENS" "0" "D3 at the slice drop floor the 'Design tokens:' line is gone"
eq "$P_HAS_EXAMPLE" "0" "D3 at the slice drop floor code examples are gone"
eq "$P_HAS_UIHEUR" "1" "D3 '### UI design quality heuristics' has NO rung — never dropped (un-budgeted)"

# "Design tokens: survives as long as any token survives" — find the pressure
# where tokens are COMPACTED but not yet dropped, and assert the marker line.
found_compact=0
if [ -n "$TOKC_N" ]; then probe "$TOKC_N"; found_compact=1; fi
chk "$found_compact" "D4 the walk passed through a compacted-but-not-dropped tokens state" \
    "no ballast in the walk left design_tokens compacted yet still present"
if [ "$found_compact" = "1" ]; then
  eq "$P_HAS_TOKENS" "1" "D4 'Design tokens:' line SURVIVES compaction (validate-dispatch-prompt.sh still sees it)"
  eq "$P_TOKENS_SPACING" "4px" "D4 compaction reduces spacing to the scale name only"
  chk "$([ "$P_IDIOMS" = "3" ] && echo 1 || echo 0)" \
      "D4 idioms already capped at 3 by the time tokens compact" "idioms=$P_IDIOMS"
  chk "$([ "$P_LIBS" = "10" ] && echo 1 || echo 0)" \
      "D4 libs already capped at 10 by the time tokens compact" "libs=$P_LIBS"
  eq "$P_HAS_EXAMPLE" "1" "D4 code_examples still present when tokens compact (they drop LATER)"
fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  E. TIER-8 SUB-ORDER — starterkit before design slice"
echo "════════════════════════════════════════════════════════════════"
DES="${WORK}/design"
FIX_P="$DES"; FIX_V="${DES}/.mega-sdd/vaults/v1"; BALLAST_MODE="const"; FIX_PLUGIN=""
mkdir -p "$FIX_V/units" "$FIX_V/bolts"
mk_source_tree "$DES"
# no ui_ux in starterkit_relevance -> sk_ui is None -> the greenfield design
# slice is built INSTEAD, and both tier-8 rows coexist.
mk_unit "$FIX_V" "[auth, authz, libs]" 0
mk_vault_json "$FIX_V"
mk_binding "$FIX_V"
mk_upstreams "$FIX_V"
mk_reuse_index "$DES"
mk_memory "$DES"
mk_starterkit "$DES"
probe 400000
eq "$RC" "1" "E0 design fixture reaches the halt state"
if has "$J_EMITTED" design_slice || has "$J_OMITTED" design_slice; then :; fi
eq "$P_HAS_DESIGN" "1" "E1 design slice never drops to empty (floor = system + style rows)"
eq "$P_HAS_DESIGNSYS_LINE" "1" "E1 the marker-compatible 'Design system:' line survives the floor"
# E runs against the REAL plugin root, so this is where the SHIPPED pack chain
# (laravel.md -> _universal.md) and the shipped design-intelligence bodies are
# exercised. Section A's walk deliberately uses a fixture pack for budget, so
# without this the priority-7 floor would be proven only against that fixture.
if has "$J_EMITTED" framework_pack_rules; then
  ok "E3 the SHIPPED pack chain produced priority-7 rules (real-pack coverage)"
else
  nok "E3 no framework_pack_rules from the shipped pack chain — P7 would be fixture-pack-only (emitted: $J_EMITTED)"
fi
eq "$P_PACK_IDS" "1" "E3 priority-7 floor keeps exactly top 1 against the SHIPPED pack too"

chk "$([ "$J_FIRST_SK" -ge 0 ] && echo 1 || echo 0)" "E2 starterkit_slice was truncated" "no rung"
chk "$([ "$J_FIRST_DS" -ge 0 ] && echo 1 || echo 0)" "E2 design_slice was truncated" "no rung"
if [ "$J_FIRST_SK" -ge 0 ] && [ "$J_FIRST_DS" -ge 0 ]; then
  chk "$([ "$J_FIRST_SK" -lt "$J_FIRST_DS" ] && echo 1 || echo 0)" \
      "E2 within tier 8 starterkit_slice gives way BEFORE design_slice" \
      "starterkit@$J_FIRST_SK design@$J_FIRST_DS"
fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  F. HALT NEGATIVE DIRECTION — over cap_hard WITHOUT the conjunction"
echo "════════════════════════════════════════════════════════════════"
# F1: fat T1, T2 fully legal. total > cap_hard, nothing truncated, MUST NOT halt.
FAT="${WORK}/fat"
FIX_P="$FAT"; FIX_V="${FAT}/.mega-sdd/vaults/v1"; BALLAST_MODE="const"; FIX_PLUGIN=""
mkdir -p "$FIX_V/units" "$FIX_V/bolts"
mk_source_tree "$FAT"
mk_unit "$FIX_V" "[auth, authz, ui_ux, libs]" 9000
mk_vault_json "$FIX_V"
mk_binding "$FIX_V"
mk_upstreams "$FIX_V"
mk_reuse_index "$FAT"
mk_memory "$FAT"
mk_starterkit "$FAT"
probe 0
eq "$RC" "0" "F1 fat-T1 run exits 0 — total>cap_hard is NOT a halt trigger on its own"
eq "$J_HALT" "none" "F1 halt is null"
chk "$([ "$J_TOTAL" -gt 12288 ] && echo 1 || echo 0)" \
    "F1 total genuinely exceeds cap_hard" "total=$J_TOTAL (fixture not exercising the case)"
# The 9000-byte body pad is sized against the AMENDED cap_t1 (12288), not the
# retired 2048: at 2048 EVERY fixture in this file crossed the threshold and the
# warning proved nothing. Compared against the REPORTED cap so that a future cap
# move surfaces here as "the fixture no longer exercises the case" rather than as
# a phantom warning-text regression.
chk "$([ "$J_T1" -gt "$J_CAP_T1" ] && echo 1 || echo 0)" \
    "F1 T1 overran the amended cap_t1 reporting threshold" "t1=$J_T1 cap_t1=$J_CAP_T1"
case "$J_WARNINGS" in *"proceeding rather than inventing a halt"*)
    ok "F1 warns 'proceeding rather than inventing a halt'" ;;
  *) nok "F1 must warn and proceed — warnings: $J_WARNINGS" ;; esac
case "$J_WARNINGS" in *"T1 exceeded its ${J_CAP_T1}-byte reporting threshold"*)
    ok "F1 warns that T1 overran and is never truncated" ;;
  *) nok "F1 must warn about the T1 overrun — warnings: $J_WARNINGS" ;; esac
# The amendment did not only move the number — it changed what the warning MEANS.
# cap_t1 no longer claims to bound anything; the residual signal is a
# generate-units atomicity smell. Pinned so a revert to budget framing is caught.
case "$J_WARNINGS" in *"ATOMICITY signal for generate-units, not a budget failure"*)
    ok "F1 the T1 warning is framed as an ATOMICITY signal, not a budget failure" ;;
  *) nok "F1 T1 warning must carry the amended atomicity framing — warnings: $J_WARNINGS" ;; esac
# F1 and F2 unsatisfy the conjunction through DIFFERENT terms — F1 via (a), F2
# via (c). Pinning the term keeps the two fixtures from collapsing into one case.
case "$J_WARNINGS" in *"all_1_8_at_floor=False"*)
    ok "F1 term (a) is NOT satisfied — T2 sections remain above their drop floors" ;;
  *) nok "F1 should fail the conjunction on term (a) — warnings: $J_WARNINGS" ;; esac

# F2: every truncatable section at its floor, total > cap_hard, but NO
# constitution -> term (c) unsatisfied -> WARN AND PROCEED. This is the exact
# regression guard for re-adding `total > cap_hard` as a truncation/halt trigger.
NOC="${WORK}/noconst"
FIX_P="$NOC"; FIX_V="${NOC}/.mega-sdd/vaults/v1"; BALLAST_MODE="map"; MAP_FW="laravel"; FIX_PLUGIN=""
mkdir -p "$FIX_V/units" "$FIX_V/bolts"
mk_source_tree "$NOC"
mk_unit "$FIX_V" "[auth, authz, ui_ux, libs]" 0
mk_vault_json "$FIX_V"
mk_binding "$FIX_V"
mk_upstreams "$FIX_V"
mk_reuse_index "$NOC"
mk_memory "$NOC"
# deliberately NO starterkit-context.yaml (so map_patterns is the ballast row)
# and deliberately NO constitution.md at all.
rm -f "$FIX_V/constitution.md"
probe 400
eq "$RC" "0" "F2 all-at-floor + over cap_hard + NO constitution -> exit 0 (conjunction unsatisfied)"
eq "$J_HALT" "none" "F2 halt is null"
chk "$([ "$J_TOTAL" -gt 12288 ] && echo 1 || echo 0)" "F2 total exceeds cap_hard" "total=$J_TOTAL"
case "$J_WARNINGS" in *"all_1_8_at_floor=True"*)
    ok "F2 term (a) IS satisfied — every priority 1..8 sits at its drop floor" ;;
  *) nok "F2 fixture failed to drive all sections to floor — warnings: $J_WARNINGS" ;; esac
case "$J_WARNINGS" in *"constitution_nontruncatable=False"*)
    ok "F2 term (c) is NOT satisfied — no constitution section exists" ;;
  *) nok "F2 term (c) should be false — warnings: $J_WARNINGS" ;; esac
case "$J_WARNINGS" in *"proceeding rather than inventing a halt"*)
    ok "F2 warns and proceeds instead of inventing a halt" ;;
  *) nok "F2 must warn and proceed — warnings: $J_WARNINGS" ;; esac
if has "$J_OMITTED" constitution_clauses; then
  ok "F2 constitution_clauses recorded as omitted (absence is the opt-out)"
else nok "F2 absent constitution.md must be recorded in sections_omitted"; fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  G. MAP §6 FALLBACK — un-truncatable tier-8 row, no starterkit"
echo "════════════════════════════════════════════════════════════════"
eq "$P_HAS_MAPPAT" "1" "G1 'Codebase patterns:' line emitted when starterkit-context.yaml is absent"
if has "$J_EMITTED" map_patterns; then ok "G1 map_patterns in sections_emitted"
else nok "G1 map_patterns must be emitted on the no-starterkit path"; fi
if has "$J_OMITTED" starterkit_slice; then ok "G1 starterkit_slice omitted (no starterkit-context.yaml)"
else nok "G1 starterkit_slice must be omitted without starterkit-context.yaml"; fi
if has "$J_TRUNC_KEYS" map_patterns; then
  nok "G2 map_patterns has a ONE-level ladder — it must never appear in truncations[]"
else ok "G2 map_patterns never truncated (single-level ladder, at floor from the start)"; fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  H. SOFT-BUDGET WARNING — t2 over cap_t2, total under cap_hard"
echo "════════════════════════════════════════════════════════════════"
# The window is narrow by construction: consumed_t2 is POST-truncation, so it can
# only exceed cap_t2 when the surviving floors alone do. Use an un-truncatable
# map_patterns row set as the only T2 section, and a deliberately thin T1.
SOFT="${WORK}/soft"
FIX_P="$SOFT"; FIX_V="${SOFT}/.mega-sdd/vaults/v1"; BALLAST_MODE="map"; MAP_FW=""
FIX_PLUGIN="${WORK}/thinplugin"
mkdir -p "$FIX_V/units" "$FIX_V/bolts" "${FIX_PLUGIN}/references/framework-conventions"
# A minimal pack body keeps T1 free of a `## Forbidden patterns` block so t1 can
# stay under 2048 — the only way total can be < cap_hard while t2 > cap_t2.
printf '# minimal\n\n## Hard Rules emitted\n\n```\n```\n' \
  > "${FIX_PLUGIN}/references/framework-conventions/_universal.md"
cat > "$FIX_V/units/U-050.md" <<'EOF'
---
id: U-050
title: Recompute stored order totals
task_type: modify
target_files:
  - path: app/Models/Order.php
    operation: modify
acceptance_test:
  _authored_by: adversarial-review-passed
---

## Goal

Recompute stored order totals from line items.
EOF
mk_source_tree "$SOFT"
probe 0
T1_THIN="$J_T1"
chk "$([ "$T1_THIN" -lt 2048 ] && echo 1 || echo 0)" \
    "H0 thin T1 stays under cap_t1 (soft-cap window exists at all)" "t1=$T1_THIN"
# grow the un-truncatable map row set until t2 clears cap_t2 by a small margin
NROWS=90
probe "$NROWS"
guard=0
while [ "$J_T2" -le "$J_CAP_T2" ] && [ "$guard" -lt 40 ]; do
  NROWS=$(( NROWS + ( (J_CAP_T2 - J_T2) / 100 ) + 1 ))
  guard=$((guard + 1))
  probe "$NROWS"
done
chk "$([ "$J_T2" -gt "$J_CAP_T2" ] && echo 1 || echo 0)" \
    "H1 consumed_t2 exceeds the 10240 soft cap" "t2=$J_T2"
chk "$([ "$J_TOTAL" -lt 12288 ] && echo 1 || echo 0)" \
    "H1 total stays UNDER cap_hard (t1=$J_T1 t2=$J_T2 total=$J_TOTAL)" "total=$J_TOTAL"
eq "$RC" "0" "H2 soft-cap overrun exits 0"
eq "$J_HALT" "none" "H2 soft-cap overrun is NOT a halt"
case "$J_WARNINGS" in *"T2 exceeded soft cap: target=10240, actual="*)
    ok "H2 emits the literal soft-cap warning line" ;;
  *) nok "H2 must emit 'T2 exceeded soft cap: target=10240, actual=<N> — truncation applied' — got: $J_WARNINGS" ;; esac
case "$J_WARNINGS" in *"proceeding rather than inventing a halt"*)
    nok "H2 must NOT warn about cap_hard here (total is under it)" ;;
  *) ok "H2 no cap_hard warning (total is legitimately under cap_hard)" ;; esac

FIX_PLUGIN=""

echo
echo "════════════════════════════════════════════════════════════════"
echo "  I. HALT REACHABILITY — an amended cap must still be able to FIRE"
echo "════════════════════════════════════════════════════════════════"
# The cap constants stopped being a guess on 2026-07-31 and became a MEASUREMENT
# (context-enrichment.md ## AMENDMENT — 123 builder runs). The regression a cap
# amendment introduces is NOT "too tight"; it is a cap that can never fire, and
# the amendment says so itself ("a cap that can never fire is not a cap", and it
# is why cap_hard was NOT raised to cap_t1+cap_t2). Section B already reaches the
# halt — with a 400 KB constitution, which proves nothing about a real vault.
#
# This section reproduces the amendment's own NON-VACUITY proof (lean probe:
# 9800 B of clause text -> no halt, 10000 B -> halt, a 200 B discriminator)
# WITHOUT its byte literals: bisect the boundary at runtime, then assert the halt
# fires at B and does NOT fire just below it. A gate that always fires is not a
# gate either — both directions are asserted here.
LEAN="${WORK}/lean"
FIX_P="$LEAN"; FIX_V="${LEAN}/.mega-sdd/vaults/v1"; BALLAST_MODE="const"
FIX_PLUGIN="${WORK}/leanplugin"
mkdir -p "$FIX_V/units" "$FIX_V/bolts" "${FIX_PLUGIN}/references/framework-conventions"
printf '# minimal\n\n## Hard Rules emitted\n\n```\n```\n' \
  > "${FIX_PLUGIN}/references/framework-conventions/_universal.md"
mk_source_tree "$LEAN"
# One target file, no starterkit, no reuse index, no memory, no binding, no
# upstreams: priorities 1..8 are nearly absent, so term (a) is satisfied almost
# immediately and the CONSTITUTION is the sole thing driving the overflow. That
# is the lean arm of the amendment's table, and it is the arm that matters — if
# the halt is unreachable anywhere, it is unreachable here first.
cat > "$FIX_V/units/U-050.md" <<'EOF'
---
id: U-050
title: Recompute stored order totals
task_type: modify
target_files:
  - path: app/Models/Order.php
    operation: modify
acceptance_test:
  _authored_by: adversarial-review-passed
---

## Goal

Recompute stored order totals from line items, governed by A-001.
EOF
probe 0
eq "$RC" "0" "I0 lean fixture starts clean — no halt at zero constitution ballast"
eq "$J_HALT" "none" "I0 halt is null at zero ballast"
case "$P_CLAUSE_IDS" in *A-001*) ok "I0 the ballast clause A-001 is actually cited and emitted" ;;
  *) nok "I0 A-001 must be emitted — otherwise the ballast never enters T2 (ids: $P_CLAUSE_IDS)" ;; esac
LEAN_T1="$J_T1"

# coarse: double the clause payload until the halt flips. Bounded at 2^9 x 1024
# = 524288 B; if the halt has not fired by then it is not reachable at any size
# a real constitution could plausibly carry.
I_LO=0; I_HI=0; iguard=0; N=1024
probe "$N"
while [ "$J_HALT" = "none" ] && [ "$iguard" -lt 9 ]; do
  I_LO="$N"; N=$(( N * 2 )); iguard=$((iguard + 1)); probe "$N"
done
I_HI="$N"
I_REACHED=0
[ "$J_HALT" = "dispatch_prompt_too_large" ] && I_REACHED=1
chk "$I_REACHED" \
    "I1 the three-way halt conjunction is REACHABLE on a LEAN unit by constitution payload alone" \
    "no halt at ${I_HI}B of never-truncatable clause text — the cap can no longer fire"
chk "$([ "$I_REACHED" = "1" ] && [ "$I_HI" -le 65536 ] && echo 1 || echo 0)" \
    "I1 it fires at a REALISTIC constitution size (<=64KB), not only at section B's 400KB" \
    "first halt needed ${I_HI}B of clause text"

if [ "$I_REACHED" = "1" ]; then
  # bisect to a <=64-byte window: the discriminator, not the sledgehammer
  while [ $(( I_HI - I_LO )) -gt 64 ]; do
    I_MID=$(( (I_HI + I_LO) / 2 ))
    probe "$I_MID"
    if [ "$J_HALT" = "none" ]; then I_LO="$I_MID"; else I_HI="$I_MID"; fi
  done

  probe "$I_LO"
  eq "$RC" "0" "I2 NON-VACUITY: ${I_LO}B of clause text does NOT halt (the gate is not always-on)"
  eq "$J_HALT" "none" "I2 halt is null immediately below the boundary"
  probe "$I_HI"
  eq "$RC" "1" "I2 BOUNDARY: ${I_HI}B DOES halt — a $(( I_HI - I_LO ))B discriminator flips it"
  eq "$J_HALT" "dispatch_prompt_too_large" "I2 halt name at the boundary"
  eq "$J_HALT_EXH" "True" "I2 truncation_exhausted at the boundary"
  eq "$J_STATUS" "halt" "I2 status=halt at the boundary"
  chk "$([ "$J_HALT_TOTAL" -gt "$J_CAP_HARD" ] && echo 1 || echo 0)" \
      "I2 term (b) holds at the boundary" "total=$J_HALT_TOTAL cap_hard=$J_CAP_HARD"
  # The halt must fire AT the cap, not merely somewhere far past it — otherwise
  # "reachable" would be true of any cap, however large.
  chk "$([ $(( J_HALT_TOTAL - J_CAP_HARD )) -le 2048 ] && echo 1 || echo 0)" \
      "I2 the boundary sits AT cap_hard (overshoot <=2KB), not in the far tail" \
      "total=$J_HALT_TOTAL is $(( J_HALT_TOTAL - J_CAP_HARD ))B past cap_hard"
  # THE DISCRIMINATOR. "Reachable with enough ballast" is trivially true of ANY
  # cap_hard — a never-truncated constitution grows T2 without bound, so the
  # bisection above finds a boundary no matter how far cap_hard drifts. What
  # separates a live cap from a dead one is WHERE that boundary sits: the halt is
  # specified to mean "the cascade exhausted and it STILL does not fit", so at the
  # boundary T2 must be sitting just past its own exhausted cap. If cap_hard
  # drifts up (the amendment's rejected `cap_t1 + cap_t2` = 22528), T2 has to
  # balloon ~10 KB PAST cap_t2 before the halt can fire — at which point cap_hard
  # is no longer a hard cap, it is a second and much looser one. Measured: 221 B
  # past cap_t2 at the shipped constants, 10 461 B at 22528.
  chk "$([ $(( J_HALT_T2 - J_CAP_T2 )) -le 1024 ] && echo 1 || echo 0)" \
      "I2 the halt fires as soon as the CASCADE EXHAUSTS, not after T2 balloons past its own cap" \
      "t2=$J_HALT_T2 is $(( J_HALT_T2 - J_CAP_T2 ))B past cap_t2=$J_CAP_T2 — cap_hard has drifted into a second, looser cap"
  chk "$([ "$P_CONST_A001_LEN" -ge "$I_HI" ] && echo 1 || echo 0)" \
      "I2 priority 9 is verbatim at the halt — the clause body was never clipped to dodge it" \
      "A-001 body is $P_CONST_A001_LEN bytes, ballast was $I_HI"
  eq "$P_EXISTS" "1" "I2 the prompt is still written at the boundary halt (forensic evidence)"
  chk "$([ "$J_T1" -le "$J_CAP_T1" ] && echo 1 || echo 0)" \
      "I3 the halting unit is LEAN — T1 never crossed its reporting threshold" \
      "t1=$J_T1 (this fixture is supposed to halt on constitution size, not unit size)"
fi

# ── the cap constants themselves ──────────────────────────────────────────────
# Byte literals are CORRECT here (unlike the walk thresholds): these are spec
# constants from a signed amendment, not hand-authored prose that will drift.
chk "$([ "$J_CAP_HARD" -le 12906 ] && echo 1 || echo 0)" \
    "I4 cap_hard stays at/below the documented reachability CEILING 12906" \
    "cap_hard=$J_CAP_HARD — above min-observed-t1 (2666) + cap_t2 (10240) the halt becomes T1-dependent"
chk "$([ "$J_CAP_T2" -lt "$J_CAP_HARD" ] && echo 1 || echo 0)" \
    "I4 cap_t2 < cap_hard (the cascade must exhaust before the halt can fire)" \
    "cap_t2=$J_CAP_T2 cap_hard=$J_CAP_HARD"
chk "$([ "$J_CAP_TARGET" -lt "$J_CAP_HARD" ] && echo 1 || echo 0)" \
    "I4 cap_target < cap_hard (advisory target below the halt term)" \
    "cap_target=$J_CAP_TARGET"
# `cap_t1 + cap_t2 == cap_hard` was an arithmetic COINCIDENCE (2048+10240) and is
# EXPLICITLY RETIRED by the amendment. Restoring it means someone put cap_t1 back
# to 2048 — the value that fired on 123/123 measured runs.
chk "$([ $(( J_CAP_T1 + J_CAP_T2 )) -ne "$J_CAP_HARD" ] && echo 1 || echo 0)" \
    "I4 the retired identity cap_t1+cap_t2==cap_hard has NOT been restored" \
    "cap_t1($J_CAP_T1)+cap_t2($J_CAP_T2)==cap_hard($J_CAP_HARD) — the coincidence is back"

echo
echo "════════════════════════════════════════════════════════════════"
echo "  J. NORMAL UNIT (T1 at the MEASURED MEDIAN) — nothing may fire"
echo "════════════════════════════════════════════════════════════════"
# The inverse rail, asserted just as hard as the halt: on a unit at the middle of
# the measured T1 distribution (context-enrichment.md ## AMENDMENT: min 2666 ·
# median 4741 · max 10874 over 123 runs), the builder must produce a complete
# prompt with NO halt, NO truncation and NO budget warning of any kind. The old
# cap_t1=2048 failed exactly this test — it fired on 123/123 runs, i.e. on every
# normal unit, which is what made it noise.
#
# T1 is driven ONTO the median adaptively (measure, then pad) rather than by a
# byte literal, for the same reason the rung walk is: the fixture's baseline
# moves whenever a reference file or the template is edited.
MEDIAN_T1=4741
NORM="${WORK}/normal"
FIX_P="$NORM"; FIX_V="${NORM}/.mega-sdd/vaults/v1"; BALLAST_MODE="const"; FIX_PLUGIN="$MINI"
mkdir -p "$FIX_V/units" "$FIX_V/bolts"
mk_source_tree "$NORM"
mk_normal_unit "$FIX_V" 0
mk_vault_json "$FIX_V"
mk_binding "$FIX_V"
mk_upstreams "$FIX_V"
mk_reuse_index "$NORM"
mk_memory "$NORM"
mk_starterkit "$NORM"
probe 0
J_BASE_T1="$J_T1"
# mk_normal_unit's pad costs 10 bytes of framing ("PADDING: " + "\n")
J_PAD=$(( MEDIAN_T1 - J_BASE_T1 - 10 ))
if [ "$J_PAD" -gt 0 ]; then
  mk_normal_unit "$FIX_V" "$J_PAD"
  probe 0
  chk "$([ "$J_T1" -ge $((MEDIAN_T1 - 64)) ] && [ "$J_T1" -le $((MEDIAN_T1 + 64)) ] && echo 1 || echo 0)" \
      "J0 T1 was driven onto the MEASURED MEDIAN (4741 +/-64)" "t1=$J_T1"
else
  nok "J0 fixture baseline T1 ($J_BASE_T1) already exceeds the measured median — cannot target it"
fi
eq "$RC" "0" "J1 a median-T1 unit exits 0"
eq "$J_HALT" "none" "J1 a median-T1 unit does NOT halt"
eq "$J_STATUS" "ok" "J1 status=ok (not ok_with_soft_halts)"
eq "$J_NTRUNC" "0" "J1 a median-T1 unit truncates NOTHING"
chk "$([ "$J_T2" -le "$J_CAP_T2" ] && echo 1 || echo 0)" \
    "J1 t2 is inside cap_t2 (so the cascade was never entered)" "t2=$J_T2 cap_t2=$J_CAP_T2"
# NOT asserted: `total <= cap_hard`. It is NOT a property of a normal unit and
# never was — cap_t2 alone is 10240 against a cap_hard of 12288, so ANY unit with
# a full-fidelity T2 and a T1 over ~2 KB crosses cap_hard with zero truncations.
# That is the amendment's own structural note ((a) ⟹ (b): term (b) does no
# discriminating work) and the documented §Size check behavior — warn and
# proceed, exit 0. Asserting the inverse here would re-introduce F10's
# "total > cap_hard is a halt trigger" reading through the back door.
if [ "$J_TOTAL" -gt "$J_CAP_HARD" ]; then
  case "$J_WARNINGS" in *"exceeds cap_hard"*"proceeding rather than inventing a halt"*)
      ok "J2 over cap_hard with zero truncations -> warn and proceed (never a halt)" ;;
    *) nok "J2 total>cap_hard must warn-and-proceed — warnings: $J_WARNINGS" ;; esac
else
  case "$J_WARNINGS" in *"exceeds cap_hard"*)
      nok "J2 total is under cap_hard yet the cap_hard warning fired — $J_WARNINGS" ;;
    *) ok "J2 total under cap_hard and no cap_hard warning" ;; esac
fi
# The budget warnings are asserted ABSENT INDIVIDUALLY rather than via
# `nwarn == 0`: an unrelated warning (absent vault.json, pack chain, …) would
# then read as a phantom cap regression.
case "$J_WARNINGS" in *"reporting threshold"*)
    nok "J2 no T1 atomicity warning on a median unit — got: $J_WARNINGS" ;;
  *) ok "J2 no T1 reporting-threshold warning at the median (the 2048 noise is gone)" ;; esac
case "$J_WARNINGS" in *"T2 exceeded soft cap"*)
    nok "J2 no T2 soft-cap warning on a normal unit — got: $J_WARNINGS" ;;
  *) ok "J2 no T2 soft-cap warning on a normal unit" ;; esac
eq "$P_HAS_TRACKER" "1" "J2 the tracker is still emitted on an untruncated unit"
eq "$P_TRACKER_NONE" "1" "J2 tracker records '- (none)'"
eq "$P_TRACKER_ROWS" "0" "J2 tracker lists no rungs"
# "must NOT truncate anything" asserted at FULL FIDELITY, not just by an empty
# truncations[]: a cascade that silently trimmed without logging would pass the
# count check and fail every one of these.
eq "$P_UPSTREAM_ENTRIES" "2" "J3 both upstream summaries survive intact"
eq "$P_PACK_IDS" "3" "J3 all 3 matched pack rules survive intact"
eq "$P_LIBS" "12" "J3 all 12 starterkit libs survive intact (no 'top 10' rung)"
eq "$P_IDIOMS" "5" "J3 all 5 ui_ux idioms survive intact (no 'top 3' rung)"
eq "$P_HAS_TOKENS" "1" "J3 the Design tokens line survives intact"
eq "$P_HAS_EXAMPLE" "1" "J3 the reference code example survives intact"
eq "$P_REUSE_SENTINEL" "0" "J3 the reuse slice carries entries, not its '+N more' floor"
chk "$([ "$P_REUSE_ENTRIES" -gt 0 ] && echo 1 || echo 0)" \
    "J3 the reuse slice carries real entries" "entries=$P_REUSE_ENTRIES"
chk "$([ "$J_T1" -ge 2666 ] && [ "$J_T1" -le 10874 ] && echo 1 || echo 0)" \
    "J3 T1 sits inside the measured corpus band [2666, 10874]" "t1=$J_T1"

echo
echo "════════════════════════════════════════════════════════════════"
echo "  K. TIER 8b — map_patterns has a ROW now: pin its position + floor"
echo "════════════════════════════════════════════════════════════════"
# context-enrichment.md §T2 section priority, amended 2026-07-31: tier 8 always
# carried THREE sections and listed ONE. `map_patterns` was emitted at tier 8
# with no row — a section outside the contract — and because its ladder has ZERO
# rungs it is permanently `at_floor()`, so it could sit AHEAD of `design_slice`
# in the cascade and yield nothing while 8c was truncated around it. The rows are
# now enumerated 8a `starterkit_slice` -> 8b `map_patterns` -> 8c `design_slice`.
#
# 8a and 8b are MUTUALLY EXCLUSIVE by construction (map_patterns is the Map §6
# FALLBACK, built only when starterkit-context.yaml is absent), so no single
# fixture can observe all three. Section E pins 8a-before-8c; this pins 8b's
# position relative to 8c and its floor. Together they cover the amended row.
MAPF="${WORK}/mapfall"
FIX_P="$MAPF"; FIX_V="${MAPF}/.mega-sdd/vaults/v1"; BALLAST_MODE="const"; FIX_PLUGIN=""
mkdir -p "$FIX_V/units" "$FIX_V/bolts"
mk_source_tree "$MAPF"
mk_unit "$FIX_V" "[auth, authz, ui_ux, libs]" 0
mk_vault_json "$FIX_V"
mk_binding "$FIX_V"
mk_upstreams "$FIX_V"
mk_reuse_index "$MAPF"
mk_memory "$MAPF"
# NO starterkit-context.yaml -> 8a omitted, 8b built. UI-bearing target_files +
# a vault design_system -> the greenfield 8c is built too, so 8b and 8c coexist.
mk_codebase_map "$MAPF" "laravel" 8
probe "$MAXBALLAST"
eq "$RC" "1" "K0 the 8b/8c fixture reaches the halt state (cascade fully exhausted)"
if has "$J_OMITTED" starterkit_slice; then ok "K0 8a omitted (no starterkit-context.yaml)"
else nok "K0 8a must be omitted so 8b is the fallback — omitted: $J_OMITTED"; fi
if has "$J_EMITTED" map_patterns; then ok "K1 8b map_patterns is emitted on the fallback path"
else nok "K1 8b must be emitted when starterkit-context.yaml is absent (emitted: $J_EMITTED)"; fi
# FLOOR: level 0 is both its ceiling and its floor. It survives MAXIMUM pressure.
eq "$P_HAS_MAPPAT" "1" "K1 8b FLOOR — 'Codebase patterns:' survives maximum pressure (never dropped)"
if has "$J_TRUNC_KEYS" map_patterns; then
  nok "K1 8b has a single-level ladder — it must NEVER appear in truncations[] (got: $J_TRUNC_KEYS)"
else ok "K1 8b never appears in truncations[] (zero rungs, permanently at floor)"; fi
# POSITION: this is the F23(a) rail. A no-op pass over the rowless 8b must NOT
# stop the cascade from reaching 8c — if it did, design_slice would keep its full
# fidelity while lower priorities starved, and the halt would fire around it.
if has "$J_TRUNC_KEYS" design_slice; then
  ok "K2 8c design_slice still gives way BEHIND the zero-rung 8b (the no-op pass does not wedge the cascade)"
else
  nok "K2 8c must be truncated once 8b is at floor — a rowless-at-floor 8b outranking 8c is the amended defect (truncs: $J_TRUNC_KEYS)"
fi
eq "$P_HAS_DESIGN" "1" "K2 8c floor is system+style, never empty"
eq "$P_HAS_DESIGNSYS_LINE" "1" "K2 the marker-compatible 'Design system:' line survives 8c's floor"
case "$P_SECTION_ORDER" in *map*design*)
    ok "K2 8b is emitted BEFORE 8c in the prompt (template order pinned)" ;;
  *) nok "K2 map_patterns must precede design_slice in the emitted order — got: $P_SECTION_ORDER" ;; esac

echo
echo "════════════════════════════════════════════════════════════════"
echo "  L. DEFAULT STDOUT SHAPE — the slimming, and where the forensics went"
echo "════════════════════════════════════════════════════════════════"
# stdout is a MEASURED INPUT CHANNEL: --quiet is forbidden for the controller
# (stdout is the sole carrier of inline_core), so this object lands as a tool
# result on EVERY bolt of a 40-unit run. `sections_omitted[]` was 41-63% of the
# old payload and the controller never reads it, so it moved OFF default stdout
# and INTO the prompt file's own provenance appendix. Both halves are asserted:
# the key is GONE from stdout, and the replacement channel ARRIVED in the file.
# Every other probe in this suite passes --explain, so without this section the
# slimming has ZERO coverage and would regress silently.
LP="${LEAN}/.mega-sdd/vaults/v1"
mk_constitution "$LP" 0        # reset the lean fixture off its halt ballast
LEAN_PROMPT="${LP}/bolts/U-050/dispatch-prompt.md"
bash "$BUILDER" --cwd="$LEAN" --vault="$LP" --unit=U-050 --plugin-root="${WORK}/leanplugin" \
  </dev/null >"${WORK}/dflt.json" 2>"${WORK}/dflt.err"
LRC=$?
# shellcheck disable=SC2086
$PY "${WORK}/keys.py" "${WORK}/dflt.json" "${WORK}/kvars.sh"
# shellcheck disable=SC1090
. "${WORK}/kvars.sh"
eq "$LRC" "0" "L0 default-flag run exits 0"
eq "$K_JSON" "1" "L0 default stdout is parseable JSON"
eq "$K_KEYS" \
   "file_bytes halt inline_core prompt_path soft_halts status t1_bytes t2_bytes total_bytes truncations unit warnings" \
   "L1 default stdout carries EXACTLY the controller-consumed key set"
for k in caps sections_emitted sections_omitted inline_core_bytes inline_core_degraded \
         pack_chain pack_resolver_exit interpreter; do
  if has "$K_KEYS" "$k"; then nok "L1 forensic key '$k' must NOT be on default stdout"
  else ok "L1 forensic key '$k' is off default stdout"; fi
done
# invariant #5 half: an absent rubric is an ABSENT KEY, never an empty string —
# "" would tell the controller it has a rubric and hand the design lens nothing.
#
# SCOPE OF THIS RAIL, stated because it was read too broadly once. This project
# carries NO starterkit-context.yaml, so `sk_ui is None` and the STARTERKIT
# branch of the lens-input write is never reached here. This assertion therefore
# passed for the whole of round 3 WHILE a non-ui_bearing unit on a starterkit
# repo was being handed a `design_slice_path` — it pins the greenfield branch
# only. The `ui_bearing` gate itself is pinned by section T4 of the sibling suite
# (tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh), which supplies
# the starterkit yaml this fixture deliberately lacks. Do not "consolidate" the
# two: the fixtures differ on the input that decides the branch.
eq "$K_HAS_DSP" "0" "L1 design_slice_path key is ABSENT on a non-UI unit (greenfield branch — see shape-suite T4 for the starterkit branch)"
eq "$K_DSP_EMPTY" "0" "L1 design_slice_path is never emitted as an empty string"
# The RETIRED key. The lens's rubric travels as a ~70-byte path; the 9.6 KB
# string it replaced was billed twice per greenfield UI bolt (once as builder
# stdout, once as the controller's verbatim paste into the lens prompt). Its
# return to stdout is a cost regression the key-set assertion above would catch
# only on a UI unit, so it is named here too.
eq "$K_HAS_DSTEXT" "0" "L1 the retired design_slice_text TEXT key is gone from stdout"
chk "$([ "$K_INLINE_LEN" -gt 0 ] && [ "$K_INLINE_LEN" -le 700 ] && echo 1 || echo 0)" \
    "L1 inline_core is present and inside its 700B cap" "len=$K_INLINE_LEN"
# ── BYTE ACCOUNTING: two numbers, two meanings, neither renamable into the other
# `total_bytes` is T1+T2 — what the cascade truncates and what the halt reasons
# about. `file_bytes` is the artifact the subagent is ordered to read IN FULL.
# The tracker injected INTO that artifact used to quote only the first for a file
# that held the second, understating it by 24-59%. Both directions are pinned:
# the meanings must NOT converge, and file_bytes must be EXACT (it is emitted
# through a fixed-width field, so a rounding-by-one is a real defect, not slack).
# t1/t2 are read from THIS run's own JSON (K_*), never from the last `probe` —
# section L does not go through probe(), so the J_* globals here still hold
# section K's max-pressure fixture.
eq "$K_TOTAL_BYTES" "$((K_T1 + K_T2))" "L1b total_bytes is still exactly t1_bytes + t2_bytes"
eq "$K_FILE_BYTES" "$K_PROMPT_BYTES" "L1b file_bytes equals the dispatch-prompt.md actually on disk"
chk "$([ "$K_FILE_BYTES" -gt "$K_TOTAL_BYTES" ] && echo 1 || echo 0)" \
    "L1b file_bytes EXCEEDS total_bytes — the un-budgeted blocks are disclosed, not folded in" \
    "file=$K_FILE_BYTES total=$K_TOTAL_BYTES — the two numbers collapsed into one meaning"
DFLT_BYTES="$K_BYTES"
bash "$BUILDER" --cwd="$LEAN" --vault="$LP" --unit=U-050 --plugin-root="${WORK}/leanplugin" \
  --explain </dev/null >"${WORK}/expl.json" 2>/dev/null
# shellcheck disable=SC2086
$PY "${WORK}/keys.py" "${WORK}/expl.json" "${WORK}/kvars.sh"
# shellcheck disable=SC1090
. "${WORK}/kvars.sh"
chk "$([ "$DFLT_BYTES" -lt "$K_BYTES" ] && echo 1 || echo 0)" \
    "L2 --explain ADDS to the payload; the default is strictly smaller" \
    "default=$DFLT_BYTES explain=$K_BYTES"
for k in caps sections_emitted sections_omitted pack_resolver_exit interpreter; do
  if has "$K_KEYS" "$k"; then ok "L2 --explain restores '$k'"
  else nok "L2 --explain must restore '$k' — keys: $K_KEYS"; fi
done
# --explain ADDS, --quiet REMOVES EVERYTHING. They are not two settings of one
# verbosity dial, so the combination is a usage error, not a precedence puzzle.
bash "$BUILDER" --cwd="$LEAN" --vault="$LP" --unit=U-050 --plugin-root="${WORK}/leanplugin" \
  --quiet --explain </dev/null >"${WORK}/qe.out" 2>/dev/null
eq "$?" "2" "L3 --quiet --explain is rejected as a usage error (exit 2)"
chk "$([ ! -s "${WORK}/qe.out" ] && echo 1 || echo 0)" "L3 rejected combination prints no JSON" "stdout not empty"
bash "$BUILDER" --cwd="$LEAN" --vault="$LP" --unit=U-050 --plugin-root="${WORK}/leanplugin" \
  --quiet </dev/null >"${WORK}/q.out" 2>/dev/null
eq "$?" "0" "L3 --quiet alone still exits 0"
chk "$([ ! -s "${WORK}/q.out" ] && echo 1 || echo 0)" "L3 --quiet emits nothing on stdout" "stdout not empty"
# THE REPLACEMENT CHANNEL. kb_anti_patterns is omitted on EVERY run by contract,
# so it is the guaranteed witness that the appendix carries real content.
if grep -qF "PROVENANCE — omissions" "$LEAN_PROMPT" 2>/dev/null; then
  ok "L4 the prompt file carries the 'PROVENANCE — omissions' appendix"
else nok "L4 sections_omitted left stdout but never arrived in the prompt file"; fi
if grep -qF "kb_anti_patterns" "$LEAN_PROMPT" 2>/dev/null; then
  ok "L4 the appendix names the contractually-omitted kb_anti_patterns section"
else nok "L4 the appendix must carry the omission entries, not just a header"; fi
if grep -qF "NOT part of the T1/T2 byte accounting" "$LEAN_PROMPT" 2>/dev/null; then
  ok "L4 the appendix DISCLOSES that it is outside the T1/T2 accounting"
else nok "L4 the appendix must disclose that it is excluded from total_bytes"; fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  M. INVARIANT #5 — absent values are DROPPED, and the guard is not"
echo "     a chain-killer"
echo "════════════════════════════════════════════════════════════════"
# Two directions of the same rule, in ONE fixture.
#  (a) A vault design_system carrying ONLY `style` is LEGAL — nothing requires
#      all four keys. The absent ones must be DROPPED and RECORDED, never
#      rendered as `palette=None`. A rendered None is worse than an omitted
#      line: the anti-halu rail names that line as the authoritative palette
#      source, while validate-ui-quality.sh sees a `Design system:` marker and
#      reports design_system_not_injected CLEAN.
#  (b) The absent-value SMOKE ALARM must not fire on prose. Its predecessor was
#      a regex scan over the ASSEMBLED TEXT that exited 4 — no prompt written —
#      on any unit whose body said "None" in English or in a code sample, which
#      made a legal machine-generated input permanently undispatchable. The
#      shipped detector compares ONE RENDERED VALUE against the placeholder
#      vocabulary WHOLE, inside compose(), and only ever appends to warnings[].
#      Both halves are asserted: the run exits 0 (it cannot do otherwise now),
#      AND the alarm is SILENT — a warning here would mean the detector had
#      drifted back to scanning text, which is the failure that mattered. The
#      fixture body carries the shapes the retired pattern matched, verbatim.
NONEF="${WORK}/nonef"
NV="${NONEF}/.mega-sdd/vaults/v1"
mkdir -p "$NV/units" "$NV/bolts"
mk_source_tree "$NONEF"
cat > "$NV/vault.json" <<'EOF'
{
  "vault": "v1",
  "design_system": {"style": "minimalism"}
}
EOF
cat > "$NV/units/U-050.md" <<'EOF'
---
id: U-050
title: Render the order detail view
task_type: create
target_files:
  - path: resources/views/orders/show.blade.php
    operation: create
acceptance_test:
  _authored_by: adversarial-reviewed (+2 gaps merged)
---

## Goal

Render the order detail view. The helper below says None a lot.

## Notes

```python
def total(cents=None):
    if cents is None:
        return None
    return [None, cents]
```

- rationale: returns None when the ledger is empty
EOF
NONE_PROMPT="${NV}/bolts/U-050/dispatch-prompt.md"
bash "$BUILDER" --cwd="$NONEF" --vault="$NV" --unit=U-050 </dev/null \
  >"${WORK}/none.json" 2>"${WORK}/none.err"
NRC=$?
eq "$NRC" "0" "M0 a unit body full of verbatim 'None' still exits 0 (the retired scan exited 4 — a chain-killer)"
chk "$([ -s "$NONE_PROMPT" ] && echo 1 || echo 0)" "M0 the prompt was written" "no artifact at $NONE_PROMPT"
# The load-bearing half: SILENCE. Exit 0 alone no longer discriminates (the
# detector is warning-only by construction), so a detector that regressed to
# scanning assembled text would still exit 0 — and announce itself here.
if grep -qF "absent-value smoke alarm" "${WORK}/none.json" 2>/dev/null; then
  nok "M0 the absent-value smoke alarm FIRED on verbatim prose — the detector is scanning text again, not comparing one rendered value"
else
  ok "M0 the absent-value smoke alarm stays SILENT on prose/code that says 'None' (zero false positives)"
fi
if grep -qE '^Design system: ' "$NONE_PROMPT" 2>/dev/null; then
  ok "M1 the 'Design system:' marker line is still emitted from a partial design_system"
else nok "M1 a partial design_system must still emit its surviving values"; fi
# The precise rail: no BUILDER-COMPOSED line may carry the token. Scoped to the
# composed prefixes so the verbatim body (which legitimately says None) is not
# what is being tested.
if grep -qE '^(Design system|Design tokens|UI/UX|Auth|Authz|Libs in scope|Style):.*None' \
     "$NONE_PROMPT" 2>/dev/null; then
  nok "M1 a composed line rendered the literal None — invariant #5 (placeholder-fill on an absent input)"
else ok "M1 no composed line renders 'None' for an absent input"; fi
if grep -qF "design_slice.system.absent_keys" "$NONE_PROMPT" 2>/dev/null; then
  ok "M1 the dropped keys are RECORDED in the provenance appendix, not silently gone"
else nok "M1 an absent input must be recorded with a reason, not merely dropped"; fi
# The C2 class, same fixture: style-principles.md's header is
# `| Style | Best For | Avoid For | CSS Keywords |` — there is no traits column
# and no anti-patterns column. Relabelling a product-suitability list as a
# design-defect list while citing the file by section is invariant #5 in its
# subtlest form, and the design-reviewer lens judges against this same slice.
if grep -qE '^Style: .*best for: ' "$NONE_PROMPT" 2>/dev/null; then
  ok "M2 the style row is emitted under style-principles.md's OWN column names"
else nok "M2 expected a 'Style: <name> — best for: …' line sourced from the real columns"; fi
if grep -qE '^Style (traits|anti-patterns):' "$NONE_PROMPT" 2>/dev/null; then
  nok "M2 the retired 'Style traits:'/'Style anti-patterns:' labels are back — they name columns that do not exist"
else ok "M2 the fabricated 'Style traits:'/'Style anti-patterns:' labels are gone"; fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  N. HALT VACUITY — term (b) is what discriminates when (a) is free"
echo "════════════════════════════════════════════════════════════════"
# THE DEFECT THIS RAIL EXISTS FOR. `all_1_to_8_at_floor` is
#   all(s.at_floor() for s in CASCADE_ORDER if s.priority < 9)
# and `add_section` returns early on an empty level, so an ABSENT section never
# enters CASCADE_ORDER at all. On a unit with no priority-1..8 section the
# predicate is therefore VACUOUSLY TRUE over an empty set — term (a) of the
# three-way halt conjunction is satisfied for free, having proven nothing.
#
# Two consequences the suite must hold apart, and this section is where they are
# separated:
#
#   * The derivation "(a) ⟹ t2 ≥ cap_t2+1" is FALSE. Arm A exhibits (a) holding
#     with t2 at a small fraction of cap_t2 — asserted, not argued.
#   * The Named backlog item "drop the redundant `total > cap_hard` term" would,
#     under vacuity, leave (c) as the ONLY discriminator: every thin unit that
#     cites a single constitution clause would halt, at any size. Arm A is the
#     executable veto on that item. If someone drops term (b), arm A goes red.
#
# BOTH DIRECTIONS ON THE SAME FIXTURE, which is what makes it a discriminator
# rather than two unrelated facts: the ONLY thing that changes between arm A and
# arm B is the size of the never-truncatable constitution payload.
#
# Section I owns the BOUNDARY (it bisects to a <=64-byte window). N deliberately
# does not re-bisect — it needs two coarse arms, not a second boundary.
VAC="${WORK}/vacuous"
FIX_P="$VAC"; FIX_V="${VAC}/.mega-sdd/vaults/v1"; FIX_UNIT="U-050"
BALLAST_MODE="const"; FIX_PLUGIN="${WORK}/leanplugin"
mkdir -p "$FIX_V/units" "$FIX_V/bolts"
mk_source_tree "$VAC"
# Everything that could feed a priority-1..8 section is deliberately ABSENT: no
# starterkit-context.yaml, no reuse-index.yaml, no memory, no binding.md, no
# upstream bolts, no codebase-map.md, no vault.json (so no design_system), a
# NON-UI target file, and a plugin root whose pack emits no rules. What is left
# in T2 is priority 9 and nothing else.
cat > "$FIX_V/units/U-050.md" <<'EOF'
---
id: U-050
title: Recompute stored order totals
task_type: modify
target_files:
  - path: app/Models/Order.php
    operation: modify
acceptance_test:
  _authored_by: adversarial-review-passed
---

## Goal

Recompute stored order totals from line items, governed by A-001.
EOF

# ── ARM A: (a) vacuously true, (c) true, (b) FALSE -> must NOT halt ───────────
probe 0
eq "$RC" "0" "N0 arm A exits 0 — vacuous term (a) plus a constitution is NOT a halt"
eq "$J_HALT" "none" "N0 arm A halt is null"
case "$P_CLAUSE_IDS" in *A-001*) ok "N0 term (c) genuinely holds on arm A — A-001 is cited and emitted" ;;
  *) nok "N0 A-001 must be emitted, else arm A proves nothing about term (c) (ids: $P_CLAUSE_IDS)" ;; esac
# THE VACUITY PROOF. Without this, arm A's "no halt" could equally be explained
# by term (a) being FALSE, and the section would test nothing — the silent-green
# class this suite exists to prevent. Asserted in aggregate so one failure names
# the offending section instead of burying it in ten near-identical lines.
T18="validation_hints reuse_slice kb_anti_patterns confidence_labels \
     depends_on_summaries framework_pack_rules starterkit_slice map_patterns design_slice"
# The list IS the assertion, so its own integrity is asserted first: TEN names —
# priorities 1..7 one row each, plus tier 8 enumerated 8a/8b/8c. A name silently
# dropping out of it (an edit, a lost line continuation) would shrink the vacuity
# proof to a subset while both checks below still reported PASS.
set -- $T18
eq "$#" "9" "N1 the priority name list is complete (6 rows + tier 8a/8b/8c — historical_memory removed v7.3.0)"
vac_emitted=""; vac_unrecorded=""
for s in $T18; do
  has "$J_EMITTED" "$s" && vac_emitted="$vac_emitted $s"
  has "$J_OMITTED" "$s" || vac_unrecorded="$vac_unrecorded $s"
done
if [ -z "$vac_emitted" ]; then
  ok "N1 VACUITY: NO priority-1..8 section is emitted — term (a) is satisfied over an EMPTY set"
else
  nok "N1 the fixture leaked priority-1..8 section(s) —$vac_emitted — arm A is no longer the vacuous case"
fi
if [ -z "$vac_unrecorded" ]; then
  ok "N1 every absent priority-1..8 section is RECORDED in sections_omitted (invariant #5)"
else
  nok "N1 absent section(s) vanished without a recorded reason —$vac_unrecorded"
fi
eq "$J_NTRUNC" "0" "N1 the cascade spent NOTHING on arm A (no rung exists to spend)"
# The falsified derivation, exhibited. ':103 (a) ⟹ t2 ≥ cap_t2+1' cannot hold
# when (a) is true at a small fraction of cap_t2.
chk "$([ "$J_T2" -lt "$J_CAP_T2" ] && echo 1 || echo 0)" \
    "N1 term (a) holds while t2 ($J_T2) sits BELOW cap_t2 ($J_CAP_T2) — '(a) implies t2 > cap_t2' is false" \
    "t2=$J_T2 is not below cap_t2=$J_CAP_T2 — the fixture stopped exhibiting the vacuous case"
# FIXTURE GUARD, in the F1/J0 style: if the builder's own scaffolding ever grows
# past cap_hard on this minimal unit, the failure above must read as "the fixture
# drifted", never as "the halt regressed".
chk "$([ "$J_TOTAL" -le "$J_CAP_HARD" ] && echo 1 || echo 0)" \
    "N2 arm A is genuinely under cap_hard, so term (b) is the ONLY unsatisfied term" \
    "total=$J_TOTAL already exceeds cap_hard=$J_CAP_HARD — the fixture no longer exercises the case"

# ── ARM B: same unit, constitution alone driven past cap_hard -> MUST halt ────
# Ballast derived from arm A's own measurement (never a byte literal): enough to
# clear cap_hard by ~4 KB, so the arm stays valid when the scaffolding moves.
VAC_BALLAST=$(( J_CAP_HARD - J_TOTAL + 4096 ))
probe "$VAC_BALLAST"
eq "$RC" "1" "N3 arm B exits 1 — constitution_clauses ALONE drives the unit past cap_hard"
eq "$J_HALT" "dispatch_prompt_too_large" "N3 arm B halt name"
eq "$J_STATUS" "halt" "N3 arm B status=halt"
chk "$([ "$J_HALT_TOTAL" -gt "$J_CAP_HARD" ] && echo 1 || echo 0)" \
    "N3 term (b) is what flipped — total $J_HALT_TOTAL now exceeds cap_hard $J_CAP_HARD" \
    "total=$J_HALT_TOTAL cap_hard=$J_CAP_HARD"
vac_emitted2=""
for s in $T18; do has "$J_EMITTED" "$s" && vac_emitted2="$vac_emitted2 $s"; done
if [ -z "$vac_emitted2" ]; then
  ok "N3 arm B is still the SAME vacuous unit — only the constitution payload changed"
else
  nok "N3 arm B gained priority-1..8 section(s) —$vac_emitted2 — the two arms are no longer comparable"
fi
eq "$P_EXISTS" "1" "N3 the prompt is still written on the vacuous halt (forensic evidence)"
# THE PAYLOAD, ON THE PATH B1 CANNOT SEE. `truncation_exhausted` is DERIVED from
# term (a), not asserted as a literal — so on this run it is true while the
# cascade demonstrably spent nothing, and the payload's own warnings[] (the
# truncation-event list) is legitimately EMPTY. B1 asserts the opposite on a rich
# fixture; both are correct, and pinning them together here is what stops the
# next reader from "hardening" B1's non-empty check into a builder invariant that
# would make this legal unit permanently undispatchable.
eq "$J_HALT_EXH" "True" "N4 truncation_exhausted is True — DERIVED from the vacuously-satisfied term (a)"
eq "$J_NTRUNC" "0" "N4 ...on a run where truncations[] is EMPTY (no rung was ever spent)"
eq "$J_HALT_NWARN" "0" "N4 ...and the halt payload's warnings[] is legitimately EMPTY on this path"

echo
echo "════════════════════════════════════════════════════════════════"
echo "  O. DESIGN-SLICE CHANNEL — the lens gets a path, the BOLT loses nothing"
echo "════════════════════════════════════════════════════════════════"
# The design lens's rubric no longer travels as a pasted string on stdout. It is
# written to `<vault>/lens-inputs/U-XXX/design-slice.md` and stdout carries the
# PATH. That is a COST fix — as text the slice was billed twice per greenfield UI
# bolt, once as builder stdout (input) and again as the controller's verbatim
# re-typing into the lens prompt (the expensive channel).
#
# THE RAIL IT MUST NOT BREAK, stated as its purpose rather than as a blanket ban
# on paths: no lens may receive a path that reaches ANOTHER LENS'S VERDICT or the
# IMPLEMENTER'S SELF-REPORT. `<vault>/bolts/U-XXX/` holds bolt-report.md — on a
# --resume it already carries the prior attempt's `## Review panel` verdicts and
# `bolt_self_report`, and a lens with Read/Grep is one Glob away from all of it.
# `lens-inputs/` is a SIBLING of bolts/ holding only controller-written inputs,
# so a path into it breaches no part of that rail. Both facts are asserted.
#
# AND THE PART THAT IS NOT ABOUT THE LENS AT ALL: the implementer's copy must be
# untouched. A "move" that silently became a "relocate" would leave the bolt
# building UI against no rubric while every stdout assertion still passed.
UIS="${WORK}/uislice"
UIV="${UIS}/.mega-sdd/vaults/v1"
mkdir -p "$UIV/units" "$UIV/bolts"
mk_source_tree "$UIS"
mk_vault_json "$UIV"          # full design_system: style/palette/typography/a11y
cat > "$UIV/units/U-050.md" <<'EOF'
---
id: U-050
title: Render the order detail view
task_type: create
target_files:
  - path: resources/views/orders/show.blade.php
    operation: create
acceptance_test:
  _authored_by: adversarial-reviewed (+2 gaps merged)
---

## Goal

Render the order detail view with a tax breakdown.
EOF
UI_PROMPT="${UIV}/bolts/U-050/dispatch-prompt.md"
UI_SLICE="${UIV}/lens-inputs/U-050/design-slice.md"
# NO --plugin-root override: this arm runs against the REAL plugin root, so the
# slice under test is the SHIPPED greenfield rubric (the one whose byte cost the
# move was made for), not a fixture stub. No --explain either — the path key is a
# DEFAULT-stdout contract and that is the only channel the controller reads.
bash "$BUILDER" --cwd="$UIS" --vault="$UIV" --unit=U-050 \
  </dev/null >"${WORK}/ui.json" 2>"${WORK}/ui.err"
URC=$?
# shellcheck disable=SC2086
$PY "${WORK}/keys.py" "${WORK}/ui.json" "${WORK}/kvars.sh"
# shellcheck disable=SC1090
. "${WORK}/kvars.sh"
eq "$URC" "0" "O0 the UI-bearing default-flag run exits 0"
eq "$K_JSON" "1" "O0 default stdout is parseable JSON on a UI unit"
# The EXACT key set for a UI unit. L1 only ever sees a non-UI unit, so without
# this the return of `design_slice_text` — or any forensic key leaking onto the
# UI path — has no assertion anywhere.
eq "$K_KEYS" \
   "design_slice_path file_bytes halt inline_core prompt_path soft_halts status t1_bytes t2_bytes total_bytes truncations unit warnings" \
   "O1 a UI unit's default stdout is the controller key set PLUS design_slice_path — nothing else"
eq "$K_HAS_DSTEXT" "0" "O1 the 9.6KB design_slice_text string did NOT come back on the UI path"
eq "$K_DSP" "$(cd "$(dirname "$UI_SLICE")" 2>/dev/null && pwd)/design-slice.md" \
   "O1 design_slice_path is the ABSOLUTE path to <vault>/lens-inputs/U-050/design-slice.md"
case "$K_DSP" in
  */bolts/*) nok "O2 BLIND-LENS RAIL: the lens path reaches into bolts/, where bolt-report.md and prior review verdicts live — $K_DSP" ;;
  *) ok "O2 BLIND-LENS RAIL: the lens path does not reach into bolts/ (no verdict, no self-report)" ;;
esac
if [ -d "${UIV}/lens-inputs" ] && [ -d "${UIV}/bolts" ]; then
  ok "O2 lens-inputs/ is a SIBLING of bolts/ under the vault, not a child of it"
else
  nok "O2 expected both ${UIV}/lens-inputs and ${UIV}/bolts to exist as siblings"
fi
# shellcheck disable=SC2086
$PY "${WORK}/slice.py" "$UI_SLICE" "$UI_PROMPT" "${WORK}/svars.sh"
# shellcheck disable=SC1090
. "${WORK}/svars.sh"
eq "$S_EXISTS" "1" "O3 the lens-input file was actually written"
chk "$([ "$S_BODY_BYTES" -gt 0 ] && echo 1 || echo 0)" \
    "O3 the lens-input file is NON-EMPTY (an empty slice would make the next assertion vacuous)" \
    "body is $S_BODY_BYTES bytes"
# THE BOLT LOSES NOTHING — the whole point of D3. Byte-for-byte containment, not
# a similarity check: implementer and design reviewer must hold the identical
# contract, and two renderings are two contracts.
eq "$S_IN_PROMPT" "1" \
   "O3 the lens-input bytes are STILL injected verbatim into the dispatch prompt itself"
eq "$S_HAS_MARKER" "1" \
   "O3 the lens's copy carries the same 'Design system:' marker line validate-ui-quality.sh keys on"
if grep -qF "## Design system (UI-bearing unit" "$UI_PROMPT" 2>/dev/null; then
  ok "O3 the prompt still carries its own '## Design system' section header"
else nok "O3 the design section header vanished from the prompt when the lens copy moved"; fi
if grep -qE '^Design system: ' "$UI_PROMPT" 2>/dev/null; then
  ok "O3 the prompt still carries the 'Design system:' marker line"
else nok "O3 the marker line vanished from the prompt when the lens copy moved"; fi
# mk_vault_json's design_system carries `source` and `provenance`, both of which
# the greenfield path EXCLUDES by contract ("audit-only, must never be injected").
# The lens-input file is a NEW artifact on a NEW path, so the exclusion has to be
# re-proven there — a copy assembled from the raw design_system instead of from
# the shipped rung would leak them and nothing else in the suite would notice.
if grep -qF "audit-only, must never be injected" "$UI_SLICE" 2>/dev/null; then
  nok "O3 the lens-input file leaked the audit-only design_system provenance the greenfield path excludes"
else
  ok "O3 the lens-input file excludes the audit-only source/provenance keys, like the prompt does"
fi

# ── The lens-input file is the LENS'S copy of a rubric, never a mint ─────────
# The obvious companion arm — "UI-bearing but EVERY design input absent, so the
# key must be absent" — is NOT ASSERTED HERE BECAUSE IT IS UNREACHABLE, and
# saying so is worth more than a green line that proves nothing. Measured three
# ways: no vault.json at all, a thin plugin root with no design-intelligence
# references, and a starterkit slice driven to its drop floor at 400 KB of
# ballast. In every one the rubric survives, because the greenfield slice's own
# drop floor is "never fully dropped" and the starterkit branch keeps its `UI/UX:`
# line. `design_slice_path` is therefore always present on a ui_bearing unit;
# the builder's absent-rubric branch is defensive, not exercised. L1 carries the
# absent-key contract on the non-UI unit, which IS the reachable absence.
#
# What IS reachable and load-bearing is the arm below: a vault with NO
# design_system at all. Invariant #5 says the absence is stated and RECORDED, and
# that nothing is defaulted in its place — a fabricated `palette=` here would be
# read by the design lens as the authoritative palette and by
# validate-ui-quality.sh as a clean injection.
NOD="${WORK}/nodesign"
NODV="${NOD}/.mega-sdd/vaults/v1"
mkdir -p "$NODV/units" "$NODV/bolts"
mk_source_tree "$NOD"
cp "$UIV/units/U-050.md" "$NODV/units/U-050.md"     # same UI-bearing unit
# deliberately NO vault.json (no design_system) and NO starterkit-context.yaml
bash "$BUILDER" --cwd="$NOD" --vault="$NODV" --unit=U-050 \
  </dev/null >"${WORK}/nod.json" 2>"${WORK}/nod.err"
NODRC=$?
NOD_PROMPT="${NODV}/bolts/U-050/dispatch-prompt.md"
NOD_SLICE="${NODV}/lens-inputs/U-050/design-slice.md"
# shellcheck disable=SC2086
$PY "${WORK}/keys.py" "${WORK}/nod.json" "${WORK}/kvars.sh"
# shellcheck disable=SC1090
. "${WORK}/kvars.sh"
eq "$NODRC" "0" "O4 a UI unit whose vault carries no design_system still builds a prompt (exit 0)"
eq "$K_HAS_DSP" "1" "O4 the lens still gets a rubric path — the UX floor and modern baseline are real inputs"
eq "$K_DSP_EMPTY" "0" "O4 design_slice_path is never emitted as an empty string"
# NOTHING DEFAULTED. The O3 arm above (full design_system) HAS this line; this
# arm must NOT — that pairing is what makes the assertion a discriminator rather
# than a restatement of "the file is short".
if grep -qE '^Design system: ' "$NOD_SLICE" 2>/dev/null; then
  nok "O4 a 'Design system:' line was composed with no design_system in the vault — invariant #5 (a defaulted palette/typography)"
else
  ok "O4 no 'Design system:' line is composed when the vault has none — no palette or type pairing is invented"
fi
if grep -qF "No design_system in this vault" "$NOD_SLICE" 2>/dev/null; then
  ok "O4 the absence is STATED in the rubric itself, as an OQ for chain end"
else
  nok "O4 the missing design_system must be stated in the slice, not silently skipped"
fi
if grep -qF "design_slice.system" "$NOD_PROMPT" 2>/dev/null; then
  ok "O4 the absence is RECORDED in the prompt's PROVENANCE appendix with a reason"
else
  nok "O4 an absent input must be recorded with a reason (invariant #5) — no design_slice.system entry in the appendix"
fi
# shellcheck disable=SC2086
$PY "${WORK}/slice.py" "$NOD_SLICE" "$NOD_PROMPT" "${WORK}/svars.sh"
# shellcheck disable=SC1090
. "${WORK}/svars.sh"
chk "$([ "$S_BODY_BYTES" -gt 0 ] && echo 1 || echo 0)" \
    "O4 the degraded rubric is still non-empty" "body is $S_BODY_BYTES bytes"
eq "$S_IN_PROMPT" "1" \
   "O4 the degraded rubric is injected verbatim into the prompt too — the bolt loses nothing on this arm either"

echo
echo "════════════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo "assertions: $((PASS + FAIL))   PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
