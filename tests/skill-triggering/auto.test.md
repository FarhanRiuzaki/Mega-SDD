# /mega-sdd front-door Trigger + Input Detection Test

The one-shot autonomous pipeline entrypoint — since 5.0.0 the front door `/mega-sdd` (was `/mega-sdd:auto`; the typed alias was removed at 6.0.0 — a typed legacy form arrives as plain text and still routes to the front door by phrase, with NO keterangan line). Tests the lane router (`scripts/route-lane.sh`, run FIRST for a PRD or brief), input shape detection, and routing to `orchestrate-flow --deep --auto` on the guarded lane. The one spec pipeline is `plan` → `execute-bolts --all --lite` (9.0 removed the classic chain).

## Trigger cases

### A1: Empty input → CWD inspection drives chain
- **Setup:** CWD has `prd.md`, no vault
- **Prompt:** `/mega-sdd`
- **Expect:** Lane 0 — GROUND + status view; `derived.proposed_next` (position `prd_no_vault`) = `plan prd.md --lite --mode=<existing|new>` → `execute-bolts --all --lite`; ONE confirmation; then `orchestrate-flow --deep --auto`

### A2: Directory path with code files → legacy rebuild
- **Setup:** `./legacy-php/` contains `.php` files + `composer.json`; no vault
- **Prompt:** `/mega-sdd ./legacy-php/ --out=./rebuild-laravel/`
- **Expect:** input detected as legacy codebase (a directory skips route-lane); chain proposes `extract-intelligence ./legacy-php/ --out=./rebuild-laravel/` → `plan --kb=./rebuild-laravel/knowledge-base/ --lite --mode=<existing|new>` → `execute-bolts --all --lite` (the bolts hop only when a target scaffold exists)

### A3: Directory path with vault.json → existing vault
- **Setup:** `./my-vault/vault.json` exists
- **Prompt:** `/mega-sdd ./my-vault/`
- **Expect:** input detected as existing vault; `derived.proposed_next`: layout-3 with units → `execute-bolts --all --lite` (JIT bind per unit: up front + each task's re-bind); layout-3 without units → `plan <prd> --lite --regenerate`; layout-2 (classic-born, no `context.md`) → propose `/mega-sdd:migrate-paths --vault-layout=3` first (then the mandatory full JIT re-bind), never run silently

### A4: File path with .md → PRD
- **Setup:** `./prd-feature-x.md` exists
- **Prompt:** `/mega-sdd ./prd-feature-x.md`
- **Expect:** Step 0 `route-lane.sh --prd=./prd-feature-x.md` FIRST. `direct` / `assisted` → `references/direct-lane.md`, no vault, no confirmation prompt, done on `delivery-check.sh` `VERDICT: PASS`. `guarded` (a vault exists, or forced) → the 2-hop chain `plan ./prd-feature-x.md --lite --mode=<existing|new>` → `execute-bolts --all --lite` under ONE confirmation; state re-derived from disk between the hops (plan emits no handoff YAML)

### A5: Quoted free-text → brief
- **Setup:** NO vault in CWD (the front door's free-text row is vault-conditional — with an owned vault present the delta lane branch applies instead; see diff-vault.test.md DV5/DV8)
- **Prompt:** `/mega-sdd "build a clinic appointment system"`
- **Expect:** `route-lane.sh --text` → direct/assisted, built without a vault. With `--guarded` (or `--lite`): the front door writes `.mega-sdd/vaults/<slug>/source/seed-PRD.md` (no pre-plan Q&A; open topics become OQs), then proposes `plan <seed-PRD> --vault=.mega-sdd/vaults/<slug> --lite --mode=<existing|new>` → `execute-bolts --all --lite`

## Halt cases

### H1: Legacy codebase WITHOUT --out
- **Setup:** `./legacy-php/` contains code; no vault
- **Prompt:** `/mega-sdd ./legacy-php/`
- **Expect:** halt asking for explicit `--out=<path>` (per AUTONOMY-OQ-7 — legacy rebuild output path must be explicit; never conflate extract output with rebuild project dir)

### H2: Directory with neither code nor vault.json
- **Setup:** `./empty-dir/` exists but is empty (or has only non-code files)
- **Prompt:** `/mega-sdd ./empty-dir/`
- **Expect:** halt asking to clarify directory purpose

### H3: File with unrecognized extension
- **Setup:** `./notes.xyz` exists
- **Prompt:** `/mega-sdd ./notes.xyz`
- **Expect:** the adoption lane — `certify-artifact.sh --rung=prd` classifies the shape; CERTIFIED → `plan ./notes.xyz --lite --mode=<existing|new>` → `execute-bolts --all --lite`; CERTIFIED_DEGRADED → the same `plan` hop with the OQ-heavy warning, the direct/assisted lane offered as the alternative; DEMOTE = C2 confirm; REJECTED halts with the keterangan verbatim (no bare "clarify file type" dead end)

## Flag behavior

### F1: --shallow reverts to cap-3
- **Prompt:** `/mega-sdd ./prd.md --guarded --shallow`
- **Expect:** chain proposed has at most 3 phases; standard `orchestrate-flow` behavior (the one pipeline is 2 phases, 3 with extract-intelligence)

### F2: --step-after=<phase>
- **Prompt:** `/mega-sdd ./prd.md --step-after=plan`
- **Expect:** `--step-after` implies `--guarded`; it renders to orchestrate-flow as `--to=plan`; the chain runs `plan` and stops for review; continue with `/mega-sdd --resume` WITHOUT `--auto` (manual per-phase) or `--from=execute-bolts` to resume auto

### F3: --stop-after=<phase>
- **Prompt:** `/mega-sdd ./prd.md --stop-after=plan`
- **Expect:** implies `--guarded`; renders as `--to=plan`; chain runs up to and including `plan`; STOPS even if state would allow execute-bolts

### F4: --resume picks up from halt point
- **Setup:** prior `/mega-sdd` halted in `execute-bolts` on `binding_conflict` for U-004; user resolved it via `resolve-oq --binding`
- **Prompt:** `/mega-sdd --resume`
- **Expect:** no upfront confirmation; CWD inspection rebuilds cursor; resumes `execute-bolts --all --lite` — a KEEP_VAULT/DEFER-only resolution already opens U-004's gate (no re-bind); a KEEP_CODE/SPLIT edit re-binds that unit first (`rebind-units.sh --units=U-004`)

### F5: --manual disables autonomy entirely
- **Prompt:** `/mega-sdd ./prd.md --guarded --manual`
- **Expect:** invokes only `plan ./prd.md --lite --mode=<existing|new>` (the first phase); prints the follow-up command; no auto-continue to next phase

### F6: --lite implies the guarded lane
- **Prompt:** `/mega-sdd ./prd.md --lite`
- **Expect:** `route-lane.sh --lane=guarded` (override recorded); the A4 guarded chain. `--greenfield`, `--scope`, `--express` and `--weight=L` imply `--guarded` the same way

### F7: Retired lane switches
- **Prompt:** `/mega-sdd ./prd.md --classic` (or `lane: standard` / `spine: classic` in `.mega-sdd/config.yaml`)
- **Expect:** ONE line saying it is retired in 9.0 and ignored (it forces no lane); the run carries on exactly as A4

## Halt-protocol preservation (Iter 4 invariant)

### HP1: binding_conflict still blocks (per unit, at run start)
- **Setup:** PRD whose U-004 claim conflicts with existing code; run `/mega-sdd ./prd.md --guarded --no-converge`
- **Expect:** chain runs `plan` → `execute-bolts`; the up-front bind writes `bolts/U-004/binding.json` with a CONFLICT → U-004 quarantined `binding_conflict` in the Karantina table (its dependents skipped with the reason; the other units proceed; every unit blocked → halt `binding_conflict`); U-004 waits for `resolve-oq --binding`; then `/mega-sdd --resume`. (Under `--deep` with convergence on — the default — `binding_conflict` is cycle-eligible: `resolve-oq --binding` is auto-invoked with grounded recommendations; reviewing CONFLICTs yourself requires `--no-converge`)

### HP2: hard_rule_violated halts the chain (detect-after)
- **Setup:** unit U-002 has `DO NOT modify src/Models/User.php`; bolt's code modifies it
- **Prompt:** `/mega-sdd ./vault/` running in --deep
- **Expect:** chain reaches execute-bolts; bolt halts post-flight with `hard_rule_violated` (detect-after — the bolt commit already landed); chain STOPS; user fixes-forward or reverts the flagged commit

### HP3: Business OQ P1 blocks its units
- **Setup:** PRD produces P1 business OQs requiring a stakeholder; the run is headless (no `AskUserQuestion`)
- **Expect:** `plan`'s single batched ask cannot be answered → the P1 business OQs stay `blocking` (never self-answered); the units citing them stay blocked at `execute-bolts` (an OQ P1 business halt waits for a human); the chain surfaces them; the user resolves via `resolve-oq`, then `--resume`

## Pass criteria

All input detection (A1-A5) correctly identifies the lane and starting phase — `route-lane.sh` runs first for every PRD/brief, and only the guarded lane reaches the pipeline. Halt cases (H1-H3) reject ambiguous inputs without silent guess. Flag behavior (F1-F7) honors each flag's semantics per `commands/mega-sdd.md` (the front door): pipeline-only flags imply `--guarded`, retired switches are named in one line and ignored. Halt-protocol invariants (HP1-HP3) preserved — autonomy does NOT relax any existing halt-condition; the CONFLICT gate now closes per unit at execute-bolts run start (the derive-exec-plan.sh quarantine). Single upfront confirmation required for ALL chains per AUTONOMY-OQ-1.

## Alias back-compat (5.x)

### AL1: legacy typed form routes as plain text
- **Prompt:** `/mega-sdd:auto ./prd-feature-x.md`
- **Expect:** no slash command registers (alias removed 6.0.0); the text routes to the `/mega-sdd` front door by phrase — same lane routing, same chain, same single confirmation as A4; NO deprecation keterangan line (there is no alias left to print one).
