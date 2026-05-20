# extract-intelligence Triggering Test

## Trigger cases

### E1: Explicit slash command
- **Prompt:** `/mega-sdd:extract-intelligence ./legacy-php/`
- **Expect:** Skill invoked. Wave 0 (prep) starts immediately. Positional arg parsed as legacy codebase path.

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
- **Setup:** CWD has legacy codebase signals (`.git` + `composer.json` or `.php` files), no `prd.md`, no `vault/`, no `docs/knowledge-base/`, user expresses rebuild intent.
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes `extract-intelligence` as next step (before `generate-intent`).

### E6: KB-already-present routing
- **Setup:** CWD has `docs/knowledge-base/README.md`, no `vault/`.
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes `generate-intent --kb=docs/knowledge-base/` directly (skips extract-intelligence — already done).

## Behavior checks

### B1: Output directory structure
After invocation against a non-trivial legacy codebase:
- `{out}/knowledge-base/` exists with all required sub-dirs: `00-overview/`, `10-domains/`, `20-workflows/`, `30-data-model/`, `40-business-rules/`, `50-integrations/`, `99-rebuild-architecture/`
- `{out}/knowledge-base/README.md` exists at top level
- If `--seed=<path>` provided: `{out}/_source/` exists and contains the seed file

### B2: Frontmatter on every domain file
Every `*.md` file under `10-domains/` has YAML frontmatter:
- `generated_by: mega-sdd:extract-intelligence`
- `domain: <kebab-case>`
- `classification: master | workflow | reporting | integration | reference`
- `verified_count`, `inferred_count`, `open_count`, `source_files_cited` — all integers

### B3: 11-section template compliance
Grep every domain file for all 11 mandatory section headers:
- `^## 1\. Purpose` … `^## 11\. Source References`
- Missing any section → test fail

### B4: Anti-hallucination
On a codebase with NO explicit OJK/regulatory references:
- The output's `40-business-rules/regulatory-rules.md` MUST mark all regulatory rules as `[INFERRED]` or `[OPEN]`
- MUST NOT invent POJK/PBI numbers
- `OQ-XXX-NN` markers MUST be present in every domain file's `## 10. Open Questions` section

### B5: Wave 5 main-thread synthesis
- After extraction completes, `99-rebuild-architecture/suggested-phasing.md` exists.
- The phasing doc cross-references domain files from waves 1-4 (proves main-thread synthesis ran with holistic context, not a single subagent dispatch).

### B6: Hand-off message
- On completion, the skill announces a next step:
  - Default: `/mega-sdd:generate-intent --kb=<out>/knowledge-base/` to bootstrap a vault.

### B7: Quality gate failure surfaced
- If Wave 1 produces a domain file missing `## 11. Source References`:
  - Skill MUST halt before Wave 2.
  - Halt message MUST name the failing file + the missing section.

## Pass criteria

All E1–E6 triggers fire correctly. B1–B7 behaviors verified against the validated trade-finance corpus (`/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import/old-reference/knowledge-base/` as reference oracle).
