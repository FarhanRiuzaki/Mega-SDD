# diff-vault — VAULT-DIFF.md diff-report format

## Contents
- Output location & purpose
- Full `VAULT-DIFF.md` structure
- Per-section examples (conflicts, auto-resolved OQs, new OQs, added/changed/removed)
- Interactive walkthrough (Step 5)

Loaded by Steps 4–5. The diff report is the **artifact** the user reviews; Step 5 walks it interactively to capture decisions on conflicts and confirm changes.

## Output location & purpose

Write a structured diff report to `<VAULT_DIR>/VAULT-DIFF.md` (overwrites if exists). This artifact persists so the user can review carefully even after the chat session ends. The header carries `prd_sha256_changed: yes | no | n/a` (set during PRD change detection in Step 1.5).

## Full `VAULT-DIFF.md` structure

```markdown
# Vault Diff Report

**Old vault**: v{X.Y} (generated YYYY-MM-DD from <old PRD version>)
**New source**: <new PRD/source filename + version + date>
**Diff scope**: <full | oq-only | specific-docs>
**Generated**: YYYY-MM-DD HH:MM

## Summary

- **Auto-resolved OQs**: {N}
- **New OQs**: {N}
- **Added** (entities / flows / decisions / sections): {N} / {N} / {N} / {N}
- **Changed**: {N} / {N} / {N}
- **Removed**: {N} / {N} / {N}
- **Conflicts requiring user input**: {N} (Resolved-OQ conflicts: {X}, Decision conflicts: {Y})
- **Unchanged**: <not enumerated; majority of vault content>

## Conflicts requiring user input (PRIORITY-1)

### Resolved-OQ conflict #1: OQ-DC-2

**Original question** (vault v1.0): "Idempotency strategy for buka rekening?"
**Resolved as** (vault v1.1, on YYYY-MM-DD via resolve-oq): "Idempotency key with 24h TTL, captured as D-010 in 05-decisions.md."
**Source of resolution**: stakeholder meeting (BE Lead — Indra), no PRD reference.
**New PRD says** (§X.Y, page Z): "Idempotency must use 7-day TTL per security review."

**Conflict**: vault decision (24h TTL) contradicts new PRD (7-day TTL).

**Options**:
- (A) **Supersede**: replace D-010 with new D-NNN reflecting 7-day TTL. Old D-010 marked `Status: Superseded by D-NNN`. Recommended when new PRD reflects newer information.
- (B) **Keep vault, OOS new PRD**: retain 24h TTL as canonical, mark new PRD line as out-of-scope-for-vault with rationale.
- (C) **Capture both**: keep D-010 (24h TTL for X scenarios), add D-NNN (7-day TTL for Y scenarios), document the split.

**User decision required.** Default: (A) Supersede.

### Decision conflict #1: D-007 (rekening sumber filter)

<similar structure>

## Auto-resolved OQs

### OQ-OV-1 → answered by new PRD §E

**Original**: "Target NoA = 4.197 — per bulan or cumulative?"
**New PRD answer** (§E.2): "NoA target 4.197 cumulative by Q2 2026."
**Action on apply**: mark `[x]`, append `→ Resolved v1.2 (auto, from new PRD §E.2): cumulative by Q2 2026`.

<...all auto-resolved OQs in this format...>

## New OQs (introduced by new PRD)

### OQ-FL-12 (new)

**Source**: new PRD §G AC18-1 introduces a "redeem early" flow not present in old PRD.
**Gap**: new flow mentions early redemption but doesn't specify pro-rated interest calculation.
**Suggested priority**: P2.

<...>

## Added entities / flows / decisions

### Entity (added): `redemption_request`

**Source**: new PRD §G AC18-2.
**Suggested DBML**:
```dbml
Table redemption_request {
  id bigint [pk, increment]
  mega_rencana_account_no varchar [ref: > mega_rencana_account.account_no]
  ...
}
```
**Action on apply**: append to `03-data-model.md` Entities section.

<...>

## Changed entities / flows / decisions

### Flow F-U-001 — changed step 5

**Old (vault v1.1)**:
> 5. Sistem call BE → BE call Host buka rekening + debit setoran awal.

**New (PRD v1.1 §G AC5-2 revised)**:
> 5. Sistem call BE → BE validate KYC freshness → BE call Host buka rekening + debit setoran awal.

**Diff**: KYC freshness check inserted between BE entry and Host call.
**Action on apply**: update step 5 in `04-flows.md`. Optionally surface as new OQ if KYC freshness logic isn't specified elsewhere.

<...>

## Removed (not in new PRD)

### Flow F-S-007 — tracking event emitter (Appsflyer)

**Source in old vault**: PRD v1.0 §G AC16-1.
**Status in new PRD**: §G AC16-1 no longer mentions Appsflyer; only Insider + Firebase remain.
**Action on apply**: in `04-flows.md`, mark F-S-007 with banner `> **Removed in v1.2**: Appsflyer dropped from new PRD §G AC16-1. Insider + Firebase retained as new flow F-S-007a.`. Don't delete F-S-007 — keep for history.

<...>

## Unchanged sections (no action needed)

<list of sections that are unchanged — single line each>
```

> The diff report is the **artifact** the user reviews. Step 5 walks through it interactively to capture decisions on conflicts + confirm changes.

## Interactive walkthrough (Step 5)

Walk the diff report with the user, prioritizing **conflicts first** (PRIORITY-1 in the report).

For each conflict (Resolved-OQ conflict, Decision conflict):
1. Show the entry from the diff report.
2. Use `AskUserQuestion` with the options listed in the report (typically Supersede / Keep vault / Capture both / Skip — defer to next round).
3. Capture the user's decision. Persist in working memory.

For Auto-resolved OQs: show batch summary, ask `["Apply all", "Review one-by-one", "Skip auto-resolution this round"]`.

For Added / Changed / Removed: walk by category, batch-confirm where safe (e.g., "apply all 5 unchanged flow renames? Y/N"), one-by-one for substantive changes.

For New OQs: show list, ask the user to confirm priority assignment (P1 default) per OQ.

The user can stop at any time — partial decisions are persisted for the next run, the rest stays as `VAULT-DIFF.md` for offline review.
