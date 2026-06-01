---
name: generate-intent
version: 1.17.0
description: Spec-driven intent generation — convert PRD/BRD + Figma OR free-text brief OR knowledge-base (legacy-rebuild scenario) into a 7-file vault with anti-hallucination guarantees. Mode A (PRD parse) vs Mode B (free-text Q&A) auto-detected from positional argument shape — no flag required. `--from-prompt` flag preserved for explicit override. `--kb=<path>` flag (v1.2+) consumes a `mega-sdd:extract-intelligence` knowledge base as Mode B brief input. (v1.3+, Iter 1) OQs carry `category: business | tech` tag. (v1.4+, Iter 2) Auto-classifier tags every OQ with `category` + `resolution_mode` + `classification_confidence` per `references/vault-contract.md` §Auto-classifier heuristics. (v1.14+, Iter 35) `--phase=N` flag for Mode B KB sub-mode; vault.json gets `phase` + `phase_total` fields; 00-index.md emits §Phase context block. Triggers — "spec out this feature", "buat dev handoff", "from this prompt", "pecah PRD ini buat AI dev", "rebuild from KB", or paraphrases.
---

# Grand Design Spec Generator

Converts PRD/BRD + Figma into 7 markdown files inside a user-specified folder, optimized for **anti-hallucination dev handoff** — meaning a downstream dev (human or AI) can implement from these docs without inventing requirements.

> **Skill instruction language**: this skill is written in English for reasoning quality. **Generated docs match the input PRD language** — if the PRD is in Indonesian, the seven output files are in Indonesian; if the PRD is in English, output is English. The skill's chat prompts to the user adapt to the user's language at runtime.

## Invocation modes

`generate-intent` has TWO input modes (with a v1.2+ KB sub-mode under Mode B), AND a starterkit-aware overlay (v1.11+ Iter 27) that applies to ALL modes when scan-codebase has been run first.

### Mode A — Structured input (PRD / BRD / Figma)
Invocation: `/mega-sdd:generate-intent ./prd.md` (or any structured doc path)
Behavior: parse + decompose directly per `references/vault-contract.md`. No Q&A unless source is critically incomplete.

### Starterkit overlay (v1.11+ Iter 27) — `--scan=<codebase-map-path>` or `--greenfield`

Per user directive "scan code base harusnya di atur di depan ... starterkit itu wajib ada". When invoked in starterkit-first mode (orchestrate-flow Mode A/B), the scan phase runs BEFORE this skill. Generated vault becomes pack-aware via the `--scan=<codebase-map-path>` flag:

- **`--scan=<path>`** (v1.11+) — read `codebase-map.md` §7 Framework + §1-6 conventions BEFORE drafting vault. Resolves the framework convention pack via the `pack_path` field. Vault sections (`02-architecture.md`, `03-data-model.md`, `06-constraints.md`) use **dual-citation format** (Intent + Starterkit binding) per `references/vault-contract.md` §Starterkit binding.
- **`--greenfield`** (v1.11+) — EXPLICIT opt-in for stack-agnostic generation. Skips scan reading. Vault stays generic. REQUIRED when starterkit absent (orchestrate-flow halt `no_starterkit_detected` enforces this).
- **`--scope=<id>`** (v1.12+ Iter 28): explicit scope selection (BE, MW, FE, custom id, or `all` for legacy single-vault). When PRD has `scopes:` block AND flag not set → interactive picker fires (Step 0.9). Halt `scope_not_declared_in_prd` if id not in PRD scopes.
- **Auto-detection**: if `codebase-map.md` exists at canonical location AND no `--greenfield` set → `--scan` implicitly applied. Confirms with user before proceeding (unless `--auto`).

When BOTH `--scan` AND `--kb` set (legacy-rebuild scenario): vault synthesizes legacy domain intent (from KB) + target scaffold conventions (from scan). `[LOCKED]` KB items preserved 1:1; `[INTENT]` KB items rendered using starterkit conventions; `[ARTIFACT]` items discarded.

### Mode B — Free-text brief (--from-prompt)
Invocation: `/mega-sdd:generate-intent --from-prompt "<brief text>"` OR detected when no structured PRD path provided.
Behavior: per `references/from-prompt-mode.md` — runs adaptive Q&A (≤10 questions) to fill gaps, then produces seed-PRD + vault in one pass.

### Mode B (KB sub-mode) — `--kb=<path>` (v1.2+, legacy-rebuild scenario; v1.10+ tier-aware routing; freshness check v1.15+)

Invocation: `/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/`

KB is treated as ANALYSIS INPUT, not a 1:1 spec. Vault output emphasizes REENGINEERING goals + business intent; legacy detail surfaces only when `[LOCKED]` tier requires preservation. Per user directive (Iter 22): "code dan ERD bisa berubah, tapi goals reengineering nya terpenuhi, jika tidak ada ketentuan erd harus 1:1".

**Preflight — KB freshness check (v1.15+, Iter 46 — D1-006 closure):**

Before reading KB content, check if `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` exists per `plugins/mega-sdd/references/shared-snapshot-schema.md §extract-intelligence (extracted-kb snapshot)`:

1. If snapshot exists, read `source_files_sha256_map`
2. For each `<repo-relative-path>` in the map: compute current sha256 of that file in the legacy source codebase
3. If ALL files match prior hashes → log `"KB freshness: confirmed (<N> source files unchanged since extraction at <generated_at>)"`. Proceed with KB consumption.
4. If SOME files drifted → log warning: `"KB may be stale: <drifted-count> of <total> source files changed since extraction (<generated_at>). Consider \`/mega-sdd:extract-intelligence --force\` to refresh KB before generating vault."`. DO NOT halt — user retains agency to proceed (legacy stale-KB warnings should not block reengineering work).
5. If snapshot absent (pre-Iter-46 KBs OR snapshot write failed) → log advisory `"KB has no freshness snapshot (pre-Iter-46 OR snapshot emission failed); treating as fresh."`. Proceed.

Freshness check is OPT-IN advisory; KB consumption correctness is unchanged whether check confirms / warns / skips.

Behavior:

1. **Read KB README first** — extract `Reengineering Opportunities` section (v1.4+ KBs) + `Mutability Tier Distribution` table. If pre-v1.4 KB (no tier markers), treat all claims as `[INTENT]` (safe middle-ground).

2. **Read `99-rebuild-architecture/data-mutation-policy.md`** (v1.4+ KBs) — this drives ERD freedom. Without this file, fall back to "all `[INTENT]`" default.

2.5. **Parse `--phase=N` flag (v1.14.0+, Iter 35).**

Default: `--phase=1` (when flag absent).

When `--kb` AND `--phase=N`:
a. Read `<KB>/99-rebuild-architecture/suggested-phasing.md`. Count `## Phase` heading occurrences → `phase_total`.
b. Validate `N` ≤ `phase_total`. If out of range → error message: "Phase <N> requested but suggested-phasing.md has only <phase_total> phases. Available: 1..<phase_total>." Halt invocation (no halt-protocol envelope needed — invocation-time validation).
c. Read `## Phase <N>` section content (scope + deliverables + acceptance criteria).
d. Scope vault generation to this phase's deliverables — extract claims from KB filtered by Phase N's scope. Out-of-phase domains may still be cited but not woven into Phase N's vault.
e. Persist: write `phase: N`, `phase_total: <phase_total>` to `vault.json` (Step 11 below — vault.json write).

Defensive fallback: if `suggested-phasing.md` absent OR has zero `## Phase` headers → log "no phasing detected in KB; treating as single-phase (phase: 1, phase_total: 1)" + proceed.

When `--phase` flag absent AND `--kb` set → assume `--phase=1` AND set `phase_total` from suggested-phasing.md (or 1 if absent).
When `--kb` not set (Mode A / Mode B free-text) → always `phase: 1, phase_total: 1`.

3. **Read 10-domains files** + extract claims with both confidence + mutability markers.

4. **Tier-aware routing per claim** (v1.10+):

   | KB marker pair | Vault treatment | Vault location |
   |---|---|---|
   | `[VERIFIED][LOCKED]` | Verbatim — exact legacy field name, type, constraint preserved | `02-architecture.md` + Hard Rule emission for execute-bolts ; tagged `mutability_source: kb_locked` |
   | `[VERIFIED][INTENT]` | Outcome goal — state transition + business rule preserved; implementation references rebuild proposal | `02-architecture.md` (rebuild shape) + `04-functional-spec.md` (outcome) ; tagged `mutability_source: kb_intent` |
   | `[VERIFIED][ARTIFACT]` | Vault `## Open Questions` — default "discard unless preserve required" | `00-index.md` OQ section ; tagged `mutability_source: kb_artifact`, default resolution: discard |
   | `[INFERRED][LOCKED]` | Single confirmation question (high stakes); default "keep as LOCKED" pending user veto | OQ until confirmed, then promoted to vault per `[VERIFIED][LOCKED]` rule |
   | `[INFERRED][INTENT]` | Vault body with note "INFERRED — confirm in dev"; outcome already captured | `04-functional-spec.md` with `[INFERRED]` annotation |
   | `[INFERRED][ARTIFACT]` | Skip vault entry entirely; log to `_diagnostics/kb-skipped-artifacts.md` | Diagnostic only |
   | `[OPEN][?]` | Vault `Open Question` — answering resolves both axes | `00-index.md` OQ section |

5. **ERD freedom**: vault `02-architecture.md` uses `99-rebuild-architecture/suggested-erd.md` as the proposed new shape — NOT the legacy `30-data-model/conceptual-erd.md`. Exception: `[LOCKED]` entities/fields from `data-mutation-policy.md` retain legacy shape verbatim (name, type, constraints, validation rules).

6. **Q&A loop**: shorter than free-text Mode B because KB covers most gaps. Aim ≤5 questions. Primary Q&A targets:
   - `[INFERRED][LOCKED]` items (highest stakes — confirm preservation requirement)
   - `[ARTIFACT]` items flagged for discard (confirm with user before discarding)
   - Reengineering Opportunities (confirm rebuild team accepts the proposal)
- Auto-detection (priority order, first hit wins): `.mega-sdd/knowledge-base/README.md` (v3.4+ default) → `docs/knowledge-base/README.md` (legacy) → `docs/mega-sdd/knowledge-base/README.md` → `old-reference/knowledge-base/README.md`. If detected AND no `--from-prompt` / positional PRD argument → set `--kb=<detected-path>` implicitly. Confirm with user before proceeding.

The three modes share the SAME vault contract (`references/vault-contract.md`). The only difference is input parsing.

### Detection rules (v1.2+ — deterministic, no LLM judgment)

When the user invokes `/mega-sdd:generate-intent <arg>`, evaluate rules in order. First match wins:

| Rule | Match condition | Mode |
|---|---|---|
| 0 | `--kb=<path>` flag is present | **B (KB sub-mode)** — explicit; positional and `--from-prompt` ignored |
| 1 | `--from-prompt` flag is present | **B** (explicit override; positional ignored as path) |
| 2 | Positional arg resolves to an existing file on disk | **A** |
| 3 | Positional arg matches glob `*.md` / `*.pdf` / `*.docx` (regardless of whether file exists) | **A** — warn if file missing; offer to switch to B |
| 4 | Positional arg contains whitespace OR is wrapped in quotes OR is longer than 80 chars | **B** (treat as brief) |
| 5 | Positional arg has no path separators (`/`, `\`) AND no recognized extension | **B** |
| 6 | No positional arg AND CWD has any of (priority order) `.mega-sdd/knowledge-base/README.md`, `docs/knowledge-base/README.md`, `docs/mega-sdd/knowledge-base/README.md`, `old-reference/knowledge-base/README.md` | **B (KB sub-mode)** — auto-detect, confirm with user |
| 7 | No positional arg AND no KB | CWD scan: search for `prd.md` / `seed-PRD.md` / `*.md` PRD candidates. 1 hit → confirm Mode A; 0 or >1 → prompt user |

The `--from-prompt` flag remains supported for explicit invocation; new users typically won't need it.

### Edge cases

- **Quoted single word** (`"buildTodoCLI"`) — Rule 4 matches (wrapped in quotes) → Mode B. The user explicitly quoted the input; treat it as a brief.
- **Looks-like-path but doesn't exist** (`./missing.md`) — Rule 2 fails (file doesn't resolve) but Rule 3 catches the `.md` extension → Mode A. Skill warns the user `"File ./missing.md not found. Treating as Mode A path. To use free-text, wrap in quotes or use --from-prompt."` and offers to abort.
- **Bare single word** (`prd`) — Rule 5 matches (no path separator, no extension) → Mode B. If the user actually meant a path, ask them to provide an extension (`prd.md`) or relative path (`./prd`).
- **Flag + positional conflict** (`--from-prompt "build X" ./prd.md`) — Rule 1 wins → Mode B. The trailing `./prd.md` is ignored. Skill warns: `"--from-prompt set; ignoring positional ./prd.md. Provide just the brief or just a path, not both."`

When detection is ambiguous (Rule 3 with missing file, Rule 6 with multiple candidates), the skill always confirms with the user before proceeding. Detection silently when high-confidence.

## When to use this skill

Trigger this skill for any of the following user requests, **whether stated literally or paraphrased**:

- "Break down this PRD for the dev team" / "pecah PRD ini buat dev"
- "Spec out this feature" / "buat dev handoff"
- "Prepare context for AI-assisted dev" / "siapkan context buat AI dev"
- "Translate business requirements into architecture docs"
- "Convert PRD + Figma into dev-ready specifications"
- Any request to take a product/business document and produce structured dev specs
- "from this prompt" / "from a brief" / "baku dari ide" — invokes Mode B (free-text)
- "I only have an idea, not a PRD" / "ide aja gue belum sempat PRD" — invokes Mode B

The skill is **anti-hallucination by construction**: every claim cites its source, ambiguities become Open Questions (not guesses), Out of Scope is always explicit.

## Core principle

> **Ground everything in the PRD/uploaded docs. Do not invent.**
> **If it is not explicit in the source, it does NOT go in the body. It goes in Open Questions.**

This applies to every doc. No "industry best practice" insertions, no "probably they meant X" guesses, no filler sentences. The source documents (PRD/BRD/Figma/uploaded files) are the ONLY ground truth. If the source is silent, the answer is "Open Question", not Claude's prior knowledge.

> **v0.6 extension**: this rule applies to **section presence too**, not just content within sections. Design-system sections (`02-architecture#ui-components`, `06-constraints#design-system`) only appear if at least one source explicitly contains design-system content. Project shape is NOT a trigger. Skill never prompts for missing design-system sources. Industry standards (WCAG, Material Design, Tailwind defaults) are NOT defaults — they only appear if cited in source.

## Simplicity policy

**Default: as simple as possible.** Each doc should be the shortest version that still answers what its readers need. Cut anything that doesn't earn its place.

**Exception: `04-flows.md` may be reasonably complete.** Flows describe step-by-step behavior with branching, error paths, and Definition of Done — completeness matters more than terseness. Length proportional to PRD complexity is fine here; for other docs, terseness wins.

## Project Shape Registry

This skill is **general-purpose** — it works for any kind of project, not just mobile banking. Project shape determines the sub-sections inside `02-architecture.md` and `04-flows.md`, and the reading paths inside `00-index.md`.

The skill **infers** the project shape from PRD content during Step 2 (extract), then **confirms** it with the user before generating files.

### Pre-templated shapes (most common)

| Shape | When to use | Layers (for `02-architecture.md`) | Flow types (for `04-flows.md`) | Roles (for `00-index.md` reading paths) |
|-------|-------------|-----------------------------------|--------------------------------|----------------------------------------|
| `mobile-app` | Mobile-first product with backend (e.g. M-Smile, e-wallet) | Mobile / Frontend, Backend, Integrations | User flows (mobile), Backend / system flows, Cross-cutting | Architect, Mobile Dev, BE Dev, QA, PM, UI/UX |
| `web-app` | Web-based product (SaaS, dashboard) with backend | Web Frontend, Backend, Integrations | User flows (web), Backend / system flows, Cross-cutting | Architect, FE Dev, BE Dev, QA, PM, UI/UX |
| `api-only` | Backend service with no own UI (microservice, internal API, webhook handler) | Backend, Integrations | Backend / system flows, Consumer-facing flows (when external clients hit the API) | Architect, BE Dev, QA, PM, External integrator |
| `multi-platform` | Has web + mobile + backend (e.g. Arygas-style) | Web Frontend, Mobile, Backend, Integrations | User flows (web), User flows (mobile), Backend / system flows, Cross-cutting | Architect, FE Dev, Mobile Dev, BE Dev, QA, PM, UI/UX |
| `data-pipeline` | ETL, batch processing, no user-facing UI (e.g. reconciliation engine, reporting job) | Source connectors, Processors, Sinks, Integrations | Pipeline flows, Error/recovery flows, Operational flows | Architect, Data Engineer, QA, PM, Data analyst |

### Custom fallback

If the project doesn't fit any of the 5 pre-templated shapes:

- Use shape `custom`.
- Skill MUST ask user to describe layers/components and roles in their own words.
- Generated sub-sections must derive from the user's description, not invented.

> Examples of custom shapes: CLI tool, library/SDK, browser extension, embedded system, hybrid mobile-cli, IoT device firmware.

### Inference rules (Step 2)

When extracting from PRD, infer shape using these heuristics:

- PRD mentions "mobile app", "M-Smile", "iOS", "Android", "push notification" → likely `mobile-app` or `multi-platform`
- PRD mentions "web", "browser", "dashboard", "SaaS" + backend → likely `web-app`
- PRD describes API endpoints/integrations only, no UI → likely `api-only`
- PRD covers both web and mobile UIs explicitly → `multi-platform`
- PRD describes batch jobs, scheduled processors, no user-facing UI flows → `data-pipeline`
- None of the above → `custom`, ask user

If inference confidence is low (e.g. PRD ambiguous, mentions both mobile and web casually), skill MUST present its inference with reasoning and ask user to confirm or override.

---

## Inputs

The user typically provides one or more of:

- **PRD/BRD file**: PDF (priority), DOCX, MD, or TXT. Location auto-detected per environment (sandbox: `/mnt/user-data/uploads/`; local Claude Code: ask user or use CWD). See Step 1.
- **Figma URL**: Use Figma MCP if connected. To check whether Figma MCP tools are loaded — Claude Code: `ToolSearch` with `query: "figma"`; Claude.ai sandbox: `tool_search(query="figma")`. If no Figma MCP and no screenshots, ASK the user before proceeding — do not guess UI structure.
- **Output folder path**: user MUST specify (see Step 0). Skill never assumes a path silently.
- **Optional context**: existing system docs, tech stack constraints, prior architecture decisions.

If critical inputs are missing or unclear, **ask before generating**. Better 5 upfront questions than 7 docs of guesses.

---

## --auto flag (v0.10+)

The `--auto` flag is set by upstream callers — typically `/mega-sdd:orchestrate-flow`, the lifecycle orchestrator — to skip logistical prompts. When `--auto` is set, the Workflow steps below behave differently:

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (output path) | Ask user via `AskUserQuestion` | Default to `.mega-sdd/vaults/<slug>/` (v3.4+ canonical per `plugins/mega-sdd/references/paths.md`) derived from PRD project name (slug-cased). If folder exists & non-empty, **STILL ASK** (destructive — never auto-overwrite). Legacy default `docs/mega-sdd/vaults/<slug>/` only honored when legacy layout already detected on disk. |
| Step 0.5 (IMPLEMENTATION_MODE) | Ask | Infer from codebase signals: `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod` / etc. detected in CWD or vault parent → `existing`; else `new`. |
| Step 0.5 (`mode_migrate_after`, mode=new only) | Ask | Default to `"first commit on main"`. |
| Step 0.6 (PRD_STATUS) | Ask | Default to `draft` (safe default — generates more OQs, less assertion). |
| Step 0.7 (OUTPUT_MODE) | Ask | Default to `compact`. |
| Step 2 (gap-count push-back when PRD_STATUS=draft) | Pause if gap count > 10 | Skip the pause; dump all gaps to OQs (matches PRD_STATUS=final behavior). |

What stays interactive even with `--auto`:

- **Figma "do you have screenshots?" prompt** if Figma was referenced but no MCP loaded — must NOT invent UI structure.
- **Destructive overwrite confirmations** when output folder exists and is non-empty.
- **PROJECT_SHAPE confirmation** if inference confidence is low (skill's existing rule). Otherwise auto-confirm the inferred shape.

What `--auto` does NOT do (anti-halu rails — NEVER bypass):

- ❌ Auto-answer Open Questions or invent values for any field.
- ❌ Skip source citation requirements.
- ❌ Skip OQ tagging for gaps.
- ❌ Pretend the PRD is final when stakeholder hasn't said so.

When the skill is invoked via the `Skill` tool without an explicit `--auto` argument, default to interactive (current v0.9 behavior). Only enter `--auto` mode when the caller explicitly passes it.

When `--auto` is active and the skill produces a P1 Open Question that would block downstream work, additionally emit a `blocker` artifact per `references/vault-contract.md` §halt-protocol. The orchestrator (or other autonomous caller) catches this and surfaces it to the human.

---

## Workflow

### Step 0: Output path setup (MANDATORY, before any generation)

Skill MUST get an explicit output folder path from the user before generating any file.

1. **Ask** the user for the output folder path. Suggest a sensible default derived from the PRD project name (slug-cased).
   - **Claude Code**: use `AskUserQuestion` with options like `["Use default '<slug>/'", "Custom path", "Cancel"]`.
   - **Claude.ai sandbox**: if `ask_user_input_v0` is available, use it with the same options.
   - Fallback: ask plainly in chat — *"Output folder path? (default: `<slug>/`)"*

2. **Detect runtime environment** before resolving the path:
   - Run `pwd && uname -a 2>/dev/null` (or equivalent platform check).
   - **Sandbox detection**: pwd is `/` and `/mnt/user-data` exists → Claude.ai / Desktop sandbox (Linux container).
   - **Local detection**: pwd is user's project dir, no `/mnt/user-data` → Claude Code on Mac/Linux/Windows.

3. **Resolve & sanity-check** path against environment:
   - **Relative path** (e.g. `mega-rencana-spec/`):
     - Sandbox → resolve to `/mnt/user-data/outputs/<path>`
     - Local → resolve to `<CWD>/<path>`
   - **Absolute path**:
     - Sandbox + path starts with `/Users/`, `/home/<not-claude>/`, `C:\`, `D:\`, or `~/` (non-resolvable) → **REJECT**. Tell user: *"This path looks like a local Mac/Windows filesystem, but I'm running in an Anthropic Linux container. If I create it, the folder will only exist inside this container (ephemeral, lost after the session ends). Options: (a) switch to a valid container path, e.g. `/mnt/user-data/outputs/<your-folder>/`, or (b) run Claude Code on your Mac/Windows for native filesystem access."*
     - Local + path starts with `/mnt/` or `/home/claude` → **REJECT**. Tell user: *"This path looks like an Anthropic container path. You're running in a local environment. Provide a local path, e.g. `/Users/<you>/projects/<folder>/`."*
     - Otherwise → use as-is.
   - **Forbidden patterns**: whitespace at edges, control chars, `..` traversal out of writable area → reject + ask again.

4. **Recheck before creating**:
   - Echo the **fully-resolved absolute path** back: *"Will be created at: `<resolved-absolute-path>` — proceed?"*
   - If folder exists and non-empty: *"Folder already exists and contains files. Overwrite, append, or cancel?"* — never silently overwrite.

5. **Auto-create** the folder once user confirms:
   - **Mac / Linux / WSL / Git Bash**: `mkdir -p <resolved-path>`
   - **Windows native cmd.exe** (modern, ≥ Windows 7): `mkdir <resolved-path>` (auto-creates parents)
   - **Windows PowerShell**: `New-Item -ItemType Directory -Path <resolved-path> -Force`
   - Verify creation succeeded (`ls -la <resolved-path>` or `dir <resolved-path>`) before proceeding.

6. **Persist** the resolved path explicitly. After Step 0 confirmation:
   - Echo a state line: `OUTPUT_DIR=<resolved-absolute-path>`.
   - In every subsequent file write (Step 3, Step 5), prefix the file path with **exactly** this `OUTPUT_DIR`. Do NOT default back to `/mnt/user-data/outputs/grand-design/` if the user picked something else.
   - Re-echo `OUTPUT_DIR=...` at the start of each major step as a reminder to self.

> Skill never proceeds to Step 0.5 without a confirmed, created `OUTPUT_DIR`.

### Step 0.5: Implementation mode flag (MANDATORY, after path setup)

The vault is a **lock against requirements** (PRD/BRD), not against existing codebase. This skill does NOT read the codebase. The mode flag is **metadata** that instructs downstream AI dev consumers (Claude Code, Cursor) how to behave when reading the vault.

1. **Ask** the user:
   - **Claude Code**: use `AskUserQuestion` with two options.
   - **Claude.ai sandbox**: use `ask_user_input_v0` if available.
   - Fallback: plain chat question.

   The two choices:
   - **`new`** — greenfield project, no existing codebase to reconcile with.
   - **`existing`** — extending or modifying a live codebase. Downstream AI consumers must verify with user before touching existing code.

2. **Persist mode flag** explicitly:
   - Echo: `IMPLEMENTATION_MODE=new | existing`
   - This flag is recorded in `00-index.md` Vault Lock Status section.
   - This flag drives downstream consumer instructions in `00-index.md` "Implementation Notes for AI Consumers" section.

3. **Do NOT ask for codebase path, repo URL, or existing entity names.** That is the job of downstream AI dev consumer when it reads the vault. This skill stays focused on the requirement → vault transformation.

4. **Migration trigger** (v0.11, applies to `mode=new` only):
   - A `mode=new` vault should plan its transition to `mode=existing` because the moment real code lands, the vault risks drifting from reality.
   - Capture the trigger event in Vault Lock Status field `mode_migrate_after`. Default suggestions:
     - `"first commit on main"` — flips to `existing` once any non-trivial implementation lands.
     - `"first prod deploy"` — flips later, after the system is observable.
     - `"sprint-1 demo"` — flips at first stakeholder review.
   - When the trigger fires, the user manually flips the flag (edit `00-index.md` Vault Lock Status + add Changelog entry + bump vault version) OR runs `/mega-sdd:diff-vault` against the current PRD with `mode=existing` selected.
   - **After flip**, `/mega-sdd:detect-drift` becomes applicable and recommended for ongoing reconciliation.
   - For `mode=existing` vaults, set `mode_migrate_after = null` (already in target state).

> Skill never proceeds to Step 0.6 without a confirmed `IMPLEMENTATION_MODE`.

### Step 0.6: PRD/source document status flag (MANDATORY, after mode flag)

The skill behaves differently when the source PRD/BRD is **declared final by stakeholder** vs still **draft and editable**. This flag controls whether the skill pauses for clarification or generates straight through.

1. **Ask** the user:
   - **Claude Code**: use `AskUserQuestion` with two options.
   - **Claude.ai sandbox**: use `ask_user_input_v0` if available.
   - Fallback: plain chat question.

   The two choices:
   - **`final`** — PRD/BRD has been signed off by stakeholder. No more edits expected. Skill **does NOT pause** to ask "should we clarify first?" — every gap, ambiguity, or contradiction goes straight to Open Questions roll-up. User triages OQ list with stakeholder offline (post-vault).
   - **`draft`** — PRD/BRD still in flux. Skill **may pause** when gap count is large (>10) and ask user whether to proceed or send back for clarification first. Default behavior.

2. **Persist flag** explicitly:
   - Echo: `PRD_STATUS=final | draft`
   - This flag is recorded in `00-index.md` Vault Lock Status section.
   - This flag drives gap-handling behavior in Step 2 and push-back behavior throughout.

3. **Implications when `PRD_STATUS=final`**:
   - Skill MUST NOT ask "Proceed or clarify first?" when gap count is high — proceed and dump everything to Open Questions.
   - Skill MUST NOT refuse to generate due to PRD inconsistencies — surface contradictions in Open Questions instead, with both PRD quotes side-by-side.
   - Skill MUST still refuse "just guess the rest" requests — `final` means the PRD is locked, not that Claude is licensed to invent. Gaps remain Open Questions, never silently filled.
   - Vault Lock Status reflects this: `PRD source: <filename> (FINAL, signed-off)`.

> Skill never proceeds to Step 0.7 without a confirmed `PRD_STATUS`.

### Step 0.7: Output verbosity flag (MANDATORY, after PRD status flag)

The skill produces two verbosity tiers of the same vault. **Compact is the default** — token-efficient, table-heavy, cuts narrative scaffolding while preserving every source citation, every Open Question, and every Definition of Done. **Full** restores prose elaboration, API payload examples, and per-decision consequence bullets — useful when the vault doubles as onboarding doc for non-technical readers.

1. **Ask** the user:
   - **Claude Code**: use `AskUserQuestion` with two options (compact recommended, listed first).
   - **Claude.ai sandbox**: use `ask_user_input_v0` if available.
   - Fallback: plain chat question — *"Output mode: `compact` (default, ~40% lighter, table-first) or `full` (verbose, prose elaboration)?"*

   The two choices:
   - **`compact`** (default) — table-first, prose-cut, 1-line TL;DR, no boilerplate API JSON examples, OQ as single-line entries, decisions as 1-paragraph blurbs. **Anti-halu invariants preserved**: every source citation, every OQ tag with priority, every DoD checklist still required.
   - **`full`** — prose-rich, 3-line TL;DR header, full request/response JSON per endpoint, prose entity descriptions alongside DBML, multi-bullet ✅⚠️ consequences per ADR. Use when audience includes non-technical reviewers (BO, legal, compliance) who need narrative context.

2. **Persist flag** explicitly:
   - Echo: `OUTPUT_MODE=compact | full`
   - This flag is recorded in `00-index.md` Vault Lock Status section.
   - This flag drives Step 3 generation rules per "Output mode policy" below.

3. **Auto-default conditions** (skill picks `compact` without asking):
   - User explicitly requested terse / minimal / token-efficient output in conversation.
   - User runs in autonomous / no-pause mode (e.g., "proceed without asking", "lanjut tanpa nanya").
   - Echo the auto-default: *"Auto-defaulting to `OUTPUT_MODE=compact` because <reason>. Override with `full` if you need prose."*

> Skill never proceeds to Step 1 without a confirmed `OUTPUT_MODE`.

### Squad partition (v1.1+)

After project shape and implementation mode are decided, ask:

> **Q (squad count):** "How many development squads will work on this project?
> Single-squad (1) = current default; multi-squad (≥2) enables per-squad
> execution via `/mega-sdd:execute-bolts --per-squad` with one Claude
> subagent per squad."

If answer is `1`:
- Skip remaining squad questions
- Do NOT emit `_meta/squads.yaml`
- Do NOT emit `interfaces/` folder
- Set `multi_squad_mode: false` in `vault.json`

If answer is `≥2`:

> **Q (partition model):** "How should squads be partitioned?
>   1. layer-based  — each squad owns architectural layers from `02-architecture.md`
>      (e.g., Backend Squad, Frontend Squad, Integrations Squad)
>   2. feature-based — each squad owns one or more feature tags
>      (e.g., Auth Squad, Billing Squad, Leave-Mgmt Squad)
>   3. hybrid       — feature wins over layer when both match"

Then per squad (loop until user signals "done"):

> **Q (squad declaration):** "Declare a squad. Provide:
>   - id (format: squad-<kebab-case>, e.g., squad-be)
>   - label (display name, e.g., Backend Squad)
>   - ownership rules per the chosen partition model:
>     - layer: list of layer names from architecture (e.g., backend, data-model)
>     - feature: list of feature tags (e.g., auth, billing)
>     - hybrid: both"

Validate per `references/squad-partition.md`. If validation fails (duplicate
ownership, malformed id), re-ask the failed field only.

After all squads declared, emit `_meta/squads.yaml` from `references/templates/squads.yaml.template`, replacing `{{PROJECT_SHAPE}}`, `{{PARTITION_MODEL}}`, and `{{SQUAD_*}}` placeholders with collected answers. Set `multi_squad_mode: true` in `vault.json`.

### Step 0.9: Scope detection + PRD filtering (v1.12+, Iter 28)

> **EXECUTION ORDER GUARD (post-Iter-29 audit P1-1 fix):** This step appears in the file BEFORE the "Scan-aware context loading" section (~line 557) due to numbering hierarchy (0.x slots are reserved for pre-Step-1 metadata). At RUNTIME, this step MUST execute AFTER scan-aware context loading completes — the picker's smart default heuristic needs the scan-codebase result (codebase-map.md framework detection) to recommend the correct scope. Sequence: Step 0 → 0.5 → 0.6 → 0.7 → squad partition → Step 0.8 Scan-aware context loading (defined at §"Step 0.8: Scan-aware context loading" later in this file) → **Step 0.9 (THIS STEP)** → Step 1 Load PRD.

Per `references/scope-picker.md`. Runs AFTER all Step 0.x metadata config (PRD_STATUS, OUTPUT_MODE, squad partition, scan-aware) and BEFORE Step 1 Load PRD — because scope choice filters which PRD content gets loaded.

a. **Read PRD frontmatter.**
   - If `scopes:` block present (canonical multi-scope PRD) → step b
   - If absent → step c (legacy retrofit bridge)

b. **Canonical scope handling**:
   - If only one scope declared → silent route to legacy single-vault flow (no picker)
   - If multiple scopes declared:
     - If `--scope=<id>` flag set → validate against declared scopes; **halt `scope_not_declared_in_prd`** if invalid (surface PRD-declared scope list + cancel option)
     - Else if `<project>/.mega-sdd/memory/decisions.md` has prior choice for this PRD sha256 + same cwd basename → silent default with confirm-once UX (5s timeout)
     - Else → invoke `AskUserQuestion` with options:
       - One option per declared scope (smart-default flagged per cwd heuristic)
       - "All scopes (single combined vault — legacy behavior)" option (legacy fallback)
       - "Cancel" option
     - If user chose `--scope=all` (legacy) → emit warning, proceed with all content (current behavior pre-Iter-28)
   - After scope chosen: filter PRD content per `references/scope-picker.md` §Filter logic
   - Persist scope choice to memory per `references/scope-picker.md` §Memory write rules
   - Tag vault.json with `scope`, `scope_metadata`, `prd_sha256` per `references/vault-contract.md` §Multi-scope vault
   - Render sibling scopes informational notes in `00-index.md` per same reference

c. **Legacy PRD retrofit bridge**:
   - Invoke `AskUserQuestion` with options:
     - "Yes, propose retrofit (recommended)" — dispatches AI subagent per `references/legacy-retrofit-prompt.md`
     - "Treat as single-scope PRD" — routes to legacy single-vault flow
     - "Cancel — manual fix first" — **halt `prd_no_scopes_block_user_rejected_retrofit`**
   - On retrofit chosen:
     - Dispatch subagent with prompt template; receive structured analysis
     - Render diff to user (detected scopes + evidence + proposed frontmatter + section restructure)
     - `AskUserQuestion`: accept / review per scope / skip / cancel
     - On accept: write retrofit to `<prd-name>.retrofit.md` (preserves original); restart Step 0.9 from step a using retrofit file
     - On `overall_confidence: LOW` → **halt `prd_retrofit_low_confidence`** with options (accept anyway / single-scope fallback / cancel)

`--scope=<id>` and `--greenfield` flags interact as documented in `commands/generate-intent.md` §Flag combinations.

### Step 1: Inventory and read

1. **Identify input file location** based on environment detected in Step 0:
   - **Sandbox** (Claude.ai / Desktop): list `/mnt/user-data/uploads/`.
   - **Local** (Claude Code on Mac/Linux/Windows): assume CWD or **ask user** explicitly: *"Where are the PRD/BRD files? (e.g. `./prd.pdf`, `~/Downloads/`, or absolute path)"*. Do NOT assume a path silently.

2. For each file, route to the right reader:
   - PDF → use `pdf-reading` skill (or platform PDF tool)
   - DOCX → use `docx` skill (or platform DOCX tool)
   - MD / TXT → read directly

3. **For Figma URLs** (if PRD references one):
   - **Claude Code**: run `ToolSearch` with `query: "figma"` (keyword) or `query: "select:mcp__claude_ai_Figma__get_design_context,mcp__claude_ai_Figma__get_screenshot,mcp__claude_ai_Figma__get_metadata"` to load Figma MCP tool schemas.
   - **Claude.ai sandbox**: run `tool_search(query="figma")` to check if Figma MCP tools are loaded.
   - If found, use them with the URL / `node-id` to fetch frame info.
   - If MCP not loaded but available in the platform's registry: optionally call `search_mcp_registry(["figma"])` then `suggest_connectors([directoryUuid])` to prompt user to connect (Claude.ai only — Claude Code uses `/mcp` command).
   - If user declines connection / no MCP / no screenshots → **ask user**: *"Figma not accessible. Skip and rely on PRD only, or will you provide manual screenshots?"* Do NOT invent UI structure from imagination.

4. **Read every input fully**. No skimming. The whole point is grounding.

### Step 2: Extract before writing

Before generating any markdown, build an internal map of:

- **Product**: what / who / why
- **Project shape**: infer from PRD content per the Project Shape Registry. Default candidates: `mobile-app`, `web-app`, `api-only`, `multi-platform`, `data-pipeline`, or `custom`.
- **Components**: explicit system parts mentioned, grouped by inferred layers
- **Data entities**: names, fields, relations
- **Flows**: user journeys, system processes
- **Decisions**: technical choices stated with rationale
- **Constraints**: technical, business, regulatory, non-functional
- **Gaps**: every ambiguity → goes to Open Questions, never to body
- **Design-system content** (v0.6, optional): scan all sources (PRD, Figma via MCP, uploaded tokens files, BRD, user-provided context) for explicit mentions of:
  - **UI components**: Figma frame inventory under "Components" page, Storybook export entries, PRD-stated component names with variants
  - **Design tokens**: Figma variables (call `mcp__claude_ai_Figma__get_variable_defs`), tokens.json entries, tailwind.config.js theme keys, PRD-stated hex/value rules
  - **Accessibility standards**: PRD-stated WCAG level, Figma a11y annotations, contrast / keyboard / screen-reader rules
  - **Voice / brand rules**: PRD-stated tone, locale, copy guidelines

  Persist findings as four flags: `HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND` (each `true | false`). These flags drive Step 3 conditional generation. **Do not infer from shape — only from explicit source content.**

**Source merge rules** (when multiple sources cover the same token/component):

1. Figma MCP (highest) — `get_variable_defs` for tokens, `get_design_context` for components.
2. User-provided tokens file (tokens.json / tailwind.config.js / Storybook export).
3. PRD-stated values.

Higher priority wins for the same value. If a higher-priority source is silent on a value, use a lower one. **If two sources of equal precedence disagree (e.g., two Figma URLs, or Figma + tokens.json with different hex for `color.primary`), do NOT silently pick — emit `OQ-CN-{N} [P1]` with both quoted values side-by-side.**

**Multi-platform note**: for `multi-platform` shape, Web and Mobile may have separate Figma URLs / token files. If user provided multiple sources, treat them independently per layer. If only one platform has a source → only that platform's design-system section appears.

**Existing-mode note**: skill does NOT read the codebase. Even if `IMPLEMENTATION_MODE=existing` and the codebase already implements a design system, the vault reflects only PRD/Figma/tokens file sources. Reconciling vault with existing-codebase design system is the downstream AI consumer's job.

**Confirm project shape with user**:

- Present inferred shape + reasoning: *"Based on the PRD, I infer shape = `<shape>`. Reasoning: <2-3 reasons>. Confirm or override?"*
- If user overrides → use new shape.
- If shape = `custom` (no clear fit) → ask user: *"Project shape doesn't fit any of the 5 pre-templated shapes. Describe the layers (e.g. 'CLI tool with engine + plugin system') and roles (e.g. 'developer + admin') that exist."*
- Persist shape: `PROJECT_SHAPE=<shape>`. This drives sub-section structure in Step 3.

**Gap-handling depends on `PRD_STATUS` (set in Step 0.6)**:

- **`PRD_STATUS=draft`**: if gap count > 10, stop and ask user whether to proceed or get clarification from stakeholder first. Default behavior.
- **`PRD_STATUS=final`**: do NOT pause regardless of gap count. PRD is locked — every gap, ambiguity, and contradiction goes straight to Open Questions. User will triage the OQ list with stakeholder after the vault is generated.

For `final` mode, surface a one-line note in the Step 5 summary: *"PRD is final; all {N} gaps are captured in the Open Questions roll-up. Triage offline with stakeholder before dev starts."*

### Step 3: Generate 7 files

Output to the **resolved output folder from Step 0** (referred to as `<OUTPUT_DIR>` below):

```
<OUTPUT_DIR>/
├── 00-index.md          ← Navigation + Vault Lock + Implementation Notes for AI Consumers + OQ roll-up
├── 01-overview.md       ← What, who, why, success criteria
├── 02-architecture.md   ← Components by layer (Mobile/Backend/Integration), API contracts
├── 03-data-model.md     ← Entities, relations, constraints (DBML preferred)
├── 04-flows.md          ← User flows + system flows (per-layer addressable) + per-flow Definition of Done
├── 05-decisions.md      ← ADR-style: context → decision → consequences
└── 06-constraints.md    ← Technical, business, non-functional
```

> **v0.6 conditional sections** (driven by Step 2 detection flags):
>
> - `02-architecture.md > UI components & patterns` sub-section: appears **only if** `HAS_UI_COMPONENTS = true`. Otherwise the sub-section is omitted entirely (no header, no placeholder, no OQ).
> - `06-constraints.md > Design system` top-level section: appears **only if** at least one of `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND` is `true`. Within the section, sub-blocks (Tokens / Accessibility / Voice & brand) appear only for the flags that are `true`.
> - `00-index.md > Reading paths`: the "UI/UX or FE Dev" path appears **only if** at least one of `02-architecture#ui-components` or `06-constraints#design-system` is present in the vault.
> - `00-index.md > Glossary`: design-system glossary entries (design tokens, design system, WCAG, a11y, semantic HTML) appear **only if** the term is actually used elsewhere in the generated vault.
>
> **No shape-based defaulting.** A project with `PROJECT_SHAPE=mobile-app` but no source coverage of design-system content produces a vault identical to v0.5 output. Skill never injects WCAG levels, color palettes, spacing scales, or component lists from prior knowledge.

#### Operator-workflow-UX capture + Design-Source OQ (v1.17+, code-delivery slice G)

> Durable enforcement is `validate-vault-oqs.sh` (PostToolUse re-validates every vault doc write; PreToolUse Branch 10 blocks `mega-sdd:execute-bolts` on a capture-stage miss). This prose is defense-in-depth — get it right at generation time so the gate never has to fire.

**Rule 1 — model the operator surface when the flows show a workflow.** When the PRD/KB flows in `04-flows.md` exhibit a **maker-checker / multi-stage-approval / workflow** pattern (a user-facing flow with a maker→checker actor hand-off chain, OR ≥2 distinct decision transition steps — approve / reject / review / confirm), model the operator-facing surface as **FIRST-CLASS requirements GROUNDED in the flows** — never invented:

- **Worklist / inbox** — where each actor (checker, confirmer, …) finds the items awaiting *their* decision, filtered by role + current workflow state.
- **Decision affordance** — the approve / reject (and any return-to-prior-stage) actions available to the actor in the entity's current state.
- **Human-readable state labels** — a label map from the raw `workflow_state` enum to operator-facing text (e.g. `SUBMITTED` → "Awaiting Checker").
- **Audit timeline** — the append-only transition history rendered for the operator (who acted, when, prior → next state).

Capture these in `02-architecture.md` (and the component/view inventory) and reflect them in `vault.json`. **Grounded, not invented**: every operator-surface requirement must trace to a flow step / actor / state in `04-flows.md`. If the surface design is genuinely undecided, capture it as an OQ instead of inventing it (see Rule 2). The validator FAILs with `operator_surface_missing` when a workflow flow exists but the vault models no operator surface AND carries no Design-Source OQ.

**Rule 2 — emit a Design-Source OQ, never a defaulted value.** When `HAS_UI_COMPONENTS = true` (UI components exist) but `HAS_TOKENS`, `HAS_A11Y`, and `HAS_VOICE_BRAND` are **all `false`** (no design tokens, no accessibility spec, no voice/brand source was provided), emit a single high-priority **Design-Source Open Question** — e.g. `OQ-DESIGN-SOURCE-{N} [P1]` — requesting the design-system source (token palette, WCAG target, brand voice) before UI units are enriched. **DO NOT relax the anti-hallucination rail**: never default WCAG levels, Material/Tailwind palettes, spacing scales, or brand voice from prior knowledge — the gap is captured as an OQ ONLY. The validator FAILs with `design_source_oq_missing` when UI components exist with all three design flags false and no Design-Source OQ is present.

> Vault structure is the same regardless of `IMPLEMENTATION_MODE`. The mode flag drives content of `00-index.md` "Implementation Notes for AI Consumers" section, not the file count.

### Bonus output: `vault.json` machine-readable manifest (v0.11)

Alongside the 7 markdown files, generate `vault.json` — a structured manifest that AI dev consumers (Claude Code, Cursor, automated agents) load for fast, reliable context without parsing prose markdown. Markdown remains the human-authoritative source; JSON is a derived index.

**Schema, field rules, and regeneration trigger points** — see `references/vault-contract.md` §schema. Read this file before generating `vault.json`.

**v1.15.1+, Iter 49 (D3-012 closure) — vault.json advisory lock:** acquire exclusive file lock on `<vault>/vault.json.lock` per `references/vault-contract.md §Concurrency contract` BEFORE writing vault.json. Backoff + retry 3x; fail with `memory_in_use` halt if all retries fail. Release lock after atomic write (temp file + rename) completes. Lock acquisition is REQUIRED for initial vault.json write — concurrent generate-intent invocations on the same vault path would race.

**Why both formats**:
- Humans review markdown — narrative, citations, nuance.
- AI consumers read `vault.json` — fast structural lookup, no token-heavy prose parsing, reliable enum-based status/priority filtering.

Use templates in `references/templates/` as scaffolds. **Resolve the path relative to where the skill is mounted**:

- **Claude Code (plugin install — primary distribution)**: `${CLAUDE_PLUGIN_ROOT}/skills/generate-intent/references/templates/<name>.md`
- **Claude Code (manual install at `~/.claude/skills/`)**: `~/.claude/skills/generate-intent/references/templates/<name>.md`
- **Claude Code (project-scoped manual install)**: `<project-root>/.claude/skills/generate-intent/references/templates/<name>.md`
- **Claude.ai upload**: `/mnt/skills/user/generate-intent/references/templates/<name>.md`

Read the relevant template:
- **Claude Code**: use the `Read` tool.
- **Claude.ai sandbox**: use `view` or the platform's read tool.

Then fill it in based on extracted facts. Never invent fields beyond what the source PRD/Figma supports.

### Multi-squad artifact emission (v1.1+)

After emitting the 7 prose docs + `vault.json`, if `multi_squad_mode: true`:

1. **Emit `_meta/squads.yaml`** from `references/templates/squads.yaml.template`,
   substituting `{{PROJECT_SHAPE}}`, `{{PARTITION_MODEL}}`, and per-squad
   `{{SQUAD_ID_N}}`, `{{SQUAD_LABEL_N}}`, ownership lists.

2. **Emit `interfaces/_index.md`** from `references/templates/interfaces-index.template.md`,
   substituting `{{VAULT_VERSION}}` and `{{PROJECT_SLUG}}`. Do NOT emit any
   `interfaces/<id>.md` files — those are authored manually by the architect
   when cross-squad contracts emerge during design.

3. **Emit `.obsidian/graph.json`** from `references/templates/obsidian-graph.json.template`,
   then ADD per-squad `colorGroups` entries — one for each declared squad with
   a distinct color from this palette in order:
   - `squad-be` → `{ "a": 1, "rgb": 3911867 }`     (blue: #3b82f6)
   - `squad-fe-web` → `{ "a": 1, "rgb": 11048700 }` (purple: #a855f7)
   - `squad-integrations` → `{ "a": 1, "rgb": 16330027 }` (orange: #f97316)
   - additional squads → cycle through standard Obsidian palette

4. **Single-squad mode**: skip steps 1-3 above. Plugin behaves as v1.0.

After emission, suggest next step per the existing hand-off message but
include squad count: "Generated vault for N squads. Next: …".

### Step 0.8: Scan-aware context loading (v1.8+, Iter 16)

> **Note (post-Iter-29 audit P1-1)**: At runtime, this section executes BEFORE Step 0.9 (Scope detection) even though Step 0.9 appears physically earlier in this file. The 0.x numbering reserves slots for pre-Step-1 metadata, but scope detection's smart default needs scan-codebase results — so the scan-aware loading runs first in the orchestrate-flow chain, then Step 0.9 picker fires with scan context in hand.

Per user feedback — vault generation produces fewer fabricated entities + tighter OQ classification when codebase context is available at gen-time. Iter 16 introduces scan-aware context loading.

Probe for existing scan artifacts BEFORE Step 1 (vault structure read) BEFORE Step 2 (extraction):

1. **Probe codebase-map.md**: check `<project>/.mega-sdd/codebase/codebase-map.md` (v3.4+) AND `<project>/codebase-map.md` (legacy)
2. **Probe conventions.md memory**: `<project>/.mega-sdd/memory/conventions.md` (v3.4+) AND `<project>/.mega-sdd/memory/conventions.md` (legacy)
3. **Probe knowledge-base**: `<project>/.mega-sdd/knowledge-base/README.md` (v3.4+) AND `<project>/docs/knowledge-base/README.md` (legacy)

**Detection outcomes**:

| Probe result | Action |
|---|---|
| All artifacts present | Load as context for Step 2 extraction; auto-resolve `tech/scan` OQs immediately |
| Codebase-map missing, brownfield indicators present (e.g., `.git` + existing code files) | INTERACTIVE prompt: "Brownfield repo detected but no codebase-map. Run scan-codebase first? (recommended)" — if Y, auto-invoke; if N, proceed with reduced precision |
| Codebase-map missing, greenfield (no code) | Proceed without scan (current behavior) |
| Knowledge-base present + `--kb` flag | Already handled (existing Mode B sub-mode); KB feeds Step 2 |

**Auto-route action**: when user accepts pre-scan, invoke `mega-sdd:scan-codebase` per orchestrate-flow's auto-route pattern; return to Step 1 after scan completes.

`--no-pre-scan` flag skips this step entirely (preserves pre-v1.8 behavior).

### Scan context usage in subsequent steps

When scan-aware mode active, extracted context is passed to:

| Step | Usage |
|---|---|
| Step 2 (PRD/brief extraction) | Cross-reference entities mentioned in PRD against codebase entity list; mark existing entities with `[CODEBASE: exists]` annotation in vault body |
| Step 3 (write 7 files) | Conventions section in 06-constraints.md auto-populated from `conventions.md` memory; tech stack section pre-filled |
| Step 3.5 (OQ auto-classifier) | OQs that match codebase signals (test framework, naming, file location, error format) auto-resolved as `tech/scan` with `status: resolved` + citation; NOT surfaced as pending OQs |
| Step 4 (self-check) | Validate entity claims don't fabricate new entities for already-existing codebase entities |

**Anti-halu rails**:

- Scan-aware mode is OPT-IN via prompt OR auto-route; never silent (per architect/dev separation philosophy when truly intent-only)
- PRD precedence preserved: PRD claims OVERRIDE codebase reality (CONFLICT surface in binding phase, not silenced)
- Existing-entity awareness adds annotation, NOT replaces vault claim. Architect can override.
- `--no-pre-scan` flag opt-out preserves pre-v1.8 architect-only workflow

### Step 3.4: Write constitution.md (v1.9+, Iter 17)

Per `references/vault-contract.md` §constitution. Write 8th vault file with project-facing rules.

1. **Extract from PRD/KB**:
   - Coding standards: from PRD tech-stack section + KB conventions
   - Security baselines: from PRD non-functional + KB business rules
   - Architecture invariants: from PRD architecture + KB design-decisions
   - Anti-patterns: from KB critical findings + past project memory (`.mega-sdd/memory/patterns.md`)
   - Performance constraints: from PRD non-functional + KB performance hints
   - Compliance: from PRD constraints + regulatory KB sections

2. **Write `<vault>/constitution.md`** with 6 sections (§A through §F):
   - §A Coding standards
   - §B Security baselines
   - §C Architecture invariants
   - §D Anti-patterns
   - §E Performance constraints
   - §F Compliance

3. **Cite source for every clause** (per anti-halu rail): `(per PRD §<section>)` OR `(per KB §<file>:<line>)` OR `(per .mega-sdd/memory/decisions.md row <N>)`

4. **Persist hash in vault.json**:
   ```json
   "constitution_version": "1.0.0",
   "constitution_hash": "<sha256 of constitution.md>"
   ```

5. **Surface for user sign-off**: emit one-line summary in chat: "Constitution.md written with N clauses. Review before bolts begin: <path>"

6. **`--no-constitution` flag** skips this step (preserves pre-v1.9 7-file vault behavior); for one-off greenfield demos.

### Step 3.5: OQ auto-classification (v1.4+, Iter 2)

After Step 3 writes the 7 files but BEFORE Step 4 self-check, run the auto-classifier on every generated OQ:

1. **For each OQ in docs 01-06**, apply the heuristic table from `references/vault-contract.md` §Auto-classifier heuristics:
   - Match OQ text against pattern column
   - Assign `category`, `resolution_mode`, `classification_confidence`
   - Conservative default when no pattern matches: `category: business`, `resolution_mode: blocking`, `classification_confidence: low`

2. **For `resolution_mode: scan`**: populate `scan_query` from the OQ's "Resolves:" hint or infer the codebase-map section to probe (e.g., "what test framework?" → `scan_query: "codebase-map §test_frameworks"`).

3. **For `resolution_mode: recommend`**: populate the four required fields:
   - `recommendation` — Claude's pick (1-2 sentences)
   - `rationale` — why this pick; what trade-off was considered (2-3 sentences)
   - `scan_citations` — at least 1 entry; cite related-pattern anchor in codebase-map / KB / source PRD (e.g., `app/Http/Resources/ErrorResource.php:12`). If no exact match exists, cite the closest pattern with a "no exact match; closest: ..." note.
   - `fallback_if_wrong` — what to revisit if this recommendation turns out incorrect (1 sentence)
   - **Anti-halu rail**: NEVER fabricate citations. If no codebase context exists at all, downgrade to `category: business` with note "no codebase context to ground recommendation; needs human decision."

4. **For `resolution_mode: blocking`** (default for business + low-confidence tech): no additional fields required.

5. **Write classified OQ data** back to both the markdown body and `vault.json` per `references/vault-contract.md` §Updated OQ schema.

6. **Generate `00-index.md` "## Auto-Classification Review" section** before the main OQ roll-up. List every tech-tagged OQ + every flipped/manually-overridden OQ. Per DESIGN-OQ-3, only `high`-confidence tech OQs auto-resolve in downstream `bind-codebase`; `medium`/`low` are flagged for user review.

7. **Validation gate**: before proceeding to Step 4, validate every OQ entry per `references/vault-contract.md` §Validation rules:
   - Tech OQ missing `resolution_mode` → halt `oq_tech_missing_mode`
   - `recommend` OQ missing any of `recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong` → halt `oq_recommend_underspecified`
   - `scan` OQ missing `scan_query` → halt `oq_scan_missing_query`

**Halt YAML format:**

```yaml
blocker:
  type: oq_recommend_underspecified
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-intent
  details:
    oq_id: OQ-AR-7
    missing_fields: [scan_citations, fallback_if_wrong]
    oq_text: "<verbatim from vault>"
  next_action: "Re-run generate-intent OR manually populate the missing fields in vault.json before bind-codebase."
```

### Step 4: Self-check before delivery

Verify every doc has:

**Grounding & anti-halu:**
- [ ] No invented entities, fields, endpoints, decisions, or behaviors. Every claim can be cited to PRD/Figma/uploaded docs.
- [ ] **Sources** section filled (cite PRD section, Figma frame, or other input).
- [ ] **Out of Scope** section filled (write `TBD - confirm with PO` if genuinely unknown — never leave empty).
- [ ] **Open Questions** section filled. Tagged `OQ-{DOC_CODE}-{N}` + prioritized P1/P2/P3.

**Readability (architect/PM/QA review-ready):**
- [ ] **TL;DR header** present in every doc 01–06. Format: 1-line if `OUTPUT_MODE=compact`, 3-line if `OUTPUT_MODE=full`.
- [ ] Output language convention consistent — code-level terms in English (entity names, field names, types, enum values, HTTP methods, framework names); prose narrative in PRD language. Avoid mixing English and PRD language in the same prose sentence except for code-term references.
- [ ] Read-aloud test: the first paragraph of each doc does not sound like AI translation.
- [ ] First-use acronym/jargon defined inline; cross-doc terms are in the Glossary at `00-index.md`.
- [ ] Cross-ref ≤ 2 per section.
- [ ] `00-index.md` has: Executive Summary, Project Readiness Status, Reading paths by role, Glossary, OQ roll-up.

**Output mode compliance (driven by `OUTPUT_MODE` from Step 0.7):**
- [ ] If `compact`: TL;DR header is 1-line in docs 01–06.
- [ ] If `compact`: API contracts use the table format; full request/response JSON only appears for endpoints with non-trivial payload (nested struct / polymorphic shape).
- [ ] If `compact`: doc 03 entity descriptions dropped — DBML block + 1-line `Purpose:` per entity is enough.
- [ ] If `compact`: doc 04 Preconditions/Postconditions sections cut; Steps + DoD remain detailed.
- [ ] If `compact`: doc 05 ADRs use the 1-paragraph format, not the multi-section block.
- [ ] If `compact`: OQ entries are 1-line, not multi-line elaboration.
- [ ] If `compact`: Glossary contains only terms used in the body + product-specific terms; generic IT terms dropped.
- [ ] If `full`: every section per template scaffold is filled, including prose narrative, JSON examples, multi-bullet consequences.

**Anti-halu invariants (mandatory in BOTH modes — never cut even in compact):**
- [ ] Every claim cites source.
- [ ] Every OQ tagged & prioritized.
- [ ] Every flow has a DoD checklist.
- [ ] Every decision has explicit source.
- [ ] Out of Scope section never empty.
- [ ] Cross-cutting flow handoff points present.
- [ ] (v1.4+, Iter 2) Every OQ carries `category` + (if tech) `resolution_mode` + `classification_confidence`.
- [ ] (v1.4+, Iter 2) Every `recommend`-mode OQ has at least one `scan_citations` entry; no fabricated citations.
- [ ] (v1.4+, Iter 2) `00-index.md` has `## Auto-Classification Review` section listing tech-tagged OQs + medium/low confidence cases.

**Each doc must be readable in <10 minutes by an architect (BOTH modes).**

**Output integrity:**
- [ ] All files written to `<OUTPUT_DIR>` (not the default sandbox path).
- [ ] Folder structure matches the 7-file spec.
- [ ] Language matches source (PRD ID → docs ID; PRD EN → docs EN).

**`vault.json` manifest (v0.11):**
- [ ] `vault.json` exists at `<OUTPUT_DIR>/vault.json` alongside the 7 markdown files.
- [ ] Every entity defined in `03-data-model.md` DBML appears in `entities[]` array.
- [ ] Every flow ID in `04-flows.md` (one per `F-{prefix}-NNN`) appears in `flows[]`.
- [ ] Every ADR `D-NNN` in `05-decisions.md` appears in `adrs[]`.
- [ ] Every OQ tag across docs 01–06 appears in `open_questions[]` with matching priority and status.
- [ ] `open_questions_summary.total` equals the count in `open_questions[]` and matches the count in the `00-index.md` roll-up.
- [ ] `open_questions_summary.by_priority` counts match the per-priority counts in the roll-up.
- [ ] All four metadata flags (`project_shape`, `implementation_mode`, `prd_status`, `output_mode`) match `00-index.md` Vault Lock Status.
- [ ] Design-system flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) match the values used to drive Step 3 conditional generation.

**Halt protocol & implementation notes (v0.13):**
- [ ] `00-index.md` contains "Halt protocol for autonomous runs" sub-section under Implementation Notes for AI Consumers (per template).
- [ ] `00-index.md` contains "Parallel-work guidance while P1s are unresolved" sub-section.
- [ ] `00-index.md` contains "Companion skills for vault evolution" sub-section pointing to `resolve-oq` / `diff-vault` / `detect-drift`.

**Design-system grounding (v0.6, only if any design-system section appears):**
- [ ] Section presence justified — `02-architecture#ui-components` exists ⇒ `HAS_UI_COMPONENTS = true` from Step 2; `06-constraints#design-system` exists ⇒ at least one of `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND` is `true`.
- [ ] Components table cites source per row (Figma frame name / tokens file path / PRD §). No invented components.
- [ ] Tokens table cites source per row. No invented hex values, type scales, spacing values, radius values.
- [ ] Patterns prose grounded in PRD note / Figma annotation / explicit user instruction. No best-practice insertions (no defaulted WCAG levels, no defaulted "max 1 CTA per screen" rules unless source explicitly states).
- [ ] Within an appearing section, sub-elements the source is silent on become `OQ-AR-{N}` or `OQ-CN-{N}` — not body.
- [ ] No design-system content appears in vault that did not originate from a cited source.

### Step 5: Present

Files are already on disk under `<OUTPUT_DIR>` (written in Step 3). Step 5 is a chat-only summary:

- **Claude Code**: no special tool needed — files are accessible via filesystem. Just summarize in chat with absolute path so user can open them.
- **Claude.ai sandbox**: use `present_files` to surface the folder in the UI.

In the chat message:

1. Summary: total docs, total Open Questions count, `PRD_STATUS` + `OUTPUT_MODE` flag values.
2. **List of Open Questions (top blockers)** — what the user must resolve before dev starts. If `PRD_STATUS=final`, frame it as: *"Take this OQ list to your stakeholders for offline triage."*
3. Brief note on which sections are most likely to need stakeholder review.
4. Path to vault: `<OUTPUT_DIR>` (absolute).
5. If `OUTPUT_MODE=compact`, mention once that a prose-rich version is available: *"Re-run with `OUTPUT_MODE=full` if you need the prose-rich version for non-technical readers."*
6. **Suggested next steps** — point the user to companion skills:
   - *"After stakeholder triage, run `/mega-sdd:resolve-oq` to walk the OQ list interactively and capture answers back into the vault."*
   - If `PRD_STATUS=final` and OQ count > 10: *"Bring the P1 list to a stakeholder meeting first; resolve-oq picks up from current state when you re-run."*
   - If `IMPLEMENTATION_MODE=existing`: *"Run `/mega-sdd:detect-drift` to reconcile this vault against the live codebase — flags entity/flow/decision drift between target and current reality."*
   - When the PRD eventually revises: *"Use `/mega-sdd:diff-vault` to evolve the vault against the new PRD without losing resolved OQs or ADR history."*

Do NOT pad with "I have created..." preamble. Just deliver and surface blockers.

---

## File-by-file content guide

### Output mode policy (driven by `OUTPUT_MODE` from Step 0.7)

| Aspect | `compact` (default) | `full` |
|--------|---------------------|--------|
| TL;DR header (doc 01–06) | 1 line: `> **TL;DR**: <doc summary> · <intended audience> · <when to read>.` | 3 lines (TL;DR / Audience / When to read) |
| API contracts (doc 02) | Table: endpoint · method · purpose · auth · errors · source. Skip request/response JSON unless payload is non-trivial or has a nested struct that isn't obvious from field names. | Full request/response JSON example per endpoint |
| Entity descriptions (doc 03) | DBML only + 1-line `Purpose:` per entity. No prose narrative. | DBML + per-entity prose: Purpose, Key fields, Relations |
| Flow blocks (doc 04) | Numbered Steps + DoD checklist per flow. Skip Preconditions/Postconditions sections (derivable from steps). Source line still required. | Actor / Trigger + Preconditions + Steps + Postconditions + DoD + Failure handling + Source |
| Decision blocks (doc 05) | 1-paragraph format: `D-XXX: title — context in 1 sentence. Decision: <X>. Consequences: <Y, Z>. Source: PRD §...` | Multi-section format: Status / Date / Context / Decision / Consequences (✅⚠️ bullets) / Source |
| Glossary (doc 00) | Only product-specific terms from PRD + acronyms that appear in the vault body. Drop generic IT terms (FK, RTO, RPO, SLO, ADR, NFR) unless they appear in the body. | Full glossary including generic IT terms |
| Open Questions per doc | 1-line format: `OQ-{CODE}-{N} [P{1\|2\|3}]: <question> — resolve: <PIC/source>` | Multi-line: question + reasoning + impact + resolution path |
| Sources section | Bullet list, no prose intro. | Same |
| "Note" / "Why X" asides in body | Cut. Reasoning belongs in `05-decisions.md`, not other docs. | Allowed when it adds context. |
| Cross-ref to other doc | 1 anchor link, no quote duplication. | Inline quote of cited doc allowed. |

**Hard invariants — preserved in BOTH modes**:
- Every claim cites source (PRD §, Figma frame, uploaded file).
- Every Open Question tagged `OQ-{CODE}-{N}` with priority `P1|P2|P3`.
- Every flow has Definition of Done as observable checklist.
- Every decision has explicit source.
- Out of Scope section never empty (write `TBD - confirm with PO` if genuinely unknown).

**Audience principle**:
- `compact` = optimized for builder reading (architect, dev, QA). Tables + DoD + citations. Skips narrative scaffolding because the reader knows the domain.
- `full` = optimized for cross-functional review (PM, BO, legal, compliance + builder). Prose context for non-technical readers, examples for clarity.

**Doc 04 (flows) exception**:
- `compact`: still cuts Preconditions/Postconditions sections, but Steps + DoD detail remain complete (flow correctness > token saving for QA & implementation).
- `full`: full structured blocks per template.

Cut filler. No padding to look thorough. No amputation to look minimal. Length follows content needed, not a target — output mode adjusts the **granularity of context**, not the completeness of facts.

### Readability standards (mandatory for all 7 files)

These rules ensure docs are reviewable by humans across roles, not just AI dev agents.

**Output language convention** (generated docs match input PRD language):
- Code-level terms always in English: entity names (`mega_rencana_account`), field names (`source_account_id`), types (`bigint`, `varchar`), enum values (`active | dormant`), HTTP methods, protocol names, framework names.
- Prose narrative in the PRD's language. Don't mix English and PRD language in one prose sentence except to reference a code term.
- Avoid awkward hybrid phrasing. Example for an Indonesian PRD: ❌ "Status MUST be active" → ✅ "Status harus `active`".
- Avoid direct-translating from AC verbatim. Example: ❌ "Sistem dapat melakukan pembayaran full akumulasi autodebet dan rekening tidak ditutup" → ✅ "Sistem bayar full akumulasi → rekening tetap aktif."

**Anti-AI-tone**:
- Read each paragraph aloud mentally. If it sounds like AI translation or robotic prose, rewrite it in natural conversational tone for the target language.
- Avoid excessive hedging ("could", "may", "possibly") unless the content is genuinely ambiguous (in which case it goes to Open Questions).
- Use active, short, direct sentences.

**Glossary policy**:
- First-use acronym/jargon in any doc → define it inline at first occurrence (e.g., "DBML (Database Markup Language)").
- `00-index.md` MUST have a **Glossary** section for cross-doc terms: DBML, ADR, FK, NFR, RTO, RPO, MPIN, CIF, OTP, SLO, parameterized, plus product-specific terms from the PRD.

**Cross-reference budget**:
- Max 2 cross-refs to other section/doc per section.
- If more than 2 are needed, inline the essential information, or move to an appendix at the end of the doc.
- Cross-refs must be self-contained: the reader should not need to open another file to grasp the basic context.

**Date format convention**:
- `Last updated:` → `YYYY-MM-DD` (precision matters; reviewer needs to know if doc is 1 day vs 30 days old).
- Decision dates, PRD versions, sprint/milestone refs → `YYYY-MM` (sprint/version-level granularity, per project convention).

**Per-doc TL;DR (mandatory header for docs 01–06)** — format depends on `OUTPUT_MODE`:

```markdown
# OUTPUT_MODE=compact (default) — 1 line:
> **TL;DR**: <doc summary> · <primary audience> · <when to read this>.

# OUTPUT_MODE=full — 3 lines:
> **TL;DR**: <one sentence: what this doc contains>.
> **Audience**: <primary reader role, e.g. Architect / Dev / QA / PM>.
> **Read when**: <condition for relevance, e.g. "you're reviewing system structure">.
```

> **Note**: TL;DR placeholders shown in English here for clarity. At runtime, render them in the PRD's language.

### 00-index.md

Required sections, **in this order**:

1. **Project header** — project name + 1-sentence product description.

1.5. **Phase context (v3.26+, Iter 35)** — emit immediately after Project header.

generate-intent MUST write this block to `00-index.md` after the existing header:

```markdown
## Phase context (v3.26+)

**Phase:** <N> of <M>

**This vault covers:** <1-line summary from suggested-phasing.md §Phase N "scope" or "deliverables" — first sentence wins>
```

When `phase_total > 1` AND `N < phase_total`, additionally emit:

```markdown
**Upcoming phases:**
- Phase <N+1>: <1-line from suggested-phasing.md §Phase N+1>
- Phase <N+2>: <1-line from suggested-phasing.md §Phase N+2>
- ...

**To start the next phase** (after this phase's bolts complete):

\`\`\`bash
/mega-sdd:generate-intent --kb=<KB-path> --phase=<N+1>
\`\`\`

**Full phased plan:** `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md`
```

When `phase_total == 1` (greenfield / single-phase project), omit upcoming phases + next-phase command; emit only:

```markdown
## Phase context (v3.26+)

**Phase:** 1 of 1
**Project type:** single-phase (greenfield OR Mode A PRD-driven OR Mode B without legacy-rebuild phasing)
```

Source for "This vault covers" line: first sentence of `## Phase N` section in `suggested-phasing.md`. When `suggested-phasing.md` absent or phase_total=1 (no phasing detected) → use "Single-phase project" as the summary.

2. **Executive Summary** — 3–4 sentences: what + why + current state of project.
3. **Project Readiness Status** — quick checklist:
   - PRD: complete / draft / pending
   - Figma: complete / pending review / not consumed
   - Tech stack: defined / TBD
   - Sign-off: X/Y stakeholders
   - Open Questions count: P1 / P2 / P3
4. **Reading paths by role** — guide for each role:
   - Architect: 02 → 03 → 05 → 06
   - Dev (FE/BE): 02 → 03 → 04
   - QA: 04 (focus DoD)
   - PM / Business Owner: 00 → 01 → 05
5. **Reading order** (full sequence with 1-line purpose per doc).
6. **Anti-hallucination rules** for dev/dev-AI consumers.
7. **Glossary** — cross-doc terms & acronyms.
   - `OUTPUT_MODE=compact`: only product-specific terms from PRD + acronyms that appear in the vault body. Drop generic IT terms (FK, RTO, RPO, SLO, ADR, NFR, DBML, DoD, OQ) unless they appear in the body.
   - `OUTPUT_MODE=full`: full glossary including generic IT terms.
8. **Open Questions roll-up** — categorized, sorted P1→P2→P3 within each (see "Mandatory section template").
   - `OUTPUT_MODE=compact`: 1-line per OQ (`OQ-{CODE}-{N} [P{x}]: <question> — resolve: <PIC>`).
   - `OUTPUT_MODE=full`: multi-line per OQ (question + reasoning + impact + resolution path).
9. **Source documents** — files consumed.
10. **Last updated** — YYYY-MM-DD.

### 01-overview.md

- **TL;DR header**
- **Product**: 2–3 sentences max
- **Target users / personas**: only what the PRD names
- **Problem & motivation**: business problem
- **Success criteria**: KPIs/metrics — only if PRD specifies, else → Open Questions

### 02-architecture.md

- **TL;DR header**
- **System overview**: 1-paragraph high-level + diagram (text/ASCII), all layers in one view.
- **By component layer** — sub-sections **derived from `PROJECT_SHAPE`** (Step 2). Use the layers from the Project Shape Registry. Each role can deep-link to its relevant section.
  - Example for `mobile-app`: `### Mobile / Frontend`, `### Backend`, `### Integrations`
  - Example for `api-only`: `### Backend`, `### Integrations`
  - Example for `multi-platform`: `### Web Frontend`, `### Mobile`, `### Backend`, `### Integrations`
  - Example for `data-pipeline`: `### Source connectors`, `### Processors`, `### Sinks`, `### Integrations`
  - For `custom`: use layers from user's description.
- **API contracts** (only if applicable to shape; e.g. `library/sdk` may have public API contracts but no HTTP endpoints): endpoint, method, req/res shape, error code — only what's explicit in PRD or directly derivable. Else → Open Questions. Group endpoints under their consuming layer.
  - `OUTPUT_MODE=compact`: table by default (endpoint · method · purpose · auth · errors · source). Inline JSON example **only when** payload is non-trivial (nested struct, polymorphic shape) — most CRUD endpoints don't need an example.
  - `OUTPUT_MODE=full`: full request/response JSON example per endpoint, including error envelope shape.
- **Tech stack**: only what's stated/constrained. Group per layer.

> **Why per-layer**: the vault is consumed by multiple roles. Per-layer sub-sections let each role scroll/anchor directly to the relevant section without reading everything. Reading paths in `00-index.md` can deep-link to `02-architecture.md#<layer-anchor>`.

### 03-data-model.md

- **TL;DR header**
- Default format: **DBML**. Fall back to entity tables if DBML doesn't fit.
- Per entity: name, purpose, key fields + types, mandatory/optional
- Relations: 1-1, 1-N, M-N, with FK direction
- Constraints: uniqueness, indexes, soft-delete, audit fields — only what's specified
- `OUTPUT_MODE=compact`: DBML block with inline `note:` per field is enough; add max 1 line `Purpose:` per entity outside DBML. Skip the "Entity descriptions" prose section. Field-level validation table only for fields with non-obvious constraints (min/max, enum, format).
- `OUTPUT_MODE=full`: DBML + per-entity prose section (Purpose / Key fields / Relations) + field-level validation table.

### 04-flows.md

> **Exception to simplicity policy**: this doc is allowed to be reasonably complete.

- **TL;DR header**
- **By flow type** — sub-sections **derived from `PROJECT_SHAPE`** (Step 2). Use flow types from the Project Shape Registry.
  - Example for `mobile-app`: `### User flows (mobile-facing)`, `### Backend / system flows`, `### Cross-cutting flows`
  - Example for `api-only`: `### Backend / system flows`, `### Consumer-facing flows` (when external clients hit the API)
  - Example for `multi-platform`: `### User flows (web)`, `### User flows (mobile)`, `### Backend / system flows`, `### Cross-cutting flows`
  - Example for `data-pipeline`: `### Pipeline flows`, `### Error/recovery flows`, `### Operational flows`
  - For `custom`: use flow categories from user's description.
- For each flow:
  - Numbered steps. Reference Figma frame if available.
  - **Per-flow Definition of Done**: observable behavior. Bullet list per flow. **Required in BOTH modes** — DoD is the QA contract; never cut.
  - `OUTPUT_MODE=compact`: skip Preconditions/Postconditions section (state changes derivable from steps + DoD). Skip Failure handling section unless the failure path is non-trivial. Steps remain detailed.
  - `OUTPUT_MODE=full`: full structured blocks per template (Actor, Preconditions, Steps, Postconditions, DoD, Failure handling, Source).
- For cross-cutting flows (or any flow that involves multiple layers), explicit handoff points: e.g. "Mobile sends to BE → BE responds → Mobile renders". **Required in BOTH modes**.

> **Why per-type**: same rationale as `02-architecture.md`. Multiple consumers, deep-link navigation. QA uses the DoD per flow; layer-specific devs focus on their flow type.

### 05-decisions.md

- **TL;DR header**
- Format depends on `OUTPUT_MODE`:

```markdown
# OUTPUT_MODE=compact (default) — 1 paragraph per ADR:
### D-001: <short title>
<Context in one sentence>. **Decision**: <what was decided, 1–2 sentences>. **Consequences**: <pros + tradeoffs, comma-separated, max 2 lines>. **Source**: <PRD §X>.

# OUTPUT_MODE=full — multi-section per ADR:
### D-001: <short decision title>
**Status**: Proposed | Accepted | Superseded by D-XXX
**Date**: YYYY-MM
**Context**: <why this decision is needed, 2–3 sentences>
**Decision**: <what was decided, 1–3 sentences>
**Consequences**:
- ✅ <positive>
- ⚠️ <trade-off>
**Source**: <PRD §X / explicit user instruction / meeting note>
```

Only decisions with an explicit source. PRD silent → not an ADR; it's an Open Question. Applies in both modes.

### 06-constraints.md

- **TL;DR header**
- **Technical constraints**: stack lock-ins, infra limits, integration boundaries
- **Business constraints**: timeline, budget, regulatory, compliance, contractual
- **NFR**: performance, scalability, security, availability, observability — only what PRD/stakeholder states

---

## Mandatory section template (every doc 01–06)

Append at the bottom of every numbered doc:

```markdown
---

## Sources
- PRD §X.Y (page Z)
- Figma: <frame-name or URL fragment>
- <other inputs>

## Out of Scope
- <explicit non-goals>
- <if unknown: "TBD - confirm with PO">

## Open Questions
- [ ] **OQ-{DOC_CODE}-{N}** [P{1|2|3}]: <ambiguity, with what's needed to resolve it>
- [ ] **OQ-{DOC_CODE}-{N+1}** [P{1|2|3}]: <next ambiguity>
```

### Open Question tagging convention

See `references/vault-contract.md` §OQ-conventions for tag format, doc-code table, and priority definitions. Every Open Question generated by this skill MUST follow that convention.

### 00-index.md Open Questions roll-up structure

The roll-up in `00-index.md` aggregates all OQs from docs 01–06. Structure:

```markdown
## Open Questions roll-up

> Total: **{N} Open Questions** across 6 docs. Sorted by category, then P1 → P2 → P3 within each category.

### {Category 1 — e.g. "PRD inconsistencies"} (PRIORITY-1)
- [ ] **OQ-DM-1** [P1]: <text> `[03-data-model.md]`
- [ ] **OQ-FL-1** [P1]: <text> `[04-flows.md]`

### {Category 2 — e.g. "Tech stack & architecture"} (PRIORITY-1)
- [ ] **OQ-AR-1** [P1]: <text> `[02-architecture.md]`
...
```

Categorize by topic (not by doc), with the overall priority of the category as the section header. Within each category, list questions sorted P1 → P2 → P3.

---

## Quality bar

- **Grounded**: every non-trivial claim cites source (PRD/Figma/uploaded). Built on the documents, not on prior knowledge.
- **Honest about gaps**: prefer Open Questions over guesses. 50 honest OQs beats 5 fabricated answers.
- **Simple**: as simple as possible (except flows). Cut adverbs, hedges, filler.
- **Human-readable**: docs must be reviewable by architect, PM, business owner, QA — not just AI dev consumers.
- **Predictable structure**: consistent headings so reviewers can skim quickly.
- **Language match**: output language follows input language. Code-level terms remain English; prose follows PRD language.

## When to push back on the user

Push-back rules are **conditional on `PRD_STATUS`** (set in Step 0.6).

### Always (regardless of PRD_STATUS)

- Figma URL given but no MCP and no screenshots → ask. Never invent UI structure.
- User says "just guess the rest" → refuse politely. The whole point of this skill is to NOT guess. Offer to mark unknowns as Open Questions instead. `PRD_STATUS=final` does NOT license invention — it only changes whether the skill pauses to ask stakeholder, not whether Claude can fill in blanks.
- Path mismatch with environment (alien path) → reject per Step 0 rules.
- Output folder exists and non-empty → ask before overwriting.

### Only when `PRD_STATUS=draft`

- Inputs missing critical sections (e.g. no flows in PRD) → ask before generating.
- PRD is contradictory → surface contradictions in chat, ask which version is canonical, wait for resolution.
- Gap count > 10 → ask whether to proceed or get clarification first.

### Only when `PRD_STATUS=final`

- Do NOT pause for any of the three `draft` cases above. PRD is locked, stakeholder is unavailable for synchronous clarification.
- Missing sections, contradictions, large gaps → all funnel into Open Questions roll-up with full context (quotes from PRD, what's missing, what would resolve it).
- For contradictions specifically: write the OQ as `OQ-{DOC}-{N} [P1]: PRD inconsistency — §X.Y says "<quote A>" but §X.Z says "<quote B>". Need stakeholder ruling on which is canonical.`
- Surface in Step 5 summary: total OQ count + reminder that user must triage with stakeholder before dev starts.

### v0.6 — Design-system absence is acceptable (no push-back)

Design-system content is **auxiliary**. Source silence on tokens, UI components, a11y, or brand voice is allowed and produces vault output without those sections. Skill MUST NOT:

- Prompt the user "do you have a Figma URL / tokens file / Storybook export?"
- Default to industry standards (WCAG 2.1 AA, Material Design, iOS HIG, Tailwind defaults).
- Generate placeholder Open Questions for missing design-system content.

If the user explicitly mentions design system in conversation but didn't upload a source, treat that as a regular request for clarification (one chat question), not a workflow gate. Otherwise stay silent.

---

## Outputs (v1.1+ additions)

**Additional outputs in multi-squad mode (≥2 squads):**
- `_meta/squads.yaml` — squad partition declaration
- `interfaces/_index.md` — cross-squad contract index (stub; architect authors actual contracts)
- `.obsidian/graph.json` — Obsidian graph view defaults with squad color groups

---

## Path resolution (v1.7+, Iter 10)

Per `plugins/mega-sdd/references/paths.md`:

- **Default vault path** (v3.4+): `<project-root>/.mega-sdd/vaults/<slug>/`
- **Legacy vault path** (≤v3.3): `<project-root>/docs/mega-sdd/vaults/<slug>/`
- **Detection**: probe `<project-root>/.mega-sdd/` directory + `config.yaml layout:` field
- **Slug derivation**: from project name OR PRD title (unchanged from prior iters)
- **Read-side back-compat**: skill probes both candidate dirs when resuming or diffing existing vault

## Handoff emission (v1.5+, Iter 4)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`. The orchestrator parses this to decide auto-continue.

```yaml
handoff:
  emitted_by: generate-intent
  emitted_at: <ISO8601 timestamp>
  status: completed | paused | halted
  artifacts:
    - <absolute path to vault directory>
    - <absolute path to vault.json>
  next_action:
    suggested_skill: mega-sdd:scan-codebase     # if mode=existing (brownfield)
    # OR
    suggested_skill: mega-sdd:generate-units    # if mode=new (greenfield)
    suggested_args: ["--auto"]
    rationale: "<1-sentence why this is next>"
  blockers: []   # populated on halt
  metrics:
    items_processed: <N OQs generated>
    items_blocked: <N business-blocking OQs requiring stakeholder input>
  scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from PRD>
  mutability:                             # v3.17+ (Iter 25) — when --kb mode produces mutability-tagged claims
    tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
    locked_claims_touched: []
    artifact_discards_proposed: <N>
  phase:                                  # v1.14+ (Iter 35) — phase fields for KB sub-mode phased rebuild
    phase: 1                              # which phase this vault represents (default 1)
    phase_total: 1                        # total phases planned per suggested-phasing.md (default 1)
```

Status `paused` when P1 business OQs are produced (downstream still works; user should triage). Status `halted` on `oq_tech_missing_mode` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` / `oq_scan_missing_query`. Required ONLY under `--auto`; standalone invocations may emit informationally.

## Memory layer (v1.6+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), participates in mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| At Step 0.5-0.7 flag setup | `~/.mega-sdd/memory/preferences.md` | Update flag tally: increment count for the picked value (OUTPUT_MODE, PRD_STATUS, IMPLEMENTATION_MODE, PROJECT_SHAPE) |
| After OQ auto-classifier runs (Step 3.5) | `<vault>/.memory/classifier-accuracy.json` | Append run entry with tags_emitted + user_overrides (when user flips a tag in review) + accuracy_estimate |

### Reads

| What | Source | How used |
|---|---|---|
| Past flag picks for this user | `~/.mega-sdd/memory/preferences.md` | At Step 0.5-0.7: SUGGEST default by pre-filling AskUserQuestion. Surface as "Past observed default: <value> (picked N/N times). Use? Y/N/Other" |
| Project conventions (test framework, naming) | `<project>/.mega-sdd/memory/conventions.md` | At Step 2 extraction: when generating tech OQs about conventions, set `resolution_mode: scan` with `scan_query: codebase-map §<convention>` (instead of `recommend`) since the convention is already established |
| Past classifier overrides on same pattern | `<vault>/.memory/classifier-accuracy.json` | If past pattern shows consistent override `tech/recommend → business/blocking`, bias new classifier toward `business/blocking` (per learning-rules.md §2.1) — SUGGEST not impose |

### Anti-halu rails

- All flag suggestions surface via AskUserQuestion; user picks final value
- Convention-derived OQ downgrades cite the convention entry in OQ rationale
- Classifier biases never bypass the heuristic table; they pre-rank options for review
- `--memory-off` disables both reads and writes

## Halt conditions (Iter 28 — Step 0.9 scope detection)

Three halts fire during Step 0.9 (scope detection + filtering). All classified as ALWAYS STOP CHAIN by `orchestrate-flow` (require human input — see `orchestrate-flow/SKILL.md` halt taxonomy v2.4.1+).

### `scope_not_declared_in_prd`

Fires when: `--scope=<id>` flag set BUT id not in PRD's `scopes:` frontmatter declared list.

```yaml
blocker:
  type: scope_not_declared_in_prd
  context: "Step 0.9 scope picker"
  requested_scope: "<id from flag>"
  declared_scopes: ["<id1>", "<id2>", ...]  # from PRD frontmatter
  options: ["re-pick-from-declared", "cancel"]
  resolver_route: user
```

User options: re-pick valid scope from PRD declared list OR cancel.

### `prd_no_scopes_block_user_rejected_retrofit`

Fires when: PRD frontmatter lacks `scopes:` block AND user rejected AI retrofit bridge AND chose cancel option.

```yaml
blocker:
  type: prd_no_scopes_block_user_rejected_retrofit
  context: "Step 0.9 retrofit bridge"
  prd_path: "<path>"
  options: ["manual-retrofit", "single-scope-fallback", "cancel"]
  resolver_route: user
```

User options: manually retrofit PRD with scopes frontmatter OR fall back to legacy single-vault flow OR cancel.

### `prd_retrofit_low_confidence`

Fires when: AI retrofit subagent returned `overall_confidence: LOW` per `references/legacy-retrofit-prompt.md` output schema.

```yaml
blocker:
  type: prd_retrofit_low_confidence
  context: "Step 0.9 retrofit AI subagent returned LOW confidence"
  detected_scopes: ["<id1>", "<id2>"]  # subagent's best guess
  overall_confidence: LOW
  warnings: ["<from subagent>", ...]
  options: ["accept-anyway", "single-scope-fallback", "cancel"]
  resolver_route: user
```

User options: accept retrofit despite LOW confidence (review per-scope manually after vault generation) OR single-scope fallback OR cancel.

### Back-compat note

Pre-v1.12 vaults / pre-Iter-28 PRDs never trigger these halts (scope detection runs only when `scopes:` block present OR retrofit bridge engaged).

## References

- `references/templates/` — scaffolds for each of the 7 files. Read these before drafting.
