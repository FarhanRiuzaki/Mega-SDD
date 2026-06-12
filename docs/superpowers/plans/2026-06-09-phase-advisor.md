# Phase Advisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an adversarial second-opinion subagent (`phase-advisor`) to the two upstream interpretation gates (bind-codebase, generate-intent) that catches false-CONFIRMED / fabrication / missed-OQ before the artifact is finalized — non-blocking itself, but feeding the EXISTING binding CONFLICT gate + OQ roll-up.

**Architecture:** One read-only opus `phase-advisor` plugin agent, parametrized per phase via a dispatch checklist. `bind-codebase` dispatches it at a new Step 2.12 (BEFORE Step 3 aggregate counts + Step 5 decision gate) so high-confidence findings materialize as canonical `### CONFLICT-NNN` headings that the existing gate + `validate-handoff-binding-units.sh` (`.validation-blockers.json`) enforce. `generate-intent` dispatches it before the Step 4 self-check so findings materialize as OQs / flagged claims. Moat-asymmetry rail: the advisor may ADD a blocking CONFLICT autonomously but may NEVER auto-downgrade one.

**Tech Stack:** Markdown agent + skill/reference files, bash gate tests (mirroring `tests/de-laravelize/` + `tests/reuse-awareness/`). Plugin-agent frontmatter rules per `plugins/mega-sdd/CLAUDE.md` (name+description only; NO hooks/mcpServers/permissionMode; tools exclude Agent/AskUserQuestion).

**Spec:** `docs/superpowers/specs/2026-06-09-phase-advisor-design.md`

---

## File Structure

**New test files** (`tests/phase-advisor/`):
- `run-all.sh` — suite runner (cd to repo root)
- `test-advisor-agent.sh` — agent exists; frontmatter-compliant (read-only tools, model opus, no hooks/mcpServers/permissionMode); findings-schema present
- `test-bind-advisor-wired.sh` — bind-codebase dispatches advisor BEFORE Step 3 counts; canonical CONFLICT-NNN materialization; confidence-gated; moat-asymmetry rail; `--no-advisor`
- `test-intent-advisor-wired.sh` — generate-intent dispatches advisor before finalize; OQ/flag materialization; `--no-advisor`
- `test-provenance-states.sh` — advisor-skipped / advisor-clean / advisor-unavailable are three distinct states in both skills

**New plugin files:**
- `plugins/mega-sdd/agents/phase-advisor.md` — the agent (system prompt = phase-agnostic adversarial-review discipline)
- `plugins/mega-sdd/references/advisor-findings-schema.md` — the findings schema + evidence-required + moat-asymmetry rails (shared)
- `plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md` — binding focus checklist
- `plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md` — intent focus checklist
- `tests/fixtures/phase-advisor/binding-false-confirmed/` — scenario fixture (a CONFIRMED that should be CONFLICT)

**Modified:**
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 2.12 dispatch + materialization + `--no-advisor` flag + provenance
- `plugins/mega-sdd/skills/generate-intent/SKILL.md` — dispatch before Step 4 + materialization + `--no-advisor` + provenance
- Versions: bind-codebase + generate-intent skill frontmatter; `plugin.json` + `marketplace.json` → v4.6.0

---

## Task 1: phase-advisor agent + findings schema

**Files:**
- Create: `plugins/mega-sdd/agents/phase-advisor.md`, `plugins/mega-sdd/references/advisor-findings-schema.md`
- Create: `tests/phase-advisor/run-all.sh`, `tests/phase-advisor/test-advisor-agent.sh`

- [ ] **Step 1: Suite runner**
```bash
mkdir -p tests/phase-advisor
cat > tests/phase-advisor/run-all.sh <<'EOF'
#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || { echo "cannot locate repo root"; exit 2; }
fail=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "=== $(basename "$t") ==="
  bash "$t" || { echo "FAIL: $(basename "$t")"; fail=1; }
done
exit $fail
EOF
chmod +x tests/phase-advisor/run-all.sh
```

- [ ] **Step 2: Write the failing test**
```bash
cat > tests/phase-advisor/test-advisor-agent.sh <<'EOF'
#!/usr/bin/env bash
set -u
a="plugins/mega-sdd/agents/phase-advisor.md"
s="plugins/mega-sdd/references/advisor-findings-schema.md"
err=0
[ -f "$a" ] || { echo "missing phase-advisor.md"; err=1; }
[ -f "$s" ] || { echo "missing advisor-findings-schema.md"; err=1; }
if [ -f "$a" ]; then
  fm=$(sed -n '1,12p' "$a")
  echo "$fm" | grep -q 'name: phase-advisor' || { echo "bad name"; err=1; }
  echo "$fm" | grep -q 'model: opus' || { echo "advisor must be opus"; err=1; }
  echo "$fm" | grep -qiE 'tools:.*Read' || { echo "needs Read tool"; err=1; }
  # read-only: must NOT have Write/Edit; must NOT have forbidden plugin-agent keys
  echo "$fm" | grep -qiE 'Write|Edit' && { echo "advisor must be read-only (no Write/Edit)"; err=1; }
  echo "$fm" | grep -qiE 'hooks:|mcpServers:|permissionMode:' && { echo "forbidden plugin-agent frontmatter key"; err=1; }
  grep -qiE 'adversarial|find what is wrong|refute|second opinion' "$a" || { echo "agent body not adversarial"; err=1; }
  grep -qiE 'evidence|_source|cite' "$a" || { echo "agent missing evidence-required discipline"; err=1; }
fi
if [ -f "$s" ]; then
  for t in false_confirmed missed_match false_conflict fabrication missed_oq misclassification; do
    grep -q "$t" "$s" || { echo "schema missing finding type: $t"; err=1; }
  done
  grep -qiE 'evidence' "$s" || { echo "schema missing evidence rail"; err=1; }
  grep -qiE 'never auto-downgrade|never auto-remove|human-only' "$s" || { echo "schema missing moat-asymmetry rail"; err=1; }
fi
exit $err
EOF
chmod +x tests/phase-advisor/test-advisor-agent.sh
bash tests/phase-advisor/test-advisor-agent.sh; echo exit=$?
```
Expected exit=1.

- [ ] **Step 3: Write `plugins/mega-sdd/agents/phase-advisor.md`**
```markdown
---
name: phase-advisor
description: Adversarial second-opinion reviewer for an upstream mega-sdd phase artifact (a binding or a vault) BEFORE it is finalized. Read-only. Reads the artifact AND its cited sources and reports evidence-backed findings (false-CONFIRMED, fabrication, missed OQ, mis-classification). The dispatching skill materializes findings; the advisor never edits artifacts. Phase-specific focus arrives in the dispatch prompt.
tools: Read, Grep, Glob, Bash
model: opus
color: red
---

You are an ADVERSARIAL reviewer of ONE mega-sdd phase artifact, dispatched BEFORE it is finalized. Your job is to find what is WRONG before it is committed — not to praise what is right. The phase-specific focus checklist arrives in your dispatch prompt; this body is the phase-agnostic discipline.

## Iron discipline
1. **Find the wrong thing.** Default to surfacing a problem as a finding rather than swallowing it. A clean pass (zero findings) is a valid, expected outcome — but only after you actually looked.
2. **Read the artifact AND its cited sources.** Every finding MUST cite source evidence (file:line / PRD §X / codebase-map entry). NO finding without evidence — you do not get to fabricate problems any more than the producer gets to fabricate claims.
3. **You are read-only.** You PROPOSE findings; the dispatching skill materializes them. You cannot rewrite a verdict, add a vault claim, or remove a CONFLICT. The moat-asymmetry is absolute: you may flag a CONFLICT as a suspected false alarm, but DOWNGRADING a CONFLICT is human-only.
4. **Structured output only.** Your final message IS the data — return findings per `references/advisor-findings-schema.md` (a YAML block). The skill acts on it.

## Workflow
1. Read your dispatch prompt's focus checklist + the named artifact + every source it points to.
2. For each focus item, hunt the specific failure mode. When you suspect one, open the cited source and verify before emitting.
3. Emit findings (id, type, severity, target, issue, evidence, suggested_action, confidence). Drop any finding you cannot back with evidence.
4. Emit a summary count. If nothing is wrong, emit empty findings + say so explicitly.

## Report format
A single YAML document per `references/advisor-findings-schema.md`. Nothing else.
```

- [ ] **Step 4: Write `plugins/mega-sdd/references/advisor-findings-schema.md`**
```markdown
# Advisor Findings Schema

> What `phase-advisor` returns and the dispatching skill materializes. Used by `bind-codebase` + `generate-intent`.

## Schema
\`\`\`yaml
phase: bind | intent
advisor_model: opus
findings:
  - id: ADV-001
    type: false_confirmed | missed_match | false_conflict | fabrication | missed_oq | misclassification | coverage_gap | state_map_error
    severity: high | medium | low
    target: "<verdict-id | claim ref | OQ-id | vault file:section>"
    issue: "<one-line statement of what is wrong>"
    evidence: "<source cite — codebase-map entry / PRD §X / file:line>"
    suggested_action: "<reclassify to CONFLICT | raise OQ | drop fabricated claim | retag business->tech | ...>"
    confidence: high | medium | low
summary: { high: N, medium: N, low: N }
\`\`\`

## Rails
1. **Evidence required.** No finding without an `evidence` cite. Evidenceless findings are dropped at materialization (anti-fabrication symmetry with producer rails).
2. **Read-only advisor.** The advisor proposes; the skill materializes. The advisor never writes the artifact.
3. **Moat-asymmetry (protects invariant #2).** The advisor may ADD a blocker autonomously (a high-confidence `false_confirmed`/`missed_match` → a real `### CONFLICT-NNN`, fail-safe). It may NEVER auto-remove or auto-downgrade an existing CONFLICT — a `false_conflict` finding is FLAGGED ONLY; downgrade is human-only (via `resolve-oq`). A planner/implementer must NOT make `false_conflict` materialization symmetric with `false_confirmed`.
4. **Confidence-gated materialization (binding):** HIGH → canonical `### CONFLICT-NNN`; MED/LOW → an OQ (non-blocking, surfaced).
5. **Distinct provenance:** advisor-skipped (`--no-advisor`), advisor-clean (0 findings), and advisor-unavailable (agent error/timeout) are THREE distinct recorded states — a skipped/failed advisor is NEVER reported as "reviewed, no issues".
```

- [ ] **Step 5: Run test → PASS.** No regression: `bash tests/de-laravelize/run-all.sh; echo de=$?` → 0; `bash tests/reuse-awareness/run-all.sh; echo reuse=$?` → 0.

- [ ] **Step 6: Commit**
```bash
git add plugins/mega-sdd/agents/phase-advisor.md plugins/mega-sdd/references/advisor-findings-schema.md tests/phase-advisor/run-all.sh tests/phase-advisor/test-advisor-agent.sh
git commit -m "feat(advisor): phase-advisor agent (read-only opus) + findings schema with moat-asymmetry rail"
```

---

## Task 2: bind-codebase advisor checklist (binding focus)

**Files:**
- Create: `plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md`

- [ ] **Step 1: Write `bind-codebase/references/advisor-checklist.md`**
```markdown
# Binding advisor checklist (phase-advisor dispatch focus — phase: bind)

Reads: `binding.md` (draft verdicts), `codebase-map.md`, the vault, the KB (if present).

## Hunt these (priority order)
1. **false_confirmed (PRIORITY)** — for every CONFIRMED verdict, open the cited codebase anchor: does it REALLY exist and match the vault claim? A CONFIRMED backed by a hallucinated/unrelated anchor is the worst failure — it silently lets a real conflict through the moat.
2. **missed_match** — for every "not found → OQ/NEW", is it actually present in the codebase under a different name/path (should be CONFIRMED or CONFLICT)?
3. **false_conflict** — is a CONFLICT a real contradiction or a false alarm? FLAG ONLY (never downgrade — human-only).
4. **state_map_error** — Implementation State Map mislabel (IMPLEMENTED vs NEW) vs the actual anchor.

## Materialization (done by bind-codebase, not the advisor)
- `false_confirmed` / `missed_match`, confidence HIGH → a canonical `### CONFLICT-NNN` (tagged `source: advisor` / `ADV-`), fail-safe blocking.
- same, confidence MED/LOW → raise an OQ (non-blocking, surfaced).
- `false_conflict` / `state_map_error` → FLAG for human review; NEVER auto-applied.
```

- [ ] **Step 2: Verify it exists + names the binding finding types**
```bash
grep -qE 'false_confirmed|missed_match|false_conflict|state_map_error' plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md && echo OK || echo MISSING
grep -qiE 'never downgrade|human-only' plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md && echo "asymmetry OK" || echo "asymmetry MISSING"
```

- [ ] **Step 3: Commit**
```bash
git add plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md
git commit -m "feat(bind-codebase): binding advisor focus checklist (false-CONFIRMED hunt)"
```

---

## Task 3: generate-intent advisor checklist (intent focus)

**Files:**
- Create: `plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md`

- [ ] **Step 1: Write `generate-intent/references/advisor-checklist.md`**
```markdown
# Intent advisor checklist (phase-advisor dispatch focus — phase: intent)

Reads: the vault (7 files) + the source (PRD/BRD/Figma/brief/KB).

## Hunt these
1. **fabrication** — any claim/entity/flow with no traceable source → should be an OQ, not an assertion.
2. **missed_oq** — a genuine gap in the source that was silently filled instead of surfaced.
3. **misclassification** — an OQ tagged business vs tech incorrectly (drives `resolution_mode` downstream).
4. **coverage_gap** — a material source section with no representation in the vault.

## Materialization (done by generate-intent, not the advisor)
- `fabrication` → demote the claim to an OQ (or flag it) + Changelog note.
- `missed_oq` → add an OQ to the roll-up (tagged per the OQ classifier).
- `misclassification` → retag the OQ category.
- `coverage_gap` → add an OQ or a flagged note.
```

- [ ] **Step 2: Verify**
```bash
grep -qE 'fabrication|missed_oq|misclassification|coverage_gap' plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md && echo OK || echo MISSING
```

- [ ] **Step 3: Commit**
```bash
git add plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md
git commit -m "feat(generate-intent): intent advisor focus checklist (fabrication/missed-OQ hunt)"
```

---

## Task 4: Wire bind-codebase dispatch + materialization (Step 2.12)

**Files:**
- Modify: `plugins/mega-sdd/skills/bind-codebase/SKILL.md`
- Test: `tests/phase-advisor/test-bind-advisor-wired.sh`

- [ ] **Step 1: Write the failing test**
```bash
cat > tests/phase-advisor/test-bind-advisor-wired.sh <<'EOF'
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/bind-codebase/SKILL.md"
err=0
grep -qiE 'phase-advisor' "$f" || { echo "bind does not dispatch phase-advisor"; err=1; }
grep -q 'advisor-checklist' "$f" || { echo "bind does not reference the binding advisor checklist"; err=1; }
grep -qE 'no-advisor' "$f" || { echo "bind missing --no-advisor flag"; err=1; }
grep -qiE 'CONFLICT-NNN|canonical .*CONFLICT' "$f" || { echo "bind materialization does not specify canonical CONFLICT-NNN"; err=1; }
grep -qiE 'before .*aggregate|Step 2.12|before Step 3' "$f" || { echo "bind advisor not ordered before aggregate counts"; err=1; }
grep -qiE 'never .*downgrade|human-only|flag .*only' "$f" || { echo "bind missing moat-asymmetry"; err=1; }
exit $err
EOF
chmod +x tests/phase-advisor/test-bind-advisor-wired.sh
bash tests/phase-advisor/test-bind-advisor-wired.sh; echo exit=$?
```
Expected exit=1.

- [ ] **Step 2: Add the `--no-advisor` flag** to the bind-codebase `**Flags:**` line (currently `--strict`, `--auto`, `--kb`, ...): append `, --no-advisor (skip the phase-advisor pass)`.

- [ ] **Step 3: Insert Step 2.12** in `bind-codebase/SKILL.md` immediately BEFORE the `**3. Aggregate counts.**` line:
```markdown
**2.12 — Phase-advisor pass (adversarial second-opinion; default-on, `--no-advisor` skips).** Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus), the draft verdicts, `codebase-map.md`, the vault, and the KB. Materialize its findings INTO the verdict set BEFORE Step 3 so they are counted + written as canonical `### CONFLICT-NNN` headings in Step 4 (the exact token the Step 5 gate AND `validate-handoff-binding-units.sh` → `.validation-blockers.json` read):
- `false_confirmed`/`missed_match` confidence HIGH → add a real CONFLICT verdict (canonical `CONFLICT-NNN`, tagged `source: advisor`). This is fail-safe blocking — a suspected hole in the moat closes the gate until a human clears it via `resolve-oq`.
- same, confidence MED/LOW → add an OQ (non-blocking, surfaced).
- `false_conflict`/`state_map_error` → FLAG ONLY in `binding.md`; the advisor may ADD a blocker autonomously but may NEVER auto-remove or auto-downgrade a CONFLICT (downgrade is human-only — invariant #2). 
- Evidenceless findings are dropped. Record the pass in the Step 6 audit log: `advisor: {model, findings: {high,med,low}}` OR `advisor: skipped` (`--no-advisor`) OR `advisor: unavailable` (agent error — NEVER reported as clean). Full focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`.
```

- [ ] **Step 4: Run test → PASS.** No regression: de + reuse suites 0.

- [ ] **Step 5: Commit**
```bash
git add plugins/mega-sdd/skills/bind-codebase/SKILL.md tests/phase-advisor/test-bind-advisor-wired.sh
git commit -m "feat(bind-codebase): Step 2.12 phase-advisor pass → canonical CONFLICT-NNN before the gate"
```

---

## Task 5: Wire generate-intent dispatch + materialization

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/SKILL.md`
- Test: `tests/phase-advisor/test-intent-advisor-wired.sh`

- [ ] **Step 1: Write the failing test**
```bash
cat > tests/phase-advisor/test-intent-advisor-wired.sh <<'EOF'
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/generate-intent/SKILL.md"
err=0
grep -qiE 'phase-advisor' "$f" || { echo "intent does not dispatch phase-advisor"; err=1; }
grep -q 'advisor-checklist' "$f" || { echo "intent does not reference the intent advisor checklist"; err=1; }
grep -qE 'no-advisor' "$f" || { echo "intent missing --no-advisor flag"; err=1; }
grep -qiE 'before .*self-check|before .*Step 4|before delivery|before finaliz' "$f" || { echo "intent advisor not ordered before finalize"; err=1; }
grep -qiE 'OQ|flag' "$f" || { echo "intent materialization not specified"; err=1; }
exit $err
EOF
chmod +x tests/phase-advisor/test-intent-advisor-wired.sh
bash tests/phase-advisor/test-intent-advisor-wired.sh; echo exit=$?
```
Expected exit=1.

- [ ] **Step 2: Add the `--no-advisor` flag** to the generate-intent `## Flags` table (add a row): `| `--no-advisor` | Skip the phase-advisor adversarial pass before finalize. | `references/advisor-checklist.md` |`.

- [ ] **Step 3: Insert the dispatch step** in the `## Workflow skeleton`, between Step 3.5 (OQ classifier) and `**Step 4 — Self-check before delivery.**`:
```markdown
**Step 3.7 — Phase-advisor pass (adversarial second-opinion; default-on, `--no-advisor` skips).** Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (intent focus), the drafted 7 vault files, and the source (PRD/brief/KB). Materialize its findings BEFORE finalize:
- `fabrication` → demote the claim to an OQ (or flag) + Changelog note.
- `missed_oq` → add an OQ to the roll-up (run it through the Step 3.5 classifier).
- `misclassification` → retag the OQ `category`.
- `coverage_gap` → add an OQ / flagged note.
Evidenceless findings are dropped. Record the pass in `vault.json` provenance: `advisor: {model, findings:{high,med,low}}` OR `advisor: skipped` (`--no-advisor`) OR `advisor: unavailable` (agent error — NEVER reported as clean). Focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`.
```

- [ ] **Step 4: Run test → PASS.** No regression: de + reuse + phase-advisor suites 0.

- [ ] **Step 5: Commit**
```bash
git add plugins/mega-sdd/skills/generate-intent/SKILL.md tests/phase-advisor/test-intent-advisor-wired.sh
git commit -m "feat(generate-intent): Step 3.7 phase-advisor pass → OQ/flag materialization before finalize"
```

---

## Task 6: Provenance-states gate + scenario fixture

**Files:**
- Create: `tests/phase-advisor/test-provenance-states.sh`
- Create: `tests/fixtures/phase-advisor/binding-false-confirmed/README.md` (scenario doc)

- [ ] **Step 1: Write the provenance test**
```bash
cat > tests/phase-advisor/test-provenance-states.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
for f in plugins/mega-sdd/skills/bind-codebase/SKILL.md plugins/mega-sdd/skills/generate-intent/SKILL.md; do
  grep -qiE 'advisor: skipped|advisor.*skipped' "$f" || { echo "$f missing 'skipped' provenance"; err=1; }
  grep -qiE 'advisor: unavailable|advisor.*unavailable' "$f" || { echo "$f missing 'unavailable' provenance"; err=1; }
  grep -qiE 'never reported as clean|NEVER reported as clean' "$f" || { echo "$f does not distinguish unavailable from clean"; err=1; }
done
exit $err
EOF
chmod +x tests/phase-advisor/test-provenance-states.sh
bash tests/phase-advisor/test-provenance-states.sh; echo exit=$?
```
(Should PASS if Tasks 4+5 included the three provenance states; if it fails, add the missing provenance wording to the relevant SKILL.md.)

- [ ] **Step 2: Write the scenario fixture doc** `tests/fixtures/phase-advisor/binding-false-confirmed/README.md`:
```markdown
# Scenario: binding false-CONFIRMED → advisor → CONFLICT-NNN → gate

A vault claim is marked CONFIRMED against a codebase anchor that does NOT actually match.

**Expected:** the binding phase-advisor emits a `false_confirmed` finding (confidence HIGH) → bind-codebase materializes a canonical `### CONFLICT-NNN` (tagged `source: advisor`) in `binding.md` BEFORE Step 3 → Step 5 decision gate sees `conflict > 0` → does NOT write `<vault>/bound/` → `validate-handoff-binding-units.sh` writes the blocker into `.validation-blockers.json` → execute-bolts PreToolUse hook fails closed.

This is a manual/behavioral scenario (the advisor is an LLM agent — not a deterministic bash assertion). Run it as a field test against a real vault+codebase with a planted false-CONFIRMED.
```

- [ ] **Step 3: Run the full phase-advisor suite → PASS**
Run: `bash tests/phase-advisor/run-all.sh; echo pa=$?` → 0.

- [ ] **Step 4: Commit**
```bash
git add tests/phase-advisor/test-provenance-states.sh tests/fixtures/phase-advisor
git commit -m "test(advisor): provenance-states gate + binding false-CONFIRMED scenario fixture"
```

---

## Task 7: Version bumps + full suites green

**Files:**
- Modify: bind-codebase + generate-intent SKILL.md versions; `plugin.json` + `marketplace.json` → v4.6.0

- [ ] **Step 1: Bump skill versions** — read each frontmatter `version:` and bump minor: `bind-codebase` and `generate-intent` SKILL.md.

- [ ] **Step 2: Bump plugin + marketplace** 4.5.0 → 4.6.0 (both manifests in sync); add a `version_note` line summarizing the phase-advisor feature.

- [ ] **Step 3: All suites green + JSON valid**
```bash
python3 -c "import json;json.load(open('plugins/mega-sdd/.claude-plugin/plugin.json'));json.load(open('.claude-plugin/marketplace.json'));print('json ok')"
for s in phase-advisor de-laravelize reuse-awareness; do bash tests/$s/run-all.sh >/dev/null 2>&1; echo "$s=$?"; done
```
All must be 0.

- [ ] **Step 4: Commit**
```bash
git add -A
git commit -m "chore(release): phase-advisor v4.6.0 bump; all gate suites green"
```

---

## Self-Review (completed by author)

- **Spec coverage:** §1/§2.1 agent→Task 1; §2.2 phase checklists→Tasks 2-3; §2.3 findings schema→Task 1; §3 data flow + materialization (binding Step 2.12 before counts/gate; intent before finalize)→Tasks 4-5; §3.1 provenance→Tasks 4/5/6; §4 halt/error (skipped/clean/unavailable distinct; evidence-drop)→Tasks 1/4/5/6; §5 testing (agent frontmatter, wiring, scenario)→Tasks 1/4/5/6; moat-asymmetry rail→Tasks 1/2/4; versioning→Task 7. Acceptance #1-9 all mapped.
- **Channel correctness (the load-bearing wiring):** Task 4 places the dispatch at Step 2.12 BEFORE "3. Aggregate counts" and materializes canonical `### CONFLICT-NNN` (validated against `validate-handoff-binding-units.sh`'s `CONFLICT-NNN` form + the execute-bolts PreToolUse hook). This is the spec's load-bearing claim, encoded as the test assertion `before aggregate` + `canonical CONFLICT-NNN`.
- **Placeholder scan:** agent, schema, both checklists, all test scripts authored in full; SKILL insertions cite exact anchor lines ("before **3. Aggregate counts**", "between Step 3.5 and **Step 4 — Self-check**").
- **Type consistency:** finding types (`false_confirmed/missed_match/false_conflict/state_map_error/fabrication/missed_oq/misclassification/coverage_gap`) + provenance states (skipped/clean/unavailable) + materialization rules (HIGH→CONFLICT-NNN, MED/LOW→OQ, false_conflict→flag-only) are identical across schema (T1), checklists (T2/T3), and both skill wirings (T4/T5).
- **Behavioral validation honesty:** the advisor is an LLM agent, so the deterministic gates check WIRING + STRUCTURE; the false-CONFIRMED→CONFLICT→gate behavior is a documented scenario fixture (Task 6), not a fake bash assertion.
