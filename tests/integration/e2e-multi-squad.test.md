# E2E Multi-Squad Pipeline Test

Walks the full pipeline on a synthetic multi-squad project. Manual run; exercises every v1.1+ behavior end-to-end.

## Setup

```bash
mkdir -p /tmp/megasdd-e2e-multi && cd /tmp/megasdd-e2e-multi
git init
echo "# Multi-Squad Test Project" > README.md
git add . && git commit -m "init"
```

## Walk

### Step 1: generate-intent with multi-squad Q&A

```
/mega-sdd:generate-intent --from-prompt "build a tenant-billing web app with backend API (Node), web frontend (React), and Stripe billing integration"
```

**Expect during Q&A:**
- Standard project shape Q → answer: `web-app`
- Standard mode Q → answer: `new` (greenfield)
- NEW squad-count Q → answer: `3`
- NEW partition-model Q → answer: `1` (layer-based)
- NEW squad-declaration loop (3 iterations):
  1. id=squad-be, label="Backend Squad", owns_layers=[backend, data-model]
  2. id=squad-fe-web, label="Frontend Web Squad", owns_layers=[web-frontend]
  3. id=squad-integrations, label="Integrations Squad", owns_layers=[integrations], owns_components=[stripe]

**Expect output:**
- `docs/mega-sdd/vaults/<name>/` with the 7 prose docs
- Each prose doc has YAML frontmatter (type, doc_id, aliases, tags)
- Cross-refs are wikilinks (e.g., `[[02-architecture#Backend]]`)
- `_meta/squads.yaml` with 3 squads declared
- `interfaces/_index.md` (empty stub, no `<id>.md` files yet)
- `.obsidian/graph.json` with color groups for 3 squads
- `vault.json` has `multi_squad_mode: true`

### Step 2: Author one interface manually (architect step)

Create `docs/mega-sdd/vaults/<name>/interfaces/api-billing-checkout.md` from the template:

```bash
cp plugins/mega-sdd/skills/generate-intent/references/templates/interface-note.template.md \
   docs/mega-sdd/vaults/<name>/interfaces/api-billing-checkout.md
```

Then edit it (substitute placeholders):
- id: api-billing-checkout
- type: interface
- producer: squad-integrations
- consumers: [squad-fe-web, squad-be]
- contract_kind: rest
- status: draft  (will lock later)

### Step 3: generate-units in multi-squad mode

```
/mega-sdd:generate-units docs/mega-sdd/vaults/<name>
```

**Expect:**
- Units generated with `squad:` field assigned per layer rules
- BE flows → `squad: squad-be`; FE flows → `squad: squad-fe-web`; Stripe-touching → `squad: squad-integrations`
- A FE unit that bills through Stripe has `consumes_interfaces: [api-billing-checkout]` in frontmatter
- An integrations unit that produces the billing endpoint has `produces_interfaces: [api-billing-checkout]`
- No `depends_on` edge crosses squads

### Step 4: Try execute-bolts --per-squad with draft interface

```
/mega-sdd:execute-bolts --per-squad
```

**Expect:**
- Halts: the FE squad subagent emits `cross_squad_interface_draft` because `api-billing-checkout` is `status: draft`
- BE squad subagent may still complete (no draft-interface dependencies)
- Integrations squad subagent works on producing the locked side

### Step 5: Lock the interface and retry

Edit `docs/mega-sdd/vaults/<name>/interfaces/api-billing-checkout.md`:
- frontmatter: `status: locked`, `locked_at: <today>`

```
/mega-sdd:execute-bolts --per-squad
```

**Expect:**
- All 3 squad subagents now complete
- Each writes bolt-reports to their squad's units
- Final consolidated report shows 3 squads, M total units, K commits, 0 halts

### Step 6: Verify per-squad handoff

Simulate a dev team member running only the FE squad on their laptop:

```
/mega-sdd:execute-bolts --squad=squad-fe-web
```

**Expect:**
- Only FE units execute
- No BE/integrations work touched (already done in step 5, but the filter would skip them anyway)
- Confirms the human-handoff use case

### Step 7: orchestrate-flow shows v1.1 awareness

```
/mega-sdd:orchestrate-flow
```

**Expect:**
- State snapshot includes `squad_count: 3`, `interfaces_count: 1`
- If any units pending: suggests `execute-bolts --per-squad`
- If all units done: suggests `detect-drift`

## Pass criteria

End-to-end pipeline produces working multi-squad project:
- 3 squad subagents executed in parallel
- Cross-squad coupling went through 1 locked interface
- Draft-interface halt fired correctly on the first --per-squad attempt
- Single-squad re-run via `--squad=squad-fe-web` worked as filtered execution
- No cross-squad direct depends_on edges existed in unit DAG
- Vault structure: 7 prose docs (with frontmatter + wikilinks) + _meta/squads.yaml + interfaces/api-billing-checkout.md + .obsidian/graph.json + units/ + bolts/
