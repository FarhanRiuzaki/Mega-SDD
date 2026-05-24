# Wave Dispatch Templates + Quality Gates

Per-wave subagent prompt templates + grep commands for the quality gate that runs between waves. Read this BEFORE dispatching any wave.

---

## Model tier per wave (v3.25.0+, Iter 34)

Each wave dispatch consults `plugins/mega-sdd/references/model-tiers.md` for its model tier:

- **Wave 1** (artifact extraction): `extract-intelligence-wave-1` → default sonnet
- **Wave 2** (domain extraction): `extract-intelligence-wave-2` → default sonnet
- **Wave 3** (cross-reference): `extract-intelligence-wave-3` → default sonnet
- **Wave 4** (mutability classification): `extract-intelligence-wave-4` → default sonnet
- **Wave 5** (synthesis): `extract-intelligence-wave-5` → **default opus** (holistic synthesis)

Override per role via CLI flag / project config / user preference (see `references/model-tiers.md §Override syntax`).

---

## Generic agent prompt structure

Every wave's subagent prompt MUST follow this skeleton:

```
ROLE: Legacy code archaeologist for [wave-specific scope].

CONTEXT:
- Project at: <absolute path>
- Legacy stack: <language>, <db>, <integrations>
- Target stack: <new stack the rebuild will use>
- Output MUST BE TECH-AGNOSTIC — no legacy stack terms outside §11 Source References + 50-integrations/.

SEED INPUT (cross-check only, do NOT blindly trust):
- <path to forensic dump if it exists; otherwise: "none">

LEGACY FILES TO READ (explicit list, with file sizes):
- <file1> (<size> KB)
- <file2> (<size> KB)
…

OUTPUT TO: <absolute path to MD file>

USE TEMPLATE: see `references/knowledge-base-schema.md` §per-domain-11-section-template.

DISCIPLINE (non-negotiable):
- Citation required: file:line for every non-trivial claim, listed in §11.
- Confidence marker: [VERIFIED] / [INFERRED] / [OPEN] on every non-trivial claim.
- Mutability tier (v1.4+ Iter 22): [LOCKED] / [INTENT] / [ARTIFACT] paired with the confidence marker — see `references/knowledge-base-schema.md` §Marker conventions Axis 2.
  - Default tier when uncertain: [INTENT] (NEVER auto-default to [LOCKED] or [ARTIFACT] — both need positive evidence)
  - [LOCKED]: regulatory citation, contract spec, audit trail, external FK
  - [ARTIFACT]: zero-caller code, legacy stack workaround, dead branch
- Tech-agnostic vocabulary outside §11 and 50-integrations/.
- Compare .bak / dated files vs live versions; document discrepancies in §9.
- NO fabrication. Ambiguous confidence → [OPEN]. Ambiguous mutability → [INTENT] default.

REPORT BACK (last line of your response, exact format):
- path: <absolute output path>
- verified: <int>
- inferred: <int>
- open: <int>
- locked: <int>
- intent: <int>
- artifact: <int>
- sources_cited: <int>
- gate_self_check: pass | fail (<reason if fail>)
```

---

## Wave 0 — Prep (main thread)

Not dispatched; main thread runs:

1. Validate legacy codebase path exists and is non-empty.
2. Create `{out}/knowledge-base/` skeleton: all 7 sub-dirs (`00-overview/`, `10-domains/`, …, `99-rebuild-architecture/`).
3. If `--seed=<path>` provided: copy seed file to `{out}/_source/` (read-only cross-reference).
4. Enumerate legacy codebase: top-level dirs, file types, total file count, total size, language breakdown.
5. Persist enumeration to `{out}/knowledge-base/.scan-meta.json` (used by later waves for file selection).
6. Confirm with user if `--auto` not set; show file count + estimated parallel-agent dispatch count.

Gate before Wave 1: skeleton dirs exist, seed copied (if provided).

---

## Wave 1 — Foundation (3 parallel subagents)

Goal: anchor docs for waves 2-4. Glossary defines terms; classification picks the master list; data-model and workflows define the cross-cutting structure.

Dispatch 3 agents in parallel:

**Agent 1.A — `00-overview/`** (4 outputs):
```
ROLE: Legacy code archaeologist for system overview.

SCOPE: Produce 4 files in {out}/knowledge-base/00-overview/:
  - system-purpose.md (2-3 paragraphs; what the system does in business terms)
  - glossary.md (40+ terms; every domain term + system term used elsewhere in KB)
  - module-classification.md (table: domain → Master|Workflow|Reporting|Integration|Reference + rationale)
  - actors-and-roles.md (every role found in legacy auth/RBAC code + role × module access matrix)

CONTEXT (continued from generic prompt):
- Read legacy auth/login/RBAC code first to identify roles.
- Read top-level module folders to identify domain boundaries.
- Glossary entries cite at least one source file:line.
```

**Agent 1.B — `30-data-model/`** (3 outputs):
```
ROLE: Legacy code archaeologist for data layer.

SCOPE: Produce 3 files in {out}/knowledge-base/30-data-model/:
  - conceptual-erd.md (Mermaid ER; LEGACY shape, not rebuild shape; tech-agnostic types)
  - core-entities.md (every entity used in 2+ domains)
  - reference-entities.md (lookup tables, parameter tables, ref data)

CONTEXT:
- Read schema dumps, migration files, model classes if present.
- For each entity: name, purpose, key fields with marker per field, FK relations.
- Tech-agnostic field types: decimal, text, datetime, …  — never varchar(255), int(11).
```

**Agent 1.C — `20-workflows/`** (variable outputs):
```
ROLE: Legacy code archaeologist for cross-cutting workflows.

SCOPE: Produce files in {out}/knowledge-base/20-workflows/ for each cross-cutting workflow pattern detected (maker-checker, approval state machine, amendment-reversal flow, …).

CONTEXT:
- Don't enumerate every workflow yet — only the cross-cutting patterns that span multiple domains.
- Per-domain transactional workflows belong to Wave 3, not here.
- State-machine docs use a state-diagram table or mermaid stateDiagram.
```

**Gate before Wave 2:**
```bash
# Run from {out}/knowledge-base/
GATE=0
for f in 00-overview/*.md 30-data-model/*.md 20-workflows/*.md; do
  [[ -f "$f" ]] || { echo "MISSING: $f"; GATE=1; }
done
# Glossary completeness check
grep -c '^## ' 00-overview/glossary.md  # ≥40 entries expected
# Forbidden patterns in non-allowed sections
grep -n 'varchar\|int(11)\|MySQL\|MSSQL\|composer' 10-domains/*.md 20-workflows/*.md 30-data-model/*.md 2>/dev/null | grep -v 'Source References' | head -10
[[ $GATE -eq 0 ]] && echo "GATE 1 PASS" || echo "GATE 1 FAIL"
```

If FAIL → re-dispatch the failing agent with the gate output as feedback. Halt if same gate fails twice.

---

## Wave 2 — Masters (4 parallel subagents)

Goal: master entities + reference data + regulatory rules. These are the low-write-volume anchors for transactional workflows.

Dispatch 4 agents in parallel — one per master domain identified by Wave 1's module classification. Examples (project-specific):

```
Agent 2.A — 10-domains/10-<master-A>.md   (e.g., customer master)
Agent 2.B — 10-domains/11-<master-B>.md   (e.g., facility / credit master)
Agent 2.C — 10-domains/12-<master-C>.md   (e.g., sublimit)
Agent 2.D — 40-business-rules/regulatory-rules.md
```

Each agent dispatch uses the generic skeleton + the 11-section template from `knowledge-base-schema.md`. Regulatory-rules agent specifically: every rule MUST cite source; if no formal regulation reference exists in code → mark `[INFERRED]` (most likely scenario for legacy systems with no PRD).

**Gate before Wave 3:** (run from `{out}/knowledge-base/`)
```bash
# Every Wave 2 file has all 11 sections
for f in 10-domains/1*.md; do
  for n in 1 2 3 4 5 6 7 8 9 10 11; do
    grep -qE "^## ${n}\." "$f" || { echo "MISSING section ${n} in $f"; GATE=1; }
  done
done
# Every domain file has frontmatter
for f in 10-domains/*.md; do
  head -1 "$f" | grep -q '^---$' || { echo "MISSING frontmatter in $f"; GATE=1; }
  grep -q '^generated_by: mega-sdd:extract-intelligence' "$f" || { echo "BAD frontmatter in $f"; GATE=1; }
done
```

---

## Wave 3 — Workflows (5 parallel subagents)

Heaviest wave. Transactional workflows + operational rules + hidden gotchas.

Dispatch 5 agents — one per transactional workflow domain (e.g., import-lc-issuance, lc-amendments, document-examination, payment-settlement, counter-balance for the trade-finance example).

A 6th file — `40-business-rules/hidden-gotchas.md` — is produced by the main thread AFTER the 5 agents report back (it needs to cite findings from all 5 agents).

**Common pitfall**: workflow domain files run large (40-60KB). Subagent timeout risk. Mitigation:
- Provide explicit file lists in the dispatch prompt, not "read all .php in /workflow/".
- Use line-range reads (`offset` / `limit`) for files >40 KB.
- If a domain has 30+ source files, split into two agents: business logic vs reporting/journal.

**Operational rules file** (`40-business-rules/operational-rules.md`) — synthesize from the 5 agent outputs on main thread. Same for hidden-gotchas.md.

**Gate before Wave 4:** all 11 sections per workflow file; `## 8. State Machine` non-empty for workflow-classified domains; `## 9. Edge Cases & Gotchas` ≥1 entry per file.

---

## Wave 4 — Integrations & Reporting (3 parallel subagents)

Dispatch 3 agents:

```
Agent 4.A — 50-integrations/ (1 file per external system — e.g., core-banking, treasury, swift-network, ldap)
Agent 4.B — 10-domains/3<N>-<integration>.md (integration as a domain — e.g., swift-messaging, gl-journal)
Agent 4.C — 10-domains/4<N>-<reporting>.md (reporting domains — e.g., regulatory reporting, monitoring)
```

Integration files: protocol details ARE allowed here (this is the one place tech-leaking is OK — describing FTP, SOAP, HTTP, message format).

**Gate before Wave 5:**
- All `50-integrations/*.md` cite at least one source file in §11.
- Every workflow domain file from Wave 3 cross-references at least one integration domain.

---

## Wave 5 — Synthesis (main thread only)

NEVER dispatch as a subagent. Wave 5 needs the holistic view across all prior wave outputs.

Produce in order:

1. `99-rebuild-architecture/suggested-erd.md` — clean ERD documenting DEPARTURES from legacy. MUST satisfy `references/knowledge-base-schema.md` §ERD Quality Rails (universal defaults + Normalization checklist + Departures section).
2. `99-rebuild-architecture/suggested-system-flow.md` — logical service boundaries.
3. `99-rebuild-architecture/module-dependency-graph.md` — DAG + leaf-vs-trunk + critical path.
4. `99-rebuild-architecture/suggested-phasing.md` — Phase 1/2/3 + per-module acceptance criteria.
5. **`99-rebuild-architecture/data-mutation-policy.md`** (v1.4+, Iter 22) — entity-level mutability summary table per `references/knowledge-base-schema.md` §data-mutation-policy.md template. Aggregate `[LOCKED]/[INTENT]/[ARTIFACT]` counts per entity from wave 2-4 outputs. Drives ERD freedom in `generate-intent --kb`.
6. `README.md` — master roll-up per `knowledge-base-schema.md` §README-roll-up-structure.

README MUST surface REENGINEERING OPPORTUNITIES + Critical findings BEFORE TOC + before stats. Format:

```markdown
## Reengineering Opportunities (Surface First — v1.4+ Iter 22)

KB analysis reveals these proposed improvements over legacy. See `99-rebuild-architecture/` for detailed proposals.

### 1. <Schema improvement>
- Legacy: <denormalization / type issue / naming problem>
- Proposed: <rebuild approach>
- Tier: [INTENT] (or [ARTIFACT] if discarded entirely)
- See: `99-rebuild-architecture/suggested-erd.md` §<section>

### 2. <Flow simplification>
- Legacy: <coupled flow / synchronous boundary / framework workaround>
- Proposed: <decoupled / async / clean boundary>
- Tier: [INTENT]
- See: `99-rebuild-architecture/suggested-system-flow.md` §<section>

## Mutability Tier Distribution

| Tier | Count | % of total |
|---|---|---|
| LOCKED | <int> | <%> |
| INTENT | <int> | <%> |
| ARTIFACT | <int> | <%> |

> [LOCKED] items in `99-rebuild-architecture/data-mutation-policy.md` MUST be preserved 1:1. [ARTIFACT] items proposed for discard. [INTENT] items free to redesign per quality rails.

## Critical Findings — Do-Not-Replicate Bugs

Things rebuild team MUST know before starting:

### 1. <Headline bug>
<2-3 sentence summary>. See [<link to detail>].
…
```

The order is now: Reengineering Opportunities (forward-looking) → Mutability Distribution → Critical Findings (backward-looking, avoid replicating bugs). Reengineering first because rebuild team's primary task is DESIGN, not ARCHAEOLOGY.

---

## Final gate (main thread, after Wave 5)

```bash
# Run from {out}/knowledge-base/
# 1. README exists and has critical findings section first (before stats)
grep -n '^## Critical Findings' README.md
grep -n '^## Stats' README.md  # line number MUST be > the previous

# 2. Every domain file has all 11 sections (final check)
for f in 10-domains/*.md; do
  for n in 1 2 3 4 5 6 7 8 9 10 11; do
    grep -qE "^## ${n}\." "$f" || echo "FINAL FAIL: ${f} missing §${n}"
  done
done

# 3. Every domain file has frontmatter with required keys
for f in 10-domains/*.md; do
  for k in generated_by domain classification criticality verified_count inferred_count open_count; do
    grep -q "^${k}:" "$f" || echo "FINAL FAIL: ${f} missing frontmatter key ${k}"
  done
done

# 4. Forbidden patterns absent from domain bodies (allowed in §11 + 50-integrations/)
grep -rn 'varchar\|int(11)\|MySQL\|MSSQL\|composer\|namespace ' 10-domains/ 20-workflows/ 30-data-model/ 2>/dev/null | grep -v 'Source References' | head -10
# Expect: no output (or only matches inside §11)

# 5. Rebuild architecture all 5 files present (v1.4+ Iter 22 adds data-mutation-policy.md)
for f in suggested-erd suggested-system-flow module-dependency-graph suggested-phasing data-mutation-policy; do
  [[ -f "99-rebuild-architecture/${f}.md" ]] || echo "FINAL FAIL: missing ${f}.md"
done

# 6. README leads with Reengineering Opportunities BEFORE Critical Findings (v1.4+ Iter 22)
reengineering_line=$(grep -n '^## Reengineering Opportunities' README.md | head -1 | cut -d: -f1)
critical_line=$(grep -n '^## Critical Findings' README.md | head -1 | cut -d: -f1)
if [[ -z "$reengineering_line" || -z "$critical_line" || "$reengineering_line" -gt "$critical_line" ]]; then
  echo "FINAL FAIL: README must lead with Reengineering Opportunities before Critical Findings"
fi
```

If any FINAL FAIL → halt, surface output to user, ask whether to re-dispatch a specific agent or accept gaps as `[OPEN]`.

---

## Token budget guidance

Per-wave token cost estimate (rule of thumb; tune per legacy size):

| Wave | Agent count | Per-agent token budget | Wave total |
|---|---|---|---|
| 0 | 0 | ~5 K main thread | ~5 K |
| 1 | 3 | ~30 K each | ~90 K |
| 2 | 4 | ~25 K each | ~100 K |
| 3 | 5 | ~40 K each | ~200 K |
| 4 | 3 | ~30 K each | ~90 K |
| 5 | 0 | ~50 K main thread | ~50 K |
| **Total** | **15 dispatches** |  | **~535 K** |

On the validated trade-finance project (~600 PHP files): ~3 hours wall-clock, output 968 KB across 35 MD files. Adjust expectations for codebase size.
