# extract-intelligence Triggering Test

The legacy-rebuild lane: legacy code → knowledge base (one PRD-kontrak per module) → `plan --kb` → `execute-bolts`. Kept in 9.0; its hand-off moved from generate-intent to `plan --kb` (plan.test.md K1–K8).

## Trigger cases

### E1: Explicit slash command
- **Prompt:** `/mega-sdd:extract-intelligence ./legacy-php/`
- **Expect:** Skill invoked. Step 1 (census) starts immediately — `derive-extract-census.sh` writes `census.json`. Positional arg parsed as legacy codebase path.

### E2: Natural English
- **Prompt:** `reverse engineer this legacy code so we can rebuild on a different stack`
- **Expect:** Skill invoked (via using-mega-sdd anchor on `reverse engineer` + `rebuild di stack baru` trigger keyword).

### E3: Natural Indonesian
- **Prompt:** `pecah legacy code jadi knowledge base`
- **Expect:** Skill invoked.

### E4: Domain knowledge extraction phrasing
- **Prompt:** `extract domain knowledge from this PHP system`
- **Expect:** Skill invoked.

### E5: orchestrate-flow auto-route
- **Setup:** CWD has legacy codebase signals (`.git` + `composer.json` or `.php` files), no `prd.md`, no vault, no knowledge base, user expresses rebuild intent.
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes `extract-intelligence` as next step (before `plan --kb`): `extract-intelligence <legacy>` → `plan --kb=<kb> --lite --mode=<existing|new>` → `execute-bolts --all --lite`. Without the rebuild intent the engine only notes the position (`legacy_code_only`) and asks — rebuild or a brief.

### E6: KB-already-present routing
- **Setup:** CWD has `docs/knowledge-base/README.md` (or `.mega-sdd/knowledge-base/README.md`), no vault.
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes `plan --kb=docs/knowledge-base/ --lite --mode=<existing|new>` directly (skips extract-intelligence — already done), plus a one-line mention of the `emit-prd` reverse lane (never auto-chained).

## Behavior checks

### B1: Output directory structure
After invocation against a non-trivial legacy codebase:
- `{out}/knowledge-base/` holds `census.json`, `README.md` (roll-up + nav) and `modules/<domain>.prd.md` — ONE PRD-kontrak per module
- `{out}/knowledge-base/data-mutation-policy.md` exists ONLY when ≥1 `[LOCKED]` claim exists across modules (never padded)
- New extractions write no numbered tree (`00-overview/` … `99-rebuild-architecture/`); a pre-existing numbered-tree KB stays readable
- If `--seed=<path>` provided: `{out}/_source/` exists and contains the seed file

### B2: Frontmatter on every module PRD
Every `modules/*.prd.md` has YAML frontmatter:
- `generated_by: mega-sdd:extract-intelligence`
- `domain: <module-name>` (= the file name)
- `classification: master | workflow | reporting | integration | reference`, `criticality`, `depends_on`, `rebuild_after` (acyclic), `source_files` (census paths claimed exactly once across all PRDs)
- `inferred_count`, `open_count`, `locked_count`, `intent_count`, `artifact_count`, `source_files_cited` — integers written by `derive-prd-counts.sh --write`, never typed by an extractor

### B3: Template compliance
Grep every module PRD for the mandatory section headers:
- `^## 1\.` … `^## 6\.` (Purpose, Business Rules, Flow, Data In/Out, Edge Cases & Gotchas, Open Questions) — explicit absence allowed, omission not
- `^## 7\.` Run & Recovery on every `classification: workflow` module
- a Mermaid fence in §3 Flow
- Missing any → per-module quality gate FAIL

### B4: Anti-hallucination
On a codebase with NO explicit OJK/regulatory references:
- Regulatory rules the code does not state MUST be `[INFERRED]` or `[OPEN]` — never presented as fact
- MUST NOT invent POJK/PBI numbers
- Every module PRD carries its `## 6. Open Questions` section (`OQ-<DOMAIN>-<NN> [P1|P2|P3]`)

### B5: Main-thread synthesis
- After extraction completes, the README roll-up is composed on the main thread from the script-derived counts; its module quick-reference carries the recommended rebuild ORDER from `rebuild_after` (module is the phasing unit)
- Multi-module: README carries `## ERD` + `## System Flow` Mermaid
- `validate-extract-census.sh` recounts the roll-up (`rollup_mismatch`)

### B6: Hand-off message
- On completion (census gate PASS), the skill announces a next step:
  - `plan --kb=<out>/knowledge-base/` to build the rebuild spec (vault + units)
  - When Open questions > 0: an OFFER to answer them now in resolve-oq KB mode (never auto-invoked)
- Under `--auto`: handoff `next_action.suggested_skill: mega-sdd:plan`, `suggested_args: ["--kb=.mega-sdd/knowledge-base/", "--auto"]`

### B7: Quality gate failure surfaced
- If a module PRD misses a mandatory section: the per-module gate FAILs → that module is re-dispatched once with the gate output as feedback
- The SAME module failing twice → halt `quality_gate_failed` (subtype `module_quality_threshold_unmet`); halt message names the failing file + the missing section, gate output verbatim
- `validate-extract-census.sh` FAIL (unclaimed / double-claimed / phantom / uncited files, missing claim-verify state, uncited WRITE/CALL site) → NEVER hand off; fix or record the gap honestly as `[OPEN]`/OQ, then re-run

## Pass criteria

All E1–E6 triggers fire correctly. B1–B7 behaviors verified against a real multi-module legacy codebase: census gate PASS, every census file claimed and cited, hand-off to `plan --kb`.
