# generate-units Trigger + Behavior Test

## Trigger cases

### GU1: Explicit
- **Prompt:** `/mega-sdd:generate-units ./vaults/v1-bound`
- **Expect:** Skill invocation

### GU2: Indonesian
- **Prompt:** `pecah vault jadi unit`
- **Expect:** Skill invocation

### GU3: Auto-route from flow (after bind)
- **Setup:** bound-vault exists, no units/ dir
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes generate-units

## Behavior

### B1: Greenfield vault → units with empty binding_refs
- **Setup:** vault.json has `mode: greenfield`, no bound-vault
- **Expect:** units generated with `binding_refs: []`

### B2: Brownfield bound-vault → units cite binding
- **Setup:** bound-vault with binding.md (10 CONFIRMED, 2 OQ)
- **Expect:**
  - Units cite C-XXX in `binding_refs`
  - Units affected by OQs have "TBD: OQ-XXX" in body
  - target_files populated from binding evidence

### B3: Cycle rejection
- **Setup:** vault structured such that U-001 depends on U-002 and vice versa
- **Expect:** halt with cycle message

### B4: Atomicity enforcement
- **Setup:** vault section that would produce >300 LOC
- **Expect:** split into U-XXX, U-XXX.1, U-XXX.2 with explicit deps

### B5: Acceptance test mandatory
- **Setup:** unit candidate with no obvious test
- **Expect:** generator inserts placeholder test command + halt with prompt to confirm, OR halts entirely

### B6 (v1.1+): Single-squad / no-squad mode = current behavior
- **Setup:** vault has no `_meta/squads.yaml` file
- **Expect:** units generated without `squad:` field (or with `squad: default`); no cross-squad validations run; behavior identical to v1.0

### B7 (v1.1+): Multi-squad assignment per partition rules
- **Setup:** vault has `_meta/squads.yaml` declaring 3 squads (squad-be, squad-fe-web, squad-integrations) with layer-based partition; vault flows include F-U-001 (user/web), F-B-003 (backend), and a flow touching Stripe (component owned by integrations)
- **Expect:** F-U-001 unit gets `squad: squad-fe-web`; F-B-003 unit gets `squad: squad-be`; Stripe-touching unit gets `squad: squad-integrations`

### B8 (v1.1+): Cross-squad depends_on rejected
- **Setup:** generate-units would produce a unit U-FE-007 that depends_on U-BE-012 (different squad)
- **Expect:** halt with `cross_squad_dep_invalid` blocker YAML; next_action mentions routing via interface

### B9 (v1.1+): Dangling interface reference rejected
- **Setup:** a unit declares `consumes_interfaces: [does-not-exist]` (no `<vault>/interfaces/does-not-exist.md`)
- **Expect:** halt with `interface_ref_missing` blocker YAML

### B10 (v1.1+): Ambiguous routing detected
- **Setup:** two squads both declare `owns_layers: [backend]` in squads.yaml; vault has backend flow F-B-001
- **Expect:** halt with `cross_squad_ambiguous` blocker YAML listing both claiming squads

## Pass criteria

All triggers fire. Behavior checks pass. No unit generated without valid frontmatter per unit-schema.md.
