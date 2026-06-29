# Wave Dispatch Templates + Quality Gates

Per-wave subagent prompt templates + grep commands for the quality gate that runs between waves. Read this BEFORE dispatching any wave.

---

## Contents

- Model tier per wave
- `<GLOSSARY_INDEX>` placeholder
- Reference offset hints
- Generic agent prompt structure
- Wave 0 — Prep (main thread)
- Wave 1 — Foundation (3 parallel subagents)
- Wave 2 — Masters (4 parallel subagents)
- Wave 3 — Workflows (5 parallel subagents)
- Wave 4 — Integrations & Reporting (3 parallel subagents)
- Wave 5 — Synthesis (main thread only)
- Reengineering Opportunities (Surface First)
- Mutability Tier Distribution
- Critical Findings — Do-Not-Replicate Bugs
- Final gate (main thread, after Wave 5)
- Token budget guidance

## Model tier per wave

Each wave dispatch consults `plugins/mega-sdd/references/model-tiers.md` for its model tier:

- **Wave 1** (artifact extraction): `extract-intelligence-wave-1` → default sonnet
- **Wave 2** (domain extraction): `extract-intelligence-wave-2` → default sonnet
- **Wave 3** (cross-reference): `extract-intelligence-wave-3` → default sonnet
- **Wave 4** (mutability classification): `extract-intelligence-wave-4` → default sonnet
- **Wave 5** (synthesis): `extract-intelligence-wave-5` → **default opus** (holistic synthesis)

Override per role via CLI flag / project config / user preference (see `plugins/mega-sdd/references/model-tiers.md §Override syntax`).

---

## `<GLOSSARY_INDEX>` placeholder

Between Wave 1 completion and Wave 2 dispatch, the main thread parses `<kb-dir>/00-overview/glossary.md` (typically 80-120 KB after full extraction) ONCE and builds a compact `glossary_index` (term → 1-line definition + line range). Injected into each Wave 2/3/4 subagent prompt as `<GLOSSARY_INDEX>` placeholder.

**Index format:**

```yaml
glossary_index:
  - term: "customer-onboarding"
    short_def: "End-to-end signup flow including KYC, tier assignment, and document upload"
    location: "glossary.md:42-58"
  - term: "trade-finance-letter-of-credit"
    short_def: "Bank-issued commitment to pay seller upon shipment evidence per UCP 600"
    location: "glossary.md:128-148"
  # ... per glossary entry
```

**Subagent instruction (appended to Wave 2/3/4 prompts):**

> When you need to reference a glossary term, FIRST consult `<GLOSSARY_INDEX>` above — it's the authoritative compact index for ALL terms in this KB. The `short_def` is usually sufficient for cross-reference citations. ONLY read `glossary.md` directly when you need full prose context for a specific term, AND when doing so use the line range from `location:` field (e.g., `Read glossary.md offset:42 limit:17`) — do NOT load the entire glossary file.
>
> When citing a glossary entry in your output, include the line range: write `glossary.md §customer-onboarding:42-58` (NOT bare `glossary.md §customer-onboarding`). Downstream readers can then spot-read instead of full-document read.

**Net savings:** ~96 KB redundant I/O eliminated per wave (15% of 535K wave token budget). 4 subagents × 3 waves (2/3/4) = 12 subagent reads saved per extraction.

## Reference offset hints

Beyond glossary citations, all reference citations in wave outputs (e.g., `data-mutation-policy.md §Customer-tier`, `workflows/onboarding.md §step-3`) SHOULD include line range hints when known. Format: `<file>.md §<section>:line-X-Y`. Downstream consumers use the line range with Read tool's `offset`/`limit` parameters for targeted reads (30-60% I/O reduction per reference read).

When the producer subagent doesn't know exact line ranges (citation written into prose without explicit tracking), the bare `<file>.md §<section>` form remains acceptable — consumers fall back to full-document read. Per simplifikasi: this is a best-effort optimization, not a hard requirement.

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

# === GLOSSARY INDEX (auto-injected by main thread for Wave 2/3/4) ===
<GLOSSARY_INDEX>
# === END GLOSSARY INDEX ===
#
# Use the GLOSSARY INDEX block above as your authoritative compact reference for glossary terms.
# Wave 2/3/4 subagents: do NOT re-read the full glossary.md file — the index above already has
# every term's short_def + line range. ONLY spot-read glossary.md (with `Read offset:X limit:Y`)
# when you need full prose context for one specific term, and use the range from the index.
# When citing a glossary entry in your output, include the line range:
# `glossary.md §customer-onboarding:42-58` (NOT bare `glossary.md §customer-onboarding`).
#
# Wave 1: no GLOSSARY_INDEX is injected (glossary doesn't exist yet — Wave 1 creates it).
# Wave 5 (main thread): reads glossary.md directly per Wave 5 contract (no subagent dispatch).

LEGACY FILES TO READ (explicit list, with file sizes):
- <file1> (<size> KB)
- <file2> (<size> KB)
…

OUTPUT TO: <absolute path to MD file>

USE TEMPLATE: see `references/knowledge-base-schema.md` §per-domain-11-section-template.

DISCIPLINE (non-negotiable):
- Citation required: file:line for every non-trivial claim ON THE SAME LINE as the marker, AND listed in §11. A claim without inline citation is UNCITED — downstream validators flag it for downgrade.
- Confidence marker: [VERIFIED] / [INFERRED] / [OPEN] on every non-trivial claim.
- Mutability tier: [LOCKED] / [INTENT] / [ARTIFACT] paired with the confidence marker — see `references/knowledge-base-schema.md` §Marker conventions Axis 2.
  - Default tier when uncertain: [INTENT] (NEVER auto-default to [LOCKED] or [ARTIFACT] — both need positive evidence)
  - [LOCKED]: regulatory citation, contract spec, audit trail, external FK
  - [ARTIFACT]: zero-caller code, legacy stack workaround, dead branch
- Tech-agnostic vocabulary outside §11 and 50-integrations/.
- Compare .bak / dated files vs live versions; document discrepancies in §9.
- NO fabrication. Ambiguous confidence → [OPEN]. Ambiguous mutability → [INTENT] default.

EXTRACTION DEPTH (deeper reasoning — protected by citation discipline above):
- **Business logic extraction**: don't just describe WHAT the code does — infer the business RULE behind it. E.g., if code checks `amount > 100000`, don't write "checks if amount exceeds threshold" — write "transaction amounts above 100,000 require additional approval [INFERRED] (`src/workflow/approval.ts:45`)" with the business rule made explicit.
- **Error path coverage**: for every happy-path flow, look for catch blocks, error handlers, fallback branches, timeout handlers, retry logic. Document each as a separate claim with its own marker. Silent error swallowing (empty catch, `|| true`) → flag in §9 Edge Cases.
- **Conditional branching**: when code has if/switch that drives different business outcomes (not just UI branching), document EACH branch as a separate business rule claim with its own citation.
- **Integration contract depth**: for every external system call (API, DB query, file I/O, message queue), document: protocol, authentication method, payload shape, error handling, retry policy, timeout. Each as a separate cited claim.
- **Hidden state machines**: look for status/state fields that drive branching. Reconstruct the state diagram even if no explicit state machine exists. Document transitions with citations to the code that implements each transition.

DEEP DISCIPLINES (catch the cases a write-side-only read misses; each is mandatory reasoning, protected by the citation discipline above):
- **P1 — State & data provenance (writer ↔ reader pairing + clone inheritance)**: for every state field you document as WRITTEN (a status/flag set via the stack's persistence or assignment idiom — see the STACK IDIOM TABLE below), also find where that value is READ — the query predicate, condition, or filter that branches on it. Cite BOTH sides. Classify each value: writer+reader present → confirmed; documented writer with NO reader in scope → flag `write-only / possibly vestigial`; a value a downstream reader depends on but that is never written in this flow → flag `inherited / cross-domain seam` (it likely arrives via a clone copy or an upstream flow). For every clone-style copy (a bulk row-copy, snapshot, record-duplicate, or object/struct copy — table row P1), list the fields carried over IMPLICITLY (the non-overwritten columns/fields) and trace who reads them downstream — that is where cross-domain coupling hides. **Capture the coupling as a BUSINESS OUTCOME** ("an amendment must still trigger the downstream dispatch + facility re-balance"), NOT as the implementation accident ("inherits `update_status=7` via clone") — the rebuild owns the encoding, so don't tie the rule to a legacy value. Do NOT invent a reader or writer to complete a pair: an unpaired side is `[OPEN]`, never a guess.
- **P2 — Enumerate ALL sites of a rule or flow**: when you find a business rule (classifier, validator, gate, threshold), do NOT stop at the first occurrence. Search for the same discriminating signature (field set + comparison + outcome) elsewhere and document EVERY site with its own citation. If two sites disagree → document each separately and mark `[OPEN]` / conflict; never average them into one consensus rule. Examine the entry point of every controller / handler / form file for **entry-point dispatchers** — a branch on an action/mode/HTTP-verb/route discriminator (table row P2): each branch is a DISTINCT flow entry that may set a different initial state — capture them as separate flows / initial-states (distinct operating models, e.g. teller-driven vs back-office, must stay distinguishable even if the rebuild later consolidates them), not one unified flow.
- **P3 — Behaviour-as-EXECUTED, not as-INTENDED**: production legacy code accretes debug artefacts and silent paths. Scan for and document what an operator OBSERVES: unconditional halt / hard-exit / early-return on a production path (a guard that ALWAYS fires → `[ARTIFACT: debug-code-as-feature]` — table row P3); the FULL transaction-rollback policy (which failures roll back vs are deliberately absorbed/skipped — that is a runtime contract); hardcoded test flags (an always-true gate, a `debug = 1`, a `// delete after testing`); and silent-success paths (empty catch / swallowed error / "expected failure → return success" — table row P3).
- **P4 — Classify files by structure, not naming**: a file's role comes from its shape, not its filename prefix. Inspect template/output ratio, form-tag/markup presence, and early-return action gates to classify each in-scope file as view / action_handler / dual_purpose / dispatcher / service. When the structural fingerprint contradicts the filename hint (a file named like an action-only handler that ALSO renders a full view → `dual_purpose`), document the mismatch in §9 — downstream rebuild planning depends on the real role.
- **P6 — Dynamic dispatch & runtime wiring**: a call site whose concrete target is decided at RUNTIME, not lexically, is a **dynamic seam** — a write-side-only read sees the seam but not what it actually does. For every dynamic seam (table row P6 — DI-container resolution, reflection / `dynamic` / duck-typed dispatch, attribute/annotation/convention-based routing & validation, interface → implementation dispatch, event/delegate/middleware/observer wiring), locate the real target(s) the runtime would bind and document the OBSERVED behaviour as a business outcome, citing BOTH the seam site and each resolved target. A seam you can resolve to one or more concrete targets → confirmed; a seam whose target genuinely cannot be determined from the code (e.g. a container registration scanned by convention with no enumerable consumer in scope) → `[OPEN]`, never an invented target. This is the inverse of P2 (one call site, N runtime targets) and the most common silent-miss on DI/reflection-heavy stacks (C#/.NET, Java/Spring, Go, modern TS) — do NOT skip a seam just because the target is not in the same file.

**STACK IDIOM TABLE** — the disciplines above are stack-neutral; this table gives the concrete idiom to grep/read for, per detected legacy stack. Match the row to the principle; if your stack is not listed, reason by analogy from the closest row (never assume "not present" — confirm by reading):

| Principle | PHP | JS / TS | Python | C# / .NET | Java | Go | Ruby | Rust |
|---|---|---|---|---|---|---|---|---|
| **P1** state write | `UPDATE`/`INSERT`/`$x =` | assignment / ORM `.save()` | assignment / ORM `.save()` | EF `SaveChanges` / property set | JPA `persist`/`merge` / setter | struct field set / `db.Save` | AR `update`/`save` / `attr=` | field set / `diesel update` |
| **P1** clone copy | `INSERT … SELECT` | object spread `{...x}` | `dict(**x)` / `copy()` | `INSERT … SELECT` / object init | `INSERT … SELECT` / copy ctor | struct copy `b := a` | `dup`/`clone`/`attributes` | `.clone()` / struct update |
| **P2** entry dispatcher | `$_GET['action']` / `mode==` | `req.method` / route switch | `request.method` / view dispatch | attribute route / `switch(action)` | `@RequestMapping` / servlet `switch` | `switch r.Method` / mux | `params[:action]` / routes | match on path / router |
| **P3** hard halt | `die()`/`exit()` | `process.exit()`/`throw` | `sys.exit()`/`raise` | `Environment.Exit`/`throw` | `System.exit`/`throw` | `os.Exit`/`panic`/`log.Fatal` | `exit`/`abort`/`raise` | `std::process::exit`/`panic!` |
| **P3** silent-success | empty `catch`/`@` | empty `catch`/`?? true` | bare `except: pass` | empty `catch`/swallow | empty `catch` | ignored `err` (`_ =`) | bare `rescue`/`rescue nil` | `let _ =`/`.ok()` discard |
| **P6** DI / IoC | service locator / container | DI token / factory inject | constructor inject / `Depends()` | `IServiceCollection` / ctor inject | `@Autowired`/`@Inject` | wire / provider func | initializer / `.new` inject | trait object / builder |
| **P6** reflection | `call_user_func`/`$$var` | `obj[name]()` / proxy | `getattr`/`__getattr__` | reflection / `dynamic` | reflection / proxy | `reflect` / interface assert | `send`/`method_missing` | trait dynamic / `Any` |
| **P6** route/validate by attr | annotation `@Route` | decorator route | decorator route | `[HttpGet]`/`[Authorize]`/`[Required]` | `@GetMapping`/`@Valid` | tag-based bind | DSL macro | attribute macro |
| **P6** event / wiring | observer / hook | `emitter.on` / callback | signal / observer | event/delegate / `+=` / middleware | listener / `@EventListener` | channel / callback | callback / ActiveSupport notif | channel / trait callback |

REPORT BACK (last line of your response, exact format):
- path: <absolute output path>
- verified: <int>
- inferred: <int>
- open: <int>
- locked: <int>
- intent: <int>
- artifact: <int>
- sources_cited: <int>
- provenance_pairs_checked: <int>      # P1: state values where BOTH writer + reader were located
- provenance_anomalies: <int>          # P1: write-only OR read-only-cross-domain values flagged (each MUST carry an [OPEN] or seam annotation)
- rule_sites_multi: <int>              # P2: rules found in >1 site (each documented separately)
- dynamic_seams_found: <int>           # P6: runtime-resolved dispatch sites located (DI / reflection / attr-route / interface / event)
- dynamic_seams_resolved: <int>        # P6: seams resolved to ≥1 concrete target, both sides cited
- dynamic_seams_open: <int>            # P6: seams whose target could not be resolved from code (each MUST carry an [OPEN])
- gate_self_check: pass | fail (<reason if fail>)
```

> **P1 self-check rail:** if you report `provenance_anomalies > 0`, every anomaly MUST appear in the output as a `write-only` / `inherited / cross-domain seam` note WITH an `[OPEN]` marker (or a cited seam). An anomaly count with no matching annotation in the file is a `fail` on `gate_self_check`.
>
> **P6 self-check rail:** `dynamic_seams_found` MUST equal `dynamic_seams_resolved + dynamic_seams_open`. Every seam counted in `dynamic_seams_open` MUST appear in the output with an `[OPEN]` marker; every resolved seam MUST cite both the seam site and at least one target. A `dynamic_seams_open > 0` with fewer matching `[OPEN]` markers is a `fail` on `gate_self_check`.

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
- State-machine docs use a state-diagram table or mermaid stateDiagram. When using Mermaid blocks, MANDATORY follow `plugins/mega-sdd/references/mermaid-emission-rules.md` (quote all node text, `<br/>` for newlines, escape `<>&"`, paraphrase raw code) — `validate-kb-flows.sh` v2 enforces a heuristic subset.
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
# Tech-leak scan (per-stack, advisory) — replaces the old hardcoded PHP/SQL grep.
# Detects the legacy stack from .scan-meta.json (or pass --stack=<x>) and flags any
# stack-specific token leaking into a tech-agnostic domain body. Advisory: prints +
# counts, never fails the gate.
# Resolve $PLUGIN_ROOT to the LATEST cached version (defeats stale-version anchoring;
# see plugins/mega-sdd/references/plugin-root-resolution.md). DERIVED = this reference
# file's own absolute path truncated before /skills/.
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
bash "$PLUGIN_ROOT/scripts/kb-leak-scan.sh" --kb-dir="$(pwd)" --stack=auto || true
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

**Depth requirements for Wave 3:**
- §3 Flow: reconstruct the FULL lifecycle state machine, not just the happy path. Include: error states, timeout states, cancellation/reversal paths, partial-completion states. Cite each transition.
- §6 Business Rules: extract IMPLICIT rules (coded as conditionals) as explicitly named rules. Format: "**BR-{domain}-{N}**: {rule in business language}. [marker] (`file:line`)".
- §8 Edge Cases: minimum 3 entries per workflow domain. Look for: empty-collection edge cases, boundary values (0, max, null), race conditions between concurrent users, timezone/date-boundary issues.
- §9 Rebuild Recommendations: for each edge case, explicitly state: replicate (it's a real business rule) / do-not-replicate (it's a bug) / open question (unclear).
- §8 State Machine — apply **P1 provenance** (see DEEP DISCIPLINES in the generic prompt): for every transition you document from a state WRITE, also locate the READ that consumes that state; flag write-only / inherited-cross-domain values rather than silently assuming a transition the read-side never honors. Apply **P2** to any classifier/gate in the flow (enumerate all sites; capture distinct entry-point initial states separately).

**Gate before Wave 4:** all 11 sections per workflow file; `## 8. State Machine` non-empty for workflow-classified domains; `## 9. Edge Cases & Gotchas` ≥3 entries per workflow file (≥1 was too lenient — shallow extraction passed the gate with trivial entries).

**Advisory (non-blocking, P1 provenance):** for each workflow agent that reports `provenance_anomalies > 0`, confirm the file carries a matching `write-only` / `inherited / cross-domain seam` note with an `[OPEN]` marker per anomaly. If a workflow file documents state transitions but its body never references the read-side (no predicate / filter / condition language consuming the state) → surface an advisory `provenance_read_side_thin` and re-dispatch the agent with the P1 discipline as feedback. **This is a MANUAL between-wave grep nudge, NOT a validator-emitted state-file signal** (unlike `kb_flow_staging_missing`, which `validate-kb-flows.sh` emits on its `advisories[]` channel) — do not grep for it in a state file. It NEVER blocks the wave; genuinely unpaired states are legitimate `[OPEN]`s.

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
2. `99-rebuild-architecture/suggested-system-flow.md` — logical service boundaries (not framework-mandate); anti-corruption layer pattern for integrations; idempotency requirements per flow; no framework prescription.
3. `99-rebuild-architecture/module-dependency-graph.md` — DAG + leaf-vs-trunk + critical path.
4. `99-rebuild-architecture/suggested-phasing.md` — Phase 1/2/3 sprint plan with per-phase acceptance criteria, a per-module acceptance template, and a pre-milestone (pre-phase) blocker list (resolved OQs required before phase start).
5. **`99-rebuild-architecture/data-mutation-policy.md`** — entity-level mutability summary table per `references/knowledge-base-schema.md` §data-mutation-policy.md template. Aggregate `[LOCKED]/[INTENT]/[ARTIFACT]` counts per entity from wave 2-4 outputs. Drives ERD freedom in `generate-intent --kb`.
6. `README.md` — master roll-up per `knowledge-base-schema.md` §README-roll-up-structure.
7. **`.extraction-scorecard.json` + `EXTRACTION-SCORECARD.md`** — the Extraction Completeness Contract per `SKILL.md` §Step 5.6. Derive each of the six principle statuses (P1–P4 + P5 staged inputs + P6 dynamic dispatch) from the Wave REPORT BACK self-checks (incl. `dynamic_seams_found/resolved/open`) + a holistic KB scan; `overall_status` PASS/PARTIAL/FAIL per the §Step 5.6 rules. Anti-halu: an honest `PARTIAL` with `[OPEN]` markers is the passing state — never up-rank to green to hide a gap.

README MUST surface REENGINEERING OPPORTUNITIES + Critical findings BEFORE TOC + before stats. Format:

```markdown
## Reengineering Opportunities (Surface First)

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

# 4. Tech-leak scan (per-stack, advisory) — allowed in §11 + 50-integrations/.
# Replaces the old hardcoded PHP/SQL grep so C#/Java/Go/Rust leaks are caught too.
# Resolve $PLUGIN_ROOT to the LATEST cached version once (reused by item 7 below;
# defeats stale-version anchoring — see plugins/mega-sdd/references/plugin-root-resolution.md).
# DERIVED = this reference file's own absolute path truncated before /skills/.
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
bash "$PLUGIN_ROOT/scripts/kb-leak-scan.sh" --kb-dir="$(pwd)" --stack=auto || true
# Expect: no leak hits (matches inside §11 / 50-integrations/ are auto-excluded)

# 5. Rebuild architecture all 5 files present
for f in suggested-erd suggested-system-flow module-dependency-graph suggested-phasing data-mutation-policy; do
  [[ -f "99-rebuild-architecture/${f}.md" ]] || echo "FINAL FAIL: missing ${f}.md"
done

# 6. README leads with Reengineering Opportunities BEFORE Critical Findings
reengineering_line=$(grep -n '^## Reengineering Opportunities' README.md | head -1 | cut -d: -f1)
critical_line=$(grep -n '^## Critical Findings' README.md | head -1 | cut -d: -f1)
if [[ -z "$reengineering_line" || -z "$critical_line" || "$reengineering_line" -gt "$critical_line" ]]; then
  echo "FINAL FAIL: README must lead with Reengineering Opportunities before Critical Findings"
fi

# 7. Extraction Completeness Contract scorecard present + self-consistent (advisory)
[[ -f ".extraction-scorecard.json" ]] || echo "ADVISORY: .extraction-scorecard.json not emitted (see SKILL.md §Step 5.6)"
bash "$PLUGIN_ROOT/scripts/validate-extraction-scorecard.sh" --cwd="$(pwd)" --quiet \
  && echo "SCORECARD: consistent (or absent → SKIP)" \
  || echo "ADVISORY: scorecard integrity FAIL — re-check §Step 5.6 (a PARTIAL/MISSING principle must carry [OPEN] markers)"
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
