# detect-drift — report formats

## Contents
- DRIFT-REPORT.md structure
- Per-finding examples (decisions, schema, flow)
- DRIFT-ACTIONS.md structure
- Vault write-back protocol (Step 5.5)

Loaded by `detect-drift` Steps 4–6. The report IS the artifact. Since v3.0.0 detect-drift is forked + non-interactive: Step 5 **queues** direction calls to `PENDING-SYNC.md` (no walkthrough); only the `--auto-apply=safe` class is written back. `DRIFT-ACTIONS.md` and the batch-confirm ACCEPT UX below are **deprecated (v3.0.0)** — retained for reference / historical artifacts only.

## DRIFT-REPORT.md structure

Write to `<VAULT_DIR>/DRIFT-REPORT.md` (overwrites if exists).

```markdown
# Drift Report

**Vault**: v{X.Y} (last updated YYYY-MM-DD; mode `existing`)
**Codebase**: <CODE_DIR> (commit `<short SHA>` if git, else "current working tree")
**Framework detected**: <e.g., Laravel 11 + Vue 3>
**Drift scope**: <full | schema-only | flows-only | decisions-only | single-doc>
**Scope**: <vault.scope_metadata.name> (<id>)   # only when vault.json has a scope field
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

> **Confidence legend** — High: exact match or unambiguous absence (action recommended). Medium: similar names, differing signatures, or partial pattern match (verify before action). Low: heuristic keyword guess (always verify manually).

## Decision violations & decision unwritten (PRIORITY-1)

> These most often correspond to compliance / architectural debt. Review first.

### D-007 — possible violation (confidence: medium)

**Vault constraint** (`05-decisions.md` D-007): "Source account filter must exclude statuses `dormant | inactive | restricted | frozen | closed` AND exclude `JOIN AND` account type."

**Code reference**: `app/Services/SourceAccountFilter.php` line 23-31:
```php
return $accounts->where('status', '!=', 'dormant')
                ->where('status', '!=', 'inactive')
                ->get();
```

**Drift**: code filters 2 of 5 statuses; no JOIN AND check found.

**Suggested action**: (A) fix code — extend filter, open PR; (B) update vault — if the narrowing was intentional, update D-007 + Changelog (use `diff-vault` if it traces to a PRD revision); (C) defer — capture as a new OQ.

### Decision unwritten #1 (confidence: high)

**Code reference**: `app/Services/IdempotencyService.php` line 12 — TTL = `24 * 60 * 60` (24h).

**Drift**: idempotency strategy implemented in code but no `D-XXX` captures it.

**Suggested action**: (A) promote to ADR — add `D-XXX` to `05-decisions.md` citing the file as Source; (B) defer — capture as `OQ-DC-{next}`.

## Schema drift

### Missing in code: `monthly_failed_debit` (confidence: high)

**Vault**: `03-data-model.md` Entities (DBML). **Code search**: no migration / model / type definition found.
**Suggested action**: (A) implement migration + model; (B) update vault — mark Removed per `diff-vault` convention; (C) defer.

### Type drift: `failed_debit_count` (confidence: high)

**Vault** (`03-data-model.md` `mega_rencana_account`): `failed_debit_count int [default: 0]`.
**Code** (`database/migrations/..._create_mega_rencana_accounts.php` line 42): `$table->string('failed_attempts')->default('0');`.
**Drift**: name (`failed_debit_count` vs `failed_attempts`) and type (`int` vs `varchar`).
**Suggested action**: (A) migrate code — rename + change type; (B) update vault if the string is intentional + add an ADR explaining why.

## Flow drift

> When a suggested action **adds or amends a flow in `04-flows.md`**, author the flow body as a Mermaid diagram (never a prose Steps list) per the Mermaid-flows hard rule — `validate-vault-flows.sh` gates it. Read vault flows as their Mermaid nodes/edges.

### Missing in code: F-S-004 `account_closure_runner` (confidence: medium)

**Vault**: `04-flows.md` system flows. **Code search**: no match; closest `app/Jobs/CloseInactiveAccountsJob.php` (name resembles, logic differs).
**Suggested action**: (A) verify — read the closest match, confirm whether it implements F-S-004 (if yes → name drift, cite it in the vault); (B) implement per spec if truly missing.

### Missing in vault: `app/Jobs/RecalculateInterestJob.php` (confidence: high)

**Code**: scheduled daily 02:00; recomputes interest on `mega_rencana_account`.
**Suggested action**: (A) add `F-S-{next}` to `04-flows.md` (source: code-as-built); (B) remove from code if added by mistake.

## Endpoint drift

API contracts vs route definitions, same per-finding shape.

## Confirmed matches

> Listed for completeness, no action needed.

- ✓ `mega_rencana_account` present in `app/Models/MegaRencanaAccount.php`, matches DBML.
- ✓ `F-U-001` apply flow implemented in `app/Http/Controllers/MegaRencanaController.php@apply`.

## Suggested next actions

Per finding: Finding ID + severity + entity/field; source-claim mutability tier (kb_locked / kb_intent / kb_artifact / vault_locked / inferred); and the **resolution path**. detect-drift is forked + non-interactive (v3.0.0): findings are **queued to `PENDING-SYNC.md`**, never resolved inline. There is **no `resolve-oq --drift` mode** — resolve-oq resolves normal vault OQs (including any drift-CREATED `OQ-DC-N` stub, per §3.5) and does NOT consume drift findings. The resolution path is one of:

1. **Human triage of `PENDING-SYNC.md`** (§3.7) — the default; a person picks the direction (fix code vs update vault) per finding.
2. **Re-run `/mega-sdd:sync`** — re-walks drift end-to-end through the Mode D chain (scan → drift → re-bind → reconcile → execute).
3. **`--auto-apply=safe`** (§3.5) — auto-applies ONLY the narrow safe class: confidence HIGH + category ∈ {name-drift, type-drift, missing-in-vault} + claim NOT `[LOCKED]` + code side committed. CRITICAL / `[LOCKED]` drift is a compliance escalation and is NEVER `--auto-apply=safe` eligible (see §Vault write-back protocol Rails) — it always routes to human triage.

In the **sync lane** (Mode D) the chain auto-continues to claim-scoped re-bind (`bind-codebase --paths=@<vault>/.sync-changed-paths.txt`); queued drift does not stall that hop, but the moat re-blocks downstream units/bolts if re-bind surfaces a CONFLICT.

```markdown
### Finding D-001 (CRITICAL — drift on LOCKED entity)
- Entity: `orders` table, field `amount`
- Drift: vault says `decimal(15,2)`, code is `int` after U-018
- Source mutability: kb_locked (BI Reg 23/2/2021 §4)
- Resolution path: queued to `PENDING-SYNC.md` for human triage — CRITICAL drift on a `[LOCKED]` claim is a compliance escalation, NOT `--auto-apply=safe` eligible. Triage decides: (a) revert code to spec, or (b) document the deviation as an ADR; re-run `/mega-sdd:sync` after the code side is corrected.

### Finding D-002 (LOW — style drift)
- File: `app/Http/Requests/RefundRequest.php` line 12 — unused import
- Resolution path: none needed; style fixers (Pint) catch it next cycle. LOW-confidence findings are report-only (not write-back eligible), so the chain continues without a halt.
```

## Notes & caveats (report footer)

- Detection is heuristic — low-confidence findings can be false positives.
- Decision detection uses keyword search on ADR constraints; treat violations as triggers for review.
- Record which dirs were scanned vs excluded.
- If a framework was mis-detected, re-run with an explicit `SCOPE_DIRS` override.

## DRIFT-ACTIONS.md structure

Written only when the interactive walkthrough (Step 5) captures decisions. The skill records choices; it does not execute them.

```markdown
# Drift Actions — chosen YYYY-MM-DD

## Code-side actions (assign to engineering)
- **D-007 violation**: extend `app/Services/SourceAccountFilter.php` to match D-007. Owner: <BE Lead>.
- **Type drift `failed_debit_count`**: new migration to rename + change type. Owner: <BE>.

## Vault-side actions
- **Decision unwritten (idempotency)**: promote to a new ADR — edit `05-decisions.md`, or run `resolve-oq` if an `OQ-DC-N` is open.
- **Missing flow `RecalculateInterestJob`**: append `F-S-{next}` to `04-flows.md`.

## Deferred
- <findings marked "review later">
```

## Vault write-back protocol (Step 5.5 — living-vault S5)

Spec `2026-06-10-living-vault-continuous-sync-design.md` lifts the old "report-only" boundary for VAULT-side actions, with guardrails. Code-side remains untouched: the skill never edits app source (`FIX_CODE` actions stay out-of-band, tracked in `DRIFT-ACTIONS.md`).

**Per-category patch shapes** (drafted per accepted `UPDATE_VAULT` action):

| Drift category | Vault patch drafted |
|---|---|
| Name drift / Type drift (code is right) | Edit the field row in `03-data-model.md` (old value struck through in the Changelog entry, not the body) |
| Missing in vault (code has it) | New subsection in the matching doc, marked `[INTENT]`-pending — content derived ONLY from the code evidence already cited in the finding |
| Behavior drift (code is right) | Amend the flow step text in `04-flows.md` |
| Decision unwritten | Draft ADR stub in `05-decisions.md` with `status: proposed` (user promotes later) |
| Missing in code / Decision violation (vault is right) | NO vault patch — these are `FIX_CODE` directions |

**Provenance line (MANDATORY on every patch):** appended to the patched section as
`(synced from code: <short-sha> "<commit subject>" — <author>, <date>)` derived from `git log -1 --format='%h|%s|%an|%ad' -- <anchor file>`. Working-tree-only changes (no commit yet) → `(synced from working tree, uncommitted — drift session <date>)`. The provenance is the citation — a patch the skill cannot source to the finding's code evidence MUST NOT be drafted.

**Batch-confirm UX:** all drafts presented as ONE diff (per-file hunks); user choices are ACCEPT ALL / pick per-patch / REJECT ALL. Nothing is written before the explicit ACCEPT. Rejected drafts are preserved in `DRIFT-ACTIONS.md` as `proposed_patch:` blocks for later manual use.

**On ACCEPT:** apply the patches; append a `00-index.md` Changelog entry listing every patched section + provenance; bump the vault version (minor); refresh `vault.json` by running `bash <plugin>/scripts/derive-vault-json.sh --vault <vault-dir>` (W5: the script re-derives the structural mirror from the patched markdown and holds the `vault.json.lock` itself — exit 4 → `memory_in_use` halt; never hand-write vault.json). The next `bind-codebase` run then re-verdicts the patched claims (in the sync lane, `--paths` covers them automatically since their vault sections changed).

**Rails:** never auto-accept; never patch from inference (only from the finding's cited code evidence); LOW-confidence findings are NOT write-back eligible (report-only); `[LOCKED]`-tier claims are NEVER patched from code (a CRITICAL drift on a locked claim is a compliance escalation, not a sync) — surface and stop.

**No write-back path (user declines / report-only run):** behavior is unchanged from the historical boundary — the Changelog entry records the drift *session* only, the vault version stays put, `vault.json` is untouched, and `DRIFT-ACTIONS.md` keeps the tentative-vs-landed boundary explicit.
