# God-Review Stage 3: `scan-codebase` — findings & fix batches

- **Date:** 2026-07-02
- **Reviewer:** adversarial multi-lens workflow (6 blind lenses -> dedup -> refute-by-default verify -> synthesize), run id `wf_0fd2a037-e67`; 46 agents, 537 tool calls.
- **Skill under review:** `plugins/mega-sdd/skills/scan-codebase/` v2.16.0 (SKILL.md 102 lines + 7 references, 1,587 lines prose + 9 tree-sitter query files) + `scripts/validate-codebase-map.sh`, `scripts/secret-scan.sh`, `scripts/compute-lock-digests.sh`, hook wiring, and consumer contracts (bind-codebase, generate-intent --scan, orchestrate-flow handoff, sync lane).
- **Method:** same discipline as stages 1-2 (extract-intelligence v4.54.0, generate-intent v4.55.0). Lenses: validator-drift, tech-agnosticism, anti-halu-secrets, procedure-correctness, deep-scan, integration-contract. Every finding adversarially verified (refute-by-default); verifier severity corrections applied. Partial-pass guard armed but unused — 0 dead lenses this run.
- **Independent spot-check:** SC3-AH-1 re-reproduced by hand post-workflow: a fixture PEM block run through `secret-scan.sh --redact` ships the full base64 body + END line while reporting `redacted:true`, exit 0.

## Dominant defect classes (stage-3 signature)

1. **Enforcement wired to the wrong write path.** The one deterministic gate this skill feeds (DEGENERATE-MAP, PreToolUse) is keyed to a PostToolUse `Write|Edit` glob — but the skill's own procedure mandates temp-file + `mv` writes (Step 10a scrub), which the glob never sees. The gate is fail-open on fresh degenerate maps AND fail-closed (unclearable) after a valid re-scan. The stage-2 class was "validator checks a grammar the generator never emits"; the stage-3 class is "validator never runs on the artifact the procedure actually produces."
2. **Detection-vs-extraction parity holes.** Step 8.5 detects frameworks (aspnetcore, dotnet, kotlin manifests) for which Steps 5/6/7 have no extraction signature and the `_universal` fallback never fires (it is keyed to "no framework match") — whole ecosystems get a confidently-wrong "None detected" ground truth. The tech-agnosticism standard is violated by the gap between the two tables, not by any single row.
3. **Positive attestation without delivery.** `redacted:true` over an unredacted PEM body; "read-only enforced at dispatch" with no dispatch mechanism; "~30-50% I/O reduction" for a snapshot shortcut whose consumer says verbatim it is NOT a shortcut; a "file scan log" no step writes. In a plugin whose moat is no-fabrication, prose fabricating its own enforcement is the highest-value defect class.

**Scope:** scan-codebase skill surfaces (SKILL.md, references/, queries/), `scripts/validate-codebase-map.sh`, `scripts/secret-scan.sh`, `scripts/compute-lock-digests.sh`, `hooks/pre-tool-use` / `hooks/post-tool-use`, and consumer contracts (bind-codebase, generate-units, orchestrate-flow handoff).
**Result:** 34 findings CONFIRMED (4 High / 18 Medium / 12 Low, after verifier severity corrections), 4 REJECTED, 0 UNVERIFIED, 0 dead lenses.

---

## 1. Verdict summary table

Severities are post-verification (`corrected_severity` applied). `↓` marks a verifier downgrade from the original grade.

| ID | Severity | Title (abbrev.) | One-line defect |
|---|---|---|---|
| ECO-1 | **High** | ASP.NET Core/EF Core inert in Steps 6/7 | Framework detected by Step 8.5 but no route/model signature row exists and the `_universal` fallback never fires → §3/§4 = "None detected" on every .NET repo, falsifying the "every supported framework" claims |
| ECO-2 | **High** | Regex engine has no C#/F#/Kotlin patterns | Default (tree-sitter-absent) engine extracts zero symbols for three detected languages; VERSIONS.md's "Kotlin extracts via regex" is a ghost claim |
| SC3-AH-1 | **High** | Private-key redaction leaves key body | `--redact` strips only the PEM BEGIN header (regex `[^-]*` self-terminates), ships the base64 key body while reporting `redacted:true`, exit 0 |
| INT-1 | **High** | Degenerate-map gate dead on the mandated write path | Temp-file+`mv` write (Step 10a / 10.5.3) bypasses the PostToolUse Write\|Edit glob → validator state goes stale in BOTH directions (fail-open on fresh degenerate map; permanent false-block after valid re-scan) |
| SC3-V1 | Medium ↓ | Iter-79 interface-depth check dead on conformant maps | Typed-field regex matches the `:42` in mandated file:line citations, so every §2 row counts as signature-bearing; the ast→binary degradation the check exists to catch is undetectable |
| SC3-V3 | Medium | "Read-only enforced at dispatch" is false | Deep-scan extractors are prompt-template dispatches, not plugin agents with `tools:` frontmatter; the only restriction is prompt prose, and "mutating-Bash" exclusion is not a dispatchable property |
| SC3-V4 | Medium | §3/§4 numbering inverted in three consumer docs | bind-codebase implementation-state.md, oq-resolution.md, and scan's own tree-sitter-integration.md swap routes vs data models against the schema/validator |
| SC3-V5 | Medium | Section-presence check is a whole-content substring match | Headings quoted in a fenced code block satisfy Check 2, so the DEGENERATE-MAP bind gate never sees `codebase_map_sections_incomplete` for the exact empty-shell shape it blocks |
| SC3-V6 | Medium | Validator omits `engine` + `last_scanned_commit` | Schema-required frontmatter fields unchecked; a map that silently disables the incremental sync lane gets a clean PASS |
| SC3-V7 | Medium | Validator + hook cover only the canonical map path | Documented `--out=` and legacy `<root>/codebase-map.md` (which bind-codebase accepts) are never validated → gate structurally inert, fail-open, on that class |
| ECO-3 | Medium | .NET missing from lock digests + manifest pre-parse | `compute-lock-digests.sh` emits empty digests for dotnet → deep-scan cache never invalidates on NuGet changes (empirically confirmed) |
| SC3-AH-3 | Medium | Cap-200 truncation has no schema marker | Truncated-away real elements become OQ/NEW in binding (task_type `create` risk); the promised "file scan log" is never produced |
| SC3-AH-4 | Medium | libs slice has no `_source` yet drop rule claims universal citation | Self-contradictory contract: either the consolidator always drops libs, or the citation rail is silently dead for one of five slices |
| SC3-AH-6 | Medium | Secret-scrub omitted from Step 10.5.3 write procedure | deep-scan-stage.md's 7-step write algorithm never runs the redactor; reuse-index.yaml is covered by no prose at all |
| SP-1 | Medium ↓ | Regex patterns miss dominant symbol forms | `export default async function`, `final class`, `async def`, Go receiver methods, `pub async fn` all unmatched — botched optional group vs the pattern's own intent; §2 degrades on the guaranteed baseline path |
| SP-3 | Medium | Incremental fallback fail-open on AND-joins | Stamp-missing + any journaled AI write → incremental proceeds with the git delta channel dead; stale rows carried byte-identical, then staleness laundered by restamp |
| SP-5 | Medium | `express` matched before `@remix-run/` | First-match-wins misdetects Remix express-adapter apps as Express → all file-based routes missed |
| SP-7 | Medium | Engine probe checks binary only, not grammars | Default `brew install` ships zero grammars; query failure has no defined path → map can stamp `precision_tier: ast` over improvised/failed extraction |
| DS-1 | Medium ↓ | Slice cache signatures omit source files | Source-only edits (controllers, policies, tailwind config) produce FULL CACHE HIT → stale auth/authz/ui_ux slices with dead citations served as fresh |
| DS-2 | Medium ↓ | Failed-slice cache poisoning | Twice-failed slice still gets a fresh cache signature; staleness diff never reads `partial_slices` → `partial:true` never self-heals |
| DS-5 | Medium | Snapshot's advertised payoff is dead | Scan docs promise bind skips re-tokenization (30–50% I/O); the consumer says verbatim "NOT a parsing shortcut"; `source_files_sha256_map` has no reader |
| INT-3 | Medium | `--auto` handoff `next_action` unconditionally generate-intent | Operative emission spec contradicts both the handoff-contract's claimed CWD-conditional and SKILL.md's bind-codebase hand-off; Mode D expects detect-drift, which no copy produces |
| SC3-V8 | Low | Query-coverage three-way drift | SKILL.md says 3 languages, tree-sitter-integration.md lists 8, disk ships 9; C# grammar unpinned in VERSIONS.md |
| SP-4 | Low ↓ | Zero-commit repo stamps literal `HEAD` | `$(git rev-parse HEAD)` in an empty repo captures the string "HEAD"; self-heals on first incremental restamp → one-window blind spot only |
| SP-6 | Low ↓ | `$RG_OPTS` code block unexecutable | Embedded single quotes break rg on bash and zsh — but the block is comment/placeholder prose on a fallback path with a loud, recoverable error |
| SP-8 | Low | "Truncate the journal" contradicts "rotate, don't truncate" | Three surfaces name the data-losing verb the operative consume protocol forbids |
| SP-9 | Low | `--shallow-scan` has two semantics, catalog documents one | The "complete flag catalog" omits the §2 sha256 reuse gate keyed to the same flag |
| DS-3 | Low ↓ | Dangling `§file-lock` citation | The anchor doesn't exist in memory/SKILL.md — but the pattern IS fully specified in vault-contract.md §Concurrency contract + `memory-write.sh`; residual defect is citation hygiene |
| DS-4 | Low ↓ | `<MANIFEST_FACTS>` injects repo text with no data-fencing rail | Real gap (no data-vs-instruction rail anywhere), but marginal escalation over an already-attacker-controlled repo; defense-in-depth item |
| DS-6 | Low | Canonical schema documents 4 cache slices, stage writes 5 | Schema-faithful reimplementation would kill the reuse slice's cache; default execution path unaffected |
| DS-7 | Low | Ghost `<FILE_HINTS>` variable in libs prompt | Absent from substitution table and the template's own header; graceful fall-through |
| DS-8 | Low | Trigger specified against numeric confidence that never exists | "≥ 0.5" / "(X.XX)" vs string-enum-only producer; `fallback` unnamed in the skip branch |
| INT-4 | Low | reuse-index.yaml + snapshot unlisted in handoff artifacts | Violates handoff-contract's MUST-list rule; promised `reuse_index:` field never emitted |
| INT-6 | Low | Symbol-graph contract phantom on producer side | Scan claims reference captures feed a graph it discards; generate-units claims a cache file nothing writes (but does own a specified rebuild) |

---

## 2. Per-finding detail

### High

**INT-1 — Degenerate-map gate + validator dead on the mandated write path**
*Defect:* `validate-codebase-map.sh` (feeding `.codebase-map-state.json`, which the PreToolUse DEGENERATE-MAP gate reads) fires only from the PostToolUse `Write|Edit)` branch on a FILE_PATH glob. Step 10a mandates temp-file + scrub + `mv` (`scan-procedure.md:289`); Step 10.5.3 mandates `.tmp` + `mv` (`deep-scan-stage.md:348`). The Bash branch has no handler. Both failure directions empirically reproduced: fresh degenerate map via `mv` → no state → gate silent (fail-open, the exact clinic empty-shell scenario); valid re-scan via `mv` over a stale FAIL state → gate keeps blocking and its own remediation message ("Re-run scan-codebase") cannot clear it.
*Evidence:* `hooks/post-tool-use:515-522`; `hooks/pre-tool-use:503-517` (no lazy re-validate, unlike GateGuard at :531-537); only other refresh is manual `run-analyze.sh:253`.
*Moat impact:* Direct — invariant #1's deterministic backstop against binding on a false-empty map is inert on every procedure-compliant scan; also the enforcement doctrine's "gates > rules" broken by wiring, plus a hard-wedge false block.
*Fix:* Make the PreToolUse gate self-healing like GateGuard (re-run validator when map is newer than state / state absent while map exists); optionally add a Bash-branch `mv`-dispatch and an explicit validate step after the Step 10a rename.

**SC3-AH-1 — Private-key redaction leaves the key body while reporting `redacted:true`**
*Defect:* `secret-scan.sh:35` pattern `-----BEGIN … PRIVATE KEY[^-]*-----` self-terminates at the header's trailing dashes, so `--redact` replaces only the BEGIN line; the base64 body and END line ship in codebase-map.md, with exit 0 and `redacted:true`. Empirically reproduced (AWS/JWT/password fixtures redact fully; PEM does not). Redaction strips the very BEGIN marker downstream scanners key on, making the residue *less* detectable.
*Evidence:* `secret-scan.sh:35`, `:56`; contradicts `scan-procedure.md:303`, `halts-flags-handoff.md:23`. Same header-only regex in `scan-secrets-code.sh:54` (detection-only there — adequate).
*Moat impact:* No-fabrication/positive-assurance breach in a security gate: the artifact propagates to committed `.mega-sdd/` state and FSD/handoff docs.
*Fix:* Span the whole block with `.*?-----END … PRIVATE KEY-----` + `re.DOTALL`, header-only fallback for truncated blocks, fixture test asserting no base64 line survives `--redact`.

**ECO-1 — ASP.NET Core / EF Core detected but extraction-inert**
*Defect:* Step 8.5 detects `aspnetcore` (`scan-procedure.md:246`) and `dotnet` (`:247`); Step 2 detects the ecosystem (`:82`). But the Step 6 routes table (`:161-182`) and Step 7 models table (`:191-206`) have no .NET rows, and the `:184` fallback is keyed to "No framework match (`_universal`)" — aspnetcore IS a match, so it never fires. §3/§4 are written "None detected" and handed to bind-codebase as ground truth. Falsifies `:157`, `:188`, and SKILL.md:53's "every supported framework" claims; all 23 other 8.5 frameworks are covered. `tags-csharp.scm` doesn't help — Steps 6/7 are signature-grep on both engines. No rescue path (deep-scan writes starterkit-context, not §3/§4).
*Moat impact:* Invariant #1 — whole-ecosystem false-empty ground truth turns every vault route/entity claim into OQ/CONFLICT against a lie; violates the repo's own tech-agnosticism standard in CLAUDE.md.
*Fix:* Add Step 6 rows (attribute routing `[Http…]`/`[Route]`, minimal APIs `app.Map…(`) and a Step 7 EF Core row (`: DbContext` + `DbSet<T>`, `[Table]`/`[Key]`); or re-key the fallback to "no Step 6/7 signature for the matched framework".

**ECO-2 — Regex engine (default install state) has no C#, F#, or Kotlin patterns**
*Defect:* Step 5's regex list (`scan-procedure.md:144-151`) covers TS/JS, PHP, Python, Go, Rust, Ruby, Java only. Step 2 detects csharp/fsharp (`:82`) and kotlin (`:81`). Consequences: C# → §2 = 0 rows on regex (the default engine — tree-sitter needs manual install + manual grammar cloning), firing the '0 public interfaces' halt with a misleading `--include`-misconfig diagnosis; F# → no `.scm` AND no regex, zero extraction path on either engine; Kotlin → `VERSIONS.md:38` affirmatively promises "extract via regex" but no Kotlin pattern exists and `rg --type java` never reaches `.kt` — a ghost claim. Empirically confirmed on fixtures (0 hits on C#/F#/Kotlin samples).
*Moat impact:* Invariant #1 ground-truth degradation for advertised stacks + a no-fabrication violation in VERSIONS.md's prose.
*Fix:* Add C#/Kotlin/F# regex rows (see finding's fix_sketch) or delete the VERSIONS.md:38 claim and document the gap.

### Medium

**SC3-V1 (High→Medium) — Interface-depth check dead on citation-conformant maps.** `validate-codebase-map.sh:133`'s typed-field regex `\w+\s*:\s*\w+` matches `ts:42` in the File column, so any §2 row carrying SKILL.md:74's mandated file:line citation counts as signature-bearing even with an empty Signature cell. Empirically proven by minimal pair (with `:42` → PASS; without → WARN). Downgraded because the check is WARN-only (advisory surface, no gate breach) — but a dead detection contradicting its own Iter-79 purpose is real. *Fix:* apply heuristics to the Signature cell (`cells[3]`) only; add a fixture.

**SC3-V3 — "Read-only enforced at dispatch" is enforcement fiction.** `halts-flags-handoff.md:22` claims dispatch-level tool restriction for deep-scan subagents; the extractors are not plugin agents (no `tools:` frontmatter — `agents/` confirmed), the only mechanism is repeated prompt prose (`deep-scan-prompts.md:117/:171/:229/:280/:319`), and "Bash (read-only)" (`:25`) is not a dispatchable property. Exactly the "prose that says HALT enforces nothing" anti-pattern, sitting in the anti-halu rails section that enforcement audits and fork-extension decisions rely on. *Fix:* define real plugin agents with `tools: Read, Glob, Grep` (drop Bash), or reword to honest prompt-level-rule language.

**SC3-V4 — §3/§4 numbering inverted in three consumer docs.** Schema/validator/SKILL.md agree §3=Routes, §4=Data models; `bind-codebase/references/implementation-state.md:14/:20/:23/:48-49`, `oq-resolution.md:54/:59`, and scan's own `tree-sitter-integration.md:58` are all swapped. Sits inside the Implementation State Map rules (invariant #1); bounded blast radius (self-describing headers let the model self-correct in most cases; harm = wrong §-number citations in binding.md + edge-case NEW/IMPLEMENTED misclassification). *Fix:* correct the three files to match the schema; add a cross-doc consistency assertion to fixtures.

**SC3-V5 — Section-presence check is substring-over-whole-file.** `validate-codebase-map.sh:87` (and the `:69` frontmatter probes) match anywhere in content — a map whose only "sections" are the 7 headings quoted in a fenced code block reports "all 7 sections present" (empirically reproduced; hook-gate simulation prints NOT BLOCKED). The schema itself presents the full skeleton in a fenced yaml block, so a degenerate scan echoing its template produces exactly the bypass shape. Defeats the hard DEGENERATE-MAP gate (invariant #1) on a narrow sub-case. *Fix:* line-anchored `re.MULTILINE` heading match after stripping fenced blocks; same for frontmatter.

**SC3-V6 — `engine` and `last_scanned_commit` unchecked.** `required_fm` (`:67`) omits both despite the schema requiring `engine` unconditionally and `last_scanned_commit` when `.git` exists; a map missing both passes clean (empirically reproduced). Silently disables the whole sync lane (session-start staleness notice no-ops, detect-drift REUSE-FIRST degrades, Mode D loses its git channel) with zero signal. *Fix:* add `engine` to required_fm; WARN `codebase_map_staleness_stamp_missing` when `.git` exists and the stamp is absent.

**SC3-V7 — Validator/hook cover only the canonical path.** MAP_PATH hardcoded (`:35`, SKIP exit 0 when absent); PostToolUse dispatch matches only `*.mega-sdd/codebase/codebase-map.md` (`post-tool-use:517`). The flag catalog documents `--out=` "always respected" plus the legacy `<root>/codebase-map.md`, which bind-codebase probes and binds against (`bind SKILL.md:22`). Gate reads only the canonical state file, fail-open → recreates the clinic scenario on a documented-supported path class. *Fix:* teach the validator bind-codebase's probe order; widen the hook case or pass `--file-path` through.

**ECO-3 — .NET missing from lock digests + manifest pre-parse.** `compute-lock-digests.sh:38-46` CANDIDATES and the `:13` enum omit dotnet despite the header's "Tech-agnostic by construction"; empirically confirmed (fixture with csproj + packages.lock.json → all-empty digests, exit 0). Deep-scan cache for .NET repos never invalidates on NuGet changes (FULL CACHE HIT forever until `--no-cache`); Step 10.5.1.5 manifest_facts also has no dotnet block. Violates the CLAUDE.md tech-agnosticism doctrine; non-blocking + recoverable → Medium. *Fix:* add dotnet CANDIDATES (packages.lock.json, `*.csproj` glob, Directory.Packages.props), extend the enum, add a `dotnet:` manifest_facts block.

**SC3-AH-3 — Cap-200 truncation invisible to binding.** `halts-flags-handoff.md:18` caps extraction at 200/category and points to a "file scan log" no step ever writes (grep: sole occurrence); the schema has no truncation field (the deep-scan path DOES formalize `truncated.<cat>: true`, proving inconsistency, not design); bind-codebase maps absence → OQ/NEW (`binding-contract.md:35/:47`) and `--strict` blocks (`:82`). Sharpest harm: truncated-away implemented elements get task_type=create → duplicate implementation risk. Fail-safe direction (OQ, never fabrication) keeps it Medium. *Fix:* frontmatter `truncated_sections` marker; map absence-in-truncated-section to UNKNOWN; delete or implement the scan-log pointer.

**SC3-AH-4 — libs slice `_source` contradiction.** `deep-scan-prompts.md:333-335` claims all 5 prompts carry the citation rail "verbatim" and slices without `_source` are dropped (`halts-flags-handoff.md:21`, SKILL.md:74) — but the libs OUTPUT FORMAT (`:270-277`) and schema §libs (`starterkit-context-schema.md:345-354`) define no `_source`; the schema's own Anti-halu rail 2 contradicts its own §libs, and the drop-rule example (`:338`) targets exactly this slice. Either permanent libs-drop or a silently dead rail — a self-contradictory shipped contract (citation-discipline invariant). *Fix:* add slice-level `_source` to libs, or scope the drop rule to the four cited slices, consistently across all four surfaces.

**SC3-AH-6 — Scrub missing from the Step 10.5.3 write site.** `scan-procedure.md:289` claims the redactor runs before the starterkit-context write, but the operative 7-step algorithm in `deep-scan-stage.md:235-352` never mentions secret-scan (grep: 0 matches across both deep-scan refs); reuse-index.yaml (first-party function signatures — likeliest to embed default creds) is named by no gate, hook, or validator anywhere. Contrast: extract-intelligence carries the gate inline at its write site. Prose-gate consistency gap; partial mitigation (agent likely just read Step 10a) keeps it Medium. *Fix:* insert `secret-scan.sh --redact` between build (step 5) and atomic write (step 6) for BOTH files; name reuse-index.yaml at `halts-flags-handoff.md:23`.

**SP-1 (High→Medium) — Regex patterns miss dominant symbol forms.** Every empirical miss re-reproduced: `export default async function`, `export enum`, `final class`, `public static function`, `async def`, Go receiver methods, `pub async fn`/`pub type`/`pub(crate)` all → no match (`scan-procedure.md:144-151`); the TS pattern's `(default |async )?` group proves intent to match modifiers and botches it (one token, not both), and `:153`'s "GNU grep fallback always works" claims a capability it doesn't deliver. Downgraded: regex is the fallback (tree-sitter default path unaffected; `.scm` files cover all cited languages), fallback is loudly warned + stamped `precision_tier: regex`, and binding is precision-aware (PARTIAL→UNKNOWN, never false CONFIRMED); §3/§7 survive via framework signatures. But on the guaranteed no-native-deps baseline, any Go/async-Python/async-Rust repo loses most of §2. *Fix:* widened patterns per fix_sketch + regression fixtures.

**SP-3 — Incremental fallback fail-open.** `scan-procedure.md:36`'s AND-joins mean: stamp-missing prior map + any journaled AI write → incremental proceeds with Channel B (git diff) unreconstructible; every manually-committed change since the prior scan is invisible, rows carried byte-identical (`:39`), the `:47` rail covers only "prior map corrupt", and `:43` then restamps HEAD — laundering the staleness permanently. Journal is AI-writes-only (`post-tool-use:376-401`, self-described "a HINT"). Narrow trigger population (legacy stamp-less maps) keeps it Medium; the unresolvable-sha sub-claim is weak (loud git fatal, agent recovers). *Fix:* full scan whenever the git channel is unavailable regardless of journal state; journal-only incremental reserved for not-a-git-repo with a stale-risk warning.

**SP-5 — Remix express-adapter misdetected as Express.** First-match-wins (`:219`) + table order `express` (`:230`) before `@remix-run/` (`:232`); the classic Remix express-adapter template ships both deps → framework=express, `app.(get|…)` signature extraction, every `app/routes/**` file-based route missed (`:167` unreachable). Ordering intent is proven elsewhere (next/nuxt/nestjs above express), so this is oversight. One caveat: the ":251 rule" is literally about starterkit packs — the defect stands without it. *Fix:* reorder meta-frameworks (`@remix-run/`, `@sveltejs/kit`) above server substrates.

**SP-7 — Grammar-absent state unhandled; `precision_tier: ast` can be a lie.** Step 0 resolves engine from `command -v` alone (`:60-61`); Step 5's only fallback is "no `.scm` file" (`:115-123`) — query-invocation failure (the default post-`brew install` state, empirically reproduced: "Error: No language found" for every language with no grammars configured) has no defined path, while `VERSIONS.md:32` promises graceful fallback nothing implements. install-deps installs only the binary and verifies with the same `command -v`. Map can stamp ast precision over improvised extraction; bind then treats matches as anchor-precise and the depth check passes regex rows (paren pairs). Corrupts precision provenance, doesn't bypass the CONFLICT gate → Medium. *Fix:* per-language grammar smoke test with downgrade + `grammars_used` recording.

**DS-1 (High→Medium) — Slice cache signatures omit source.** auth/authz/ui_ux/libs signatures = lock digests + pack section + catalog sha only (`deep-scan-stage.md:59-62`); the reuse slice DOES hash source (`:63-64` — authors knew), yet slice outputs are source-derived (entrypoints, authz declarations with file:line, tailwind tokens). Source-only edits → FULL CACHE HIT (`:75`) forever; the sync lane explicitly reruns only the lock-digest check; the invalidation matrix has no source-edit row and claims "correctness preserved" (defeating the intentional-design defense). Downgraded: bind-codebase never reads starterkit-context (moat unaffected); affected consumers are best-effort enrichment; deps bumps and `--no-cache` heal. *Fix:* fold a per-domain source component (pack file-hint dirs listing+mtimes, mirroring reuse) into each signature; also fold prompt/skill version.

**DS-2 (High→Medium) — Failed-slice cache poisoning.** Step 10.5.3 templates `per_slice` signature entries for all five domains unconditionally (`:250-336`); Step 10.5.1's staleness diff never reads `partial_slices` (`:70-77`) → a twice-failed slice's stored signature matches next run → FULL CACHE HIT reuses the partial YAML; `partial:true` never self-heals. Worse, the documented downstream remediation (`vault-contract.md:830`: `--force-deep`) does not bust the cache — only `--no-cache` does. Downgraded: enrichment layer not the binding moat; orchestrate-flow's ALWAYS-STOP starterkit_metrics_inconsistent halt catches the partial state; escape hatch exists. *Fix:* `stale_slices ∪= prior.partial_slices` in step 4c; don't write per_slice entries for failed domains; fix the `:830` remediation to `--no-cache`.

**DS-5 — Snapshot payoff is dead prose + write-only field.** Three producer docs promise bind-codebase skips re-tokenization with "~30–50% I/O reduction" (SKILL.md:68, deep-scan-stage.md:365, shared-snapshot-schema.md:139-142); the sole consumer compares one sha and states verbatim "NOT a parsing shortcut" (`auto-memory-handoff.md:41`); `source_files_sha256_map` for the codebase-map snapshot has no reader anywhere (orchestrate-flow chain-skip uses mtimes). Every scan pays per-file hashing for a write-only field; the perf figure is fabricated — in a plugin whose contract forbids fabrication. *Fix:* pick one truth — implement the shortcut, or delete the claims and give the sha map a real consumer (chain-skip: sha beats mtime) or stop writing it.

**INT-3 — Handoff `next_action` unconditional and wrong.** The operative emission spec (`halts-flags-handoff.md:114-119`, per handoff-contract:7's precedence rule) hardcodes `suggested_skill: mega-sdd:generate-intent`; handoff-contract's block falsely claims a CWD-conditional that "mirrors the operative copy"; SKILL.md says bind-codebase; Mode D expects detect-drift — no copy produces it. The orchestrator loop literally reassigns `current = handoff.next_action.suggested_skill`; the confidence-demotion gate is inert (scan emits no confidence field). Sits on the flagship `--deep`/`--auto` path; bounded by the upfront-confirmed chain plan → Medium. *Fix:* move the CWD-conditional (no vault → generate-intent; vault → bind-codebase; `--changed-only` under Mode D → detect-drift) INTO the operative YAML; align SKILL.md.

### Low

**SC3-V8** — Three-way language-coverage drift (SKILL.md:98 says 3, tree-sitter-integration.md:60-69 lists 8, disk ships 9) + C# grammar unpinned in VERSIONS.md. Routing is a disk-existence check so no misrouting; residual impact = stale always-loaded doc + unpinned grammar. *Fix:* update both lists + add a C# VERSIONS row.

**SP-4 (Medium→Low)** — Zero-commit repo stamps literal `HEAD` (`scan-procedure.md:285` guards only no-`.git`; repro: exit 128, stdout "HEAD"). Refuted headline: `:43` restamps real HEAD on the first incremental run → self-heals; blast radius is one window, partially covered by journal + porcelain, and detect-drift takes the safe stale path. *Fix:* `git rev-parse --verify HEAD^{commit}` guard; treat stamp=="HEAD" as missing.

**SP-6 (Medium→Low)** — `RG_OPTS` block breaks rg on bash and zsh (repro: exit 2 both). But the invocations are comments with `<paths>` placeholders on a fallback path, failure is loud, and `:144-151` restate the patterns plainly — one-step recoverable. *Fix:* array form or drop the redundant `--type-add` flags.

**SP-8** — SKILL.md:37, halts-flags-handoff.md:88, and sync.md:33 say "truncate the journal"; the operative protocol (`scan-procedure.md:45`) is "rotate, don't truncate". sync.md's literal reading preserves the crash-window ordering; residual harm = concurrent-session append loss for an agent following the hard rail without loading the reference. *Fix:* reword all three to "consume (rotate-and-delete per §Incremental step 4)".

**SP-9** — The "complete flag catalog" (`:85`) documents only `--shallow-scan`'s deep-scan opt-out, omitting the §2 sha256 reuse gate (`scan-procedure.md:107`). SKILL.md documents the second semantic twice and the coupling is intentional coherent design; reuse is sha-gated (correctness-neutral). *Fix:* extend the catalog entry with clause (b).

**DS-3 (Medium→Low)** — `deep-scan-stage.md:356` cites "memory SKILL.md §file-lock", a heading that doesn't exist — but the finding's harm claims are refuted: the pattern is fully specified in `vault-contract.md §Concurrency contract` (lock path, O_EXCL, backoff, 30s stale-steal) and implemented deterministically in `scripts/memory-write.sh` (mkdir-atomic, trap release, stale steal). Residual: imprecise anchor used in ~6 files. *Fix:* one-line repoint (or add the heading + link the script).

**DS-4 (Medium→Low)** — `<MANIFEST_FACTS>` embeds repo-controlled strings (scripts commands) into all 5 subagent prompts with no data-vs-instruction fencing anywhere in the plugin, and subagents are told the block is "authoritative". Real gap with a real escalation path into design_system/Hard Rules/exemplars — but the precondition already gives the attacker honest control of scan ground truth, impact is deferred through mediating stages, and the fix is best-effort prose. Cheap defense-in-depth. *Fix:* fourth cross-cutting rail (untrusted-data) + fenced injection block.

**DS-6** — Canonical schema (`starterkit-context-schema.md:365-395`) documents 4 per_slice entries and a /4 matrix; the stage computes/diffs/writes 5 (reuse). Default execution path writes reuse (stage template governs), so the "dead reuse cache" needs a schema-faithful reimplementer. *Fix:* one-file schema update (add reuse entry, 4→5, matrix row).

**DS-7** — `<FILE_HINTS>` at `deep-scan-prompts.md:257` is in no substitution-table entry and the libs header (uniquely among the 5) declares no FILE HINTS line — the one hole in an otherwise complete substitution contract. Graceful fall-through by the prompt's own "if provided, else…" clause. *Fix:* delete the token or promote it to `<LIBS_FILE_HINTS>`.

**DS-8** — Trigger grammar "≥ 0.5" / log "(X.XX)" (`deep-scan-stage.md:18-21`, SKILL.md:64) vs a producer that emits only `high|medium|low|fallback` strings; "(X.XX)" is unfillable, `fallback` skips only by accident and gets mislabeled LOW. Behavior survives via the enum comparison. *Fix:* rewrite the trigger purely in the enum domain, naming `fallback`.

**INT-4** — `deep-scan-stage.md:245-246` promises a `reuse_index:` handoff field the operative emission spec never defines; reuse-index.yaml and the Step 10.6 snapshot are written but unlisted in artifacts, violating handoff-contract's MUST-list + existence-check rule. Consumers read from fixed disk paths, so zero functional impact. *Fix:* list the artifacts (conditional comment, like starterkit-context) + declare or delete the field.

**INT-6** — Scan routes `name.reference.*` captures to a "symbol graph" its output contract has no channel for (discarded); generate-units says the graph is "cached per scan-codebase run" at `<vault>/.internal/symbol-graph.json`, which nothing writes; paths.md even names a third owner (execute-bolts). Overstated core refuted: generate-units DOES own a fully specified build path (pagerank-targeting §Step 1), so degradation is graceful. Residual: misleading producer attribution across three docs. *Fix:* fix attribution per option (a); correct the paths.md owner.

---

## 3. Proposed fix batches

Each batch is independently shippable. Suggested sequence: **3A → 3B (∥ 3C) → 3D → 3E → 3F** — gate determinism first (it multiplies the value of every other validator fix), then the two High extraction/security batches, then cache correctness, then the doc-truth batches.

### Batch 3A — Gate & validator determinism (1 High, 4 Medium) — *ship first*
Theme: the DEGENERATE-MAP gate and its sole feeder validator must actually see and verify what they claim to. All fixes land in `scripts/validate-codebase-map.sh` + `hooks/pre-tool-use`/`post-tool-use`, plus a validator fixture suite (currently nonexistent — a root enabler for V1/V5/V6).
- **INT-1** (High): self-healing PreToolUse re-validation (GateGuard pattern) + Bash-branch `mv` dispatch + explicit validate step after the Step 10a rename.
- **SC3-V5**: line-anchored MULTILINE heading match after stripping fenced blocks; same for frontmatter probes.
- **SC3-V1**: run signature heuristics on the Signature cell only.
- **SC3-V6**: add `engine` to required_fm; WARN on missing `last_scanned_commit` when `.git` exists.
- **SC3-V7**: validator adopts bind-codebase's probe order; widen the PostToolUse glob / pass `--file-path`.
- Deliverable: fixture tests covering degenerate-shell, fenced-skeleton, citation-bearing-empty-signature, missing-stamp, and legacy-path cases.

### Batch 3B — Ecosystem extraction coverage (2 High, 2 Medium, 1 Low)
Theme: tech-agnosticism — the §8.5 detection table vs actual extraction signatures. All fixes in `scan-procedure.md` tables + `SKILL.md`/`tree-sitter-integration.md`/`VERSIONS.md`.
- **ECO-1** (High): .NET Step 6 (attribute routing + minimal APIs) and Step 7 (EF Core) rows; optionally re-key the `_universal` fallback to signature-gap.
- **ECO-2** (High): C#/Kotlin/F# regex rows (or delete the VERSIONS.md:38 ghost claim).
- **SP-1**: widen TS/PHP/Python/Go/Rust patterns for modifier-prefixed/async/receiver forms + regression fixtures.
- **SP-5**: reorder `@remix-run/`/`@sveltejs/kit` above `express`/`fastify`.
- **SC3-V8**: sync the three language lists; pin the C# grammar in VERSIONS.md.

### Batch 3C — Secret-scan integrity (1 High, 1 Medium) — *can ship in parallel with 3B*
Theme: the redaction gate must deliver what it attests.
- **SC3-AH-1** (High): DOTALL whole-block PEM pattern + header-only truncation fallback + no-body-survives fixture test in `secret-scan.sh`.
- **SC3-AH-6**: inline the `--redact` invocation into deep-scan-stage.md Step 10.5.3 (both starterkit-context.yaml and reuse-index.yaml); name reuse-index.yaml in the gate prose.

### Batch 3D — Deep-scan cache correctness (3 Medium, 1 Low)
Theme: per-slice cache signatures and invalidation. Fixes in `deep-scan-stage.md`, `compute-lock-digests.sh`, `starterkit-context-schema.md`.
- **DS-1**: fold a per-domain source component (pack file-hint dirs listing+mtimes) + detector version into slice signatures.
- **DS-2**: `stale_slices ∪= prior.partial_slices`; omit per_slice entries for failed domains; correct the `--force-deep` remediation to `--no-cache`.
- **ECO-3**: dotnet CANDIDATES + enum + manifest_facts `dotnet:` block.
- **DS-6**: schema 4→5 slices, reuse per_slice entry, matrix row.

### Batch 3E — Incremental/sync lane correctness (2 Medium, 3 Low)
Theme: the `--changed-only` lane's fallback conditions and stamp hygiene. Fixes in `scan-procedure.md` + wording in SKILL.md/halts-flags-handoff.md/sync.md.
- **SP-3**: full-scan whenever the git delta channel is unavailable, regardless of journal state.
- **SP-7**: per-language grammar smoke test with engine downgrade + `grammars_used`.
- **SP-4**: `--verify HEAD^{commit}` stamp guard; treat "HEAD" as missing.
- **SP-8**: "truncate" → "consume (rotate-and-delete)" in three surfaces.
- **SP-6**: fix/drop the RG_OPTS block. **SP-9**: complete the `--shallow-scan` catalog entry.

### Batch 3F — Contract & prose-truth alignment (4 Medium, 6 Low)
Theme: docs claiming mechanisms/fields/numbers that don't exist, and cross-doc contradictions. Pure doc edits; no behavior change except the INT-3 conditional.
- **INT-3**: CWD-conditional (+ Mode D detect-drift branch) into the operative handoff YAML; align SKILL.md.
- **SC3-V4**: fix §3/§4 inversion in implementation-state.md, oq-resolution.md, tree-sitter-integration.md + cross-doc assertion.
- **SC3-V3**: honest rewording of "enforced at dispatch" (or promote extractors to plugin agents — larger; defer decision).
- **SC3-AH-3**: `truncated_sections` marker + UNKNOWN mapping + delete/implement the scan-log pointer.
- **SC3-AH-4**: pick one `_source` grammar for libs across four surfaces.
- **DS-5**: delete the re-tokenization/30-50% claims (or implement); resolve `source_files_sha256_map`.
- **DS-3** repoint §file-lock; **DS-7** fix `<FILE_HINTS>`; **DS-8** enum-domain trigger; **DS-4** add the untrusted-data rail; **INT-4** list artifacts / declare-or-delete `reuse_index`; **INT-6** fix symbol-graph attribution (incl. paths.md owner).

---

## 4. Rejected-findings appendix

| Rejected finding | Refutation |
|---|---|
| "Schema-validation drops slices" claims a validator that exists nowhere [validator-drift] | Mechanism is not nonexistent: starterkit-context-schema.md Anti-halu rail 3 explicitly documents consolidator self-validation against the schema before write — the claimed ghost is a documented LLM-executed check, consistent with the enforcement doctrine's rules tier. |
| Memory-layer re-verify promise unimplemented, contradicted by learning-rules [anti-halu-secrets] | "No re-verify procedure exists" is false — halts-flags-handoff.md:150 IS the procedure ("SKIP re-detection … confirm signal still present"), backed by rails :155-156 (detector-version change forces full re-detect). |
| `--no-default-excludes` silently re-ingests `.mega-sdd/**`, defeating the confirmation-bias rail [anti-halu-secrets] | Quoted lines exist, but the central attack scenario ("including one dep dir silently re-ingests vault intent") is refuted by the documented flag semantics. |
| Step 10a chat warning cites "source file:line rows" the report doesn't contain [anti-halu-secrets] | Quotes accurate (report is artifact-relative), but the instruction targets an agent that just assembled the artifact and holds the mapping in context — not a defect. |

---

## 5. Coverage disclosure

- **Lenses run (6):** validator-drift, tech-agnosticism, procedure-correctness, integration-contract, anti-halu-secrets, deep-scan. Findings from every lens survived verification; no lens produced zero output.
- **Dead lenses after rerun:** none.
- **Unverified findings (verifier died):** none — all 34 confirmed findings carry a completed high-confidence verdict; nothing is marked UNCERTAIN.
- **Not reviewed in this pass:**
  - Semantic correctness of the 9 `queries/tags-*.scm` capture files against their pinned grammars (only their existence, listing, and pinning were checked — SC3-V8/SP-7 touch the metadata, not query semantics).
  - Live end-to-end execution of a real scan (all empirical reproductions were script/fixture-level in scratchpad; no full `/mega-sdd:scan-codebase` run on a production repo).
  - Sibling skills beyond their scan-facing contract seams (bind-codebase/generate-units/orchestrate-flow internals were read only where scan artifacts flow in; extract-intelligence only as a convention contrast point).
  - Windows (`run-hook.sh`) dispatch behavior of the scan-related hooks.
  - The framework-conventions packs' content accuracy (only their existence/routing was load-bearing for ECO-1/ECO-3).
