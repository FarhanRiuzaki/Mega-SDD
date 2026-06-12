# Pack-Authoring Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the author-time pack kit — a `validate-pack.sh` linter + `_lint.md` checklist, an auto-generated `_registry.md` readiness table, and a `scaffold-pack.sh` generator — so 3c per-stack packs are cheap + validated.

**Architecture:** Three bash scripts + two reference docs under existing locations, plus a `## Reuse discovery` addition to `_template.md` and a README/scan advisory touch-up. Author/CI tooling only — the linter exits non-zero on a malformed pack (gates pack PRs) but is NEVER wired into a runtime hook; pipeline behavior is unchanged except one advisory readiness note in scan output.

**Tech Stack:** bash, python-yaml (graceful structural fallback), markdown. Deterministic gate suite `tests/pack-kit/` (mirrors `tests/de-laravelize/`).

**Spec:** `docs/superpowers/specs/2026-06-09-pack-authoring-kit-design.md` (read it for the full contract).

**Prereq for the implementer:** read `plugins/mega-sdd/references/framework-conventions/_template.md` (the contract), `laravel.md` (the must-pass reference pack), `django.md` (the thin proof-pack), `README.md` (the "Adding a new pack" + Files sections), and `scan-codebase/references/scan-procedure.md §8.5` (the detection table) before starting.

---

## File Structure
- New: `plugins/mega-sdd/references/framework-conventions/_lint.md` (checklist + cross-framework token map)
- New: `plugins/mega-sdd/scripts/validate-pack.sh` (linter; modes: `<pack>`, `--all`, `--registry`, `--check-registry`)
- New: `plugins/mega-sdd/references/framework-conventions/_registry.md` (generated)
- New: `plugins/mega-sdd/scripts/scaffold-pack.sh`
- New: `tests/pack-kit/{run-all.sh,test-*.sh}` + `tests/fixtures/pack-kit/bad-pack.md`
- Modify: `_template.md` (+ `## Reuse discovery`), `framework-conventions/README.md` (un-TBD + Files), `scan-codebase/SKILL.md` or `references/deep-scan-stage.md` (advisory readiness note), `laravel.md`/`django.md` (add `pack_tier:` frontmatter)
- Versions: scan-codebase skill + `plugin.json` + `marketplace.json` → v4.7.0

---

## Task 1: `## Reuse discovery` into `_template.md` + suite scaffold

**Files:** `_template.md`; `tests/pack-kit/run-all.sh`, `tests/pack-kit/test-template-has-reuse.sh`

- [ ] **Step 1:** Create `tests/pack-kit/run-all.sh` (copy the `tests/reuse-awareness/run-all.sh` runner verbatim — `cd "$here/../.."` then loop `test-*.sh`). chmod +x.
- [ ] **Step 2:** Write `tests/pack-kit/test-template-has-reuse.sh`:
```bash
#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/references/framework-conventions/_template.md"
grep -q '## Reuse discovery' "$f" || { echo "_template.md missing ## Reuse discovery"; exit 1; }
grep -q 'reuse_hints' "$f" || { echo "_template.md Reuse discovery missing reuse_hints"; exit 1; }
exit 0
```
chmod +x; run → exit 1.
- [ ] **Step 3:** Append to `_template.md` (after the existing `## UI detection` contract section, matching its `<!-- REQUIRED when… -->` style):
````markdown
## Reuse discovery   <!-- REQUIRED when the stack has reusable first-party code -->

```yaml
reuse_hints:
  helpers:  [ <globs where helper/util functions live> ]
  model_api:[ <globs where domain models live — methods/scopes/traits> ]
  services: [ <globs where service/action classes live> ]
  commands: [ <globs where CLI/commands live> ]
```
- model_api: public methods + scopes + traits on each model. commands: each command's signature/handler.
````
- [ ] **Step 4:** run test → PASS. Regression: `bash tests/reuse-awareness/run-all.sh; echo r=$?` → 0.
- [ ] **Step 5:** commit: `git add plugins/mega-sdd/references/framework-conventions/_template.md tests/pack-kit/ && git commit -m "feat(packs): add Reuse discovery to _template contract + pack-kit suite scaffold"`

---

## Task 2: `validate-pack.sh` linter + `_lint.md` checklist

**Files:** `plugins/mega-sdd/scripts/validate-pack.sh`, `references/framework-conventions/_lint.md`; tests `test-linter-accepts-good.sh`, `test-linter-rejects-bad.sh`, `tests/fixtures/pack-kit/bad-pack.md`

- [ ] **Step 1:** Write the two failing tests + the bad fixture.
`tests/fixtures/pack-kit/bad-pack.md` — a deliberately malformed pack: frontmatter `framework: django` but body contains `Gate::define` and `app/Http/Middleware`, missing `## Testing conventions`, and a broken yaml block under `## Deep-scan file hints`.
`tests/pack-kit/test-linter-accepts-good.sh`:
```bash
#!/usr/bin/env bash
set -u
bash plugins/mega-sdd/scripts/validate-pack.sh plugins/mega-sdd/references/framework-conventions/laravel.md
rc=$?; [ $rc -eq 0 ] || { echo "linter rejected the reference laravel.md (rc=$rc)"; exit 1; }
exit 0
```
`tests/pack-kit/test-linter-rejects-bad.sh`:
```bash
#!/usr/bin/env bash
set -u
out=$(bash plugins/mega-sdd/scripts/validate-pack.sh tests/fixtures/pack-kit/bad-pack.md 2>&1); rc=$?
[ $rc -ne 0 ] || { echo "linter accepted a malformed pack"; exit 1; }
echo "$out" | grep -qiE 'Testing conventions|missing section' || { echo "did not flag the missing section"; exit 1; }
echo "$out" | grep -qiE 'leak|Gate::define|cross-framework' || { echo "did not flag the Laravel leak"; exit 1; }
exit 0
```
chmod +x all; run both → fail (no script yet).
- [ ] **Step 2:** Write `_lint.md` — the checklist (the 5 checks from spec §2.1, in prose) + a `## Cross-framework token map` section listing per-framework forbidden tokens (laravel: `app/Http`, `Gate::define`, `$routeMiddleware`, `.blade.php`, `Eloquent`, `artisan`). The script reads this map.
- [ ] **Step 3:** Write `plugins/mega-sdd/scripts/validate-pack.sh`. Implement (per spec §2.1):
  - arg parse: `<pack.md>` | `--all` | `--registry` | `--check-registry` (Tasks 2 implements `<pack>` + `--all`; Task 3 adds `--registry`/`--check-registry`).
  - For a pack: read frontmatter (between the first two `---`); assert `framework:`, `detection_signature` (+ `package_manifest`,`dependency_marker`), `framework_version_range:`.
  - Assert required-always sections present: `## File location standards`, `## Naming standards`, `## Idioms`, `## Hard Rules emitted`, `## Testing conventions`.
  - Assert conditional sections present OR N/A: for each of `## Deep-scan file hints`,`## Authz mapping`,`## UI detection`,`## Reuse discovery` — heading present; if followed by `_(N/A:` it's allowed.
  - YAML check: extract each ```yaml block under the hint sections; pipe to `python3 -c 'import sys,yaml;yaml.safe_load(sys.stdin.read())'` (try `python3` then `/opt/homebrew/bin/python3.11`); on missing yaml module → structural brace/indent check + a "yaml validator unavailable" note (never hard-fail on missing dep).
  - Cross-framework leak: read `_lint.md`'s token map; for the pack's declared `framework`, grep the body for OTHER frameworks' forbidden tokens (excluding fenced blocks labeled "contrast example") → violation.
  - Print each violation; exit 1 if any, else 0. `--all`: loop `<fw>.md` excluding `_template/_universal/_lint/_registry`; aggregate exit.
- [ ] **Step 4:** run both tests → PASS. If `test-linter-accepts-good` fails, the laravel.md pack is missing a now-required section (e.g. it may lack `## Reuse discovery` until #2 added it — verify; if a real gap, that's a finding — add the section to laravel.md or mark the check conditional correctly).
- [ ] **Step 5:** commit: `feat(packs): validate-pack.sh linter + _lint.md checklist (author/CI gate)`

---

## Task 3: `_registry.md` generator + freshness gate

**Files:** `validate-pack.sh` (add `--registry`/`--check-registry`), `references/framework-conventions/_registry.md`, `laravel.md`+`django.md` (add `pack_tier:`); test `test-registry-fresh.sh`

- [ ] **Step 1:** Write `tests/pack-kit/test-registry-fresh.sh`:
```bash
#!/usr/bin/env bash
set -u
bash plugins/mega-sdd/scripts/validate-pack.sh --check-registry || { echo "_registry.md stale — run --registry"; exit 1; }
r="plugins/mega-sdd/references/framework-conventions/_registry.md"
grep -qiE 'laravel.*ready' "$r" || { echo "laravel not ready in registry"; exit 1; }
grep -qiE 'django.*thin' "$r" || { echo "django not thin in registry"; exit 1; }
grep -qiE 'none' "$r" || { echo "registry lists no 'none' framework"; exit 1; }
exit 0
```
chmod +x; run → fail.
- [ ] **Step 2:** Add `pack_tier: full` to `laravel.md` frontmatter and `pack_tier: thin` to `django.md` frontmatter.
- [ ] **Step 3:** Add `--registry` + `--check-registry` to `validate-pack.sh`: parse the detection table from `scan-codebase/references/scan-procedure.md §8.5` (the framework fingerprint rows) → for each framework, status = `ready` if `<fw>.md` exists with `pack_tier: full` AND lints clean; `thin` if `pack_tier: thin`; `none` if no `<fw>.md`. `--registry` writes `_registry.md` (a markdown table: framework | pack file | tier | status | lints_clean). `--check-registry` regenerates in-memory + diffs the committed file → exit 1 if different.
- [ ] **Step 4:** Run `validate-pack.sh --registry` to generate `_registry.md`. Run test → PASS.
- [ ] **Step 5:** commit: `feat(packs): auto-generated _registry.md pack-readiness table + freshness gate`

---

## Task 4: `scaffold-pack.sh` generator

**Files:** `plugins/mega-sdd/scripts/scaffold-pack.sh`; test `test-scaffold-smoke.sh`

- [ ] **Step 1:** Write `tests/pack-kit/test-scaffold-smoke.sh`:
```bash
#!/usr/bin/env bash
set -u
tmp="tests/fixtures/pack-kit/.scratch"; rm -rf "$tmp"; mkdir -p "$tmp"
# scaffold into a sandbox dir override
out=$(SCAFFOLD_DEST_DIR="$tmp" bash plugins/mega-sdd/scripts/scaffold-pack.sh fastapi 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "scaffold failed: $out"; exit 1; }
f="$tmp/fastapi.md"
[ -f "$f" ] || { echo "no skeleton produced"; exit 1; }
for s in "## File location standards" "## Deep-scan file hints" "## Authz mapping" "## UI detection" "## Reuse discovery"; do grep -qF "$s" "$f" || { echo "skeleton missing $s"; exit 1; }; done
grep -q 'framework: fastapi' "$f" || { echo "frontmatter not filled"; exit 1; }
# no-clobber
SCAFFOLD_DEST_DIR="$tmp" bash plugins/mega-sdd/scripts/scaffold-pack.sh fastapi >/dev/null 2>&1 && { echo "clobbered existing"; exit 1; }
rm -rf "$tmp"; exit 0
```
chmod +x; run → fail.
- [ ] **Step 2:** Write `scaffold-pack.sh <framework>`: dest dir = `${SCAFFOLD_DEST_DIR:-plugins/mega-sdd/references/framework-conventions}`; refuse if `<dest>/<fw>.md` exists (exit 1); copy `_template.md` → `<dest>/<fw>.md`; replace the title line + set frontmatter `framework: <fw>`, `pack_tier: thin`, `framework_version_range: "TBD"`, `detection_signature:` stub (package_manifest/dependency_marker placeholders); keep all section markers; print next-steps (fill sections → `validate-pack.sh <fw>.md` → `validate-pack.sh --registry`).
- [ ] **Step 3:** run test → PASS.
- [ ] **Step 4:** commit: `feat(packs): scaffold-pack.sh — linter-valid pack skeleton from _template`

---

## Task 5: README + scan advisory + not-a-hook gate + v4.7.0

**Files:** `framework-conventions/README.md`, `scan-codebase/SKILL.md` (or `references/deep-scan-stage.md`), `test-linter-not-a-hook.sh`, versions

- [ ] **Step 1:** Write `tests/pack-kit/test-linter-not-a-hook.sh`:
```bash
#!/usr/bin/env bash
set -u
grep -q 'validate-pack' plugins/mega-sdd/hooks/pre-tool-use 2>/dev/null && { echo "validate-pack wrongly wired into PreToolUse (must stay author tool)"; exit 1; }
exit 0
```
chmod +x; run → PASS (it's not wired).
- [ ] **Step 2:** README: replace step 4 "TBD: pack linter" with "run `scripts/validate-pack.sh <pack>.md` (checklist: `_lint.md`); CI gate: `validate-pack.sh --all && validate-pack.sh --check-registry`". Add `_lint.md` + `_registry.md` rows to the Files table. Mention `scripts/scaffold-pack.sh <fw>` in "Adding a new pack" step 1.
- [ ] **Step 3:** Add the advisory readiness note to scan output: in `scan-codebase/references/deep-scan-stage.md` (or SKILL.md §output), after §7 Framework is populated, read `_registry.md` and emit an advisory line for `thin`/`none` status: `pack coverage: <status> for <framework> — generic _universal fallback; see framework-conventions/_registry.md`. Advisory only; `_registry.md` absent → skip. (Add a one-line note; do not add a hook.)
- [ ] **Step 4:** Bump scan-codebase skill version (minor) + `plugin.json` + `marketplace.json` 4.6.0 → 4.7.0 (with a version_note).
- [ ] **Step 5:** Full gates: `for t in pack-kit de-laravelize reuse-awareness phase-advisor; do bash tests/$t/run-all.sh >/dev/null 2>&1; echo "$t=$?"; done` → all 0. JSON valid.
- [ ] **Step 6:** commit: `chore(release): pack-authoring kit v4.7.0 — README un-TBD + scan readiness advisory; suites green`

---

## Self-Review (completed by author)
- **Spec coverage:** §2.1 linter→Tasks 2; §2.2 registry→Task 3; §2.3 scaffold→Task 4; §2.4 _template reuse→Task 1; §3 flow + §4 errors→across; README/scan wiring→Task 5; not-a-hook→Task 5; versioning→Task 5. Acceptance #1-9 all mapped.
- **Placeholder scan:** test scripts authored in full; the script bodies are specified by exact behavior + the spec §2 contract (the implementer writes bash to satisfy the named checks + the gate tests — gates are the objective contract). _lint.md/_template content authored.
- **Type consistency:** modes (`<pack>`/`--all`/`--registry`/`--check-registry`), `pack_tier` (full|thin), status (ready|thin|none), section names — consistent across linter (T2), registry (T3), scaffold (T4), tests.
- **Determinism honesty:** unlike the LLM-agent features, these are deterministic scripts — the gate tests are real assertions (reject-bad, accept-good, registry-fresh, scaffold-smoke, not-a-hook), not scenario docs.
- **Risk note for executor:** Task 2 Step 4 — if `validate-pack.sh laravel.md` fails because laravel.md lacks a now-required conditional section, verify against the spec's required-vs-conditional split (conditional sections allow `_(N/A:)_`); fix laravel.md OR the check, don't weaken the contract.
