# /mega-sdd front-door Trigger + Input Detection Test

The one-shot autonomous pipeline entrypoint — since 5.0.0 the front door `/mega-sdd` (was `/mega-sdd:auto`; that typed form now resolves as a deprecation alias with IDENTICAL behavior plus a one-line keterangan printed first). Tests input shape detection and routing to `orchestrate-flow --deep --auto`.

## Trigger cases

### A1: Empty input → CWD inspection drives chain
- **Setup:** CWD has `prd.md`, no vault
- **Prompt:** `/mega-sdd`
- **Expect:** routes to `orchestrate-flow --deep --auto`; CWD inspection detects PRD; proposes `generate-intent ./prd.md → scan → bind → units → bolts`

### A2: Directory path with code files → legacy rebuild
- **Setup:** `./legacy-php/` contains `.php` files + `composer.json`; no vault
- **Prompt:** `/mega-sdd ./legacy-php/ --out=./rebuild-laravel/`
- **Expect:** input detected as legacy codebase; chain proposes `extract-intelligence ./legacy-php/ --out=./rebuild-laravel/ → generate-intent --kb=./rebuild-laravel/docs/knowledge-base/ → scan → bind → units → bolts`

### A3: Directory path with vault.json → existing vault
- **Setup:** `./my-vault/vault.json` exists; no bound-vault
- **Prompt:** `/mega-sdd ./my-vault/`
- **Expect:** input detected as existing vault; chain proposes `scan-codebase → bind-codebase ./my-vault/ → generate-units → execute-bolts`

### A4: File path with .md → PRD Mode A
- **Setup:** `./prd-feature-x.md` exists
- **Prompt:** `/mega-sdd ./prd-feature-x.md`
- **Expect:** input detected as PRD; chain proposes `generate-intent ./prd-feature-x.md → scan → bind → units → bolts`

### A5: Quoted free-text → Mode B brief
- **Setup:** NO vault in CWD (the front door's free-text row is vault-conditional — with an owned vault present the delta lane branch applies instead; see diff-vault.test.md DV5/DV8)
- **Prompt:** `/mega-sdd "build a clinic appointment system"`
- **Expect:** input detected as Mode B brief; chain proposes `generate-intent --from-prompt "build a clinic appointment system" → generate-units → bolts` (3 phases — no codebase, no scan/bind)

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
- **Expect:** the adoption lane — `certify-artifact.sh --rung=prd` classifies the shape; CERTIFIED/CERTIFIED_DEGRADED proceed generate-intent, DEMOTE = C2 confirm, REJECTED halts with the keterangan verbatim (no bare "clarify file type" dead end)

## Flag behavior

### F1: --shallow reverts to cap-3
- **Prompt:** `/mega-sdd ./prd.md --shallow`
- **Expect:** chain proposed has at most 3 phases; standard `orchestrate-flow` behavior

### F2: --step-after=<phase>
- **Prompt:** `/mega-sdd ./prd.md --step-after=bind-codebase`
- **Expect:** chain runs up to and including bind-codebase; then switches to manual handoff (subsequent phases require explicit invocation)

### F3: --stop-after=<phase>
- **Prompt:** `/mega-sdd ./prd.md --stop-after=generate-units`
- **Expect:** chain runs up to and including generate-units; STOPS even if state would allow execute-bolts

### F4: --resume picks up from halt point
- **Setup:** prior `/mega-sdd` halted at bind-codebase; user resolved blocker
- **Prompt:** `/mega-sdd --resume`
- **Expect:** no upfront confirmation; CWD inspection rebuilds cursor; resumes from `bind-codebase` (re-runs binding) or `generate-units` (if binding now clean)

### F5: --manual disables autonomy entirely
- **Prompt:** `/mega-sdd ./prd.md --manual`
- **Expect:** invokes only `generate-intent ./prd.md` (the first phase); standard chat hint at end; no auto-continue to next phase; reverts to current per-skill explicit-invocation behavior

## Halt-protocol preservation (Iter 4 invariant)

### HP1: bind_conflict still blocks
- **Setup:** PRD with claim that conflicts with codebase
- **Prompt:** `/mega-sdd ./prd.md`
- **Expect:** chain runs through `generate-intent → scan-codebase`; bind-codebase emits `status: halted` with `bind_conflict` blocker; chain STOPS at bind phase; user resolves via resolve-oq; runs `/mega-sdd --resume`

### HP2: hard_rule_violated halts the chain (detect-after)
- **Setup:** unit U-002 has `DO NOT modify src/Models/User.php`; bolt's code modifies it
- **Prompt:** `/mega-sdd ./vault/` running in --deep
- **Expect:** chain reaches execute-bolts; bolt halts post-flight with `hard_rule_violated` (detect-after — the bolt commit already landed); chain STOPS; user fixes-forward or reverts the flagged commit

### HP3: Business OQ P1 blocks chain (when --strict)
- **Setup:** PRD produces P1 business OQs requiring stakeholder; `bind-codebase --strict`
- **Expect:** chain HALTS after bind-codebase emits `status: halted` with a `bind_conflict` blocker (per bind SKILL.md §5 decision gate: `conflict>0 OR (--strict AND oq>0)` → emit the halt YAML, route to resolve-oq — the same envelope as a CONFLICT halt, cf. HP1); chat surfaces the blocker; user resolves OQs via resolve-oq; runs `--resume`

## Pass criteria

All input detection (A1-A5) correctly identifies starting phase. Halt cases (H1-H3) reject ambiguous inputs without silent guess. Flag behavior (F1-F5) honors each flag's semantics per `commands/mega-sdd.md` (the front door). Halt-protocol invariants (HP1-HP3) preserved — Iter 4 autonomy does NOT relax any existing halt-condition. Single upfront confirmation required for ALL chains per AUTONOMY-OQ-1.

## Alias back-compat (5.x)

### AL1: deprecated typed form still resolves
- **Prompt:** `/mega-sdd:auto ./prd-feature-x.md`
- **Expect:** one-line Indonesian deprecation keterangan printed FIRST (points at `/mega-sdd`), then behavior IDENTICAL to A4 — same input detection, same chain, same single confirmation.
