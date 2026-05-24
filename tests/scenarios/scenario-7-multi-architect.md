# Scenario 7 — Multi-Architect (Multi-Scope PRD)

**Time**: 60 minutes total (20 min per architect)
**When to use**: Project where PRD is shared across multiple IT architects (BE, MW, FE) — each architect generates their own vault for their scope only

**Prerequisites**:
- Mega-sdd v3.20.0+ (Iter 28 multi-scope picker)
- Canonical PRD with `scopes:` frontmatter (or legacy PRD via retrofit bridge)
- Three separate repos (BE, MW, FE) — or three separate folders within one monorepo
- Each architect operating in their own session

## Setup (one-time, by Product Owner)

1. Product Owner writes PRD following `docs/templates/prd-template.md`
2. PRD frontmatter declares scopes block with BE, MW, FE
3. PRD shared via shared docs (Notion, Git, Drive) to all 3 architects
4. Each architect clones PRD into their working folder

```bash
# Architect BE
cd ~/projects/order-management-be/
cp ~/shared/order-mgmt-prd.md ./prd.md

# Architect MW
cd ~/projects/order-management-mw/
cp ~/shared/order-mgmt-prd.md ./prd.md

# Architect FE
cd ~/projects/order-management-fe/
cp ~/shared/order-mgmt-prd.md ./prd.md
```

## Phase 1 — Architect BE generates vault (20 min)

```bash
cd ~/projects/order-management-be/
/mega-sdd:auto ./prd.md
```

Expected output:

```
▶ Phase 0a: PRD scope detection
  Reading ./prd.md frontmatter...
  ✓ Canonical format detected (scopes: BE, MW, FE)
  Smart default: BE (cwd basename `order-management-be` matches)

❓ This vault is for which scope?
   [1] BE — Backend API (recommended)
   [2] MW — Integration Middleware
   [3] FE — Frontend Web
   [4] All scopes (single combined vault — legacy behavior)
   [5] Cancel
```

User picks `[1] BE`.

```
✓ Scope: BE locked in.
  Filtering PRD to: §Backend + universal sections §1-§7
  Sibling scopes noted: MW, FE

▶ Phase 0b: Starterkit detection (Iter 27)
  ✓ composer.json → laravel-base-26 detected

▶ Phase 1: scan-codebase ./
  Output: .mega-sdd/codebase/codebase-map.md
  §7 Framework: laravel-base-26 (pack loaded)

▶ Phase 2: generate-intent --scope=BE --scan ./prd.md
  Output: .mega-sdd/vaults/order-management-be/
  - vault.json: scope=BE, scope_metadata declared, prd_sha256 recorded
  - 00-index.md: scope header + sibling scopes (MW, FE) noted + locked contracts listed

▶ Phase 3: bind-codebase
▶ Phase 4: generate-units
▶ Phase 5: execute-bolts (auto, with halts on conflict)
```

BE architect's vault is at `.mega-sdd/vaults/order-management-be/`. 00-index.md shows:

```markdown
# Vault: Order Management System — BE

**Scope**: Backend API (BE)
**PICs**: Alex Tan
**Priority**: 1

## Sibling scopes (managed externally)
- MW — Integration Middleware (PIC: Budi Santoso; priority: 2)
- FE — Frontend Web (PIC: Maya Putri; priority: 3)

## Locked contracts this scope PUBLISHES
- be-mw-event-bus
- be-fe-orders-api
```

Memory entry written:
```
<project>/.mega-sdd/memory/decisions.md
| sha256 abc... | Order Mgmt v1.0 | 2026-05-23 | BE | order-management-be | 0 |
```

## Phase 2 — Architect FE generates vault (20 min, different session)

```bash
cd ~/projects/order-management-fe/
/mega-sdd:auto ./prd.md
```

Same PRD, different cwd. Smart default suggests FE.

User picks `[3] FE`.

Vault filtered to §Frontend + universal sections. 00-index.md shows:

```markdown
# Vault: Order Management System — FE

**Scope**: Frontend Web (FE)
**Priority**: 3

## Sibling scopes (managed externally)
- BE — Backend API (PIC: Alex Tan; priority: 1)
- MW — Integration Middleware (PIC: Budi Santoso; priority: 2)

## Locked contracts this scope CONSUMES
- be-fe-orders-api → see PRD §Cross-scope contracts
- mw-fe-realtime-channels → see PRD §Cross-scope contracts
```

## Phase 3 — Architect BE re-runs (memory hit demo)

BE architect adds a unit, re-runs:

```bash
cd ~/projects/order-management-be/
/mega-sdd:auto ./prd.md
```

Expected:

```
▶ PRD ./prd.md recognized (sha256: abc123..., last scope: BE 2026-05-23)

❓ Same scope this run?
   [Enter] BE (default after 5s; confirm-once)
   [2/3/4] Different scope
   [5] Cancel
```

User presses Enter. Silent re-run with BE scope. No friction.

## Phase 4 — Architect MW generates vault (later that day)

MW architect arrives later, fresh session:

```bash
cd ~/projects/order-management-mw/
/mega-sdd:auto ./prd.md
```

User picks `[2] MW` (cwd basename matches).

MW vault generated. Cross-scope contracts referenced:
- Consumes: be-mw-event-bus (BE publishes; MW receives)
- Publishes: mw-fe-realtime-channels (MW publishes; FE receives)

## Validation: independent vaults

Each architect has their own vault. No cross-vault automation by mega-sdd.

```bash
# Validate scope tagging
jq -r '.scope' ~/projects/order-management-be/.mega-sdd/vaults/*/vault.json
# Output: BE

jq -r '.scope' ~/projects/order-management-fe/.mega-sdd/vaults/*/vault.json
# Output: FE

jq -r '.scope' ~/projects/order-management-mw/.mega-sdd/vaults/*/vault.json
# Output: MW
```

Cross-scope coordination happens OUTSIDE mega-sdd — architects meet, lock contracts in PRD §Cross-scope contracts, then re-generate vaults.

## What if PRD changes mid-flight

PM updates PRD to add new endpoint:

```bash
# Architect BE
/mega-sdd:auto ./prd.md
```

Memory check:
```
▶ PRD ./prd.md recognized (sha256: NEW_HASH... — content changed since last invocation)

⚠️ PRD content changed since last vault generation (2026-05-23, sha: abc123...)
   Run diff-vault to apply revisions? [Y/n]
```

User runs `/mega-sdd:diff-vault ./prd.md` → revisions applied; bolts re-execute for changed units only.

## Common questions

**Q: What if architect FE invokes `--scope=BE` flag?**
A: Mega-sdd halts `scope_not_declared_in_prd` IF cwd doesn't have BE manifest signals; otherwise proceeds with BE scope (architect is explicitly overriding role). Useful for architect doing cross-scope review.

**Q: How do BE and FE architects coordinate on the locked contract `be-fe-orders-api`?**
A: Outside mega-sdd. Both vaults reference the contract section in PRD. When contract changes:
1. BE + FE architects agree on new spec in rapat
2. PM updates PRD §Cross-scope contracts > be-fe-orders-api
3. Both architects run `/mega-sdd:auto --resume` → diff-vault detects PRD change → revisions applied per-scope

**Q: What if PRD has no scopes frontmatter?**
A: Retrofit bridge fires (per `scope-picker.md` step 2). AI proposes scope partitioning. User accepts or rejects per scope. Retrofit written to `<prd>.retrofit.md` (preserves original).

**Q: Can one architect own multiple scopes?**
A: Yes. PRD `scopes:` can have same person in multiple `pics` arrays. Architect runs mega-sdd once per scope they own; gets multiple vaults.
