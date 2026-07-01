# Lead Review — `extract-intelligence` (mega-sdd pipeline stage 1)

## 1. Executive verdict

**The stage is healthy and structurally sound — its moat contribution (per-claim confidence + mutability markers, inline citation discipline, tech-agnostic KB) is real and the blocking rails it feeds downstream are intact.** Every defect found is in the *advisory / documentation* tier, not in a hard-block gate. But the advisory validators that are supposed to be the stage's own quality net have a recurring, provable disease: **they were tuned on one PHP trade-finance codebase and silently fail-open or go no-op on the other stacks and domains the contract says they must serve.**

Top 3 risks (one line each):
1. **`validate-kb-citations.sh` fails open** — a C#/.NET/Kotlin/TSX legacy's §11 citations match no pattern, so the anti-hallucination grounding check exits `SKIP`/green with **zero** citations verified (`valq-01`/`cite-01`).
2. **Silent downstream scope collapse** — the KB phasing heading the consumer counts (`## Phase N`) is never mandated by the producer; a mis-formatted phasing file silently collapses a multi-phase rebuild to single-phase with a green validator (`xpc-04`), and an interrupted re-run can contaminate Wave-5 synthesis with orphan domain files (`corr-06`).
3. **Project-specific behavior baked into plugin validators** — `audit-domain-rules.sh` hardcodes Indonesian bank-regulator acronyms (→ PASS-green for every non-ID-banking domain), and `validate-kb-citations.sh` hardcodes that project's folder names (`input/report/generate/approval`) — both direct violations of the contract's "plugin behavior must generalize" clause (`valq-03`, `valq-02`).

**Overall grade: MINOR-GAPS.** No CRITICAL and no moat-invariant breach; one HIGH and nine MEDIUM, all confined to the advisory layer, all with cheap, well-understood fixes.

---

## 2. Findings by severity

Merged across lenses (dedup noted per finding). Ordered severity → blast radius. **CRITICAL bucket: empty.**

### HIGH

#### H1 — `validate-kb-citations.sh` extension allow-list makes whole ecosystems SKIP-green (fail-open grounding check)
*Merges `valq-01` + `cite-01`.*
- **File:** `plugins/mega-sdd/scripts/validate-kb-citations.sh:94-96, 106-112` (SKIP→exit 0 at `:181`)
- **Evidence:** `citation_pattern = re.compile(BT + r"([^"+BT+r"]*?[\w/.-]+\.(?:php|js|ts|py|rb|java|go|rs|sql|yaml|json|md|vue)(?::\d+[-–]?\d*)?)" + BT)`. The alternation has `go/rs/java` but **no `cs`** (nor `cshtml/kt/tsx/jsx/scala/ex/twig/xml/ini/sh`). When §11 cites only `SomeService.cs:45`, `citations` is empty → `{"status":"SKIP","detail":"§11 exists but no file citations found"}` → `SystemExit(0)` → green. A KB whose grounding is *entirely* in an omitted ecosystem passes with zero citations resolved; in mixed KBs every `.cs` ref is silently dropped from the checked set.
- **Why it matters:** Citation resolution is a named anti-hallucination guarantee and one of the 4 wired KB validators. C#/.NET is an explicitly-supported first-class stack (SKILL.md:170 idiom table, wave-dispatch-templates.md:138). The sibling `validate-kb-markers.sh:66` already fixed this exact class deliberately (`# Deliberately broad: avoids hardcoded extension list (was missing .xml/.ini/.sh/.twig etc.)`), and two other repo scripts (`build-graph.sh:234`, `enrich-workflows-staging.sh:199`) already include `cs` — proving oversight, not intent. It is a validator that *lies green* on the stage's own tech-agnosticism invariant. (Below CRITICAL only because it is PostToolUse-advisory, not a blocking gate.)
- **Fix:** Replace the extension alternation with the generic `path.ext:line` form from `validate-kb-markers.sh:66` (or open the ext class to `\.[A-Za-z0-9]{1,10}`). Additionally: when §11 exists but 0 citations are extracted **and** the KB carries `[VERIFIED]` claims, emit `WARN`/`FAIL`, not a silent `SKIP` — "no citations in a grounded KB" is itself a defect. Pin with a fixture: a `.cs`-only §11 that must not return `SKIP`.

### MEDIUM

#### M1 — `phase_total` couples to an unpinned `## Phase N` heading the producer never mandates → silent single-phase collapse
- **File:** consumer `plugins/mega-sdd/skills/generate-intent/references/kb-submode.md:44,46,50`; producer `.../extract-intelligence/references/knowledge-base-schema.md:451-455` + `wave-dispatch-templates.md:353`; validator `validate-kb-reengineering.sh:130`
- **Evidence:** Consumer counts `## Phase` H2 occurrences → `phase_total` (`:44`), falls back to `phase:1, phase_total:1` on zero (`:50`). Producer only ever says "Phase 1 / 2 / 3 plan." (schema `:452`) and "Phase 1/2/3 sprint plan" (wave `:353`) — **content, not heading structure**. The validator greps only case-insensitive `\bphase\b` (`:130`), so a phasing file rendered as `### Phase 1`, a table, or prose passes green while the consumer counts 0.
- **Why it matters:** The consumer's deterministic phase count depends on an H2 format nothing instructs Wave-5 to emit. On the default (`--phase` absent) path this silently collapses a multi-phase rebuild into a single-phase vault and logs a *misleading* "no phasing detected" — losing phase sequencing that `generate-units`/`execute-bolts` build from, with no gate to catch it and a false-green validator.
- **Fix:** Mandate one `## Phase N — <title>` H2 per phase in `knowledge-base-schema.md §suggested-phasing` and `wave-dispatch-templates.md` Wave-5 item 4; harden `validate-kb-reengineering.sh` to assert `^## Phase` (not loose `\bphase\b`) so a mis-formatted file is surfaced before generate-intent single-phases it.

#### M2 — `_kb_source` back-reference hardcodes `20-workflows/` but staged workflows are produced under `10-domains/`
- **File:** `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md:118,120`; also `generation-guide.md:248`, `templates/04-flows.md:84`, `knowledge-base-schema.md:469`; producer `wave-dispatch-templates.md:302`; guard `validate-vault-flow-staging.sh:110-113`
- **Evidence:** All four propagation sites pin the directory literally: `_kb_source: [20-workflows/<file>.md]` (only `<file>` is a placeholder). But §3a `stages:` is a per-workflow field→stage allocation (schema `:162-185`) that lives in `classification: workflow` **domain** files — produced into `10-domains/` (wave `:302` dispatches import-lc-issuance/lc-amendments into 10-domains; `enrich-workflows-staging.sh:248-250` globs `10-domains/*.md`). Schema `:469` even self-contradicts: it says stamp `20-workflows/<file>.md` "when a workflow DOMAIN carries a §3a stages: block."
- **Why it matters:** generate-intent, following the contract literally, stamps a dead back-reference (`20-workflows/import-lc-issuance.md` when the file is `10-domains/2X-import-lc-issuance.md`). The staging non-loss guard — the purpose-built anti-regression for the trade-finance flatten case — then misses the direct path AND the numeric-prefix basename glob (`import-lc-issuance` ≠ `2X-import-lc-issuance`), returns None, and **SKIPs** (`:179-180`): it silently fails to *detect* a flatten. `build-graph.sh:206-210` keys a graph edge on the literal stem → dangling node. Content isn't lost (stages are copied independently), but detection + traceability degrade exactly where the guard was meant to bite.
- **Fix:** Change the notation in all four sites to a directory-agnostic placeholder (`_kb_source: [<kb-workflow-file>.md]`) and instruct generate-intent to stamp the **actual** KB path it read stages from. In `validate-vault-flow-staging.sh:110-113`, emit an ambiguity warning (not silent `hits[0]`) when the basename glob returns >1.

#### M3 — No wave-level resumability or prior-run cleanup → interrupted extraction can contaminate Wave-5 synthesis
- **File:** `plugins/mega-sdd/skills/extract-intelligence/SKILL.md:199-203, 283-288`; `wave-dispatch-templates.md:182, 409`
- **Evidence:** Wave 0 persists `.scan-meta.json` (`:182`); snapshot + scorecard emit only *after* Wave 5. Halt conditions (`:283-288`) define no resume path and no step that purges orphans or skips completed waves. Wave 5 is "main thread only … holistic context across every wave's output" (`:201`) and globs sibling files (`for f in 10-domains/*.md`, `:409`).
- **Why it matters:** A re-run lands in the same `.mega-sdd/knowledge-base/` with no purge. If the second run's LLM-decided `{NN}-{slug}` domain set differs, **complete** orphan domain files from the first run linger and are read by Wave-5 synthesis (ERD, dependency-graph, phasing, README) — silently baking a phantom/duplicate domain into the canonical KB that `generate-intent --kb` and `bind-codebase` consume. (The finding's "false-fail the final gate" path is overstated — complete orphans pass the gate; the real, ungated harm is silent contamination.) Conditional on interruption + filename drift, hence MEDIUM not HIGH.
- **Fix:** Add a Wave-0 idempotency step: when writing into an existing KB dir, either purge the target wave's output range before re-dispatch, or diff `.scan-meta.json` and skip gate-passed waves; make Wave-5 enumerate only the current run's domain set.

#### M4 — `validate-kb-citations.sh` legacy-root detection + fallback are PHP/Node/Ruby-shaped and project-specific; line numbers never verified
*Merges `valq-02` + `moat-04` + `cite-02`.*
- **File:** `plugins/mega-sdd/scripts/validate-kb-citations.sh:49-60, 130-139` (PostToolUse invokes with no `--legacy-root`, `post-tool-use:569`)
- **Evidence:** Auto-detect gates only on `index.php / composer.json / package.json / Gemfile` (`:55`) — no `go.mod / Cargo.toml / *.csproj|*.sln / pom.xml|build.gradle / pyproject.toml`. The basename fallback iterates a hardcoded subdir list `["", "app", "src", "input", "report", "generate", "approval"]` (`:135`) — `input/report/generate/approval` are literal folders of the specific trade-finance app the stage was tuned on. Resolution tests only `os.path.isfile`; the parsed line range (`:102-104`) is discarded and never checked.
- **Why it matters:** Two contract hits. (1) **Project-specific behavior** in a shipped plugin validator — the contract's "What we will not accept" list. (2) **Tech-agnosticism** — for a Java/Go/Rust/C#/Python legacy seeded to `_source/` (or a `foo-rebuild/` layout, a first-class flow), `legacy_root` resolves empty and citations degrade to basename/cwd search → false-PASS on a wrong path (any `User.php` anywhere) or false-FAIL noise. The co-located case works on any stack, so blast is confined to the non-co-located slice; advisory-only, hence MEDIUM.
- **Fix:** Broaden the manifest probe to every §8.5 ecosystem; probe `_source/`/`.scan-meta.json` for the real legacy root and pass `--legacy-root` from the PostToolUse dispatch. Replace the hardcoded subdir list with a bounded recursive basename walk; require a **unique** basename hit (mark multi-hits unresolved, not PASS). Add an optional cited-line ≤ EOF check.

#### M5 — `audit-domain-rules.sh` hardcodes Indonesian bank-regulator acronyms → the "domain-rule GAP detector" is a no-op that PASSes green for every other domain
- **File:** `plugins/mega-sdd/scripts/audit-domain-rules.sh:80-82, 173`
- **Evidence:** `reg_patterns = [ r"(?:PBI|POJK|UCP|URR|SLIK|SIMODIS|SIUL|SKBDN|Normatif|OJK|BI\s+(?:Antasena|regulation))" ]`, then `status = "FAIL" if gaps else "PASS"`. Any KB from another domain (HIPAA / SOX / PCI-DSS / GDPR / telecom / logistics) matches zero patterns → `unique_rules` empty → `gaps` empty → **PASS** with "0/0 regulatory rules addressed."
- **Why it matters:** A validator whose entire purpose is catching *missing* compliance rules silently reports "all clear" for the general case; it functions only for one country's banking regs. Direct hit on "plugin behavior must generalize." Advisory (`/mega-sdd:analyze` V9), hence MEDIUM not HIGH — but it gives false compliance assurance across the whole non-ID-banking user base.
- **Fix:** Derive regulatory candidates generically from KB structure (§7 `[LOCKED]` rows carrying a "Mandated by"/"Source" citation; `40-business-rules/regulatory-rules.md` headings) — the schema already provides these. If a curated acronym list is wanted, ship it as a swappable pack. When a KB has `regulatory-rules.md` but 0 rules parse, emit "no regulatory rules parsed" — not green PASS.

#### M6 — `kb-leak-scan.sh SCAN_DIRS` omits `00-overview`, `40-business-rules`, `99-rebuild-architecture` — tech leaks there are never scanned
- **File:** `plugins/mega-sdd/scripts/kb-leak-scan.sh:124`
- **Evidence:** `SCAN_DIRS = ["10-domains", "20-workflows", "30-data-model"]`. The schema's own anti-leak invariant (`knowledge-base-schema.md:463`) exempts *only* §11 + `50-integrations/` — the whole KB is otherwise in scope, and `:444` explicitly requires "No framework names" in `99-rebuild-architecture/`. The scanner's own header (`:10-14`) states the contract as tech-agnostic "EXCEPT §11 and 50-integrations/" — contradicting its own 3-dir list. Asymmetry: `post-tool-use:667` fires `validate-kb-output.sh` on `40-business-rules/` and `99-rebuild-architecture/` writes, but the leak scanner skips both.
- **Why it matters:** A `DbContext`/`@Entity`/`Eloquent`/`gorm` leak in a business-rules, overview, or rebuild-architecture file passes clean. Advisory (`|| true`, exit 0 unless `--strict`), hence MEDIUM.
- **Fix:** Add the three dirs to `SCAN_DIRS` (keep §11 + `50-integrations/` exemptions). A naive add will false-positive on the schema's legitimate `## Departures from Legacy` (`:356`) and on `40-business-rules` Source cells citing legacy paths — so make the additions **section-aware** (skip §11 bodies + Source columns), consistent with the scanner's existing section-awareness.

#### M7 — `validate-kb-markers.sh` per-claim citation gate accepts non-file tokens (regulatory / version / time refs)
*Merges `moat-03` + `valq-09`.*
- **File:** `plugins/mega-sdd/scripts/validate-kb-markers.sh:66, 98-99`
- **Evidence:** `PATH_LINE_RE = re.compile(r"[\w/.:-]+\.\w+:\d+")`, used as `has_inline = bool(PATH_LINE_RE.search(line))`. No `/` required; `.`/`:`/`-` in-class → any `token.token:digits` matches. Confirmed: `per BI Regulation 23.2:2021 [VERIFIED]` matches `23.2:2021`; `1.5:1 backoff ratio` matches `1.5:1`; `runs at 09.30:00 daily` matches `09.30:00`. Each is scored *cited* with no source anchor.
- **Why it matters:** Citation discipline (moat #3): a `[VERIFIED]` claim citing *only* a regulation number/version/time is exactly the "VERIFIED without a code anchor" case the gate exists to stop, and this stage's target domain (SKILL.md:145 "never guess regulatory citations") makes `NN.N:NNNN` tokens plausible. Advisory (PostToolUse "detection-only at hook layer", `post-tool-use:588`) — a false-green in the analyze scorecard, not a bypassed hard block, hence MEDIUM.
- **Fix:** Require a path-like structure — a `/` OR a known source extension before `:line` (reuse the extension-anchored form in `validate-kb-citations.sh:94-96`, but keep the ext class open per H1). Keep the §11-basename + backtick fallbacks. Add a fixture: a regulation-only `[VERIFIED]` line must flag uncited.

#### M8 — Wave-3 depth-requirement section numbers contradict the schema and self-collide
- **File:** `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md:314-320`
- **Evidence:** Depth bullets read `§6 Business Rules` (`:315`), `§8 Edge Cases` (`:316`), `§9 Rebuild Recommendations` (`:317`), `§8 State Machine` (`:318`) — so **§8 is labelled twice** (Edge Cases *and* State Machine). The authoritative template is §6 Outputs / §7 Business Rules / §8 State Machine / §9 Edge Cases & Gotchas (`knowledge-base-schema.md:217-255`), and the same file's generic bullets (`:124,:133`) and the gate directly below (`:320`) already use the correct numbering.
- **Why it matters:** This block is injected into the Wave-3 dispatch prompt. It hands the subagent a section map that conflicts with the template it is simultaneously told to use. Gates grep only numeric prefixes (`## ${n}.`), so a subagent that files Business Rules under §6 or Edge Cases under §8 passes every gate — silent content misallocation. Lower-probability than the schema template it's shown alongside, hence MEDIUM.
- **Fix:** Migrate the depth bullets to §7 Business Rules / §8 State Machine / §9 Edge Cases & Gotchas; drop the non-existent "Rebuild Recommendations" section name (rebuild guidance folds into §9 per schema `:259`); reconcile the double-labelled §8.

#### M9 — SKILL.md points to a plugin-root ref with the forbidden bare `references/X.md` form
- **File:** `plugins/mega-sdd/skills/extract-intelligence/SKILL.md:74`
- **Evidence:** L74: "resolved per role from `references/model-tiers.md`". No such skill-local file exists (the dir holds only `knowledge-base-schema.md` + `wave-dispatch-templates.md`); the file is at plugin root `plugins/mega-sdd/references/model-tiers.md`. The routed sibling writes the correct full path twice (`wave-dispatch-templates.md:27,35`). L74's *other* ref (`references/wave-dispatch-templates.md`) is correctly skill-local — proving bare `references/` from this SKILL resolves skill-locally, so `references/model-tiers.md` lands on nothing.
- **Why it matters:** Exactly the anti-pattern the contract names (never bare `references/X.md` from inside a skill — resolves ambiguously). Every other reference to this file across the plugin uses the full path. Degrades gracefully (L74 inlines the defaults; correct path exists in the sibling), hence MEDIUM.
- **Fix:** Rewrite the model-tiers path on L74 to `plugins/mega-sdd/references/model-tiers.md`; leave the correct same-skill `references/wave-dispatch-templates.md` untouched.

### LOW

#### L1 — `validate-kb-output.sh` `required_sections` titles are stale vs the schema; check is number-only + unanchored substring
*Merges `moat-05` + `corr-02` + `out-01` + `valq-04` + `xpc-01`.*
- **File:** `plugins/mega-sdd/scripts/validate-kb-output.sh:153-172`
- **Evidence:** The list embeds `## 4. Entities / ## 5. Fields & Validation / ## 7. Integrations / ## 8. Edge Cases / ## 9. Rebuild Recommendations / ## 11. Source Files` — 7 of 11 titles contradict the schema (§4 Inputs / §5 Process / §7 Business Rules / §8 State Machine / §9 Edge Cases & Gotchas / §11 Source References). Saved only by `sec_num = sec.split(".")[0] + "."` + unanchored `if sec_num not in content` (`:170-171`).
- **Why it matters:** No live false-pass (number-only match holds), but the header claims it "validates against knowledge-base-schema.md contract" while embedding a superseded contract; the stale title is pushed into the user-facing `missing_sections` diagnostic (`:172,177`), so a genuinely-absent section is reported under the wrong name, and any future title-aware hardening would reject every conformant KB. The substring test is also unanchored (a `## N.` in prose/a code fence satisfies it) — weaker than the header's "all 11 section headers" claim.
- **Fix:** Sync titles to the current schema (or drop titles and keep only `## N.` tokens + a comment naming the schema as source of truth); anchor the match with `^## N\.` (re.MULTILINE) so prose mentions don't satisfy it.

#### L2 — `intent_count` / `artifact_count` never validated (and `locked_count` optional); schema misattributes the reader
*Merges `moat-02` + `valq-05` + `xpc-05`.*
- **File:** `validate-kb-output.sh:108-125`; `knowledge-base-schema.md:99-107`
- **Evidence:** `marker_checks = [("verified_count","[VERIFIED]"),("inferred_count","[INFERRED]"),("open_count","[OPEN]"),("locked_count","[LOCKED]")]` — `intent_count`/`artifact_count` absent, `locked_count` SKIPs when absent. Schema `:99-102` marks all three mutability counts MANDATORY. Schema `:107` claims the counts are "machine-read by generate-intent --kb to route claims" — but routing is per-inline-marker (`kb-submode.md:61-63`); the only real reader is this validator.
- **Why it matters:** `[ARTIFACT]` = "free to DISCARD" (schema `:321`) has zero count-integrity; a body/frontmatter mismatch on 2 of 3 mutability tiers is undetected. No downstream corruption (routing is body-marker-based), and schema `:107` over-states the counts' role — hence LOW.
- **Fix:** Add `("intent_count","[INTENT]")` + `("artifact_count","[ARTIFACT]")` to `marker_checks` (same v1.4+ SKIP treatment); add the three mutability counts to the final-gate presence list (`wave-dispatch-templates.md:417`); correct schema `:107` to describe counts as an integrity checksum read by `validate-kb-output.sh`, not the routing input.

#### L3 — Scorecard hidden-gap check uses a GLOBAL `[OPEN]` count, not per-principle correspondence
*Merges `corr-03` + `score-01`.*
- **File:** `plugins/mega-sdd/scripts/validate-extraction-scorecard.sh:162-187`
- **Evidence:** `open_marker_count` is a flat `re.findall(r"\[OPEN", …)` across all KB `.md` (`:162-173`); the only hidden-gap trip is `if not_covered and open_marker_count == 0` (`:184`). SKILL.md:247 defines the contract as "every PARTIAL/MISSING principle has *corresponding* `[OPEN]` markers." A single unrelated `[OPEN]` masks up to six uncovered principles. Also: `overall=PARTIAL/FAIL` with ALL principles COVERED (self-contradictory) is unflagged (`:178-180` guards only PASS+not_covered).
- **Why it matters:** The exact silent-drift the Extraction Completeness Contract exists to catch, degraded to "any `[OPEN]` exists." But per-principle correspondence isn't machine-derivable (markers are untagged), the validator honestly self-scopes, and it's advisory/non-blocking — hence LOW.
- **Fix:** Corroborate per principle using the count fields the scorecard JSON already carries (P1 `anomalies_count>0`, P6 `seams_open>0`, etc.); flag `hidden_gap` when an uncovered principle's own evidence fields are all zero. Minimum: at least `open_marker_count >= len(not_covered)`, and document in SKILL.md §5.6 that only global presence is checked.

#### L4 — `kb-leak-scan.sh` UNIVERSAL DB token set omits Oracle / DB2 / MariaDB
- **File:** `plugins/mega-sdd/scripts/kb-leak-scan.sh:58-61`
- **Evidence:** `UNIVERSAL = ["varchar","nvarchar","int(11)","tinyint","bigint","AUTO_INCREMENT","MySQL","MSSQL","PostgreSQL","Postgres","MongoDB","SQLite"]`. No Oracle/DB2 and no `VARCHAR2`/`NUMBER(`/`NCLOB` — the engines/types that dominate the stated financial/banking target (SKILL.md:20). Case-sensitive `tok in line` also misses uppercase Oracle DDL.
- **Why it matters:** An Oracle-backed legacy leaks `VARCHAR2`/`NUMBER(10)`/`Oracle` with zero hits. Advisory, non-blocking, MariaDB shares MySQL DDL (already covered) — hence LOW.
- **Fix:** Add distinctive `Oracle`, `VARCHAR2`, `NCLOB`, `NUMBER(`, `DB2` tokens (keep them distinctive — avoid substrings of business words like `char`/`float` under `if tok in line`).

#### L5 — `kb-leak-scan --stack=auto` narrows to the LEGACY stack, missing TARGET-stack idiom leaks
- **File:** `plugins/mega-sdd/scripts/kb-leak-scan.sh:20, 91-115`; gates `wave-dispatch-templates.md:258, 431`
- **Evidence:** `detect_stacks()` reads `.scan-meta.json` and returns only legacy languages; the UNION fallback fires only when scan-meta is absent (`:115`). Docstring itself argues UNION is "strictly more correct." Every gate hardcodes `--stack=auto`, yet each subagent prompt is seeded `- Target stack: <new stack>` (`:82`). Legacy=PHP → rebuild=.NET: a domain file leaking `IServiceCollection`/`[HttpGet]` is missed (auto loaded only php + UNIVERSAL).
- **Why it matters:** A tech-agnostic KB must be neutral to both legacy AND target stack; auto-detect reduces coverage below the union. Advisory + realistic target-idiom leaks are low-frequency — hence LOW.
- **Fix:** Have the gates call `--stack=all`, or always union the known target stack's tokens with the legacy set regardless of scan-meta.

#### L6 — Several between-wave "gates" are non-enforcing diagnostics; schema mislabels one "(gate enforced)"
- **File:** `wave-dispatch-templates.md:246, 281-294`; `knowledge-base-schema.md:262`
- **Evidence:** Wave-1 glossary "gate" is `grep -c '^## ' glossary.md  # ≥40 entries expected` — prints a count, never compares or sets GATE. The Wave-2 gate (`:282-294`) sets `GATE=1` on failure but never inits GATE nor echoes a PASS/FAIL verdict (unlike Wave-1). Schema `:262` marks "≥3 entries per workflow domain (gate enforced)" but no validator counts §9 entries.
- **Why it matters:** "(gate enforced)" is a verifiable false enforcement claim — precisely the "prose that says enforced but isn't" the gate>rules>hooks doctrine polices. Cosmetic/doc-integrity, no moat breach — hence LOW.
- **Fix:** Make each gate fold its condition into GATE and echo an explicit verdict; downgrade schema `:262` to "(advisory — self-checked)" unless a validator actually counts §9 entries.

#### L7 — `validate-kb-flows.sh` §8 State Machine accepts raw ASCII transitions, bypassing all Mermaid syntax checks
- **File:** `plugins/mega-sdd/scripts/validate-kb-flows.sh:358-360`
- **Evidence:** `elif has_transitions:` → `sec8_state_machine_fence` **PASS** ("consider mermaid fence for consistency"). `check_mermaid_syntax` runs only inside mermaid fences, so an un-fenced §8 with transition chains ships un-validated. §3 correctly FAILs the equivalent non-fenced flow (`:314-323`); schema §8 (`:241`) marks the Mermaid `stateDiagram` MANDATORY.
- **Why it matters:** Inconsistent with §3 and the schema's MANDATORY status. Narrow trigger (only one-line `A --> B --> C` chains / labelled edges match; the canonical one-arrow-per-line form correctly FAILs) and non-blocking — hence LOW.
- **Fix:** Treat a non-N/A §8 with transitions but no mermaid fence like §3 — FAIL `kb_flow_not_mermaid` (or at least route it through the syntax checker).

#### L8 — Schema README roll-up omits the two sections `generate-intent --kb` actually reads first
- **File:** `knowledge-base-schema.md:414-427`; consumer `kb-submode.md:35`; producer `wave-dispatch-templates.md:358-396, 439-444`
- **Evidence:** The 10-section roll-up lists neither "Reengineering Opportunities" nor "Mutability Tier Distribution" and says Critical findings "GETS READ FIRST" — yet `kb-submode.md:35` reads exactly those two omitted sections, the producer emits both, and the final gate (`:439-444`) hard-fails a README not leading with Reengineering Opportunities.
- **Why it matters:** Stale schema subsection contradicting the later reengineering-first reorg. Operative producer path + hard gate prevent actual breakage (the finding's "would starve the consumer" is foreclosed) — hence LOW.
- **Fix:** Add "Reengineering Opportunities (Surface First)" + "Mutability Tier Distribution" as the leading required sections in the schema roll-up so schema, template, gate, and consumer agree.

#### L9 — Schema directory tree omits `data-mutation-policy.md` from `99-rebuild-architecture/`
- **File:** `knowledge-base-schema.md:65-69`
- **Evidence:** The tree lists only 4 children (suggested-erd/system-flow/module-dependency-graph/phasing), no ellipsis — `data-mutation-policy.md` absent. Yet the consumer reads it there (`kb-submode.md:36`), the validator HALT-enforces it (`validate-kb-reengineering.sh:113-120`), and the producer writes it (`wave-dispatch-templates.md:354, 435`).
- **Why it matters:** The file "drives ERD freedom in generate-intent --kb" (schema `:370`); the canonical tree contradicts the schema's own template section + producer + validator. Doesn't break today (documented elsewhere) — hence LOW.
- **Fix:** Add `data-mutation-policy.md` to the `99-rebuild-architecture/` subtree.

#### L10 — Self-contradicting hardcoded version literals in emitted JSON templates
- **File:** `plugins/mega-sdd/skills/extract-intelligence/SKILL.md:218, 255` (vs frontmatter `:3`)
- **Evidence:** Frontmatter `version: 1.12.0`; snapshot template `"generated_by":"extract-intelligence@1.6.0"` (`:218`); scorecard template `"extractor_version":"extract-intelligence@1.11.0"` (`:255`). Three disagreeing versions baked as literals into artifacts the skill emits. Snapshot `:218` also diverges from the canonical `shared-snapshot-schema.md:113` placeholder form.
- **Why it matters:** Every extraction stamps a stale/contradictory provenance version. No consumer gates on it (freshness uses the sha256 map; the scorecard's `ext_ver` is read only in the pre-1.11.0 `else` branch) — hence LOW.
- **Fix:** Replace both literals with `extract-intelligence@<version>`, resolved from `plugin.json`/frontmatter at emit time.

#### L11 — Time-sensitive / changelog fragments in runtime prose
- **File:** `knowledge-base-schema.md:191, 199, 201, 325`; `SKILL.md:164, 270`
- **Evidence:** "best-effort / advisory in v3.72.0", "advisory via /mega-sdd:analyze in v4 Hybrid — no longer a hard-block", "Fork-B-future … later iter", "Pre-v1.4 KBs", "this iter" (×2). References are loaded into model context — they ARE runtime prose.
- **Why it matters:** The contract forbids `vN+`/`Iter N`/changelog fragments in any runtime prose — the pre-v4 version-archaeology anti-pattern. Purely cosmetic — hence LOW.
- **Fix:** State the stance in present tense without version stamps ("advisory / best-effort — not validator-blocking"; "KBs without tier markers are treated as `[INTENT]`"); move roadmap notes to CHANGELOG/spec.

#### L12 — Per-wave subagent counts (4, 5) exceed default `--max-parallel=3` with no batching
- **File:** `wave-dispatch-templates.md:266, 298, 302`; `SKILL.md:50, 77`
- **Evidence:** SKILL.md:77 "never more than `--max-parallel` subagents in flight" + default 3 (`:50`); yet Wave 2 dispatches 4 and Wave 3 dispatches 5, and `grep -rni batch skills/extract-intelligence/` is empty.
- **Why it matters:** The stated cap is unenforced by default. But total token cost is unchanged by peak concurrency (this is a concurrency nit mis-framed as token-budget), it's soft non-moat guidance, and the wave template's explicit "Dispatch 5" is the tested config — hence LOW.
- **Fix:** Either dispatch each wave in `ceil(domain_count / max-parallel)` sequential batches so the invariant holds, or raise the documented default to 5 and delete the contradicting "never more than" language.

#### L13 — Glossary-index savings figure is internally inconsistent and unit-mixed
- **File:** `wave-dispatch-templates.md:62`
- **Evidence:** "~96 KB … per wave (15% of 535K wave token budget). 4 subagents × 3 waves = 12" — but 4 subagents each avoiding ~96 KB is ~384 KB/wave (not 96); "15% of 535K" pits KB-bytes against a *token* count (`:469`); and "4 × 3 = 12" contradicts the skill's own Wave-3 = 5 (true counts are 4+5+3).
- **Why it matters:** The stage's sole quantified token-perf claim doesn't survive inspection (the dedup mechanism itself is sound). Doc-accuracy only — hence LOW.
- **Fix:** Recompute per-wave saving as `(subagents_in_wave − 1) × glossary_bytes` converted to tokens before comparing to a token budget; fix the arithmetic to 4/5/3, or state the saving qualitatively.

---

## 3. What's strong (be fair)

This stage is a genuinely well-built moat anchor, not a rough first draft:

- **Dual orthogonal marker axes are a real, correct design.** Confidence (`[VERIFIED]/[INFERRED]/[OPEN]`) × mutability (`[LOCKED]/[INTENT]/[ARTIFACT]`) with default-to-`[INTENT]` (never auto-`[LOCKED]`/`[ARTIFACT]`) is exactly the "analysis input, not a 1:1 mirror" framing a rebuild needs, and the tiers route cleanly into `generate-intent --kb`'s vault/OQ/Hard-Rule decisions (`kb-submode.md:59-67`).
- **Per-claim citation grounding is enforced on the right axis.** `validate-kb-markers.sh` requires each `[VERIFIED]` line to carry its OWN same-line anchor with no proximity window — the strict interpretation. Its "deliberately broad, no hardcoded extension list" comment shows the authors already learned the per-stack-drift lesson (which makes the citations-validator regression H1 a fixable oversight, not a design flaw).
- **The stage correctly refuses to assert a hard block.** Per the enforcement doctrine, extract-intelligence's checks live in the rule/gate/advisory tier; the moat's hard block correctly lives downstream at the bind→units CONFLICT gate. Every defect above is confined to advisory precision — none can push fabricated content through a blocking rail.
- **The agent contract is clean.** `domain-extractor.md` (tools `Read, Write, Edit, Bash, Grep, Glob`; model sonnet) correctly excludes `Agent`/`AskUserQuestion` and uses no `hooks/mcpServers/permissionMode` — fully compliant with the plugin-agent frontmatter standard.
- **The schema is thorough and self-defending.** Mandatory 11-section template with "empty → `_None detected_`, never omitted", the §3a staged-input block for the maker-checker case, ERD Quality Rails with a mandatory `## Departures from Legacy`, and the Extraction Completeness Contract (P1-P6) with a genuine anti-halu intent ("a green scorecard hiding a gap is the failure"). The bones are right; the gaps are in the *checkers'* fidelity, not the contract.
- **Wave-based parallelism + glossary pre-parse is a sound token architecture** (the mechanism, if not L13's arithmetic): one glossary parse replacing N full-document reads per wave is a legitimate optimization.

---

## 4. Prioritized action list (cheapest-high-value first)

Version discipline: all script edits are plugin-level (`plugin.json` SemVer bump, `marketplace.json` must match); SKILL/schema/reference edits also bump the per-skill `version:` in `extract-intelligence/SKILL.md` frontmatter (currently `1.12.0`). Fixtures live under `tests/fixtures/`.

| # | Fix | Files | Pinned by | Value / Cost |
|---|-----|-------|-----------|--------------|
| 1 | **H1** — swap the citations extension whitelist for the generic pattern; emit WARN (not SKIP) on 0-citations-in-a-grounded-KB | `validate-kb-citations.sh:94-96,106-112` | New fixture: `.cs`-only §11 must not return SKIP | Highest value, ~1-line pattern swap. **Do first.** |
| 2 | **M9** — fix bare `references/model-tiers.md` → full plugin-root path | `SKILL.md:74` | ref-resolution check in `/mega-sdd:analyze` | Trivial edit, removes a dead pointer |
| 3 | **M8** — migrate Wave-3 depth numbers to §7/§8/§9; kill double-labelled §8 | `wave-dispatch-templates.md:314-320` | grep: no `§8 Edge Cases` in the block | Cheap doc fix, removes agent-facing contradiction |
| 4 | **L1 + L2** — sync `validate-kb-output` titles to schema (or drop titles), anchor the match, add `intent_count`/`artifact_count` to `marker_checks`; correct schema `:107` | `validate-kb-output.sh:108-172`, `knowledge-base-schema.md:107` | fixture: KB with `[ARTIFACT]` count mismatch must FAIL | Cheap, closes 2 tier-integrity/consistency gaps |
| 5 | **M6 + L4 + L5** — broaden `kb-leak-scan` `SCAN_DIRS` (section-aware for §11/Source cells), add Oracle/DB2 tokens, gates call `--stack=all` | `kb-leak-scan.sh:58-61,124`; `wave-dispatch-templates.md:258,431` | fixture: Oracle/framework leak in `40-business-rules/` must be reported | Cheap, three coverage holes in one pass |
| 6 | **M1** — mandate `## Phase N — <title>` H2 in producer; harden validator to `^## Phase` | `knowledge-base-schema.md:452`, `wave-dispatch-templates.md:353`, `validate-kb-reengineering.sh:130` | fixture: `### Phase 1` phasing file must WARN, not silently single-phase | High value (stops silent scope collapse), moderate cost |
| 7 | **M5** — replace hardcoded Indonesian regulator list with schema-derived rule extraction (or ship as pack) | `audit-domain-rules.sh:80-82` | fixture: a GDPR/HIPAA KB must not PASS "0/0" | Removes a contract violation + false compliance assurance |
| 8 | **M4** — broaden legacy-root manifest probe to all §8.5 stacks; drop project-specific subdir list → bounded recursive walk; require unique basename; pass `--legacy-root` from PostToolUse | `validate-kb-citations.sh:49-60,130-139`; `post-tool-use:569` | fixture: Go/C# legacy in `_source/` resolves citations | Removes project-specific behavior + tech-agnostic gap |
| 9 | **M7** — constrain `PATH_LINE_RE` to require `/` or a source extension | `validate-kb-markers.sh:66` | fixture: regulation-only `[VERIFIED]` line flags uncited | Cheap, closes citation false-negative |
| 10 | **M2** — make `_kb_source` directory-agnostic in all 4 sites; ambiguity warning in the staging guard | `vault-contract.md:118`, `generation-guide.md:248`, `templates/04-flows.md:84`, `knowledge-base-schema.md:469`, `validate-vault-flow-staging.sh:110-113` | fixture: staged `10-domains/` workflow — guard must resolve, not SKIP | Higher cost (5 sites), protects the staging anti-regression guard |
| 11 | **M3** — add Wave-0 purge/idempotency + Wave-5 own-run enumeration | `SKILL.md:199-203`; `wave-dispatch-templates.md` Wave 0/5 | fixture: re-run with drifted domain set produces no orphan in synthesis | Highest cost; guards canonical-KB integrity |
| 12 | **L3, L6-L13** — batch of doc/consistency/cosmetic cleanups (scorecard per-principle corroboration, gate verdicts, §8 mermaid parity, README roll-up + directory-tree schema sync, version literals, time-sensitive prose, batching/glossary arithmetic) | as cited per finding | `/mega-sdd:analyze` consistency pass | Low value each; fold into the next version bump |

**Sequencing note:** #1 is the only fix touching a stated moat invariant (tech-agnosticism) and is nearly free — ship it first. #6, #7, #8 all attack the same underlying disease (one-codebase tuning) and should be batched into a single "tech-agnostic hardening" release with a multi-stack fixture matrix, since that fixture set is what actually pins them against recurrence.