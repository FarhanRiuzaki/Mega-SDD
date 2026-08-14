# Scenario 9 — Flawless Seamless Intelligence (full pipeline)

> Integration scenario for orchestrator intelligence (memory-driven routing + predictive halts) + handoff solidity (schema validation + type-check) on a real Laravel starterkit project.

**Time:** ~30-40 min (2 chain runs to demonstrate F1 cache hit)
**When to use:** verify the intelligence layer (memory-driven routing + predictive halts + handoff validation) end-to-end on the `base-laravel-26` starterkit; field-test acceptance criterion. Runs the **classic spine** (`--classic`) because Step 5's predictive-halt leg exercises the scan phase.

## Prerequisites

- Plugin v6+ installed
- Laravel starterkit project at `<project_root>` with composer.json + package.json + tailwind.config.js
- tree-sitter installed (for predictive check pass demonstration)
- PRD at `<project_root>/prd.md`

## Scenario steps

### Step 1: First chain run (no prior routing-outcomes)

```
/mega-sdd --classic
```

**Assertions:**
- Step 2.7 routing preflight runs but skips recommendation (no routing-outcomes.md file)
- Step 3.5 predictive preflight runs; ast_engine_present passes (no warning)
- Chain executes (classic): scan-codebase → generate-intent → bind-codebase → generate-units → execute-bolts
- Each handoff passes Step 6.b schema validation (all REQUIRED + CONDITIONAL fields present per Phase A1 sweep)
- Each handoff passes Step 6.b.i type-check (no shape drift)
- Step 7.5 creates `.mega-sdd/memory/routing-outcomes.md` + appends first row

### Step 2: Second chain run (routing-outcomes consulted)

```
/mega-sdd --classic
```

**Assertions:**
- Step 2.7 reads routing-outcomes.md → 1 row matches fingerprint (from Step 1); below ≥3 threshold → fall-through to default routing
- Routing identical to first run (default)
- Step 7.5 appends second row

### Step 3: Third chain run (3 rows → recommendation triggers)

```
/mega-sdd --classic
```

**Assertions:**
- Step 2.7 finds 2 prior rows → still below ≥3 threshold → fall-through

### Step 4: After 3 successful runs, fourth run triggers recommendation

```
/mega-sdd --classic
```

**Assertions:**
- Step 2.7 finds ≥3 prior rows; all converged=yes; same chain-used
- Recommendation displayed: "Routing recommendation from past 3 runs (all converged in avg X min): starterkit-first"
- Chain uses recommended routing
- Step 7.5 appends fourth row

### Step 5: Force a predictive halt

```
# Uninstall tree-sitter
brew uninstall tree-sitter

# Force tree-sitter engine — say "scan codebase ini --engine=tree-sitter"
# (typed skill commands were removed at 6.0.0; the phrase routes to scan-codebase)
```

**Assertions:**
- Step 3.5 predictive preflight runs
- ast_engine_present check fails (tree-sitter AND ast-grep both absent); fatal=NO → warning only
- Chain proceeds; scan-codebase fails with dep_missing AFTER (as expected — predictive check was correct)

### Step 6: Force a validation halt (simulated)

```
# Manually edit bind-codebase SKILL.md handoff template to REMOVE scope: block
# Then run chain on vault with scope_metadata
/mega-sdd --classic
```

**Assertions:**
- Step 6.b validation runs after bind-codebase completes
- CONDITIONAL field scope: missing; condition (vault has scope_metadata) TRUE
- Halt invalid_handoff emitted; chain STOPS
- next_action.hint guides user to fix bind-codebase template

## Pass criteria

ALL of:
- routing-outcomes.md created on first run + appended each subsequent run
- Recommendation triggers after ≥3 consistent successful runs
- Predictive checks fire warnings non-fatally + fatal halt when fatal=yes
- Schema validation gate halts on missing CONDITIONAL field
- Type-check halts on type mismatch
- Generated code matches starterkit patterns (deep-scan carryover behavior — sanity)

## Failure modes to watch

- `routing_outcome_corrupt` (file gets malformed) → auto-invalidate + chain proceeds (soft halt; expected)
- `predictive_check_failed` (fatal check) → chain halts BEFORE skill invocation (expected behavior)
- `invalid_handoff` (schema validation) → chain halts AFTER skill completes BUT BEFORE next skill invocation (expected)
- `handoff_type_mismatch` (type check) → same as invalid_handoff routing (expected)

## Related artifacts

- Spec: `docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md`
- Plan: `docs/superpowers/plans/2026-05-24-iter-33-flawless-seamless-intelligence.md`
- Audit: `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` (Phase B output)

## Field test path

`/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/base-laravel-26`
