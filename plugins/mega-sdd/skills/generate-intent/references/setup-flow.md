# generate-intent — Setup flow (Steps 0–0.9)

## Contents
- `--auto` setup behavior (quick reference)
- Step 0 — Output path setup (MANDATORY)
- Step 0.5 — Implementation mode flag
- Step 0.6 — PRD/source document status flag
- Step 0.7 — Output verbosity flag
- Squad partition
- Step 0.8 — Scan-aware context loading
- Step 0.9 — Scope detection + PRD filtering
- Multi-squad artifact emission
- Scope-detection halt conditions

> **Runtime ordering note:** the `0.x` numbering reserves slots for pre-Step-1 metadata, but **Step 0.8 (scan-aware loading) executes at RUNTIME BEFORE Step 0.9 (scope detection)** — the scope picker's smart default needs the scan-codebase result. Sequence: Step 0 → 0.5 → 0.6 → 0.7 → squad partition → **0.8** → **0.9** → Step 1.

## `--auto` setup behavior (quick reference)

`--auto` (set by `orchestrate-flow` / `/mega-sdd`) skips logistical prompts in these steps. The full table + anti-halu carve-outs are routed from the SKILL router's "Specialist references" (the `--auto`/handoff ref); the setup-specific defaults:

The per-step `--auto` defaults (Step 0 output-path, 0.5 IMPLEMENTATION_MODE, `mode_migrate_after`, 0.6 PRD_STATUS, 0.7 OUTPUT_MODE, Step 2 gap-count pause) are the canonical table in `generate-intent/references/auto-and-handoff.md` §`--auto` flag behavior — setup-flow does not restate them.

Stays interactive even with `--auto`: the Figma "do you have screenshots?" prompt (must not invent UI); destructive overwrite confirmations; `PROJECT_SHAPE` confirmation when inference confidence is low (otherwise auto-confirm). When invoked via the `Skill` tool without an explicit `--auto`, default to interactive.

## Step 0 — Output path setup (MANDATORY, before any generation)

Skill MUST get an explicit output folder path from the user before generating any file.

1. **Ask** for the output folder path; suggest a sensible default derived from the PRD project name (slug-cased).
   - **Claude Code:** `AskUserQuestion` with options like `["Use default '<slug>/'", "Custom path", "Cancel"]`.
   - **Claude.ai sandbox:** `ask_user_input_v0` if available, with the same options.
   - Fallback: ask plainly — *"Output folder path? (default: `<slug>/`)"*

2. **Detect runtime environment** before resolving the path:
   - Run `pwd && uname -a 2>/dev/null` (or equivalent).
   - **Sandbox:** pwd is `/` and `/mnt/user-data` exists → Claude.ai / Desktop sandbox (Linux container).
   - **Local:** pwd is the user's project dir, no `/mnt/user-data` → Claude Code on Mac/Linux/Windows.

3. **Resolve & sanity-check** path against environment:
   - **Relative path** (e.g. `mega-rencana-spec/`): Sandbox → `/mnt/user-data/outputs/<path>`; Local → `<CWD>/<path>`.
   - **Absolute path:**
     - Sandbox + path starts with `/Users/`, `/home/<not-claude>/`, `C:\`, `D:\`, or `~/` (non-resolvable) → **REJECT**: *"This path looks like a local Mac/Windows filesystem, but I'm running in an Anthropic Linux container. If I create it, the folder will only exist inside this container (ephemeral, lost after the session ends). Options: (a) switch to a valid container path, e.g. `/mnt/user-data/outputs/<your-folder>/`, or (b) run Claude Code on your Mac/Windows for native filesystem access."*
     - Local + path starts with `/mnt/` or `/home/claude` → **REJECT**: *"This path looks like an Anthropic container path. You're running in a local environment. Provide a local path, e.g. `/Users/<you>/projects/<folder>/`."*
     - Otherwise → use as-is.
   - **Forbidden patterns:** whitespace at edges, control chars, `..` traversal out of writable area → reject + ask again.

4. **Recheck before creating:**
   - Echo the **fully-resolved absolute path**: *"Will be created at: `<resolved-absolute-path>` — proceed?"*
   - If folder exists and non-empty: *"Folder already exists and contains files. Overwrite, append, or cancel?"* — never silently overwrite.

5. **Auto-create** once the user confirms:
   - **Mac / Linux / WSL / Git Bash:** `mkdir -p <resolved-path>`
   - **Windows native cmd.exe** (≥ Windows 7): `mkdir <resolved-path>` (auto-creates parents)
   - **Windows PowerShell:** `New-Item -ItemType Directory -Path <resolved-path> -Force`
   - Verify (`ls -la <resolved-path>` / `dir <resolved-path>`) before proceeding.

6. **Persist** the resolved path:
   - Echo a state line `OUTPUT_DIR=<resolved-absolute-path>`.
   - In every subsequent file write (Step 3, Step 5), prefix the path with **exactly** this `OUTPUT_DIR`. Do NOT default back to `/mnt/user-data/outputs/grand-design/` if the user picked something else.
   - Re-echo `OUTPUT_DIR=...` at the start of each major step as a self-reminder.

> Never proceed to Step 0.5 without a confirmed, created `OUTPUT_DIR`.

## Step 0.5 — Implementation mode flag (MANDATORY, after path setup)

The vault is a **lock against requirements** (PRD/BRD), not against an existing codebase. This skill does NOT read the codebase. The mode flag is **metadata** that tells downstream AI dev consumers (Claude Code, Cursor) how to behave when reading the vault.

1. **Ask** (`AskUserQuestion` / `ask_user_input_v0` / plain chat). Two choices:
   - **`new`** — greenfield, no existing codebase to reconcile.
   - **`existing`** — extending/modifying live code. Downstream AI consumers must verify with the user before touching existing code.

2. **Persist:** echo `IMPLEMENTATION_MODE=new | existing`. Recorded in the vault.md frontmatter lock (`implementation_mode:`).

3. **Do NOT ask** for codebase path, repo URL, or existing entity names — that is the downstream consumer's job. This skill stays focused on requirement → vault.

4. **Migration trigger** (mode=new only): a `mode=new` vault should plan its transition to `existing` because the moment real code lands it risks drifting. Capture in Vault Lock Status field `mode_migrate_after`. Defaults: `"first commit on main"` (flips once non-trivial implementation lands) / `"first prod deploy"` (after the system is observable) / `"sprint-1 demo"` (at first stakeholder review). When the trigger fires the user manually flips the flag (edit the vault.md frontmatter + Changelog + bump version) OR runs `diff-vault` with `mode=existing`. After the flip, `detect-drift` becomes applicable. For `mode=existing`, set `mode_migrate_after = null`.

> Never proceed to Step 0.6 without a confirmed `IMPLEMENTATION_MODE`.

## Step 0.6 — PRD/source document status flag (MANDATORY, after mode flag)

Controls whether the skill pauses for clarification or generates straight through.

1. **Ask.** Two choices:
   - **`final`** — signed off by stakeholder, no more edits. Skill **does NOT pause** to ask "should we clarify first?" — every gap, ambiguity, or contradiction goes straight to the Open Questions roll-up; the user triages offline post-vault.
   - **`draft`** — still in flux. Skill **may pause** when gap count is large (>10) and ask whether to proceed or send back for clarification. Default behavior.

2. **Persist:** echo `PRD_STATUS=final | draft`. Recorded in the vault.md frontmatter lock; drives Step 2 gap-handling + push-back.

3. **Implications when `PRD_STATUS=final`:** MUST NOT ask "Proceed or clarify first?" when gaps are high — proceed, dump everything to OQs. MUST NOT refuse to generate due to PRD inconsistencies — surface contradictions in OQs with both quotes side-by-side. MUST still refuse "just guess the rest" — `final` means the PRD is locked, NOT that Claude may invent; gaps stay OQs. Vault Lock Status reflects: `PRD source: <filename> (FINAL, signed-off)`.

> Never proceed to Step 0.7 without a confirmed `PRD_STATUS`.

## Step 0.7 — Output verbosity flag (MANDATORY, after PRD status flag)

Two verbosity tiers of the same vault. **Compact is the default** — token-efficient, table-heavy, cuts narrative scaffolding while preserving every source citation, every OQ, every Definition of Done. **Full** restores prose elaboration, API payload examples, and per-decision consequence bullets — useful when the vault doubles as an onboarding doc for non-technical readers.

1. **Ask** (compact recommended, listed first). Fallback: *"Output mode: `compact` (default, ~40% lighter, table-first) or `full` (verbose, prose elaboration)?"*
   - **`compact`** (default) — table-first, prose-cut, 1-line TL;DR, no boilerplate API JSON, OQ as single-line entries, decisions as 1-paragraph blurbs. **Anti-halu invariants preserved:** every source citation, every OQ tag with priority, every DoD checklist still required.
   - **`full`** — prose-rich, 3-line TL;DR header, full request/response JSON per endpoint, prose entity descriptions alongside DBML, multi-bullet ✅⚠️ consequences per ADR. For audiences with non-technical reviewers (BO, legal, compliance).

2. **Persist:** echo `OUTPUT_MODE=compact | full`. Recorded in the vault.md frontmatter lock; drives Step 3 generation per the output-mode policy in the generation guide (routed from the SKILL router).

3. **Auto-default to `compact` without asking** when: the user explicitly requested terse/minimal/token-efficient output; or runs in autonomous / no-pause mode ("proceed without asking", "lanjut tanpa nanya"). Echo: *"Auto-defaulting to `OUTPUT_MODE=compact` because <reason>. Override with `full` if you need prose."*

> Never proceed to Step 1 without a confirmed `OUTPUT_MODE`.

## Squad partition

After project shape and implementation mode are decided, ask:

> **Q (squad count):** "How many development squads will work on this project? Single-squad (1) = current default; multi-squad (≥2) enables per-squad execution via `execute-bolts --per-squad` (a main-thread loop over squads — concurrent depth-1 bolt dispatch, no squad subagent)."

If answer is `1`: skip remaining squad questions; do NOT emit `_meta/squads.yaml` or `interfaces/`; set `multi_squad_mode: false` in `vault.json`.

If answer is `≥2`:

> **Q (partition model):** "How should squads be partitioned?
>   1. layer-based  — each squad owns architectural layers from `vault.md ## Architecture` (e.g., Backend Squad, Frontend Squad, Integrations Squad)
>   2. feature-based — each squad owns one or more feature tags (e.g., Auth Squad, Billing Squad, Leave-Mgmt Squad)
>   3. hybrid       — feature wins over layer when both match"

Then per squad (loop until the user signals "done"):

> **Q (squad declaration):** "Declare a squad. Provide:
>   - id (format: squad-<kebab-case>, e.g., squad-be)
>   - label (display name, e.g., Backend Squad)
>   - ownership rules per the chosen partition model:
>     - layer: list of layer names from architecture (e.g., backend, data-model)
>     - feature: list of feature tags (e.g., auth, billing)
>     - hybrid: both"

Validate per the squad-partition rules ref (routed from the SKILL router). If validation fails (duplicate ownership, malformed id), re-ask the failed field only. After all squads are declared, emit `_meta/squads.yaml` from `templates/squads.yaml.template`, replacing `{{PROJECT_SHAPE}}`, `{{PARTITION_MODEL}}`, and `{{SQUAD_*}}` placeholders with collected answers. Set `multi_squad_mode: true` in `vault.json`.

## Step 0.8 — Scan-aware context loading

Vault generation produces fewer fabricated entities + tighter OQ classification when codebase context is available at gen-time. Probe for existing scan artifacts BEFORE Step 1 (vault structure read) and BEFORE Step 2 (extraction):

1. **Probe codebase-map.md:** `<project>/.mega-sdd/codebase/codebase-map.md` (canonical) AND `<project>/codebase-map.md` (legacy).
2. **Probe conventions memory:** `<project>/.mega-sdd/memory/conventions.md`.
3. **Probe knowledge-base:** `<project>/.mega-sdd/knowledge-base/README.md` (canonical) AND `<project>/docs/knowledge-base/README.md` (legacy).

**Detection outcomes:**

| Probe result | Action |
|---|---|
| All artifacts present | Load as context for Step 2 extraction; auto-resolve `tech/scan` OQs immediately |
| Codebase-map missing, brownfield indicators present (e.g., `.git` + existing code files) | **DEFAULT (express spine, P2): proceed map-less** — ground against `state.json` (manifests, `derived.framework_pack`) + symbol-index queries (`scripts/query-symbol-index.sh`) + targeted file probes; the `[CODEBASE: exists]` annotation and tech/scan OQ resolution come from those probes with real `file:line` citations. NO prompt, NO scan auto-invoke (scan is on-demand — the demoted phase must not be resurrected here). Under `spine: classic` only: the old prompt applies ("Run scan-codebase first?" — Y → auto-invoke; N → reduced precision). |
| Codebase-map missing, greenfield (no code) | Proceed without scan (current behavior) |
| Knowledge-base present + `--kb` flag | Already handled (KB sub-mode); KB feeds Step 2 |

**Auto-route action (classic spine only):** when the user accepts pre-scan, invoke `mega-sdd:scan-codebase` per orchestrate-flow's auto-route pattern; return to Step 1 after the scan completes. `--no-pre-scan` skips this step entirely.

**Scan context usage in subsequent steps:**

| Step | Usage |
|---|---|
| Step 2 (PRD/brief extraction) | Cross-reference PRD-mentioned entities against the codebase entity list; mark existing entities with `[CODEBASE: exists]` annotation in the vault body |
| Step 3 (write the 4 files) | Conventions section in `constraints.md` auto-populated from `conventions.md` memory; tech stack pre-filled (see the generation guide via the SKILL router) |
| Step 3.5 (OQ auto-classifier) | OQs matching codebase signals (test framework, naming, file location, error format) auto-resolved as `tech/scan` with `status: resolved` + citation; NOT surfaced as open. **Map-less (express default): the SAME resolution runs from manifest/index/file probes** — `scan_query` names the probe target (e.g. `manifest phpunit.xml`, `symbol-index LeaveRequest`), citations are real `file:line`. This matters beyond quality: an unresolved P1 tech/scan OQ trips the `oq_gate` position and inserts an interactive resolve-oq ahead of bind — the classifier resolving from probes is what keeps the express path non-stop. |
| Step 4 (self-check) | Validate entity claims don't fabricate new entities for already-existing codebase entities |

**Anti-halu rails:** scan-aware mode is OPT-IN via prompt OR auto-route, never silent; PRD precedence preserved (PRD claims OVERRIDE codebase reality — CONFLICT surfaces in the binding phase, not silenced); existing-entity awareness ADDS an annotation, does NOT replace the vault claim (architect can override); `--no-pre-scan` preserves the architect-only workflow.

## Step 0.9 — Scope detection + PRD filtering

Driven by the scope-picker ref (filter logic + memory write rules; routed from the SKILL router). Runs AFTER all Step 0.x metadata config (PRD_STATUS, OUTPUT_MODE, squad partition, scan-aware) and BEFORE Step 1 Load PRD — scope choice filters which PRD content gets loaded. `--scope=<id>` and `--greenfield` interact as documented in the `generate-intent` skill (Mode/flag detection) + `scope-picker.md`.

a. **Read PRD frontmatter.** `scopes:` block present → step b; absent → step c.

b. **Canonical scope handling:**
   - Only one scope declared → silent route to legacy single-vault flow (no picker).
   - Multiple scopes declared:
     - `--scope=<id>` set → validate against declared scopes; **halt `scope_not_declared_in_prd`** if invalid (surface the PRD-declared scope list + cancel).
     - Else if `<project>/.mega-sdd/memory/decisions.md` has a prior choice for this PRD sha256 + same cwd basename → silent default with confirm-once UX (5s timeout).
     - Else → `AskUserQuestion` with a lead line ("Memilih satu scope memfilter PRD ke bagian scope itu; scope lain bisa digenerate sebagai vault terpisah nanti."): one option per declared scope rendered as `<id> — <name/1-line summary from the PRD scopes: block>` (smart-default flagged per cwd heuristic) + "All scopes — satu vault gabungan (legacy; tidak ada filter per scope)" + "Cancel".
     - If the user chose `--scope=all` (legacy) → emit a warning, proceed with all content.
   - After scope chosen: filter PRD content per the scope-picker §Filter logic + persist the choice per its §Memory write rules (scope-picker ref, routed from the SKILL router); tag `vault.json` with `scope` / `scope_metadata` / `prd_sha256` per `generate-intent/references/multi-scope.md`; render sibling-scope informational notes in `vault.md`.

c. **Legacy PRD retrofit bridge:**
   - `AskUserQuestion`: "Yes, propose retrofit (recommended)" (dispatches an AI subagent per the legacy-retrofit-prompt ref, routed from the SKILL router) / "Treat as single-scope PRD" (legacy single-vault) / "Cancel — manual fix first" (**halt `prd_no_scopes_block_user_rejected_retrofit`**).
   - On retrofit chosen: dispatch the subagent; render the diff (detected scopes + evidence + proposed frontmatter + section restructure); `AskUserQuestion` with the glossed menu (canonical code names — `legacy-retrofit-prompt.md` mirrors these): `accept` — tulis `<prd>.retrofit.md` (original tidak disentuh), Step 0.9 restart dari file retrofit; `review per scope` — walk scope satu-satu, approve/reject per scope sebelum ditulis; `skip retrofit` — lanjut sebagai single-scope PRD tanpa filter (legacy); `cancel` — berhenti, tidak ada vault yang ditulis. On accept: write the retrofit to `<prd-name>.retrofit.md` (preserves the original); restart Step 0.9 from step a using the retrofit file. On `overall_confidence: LOW` → **halt `prd_retrofit_low_confidence`** (accept anyway / single-scope fallback / cancel).

## Multi-squad artifact emission

After the 7 prose docs + `vault.json`, if `multi_squad_mode: true`:

1. **Emit `_meta/squads.yaml`** from `templates/squads.yaml.template`, substituting `{{PROJECT_SHAPE}}`, `{{PARTITION_MODEL}}`, and per-squad `{{SQUAD_ID_N}}`, `{{SQUAD_LABEL_N}}`, ownership lists.
2. **Emit `interfaces/_index.md`** from `templates/interfaces-index.template.md`, substituting `{{VAULT_VERSION}}` and `{{PROJECT_SLUG}}`. Do NOT emit any `interfaces/<id>.md` files — those are authored manually by the architect when cross-squad contracts emerge.
3. **Emit `.obsidian/graph.json`** from `templates/obsidian-graph.json.template`, then ADD per-squad `colorGroups` entries — one per declared squad with a distinct color in order:
   - `squad-be` → `{ "a": 1, "rgb": 3911867 }` (blue: #3b82f6)
   - `squad-fe-web` → `{ "a": 1, "rgb": 11048700 }` (purple: #a855f7)
   - `squad-integrations` → `{ "a": 1, "rgb": 16330027 }` (orange: #f97316)
   - additional squads → cycle through the standard Obsidian palette.
4. **Single-squad mode:** skip steps 1–3.

After emission, suggest the next step with the squad count: "Generated vault for N squads. Next: …".

## Step 3.4 — Write constitution.md

Per `generate-intent/references/vault-contract.md §constitution`. Write the 8th vault file with project-facing rules unless `--no-constitution` is set.

1. **Extract from PRD/KB:** coding standards (PRD tech-stack + KB conventions); security baselines (PRD non-functional + KB business rules); architecture invariants (PRD architecture + KB design-decisions); anti-patterns (KB critical findings + `.mega-sdd/memory/patterns.md`); performance constraints (PRD non-functional + KB perf hints); compliance (PRD constraints + regulatory KB sections).
2. **Write `<vault>/constitution.md`** with 6 sections §A–§F (Coding standards / Security baselines / Architecture invariants / Anti-patterns / Performance constraints / Compliance).
3. **Cite a source for every clause** (anti-halu rail): `(per PRD §<section>)` OR `(per KB §<file>:<line>)` OR `(per .mega-sdd/memory/decisions.md row <N>)`.
4. **Hash pin:** `constitution_version` + `constitution_hash` land in `vault.json` via the Step-3.8 `derive-vault-json.sh` run (which runs AFTER this step, so `constitution.md` is on disk) — the script computes them fresh at initial generation (sha256 of `constitution.md` + its `**Version**` line) and CARRIES THEM FORWARD on every later derive (at-generation pin, like `prd_sha256`); never hand-write them. If constitution.md was somehow written AFTER a derive already ran (out-of-order re-run), re-run `derive-vault-json.sh --vault <OUTPUT_DIR>` so the pin is computed.
5. **Surface for sign-off:** one-line chat summary — "Constitution.md written with N clauses. Review before bolts begin: <path>".
6. **`--no-constitution`** skips this step (vault md files only); for one-off greenfield demos.

## Scope-detection halt conditions

Three halts fire during Step 0.9. All classified ALWAYS STOP CHAIN by `orchestrate-flow` (require human input). Pre-multi-scope vaults / PRDs without a `scopes:` block never trigger these (scope detection runs only when a `scopes:` block is present OR the retrofit bridge is engaged).

**Options keterangan (rendered by the halt displayer per the keterangan contract — codes stay English, descriptions Tier-2):** `re-pick-from-declared` — pilih ulang dari daftar scope yang PRD deklarasikan; `manual-retrofit` — user edit `scopes:` frontmatter di PRD sendiri lalu re-run; `single-scope-fallback` — perlakukan PRD sebagai satu scope tanpa filter (legacy); `accept-anyway` — pakai hasil retrofit LOW-confidence apa adanya (risiko pemecahan scope salah; recommended HANYA kalau warnings-nya sudah direview); `cancel` — berhenti, tidak ada vault yang ditulis.

### `scope_not_declared_in_prd`
Fires when `--scope=<id>` is set BUT the id is not in the PRD's `scopes:` frontmatter list.

```yaml
blocker:
  type: scope_not_declared_in_prd
  context: "Step 0.9 scope picker"
  requested_scope: "<id from flag>"
  declared_scopes: ["<id1>", "<id2>", ...]  # from PRD frontmatter
  options: ["re-pick-from-declared", "cancel"]
  resolver_route: user
```

### `prd_no_scopes_block_user_rejected_retrofit`
Fires when the PRD frontmatter lacks a `scopes:` block AND the user rejected the AI retrofit bridge AND chose cancel.

```yaml
blocker:
  type: prd_no_scopes_block_user_rejected_retrofit
  context: "Step 0.9 retrofit bridge"
  prd_path: "<path>"
  options: ["manual-retrofit", "single-scope-fallback", "cancel"]
  resolver_route: user
```

### `prd_retrofit_low_confidence`
Fires when the AI retrofit subagent returns `overall_confidence: LOW` per the legacy-retrofit-prompt ref's output schema (routed from the SKILL router).

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
