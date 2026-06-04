# detect-drift — report formats

## Contents
- DRIFT-REPORT.md structure
- Per-finding examples (decisions, schema, flow)
- DRIFT-ACTIONS.md structure
- vault.json reconciliation boundary

Loaded by `detect-drift` Steps 4–6. The report IS the artifact; Step 5 walks it interactively to capture decisions.

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

Per finding: Finding ID + severity + entity/field; source-claim mutability tier (kb_locked / kb_intent / kb_artifact / vault_locked / inferred); a concrete suggested command with pre-filled flags; and (when chain auto-continuation is safe) an auto-handoff command.

```markdown
### Finding D-001 (CRITICAL — drift on LOCKED entity)
- Entity: `orders` table, field `amount`
- Drift: vault says `decimal(15,2)`, code is `int` after U-018
- Source mutability: kb_locked (BI Reg 23/2/2021 §4)
- Suggested action: `/mega-sdd:resolve-oq --drift D-001` — (a) revert code to spec, or (b) document the deviation as an ADR
- Auto-handoff: `/mega-sdd:resolve-oq --drift D-001 --auto`

### Finding D-002 (LOW — style drift)
- File: `app/Http/Requests/RefundRequest.php` line 12 — unused import
- Suggested action: none needed; style fixers (Pint) catch it next cycle
- Auto-handoff: chain continues automatically (no halt for LOW)
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

## vault.json reconciliation boundary

detect-drift deliberately does NOT regenerate `vault.json` — its core principle is "no code execution, write reports only," and auto-reconciling the manifest would contradict that.

- When the user accepts a vault-side action that would alter vault content (e.g., promote an unwritten decision to an ADR), the actual edit happens later via `resolve-oq` (OQ-tagged items) or a manual edit followed by re-running `generate-intent`.
- Until that lands, `vault.json` stays at the pre-drift state; AI consumers won't see proposed-but-unlanded changes.
- The Step 6 Changelog entry records the drift *session*, not content changes; the vault version stays unchanged.
- If a manual edit later lands the change, the user triggers `vault.json` regeneration (re-run `/mega-sdd:generate-intent` against the same PRD/flags, or `resolve-oq` for OQ-driven changes, which writes `vault.json` automatically).

This is acceptable because detect-drift findings are always advisory; `DRIFT-ACTIONS.md` makes the tentative-vs-landed boundary explicit.
