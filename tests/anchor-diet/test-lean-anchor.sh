#!/usr/bin/env bash
# Pin test for the lean-anchor session-start diet.
#
# session-start injects the using-mega-sdd anchor on EVERY session + EVERY
# compaction. The diet trims the injected payload to the routing-critical CORE
# (triggers + auto-trigger logic + the hard rule), dropping pure explanation
# (pipeline diagram, phase-ownership table, red-flags, priority-order) which
# stays loadable via the Skill tool. The danger of a diet is silently dropping
# a trigger keyword -> a routing regression on a cold (post-compaction) start.
# This test is the guard: every load-bearing ID/EN + natural-language trigger
# MUST survive on the ALWAYS-LOADED surface (the injected core OR some skill's
# frontmatter description — both reload on a cold/post-compaction start), the
# hard rule MUST survive in the core, and the dropped EXPLANATION detail MUST NOT
# appear in the injected core (proving the diet actually happened). M-13 moved the
# verbatim keyword bullets core->description; the union check below is the guard.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/plugins/mega-sdd/skills/using-mega-sdd/SKILL.md"
HOOK="$ROOT/plugins/mega-sdd/hooks/session-start"
MARKER='ANCHOR-CORE ends'

fail=0
note() { printf '  %s\n' "$1"; }
ok()   { printf 'ok   %s\n' "$1"; }
bad()  { printf 'FAIL %s\n' "$1"; fail=1; }

[ -f "$SKILL" ] || { echo "FAIL anchor SKILL.md missing: $SKILL"; exit 1; }
[ -f "$HOOK" ]  || { echo "FAIL session-start hook missing: $HOOK"; exit 1; }

# The SAME extraction session-start uses: strip YAML frontmatter, print body
# up to the ANCHOR-CORE marker.
extract_core() {
  awk 'BEGIN{dash=0;body=0}
       /^---[[:space:]]*$/{dash++; if(dash==2)body=1; next}
       body==0{next}
       /ANCHOR-CORE ends/{exit}
       {print}' "$1"
}

# ---- 1) marker exists -------------------------------------------------------
if grep -q "$MARKER" "$SKILL"; then ok "core-end marker present in SKILL.md"
else bad "core-end marker ('$MARKER') missing from SKILL.md"; fi

CORE="$(extract_core "$SKILL")"
if [ -z "$CORE" ]; then bad "extracted core is EMPTY (frontmatter/marker drift)"; fi

# ---- 2) frontmatter stripped from the injected core -------------------------
if printf '%s' "$CORE" | grep -qE '^name:[[:space:]]*using-mega-sdd|^description:'; then
  bad "injected core still contains YAML frontmatter (name:/description:) — wasted duplication"
else ok "frontmatter stripped from injected core"; fi

# ---- 3) the hard rule survives ---------------------------------------------
core_has() { printf '%s' "$CORE" | grep -qiF "$1"; }
for needle in "STOP" "Skill" "orchestrate-flow"; do
  if core_has "$needle"; then ok "hard rule keeps: $needle"; else bad "hard rule LOST: $needle"; fi
done
# the bind CONFLICT gate line
if core_has "bind-codebase" && core_has "CONFLICT"; then ok "bind CONFLICT gate kept in core"
else bad "bind CONFLICT gate dropped from core"; fi

# ---- 3b) the 5.0.0 front-door contract survives in the core -----------------
# P6 collapsed the natural-language lanes to ONE rule: any SDD lane phrase →
# the /mega-sdd front door. The core must carry that rule + the other two
# public verbs + the Skill-dispatch (never Agent-offload) moat line — the same
# intent as the trigger checks: what the anchor promises must survive the diet.
for needle in "/mega-sdd" "front door" "/mega-sdd:sync" "/mega-sdd:emit"; do
  if core_has "$needle"; then ok "front-door rule keeps: $needle"; else bad "front-door rule LOST: $needle"; fi
done
if core_has "never Agent-offload"; then ok "core keeps the Skill-dispatch moat line"
else bad "Skill-dispatch (never Agent-offload) line dropped from core"; fi

# ---- 4) EVERY load-bearing trigger survives on the ALWAYS-LOADED surface -----
# M-13 (token-efficiency B3): the diet collapsed the core's verbatim keyword
# bullets to a pointer at the always-loaded descriptions. The real cold-start
# invariant is NOT "the phrase is in the core" but "the phrase is reachable on a
# cold/post-compaction start" — i.e. present in the injected core OR in some
# mega-sdd skill's frontmatter description (the harness reloads the full skill
# listing + descriptions on startup AND on compaction). So we assert each trigger
# against the UNION of the core + every skill description. A phrase missing from
# BOTH is a genuine routing regression; a phrase that merely moved core→description
# is safe. (This is why the collapse first UNION'd bound-vault / legacy
# intelligence / source of truth dari legacy into using-mega-sdd's own description
# and check consistency / consistency report into analyze's.)
ALWAYS_LOADED="$CORE"$'\n'"$(
  for sk in "$ROOT"/plugins/mega-sdd/skills/*/SKILL.md; do
    awk 'BEGIN{d=0} /^---[[:space:]]*$/{d++; next} d==1 && /^description:/{print} d>=2{exit}' "$sk"
  done
)"
loaded_has() { printf '%s' "$ALWAYS_LOADED" | grep -qiF "$1"; }
TRIGGERS=(
  # EN pipeline keywords
  "intent" "unit" "bolt" "vault" "PRD" "BRD" "binding" "bound-vault" "knowledge-base"
  "extract intelligence" "reverse engineer" "legacy intelligence" "rebuild" "sync" "auto"
  # ID variants
  "pecah PRD" "buat dev" "lanjut" "next" "jalankan otomatis"
  "siapkan context" "rebuild di stack baru" "source of truth dari legacy"
  # natural-language diagnostic/output lanes
  "cek konsistensi" "consistency report" "blast radius" "apa yang kena kalau ubah ini"
  "buat FSD" "pasang tools"
  # CWD signal
  ".mega-sdd/"
)
for t in "${TRIGGERS[@]}"; do
  if loaded_has "$t"; then ok "trigger reachable (core∪descriptions): $t"; else bad "TRIGGER DROPPED from ALL always-loaded surfaces: '$t'"; fi
done

# ---- 5) the diet actually happened: dropped detail NOT in the core ----------
# These headings are explanation, loadable on demand — they must be BELOW the
# marker, i.e. absent from the injected core.
for dropped in "## Phase ownership" "## Red flags" "## Priority order"; do
  if printf '%s' "$CORE" | grep -qF "$dropped"; then
    bad "detail not trimmed — '$dropped' still in injected core"
  else ok "detail trimmed from core: $dropped"; fi
done

# ---- 6) the dropped detail is still LOADABLE (present below the marker) ------
# v7.0.0: "## Red flags" is DELETED from the skill entirely (gate-1 decision —
# the table shamed inline work and fought the S/M/L weight table), so it is no
# longer in this keep list; §5 still asserts it never reappears in the core.
for keep in "## Phase ownership" "## The pipeline" "## Priority order"; do
  if grep -qF "$keep" "$SKILL"; then ok "detail still loadable in full SKILL.md: $keep"
  else bad "detail LOST entirely from SKILL.md (not just trimmed): $keep"; fi
done

# ---- 7) session-start uses marker extraction + fail-open fallback ------------
if grep -q "ANCHOR-CORE ends" "$HOOK"; then ok "session-start extracts at the marker"
else bad "session-start does not reference the ANCHOR-CORE marker (still cat's whole file?)"; fi
# fail-open: empty extraction must fall back to full cat, never inject nothing
if grep -qE 'if \[ -z "\$ANCHOR_CONTENT" \]' "$HOOK"; then ok "session-start has empty-extraction fail-open fallback"
else bad "session-start missing fail-open fallback (empty core would inject NOTHING -> routing breaks)"; fi

echo
if [ "$fail" -eq 0 ]; then echo "PASS lean-anchor pins"; exit 0
else echo "lean-anchor pins FAILED"; exit 1; fi
