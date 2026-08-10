# Wave Dispatch Templates + Quality Gates

Per-wave subagent prompt templates + grep commands for the quality gate that runs between waves. Read this BEFORE dispatching any wave.

**Division of labour (tranche 5d):** the INVARIANT extraction contract — extraction depth, deep disciplines P1–P4+P6, the REPORT BACK format + self-check rails, glossary-index usage — lives in `agents/domain-extractor.md` (the subagent's system prompt: it loads on every `domain-extractor` dispatch by construction — extract-intelligence is its only dispatcher — so a lazy or hurried controller cannot truncate it the way a typed block could be). The MECHANICAL injections — the stack-idiom slice + the glossary index — are built into `<kb-dir>/.dispatch-static.md` by `scripts/build-extract-static.sh`, which every subagent Reads first. The controller TYPES only the small variable core below (scope, paths, files, output) plus each wave's SCOPE block. Do NOT re-type the disciplines or the injections into a dispatch prompt — that is the measured ~9 KB/dispatch (≈34K output tok per 15-dispatch run) 5d removed.

---

## Contents

- Model tier per wave
- The dispatch-static file (script-built: stack-idiom slice + glossary index)
- Reference offset hints
- Generic agent prompt structure (the variable core)
- Stack-idiom slicing (script-executed; the master table)
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

## The dispatch-static file (script-built)

`bash <plugin-root>/scripts/build-extract-static.sh --kb-dir=<kb> --plugin-root=<plugin-root>` (where `<plugin-root>` = the resolved plugin root — the gate blocks below derive it via `resolve-plugin-root.sh`; from the SKILL.md body use the plugin-root env var directly) writes `<kb-dir>/.dispatch-static.md` (temp-file + rename, so the path either holds a complete file or is untouched; compact JSON on stdout: `status`, `static_path`, `stacks`, `stack_source`, `columns`, `glossary_present`, `glossary_skipped`, `glossary_terms`, `warnings`, `bytes`). Run it at **Wave 0 with `--no-glossary`** (idiom slice only — Wave 1 REBUILDS the glossary, and on a re-run into an existing KB a prior run's glossary must otherwise leak in as a stale index that Wave-1 subagents, who WRITE the glossary, would be told to trust) and AGAIN **after the Wave 1 gate passes, without the flag** (it now also emits the `## GLOSSARY INDEX` section parsed from `00-overview/glossary.md`). The script is idempotent — it builds from what exists on disk; re-running it is always safe. Every wave subagent Reads this ONE file first (the instruction lives in the `domain-extractor` agent body), so the controller never types either injection into a prompt. The file is disposable and regenerable — safe to delete any time, one script run rebuilds it, and it need not travel when a KB is copied into a rebuild project.

The file sits at the KB ROOT (dot-prefixed) — deliberately OUTSIDE `kb-leak-scan.sh`'s `SCAN_DIRS`, because the idiom slice legitimately contains raw stack tokens (`UPDATE`, `$_GET`, `EF SaveChanges`, …) that must never be counted as KB tech-leaks.

### Glossary index (inside the dispatch-static file)

After Wave 1, the builder parses `<kb-dir>/00-overview/glossary.md` (typically 80-120 KB after full extraction) ONCE — deterministically, not by the model — and emits a compact `glossary_index` (term → 1-line definition + line range) into the dispatch-static file. Since 5d the main thread neither reads the full glossary into its own context nor re-types the index per dispatch.

**Index format (one line per term — spec amendment 2026-07-06; the old per-term YAML triple cost ~40% more across an 80–120 KB glossary):**

```
glossary_index (term: short_def (L<start>-<end>)):
- customer-onboarding: End-to-end signup flow incl. KYC, tier assignment, document upload (L42-58)
- trade-finance-letter-of-credit: Bank commitment to pay seller upon shipment evidence per UCP 600 (L128-148)
# ... one line per glossary entry
```

- `short_def` cap: **~80 chars** — the builder truncates at a word boundary with `…`. The def is a VERBATIM prefix of the term's glossary prose — a script cannot paraphrase, which also removes the summarization-drift surface the model-built index carried. The full prose stays spot-readable via the line range. The cap applies to the INDEX only; glossary.md itself is untouched.
- `(L42-58)` = the term's line range in `glossary.md` (heading line through the line before the next heading; same semantics as the old `location:` field; used with `Read offset/limit` for spot-reads).
- The subagent-facing usage instruction lives ONCE, in `agents/domain-extractor.md` §Read the dispatch-static file FIRST (it is invariant, so it rides the system prompt — ONLY spot-read glossary.md via the index ranges, never re-read it whole). Citation format in outputs is unchanged: `glossary.md §customer-onboarding:42-58`, never the bare form.
- Wave 1 dispatches have no glossary index (Wave 1 creates the glossary). Wave 5 (main thread): reads glossary.md directly per the Wave 5 contract (no subagent dispatch).

**Net savings:** ~96 KB redundant I/O eliminated per wave (15% of 535K wave token budget). 4 subagents × 3 waves (2/3/4) = 12 subagent reads saved per extraction; the one-line index form saves a further ~40% of the injected index itself; and since 5d the index is TYPED by no one — it travels as a file, not as model output.

## Reference offset hints

Beyond glossary citations, all reference citations in wave outputs (e.g., `data-mutation-policy.md §Customer-tier`, `workflows/onboarding.md §step-3`) SHOULD include line range hints when known. Format: `<file>.md §<section>:line-X-Y`. Downstream consumers use the line range with Read tool's `offset`/`limit` parameters for targeted reads (30-60% I/O reduction per reference read).

When the producer subagent doesn't know exact line ranges (citation written into prose without explicit tracking), the bare `<file>.md §<section>` form remains acceptable — consumers fall back to full-document read. Per simplifikasi: this is a best-effort optimization, not a hard requirement.

---

## Generic agent prompt structure (the variable core)

Every wave's subagent prompt MUST follow this skeleton — and carry ONLY this. The extraction contract (extraction depth, deep disciplines P1–P4+P6, REPORT BACK + self-check rails, glossary-index usage, tech-agnostic output scoping) is already in the `domain-extractor` agent body and fires on every dispatch by construction; re-typing any of it into the prompt is the measured ~9 KB/dispatch regression 5d removed:

```
ROLE: Legacy code archaeologist for [wave-specific scope].

CONTEXT:
- Project at: <absolute path>
- Legacy stack: <language>, <db>, <integrations>
- Target stack: <new stack the rebuild will use>

SEED INPUT (cross-check only, do NOT blindly trust):
- <path to forensic dump if it exists; otherwise: "none">

READ FIRST: <kb-dir>/.dispatch-static.md
  (stack-idiom rows + glossary index; script-built — §The dispatch-static file.
   If it is missing, run build-extract-static.sh BEFORE dispatching — never
   dispatch without it.)

LEGACY FILES TO READ (explicit list, with file sizes):
- <file1> (<size> KB)
- <file2> (<size> KB)
…

OUTPUT TO: <absolute path to MD file>

USE TEMPLATE: see `references/knowledge-base-schema.md` §per-domain-11-section-template.

mega-sdd-trace:extract-intelligence
```

**What used to be typed here, and where it lives now** (the relocation is 1:1 — no rule was dropped):

| Was typed per dispatch | Lives now |
|---|---|
| DISCIPLINE DELTAS (same-line citation + §11, `[INTENT]`-default + positive-evidence tiers, `.bak`-vs-live) | `agents/domain-extractor.md` §Core discipline + §Mutability tiers |
| EXTRACTION DEPTH (5 bullets) | `agents/domain-extractor.md` §Extraction depth |
| DEEP DISCIPLINES P1–P4 + P6 | `agents/domain-extractor.md` §Deep disciplines |
| REPORT BACK exact format + P1/P6 self-check rails | `agents/domain-extractor.md` §Report back |
| GLOSSARY INDEX usage comment | `agents/domain-extractor.md` §Read the dispatch-static file FIRST |
| Tech-agnostic output scoping (no stack terms outside §11 + 50-integrations/) | `agents/domain-extractor.md` §Core discipline |
| `<GLOSSARY_INDEX>` injection | `<kb-dir>/.dispatch-static.md` §GLOSSARY INDEX (script-built) |
| `<STACK_IDIOM_ROWS>` injection | `<kb-dir>/.dispatch-static.md` §STACK IDIOMS (script-built slice) |

The REPORT BACK contract is unchanged — the controller still parses the same exact-format block (incl. `provenance_anomalies`, `dynamic_seams_*`, `gate_self_check`) from each subagent's final message; it simply arrives via the agent body instead of the typed prompt.

---

## Stack-idiom slicing (script-executed; the master table below is the single copy)

The MASTER STACK IDIOM TABLE below lives HERE (the single authoritative copy — never emitted whole when detection succeeds, and never duplicated into the script: `scripts/build-extract-static.sh` PARSES this table at run time, so editing the table here is sufficient and doc↔script drift is structurally impossible). The builder slices it into `.dispatch-static.md` §STACK IDIOMS per these rules (spec amendment 2026-07-06 in `docs/superpowers/specs/2026-06-15-extract-intelligence-tech-agnostic.md` — the full 8-stack table cost ~2.5 KB × 12–15 dispatches while the prompt's own CONTEXT block already names the legacy stack; script-executed since tranche 5d):

1. **Detected stacks** = the UNION of languages in the Wave 0 enumeration (`.scan-meta.json` language breakdown — every language present, not just the dominant one; a PHP+JS legacy gets BOTH columns). Language → column mapping follows the SAME alias convention as `scripts/kb-leak-scan.sh` `LANG_MAP` (the canonical `.scan-meta.json` language-name mapper): javascript/js/node/nodejs/typescript/ts → `JS / TS`; c#/csharp/cs/.net/dotnet/vb/vb.net/vbnet → `C# / .NET`; kotlin → `Java`; golang → `Go`; py → `Python`; rb → `Ruby`; rs → `Rust`; match case-insensitively. **The alias map — unlike the idiom table — is a hand-maintained duplicate in its two consumers (`kb-leak-scan.sh` + `build-extract-static.sh`); keep them in step** (full-set parity is pinned by `tests/token-efficiency/test-extract-dispatch-static.sh`). Markup/data-only languages in the breakdown (HTML, CSS, SQL, YAML, …) map to no column and are ignored for slicing.
2. **Emitted slice** = the `Principle` column + one column per detected stack, ALL 9 rows, rendered as a markdown table (2..N+1 columns), written into `.dispatch-static.md` §STACK IDIOMS.
3. **Fallback — emit the FULL table** when: the enumeration is missing/empty, NO detected language maps to a column, or the run predates `.scan-meta.json`. The builder never writes an empty §STACK IDIOMS — a subagent must always have concrete idiom anchors (the agent body's reason-by-analogy rule covers stacks beyond the emitted slice either way).
4. Mixed case — SOME detected languages map, others don't: emit the mapped columns (the analogy rule covers the rest); do NOT fall back to the full table for that.

**MASTER STACK IDIOM TABLE** (dispatcher-side; match the row to the principle):

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

---

## Wave 0 — Prep (main thread)

Not dispatched; main thread runs:

1. Validate legacy codebase path exists and is non-empty.
2. Create `{out}/knowledge-base/` skeleton: all 7 sub-dirs (`00-overview/`, `10-domains/`, …, `99-rebuild-architecture/`).
3. If `--seed=<path>` provided: copy seed file to `{out}/_source/` (read-only cross-reference).
4. Enumerate legacy codebase: top-level dirs, file types, total file count, total size, language breakdown.
5. Persist enumeration to `{out}/knowledge-base/.scan-meta.json` (used by later waves for file selection).
6. **Run** `bash <plugin-root>/scripts/build-extract-static.sh --kb-dir={out}/knowledge-base --plugin-root=<plugin-root> --no-glossary` — writes `.dispatch-static.md` (idiom slice only; `--no-glossary` keeps a prior run's glossary from leaking in as a stale index). The stdout JSON's `stacks` + `stack_source` also feed the CONTEXT block's legacy-stack line.
7. Confirm with user if `--auto` not set; show file count + estimated parallel-agent dispatch count.

Gate before Wave 1: skeleton dirs exist, seed copied (if provided), `.dispatch-static.md` exists. If the builder failed instead, its stderr already carries the remedy (e.g. the resolve-python guidance on Windows) — fix and re-run it; never dispatch without the file.

---

## Wave 1 — Foundation (3 parallel subagents)

Goal: anchor docs for waves 2-4. Glossary defines terms; classification picks the master list; data-model and workflows define the cross-cutting structure.

Dispatch 3 agents in parallel:

**Agent 1.A — `00-overview/`** (4 outputs):
```
ROLE: Legacy code archaeologist for system overview.

SCOPE: Produce 4 files in {out}/knowledge-base/00-overview/:
  - system-purpose.md (2-3 paragraphs; what the system does in business terms)
  - glossary.md (40+ terms; every domain term + system term used elsewhere in KB.
    FORMAT MANDATE: one `## <term>` heading per term — the dispatch-static index
    builder parses exactly that shape, and the Wave-1 gate FAILS on zero such headings)
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
# Glossary format gate (HARD) + completeness (advisory). The index builder and the
# downstream citation discipline both require one `## <term>` heading per term; ZERO
# such headings must fail HERE — where the documented re-dispatch remedy still applies —
# because the post-Wave-1 `## GLOSSARY INDEX` verify below would otherwise dead-end the
# whole run with no stated cause. The ≥40-entries expectation stays ADVISORY (a small
# legacy can legitimately have fewer terms).
GC=$(grep -c '^## ' 00-overview/glossary.md)
[[ "$GC" -ge 1 ]] || { echo "GLOSSARY FORMAT FAIL: zero '## <term>' headings"; GATE=1; }
echo "glossary terms: $GC (≥40 expected)"
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
bash "$PLUGIN_ROOT/scripts/kb-leak-scan.sh" --kb-dir="$(pwd)" --stack=all || true
[[ $GATE -eq 0 ]] && echo "GATE 1 PASS" || echo "GATE 1 FAIL"
```

If FAIL → re-dispatch the failing agent with the gate output as feedback. Halt if same gate fails twice.

**After GATE 1 PASS, before any Wave 2 dispatch:** re-run `bash <plugin-root>/scripts/build-extract-static.sh --kb-dir={out}/knowledge-base --plugin-root=<plugin-root>` — the glossary now exists, so `.dispatch-static.md` gains its `## GLOSSARY INDEX` section. Verify: `grep -q '^## GLOSSARY INDEX' {out}/knowledge-base/.dispatch-static.md` — dispatch no Wave 2/3/4 agent until it passes.

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
- §8 State Machine — apply **P1 provenance** (see §Deep disciplines in `agents/domain-extractor.md`): for every transition you document from a state WRITE, also locate the READ that consumes that state; flag write-only / inherited-cross-domain values rather than silently assuming a transition the read-side never honors. Apply **P2** to any classifier/gate in the flow (enumerate all sites; capture distinct entry-point initial states separately).

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
bash "$PLUGIN_ROOT/scripts/kb-leak-scan.sh" --kb-dir="$(pwd)" --stack=all || true
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
