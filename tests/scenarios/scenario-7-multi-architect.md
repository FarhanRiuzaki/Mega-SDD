# Scenario 7 — Multi-Architect (Multi-Scope PRD)

**Time**: 60 minutes total (20 min per architect)
**When to use**: Project where PRD is shared across multiple IT architects (BE, MW, FE) — each architect generates their own vault for their scope only

A vault per scope is a pipeline artefact, so this walkthrough runs the guarded lane (`plan` → `execute-bolts --all --lite`). The scope picker lives in `plan`. Each architect's FIRST run needs `--guarded`, or `--scope=<id>` (which implies it): without either, the front door's router (`scripts/route-lane.sh`) sends a PRD with no vault in the repo to the direct or assisted lane, which builds it in the main session with no vault and no scope picker (`plugins/mega-sdd/references/direct-lane.md`). Once the vault exists, later runs route to guarded on their own (`vault_present`).

**Prerequisites**:
- mega-sdd 9.0+ (the scope picker is `plan` Step 0.9)
- Canonical PRD with `scopes:` frontmatter (a PRD without one is single-scope — see Common questions)
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
/mega-sdd ./prd.md --guarded
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

▶ Phase 0b: Starterkit detection
  ✓ composer.json → laravel-base-26 detected (GROUND matcher; symbol index built — no scan phase)

▶ Phase 1: plan ./prd.md --scope=BE --lite --mode=<existing|new>   (existing when the repo carries code)
  Output: .mega-sdd/vaults/<slug>/   (slug from the PRD file name)
  - context.md: scope / scope_name frontmatter + ## Overview "Sibling scopes" note
  - vault.json: scope=BE, scope_metadata declared, prd_sha256 recorded
  - units/U-*.md: only the BE sections' requirements

▶ Phase 2: execute-bolts --all --lite (JIT bind per unit; a CONFLICT quarantines its unit at run start)
```

BE architect's vault is at `.mega-sdd/vaults/<slug>/`. `context.md ## Overview` carries the sibling-scope note:

```markdown
### Sibling scopes (managed externally — NOT in this vault)

- **MW** — Integration Middleware (PIC: Budi Santoso; priority: 2)
- **FE** — Frontend Web (PIC: Maya Putri; priority: 3)

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault.
> Locked contracts cross-referenced in `vault.json` `scope_metadata` (`published_locked_contracts` / `consumed_locked_contracts`) for awareness, NOT enforcement.
```

Recorded in vault.json: prd_sha256 + scope + scope_metadata — including the locked contracts this scope PUBLISHES:

```json
"scope": "BE",
"scope_metadata": {
  "id": "BE",
  "name": "Backend API",
  "pics": ["Alex Tan"],
  "priority": 1,
  "sibling_scopes_in_prd": ["MW", "FE"],
  "consumed_locked_contracts": [],
  "published_locked_contracts": ["be-mw-event-bus", "be-fe-orders-api"]
}
```

The bolt run ends with the result contract every lane delivers: the acceptance-criterion → test table, `delivery-check.sh` `VERDICT: PASS` on the final commit, and the assumptions and decisions made.

## Phase 2 — Architect FE generates vault (20 min, different session)

```bash
cd ~/projects/order-management-fe/
/mega-sdd ./prd.md --scope=FE
```

Same PRD, different cwd. `--scope=FE` skips the picker (and implies `--guarded`); without it, `--guarded` alone shows the picker with FE as the smart default.

Vault filtered to §Frontend + universal sections. `vault.json` `scope_metadata` lists what the scope CONSUMES:

```json
"scope": "FE",
"scope_metadata": {
  "id": "FE",
  "name": "Frontend Web",
  "pics": ["Maya Putri"],
  "priority": 3,
  "sibling_scopes_in_prd": ["BE", "MW"],
  "consumed_locked_contracts": ["be-fe-orders-api", "mw-fe-realtime-channels"],
  "published_locked_contracts": []
}
```

`context.md ## Overview` names BE and MW as sibling scopes, and the PRD §Cross-scope contracts dependencies that touch FE ride along as informational notes.

## Phase 3 — Architect BE re-plans (prior-vault scope default)

Later the BE architect re-plans the vault from the same, unchanged PRD (`plan` refuses an existing vault unless `--regenerate`; units marked `_authored_by: human` are kept):

```
plan ./prd.md --regenerate
```

Expected:

```
▶ PRD ./prd.md recognized (sha256: abc123...)
  Existing vault scope: BE (vault.json)

❓ Same scope this run?
   [Enter] BE (recommended — confirm-once)
   [2/3/4] Different scope
   [5] Cancel
```

User presses Enter. Silent re-run with BE scope. No friction. (Under `--auto` the prior scope is taken without a prompt.)

## Phase 4 — Architect MW generates vault (later that day)

MW architect arrives later, fresh session:

```bash
cd ~/projects/order-management-mw/
/mega-sdd ./prd.md --guarded
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

Cross-scope coordination happens OUTSIDE mega-sdd — architects meet, lock contracts in PRD §Cross-scope contracts, then each applies the revised PRD to their vault (below).

## What if PRD changes mid-flight

PM updates PRD to add new endpoint:

```bash
# Architect BE
cp ~/shared/order-mgmt-prd.md ./prd.md
/mega-sdd
```

The status view sees a PRD file newer than the vault (position `prd_revision`) and proposes `diff-vault ./prd.md` first — one confirmation. Or say "PRD updated — diff the vault" (routes to diff-vault) → revisions applied, IDs preserved. The new endpoint needs a NEW unit, which only `plan --regenerate` writes (`plan --reconcile` never adds units); `execute-bolts --all --lite` then runs the new and stale units only.

## Common questions

**Q: What if architect FE invokes `--scope=BE` flag?**
A: Mega-sdd proceeds — BE is a declared scope; only an undeclared id halts `scope_not_declared_in_prd` (cwd manifests are irrelevant). Useful for architect doing cross-scope review.

**Q: How do BE and FE architects coordinate on the locked contract `be-fe-orders-api`?**
A: Outside mega-sdd. Both vaults reference the contract section in PRD. When contract changes:
1. BE + FE architects agree on new spec in rapat
2. PM updates PRD §Cross-scope contracts > be-fe-orders-api
3. Both architects run `/mega-sdd` → the status view proposes `diff-vault` for the newer PRD → revisions applied per-scope

**Q: What if PRD has no scopes frontmatter?**
A: The PRD is single-scope: no picker, no retrofit prompt, no retrofit subagent. `plan` records `scope_inferred: single` and adds ONE delivery-report line offering the manual retrofit — add a `scopes:` block to the PRD by hand, then re-run `plan --regenerate --scope=<id>` (`plugins/mega-sdd/skills/plan/references/scope-flow.md` Step 0.9 c).

**Q: Can one architect own multiple scopes?**
A: Yes. PRD `scopes:` can have same person in multiple `pics` arrays. Architect runs `plan` once per scope they own; gets multiple vaults. In ONE repo the second run needs its own vault dir (`plan ./prd.md --scope=MW --vault=.mega-sdd/vaults/<name>`) — the default dir comes from the PRD file name, and `plan` refuses an existing vault.
