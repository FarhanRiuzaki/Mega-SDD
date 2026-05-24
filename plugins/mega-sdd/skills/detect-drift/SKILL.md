---
name: detect-drift
version: 1.4.0
description: Detects drift between a `mode=existing` vault (the "should be" state) and the live codebase (the "as is" state). Heuristic scan of entities, flows, decisions, API surface; produces a structured DRIFT-REPORT.md with confidence-rated findings and offers interactive resolution. Triggers — "drift detect", "vault vs code", "check codebase against vault", "cek code vs vault", or paraphrases.
---

# Drift Detect — vault vs live codebase reconciliation

For revamp / extension projects (`mode=existing` in the vault), the vault represents the target spec and the live codebase represents current reality. They drift apart — silently. A field gets renamed in code but not in vault. A flow gets a new step that violates a vault decision. A new endpoint ships without an ADR. By the time anyone notices, fixing the drift is expensive.

This skill scans the codebase, compares it to the vault, and produces a structured drift report. Findings are heuristic (high recall, decent precision) — the report is a **starting point for review**, not a verdict.

> **Skill instruction language**: this skill is written in English for reasoning quality. Drift findings (entity names, file paths, line numbers) are recorded verbatim from the codebase; rationale prose follows the vault's language.

## When to use this skill

Trigger this skill when:

- Vault is `mode=existing` and the user wants a sanity check that the codebase still matches.
- The user says "drift detect", "vault vs code", "check codebase against vault", "cek code vs vault", "is the code in sync?", or paraphrases.
- Before locking the vault for a milestone — confirm the vault accurately describes what's actually shipped.
- After a long sprint where many PRs landed — periodic reconciliation.
- When onboarding a new dev who needs to understand "what's actually true vs what's documented".

Do NOT use this skill when:

- Vault is `mode=new` — there's no live codebase to drift against. The skill bails with a hint to use `diff-vault` if comparing two PRDs.
- The user wants vault evolution from a new PRD — that's `diff-vault`.
- The codebase isn't accessible (different repo, no permissions) — skill needs `Read` access to scan.

## Core principle

> **The vault is one ground truth. The code is another. When they disagree, surface it — don't pick a side.**

Drift can mean two things:
1. **Code is right, vault is stale** → update vault (typically via `diff-vault` if PRD also changed, or directly via `Edit`).
2. **Vault is right, code regressed** → fix code in a PR.

The skill never assumes which side is correct. Findings come with **direction-neutral framing**: *"vault says X, code does Y, here's where each lives"* — and the user (with their team) decides the action.

## Drift outcome categories

Each finding lands in one of these:

| Category | What it means | Example |
|----------|---------------|---------|
| **Missing in code** | Vault references entity / flow / endpoint / decision that has no analog in codebase. | Vault `mega_rencana_account` table, no migration / model found. |
| **Missing in vault** | Code has entity / flow / endpoint that's not documented in vault. | Codebase has `app/Jobs/CleanupOrphanRecords.php`, no flow F-S-* in vault. |
| **Name drift** | Same concept, different name. Vault and code refer to the same thing with different identifiers. | Vault `failed_debit_count`, code `failed_attempts`. |
| **Type drift** | Same field name, different type / constraints. | Vault `failed_debit_count int`, code `failed_attempts varchar`. |
| **Behavior drift** | Same flow ID, but steps in code differ from vault description. | Vault F-S-001 step 3 says "call Host", code calls a 3rd-party adapter first. |
| **Decision violation** | Code violates a vault ADR (`D-XXX`). | Vault D-007 says "no JOIN AND accounts as autodebet source", code filter only excludes `dormant`. |
| **Decision unwritten** | Code embodies a decision that's not captured as an ADR. | Code uses idempotency keys with 24h TTL — no `D-XXX` for it in vault. |
| **Confirmed match** | Vault says X, code does X. (Surfaced in summary, not detailed in report.) | — |

Each finding carries a **confidence**: `high` (exact name + type match found / not-found), `medium` (similar names but different signatures), `low` (heuristic guess based on keyword search).

## --auto flag (v0.3+)

The `--auto` flag is passed by upstream callers (typically `/mega-sdd:orchestrate-flow`) to skip logistical prompts and the optional Step 5 interactive walkthrough.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (vault path) | Ask | Auto-detect from CWD if exactly 1. |
| Step 0 (codebase path) | Ask | If CWD obviously a code repo (has `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / `go.mod`), use CWD. Otherwise REQUIRE explicit arg — never guess. |
| Step 0 (mode=new bail-out) | Surface migration trigger | Same — but emit `blocker` (type=`drift_framework_mismatch` if trigger isn't detectable, OR refuse cleanly with a structured message). |
| Step 0.5 (drift scope) | Ask | Default to `full`. |
| Step 1.5 (framework detection) | Auto-detect, propose scope dirs, ask user to confirm | Auto-confirm if confidence high (single framework signature found). If multi-framework or ambiguous → emit `blocker` (type=`drift_framework_mismatch`). |
| Step 5 (interactive walkthrough) | Ask "walk now / save report only / cancel" | **Skip walkthrough.** Write `DRIFT-REPORT.md`. Surface top 3 PRIORITY-1 findings in chat. **Do NOT generate `DRIFT-ACTIONS.md`** — the action list is a deliberate human decision. |

What stays interactive even with `--auto`:

- **Major framework mismatch warning** — when vault implies one stack but codebase is another (e.g., vault says Java/Spring, code is PHP). Emits `blocker` per Step 0/1.5. Never assume vault is wrong.
- **mode=new bail-out** — detect-drift refuses cleanly when vault is `mode=new`; this is a hard rule that `--auto` doesn't change.

### `drift_framework_mismatch` blocker emission

When framework detection fails or finds a mismatch with vault expectations:

```yaml
blocker:
  type: drift_framework_mismatch
  tag: n/a
  priority: n/a
  context: "<e.g. 'detect-drift Step 1.5: vault implies Java/Spring per 02-architecture; codebase is PHP/Laravel per composer.json'>"
  resolver_owner: null
  resolver_route: null
  vault_version: "<current>"
  source_skill: detect-drift
  detected_framework: "<e.g. 'PHP/Laravel'>"
  expected_framework: "<e.g. 'Java/Spring'>"
```

After emit, the skill stops. No `DRIFT-REPORT.md` is generated for the mismatched scope. Caller decides whether to override scope or correct vault.

What `--auto` does NOT do:

- ❌ Generate `DRIFT-ACTIONS.md` (deliberate human decision; `--auto` only writes reports).
- ❌ Modify vault content (detect-drift is read-only by design).
- ❌ Open PRs or run code changes.

When this skill is invoked without `--auto`, behavior is unchanged from v0.2.

---

## Workflow

### Step 0: Inputs (MANDATORY)

1. **Vault path** — auto-detect from CWD (looks for the 7 standard files). Verify `00-index.md` Vault Lock Status has `Implementation mode: existing`.
   - If `Implementation mode: new` → STOP. Surface the `mode_migrate_after` field (v0.11) from Vault Lock Status if present: *"This vault is `mode=new`. Migration trigger declared: `<event>`. If that trigger has fired (first commit landed on main, first deploy, etc.), flip mode to `existing` first — edit `00-index.md` Vault Lock Status + add Changelog entry + bump vault version, OR run `/mega-sdd:diff-vault`. Then re-run detect-drift."*
   - If `mode_migrate_after` is missing or null and mode=new → suggest the user define a trigger before re-running.
2. **Codebase path** — root of the live codebase repo (typically the project root or a subdirectory).
   - **Claude Code**: use `AskUserQuestion` with options like `["Use CWD as codebase root", "Specify subdirectory", "Different path"]`.
   - Fallback: ask plainly — *"Path to codebase root? (must contain the live source for the project this vault describes)"*
3. **Scope hints** (optional but recommended) — let the user narrow the scan:
   - Backend dir(s): `app/`, `src/`, `pkg/`, `internal/`
   - DB migrations dir: `database/migrations/`, `db/migrate/`, `prisma/migrations/`
   - Routes / controllers: `routes/`, `app/Http/Controllers/`
   - Jobs / cron: `app/Jobs/`, `app/Console/Commands/`
   - Frontend (if applicable): `resources/`, `frontend/`, `src/components/`
   - Skill auto-detects framework first (see Step 1.5) and proposes defaults; user confirms or overrides.
4. **Persist** inputs:
   - `VAULT_DIR=<absolute>`
   - `CODE_DIR=<absolute>`
   - `SCOPE_DIRS=<comma-separated list>` (after Step 1.5 detection)
5. **Git safety**: run `git status` in codebase. If uncommitted changes exist, note in the report (the drift report's findings are based on current working tree, not last commit).

> Skill never proceeds to Step 0.5 without verified inputs and `mode=existing` confirmed.

### Step 0.5: Drift scope (MANDATORY)

Ask the user which axes to scan:

- **`full`** (default) — entities, flows, endpoints, decisions, all docs. Slowest but most complete.
- **`schema-only`** — entities + DB-level constraints only. Fast, useful before a migration review.
- **`flows-only`** — flow IDs + endpoints + jobs. For runtime correctness check.
- **`decisions-only`** — ADRs vs code patterns. Slowest precision, useful when reviewing architecture compliance.
- **`single-doc`** — drift only for a specific vault doc (e.g., "just `03-data-model.md`").

Persist: `DRIFT_SCOPE=<choice>`.

### Step 1: Read vault

Read the relevant vault docs based on scope:
- `schema-only` → `03-data-model.md` only.
- `flows-only` → `04-flows.md` + `02-architecture.md` (for endpoint contracts).
- `decisions-only` → `05-decisions.md`.
- `full` → all 6 numbered docs.

Build internal model: list of entities (with field signatures), list of flow IDs (with steps), list of endpoints, list of ADRs (with constraints to verify).

### Step 1.5: Codebase framework detection

Run heuristics to detect the codebase framework so the scan targets the right files:

- `composer.json` → PHP. Look for Laravel (`laravel/framework`), Symfony, etc.
- `package.json` → Node. Look for Next.js, NestJS, Express, etc.
- `Gemfile` → Ruby. Rails / Sinatra.
- `go.mod` → Go.
- `requirements.txt` / `pyproject.toml` → Python. Django / FastAPI / Flask.
- `pom.xml` / `build.gradle` → Java. Spring / Spring Boot.
- `Cargo.toml` → Rust.
- Mobile: `ios/Podfile` + `android/app/build.gradle` → React Native or native split.
- Mobile: `pubspec.yaml` → Flutter.

Display detected framework + propose default scope dirs. User confirms or overrides.

If detection is ambiguous (e.g., monorepo with multiple frameworks), ask user explicitly which subproject to scan.

### Step 2: Scan codebase

Use `Bash` (grep, find), `Glob`, and `Read` to extract:

#### Entities (for `schema-only` and `full` scope)

- **Migrations**: search for `CREATE TABLE` statements, `Schema::create`, `up()` migrations, Prisma schema, etc.
- **Models / ORM definitions**: framework-specific (e.g., Laravel `app/Models/*.php`, Rails `app/models/*.rb`, Prisma `schema.prisma`, Sequelize/TypeORM model files).
- For each detected entity in code: capture name + fields + types. Store in code-side model.

#### Flows / endpoints (for `flows-only` and `full` scope)

- **Routes**: `routes/*.php`, `config/routes.rb`, `app.use()`, Express `router.METHOD()`, FastAPI `@app.get()`, etc. Extract endpoint paths + HTTP methods.
- **Jobs / cron**: `app/Jobs/`, `app/Console/Commands/`, `cron.yaml`, `schedule:run`, `whenever`, etc.
- **Controllers / handlers**: link endpoints to handler functions. Capture method names; first-line summary if doc-comment exists.

#### Decisions (for `decisions-only` and `full` scope)

- For each ADR `D-XXX` in `05-decisions.md`, parse the **decision statement** + **constraints** (e.g., D-007: filter excludes `dormant | inactive | restricted | frozen | closed` and JOIN AND).
- Search codebase for keywords from the decision: status enum values, function names, configuration constants.
- Heuristic: if all keywords from the decision appear together in a single file/function, presume the decision is implemented. If keywords appear partially, flag as `Decision violation` candidate.
- This step has the lowest confidence — flag findings as `medium` or `low` and recommend human verification.

#### Open Question references

- Search the codebase (commits, comments, PR descriptions if `git log` is accessible) for `OQ-{CODE}-{N}` patterns.
- Cross-reference with vault: which OQs are referenced in code? Are any of those still `[ ]` open? If so → flag as "code references unresolved OQ".

### Step 3: Compute drift

For each axis, compare vault model vs code model. Output is a list of findings, each with:
- Category (Missing in code / Missing in vault / Name drift / Type drift / Behavior drift / Decision violation / Decision unwritten)
- Vault reference (doc + section + line/identifier)
- Code reference (file path + line range, when applicable)
- Confidence (high / medium / low)
- **Severity (v1.2.1+ Iter 25 — mutability-tier-aware)**:
  - **CRITICAL** — drift on a vault claim where `mutability_source: kb_locked` (regulatory / contractual lock per Iter 22). Rebuild MUST preserve 1:1; any drift here is a compliance / contract risk.
  - **HIGH** — drift on a CONFIRMED claim with no mutability source OR `mutability_source: kb_intent` where outcome changed (not just implementation)
  - **MEDIUM** — drift on `mutability_source: kb_intent` where implementation changed but outcome preserved (acceptable per design freedom)
  - **LOW** — drift on `mutability_source: kb_artifact` (legacy artifact already flagged as discardable; drift may be a partial cleanup)
- Suggested action (informational only — user decides)

Pre-v1.4 vaults without `mutability_source` annotations → all drift treated as severity HIGH (safe conservative default).

### Step 4: Generate `DRIFT-REPORT.md` artifact

Write the report to `<VAULT_DIR>/DRIFT-REPORT.md` (overwrites if exists).

Structure:

```markdown
# Drift Report

**Vault**: v{X.Y} (last updated YYYY-MM-DD; mode `existing`)
**Codebase**: <CODE_DIR> (commit `<short SHA>` if git, else "current working tree")
**Framework detected**: <e.g., Laravel 11 + Vue 3>
**Drift scope**: <full | schema-only | flows-only | decisions-only | single-doc>
**Generated**: YYYY-MM-DD HH:MM

## Summary

| Category | High | Medium | Low | Total |
|----------|-----:|-------:|----:|------:|
| Missing in code | {n} | {n} | {n} | {n} |
| Missing in vault | {n} | {n} | {n} | {n} |
| Name drift | {n} | {n} | {n} | {n} |
| Type drift | {n} | {n} | {n} | {n} |
| Behavior drift | {n} | {n} | {n} | {n} |
| Decision violation | {n} | {n} | {n} | {n} |
| Decision unwritten | {n} | {n} | {n} | {n} |
| **Confirmed match** | — | — | — | **{n}** |

> **Confidence legend**:
> - **High**: exact name match (or unambiguous absence). Action recommended.
> - **Medium**: similar names but signatures differ, or partial pattern match. Verify before action.
> - **Low**: heuristic keyword guess. Always verify manually before acting.

## Decision violations & decision unwritten (PRIORITY-1)

> These findings most often correspond to compliance / architectural debt. Review first.

### D-007 — possible violation (confidence: medium)

**Vault constraint** (`05-decisions.md` D-007): "Source account filter must exclude statuses `dormant | inactive | restricted | frozen | closed` AND exclude `JOIN AND` account type."

**Code reference**: `app/Services/SourceAccountFilter.php` line 23-31:
```php
return $accounts->where('status', '!=', 'dormant')
                ->where('status', '!=', 'inactive')
                ->get();
```

**Drift**: code only filters 2 statuses out of 5; no JOIN AND check found in this file or referenced files.

**Suggested action**:
- (A) **Fix code**: extend filter to match vault. Open PR.
- (B) **Update vault**: if filter scope was intentionally narrowed (per stakeholder), update D-007 with new constraints + Changelog entry. Use `diff-vault` if it traces to a PRD revision.
- (C) **Defer**: capture as new OQ for stakeholder review.

### Decision unwritten #1 (confidence: high)

**Code reference**: `app/Services/IdempotencyService.php` line 12 — defines TTL = `24 * 60 * 60` seconds (24h).

**Drift**: idempotency strategy is implemented in code but no `D-XXX` ADR captures it in the vault.

**Suggested action**:
- (A) **Promote to ADR**: add new `D-XXX` to `05-decisions.md` with current implementation as the decision + cite `app/Services/IdempotencyService.php` as Source.
- (B) **Defer**: capture as `OQ-DC-{next}` for explicit stakeholder confirmation before formalizing.

<...>

## Schema drift

### Missing in code: `monthly_failed_debit` (confidence: high)

**Vault reference**: `03-data-model.md` Entities (DBML).
**Code search**: no `monthly_failed_debit` migration found in `database/migrations/`. No model found in `app/Models/`. No type definition in `database/types/`.

**Drift**: vault entity is not implemented.

**Suggested action**:
- (A) **Implement**: create migration + model.
- (B) **Update vault**: if entity is no longer needed, mark as Removed in vault per `diff-vault` removal convention.
- (C) **Defer**: schedule into roadmap.

### Type drift: `failed_debit_count` (confidence: high)

**Vault** (`03-data-model.md` `mega_rencana_account` table): `failed_debit_count int [default: 0]`.
**Code** (`database/migrations/2026_03_15_create_mega_rencana_accounts.php` line 42): `$table->string('failed_attempts')->default('0');`.

**Drift**: name (`failed_debit_count` vs `failed_attempts`) and type (`int` vs `varchar`).

**Suggested action**:
- (A) **Migrate code**: rename column + change type. New migration.
- (B) **Update vault**: if `failed_attempts` (string) is intentional, update vault entity definition + add ADR explaining why string was chosen.

<...>

## Flow drift

### Missing in code: F-S-004 `account_closure_runner` (confidence: medium)

**Vault reference**: `04-flows.md` Backend / system flows.
**Code search**: no class / file matches `account_closure_runner` or `AccountClosure` patterns. Closest match: `app/Jobs/CloseInactiveAccountsJob.php` — name resembles concept but logic differs.

**Drift**: vault flow may not be implemented, OR it's implemented under a different name (`CloseInactiveAccountsJob`).

**Suggested action**:
- (A) **Verify**: read `CloseInactiveAccountsJob.php` and confirm whether it implements F-S-004 logic. If yes → name drift, update vault to cite this file.
- (B) **Implement**: if F-S-004 is missing, create the job per vault spec.

### Missing in vault: `app/Jobs/RecalculateInterestJob.php` (confidence: high)

**Code reference**: scheduled job runs daily at 02:00. Reads `mega_rencana_account` table, recomputes interest accrual.

**Drift**: code has a flow that's not described in `04-flows.md`.

**Suggested action**:
- (A) **Add to vault**: create new flow `F-S-{next}` documenting this job. Note source: code-as-built (no PRD reference).
- (B) **Remove from code**: if this job was added by mistake or is no longer needed.

<...>

## Endpoint drift

<API contracts vs route definitions>

## Confirmed matches

> Listed for completeness, no action needed.

- ✓ `mega_rencana_account` entity present in `app/Models/MegaRencanaAccount.php` and matches DBML schema in `03-data-model.md`.
- ✓ `F-U-001` apply flow implemented in `app/Http/Controllers/MegaRencanaController.php@apply` per vault.
- <...>

## Notes & caveats

- Detection is **heuristic**. Low-confidence findings can be false positives — verify before acting.
- Decision detection uses keyword search on ADR constraints; semantic analysis is limited. Treat decision violations as triggers for human review, not verdicts.
- Codebase scan covered: <list of dirs scanned>. Excluded: <list of dirs skipped, e.g., test files, vendor>.
- If findings seem off (e.g., framework mis-detected), re-run with explicit `SCOPE_DIRS` override.
```

> The report is the artifact. Step 5 walks it interactively to capture user decisions per finding.

### Step 5: Interactive walkthrough (optional)

Ask user via `AskUserQuestion`: `["Walk findings now (interactive)", "Save report only — review offline first", "Cancel"]`.

If interactive:

1. Walk findings in priority order: Decision violations / unwritten → Schema drift (high confidence) → Flow drift (high) → others.
2. Per finding, show the entry + present the suggested actions as `AskUserQuestion` options.
3. Capture user's chosen action. The skill does NOT execute the action automatically (e.g., creating a PR or writing migrations is out of scope) — it captures the decision into a follow-up `DRIFT-ACTIONS.md` file:

```markdown
# Drift Actions — chosen YYYY-MM-DD

## Code-side actions (assign to engineering)

- **D-007 violation**: extend `app/Services/SourceAccountFilter.php` to match D-007 constraints. Owner: <BE Lead>.
- **Type drift `failed_debit_count`**: new migration to rename + change type. Owner: <BE>.
- <...>

## Vault-side actions

- **Decision unwritten (idempotency)**: promote to new ADR. Action: edit `05-decisions.md` directly OR run `resolve-oq` if there's a corresponding `OQ-DC-N` open.
- **Missing flow `RecalculateInterestJob`**: append new `F-S-{next}` to `04-flows.md`.
- <...>

## Deferred

- <findings the user marked as "review later">
```

4. Write `DRIFT-ACTIONS.md` to vault directory.

If non-interactive: skip Step 5; user reviews `DRIFT-REPORT.md` offline and acts manually.

### Step 6: Update vault metadata (only if interactive walkthrough captured vault-side actions)

If the user chose any vault-side actions:

1. Append a Changelog entry in `00-index.md`:

```markdown
### v{X.Y} ({YYYY-MM-DD})

Drift detection performed against codebase at <commit SHA / "current working tree">.

- **Findings**: {N} total ({M} high-confidence, {L} medium, {P} low).
- **Vault-side actions queued** (see `DRIFT-ACTIONS.md`):
  - Update D-007 constraints to match new code intent.
  - <...>
- **Code-side actions queued**: see `DRIFT-ACTIONS.md`.
- **Note**: this entry records the drift session; vault content not modified yet. Apply vault-side actions via direct edits or `resolve-oq` for OQ-tagged items.
```

2. Update `Last updated` date.

3. Do NOT bump vault version yet — version bump happens when actions are actually applied to vault content.

### `vault.json` reconciliation boundary (v0.13)

`detect-drift` deliberately does NOT regenerate `vault.json`. The skill's core principle is *"no code execution, write reports only"* — auto-reconciling the manifest would contradict that.

**What this means in practice:**

- When the user accepts a vault-side action that *would* alter vault content (e.g., "promote unwritten decision to ADR"), the actual vault edit happens later, via `resolve-oq` (for OQ-tagged items) or direct manual edit followed by re-running `generate-intent` to regenerate the full vault.
- Until the edit lands and a regen runs, `vault.json` stays at the pre-drift-session state. AI consumers loading the manifest will not see the proposed-but-unlanded changes.
- The Changelog entry written in step 1 above flags this — it records the drift session, not vault content changes. Vault version stays unchanged.
- If a later manual edit lands the proposed change, the user is responsible for triggering `vault.json` regeneration: easiest path is to edit the markdown then re-run `/mega-sdd:generate-intent` against the same PRD with the same flags, OR use `resolve-oq` if the change is OQ-driven (resolve-oq writes back vault.json automatically).

**Why this is acceptable**: detect-drift findings are always advisory. The action list in `DRIFT-ACTIONS.md` makes the boundary explicit so the user knows what's tentative vs landed.

### Step 7: Self-check before delivery

- [ ] `mode=existing` confirmed before scan started.
- [ ] Framework detected (or user confirmed override). Scope dirs documented in report.
- [ ] Every finding has: category, vault reference, code reference (when applicable), confidence rating.
- [ ] No finding silently filed as "confirmed match" without reasoning visible in the report.
- [ ] Decision violations / unwritten section appears at top of report (PRIORITY-1).
- [ ] If interactive walkthrough ran: every finding ended in an action choice or explicit defer.
- [ ] Skill did NOT execute code changes (writing migrations, opening PRs) — only captured the decisions.
- [ ] `DRIFT-REPORT.md` written; if interactive, `DRIFT-ACTIONS.md` written.

### Step 8: Present summary

1. Total findings + breakdown by category and confidence.
2. Top 3 PRIORITY-1 (Decision violations / unwritten) findings with one-line each.
3. Path to `DRIFT-REPORT.md` (and `DRIFT-ACTIONS.md` if walkthrough ran).
4. Suggested next step:
   - For vault-side actions: edit directly or use `resolve-oq` for OQ-tagged items.
   - For code-side actions: assign to engineering team; PRs can cite drift findings (e.g., "Fixes drift identified in DRIFT-REPORT.md D-007 violation").
   - For periodic checks: re-run after major sprints.

Do NOT pad with "I have completed the scan..." preamble.

---

## Limitations (be honest about these)

- **Heuristic detection**, not static analysis. The skill grep-and-reads; it does NOT build an AST or run type-checking. False positives and false negatives both happen.
- **Semantic equivalence is hard**. `MegaRencanaAccount` (vault) vs `MegaRencanaAccountModel` (code) — same concept, different name. Skill flags as Name drift; user must confirm equivalence.
- **Decision compliance is the lowest-confidence axis**. Many decisions are implemented across multiple files / layers; keyword-based detection only catches obvious cases. Use this category as a *trigger for human review*, not a verdict.
- **Codebase size limits**. For very large monorepos (>1000 files in scope), scan time and accuracy both degrade. Recommend narrowing scope via `SCOPE_DIRS` to the most relevant subdirectories.
- **Not a replacement for code review or tests**. Drift detection complements them — it catches divergence between docs and code that neither code review nor tests typically check.

## Quality bar

- **Direction-neutral framing**: every finding presents vault state and code state side-by-side. Skill never says "code is wrong" or "vault is stale" — only "they disagree, here's where".
- **Confidence labels mandatory**: every finding has high / medium / low. Low-confidence findings carry an explicit "verify manually" caveat.
- **No silent dismissal**: if a finding is a confirmed match, it's listed in the "Confirmed matches" section so reviewers know it was evaluated, not skipped.
- **No code execution**: the skill writes report files. It does NOT modify codebase files, open PRs, run migrations, or alter the vault directly. All actions are captured in `DRIFT-ACTIONS.md` for human follow-up.
- **Idempotency**: re-running with no changes to vault or code regenerates an identical report.

## When to push back on the user

### Always

- **Vault is `mode=new`** → STOP. Tell the user: *"This vault is `mode=new` — there's no live codebase to drift against. Use `diff-vault` if comparing two PRD versions, or generate a `mode=existing` vault first."*
- **Codebase path doesn't exist or has no recognizable code** → STOP. Ask user to verify path.
- **User asks the skill to apply fixes** → refuse politely. The skill captures decisions; engineering / vault edits are deliberate human actions. Offer: "I can write up the action list as `DRIFT-ACTIONS.md` so your team can pick up the work — that's the boundary."
- **Major framework mismatch** (e.g., vault implies a backend in Java but `composer.json` says PHP) → flag inconsistency. The vault may have been generated against a different repo or the codebase may have been rewritten. Confirm before scanning.

### Conditional

- **Scope too large** (>10k files in selected dirs) → recommend narrowing scope or running per-subdirectory. Don't refuse, but warn that accuracy degrades.
- **Many low-confidence decision findings** (>10) → recommend running `decisions-only` scope with narrower codebase scope (e.g., just service / domain layer). Reduces noise.
- **Vault has lots of unresolved OQs** (>20 P1 still open) → recommend running `resolve-oq` first. Drift detection against an unresolved vault produces noisier findings (vault doesn't yet say what code should do, so divergence is expected).

---

## Constitution drift detection (v1.2+, Iter 20 — closes Iter 17 Bug 3)

Per `generate-intent/references/vault-contract.md` §constitution. When `<vault>/constitution.md` exists, detect-drift extends scan to validate code against constitution clauses (in addition to existing vault-claim drift detection).

### Procedure additions

After existing drift scan (entities, flows, decisions):

1. **Read constitution.md** + constitution_hash from vault.json
2. **Validate constitution hasn't drifted from binding**:
   - Compute current sha256 of constitution.md
   - Compare to binding.md's `constitution_hash` (per Iter 20 bind-codebase v1.8+)
   - If mismatch → halt `constitution_drift_detected` (constitution changed since last binding; re-bind needed)
3. **Scan code for clause violations** (§A through §F):
   - For each constitution clause with mechanically-detectable pattern → run ast-grep or regex probe
   - Non-detectable clauses (prose-only) → flag as "manual review needed" in drift report
4. **Categorize findings**:
   - `constitution_violation_critical` — §B Security, §F Compliance violations → halt-equivalent
   - `constitution_violation_standard` — §A Coding, §C Architecture, §E Performance violations → warning in drift report
   - `constitution_violation_advisory` — §D Anti-patterns → flag for review (not halt)

### Halt YAML for constitution_drift_detected

```yaml
blocker:
  type: constitution_drift_detected
  emitted_at: <ISO8601>
  emitted_by: detect-drift
  details:
    constitution_hash_at_binding: <sha256>
    constitution_hash_current: <sha256>
    binding_dated: <ISO8601 from binding.md>
    constitution_modified_at: <ISO8601 from fs mtime>
  next_action: "Constitution.md modified since last binding. Re-run /mega-sdd:bind-codebase to refresh binding under new constitution OR revert constitution.md to match binding state."
```

### Drift report extension

`<vault>/drift-report.md` gains new `## Constitution Findings` section:

```markdown
## Constitution Findings

### Critical violations (§B Security, §F Compliance)
- src/Http/Controllers/UserController.php:45 violates §B-001 (Sanctum auth middleware required); current uses session auth

### Standard violations (§A Coding, §C Architecture, §E Performance)
- src/Models/Order.php:78 violates §C-002 (Models MUST NOT have side effects); fires direct email

### Advisory (§D Anti-patterns)
- src/Services/SwiftDispatcher.php:120 may replicate legacy cfkdhl→CFKDDL pattern (per §D-001); manual review recommended
```

### Anti-halu rails

- Constitution detection requires `precision_tier: ast` in codebase-map (else degraded to text-grep with caveat)
- Drift findings cite specific file:line + specific clause ID
- Mechanically detectable clauses use ast-grep YAML rule (deterministic)
- Prose-only clauses flagged with `manual review needed`; NEVER fabricated violations
- `--no-constitution-drift` flag opt-out preserves pre-v1.2 behavior

### Backward compat

- v3.12 vaults without constitution.md → constitution-drift section SKIPPED gracefully
- Existing vault-claim drift detection unchanged (Iter 0 behavior preserved)

**v1.2.2+ Iter 29 scope-aware drift scanning (P2-1)**: When `vault.json` has `scope` field, drift scan defaults to scope-filtered files (only files referenced by current scope's units/binding). DRIFT-REPORT.md header includes:

```markdown
**Scope**: <vault.scope_metadata.name> (<vault.scope_metadata.id>)
**Scope-filtered drift**: yes
```

If vault has no scope (legacy single-vault), scan full codebase as before. User override: `--full-scan` flag forces full scan even on scoped vault.

Handoff YAML includes scope: block per handoff-contract.md v3.20+ when applicable.

## Handoff emission (v1.1+, Iter 15 — closes Iter 9 audit Drift D-2)

When invoked with `--auto` flag, emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: detect-drift
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to <vault>/drift-report.md>
  next_action:
    suggested_skill: mega-sdd:resolve-oq        # if drift findings need triage
    # OR
    suggested_skill: null                       # if zero drift; no follow-up
    suggested_args: ["--auto"]
    rationale: "<e.g., 'N drift findings; route via resolve-oq' OR 'Zero drift; vault + code aligned'>"
  blockers: []                                  # populated on drift_framework_mismatch
  metrics:
    items_processed: <N claims compared>
    items_blocked: <N drift findings>
  scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
    id: <scope id, e.g., "BE">
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

Status `halted` on `drift_framework_mismatch` (vault framework signal doesn't match codebase reality). Standalone invocation emits informational chat hint only.

## References

- Source vault: must be a `mega-sdd` vault with `Implementation mode: existing` in Vault Lock Status. The 7-file structure, OQ tagging convention, and ADR `D-XXX` numbering are all assumed.
- OQ tagging conventions and `vault.json` field rules: see `../generate-intent/references/vault-contract.md` (§OQ-conventions, §schema). Note: detect-drift reads vault.json but never writes to it — see "vault.json reconciliation boundary" in Step 6.
- For vault evolution from a new PRD, see `diff-vault` SKILL.md — different concern (source revisions vs codebase reality).
- For OQ resolution mechanics (when drift findings produce new OQs that need stakeholder input), see `resolve-oq` SKILL.md.

## Auto-trigger handoff (v1.4.0+, Iter 30 §6.4)

When invoked by orchestrate-flow as chain phase (auto-gate after execute-bolts batch — default-on per `orchestrate-flow/SKILL.md` §Hybrid drift gate):

a. Detect chain context: `--auto-gate` flag + presence of `<vault>/bolts/` directory with recent postflight snapshots
b. Switch to incremental mode (see §Snapshot reuse below)
c. Apply severity → chain action per `orchestrate-flow/SKILL.md` mapping:
   - CRITICAL drift on LOCKED entity → emit halt blocker; orchestrate-flow halts chain
   - HIGH drift → emit pause signal; orchestrate-flow surfaces to user
   - MEDIUM/LOW drift → log only; chain continues

When invoked standalone (`/mega-sdd:detect-drift`, no chain context): behave as v1.2.x (fresh full scan; ignore bolt snapshots).

## Snapshot reuse (v1.4.0+, Iter 30 §6.6)

Per `plugins/mega-sdd/references/shared-snapshot-schema.md`.

When invoked with `--reuse-bolt-snapshots` flag (auto-set by orchestrate-flow auto-gate):

1. For each unit in vault.json: read `<vault>/bolts/U-XXX/postflight.json` if present (must be fresher than vault.json modification time)
2. Aggregate file-level sha256 + ast_signatures across all valid postflight snapshots
3. Compare aggregated state vs vault expectations (per existing detect-drift Steps 1-4)
4. For files NOT in any bolt postflight: fall back to fresh scan (typically small remainder)
5. Performance: skip Read + ast-extract for files already captured by bolts → ~5s on 20-bolt batch vs ~28s full re-scan

Stale snapshot detection: if `postflight.json.vault_sha256` mismatches current vault.json sha256 → fresh scan for that unit's files (snapshot invalid).

## Per-bolt incremental scan mode (v1.4.0+, Iter 30 §6.4)

Used by execute-bolts per-bolt drift check (§6.4 lightweight mode). Single-bolt scope:

a. Invoked from execute-bolts with `--per-bolt --unit=U-XXX` flags
b. Compare only this bolt's target_files vs vault expectations
c. Return synchronous result (no DRIFT-REPORT.md write):
   ```
   per_bolt_drift_result:
     unit_id: U-XXX
     drift_detected: true | false
     critical_findings: [<list>]
     non_critical_findings: [<list>]
   ```
d. Execute-bolts compact streaming format renders this inline

## Suggested next actions block in DRIFT-REPORT.md (v1.4.0+, Iter 30 §6.5)

DRIFT-REPORT.md gains `## Suggested next actions` section per finding. Each finding includes:

- Finding ID + severity + entity/field affected
- Source claim mutability tier (kb_locked / kb_intent / kb_artifact / vault_locked / inferred)
- Suggested action (concrete command with pre-filled flags)
- Auto-handoff command (for chain auto-continuation when safe)

Example:

```markdown
## Suggested next actions

### Finding D-001 (CRITICAL — drift on LOCKED entity)
- Entity: `orders` table, field `amount`
- Drift: vault says `decimal(15,2)`, code is `int` after U-018
- Source claim mutability: kb_locked (BI Reg 23/2/2021 §4)
- **Suggested action**: `/mega-sdd:resolve-oq --drift D-001` — choose:
  - (a) Revert code to vault spec (preserve LOCKED contract)
  - (b) Document deviation in 05-decisions.md with ADR (audit-significant)
- **Auto-handoff command**: `/mega-sdd:resolve-oq --drift D-001 --auto`

### Finding D-002 (LOW — style drift)
- File: `app/Http/Requests/RefundRequest.php` line 12
- Drift: unused import `use App\Models\User;`
- **Suggested action**: No action needed; style fixers (Pint) catch in next cycle.
- **Auto-handoff**: chain continues automatically (no halt for LOW)
```
