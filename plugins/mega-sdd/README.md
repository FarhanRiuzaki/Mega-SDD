# mega-sdd

Spec-driven AI development pipeline for [Claude Code](https://claude.com/claude-code). PRD or idea → vault → atomic units → tested commits with anti-hallucination at every handoff.

**Version:** 3.44.0 · **License:** MIT

> 📖 Full documentation + user-facing scenarios at the repo root. See [`../../README.md`](../../README.md) + [`../../tests/scenarios/`](../../tests/scenarios/).

## Quick start

```bash
# Install
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended

# Optional native binaries (precision boost):
brew install tree-sitter ast-grep ripgrep jd
# OR
cargo install tree-sitter-cli ast-grep ripgrep
go install github.com/josephburnett/jd@latest

# Then in any project:
/mega-sdd:auto ./prd.md
```

That's it. Full install matrix: [`references/tooling-install.md`](./references/tooling-install.md).

## First-time user? Start with a scenario

| Scenario | When | Time |
|---|---|---|
| [Greenfield from idea](../../tests/scenarios/scenario-1-greenfield-from-idea.md) | Brand new; minimum viable demo | 15 min |
| [PRD-driven feature](../../tests/scenarios/scenario-2-prd-driven-feature.md) | Have PRD; existing project | 30 min |
| [Field-level extension](../../tests/scenarios/scenario-3-field-extension.md) | Add field to existing model | 20 min |
| [Legacy rebuild](../../tests/scenarios/scenario-4-legacy-rebuild.md) | Legacy → new framework | 4 hours |
| [Multi-squad parallel](../../tests/scenarios/scenario-5-multi-squad-parallel.md) | Multi-team coordination | 45 min |
| [Recovery from halt](../../tests/scenarios/scenario-6-recovery-from-halt.md) | Bolt halted; need to recover | 15 min |

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest (v3.44.0)
├── skills/                       # 15 skills + _vendored/
│   ├── using-mega-sdd/           # anchor skill (auto-injected) (v1.3.4)
│   ├── memory/                   # memory + self-learning (v1.3.1)
│   ├── emit-agents-md/           # AGENTS.md flatten (v1.2.5)
│   ├── emit-fsd/                 # Confluence FSD generator (v1.0.0) — Iter 54
│   ├── install-deps/             # OS-aware dep installer (v1.0.0) — NEW Iter 55
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.7.0)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.15.1)
│   ├── scan-codebase/            # tree-sitter AST scan (v2.7.2)
│   ├── bind-codebase/            # validation gate + field diff (v1.10.3)
│   ├── generate-units/           # atomic decomposition (v2.7.1)
│   ├── execute-bolts/            # superpowers TDD bridge (v2.10.0)
│   ├── orchestrate-flow/         # lifecycle router (v3.5.0)
│   ├── resolve-oq/               # OQ resolver + recommendations (v0.9.3)
│   ├── detect-drift/             # code vs vault (v1.4.1)
│   ├── diff-vault/               # PRD revision + jd patches (v1.3.2)
│   └── _vendored/                # superpowers fallback
├── commands/                     # 22 slash commands (1 primary + 21 advanced)
│   ├── auto.md                   # ⭐ THE command
│   ├── generate-intent.md, scan-codebase.md, bind-codebase.md, generate-units.md, execute-bolts.md
│   ├── extract-intelligence.md, orchestrate-flow.md, resolve-oq.md, diff-vault.md, detect-drift.md
│   ├── memory.md, emit-agents-md.md, emit-fsd.md, install-deps.md, replay.md
│   ├── lint-units.md, analyze-parallelism.md, list-modules.md    # [auto-invoked by /mega-sdd:auto]
│   ├── migrate-rules.md, migrate-paths.md                         # one-off maintenance
│   └── update-plugin.md
├── references/
│   ├── paths.md                  # canonical folder layout (Iter 10)
│   └── tooling-install.md        # optional native binaries install matrix (Iter 14)
├── hooks/                        # SessionStart hook
├── scripts/                      # sync-superpowers + memory-migrations/
├── CLAUDE.md                     # AI-agent contributor guidelines
└── LICENSE
```

## Pipeline (one-line)

```
[legacy → extract-intelligence] → brief/PRD → generate-intent → (scan + bind for brownfield) → generate-units → execute-bolts → emit-agents-md → emit-fsd
```

Wrapped by `/mega-sdd:auto` for autonomous end-to-end execution with single upfront confirmation. Diagnostics (lint, analyze, modules, emit) AUTO-INVOKED at appropriate phases per Iter 13 consolidation. Halt-protocol preserved across all iters.

## What's new

### v3.38.0 (Iter 55, minor) — OS-Aware Auto-Install Deps (new skill `install-deps`)

User-driven feature after Iter 54: dependency install friction. Iter 54 shipped emit-fsd which needs pandoc + tectonic for PDF rendering — but installing these (plus tree-sitter, ast-grep, ripgrep, jd) was manual per-OS work. Iter 55 adds dedicated installer skill that detects OS + package manager + auto-installs with safety rails.

**New skill `mega-sdd:install-deps` (v1.0.0):**

- Detects OS: macOS / Ubuntu / Debian / Fedora / RHEL / Arch / Alpine / WSL / Windows-bash
- Detects package manager: brew / apt / dnf / pacman / apk / winget / scoop / choco + cross-platform fallbacks (cargo / npm / go)
- Audits 8 tools per `tool-matrix.yaml`: tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh
- 6-step procedure: detect env → audit inventory → build install plan → propose+confirm (AskUserQuestion) → execute via Bash → verify post-install → memory write
- Safety rails (non-negotiable):
  - **NEVER auto-`sudo`** — sudo-required tools (apt/dnf) get printed with instruction "run manually"; memory records as "sudo-pending"
  - **NEVER curl|bash patterns** — only signed package manager commands per matrix
  - **ALWAYS show exact `install_cmd` + source + size BEFORE running** — single batch confirmation
  - **ALWAYS verify post-install** with `verify_cmd` — claim "installed" only after verify passes
- Memory-cached outcomes at `<project>/.mega-sdd/memory/install-outcomes.md` — skip re-audit of already-installed tools on next session (Iter 5 memory layer pattern); `--force-recheck` ignores cache

**Trigger:** standalone `/mega-sdd:install-deps [flags]` (no auto-invocation per safety consensus — install is user-explicit). Flags: `--dry-run`, `--tools=<csv>`, `--force-recheck`, `--pkg-mgr=<name>`, `--manual`, `--auto`.

**2 new halt types** (added to `vault-contract.md §halt-protocol type enum`):
- `install_failed` — install ran but verify_cmd failed OR install_cmd exited non-zero
- `pkg_mgr_not_found` — no compatible pkg manager detected for OS

**Predictive-checks hint update:** 3 existing tool-presence checks (`tree_sitter_present`, `pandoc_installed`, `pandoc_latex_engine_present`) get suffix `"...OR run /mega-sdd:install-deps for auto-install (Iter 55+)."` — no behavior change, just better discoverability.

**Reuse-first:** emit-fsd skill anatomy (analog template); Iter 33 predictive-checks pattern (hint extension); Iter 5 memory layer (install-outcomes.md); existing `tooling-install.md` matrix promoted to YAML + extended with pandoc/tectonic (Iter 54 deps).

**Also closed Iter 54 drift:** `emit-fsd` was added as a skill in Iter 54 but never added to the `source_skill` enum in vault-contract.md. Iter 55 commit added both `emit-fsd` and `install-deps` to the enum.

**Files created (3):**
- `plugins/mega-sdd/skills/install-deps/SKILL.md` (~190 lines)
- `plugins/mega-sdd/skills/install-deps/references/os-detection.md` (canonical Bash detection algorithm)
- `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml` (8-tool × OS × pkg_mgr matrix)
- `plugins/mega-sdd/commands/install-deps.md` (slash command wrapper)

**Files modified (5):**
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — 3 hint suffixes appended
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — 2 new halt types in §halt-protocol enum + descriptions; emit-fsd + install-deps added to source_skill enum (Iter 54 drift closure)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.37.0 → 3.38.0
- `CHANGELOG.md` — this entry
- `plugins/mega-sdd/README.md` + `README.md` — version refs + skill listing + cheat-sheet

**Plugin v3.37.0 → v3.38.0** (MINOR — new skill; backward-compatible; install is user-explicit so no impact on existing auto-pipeline runs).

### v3.37.0 (Iter 54, minor) — FSD Auto-Generation (new skill `emit-fsd`)

User-driven feature after real-project field test. Corporate Confluence FSD is mandatory deliverable; previously generated manually outside mega-sdd. Iter 54 adds dedicated FSD emitter skill grounded on actual vault/units/bolts/binding state with anti-hallucination citation discipline.

**New skill `mega-sdd:emit-fsd` (v1.0.0):**

- Generates Hybrid Confluence-format FSD (Markdown + PDF via pandoc + xelatex/tectonic)
- 10 canonical sections (Overview, Goals, Stakeholders, User Stories, FRs, NFRs, Design, API/Data, UAT, Risks)
- Mode auto-detect: pre-development (vault only) vs post-development (vault + bolts) from CWD state
- Anti-hallucination: every section text traces to source artifact via `.citation-map.json` (sha256-stamped); missing sources emit `[Pending — X not yet generated]` placeholder, NEVER fabricate
- Drift detection: re-emit on changed sources inserts ⚠ "Updated since last emit" callout
- ID corporate styling defaults (A4, Arial 11pt, navy accent, classification stamp, draft watermark in pre-dev mode); per-project override via `<vault>/fsd/FSD.styling.yaml` (banking_indonesia / telco_indonesia presets included as commented examples)
- Predictive preflight checks added (3 in orchestrate-flow predictive-checks.md): `vault_present_for_fsd` (fatal), `pandoc_installed` (warn → markdown-only fallback), `pandoc_latex_engine_present` (warn → HTML fallback for browser print-to-PDF)

**Trigger:** standalone (`/mega-sdd:emit-fsd [vault]`) + auto-invoked at end of `/mega-sdd:auto` (skip via `--no-fsd`).

**Output:** `<vault>/fsd/FSD.pdf` (+ FSD.md, FSD.styling.yaml, .citation-map.json). User uploads PDF manually to Confluence per corporate workflow.

**orchestrate-flow extension (v3.4.0 → v3.5.0):** Step 6 auto-integrated diagnostics table +1 row for emit-fsd.

**Reuse-first:** emit-agents-md skill anatomy (analog pattern); Iter 33 predictive-checks pattern (3 new entries); Iter 13 auto-integrated diagnostics extension; citation discipline from binding.md (sha256 + line ranges); Iter 53 acceptance_test_concerns consumer (section 10 Risks aggregates bolt concerns).

**Plugin v3.36.0 → v3.37.0** (MINOR — new skill; backward-compatible: existing pipelines unchanged; skip flag works for users who don't want FSD).

### v3.36.0 (Iter 53, minor) — Consumer wiring closure: producer-only fields → end-to-end USED

Self-initiated post-audit closure pass. After Iter 38 audit (37 findings) closed in Iter 52, ran a fresh meta-audit asking: "is every artifact produced by each pipeline phase actually consumed downstream, or do we emit producer-only fields that no consumer reads?" Audit found 3 PARTIAL items (no full orphans, but documented behavior not wired into consumer body — same regression class as Iter 43 + Iter 48 + Iter 52 fix-forwards). Iter 53 wires all 3 consumers atomically.

**Wired (3 consumers):**

- **C1 — `binding_metadata.codebase_map_provenance`** (Iter 46 producer-only):
  - Producer: bind-codebase Step 1 writes `snapshot-verified | snapshot-stale | no-snapshot` to binding.md header.
  - Pre-Iter-53: no consumer read the field; documented as "downstream consumers can trust the codebase-map is current" but grep across generate-units/execute-bolts/orchestrate-flow found ZERO reads.
  - Consumer wired (Iter 53): orchestrate-flow Step 3 chain optimization reads the field. When `snapshot-verified` AND source files unchanged → REMOVES scan-codebase from the chain (the 30-50% savings number the Iter 46 wording promised). Logs skip with rationale.

- **C2 — `units_with_starterkit_*` metrics** (Iter 32 producer-only):
  - Producer: generate-units handoff emits `units_with_starterkit_anchors` + `units_with_starterkit_rules` counts.
  - Pre-Iter-53: no consumer cross-checked these metrics against upstream `starterkit-context.yaml` `partial:` flag. Pure observational telemetry.
  - Consumer wired (Iter 53): orchestrate-flow Step 6.b.ix new cross-metric consistency check. IF `units_with_starterkit_rules > 0` AND `starterkit_context.partial == true` → halt `quality_gate_failed` subtype `starterkit_metrics_inconsistent` (rules pulled from incomplete framework slice may cite missing conventions). Reuses existing `quality_gate_failed` halt — no new halt type.

- **C3 — `acceptance_test_concern:` self-assessment field** (Iter 47 producer-only):
  - Producer: bolt subagent writes the field in bolt-report.md self-assessment per Iter 47 D4-006 contract when implementation passes acceptance test but feels under-validated.
  - Pre-Iter-53: no execute-bolts post-flight scanned the field; no orchestrate-flow surface displayed it. The bolt subagent's signal had nowhere to go.
  - Consumer wired (Iter 53): execute-bolts new §Post-flight acceptance-test concern harvest scans every bolt-report.md, aggregates into handoff `metrics.acceptance_test_concerns: []`. orchestrate-flow Step 7 final summary surfaces count + unit list + actionable next-step (`/mega-sdd:generate-units --regenerate --adversarial-subagent --units=<list>`). Surfaced as warning (not blocker — concerns don't fail the chain, they invite re-validation).

**Audit method:** dispatched Explore subagent with explicit producer→consumer matrix mandate; manually verified all 3 PARTIAL findings via grep (zero false positives). Same validation discipline as the 3 fix-forward iters but applied PROACTIVELY (audit-then-wire) rather than REACTIVELY (ship-then-fix). Tactic worth repeating after every minor release.

**Surface changes:**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 3 chain optimization (+9 lines), Step 6.b.ix consistency check (+10 lines), Step 7 diagnostics summary surface line (+1 line); version 3.3.0 → 3.4.0
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — new §Post-flight acceptance-test concern harvest section (+15 lines); handoff metrics block gains `acceptance_test_concerns: []` field (+6 lines); version 2.9.1 → 2.10.0
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — line 41 wording cites orchestrate-flow Step 3 as consumer; version 1.10.2 → 1.10.3
- `plugins/mega-sdd/skills/generate-units/SKILL.md` — handoff metrics block gains consumer-wiring comment; version 2.7.0 → 2.7.1
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.35.1 → 3.36.0
- `CHANGELOG.md` — + v3.36.0 Iter 53 entry
- `README.md` (root) — version bump

**Skill bumps:**
- `orchestrate-flow` 3.3.0 → 3.4.0 (MINOR — new Step 3 sub-bullet + new validation sub-step + new summary surface line)
- `execute-bolts` 2.9.1 → 2.10.0 (MINOR — new post-flight scan section + handoff field)
- `bind-codebase` 1.10.2 → 1.10.3 (PATCH — wording correction citing now-wired consumer)
- `generate-units` 2.7.0 → 2.7.1 (PATCH — comment annotation citing now-wired consumer)

**Standing directives applied:**
- simplifikasi: 3 PARTIAL findings → 1 atomic iter (no per-finding iters); minimum new files (zero — all edits to existing skills); reuses existing halts (`quality_gate_failed`)
- flawless: producer + consumer ship same iter (no "defer to next" excuse); atomic commit
- reuse-first: extends Iter 33 predictive-checks/validation-gate patterns; reuses Iter 32 starterkit-context.yaml `partial:` field as consistency anchor; reuses Iter 47 bolt subagent self-assessment field; reuses Iter 46 binding_metadata write site

**Plugin v3.35.1 → v3.36.0** (MINOR — backward-compatible: new optimization paths skip work when conditions met but don't change behavior when conditions don't; new halt subtype reuses existing halt envelope).

**Pattern reinforced:** post-audit closure (Iter 38 audit) → meta-audit (Iter 53 producer→consumer) is now part of the cumulative-iter release discipline. Validation gate caught 4 release-blockers across 3 fix-forwards; proactive audit caught 3 PARTIAL findings BEFORE they became release-blockers.

### v3.35.1 (Iter 52, patch) — Fix-Forward #3: wire GLOSSARY_INDEX + resolve-oq lock note + vault-contract wording

Third validation gate caught 2 release-blockers — both same pattern as prior fix-forwards (Iter 43 + Iter 48): docs declaring behavior that wasn't actually wired into the consumer body.

**Fixed (critical):**

- **C1 (Iter 51 wiring gap):** `<GLOSSARY_INDEX>` placeholder was defined in a standalone section of `wave-dispatch-templates.md` but NOT injected into the actual Wave 2/3/4 dispatch prompts. Subagents at runtime wouldn't see the placeholder — same algorithm-doc-vs-prompt drift caught in Iter 48 fix-forward. Iter 52 wires the placeholder into the **Generic agent prompt structure** skeleton (which auto-applies to every wave dispatch). Wave 1 skipped (no glossary exists yet); Wave 5 skipped (main-thread, no subagent).

- **C2 (Iter 49 propagation gap):** `vault-contract.md §Concurrency contract` listed `resolve-oq` as the 4th vault.json writer but no inline lock acquisition note in `resolve-oq/SKILL.md` Step 2c step 9 (the 3 vault.json regen sites: Resolve / Out-of-Scope / Defer outcomes). Plus `vault-contract.md` parenthetical claimed resolve-oq was "already file-lock-disciplined via memory subsystem" — incorrect; Iter 5's pattern was MEMORY only. Iter 52 adds explicit lock note + corrects parenthetical.

**Skill bumps:**
- `resolve-oq` 0.9.2 → 0.9.3 (PATCH — explicit lock acquisition note in Step 2c step 9)

**Plugin v3.35.0 → v3.35.1** (PATCH — fix-forward; pure correctness).

**Audit closure status:** with Iter 52, all 13 closure iters (39-51) plus 3 fix-forwards (43, 48, 52) are clean. Iter 38 audit's 37 findings are CLOSED. Validation pattern (advisor + code-reviewer + fix-forward) caught 4 release-blockers across the session — pattern is now load-bearing for cumulative-iter work.

### v3.35.0 (Iter 51, minor) — Glossary Anchoring + Reference Offset Hints + Parallelism Tuning (Queue #10 — final queue closure)

Closes Iter 38 audit Queue #10 (D1-004 + D1-007 + D2-001) — 3 editorial optimizations to extract-intelligence wave-based extraction. **Queue #10 was the FINAL audit queue item** — Iter 38's entire 10-iter optimization queue is now closed (Iters 39-51).

**Change 1 (D1-004): Glossary pre-parse — `<GLOSSARY_INDEX>` placeholder**

Wave-2/3/4 subagents previously each re-read full glossary.md (80-120 KB). Iter 51 main thread parses glossary ONCE between Wave 1 and Wave 2, builds compact `glossary_index` (term → 1-line definition + line range), injects as `<GLOSSARY_INDEX>` placeholder in each wave subagent prompt. Subagents instructed to use the index for cross-references; only spot-read glossary.md (with `offset`/`limit`) when full prose context needed.

**Net savings:** ~96 KB redundant I/O per wave (15% of 535K wave token budget). 4 subagents × 3 waves = 12 subagent reads saved per extraction.

**Change 2 (D1-007): Reference offset hints**

All wave outputs cite references with line range hints: `<file>.md §<section>:line-X-Y` instead of bare `<file>.md §<section>`. Downstream consumers use the range with Read tool's `offset`/`limit` for targeted reads. Best-effort optimization — bare citation form still accepted as fallback.

**Net savings:** 30-60% I/O reduction per reference read when consumers spot-read.

**Change 3 (D2-001): Parallelism tuning — extract-intelligence `--max-parallel` default 5 → 3**

Per Zylos 2026 empirical optimum (3 parallel agents per turn is sweet spot; beyond 3 coordination overhead exceeds gain). Soft warn at >5 (existing predictive-checks.md `subagent_capacity_reasonable` aligns); hard cap remains 8.

**Net effect:** lower-default extractions use fewer tokens, less coordination time, often higher quality outputs (less context dilution per subagent).

**External research applied:** Zylos 2026 parallel agent optimization research.

**Skill bumps:**
- `extract-intelligence` 1.6.0 → 1.7.0 (MINOR — new default + new placeholder + reference offset hints convention)

**Plugin v3.34.0 → v3.35.0** (MINOR — extract-intelligence default behavior change).

**Audit completion status:** Queue #1-#10 all closed (Iters 40-51). Plus 5 immediate wins (Iter 39). Plus 2 fix-forward iters caught defects via validation gate (Iter 43, Iter 48). **13 iters total closing Iter 38 audit's 37 findings.** Most findings: closed. A few P2/Advisory items remain low-priority; may surface in future audit.

### v3.34.0 (Iter 50, minor) — Predictive Checks Coverage Expansion (Queue #9)

Closes Iter 38 audit Queue #9 (pattern E — predictive-checks.md coverage asymmetric). Extended preflight check catalog from 4 skills to 10. Closes 6 coverage gaps.

**Before:** predictive-checks.md covered scan-codebase / bind-codebase / execute-bolts / generate-intent (4 of 9 user-invocable skills). Missing: detect-drift, diff-vault, resolve-oq, extract-intelligence, emit-agents-md, memory.

**After:** all 10 user-invocable skills have ≥1 preflight check. Total checks: 8 (pre-Iter-50) → 26 (Iter 50).

**New per-skill checks (18 added):**

- **detect-drift (3):** `vault_present_for_drift` (chain order), `binding_present_for_drift` (chain order — no binding = no anchor points), `clean_working_tree_for_drift` (warn — uncommitted conflates with drift)
- **diff-vault (3):** `current_vault_present_for_diff` (chain order), `new_source_resolves_for_diff` (predicts `prd_path_missing`), `vault_version_parseable` (predicts `invalid_handoff`)
- **resolve-oq (3):** `vault_present_for_oq` (chain order), `oq_status_field_present` (warn — pre-v1.1 schema lacks status tracking), `unresolved_oqs_exist` (no-op warning)
- **extract-intelligence (3):** `legacy_codebase_path_present` (predicts `dep_missing`), `kb_target_writable` (predicts `dep_missing`), `subagent_capacity_reasonable` (warn — Iter 38 D2-001 max-parallel ≤ 5 per Zylos 2026 empirical optimum)
- **emit-agents-md (2):** `vault_present_for_agents_md` (chain order), `units_present_for_agents_md` (warn — degraded AGENTS.md without units)
- **memory (3):** `memory_dir_writable` (predicts `memory_in_use`), `schema_version_match` (predicts `memory_schema_mismatch`), `concurrent_writer_check` (warn — stale lock detection)

Per Iter 49 pattern: checks use Iter 5 memory file-lock detection + Iter 41 canonical halt names + reuse `predictive_check_failed` halt envelope (no new halt type).

**Skill bumps:**
- `orchestrate-flow` 3.2.1 → 3.3.0 (MINOR — predictive-checks consumer now covers 10 skills instead of 4)

**Plugin v3.33.0 → v3.34.0** (MINOR — coverage expansion is behavioral change for orchestrate-flow Step 3.5).

**Spec:** inline in CHANGELOG (per simplifikasi — pure docs/catalog iter; no new file needed).

### v3.33.0 (Iter 49, minor) — vault.json Advisory Lock + Scenario-6 Halt Walkthroughs

Closes Iter 38 audit Queue #8 (D3-012 vault.json concurrent-write safety + D3-006 scenario-6 recovery coverage). All vault.json writers now use Iter 5 file-lock pattern; scenario-6 expanded from 3 walkthroughs to 13.

**Change 1 (D3-012): vault.json advisory lock**

All 4 vault.json writers (`generate-intent` Step 11, `bind-codebase` Step 6, `diff-vault` Step 8, `resolve-oq` regen) acquire exclusive lock on `<vault>/vault.json.lock` per the Iter 5 memory file-lock pattern. Backoff + retry 3x; fail with `memory_in_use` halt (reused — no new halt type per reuse-first). detect-drift NEVER writes (preserved).

Canonical contract documented in `vault-contract.md §Concurrency contract` (new section). Halt envelope reuses `memory_in_use` with vault-specific details (`file`, `lock_path`, `attempts`, `lock_holder_pid`).

**Change 2 (D3-006): scenario-6 expansion (3 → 13 walkthroughs)**

Added 10 high-frequency halt walkthroughs to `tests/scenarios/scenario-6-recovery-from-halt.md`:
- `handoff_missing` (Iter 40 + 43 fix-forward) — with chat_tail_excerpt diagnosis
- `artifact_missing` (Iter 40) — re-run producer guidance
- `partial_state_corrupt` + saga rollback (Iter 40 + 45) — both forensics restart + --rollback recovery paths
- `oq_blocker` — resolve-oq interactive walk + tech-OQ auto-resolve path
- `diff_conflict` (Iter 3) — 3-option resolution
- `dispatch_prompt_too_large` (Iter 30 + 44) — constitution-clause splitting guidance
- `provenance_missing` (Iter 30) — trailer + amend recovery
- `bind_conflict_constitution_violation` (Iter 20) — review-or-fix protocol
- `cross_squad_dep_invalid` (Iter 25) — 3-path resolution (producer lock / wait + converge / fix ref)
- `memory_schema_mismatch` (Iter 5) — migrate vs --memory-off paths

Each walkthrough includes trigger, example envelope, recovery options, cross-refs. Brings scenario-6 from 365 LOC to ~800 LOC.

**Skill bumps:**
- `generate-intent` 1.15.0 → 1.15.1 (PATCH — lock acquisition)
- `bind-codebase` 1.10.1 → 1.10.2 (PATCH — lock acquisition)
- `diff-vault` 1.3.1 → 1.3.2 (PATCH — lock acquisition)

**Plugin v3.32.1 → v3.33.0** (MINOR — concurrent-write contract is new behavior; pre-Iter-49 chains that depended on silent racing now halt explicitly).

**Spec:** `docs/superpowers/specs/2026-05-25-iter-49-vault-lock-and-scenario-expansion-design.md`

### v3.32.1 (Iter 48, patch) — Fix-Forward: Iter 44 algorithm rewrite, Iter 46 step relocation, Iter 46 wording correction

Code-quality review (`superpowers:code-reviewer` subagent on commits 3d11c09..HEAD covering Iters 44-47) surfaced 2 CRITICAL defects + 1 MEDIUM. Iter 48 fixes them all before next feature iter.

**Fixed (critical):**

- **C1 — Iter 44 algorithm drift:** `bolt-dispatch-prompt.md §Tier-loading algorithm` still encoded the pre-Iter-44 single-halt pseudocode (`if size(prompt) > 10_000: halt`). LLM following the canonical algorithm would execute the OLD behavior, contradicting SKILL.md's running-budget tracker design. Rewritten with running-budget pseudocode + per-section priority loop + truncation cascade. v1.0 (Iter 30) algorithm preserved at bottom as historical reference. Header bumped to v2.0 (Iter 44 semantics).

- **C2 — Iter 46 step misplacement:** scan-codebase Step 9.5 (per-file invalidation) was placed AFTER Step 5 symbol extraction had already run — too late to short-circuit. Also caused a double-write (Step 9.5 wrote codebase-map.md, then Step 10 overwrote it). Iter 48 relocates the gate to BEFORE Step 5 tree-sitter/regex extraction so it actually short-circuits expensive per-file invocations. Step 9.5 location now holds a brief breadcrumb pointing to the relocated gate.

**Fixed (medium):**

- **M1 — Iter 46 bind-codebase reuse hook wording:** the Iter 46 description claimed "skip per-source-file re-tokenization (~30-50% I/O saving)" but bind-codebase Step 2 has never re-tokenized — it consumes pre-extracted §2 entries. The actual benefit is a **freshness attestation** that orchestrate-flow + downstream skills can trust without re-running scan-codebase. Reworded: bind-codebase now records `binding_metadata.codebase_map_provenance` (`snapshot-verified` / `snapshot-stale` / `no-snapshot`) in binding.md header. The 30-50% savings applies at chain level (avoid scan re-run), not within bind-codebase.

**Skill bumps:**
- `scan-codebase` 2.7.1 → 2.7.2 (PATCH — Step 5 gate relocation)
- `bind-codebase` 1.10.0 → 1.10.1 (PATCH — wording correction)

**Validation pattern reinforced:** for the second time in this audit-closure cycle, `superpowers:code-reviewer` validation gate caught release-blockers BEFORE they affected production. The pattern (advisor checkpoint + code-reviewer dispatch + fix-forward iter before next feature) is now standard for cumulative-iter sessions.

**Plugin v3.32.0 → v3.32.1** (PATCH — fix-forward).

### v3.32.0 (Iter 47, minor) — Independent Acceptance-Test Authoring (Adversarial Review Pass)

Closes Iter 38 audit Queue #7 (D4-006 — HIGH structural risk; pattern F). Per ACM FSE 2025: "Never trust AI to both generate and validate." Adds adversarial second-pass review to acceptance_test authoring so blind spots in the unit body don't silently propagate to the test that validates it.

**Problem:** every unit's `acceptance_test` was authored by the SAME LLM pass that wrote the unit body. If the LLM misunderstood the requirement, both unit + test were wrong in the same direction. Bolt runs test → green checkmark → user trusts it → broken code ships.

**Solution:**

1. **Adversarial review pass — generate-units Step 9.5 (NEW)** runs AFTER Step 9 acceptance_test authoring. Default: main thread self-re-prompts in adversarial mode ("you're a QA engineer; find at least 2 cases this test fails to catch"). Opt-in: dispatch separate subagent via `--adversarial-subagent` flag for stronger blind-spot coverage.

2. **`_authored_by:` provenance field (NEW)** on `acceptance_test`. Values: `same-pass` (weakest, pre-Iter-47) / `adversarial-reviewed (no gaps)` / `adversarial-reviewed (+N gaps merged)` / `adversarial-review-failed` (weak + warning) / `independent-llm` / `human` (strongest).

3. **Gap merge logic** — adversarial reviewer returns YAML `adversarial_review:` block with `gaps_identified[]` + `coverage_verdict`. Main thread merges proposed assertions into the acceptance_test; provenance updated to reflect outcome.

4. **execute-bolts surface (NEW NOTE)** — when bolt dispatches a unit with `_authored_by: same-pass` OR `adversarial-review-failed`, dispatch prompt gets a NOTE warning the bolt subagent that the test may have blind spots. Bolt instructed to flag `acceptance_test_concern: <details>` in self-assessment if implementation passes test but feels under-validated.

5. **`--regenerate` preserves `_authored_by: human`** — user-edited tests are NEVER overwritten by regeneration.

**New file:** `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` (canonical prompt template + merge logic + provenance values table).

**Skill bumps:**
- `generate-units` 2.6.0 → 2.7.0 (MINOR — new Step + new flags + new frontmatter field)
- `execute-bolts` 2.9.0 → 2.9.1 (PATCH — detection + NOTE injection)

**Backward compat:** pre-Iter-47 units (no `_authored_by:` field) treated as `same-pass` — execute-bolts NOTE fires + `generate-units --regenerate` rewrites them with adversarial review. Zero breaking changes.

**External research applied:** PBT for LLM-Generated Code (ACM FSE 2025) + Multicalibration for LLM Code Generation + Stanford AI Index 2026 — Hallucination Engineering.

**Plugin v3.31.0 → v3.32.0** (MINOR).

**Spec:** `docs/superpowers/specs/2026-05-25-iter-47-independent-acceptance-test-authoring-design.md`

### v3.31.0 (Iter 46, minor) — Shared-Snapshot Reuse Extension + Per-File Symbol Invalidation

Closes Iter 38 audit Queue #6 (D1-006 + D2-007 — pattern C cache invalidation). Extends Iter 30 shared-snapshot reuse pattern from 1 hop (execute-bolts ↔ detect-drift) to 3 hops + adds per-file symbol cache for shallow-scans.

**Change 1 (D1-006): shared-snapshot scope extension to 2 new hops**

- **scan → bind hop:** `scan-codebase` Step 10.6 (NEW) emits `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` with `codebase_map_sha256` + `source_files_sha256_map`. `bind-codebase` Step 1 (extended) reuses parsed §2 symbols when snapshot fresh → 30-50% I/O saving on iterative dev cycles.
- **extract → intent hop:** `extract-intelligence` Step 5.5 (NEW) emits `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json`. `generate-intent --kb` (Mode B preflight, v1.15+) verifies source files unchanged since extraction; warns advisory if drift (does NOT halt — user retains agency).

**Change 2 (D2-007): per-file symbol invalidation for `--shallow-scan`**

- `codebase-map.md §2 Public interfaces` gains `Last_Scanned_Sha256` column
- `scan-codebase --shallow-scan` (v2.7.1+) does per-file invalidation in Step 9.5 (NEW): files with unchanged sha256 → reuse prior §2 entries; only changed files re-tokenized via tree-sitter
- **Savings:** shallow re-scan goes from 5-10s → <1s on iterative dev (most files unchanged)

**Shared-snapshot-schema.md bumped v1.0 → v1.1:**
- `snapshot_type` enum + 2 values: `codebase-map`, `extracted-kb`
- `codebase_map_sha256` + `source_files_sha256_map` OPTIONAL fields
- New producer responsibilities + consumer responsibilities sections per skill

**Skill bumps:**
- `scan-codebase` 2.7.0 → 2.7.1 (PATCH — additive)
- `bind-codebase` 1.9.4 → 1.10.0 (MINOR — new reuse path)
- `extract-intelligence` 1.5.0 → 1.6.0 (MINOR — new snapshot emission step)
- `generate-intent` 1.14.0 → 1.15.0 (MINOR — new freshness check preflight)

**Backward compat:** all snapshot fields OPTIONAL; v1.0 readers gracefully degrade (no snapshot → behave as today). Zero breaking changes.

**Plugin v3.30.0 → v3.31.0** (MINOR).

**Spec:** `docs/superpowers/specs/2026-05-25-iter-46-snapshot-reuse-extension-design.md`

### v3.30.0 (Iter 45, minor) — Saga Compensating Actions (`--rollback` flag + partial-state v2.0)

Closes Iter 38 audit Pattern D (D3-009 + D3-003) — replaces forward-only resume with saga-pattern compensating actions. Crashed bolts can now be cleanly rolled back instead of compounding partial writes.

**Problem:** mega-sdd used forward-only resume. On `--resume`, execute-bolts retried the failing step but couldn't undo non-idempotent prior steps (composer dep adds, migrations, external API calls). Partial writes compounded on subsequent runs.

**Solution:**

1. **partial-state.json schema bump v1.0 → v2.0** — adds `rollback_hints[]` array. Each entry: `{step_id, step_type, evidence, compensating_action, idempotent, applied_at}`.

2. **Canonical step_type taxonomy (14 types)** — `file_created` / `file_modified` / `file_partially_written` / `composer_dep_added` / `migration_executed` / `external_api_call` / etc. Each maps to a default compensating action template + idempotency flag.

3. **`--rollback <unit-id>` flag (NEW)** — reads partial-state.json v2.0 + applies `rollback_hints[]` in reverse order with per-action confirmation. Non-idempotent actions get safe-default confirmation. Applied actions stamp `applied_at:` so partial rollback can be resumed.

4. **Bolt subagent contract** — bolt-dispatch-prompt.md gets new `## Rollback hints` self-assessment section. Bolt subagent appends hint per significant step during execution. On crash: execute-bolts harvests hints into partial-state.json.

5. **Backward compat** — v1.0 partial-state.json (Iter 30 baseline) → `--rollback` errors gracefully ("no rollback hints; manual review via `git status` + `git diff HEAD`"). `--resume` still works.

**Reused halt:** malformed `rollback_hints[]` entries trigger existing `partial_state_corrupt` halt (Iter 40) with `malformed_hints:` detail. No new halt type.

**External research cited:** Saga Pattern (microservices.io) + Compensating Transactions (Microsoft Azure).

**Skill bumps:**
- `execute-bolts` 2.8.0 → 2.9.0 (MINOR — schema bump + new flag + new self-assessment section)

**Plugin v3.29.0 → v3.30.0** (MINOR — schema bump + new flag).

**Spec:** `docs/superpowers/specs/2026-05-25-iter-45-saga-compensating-actions-design.md`

### v3.29.0 (Iter 44, minor) — T2 Running Budget Tracker + Progressive Truncation

Closes Iter 38 audit Queue #4 (D1-003) — replaces aspirational 5KB T2 soft cap + single 10KB halt with running byte tracker + progressive section-level truncation cascade. Every bolt dispatch benefits.

**Problem (audit D1-003):** T2 5KB soft cap was documented but never enforced. The only enforcement was the 10KB hard cap (halt-or-pass binary). Complex units silently exceeded T2 budget, ballooning context until they tripped the hard cap. Audit estimate: 15-30% T2 size reduction for complex units once progressive truncation enforced.

**Solution:**

1. **Running budget tracker** (NEW — Step 4.5.a.5) tracks `consumed_t2 / cap_t2 / remaining_t2` as each T2 section loads. Truncation triggered BEFORE next section overflows budget, not after.

2. **8-tier section priority for truncation** — sections ordered from MOST disposable (validation_hints / historical_memory / kb_anti_patterns) to MOST critical (constitution_clauses NEVER truncates). Each section has explicit truncation cascade with drop floor.

3. **Soft-budget warnings (NEW)** — exceeding 5KB target now logs a warning + applies truncation; only `dispatch_prompt_too_large` halt fires when constitution_clauses alone exceeds budget (true config issue).

4. **Truncation provenance to subagent** — bolt-dispatch-prompt.md gets new `### T2 budget tracker` section listing `truncations_applied`. Subagent instructed: "if your self-assessment references truncated information, mark confidence: MEDIUM and note the truncation."

**Skill bumps:**
- `execute-bolts` 2.7.3 → 2.8.0 (MINOR — new Step 4.5.a.5 + new bolt-dispatch-prompt section)

**Plugin v3.28.1 → v3.29.0** (MINOR — new optimization step + new self-assessment field).

**Spec:** `docs/superpowers/specs/2026-05-25-iter-44-t2-running-budget-tracker-design.md`

### v3.28.1 (Iter 43, patch) — Fix-Forward: handoff_missing semantics, schema doc, savings accuracy

**Release-blocker fix.** A code-quality review of Iters 39-42 surfaced a critical regression in Iter 40's `handoff_missing` halt (would fire on every auto run because the file-existence check pointed at a path no skill actually writes). Plus: starterkit-context-schema.md was left at v1.0 docs while scan-codebase v2.7.0 writes v2.0; Iter 42 CHANGELOG savings estimates were inverted/optimistic.

**Fixed (critical):**
- `handoff_missing` (orchestrate-flow v3.2.1+) semantics corrected: now scans sub-skill's **chat output** for an inline `handoff:` YAML block (per actual skill emission convention) instead of `test -f` on a hardcoded path. Halt envelope gains `chat_tail_excerpt: <last 500 chars>` field for diagnosis. Iter 40 production-correct again.
- `handoff-contract.md` Emission contract section added: documents that skills emit handoff YAML inline in chat (last assistant message). File-write to `<vault>/.internal/checkpoints/` is OPTIONAL (replay/audit); chat-block is the authoritative source.
- `starterkit-context-schema.md` bumped to v2.0 to match scan-codebase v2.7.0 producer. Adds `cache_signatures:` block + per-slice invalidation matrix table + legacy v1.0 backward-compat note.

**Fixed (medium):**
- `partial_state_corrupt` canonical path in vault-contract.md corrected: `<vault>/bolts/U-XXX/partial-state.json` (matches execute-bolts §Partial-state contract emit example).
- Iter 42 cache savings claims corrected: actual savings are 25% (PHP dep edit — composer.lock invalidates auth+rbac+libs), 50% (JS dep edit — package.lock invalidates ui_ux+libs), 75% (single lib-pattern file edit). Earlier CHANGELOG bullets were inverted/imprecise.

**Skill bumps:**
- `orchestrate-flow` 3.2.0 → 3.2.1 (semantics correction)

**Plugin v3.28.0 → v3.28.1** (PATCH — fix-forward audit closure stack).

### v3.28.0 (Iter 42, minor) — Deep-Scan Manifest Pre-Parse + Per-Slice Cache

Closes Iter 38 audit Queue #3 (D1-002 + D2-003) — eliminates redundant manifest reads + replaces whole-file cache invalidation with per-slice signatures. Every project pipeline benefits.

**Change 1 (D1-002): Manifest pre-parse** — `scan-codebase` Step 10.5.1.5 (NEW). Main thread parses `composer.json` + `package.json` ONCE, injects `manifest_facts` struct into all 4 deep-scan subagent prompts via `<MANIFEST_FACTS>` placeholder. Subagents instructed: "do NOT re-read manifest files; manifest_facts is authoritative."

- **Net savings:** ~9-24KB per scan (4 subagents × ~2-6KB saved per subagent context)
- **External research:** subagent-token pattern (Sathish Raju Medium) — "pass analytical outputs, not raw data"

**Change 2 (D2-003): Per-slice cache (schema v2.0)** — `scan-codebase` Step 10.5.1 + 10.5.3 reworked. Each of 4 slices (auth, rbac, ui_ux, libs) tracks its own `signature_sha256` (composed from slice-relevant inputs: lock file + framework_pack section + lib-pattern file). On scan:
  - Full cache hit (no slices stale) → reuse entire prior YAML
  - Partial cache hit (1-3 slices stale) → dispatch only stale subagents; consolidator merges fresh + cached
  - Full cache miss (all slices stale or no prior YAML) → dispatch all 4 (current behavior)

- **Net savings (incremental edits):** 1-3 subagent dispatches saved per minor edit (~25-75% wasted compute eliminated)
- **External research:** real-time codebase indexing (cocoindex-io) — "per-file invalidation via hash"
- **Backward compat:** v1.0 `cache_key:` schema treated as fully-stale (auto-migrates to v2.0 `cache_signatures:` on next write)

**Skill bumps:**
- `scan-codebase` 2.6.3 → 2.7.0 (MINOR — new Step 10.5.1.5 + cache schema bump)

**Spec:** `docs/superpowers/specs/2026-05-25-iter-42-deep-scan-manifest-preparse-and-per-slice-cache-design.md`

**Plugin v3.27.1 → v3.28.0** (MINOR — new optimization step + cache schema bump).

### v3.27.1 (Iter 41, patch) — Halt Taxonomy Sync Sweep

Reconciles the canonical halt registry (`vault-contract.md §halt-protocol`) with all halts actively emitted by skills and tracked by orchestrate-flow. Closes Iter 38 audit priority 2 (registry drift).

**Pre-sweep state:**
- Enum had 37 halt types
- Orchestrate-flow taxonomy referenced 39 halt types
- **9 halts emitted by skills + listed in orchestrate-flow were missing from canonical enum** (any consumer validating envelopes would reject them)
- 5 halts in enum were missing from orchestrate-flow taxonomy (orchestrator couldn't decide auto-loop vs ALWAYS-STOP behavior)

**Post-sweep state:**
- Enum: 46 halts (+9 reconciled)
- Description list: 37 bulleted entries (+9 with provenance: producer skill + iter + resolution)
- Orchestrate-flow taxonomy: 44 entries (+5 reconciled)

**Halts added to enum + description (9):**
`dedup_ambiguous` (generate-units), `hard_rule_unparseable` (generate-units), `hard_rule_violated` (execute-bolts), `memory_schema_mismatch` (memory), `prd_no_scopes_block_user_rejected_retrofit` (generate-intent, Iter 28), `prd_path_missing` (diff-vault, Iter 29), `prd_retrofit_low_confidence` (generate-intent, Iter 28), `quality_gate_failed` (extract-intelligence), `scope_not_declared_in_prd` (generate-intent, Iter 28).

**Halts added to orchestrate-flow ALWAYS-STOP taxonomy (5):**
`oq_blocker` (canonical envelope; coexists with orch-level alias `oq_business_p1_unresolved`), `cross_squad_ambiguous`, `cycle_detected`, `interface_ref_missing`, `pbt_citation_invalid` (Iter 39 oversight closure).

**No new skills, no new halts.** All halts already existed in code; sweep makes the registry match reality. Closes Iter 38 audit D3-006 (taxonomy sync).

**Plugin v3.27.0 → v3.27.1.**

### v3.27.0 (Iter 40, minor) — Silent-Failure Path Closure (3 new halts)

Closes 3 silent-failure paths surfaced by Iter 38 audit (priority 1, robustness D3). All 3 fire as ALWAYS-STOP halts at the exact failing boundary instead of leaking into cryptic downstream errors.

**New halts:**

- `handoff_missing` (orchestrate-flow v3.2.0+) — sub-skill exited without emitting handoff YAML at the expected path. Previously orchestrator either proceeded with empty state OR failed downstream with file-not-found; now halts at the boundary with `last_known_step` hint.
- `artifact_missing` (orchestrate-flow v3.2.0+) — handoff YAML lists `artifacts: [paths]` but one or more paths fail `test -f` / `test -d`. Previously next-stage consumer skill failed with cryptic file-not-found; now halts at producer boundary with explicit `missing_paths: [...]` list.
- `partial_state_corrupt` (execute-bolts v2.7.3+) — `--resume` mode found partial-state.json fails JSON parse. Previously silent overwrite with fresh state (hidden recovery loss); now halts with `corrupt_backup_path` suggestion for forensics.

**4-surface taxonomy sync (per Iter 33+Iter 31 propagation directive):**

- `vault-contract.md` enum + descriptions: 3 new entries
- `orchestrate-flow/SKILL.md` ALWAYS-STOP halt taxonomy: 3 new rows
- `orchestrate-flow/SKILL.md` Procedure: 2 new validation steps (`b.0` handoff presence, `b.vii` artifact existence)
- `handoff-contract.md`: documents orchestrator-side detection for both checks
- `execute-bolts/SKILL.md` §Partial-state contract: resume-time integrity check added

**Skill bumps:**
- `orchestrate-flow` 3.1.2 → 3.2.0 (MINOR — new procedure steps + new halts emitted)
- `execute-bolts` 2.7.2 → 2.7.3 (PATCH — new error path; same procedure)

**Why MINOR (not PATCH):** Chains that previously silently-passed corrupt/missing state now halt explicitly. Existing user workflows that depend on "silent recovery" behavior will see new halts. Documented as expected-behavior change.

**Plugin v3.26.3 → v3.27.0.** Spec: `docs/superpowers/specs/2026-05-25-iter-40-silent-failure-path-closure-design.md`.

### v3.26.3 (Iter 39, patch) — Quick Audit Closure Pass (5 immediate wins)

Closes 5 P1/HIGH findings from `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`. All atomic doc/contract fixes; no behavior changes.

**What changed:**

- **D4-001 layer count**: plugin README header `(13 layers)` → `(15 layers)` + added layer 14 (predictive preflight from Iter 33 F2) + layer 15 (handoff schema validation from Iter 33 F3+F4). Root README line 406 stale `13-layer pipeline defense above` → `15-layer pipeline defense above`.
- **D3-010 --max-cycles default**: SKILL.md was documenting `default 5` in 2 spots while `commands/orchestrate-flow.md` said `default 3`. Canonicalized to **3** (one canonical default) — matches user-facing slash command help.
- **D3-007 --force-skip-postflight**: undocumented escape hatch now formally surfaced in `execute-bolts/SKILL.md ## Inputs` with WARNING block citing anti-bypass policy (CLAUDE.md). Logged in handoff YAML via `notes.postflight_skipped: true`.
- **D3-004 pbt_citation_invalid halt**: added to `vault-contract.md §halt-protocol` enum + canonical description. Emitted by execute-bolts v2.4+ (Iter 20) when a PBT property `Cites: §Decision-D-NNN` references a non-existent ADR.

**Skill bumps:**
- `execute-bolts` 2.7.1 → 2.7.2 (+ `--force-skip-postflight` flag)
- `orchestrate-flow` 3.1.1 → 3.1.2 (canonical max-cycles=3)

**Why this matters:** Iter 38 audit surfaced 37 optimization findings across 4 dimensions (token / performance / robustness / output quality). These 5 are the immediate wins with <40min total time-to-ship. Higher-effort closures (priority 1: silent-failure path) land in Iter 40.

**Plugin v3.26.2 → v3.26.3** (PATCH — pure doc/contract fixes; no skill behavior changes).

### v3.26.2 (Iter 37, patch) — Scenarios Coverage + README Audit

mega-sdd now ships **scenarios for all user-facing features through Iter 35**, plus README audit for 1:1 accuracy with current state.

**What changed:**

- **NEW scenarios:** 
  - `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md` — phased legacy rebuild tutorial (Iter 35 phase discoverability)
  - `tests/scenarios/scenario-11-model-tier-override.md` — model tier override tutorial (Iter 34)
- **Scenarios chooser** (`tests/scenarios/README.md`) — now lists all 11 scenarios + upgrade-guide pointer
- **README audit** — fixed stale "13-layer anti-hallucination" header (now 15-layer per Iter 33 F3+F4 additions); fixed stale v3.18.1 reference; normalized "What's new" structure

**Why this matters:** field-test feedback — users coming to mega-sdd needed walkthroughs for the Iter 34/35 features. Now every iter has either a scenario OR a reference doc serving as tutorial.

**Plugin v3.26.1 → v3.26.2** (PATCH — pure documentation; no skill behavior changes).

### v3.26.1 (Iter 36, patch) — Upgrade-from-old-version guide

For users coming from older mega-sdd versions: see `plugins/mega-sdd/references/upgrade-from-old-version.md`. Consolidates compat matrix + migration commands + halt recovery + decision tree (Path A regenerate vs Path B preserve). Documentation-only patch; no behavior change.

### v3.26.0 (Iter 35) — Reading Map + Phase Discoverability

mega-sdd now tells you **where to look at each pipeline stage** + **what phase your vault represents**.

**What changed:**

- **NEW: `plugins/mega-sdd/references/reading-map.md`** — user-facing guide indexed by pipeline stage. "After stage X, look at file Y at location Z." ⭐ marks primary entry-point per stage.
- **Phase fields in `vault.json`** — `phase` + `phase_total`. Surfaces at top of `00-index.md §Phase context`: "Phase 1 of 3" + upcoming phases + next-phase command.
- **`generate-intent --phase=N` flag** — bootstrap Phase 2/3+ vaults from the same KB. Mode B with `--kb` parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for the plan.
- **End-of-chain hint** — execute-bolts + orchestrate-flow surface "Phase 1 complete. Phase 2 next: run `/mega-sdd:generate-intent --kb=<KB> --phase=2`" when applicable.

**Why this matters:**

Before: vault only contained Phase 1; user had to know `suggested-phasing.md` existed deep in the KB. Now: vault tells you the phase + how to get to next phase. No more "where's Phase 2?" friction.

**Audit closure:** all mega-sdd-generated files live under `.mega-sdd/` or `~/.mega-sdd/` (verified). AGENTS.md at repo root is INTENTIONAL (tool-interop standard). One stale doc line fixed in scan-codebase.

**Plugin v3.25.0 → v3.26.0.**

See [docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md](../../docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md) for full design.

### v3.25.0 (Iter 34) — Dynamic Model Selection

mega-sdd now picks the **best model per subagent dispatch** instead of inheriting the caller's model. Curated catalog maps 17 named subagent roles to tier (haiku / sonnet / opus) with explicit rationale per entry.

**What changed:**
- **Catalog at `plugins/mega-sdd/references/model-tiers.md`** — 17 roles + tier + rationale + selection rubric
- **orchestrate-flow Step 2.8** — resolves override chain (CLI flag > project config > user preference > catalog default); emits `metadata.model_tiers:` in handoff
- **3 opus + 12 sonnet + 2 haiku** distribution by design (sonnet-dominant)

**Why this matters:**
Before: every subagent dispatch silently inherited the main thread's model. Opus for everything (expensive) OR inconsistent (depending on caller). No way to express "this synthesis needs opus" vs "this probe scoring is fine on haiku".

After: catalog explicit. extract-intelligence wave-5 (holistic synthesis) → opus. intelligence-audit-probe (0-3 scoring) → haiku. Most fuzzy-classification work → sonnet. User can override any role at any level (CLI / project / user).

**Override examples:**
```bash
# CLI: cheap reviews this run
/mega-sdd:auto --model-tier=code-quality-reviewer:sonnet ./prd.md

# Project: team prefers cheaper synthesis
# <project>/.mega-sdd/config.yaml:
model_tiers:
  extract-intelligence-wave-5: sonnet
```

**Plugin v3.24.0 → v3.25.0.**

See [docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md](../../docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md) for full design.

### v3.24.0 (Iter 33) — Flawless Seamless Intelligence

**Combined mega-iter:** orchestrator becomes intelligent + handoffs become flawless.

**What changed:**

Smart orchestrator:
- **F1 Memory-driven routing** — orchestrator now learns from past runs. After ≥3 successful runs of the same project shape, orchestrator recommends the proven chain (overriding default routing-rules.md). Fall-through silently for fresh projects.
- **F2 Predictive halt detection** — orchestrator runs lightweight preflight checks BEFORE invoking each skill in chain. Instead of "scan-codebase halted on dep_missing 8 min in", you see "before chain starts: tree-sitter not installed; install or use --engine=regex" — actionable upfront.

Solid handoffs:
- **F3 Schema validation gate** — every handoff YAML validated against handoff-contract.md at emission. Missing REQUIRED/CONDITIONAL field = `invalid_handoff` halt at producer side (immediate developer feedback, not silent consumer miss).
- **F4 Type-checked field propagation** — handoff-contract.md now declares TYPE annotations. Field type mismatch = `handoff_type_mismatch` halt. Prevents silent shape drift (e.g., scope.id being string in one skill but object in another).

**Phase A foundation:** closes 3 of Iter 31's audit areas (handoff YAML sweep + halt taxonomy sync + stale name sweep) to enable F3/F4 enforceability without breaking existing pipelines.

**Phase B audit:** `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` documents intelligence gaps across all 13 skills with prioritized Iter 34+ candidates.

**orchestrate-flow major bump v2.5.1 → v3.0.0:** new procedure steps + 4 new halts may stop chains where prior versions wouldn't (all backward-compat by default — fall-through on missing memory/checks/schema).

**Plugin v3.23.0 → v3.24.0.**

See [docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md](../../docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md) for full design.

### v3.23.0 (Iter 32) — Starterkit-Aware Deep Scan

mega-sdd now **automatically** captures your starterkit's actual auth/RBAC/UI-UX/library patterns and feeds them through the pipeline — no flags, no config.

**What changed:**
- `scan-codebase` v2.6.0+ runs a deep-scan stage automatically when a framework is detected. 4 parallel subagents read your manifests + actual code to extract: which auth lib (Sanctum/Breeze/Jetstream/Fortify/Passport), which RBAC lib (Spatie/permission/custom), which UI stack (Alpine/Livewire/Inertia + Tailwind/Bootstrap + SweetAlert/Toastr), and your full library inventory with usage hints.
- Output: `.mega-sdd/codebase/starterkit-context.yaml` — canonical structured context, cached via lock-file hashing (re-scan with unchanged deps is 0sec).
- `generate-units` v2.6.0+ reads the context and adds starterkit-specific Anchors and Hard Rules to each unit with mandatory citations. Your unit specs now know about `layouts.app`, `User` model FQCN, your Spatie middleware names, your SweetAlert2 component path.
- `execute-bolts` v2.7.0+ injects a relevant slice (≤2KB, per-unit) into the bolt-dispatch-prompt T2 tier. Bolts generate code that matches your starterkit by default — uses your layout, your notification lib, your auth guard.

**Why this matters:**
- Before: generated units used framework defaults; bolts produced code that didn't always match your starterkit's libs.
- After: your starterkit's choices propagate automatically. Standing prefs like SweetAlert2 + `document.addEventListener` over `$(document).ready` + responsive mobile-first flow into Hard Rules with citations — no per-session reminder needed.

**Autonomous by design:**
- Zero user flags. Zero config. Triggers automatically when `scan-codebase` detects a framework at MEDIUM+ confidence.
- Graceful degradation: subagent timeouts → partial output; all-fail → preserve prior cache + halt for retry; no framework detected → skip silently.

See [docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md](../../docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md) for the full design.

---

### v3.22.0 (Iters 17-30)

- **Iter 17 Constitution layer** — 8th vault file (`constitution.md`) with project-facing rules; clauses inject into bolt Hard Rules
- **Iter 18 Replay + PBT** — `/mega-sdd:replay <unit>` for regression detection; `properties:` field for invariant testing
- **Iter 19 Convergence loops** — `/mega-sdd:auto --converge` auto-recovers eligible halts using memory recommendations
- **Iter 20 Audit fixes** — closed 5 claim-vs-implementation gaps from Iter 17-19
- **Iter 21 Path-default hotfix** — all writer-side defaults flip to `.mega-sdd/` (no excuse); read-side back-compat preserved
- **Iter 22 KB-as-analysis philosophy** — 3-tier mutability classification (`[LOCKED]/[INTENT]/[ARTIFACT]`) orthogonal to existing confidence markers. KB drives reengineering recommendations, not 1:1 legacy mirror. `data-mutation-policy.md` + ERD Quality Rails. `generate-intent --kb` routes claims to vault per tier
- **Iter 23 Framework Convention Packs** — pluggable convention catalog at `references/framework-conventions/`. scan-codebase detects framework (Laravel/Django/Rails/Express/NestJS/FastAPI/etc.) → bind-codebase loads matching pack → framework-specific Hard Rules merged into Suggested Unit Hard Rules. Universal-good-practice fallback. v1.0 ships with `_universal.md` + `laravel.md` + `_template.md` for adding more
- **Iter 24 RECON / base-laravel-26 starterkit pack** — extracted user's Laravel 12 starterkit conventions (Vuexy + Jetstream + Spatie + Reverb + custom helpers/traits + CRUD generator + notification rule engine) into `laravel-base-26.md` (~600 lines, extends `laravel.md`). 11 Hard Rules + 11 forbidden patterns + project-specific idioms encoded as enforceable conventions. scan-codebase detects via Vuexy fingerprint
- **Iter 25 Audit closure** — closed 27 findings from v3.16.0 deep audit: completed Iter 21 hotfix across 6 commands + handoff-contract + memory schema + recommendation-context + checkpoint paths; fixed bind-codebase step sequence (duplicate 2.5 + dangling 2.10) + halt-conditions completion; fixed generate-units step jumble; propagated Iter 22 mutability to 6 consumer skills (bind, drift, resolve-oq, generate-units, agents-md, handoff); propagated Iter 23 framework pack to generate-units (provenance citation) + execute-bolts + AGENTS.md header; fixed 2 broken cross-references; updated scenario-4 to demo tier flow + starterkit detection
- **Iter 26 Verification closure** — closed 5 highest-leverage gaps from v3.17.0 verification audit: emit-agents-md output template now uses `{{vault_path}}` substitution (no more legacy paths in every AGENTS.md emitted); bind-codebase step 2.10 placed in linear sequence; generate-units 7.5/7.6 swap + audit log → step 13; diff-vault:318 cross-ref fixed; commands/orchestrate-flow.md refreshed for `--deep` + `--resume`; AGENTS.md schema gains PBT/replay/convergence header fields (P1-9)
- **Iter 27 Starterkit-first pipeline** — scan-codebase moves to FIRST phase when starterkit detected; vault generation becomes pack-aware via dual-citation format (Intent + Starterkit binding). Three modes: A (starterkit-first DEFAULT), B (framework universal fallback), C (explicit `--greenfield`). New halt `no_starterkit_detected` enforces opinion. Per user directive "starterkit itu wajib ada, jika tidak ada baru greenfield"
- **Iter 28 Multi-scope PRD picker** — canonical PRD/BRD format with `scopes:` frontmatter block enables deterministic scope detection. Each architect (BE/MW/FE) generates a vault scoped to ONLY their content. Interactive picker (cwd smart default + memory-driven recall + confirm-once). Legacy PRDs without frontmatter trigger AI-assisted retrofit bridge. No cross-scope orchestration — coordination remains human-driven (rapat antar arsitek). New `--scope=<id>` flag in `/mega-sdd:auto` + `/mega-sdd:generate-intent`. Governance artifact: `docs/templates/prd-template.md` for sharing with PMs as new SOP
- **Iter 29 v3.20.0 audit closure** — 13 findings closed from post-Iter-28 deep audit (`docs/superpowers/audits/2026-05-24-iter-28-v3.20.0-deep-audit.md`). Pattern was Iter 28 producer-only: generate-intent wrote scope to vault.json + handoff YAML, but ZERO downstream skills consumed it. Fix: scope propagation to 6 consumer skills (bind-codebase v1.9.3, generate-units v2.5.4, emit-agents-md v1.2.4, execute-bolts v2.4.2, detect-drift v1.2.2, resolve-oq v0.9.1). Also: diff-vault v1.3.0 implements prd_sha256 change detection (closed unimplemented spec claim). Orchestrate-flow v2.4.1 halt taxonomy gains 4 new entries (3 Iter 28 + 1 Iter 29). Generate-intent gains formal §Halt conditions section with full YAML envelope examples. Step 0.9 execution-order guard added (file order ≠ runtime order). agents-md-schema.md stale legacy vault paths fixed
- **Iter 30 execute-bolts seamless pipeline** — bolt subagent dispatched via tiered context enrichment (T1 always ≤2KB / T2 conditional ≤5KB / T3 reference-on-demand) per `references/bolt-dispatch-prompt.md`. Implements 10 AI-executor principles from spec (anti-context, confidence labels, past-failure intelligence, self-assessment vocabulary, halt vocabulary, validation hints, atomic discipline, provenance trailers, graceful partial-state). Plus seamless pipeline: compact streaming progress + aggregate `<vault>/bolts/_summary.md` + propose-and-confirm halt UX (AI fix proposer for test_fail / hard_rule_violated / pbt_property_violated; user single-click approve) + auto-drift gate DEFAULT-ON after batch (~6x faster via shared snapshot reuse) + DRIFT-REPORT.md `## Suggested next actions` with auto-handoff commands + convergence loops bridge bolt halts. New halts: dispatch_prompt_too_large, bolt_repeated_partial_failure, provenance_missing, self_assessment_missing, bolt_introduces_locked_drift

## Anti-hallucination defense (15 layers)

1. **Intent** — uncertain claims promote to Open Questions
2. **OQ classification** — business vs tech; tech auto-resolves
3. **Binding gate** — CONFLICT blocks
4. **Implementation state** — IMPLEMENTED / NEW / PARTIAL_FIELDS_MISSING / UNKNOWN
5. **Unit grounding** — target_files whitelist + acceptance_test + Anchors
6. **Hard Rules pre/post-flight** — ast-grep validates at bolt time
7. **AST-precise extraction** — tree-sitter (Aider pattern)
8. **Memory** — suggestion-only with audit log
9. **Drift detection** — code vs vault reconciliation
10. **Interface lock** — cross-squad consumed interfaces must be locked
11. **Mutability tier classification** — [LOCKED]/[INTENT]/[ARTIFACT] orthogonal to confidence (Iter 22)
12. **Constitution layer** — project invariants enforced as Hard Rules at bolt time (Iter 17)
13. **Framework convention packs** — laravel/django/rails/etc. conventions inject into Suggested Unit Hard Rules (Iter 23)
14. **Predictive preflight** — orchestrate-flow surfaces upcoming halts before they fire (Iter 33 F2)
15. **Handoff schema validation** — handoff YAML type-checked against handoff-contract.md per skill (Iter 33 F3+F4)

## Memory layer (v2.1+)

Three scopes of markdown + JSON memory persist context across sessions:

- `~/.mega-sdd/memory/` — USER (opt-in, cross-project)
- `<project>/.mega-sdd/memory/` — PROJECT (per-repo, git-trackable per-file)
- `<vault>/.memory/` + `<vault>/.internal/checkpoints/` — VAULT (per-vault, ephemeral)

Self-learning via threshold-based suggestions reviewed through `/mega-sdd:memory review`. Never auto-applied. Mandatory audit log + rollback path. Complementary to Claude Code's `auto memory`.

## Reuse-stable tooling (Iter 14)

Mega-sdd ADOPTS stable native binaries instead of building from scratch (all OPTIONAL with graceful fallback):

| Tool | Used by | Fallback |
|---|---|---|
| `tree-sitter` | scan-codebase (AST extraction) | regex |
| `ast-grep` | execute-bolts (Hard Rules v2) | v1 5-type grammar |
| `ripgrep` (`rg`) | scan-codebase / detect-drift / bind-codebase / lint-units | GNU grep |
| `jd` | diff-vault (canonical JSON/YAML patches) | manual Read+compare |
| `markdownlint-cli2` | lint-units (vault prose) | skill-internal heuristics |
| `gh` (GitHub CLI) | optional PR automation | manual PR by user |

See [`references/tooling-install.md`](./references/tooling-install.md) for one-command install per platform.

See the [root README](../../README.md) for diagrams, full command table, halt protocol, autonomy mechanics, migration guide.

## Contributing

Read [`CLAUDE.md`](./CLAUDE.md) first if you're an AI agent submitting a PR — anti-slop protocol applies. Every behavior change traces back to a spec doc in [`../../docs/superpowers/specs/`](../../docs/superpowers/specs/).

For human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md). Tree-sitter `.scm` query patterns adapted from [Aider](https://github.com/Aider-AI/aider) (Apache 2.0) — see `skills/scan-codebase/queries/`.
