# Starterkit Reuse-Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bolts reuse the starterkit's existing functions/methods/services/commands instead of reinventing them, via a scan-built reuse index + a bolt-time reuse-first protocol.

**Architecture:** A 5th deep-scan `reuse-extractor` (pack-hint-driven, mirroring the 3a authz-extractor pattern) catalogs the starterkit's callable API surface into a separate `.mega-sdd/codebase/reuse-index.yaml` (signatures + `_source` only). `generate-units` attaches per-unit `reuse_candidates` (fast-path hint); `execute-bolts` hands the bolt the FULL index path (primary lookup surface) + a relevant slice, and `bolt-implementer` runs a reuse-first protocol recording `reuse_decisions`. A post-flight **advisory** duplication check flags probable reinvention (never blocks).

**Tech Stack:** Markdown skill/reference/agent files, YAML schema, bash gate tests (mirroring `tests/de-laravelize/`), `grep`/`rg`. Builds on the 3a-implemented pack-hint architecture (`<*_FILE_HINTS>`/`<*_CONSTRUCT_MAP>`, `## Deep-scan file hints` pack sections, neutral schema v3.1).

**Spec:** `docs/superpowers/specs/2026-06-09-starterkit-reuse-awareness-design.md`

---

## File Structure

**New test files** (deterministic gates):
- `tests/reuse-awareness/test-reuse-schema.sh` — reuse-index schema doc has the 4 asset sections + `_source` rail
- `tests/reuse-awareness/test-reuse-extractor-neutral.sh` — reuse-extractor prompt is pack-hint-driven, zero Laravel tokens in the generic prompt
- `tests/reuse-awareness/test-reuse-hints-present.sh` — laravel.md + django.md carry a `## Reuse discovery` section; `_universal.md` has a generic one
- `tests/reuse-awareness/test-stage-wired.sh` — deep-scan-stage lists the reuse extractor + a reuse cache signature + reuse-index.yaml output
- `tests/reuse-awareness/test-unit-reuse-field.sh` — unit-schema documents `reuse_candidates`; starterkit-derivation derives it
- `tests/reuse-awareness/test-bolt-reuse-first.sh` — bolt-implementer has the reuse-first protocol + reuse_decisions; context-enrichment injects the index path + slice
- `tests/reuse-awareness/test-duplication-advisory.sh` — duplication validator exists and is advisory (no PreToolUse wiring)
- `tests/reuse-awareness/run-all.sh` — suite runner (cd to repo root, like the de-laravelize one)

**New plugin files:**
- `plugins/mega-sdd/references/reuse-index-schema.md` — canonical `reuse-index.yaml` schema
- `plugins/mega-sdd/scripts/validate-reuse-duplication.sh` — advisory post-flight duplication heuristic
- `tests/fixtures/reuse-awareness/laravel-sample/.mega-sdd/codebase/reuse-index.yaml` — sample index for tests

**Modified:**
- `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` — add `## reuse-extractor prompt` + Contents + `<REUSE_FILE_HINTS>`/`<REUSE_CONSTRUCT_MAP>` in Variable substitution
- `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-stage.md` — 5th slice `reuse`; cache signature; consolidation → `reuse-index.yaml`
- `plugins/mega-sdd/references/framework-conventions/laravel.md` + `django.md` — `## Reuse discovery` section; `_universal.md` — generic version
- `plugins/mega-sdd/references/lib-patterns/laravel/` + `django/` — (no new catalog; reuse uses hints, not lib catalogs)
- `plugins/mega-sdd/skills/generate-units/references/unit-schema.md` — `reuse_candidates` frontmatter field
- `plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md` — derive `reuse_candidates`
- `plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md` — T1 reuse-index path + T2 reuse slice
- `plugins/mega-sdd/agents/bolt-implementer.md` — reuse-first protocol + `reuse_decisions`
- `plugins/mega-sdd/skills/analyze/` (or the analyze runner) — surface the duplication advisory
- Versions: scan-codebase, generate-units, execute-bolts skill frontmatter; `plugin.json` + `marketplace.json` → v4.5.0

---

## Task 1: Suite scaffold + reuse-index schema

**Files:**
- Create: `tests/reuse-awareness/run-all.sh`, `tests/reuse-awareness/test-reuse-schema.sh`
- Create: `plugins/mega-sdd/references/reuse-index-schema.md`

- [ ] **Step 1: Create the suite runner**

```bash
mkdir -p tests/reuse-awareness
cat > tests/reuse-awareness/run-all.sh <<'EOF'
#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || { echo "cannot locate repo root"; exit 2; }
fail=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "=== $(basename "$t") ==="
  bash "$t" || { echo "FAIL: $(basename "$t")"; fail=1; }
done
exit $fail
EOF
chmod +x tests/reuse-awareness/run-all.sh
```

- [ ] **Step 2: Write the failing schema test**

```bash
cat > tests/reuse-awareness/test-reuse-schema.sh <<'EOF'
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/references/reuse-index-schema.md"
err=0
[ -f "$f" ] || { echo "missing reuse-index-schema.md"; exit 1; }
for s in "helpers:" "model_api:" "services:" "commands:"; do
  grep -qF "$s" "$f" || { echo "missing section: $s"; err=1; }
done
grep -qF "_source:" "$f" || { echo "missing _source anti-halu rail"; err=1; }
grep -qiE 'signature' "$f" || { echo "missing signature field"; err=1; }
grep -qiE 'no body|signatures only|never store' "$f" || { echo "missing 'signatures-only' rail"; err=1; }
exit $err
EOF
chmod +x tests/reuse-awareness/test-reuse-schema.sh
bash tests/reuse-awareness/test-reuse-schema.sh; echo "exit=$?"
```
Expected: exit=1 (missing file).

- [ ] **Step 3: Write `reuse-index-schema.md`**

```markdown
# Reuse Index Schema

> Canonical schema for `.mega-sdd/codebase/reuse-index.yaml` — the starterkit's callable API surface, so bolts reuse existing code instead of reinventing it. Sibling to `starterkit-context.yaml`; separately cacheable.

**Produced by:** `scan-codebase` deep-scan `reuse-extractor` (5th slice)
**Consumed by:** `generate-units` (per-unit `reuse_candidates`), `execute-bolts` (bolt reuse-first lookup), `validate-reuse-duplication.sh` (advisory)

## Anti-halu rails
1. Every entry MUST carry `_source: <file:line>`; an entry with no verifiable source is dropped, not emitted.
2. Signatures only — NEVER store a function body (bounds size; avoids stale-copy drift).
3. `purpose_confidence: inferred` marks any purpose not backed by a docblock.
4. Absence is omission, never a fabricated entry.
5. Per-category cap (default 300) with `truncated.<cat>: true` + overflow note when exceeded.

## Structure

```yaml
schema_version: "1.0"
generated_from: "<git sha or content signature>"
truncated: { helpers: false, model_api: false, services: false, commands: false }

helpers:
  - name: format_currency
    kind: global_helper            # global_helper | util_method
    path: app/Helpers/money.php
    signature: "format_currency(int $amount, string $currency = 'IDR'): string"
    purpose: "Format integer minor-units into a localized currency string"
    purpose_confidence: stated     # stated | inferred
    _source: "app/Helpers/money.php:42-58"

model_api:
  - model: "App\\Models\\User"
    path: app/Models/User.php
    methods: [ "hasRole(string|Role $role): bool   @88" ]
    scopes:  [ "scopeActive(Builder $q): Builder    @120" ]
    traits:  ["HasRoles", "HasAuditLog"]
    _source: "app/Models/User.php"

services:
  - class: "App\\Services\\CreateOrderService"
    path: app/Services/CreateOrderService.php
    entrypoints: [ "handle(OrderData $d): Order   @30" ]
    purpose: "Create an order with stock reservation + invoice"
    purpose_confidence: inferred
    _source: "app/Services/CreateOrderService.php:30-95"

commands:
  - signature: "sync:catalog {--force}"
    class: "App\\Console\\Commands\\SyncCatalog"
    path: app/Console/Commands/SyncCatalog.php
    purpose: "Re-sync product catalog from upstream"
    purpose_confidence: stated
    _source: "app/Console/Commands/SyncCatalog.php"
```
```

- [ ] **Step 4: Run the test → PASS**

Run: `bash tests/reuse-awareness/test-reuse-schema.sh; echo exit=$?` → 0.

- [ ] **Step 5: Commit**

```bash
git add tests/reuse-awareness/run-all.sh tests/reuse-awareness/test-reuse-schema.sh plugins/mega-sdd/references/reuse-index-schema.md
git commit -m "feat(reuse): reuse-index.yaml schema + gate scaffold"
```

---

## Task 2: reuse-extractor prompt (pack-hint-driven) + pack reuse-discovery sections

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md`
- Modify: `plugins/mega-sdd/references/framework-conventions/laravel.md`, `django.md`, `_universal.md`
- Test: `tests/reuse-awareness/test-reuse-extractor-neutral.sh`, `tests/reuse-awareness/test-reuse-hints-present.sh`

- [ ] **Step 1: Write the failing tests**

```bash
cat > tests/reuse-awareness/test-reuse-extractor-neutral.sh <<'EOF'
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md"
err=0
grep -q '## reuse-extractor prompt' "$f" || { echo "missing reuse-extractor prompt"; err=1; }
grep -q '<REUSE_FILE_HINTS>' "$f" || { echo "missing <REUSE_FILE_HINTS>"; err=1; }
# The reuse-extractor prompt body must be framework-neutral (no Laravel constructs)
body=$(sed -n '/## reuse-extractor prompt/,/^## [a-z]/p' "$f")
echo "$body" | grep -nE 'app/Helpers|app/Models|app/Services|app/Console|\.blade\.php|artisan|Eloquent' && { echo "Laravel leak in reuse prompt"; err=1; }
exit $err
EOF
chmod +x tests/reuse-awareness/test-reuse-extractor-neutral.sh

cat > tests/reuse-awareness/test-reuse-hints-present.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
for p in laravel django _universal; do
  grep -q '## Reuse discovery' "plugins/mega-sdd/references/framework-conventions/$p.md" || { echo "$p.md missing ## Reuse discovery"; err=1; }
done
# Laravel reuse discovery must name its real asset locations
grep -qE 'app/Helpers|app/Services|app/Console/Commands|app/Models' plugins/mega-sdd/references/framework-conventions/laravel.md || { echo "laravel reuse discovery not populated"; err=1; }
# _universal must be generic (NOT Laravel-shaped)
sec=$(sed -n '/## Reuse discovery/,/^## /p' plugins/mega-sdd/references/framework-conventions/_universal.md)
echo "$sec" | grep -qE 'app/Helpers|\.blade' && { echo "_universal reuse discovery leaks Laravel"; err=1; }
exit $err
EOF
chmod +x tests/reuse-awareness/test-reuse-hints-present.sh
```

Run both → both exit 1.

- [ ] **Step 2: Add `## reuse-extractor prompt` to deep-scan-prompts.md**

Append (after the libs-extractor prompt, before "Subagent dispatch pattern"), and add `reuse-extractor prompt` to the `## Contents` list, and `<REUSE_FILE_HINTS>` + `<REUSE_CONSTRUCT_MAP>` to `## Variable substitution`:

````markdown
## reuse-extractor prompt

```
ROLE: Reusable-code (callable API surface) cataloger for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
FILE HINTS: <REUSE_FILE_HINTS>          (from pack `## Reuse discovery`; or _universal generic)
CONSTRUCT MAP: <REUSE_CONSTRUCT_MAP>    (from pack `## Reuse discovery`; or _universal generic)

YOUR JOB:
Catalog the starterkit's OWN reusable code so downstream bolts call it instead of
reinventing it. Four asset categories: helpers/utils, model API (methods/scopes/traits),
services/actions, CLI/commands. Capture SIGNATURE + 1-line purpose + _source ONLY —
never a function body.

INPUTS TO READ:
1. <MANIFEST_FACTS> (authoritative; do NOT re-read manifests)
2. Each path/glob in <REUSE_FILE_HINTS>
   (use tree-sitter -> ast-grep -> ripgrep/regex fallback, the established tool ladder)

PROCEDURE:
1. For each category in <REUSE_CONSTRUCT_MAP>, enumerate the stack's reusable symbols at the hinted locations.
2. For each symbol emit: signature, a 1-line purpose (from docblock if present -> purpose_confidence: stated; else conservatively inferred -> inferred), and _source: <file:line>.
3. Drop any symbol you cannot cite with a real _source. Cap each category at 300; if exceeded set truncated.<cat>: true.

OUTPUT: a single reuse-index.yaml document per `references/reuse-index-schema.md` (helpers/model_api/services/commands).

CONSTRAINTS:
- READ-ONLY. Signatures only — NEVER copy a function body.
- Every entry cited in _source. Absence = omission, never a guess.
```
````

- [ ] **Step 3: Add `## Reuse discovery` to the three packs**

To `laravel.md`:
```markdown
## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "app/Helpers/**", "app/Support/**" ]   # + composer autoload.files
  model_api:[ "app/Models/**" ]                       # public methods, scope* methods, used traits
  services: [ "app/Services/**", "app/Actions/**" ]   # public entrypoints
  commands: [ "app/Console/Commands/**" ]             # $signature property
```
- model_api: public methods + `scope*` scopes + `use` traits on each Eloquent model.
- commands: the `$signature` string of each Artisan command.
```

To `django.md`:
```markdown
## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "**/utils.py", "**/helpers.py" ]
  model_api:[ "**/models.py" ]            # model methods + @property + managers
  services: [ "**/services.py", "**/selectors.py" ]
  commands: [ "**/management/commands/**" ]  # Command.handle
```
```

To `_universal.md` (generic, NOT framework-specific):
```markdown
## Reuse discovery (generic fallback)

```yaml
reuse_hints:
  helpers:  [ "**/helpers*", "**/util*", "**/lib/**" ]
  model_api:[ "**/models/**", "**/entities/**", "**/domain/**" ]
  services: [ "**/services/**", "**/actions/**", "**/usecases/**" ]
  commands: [ "**/commands/**", "**/cli/**", "**/cmd/**" ]
```
- helpers: top-level functions + static util methods. model_api: public methods on entity classes. services: public entrypoints on service/action classes. commands: declared CLI command handlers.
```

- [ ] **Step 4: Run both tests → PASS**

Run both; both exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md plugins/mega-sdd/references/framework-conventions/laravel.md plugins/mega-sdd/references/framework-conventions/django.md plugins/mega-sdd/references/framework-conventions/_universal.md tests/reuse-awareness/test-reuse-extractor-neutral.sh tests/reuse-awareness/test-reuse-hints-present.sh
git commit -m "feat(scan): pack-hint-driven reuse-extractor prompt + per-pack reuse discovery"
```

---

## Task 3: Wire reuse slice into deep-scan-stage (5th slice → reuse-index.yaml)

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-stage.md`
- Test: `tests/reuse-awareness/test-stage-wired.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/reuse-awareness/test-stage-wired.sh <<'EOF'
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/scan-codebase/references/deep-scan-stage.md"
err=0
grep -q 'reuse-extractor' "$f" || { echo "stage does not list reuse-extractor"; err=1; }
grep -qE 'reuse-index\.yaml' "$f" || { echo "stage does not emit reuse-index.yaml"; err=1; }
grep -qE '\[auth, authz, ui_ux, libs, reuse\]|reuse' "$f" || { echo "reuse not in slice list"; err=1; }
exit $err
EOF
chmod +x tests/reuse-awareness/test-stage-wired.sh
bash tests/reuse-awareness/test-stage-wired.sh; echo exit=$?
```
Expected exit=1.

- [ ] **Step 2: Wire the reuse slice into deep-scan-stage.md**

Make these edits (preserve surrounding structure):
- The `Subagents:` list (after libs-extractor #4): add `5. **reuse-extractor** — model: per references/model-tiers.md §reuse-extractor (default sonnet); hints: framework pack ## Reuse discovery; output: .mega-sdd/codebase/reuse-index.yaml (separate sibling artifact).`
- The slice arrays `[auth, authz, ui_ux, libs]` (lines ~47, 52): append `reuse` → `[auth, authz, ui_ux, libs, reuse]`.
- The `cache_signatures.per_slice` block (in the merged-YAML structure note ~line 280-ish and the schema): add a `reuse: { signature_sha256: <hex>, generated_at: <ISO8601> }` entry. The reuse signature input = first-party source tree signature (NOT lock files): `reuse_sig_input = sha256(concat of hinted source dir listings + mtimes) + framework_pack ## Reuse discovery content`.
- Consolidation note: the reuse slice is written to `.mega-sdd/codebase/reuse-index.yaml` (its OWN file, per `references/reuse-index-schema.md`), NOT merged into `starterkit-context.yaml`. The handoff carries `reuse_index: { path, counts, truncated }`.
- Add to model-tiers.md a `reuse-extractor` row (default sonnet).

- [ ] **Step 3: Run test → PASS**; also confirm no regression: `bash tests/de-laravelize/run-all.sh; echo de=$?` → 0.

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/skills/scan-codebase/references/deep-scan-stage.md plugins/mega-sdd/skills/scan-codebase/references/model-tiers.md tests/reuse-awareness/test-stage-wired.sh
git commit -m "feat(scan): dispatch reuse-extractor as 5th slice; emit reuse-index.yaml"
```

---

## Task 4: generate-units — `reuse_candidates` (schema field + derivation)

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/references/unit-schema.md`
- Modify: `plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md`
- Test: `tests/reuse-awareness/test-unit-reuse-field.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/reuse-awareness/test-unit-reuse-field.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
grep -q 'reuse_candidates' plugins/mega-sdd/skills/generate-units/references/unit-schema.md || { echo "unit-schema missing reuse_candidates"; err=1; }
grep -q 'reuse-index' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "derivation does not read reuse-index"; err=1; }
grep -q 'reuse_candidates' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "derivation does not emit reuse_candidates"; err=1; }
# fast-path-hint framing must be explicit (full index is primary surface)
grep -qiE 'fast-path|hint, not|primary lookup' plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md || { echo "missing fast-path-hint framing"; err=1; }
exit $err
EOF
chmod +x tests/reuse-awareness/test-unit-reuse-field.sh
```

- [ ] **Step 2: Add the `reuse_candidates` field to unit-schema.md**

In the `## Required frontmatter` section, document a new OPTIONAL field:
```yaml
reuse_candidates:                  # OPTIONAL — fast-path hints from reuse-index.yaml (NOT exhaustive; the bolt reads the full index)
  - { name: <symbol>, path: <file>, signature: <sig>, purpose: <1-line> }
```
State: absent when no candidate matched; never fabricated.

- [ ] **Step 3: Add derivation logic to starterkit-derivation.md**

Add a sub-step (after the existing starterkit anchor/hard-rule derivation):
```
### Reuse candidate derivation (fast-path hint, NOT the bolt's primary surface)
IF reuse-index.yaml exists:
  for this unit, select up to ~12 entries from reuse-index.{helpers,model_api,services,commands}
  whose name/purpose keywords overlap the unit's title/description/domain
  OR whose path overlaps the unit's target_files prefix.
  Attach them as unit.reuse_candidates [{name, path, signature, purpose}].
  These are a FAST-PATH HINT only — the bolt receives the full reuse-index.yaml path and
  scans it at write time (a cross-cutting helper often won't keyword-match a unit but is in the index).
  No match => omit reuse_candidates (valid; never fabricate).
```

- [ ] **Step 4: Run test → PASS** (exit 0). No-regression: `bash tests/de-laravelize/run-all.sh; echo de=$?` → 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/generate-units/references/unit-schema.md plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md tests/reuse-awareness/test-unit-reuse-field.sh
git commit -m "feat(generate-units): per-unit reuse_candidates fast-path hints from reuse-index"
```

---

## Task 5: execute-bolts — inject reuse-index path (T1) + reuse slice (T2) + bolt reuse-first protocol

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md`
- Modify: `plugins/mega-sdd/agents/bolt-implementer.md`
- Test: `tests/reuse-awareness/test-bolt-reuse-first.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/reuse-awareness/test-bolt-reuse-first.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
ce="plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md"
bi="plugins/mega-sdd/agents/bolt-implementer.md"
# T1 carries the reuse-index PATH always; T2 carries the relevant slice
grep -qE 'reuse-index\.yaml' "$ce" || { echo "context-enrichment does not inject reuse-index path"; err=1; }
grep -qiE 'reuse_candidates' "$ce" || { echo "context-enrichment does not carry reuse_candidates"; err=1; }
# bolt-implementer reuse-first protocol + decisions
grep -qiE 'reuse-first|reuse first' "$bi" || { echo "bolt-implementer missing reuse-first protocol"; err=1; }
grep -qF 'reuse_decisions' "$bi" || { echo "bolt-implementer missing reuse_decisions"; err=1; }
grep -qiE 'scan the full reuse-index|read the full index|not just the' "$bi" || { echo "bolt-implementer does not make the full index the primary surface"; err=1; }
exit $err
EOF
chmod +x tests/reuse-awareness/test-bolt-reuse-first.sh
```

- [ ] **Step 2: Wire context-enrichment.md**

- In `## TIER 1 (always included, target ≤2KB)`: add two lines — `unit.reuse_candidates` (the fast-path hint, when present) AND the line `Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup; scan it for any capability you are about to write (the implementer has Read/Grep). reuse_candidates above are a hint, not the boundary.` (the path is included even when no candidates matched).
- In the `## T2 section priority + truncation cascade` table: add a `reuse_slice` T2 section (a filtered slice of reuse-index entries matching the unit's reuse_candidates + target_files), with a sensible priority (below framework-pack rules, above historical memory) and a truncation cascade ending in "+N more — read reuse-index.yaml directly". Build the slice in the existing "Starterkit slice: build" area: `IF reuse-index.yaml exists: slice.reuse = entries whose path overlaps unit.target_files OR whose name is in unit.reuse_candidates`.

- [ ] **Step 3: Add the reuse-first protocol to bolt-implementer.md**

Add to `## The Iron Rules` a 4th rule:
```
4. **Reuse before you build.** Before implementing any capability: (a) check `reuse_candidates` (a hint), (b) **scan the full `reuse-index.yaml`** (path in your prompt; you have Read/Grep) for an existing helper/model-method/service/command that covers it — cross-cutting helpers are often absent from the per-unit hint and present only in the full index, (c) **read the actual function** at its `_source` before deciding, (d) reuse it if it fits, OR if you write fresh, record the reason in `reuse_decisions`. Reinventing something the index already provides — without a recorded reason — is a rejected bolt.
```
Add to the `## Report format`: `- **reuse_decisions:** [ {candidate, decision: reused|not_applicable|reimplemented, reason?} ] — reimplemented without a reason is a finding.`

- [ ] **Step 4: Run test → PASS** (exit 0). No-regression: de-laravelize suite 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md plugins/mega-sdd/agents/bolt-implementer.md tests/reuse-awareness/test-bolt-reuse-first.sh
git commit -m "feat(execute-bolts): reuse-index path (T1 primary surface) + slice (T2) + bolt reuse-first protocol"
```

---

## Task 6: Post-flight advisory duplication check

**Files:**
- Create: `plugins/mega-sdd/scripts/validate-reuse-duplication.sh`
- Modify: the analyze runner (`plugins/mega-sdd/scripts/run-analyze.sh`) to call it as ADVISORY
- Test: `tests/reuse-awareness/test-duplication-advisory.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/reuse-awareness/test-duplication-advisory.sh <<'EOF'
#!/usr/bin/env bash
set -u
err=0
v="plugins/mega-sdd/scripts/validate-reuse-duplication.sh"
[ -f "$v" ] || { echo "missing validate-reuse-duplication.sh"; err=1; }
[ -x "$v" ] || { echo "validator not executable"; err=1; }
# MUST be advisory: never exit non-zero to block; never wired into the PreToolUse hook
grep -qiE 'advisory|never block|exit 0' "$v" || { echo "validator not marked advisory"; err=1; }
grep -q 'validate-reuse-duplication' plugins/mega-sdd/hooks/pre-tool-use && { echo "duplication check wrongly wired into PreToolUse (must stay advisory)"; err=1; }
exit $err
EOF
chmod +x tests/reuse-awareness/test-duplication-advisory.sh
```

- [ ] **Step 2: Write `validate-reuse-duplication.sh` (advisory)**

```bash
#!/usr/bin/env bash
# ADVISORY post-flight reuse-duplication heuristic. NEVER blocks (always exits 0).
# Compares newly-introduced symbol names against reuse-index.yaml entries; emits WARNINGs
# with both _source locations. Surfaced via /mega-sdd:analyze; NOT wired to PreToolUse.
set -u
CWD="${1:-$PWD}"
idx="$CWD/.mega-sdd/codebase/reuse-index.yaml"
[ -f "$idx" ] || { echo "[reuse-dup] no reuse-index.yaml — skipping (advisory)"; exit 0; }
# Heuristic: collect index symbol names; grep the last commit's added defs; report name collisions.
names=$(grep -oE 'name: [A-Za-z_][A-Za-z0-9_]*' "$idx" | awk '{print $2}' | sort -u)
added=$(git -C "$CWD" diff HEAD~1 HEAD --unified=0 2>/dev/null | grep -E '^\+.*(function |def |public function )' || true)
hits=0
while IFS= read -r n; do
  [ -z "$n" ] && continue
  if echo "$added" | grep -qw "$n"; then
    echo "[reuse-dup][WARN] new code may reinvent existing '$n' (see reuse-index.yaml _source). Verify before merge."
    hits=$((hits+1))
  fi
done <<< "$names"
echo "[reuse-dup] advisory scan complete — $hits possible duplication(s). (non-blocking)"
exit 0
```

- [ ] **Step 3: Surface it in the analyze runner**

In `plugins/mega-sdd/scripts/run-analyze.sh`, add a call to `validate-reuse-duplication.sh "$CWD"` in the advisory section (append its output to the consistency report; do NOT let its result affect the gate exit). Follow the existing pattern for advisory checks in that script.

- [ ] **Step 4: Run test → PASS**. Run the validator against the repo to confirm it exits 0: `bash plugins/mega-sdd/scripts/validate-reuse-duplication.sh "$PWD"; echo rc=$?` → rc=0.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/validate-reuse-duplication.sh plugins/mega-sdd/scripts/run-analyze.sh tests/reuse-awareness/test-duplication-advisory.sh
git commit -m "feat(analyze): advisory reuse-duplication check (non-blocking, surfaced via /analyze)"
```

---

## Task 7: Sample fixture + full-suite green + version bumps

**Files:**
- Create: `tests/fixtures/reuse-awareness/laravel-sample/.mega-sdd/codebase/reuse-index.yaml`
- Modify: scan-codebase / generate-units / execute-bolts SKILL.md versions; `plugin.json` + `marketplace.json`

- [ ] **Step 1: Create a sample reuse-index.yaml fixture** (valid per schema; one entry per category)

```bash
mkdir -p tests/fixtures/reuse-awareness/laravel-sample/.mega-sdd/codebase
cat > tests/fixtures/reuse-awareness/laravel-sample/.mega-sdd/codebase/reuse-index.yaml <<'EOF'
schema_version: "1.0"
generated_from: "deadbeef"
truncated: { helpers: false, model_api: false, services: false, commands: false }
helpers:
  - { name: format_currency, kind: global_helper, path: app/Helpers/money.php, signature: "format_currency(int $amount): string", purpose: "Format minor units to IDR", purpose_confidence: stated, _source: "app/Helpers/money.php:42" }
model_api:
  - { model: "App\\Models\\User", path: app/Models/User.php, methods: ["hasRole(string $r): bool   @88"], scopes: ["scopeActive(Builder $q): Builder @120"], traits: ["HasRoles"], _source: "app/Models/User.php" }
services:
  - { class: "App\\Services\\CreateOrderService", path: app/Services/CreateOrderService.php, entrypoints: ["handle(OrderData $d): Order @30"], purpose: "Create order + invoice", purpose_confidence: inferred, _source: "app/Services/CreateOrderService.php:30" }
commands:
  - { signature: "sync:catalog {--force}", class: "App\\Console\\Commands\\SyncCatalog", path: app/Console/Commands/SyncCatalog.php, purpose: "Re-sync catalog", purpose_confidence: stated, _source: "app/Console/Commands/SyncCatalog.php" }
EOF
```

- [ ] **Step 2: Add a fixture validity check to the schema test** (extend `test-reuse-schema.sh` to also assert the fixture parses + uses the 4 sections):

Append to `tests/reuse-awareness/test-reuse-schema.sh` before `exit $err`:
```bash
fx="tests/fixtures/reuse-awareness/laravel-sample/.mega-sdd/codebase/reuse-index.yaml"
if [ -f "$fx" ]; then
  for s in "helpers:" "model_api:" "services:" "commands:"; do grep -qF "$s" "$fx" || { echo "fixture missing $s"; err=1; }; done
  grep -q '_source:' "$fx" || { echo "fixture missing _source"; err=1; }
fi
```

- [ ] **Step 3: Bump versions** — scan-codebase 2.1.0→2.2.0, generate-units 2.2.0→2.3.0, execute-bolts 2.3.0→2.4.0; `plugin.json` + `marketplace.json` 4.4.0→4.5.0 (add a version_note line).

- [ ] **Step 4: Full suites green**

Run: `bash tests/reuse-awareness/run-all.sh; echo reuse=$?` → 0. `bash tests/de-laravelize/run-all.sh; echo de=$?` → 0.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(release): reuse-awareness sample fixture + v4.5.0 bump; full suites green"
```

---

## Self-Review (completed by author)

- **Spec coverage:** §A reuse-index schema→Task 1; §B reuse-extractor (pack-hint-driven)→Tasks 2-3; §C reuse_candidates + unit-schema→Task 4; §D execute-bolts path(T1 primary)+slice(T2)+reuse-first protocol+reuse_decisions→Task 5; §E advisory duplication→Task 6; §F framework-pack-driven (laravel+django+_universal reuse discovery)→Task 2; versioning→Task 7. Spec's "full index is primary lookup surface" is enforced in Task 5 (T1 path + bolt scans full index) and Task 4 (fast-path-hint framing). All sections mapped.
- **Placeholder scan:** test scripts + novel content (schema, prompt, hints, validator) authored in full; wiring steps cite exact files + sections + the exact lines/blocks to add.
- **Type consistency:** field names align across tasks — `reuse-index.yaml` sections `helpers/model_api/services/commands`, entry fields `{name,path,signature,purpose,_source}`, unit `reuse_candidates[]`, bolt `reuse_decisions[]` — used identically in schema (T1), extractor (T2), derivation (T4), context-enrichment + bolt (T5), validator (T6), fixture (T7).
