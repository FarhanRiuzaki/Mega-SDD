# Pack-Authoring Kit — linter + readiness registry + scaffold (Spec 3b)

**Status:** Design approved 2026-06-09
**Plugin target:** v4.6.0 → v4.7.0
**Type:** Tooling (author-time pack quality kit) — no runtime/pipeline behavior change
**Decomposition:** Spec **3b** of the multi-stack effort. Depends on **3a** (the pack contract: `## Deep-scan file hints` / `## Authz mapping` / `## UI detection`) which shipped in v4.4.0, and on the `## Reuse discovery` contract from v4.5.0. Unblocks **3c** (per-stack packs) by making each pack cheap to author + validated.

---

## Background and motivation

mega-sdd's deep-scan is now genuinely tech-stack-agnostic (3a) and reuse-aware (#2), but only Laravel has a full pack (+ a thin Django proof-pack). Authoring the remaining ~21 detected frameworks (3c) is currently unsafe + inconsistent: the `framework-conventions/README.md` "Adding a new pack" step 4 references a pack linter `_lint.md` that is marked **TBD** and does not exist, there is no record of which frameworks have a pack vs fall back to `_universal`, and a new pack starts from a 17KB hand-copied `_template.md`.

This kit closes those gaps with three author-time tools:
1. **Pack linter** — a deterministic validator + the `_lint.md` checklist, so a new pack is provably conformant to the `_template.md` contract before it ships.
2. **Pack-readiness registry** — an auto-derived record of pack coverage across the detected frameworks, surfaced in scan output so users know whether their stack has a real pack or only the generic fallback.
3. **Scaffold generator** — produces a linter-valid pack skeleton for a named framework.

It also reconciles a contract gap: v4.5.0 added `## Reuse discovery` to the packs but not to `_template.md`; the linter validates against the contract, so `_template.md` must document it.

**Non-goal:** authoring actual new packs (that is 3c). This kit is purely the tooling that makes 3c safe and cheap. It introduces **no runtime/pipeline behavior change** and **no new blocking hook** — the linter is an author/CI gate (it exits non-zero on a malformed pack), not a PreToolUse hook.

---

## §1 Architecture overview

Three author-time artifacts, all under existing locations:

- `plugins/mega-sdd/references/framework-conventions/_lint.md` — the human-readable conformance checklist (what `validate-pack.sh` enforces, in prose).
- `plugins/mega-sdd/scripts/validate-pack.sh` — the deterministic linter. `validate-pack.sh <pack.md>` lints one pack; `--all` lints every `<fw>.md` in the conventions dir (excluding `_template.md`/`_universal.md`/`_lint.md`/`_registry.md`); `--registry` regenerates `_registry.md`; `--check-registry` fails if `_registry.md` is stale. Exits non-zero on any violation (author/CI gate).
- `plugins/mega-sdd/references/framework-conventions/_registry.md` — auto-generated pack-readiness table.
- `plugins/mega-sdd/scripts/scaffold-pack.sh` — `scaffold-pack.sh <framework>` writes a linter-valid `<framework>.md` skeleton from `_template.md`.

Plus contract + docs reconciliation: add `## Reuse discovery` to `_template.md`; update README (remove the TBD; add the new files); have `scan-codebase` surface pack-readiness from `_registry.md`.

These are tooling files; the pipeline skills (scan/bind/units/bolts) are unchanged except for the one advisory readiness note in scan output.

---

## §2 Components

### 2.1 Pack linter (`validate-pack.sh` + `_lint.md`)

`validate-pack.sh <pack.md>` checks, in order (each failure printed with the offending pack + reason; non-zero exit if any fail):

1. **Frontmatter present + parseable** with required keys: `framework:` (lowercase id), `detection_signature:` (with `package_manifest` + `dependency_marker`), `framework_version_range:`.
2. **Required-always sections present** (the core contract from `_template.md`): `## File location standards`, `## Naming standards`, `## Idioms`, `## Hard Rules emitted`, `## Testing conventions`.
3. **Conditional-required contract sections** — `## Deep-scan file hints`, `## Authz mapping`, `## UI detection`, `## Reuse discovery`. Each must be PRESENT, or explicitly declared not-applicable via a one-line `_(N/A: <reason>)_` marker under the heading (a stack with no authorization may N/A `## Authz mapping`). Silent omission fails.
4. **YAML validity** of every fenced `yaml` block under the hint sections (`auth_hints`/`authz_hints`/`ui_hints` in Deep-scan file hints; `reuse_hints` in Reuse discovery). Parsed with the same python-yaml the repo already uses; a parse error fails.
5. **Cross-framework leak check** — the pack's content must match its declared `framework:`. A non-laravel pack must NOT contain Laravel construct tokens (`app/Http`, `Gate::define`, `$routeMiddleware`, `.blade.php`, `Eloquent`, `artisan`) outside an explicit "contrast example" fenced block. (Generalizes the de-laravelize discipline: a Django pack hunting `Gate::define` is a copy-paste error.) The token→framework map lives in `_lint.md` so it is extensible.

`_lint.md` documents each check as a human checklist (so a PR author can self-check) and carries the cross-framework token map.

**Why non-zero exit (vs the advisory pattern used elsewhere):** unlike the runtime advisory checks (reuse-duplication, etc.) which must never block a developer's pipeline, this linter runs at *pack-authoring* time on a *pack file* — failing the build is its job (it gates pack PRs). It is never wired into a PreToolUse hook, so it never blocks an end-user's scan/bind/units/bolts run.

### Amendment (during implementation) — tier-aware `--all`

`--all` aggregation is tier-aware: `pack_tier: full` packs block on any violation; `thin`/untiered packs block only on structural errors (invalid YAML / cross-framework leak). Missing-section gaps in thin proof-packs or overlays are reported but non-blocking. Single-pack mode (`validate-pack.sh <pack>`) remains strict (non-zero on any violation). This keeps `validate-pack.sh --all` a usable green CI gate while honoring intentionally-incomplete thin proof-packs.

### 2.2 Pack-readiness registry (`_registry.md`, auto-generated)

`validate-pack.sh --registry` regenerates `_registry.md` by cross-referencing:
- the detection table in `scan-codebase/references/scan-procedure.md §8.5` (the ~22 framework fingerprints), and
- the `<fw>.md` files present in `framework-conventions/`, and
- each present pack's linter result + a `pack_tier:` frontmatter field (`full` | `thin`),

→ a table: `framework | detected? | pack file | status (ready | thin | none) | lints_clean?`. `ready` = a `pack_tier: full` pack that passes the linter; `thin` = a `pack_tier: thin` proof-pack (e.g. django); `none` = detected but no pack → `_universal` fallback.

The registry is **generated, not hand-maintained** (avoids drift). `validate-pack.sh --check-registry` re-derives in-memory and diffs against the committed `_registry.md` → non-zero if stale (a lockfile-style gate, so a pack added without registry regen is caught).

`scan-codebase` surfaces readiness: when §7 Framework is populated, it reads `_registry.md` and, for a `thin`/`none` status, emits an advisory line: `pack coverage: <status> for <framework> — generic _universal fallback in use; see framework-conventions/_registry.md`. Advisory only (never halts).

### 2.3 Scaffold generator (`scaffold-pack.sh`)

`scaffold-pack.sh <framework>` (e.g. `scaffold-pack.sh fastapi`):
- refuses if `framework-conventions/<framework>.md` already exists (no clobber).
- copies `_template.md` → `<framework>.md`, replacing the title + filling frontmatter `framework: <framework>` and a `detection_signature:` stub + `pack_tier: thin` + `framework_version_range: "TBD"`.
- keeps every `<!-- REQUIRED when… -->` section marker so the author knows what to fill, and so the linter guides completion.
- prints next steps: "fill the sections, then run `validate-pack.sh <framework>.md` and `validate-pack.sh --registry`".

The scaffold output is intentionally NOT linter-clean on every check (frontmatter stubs like `framework_version_range: "TBD"` and unfilled sections will fail) — it is a *starting point*, not a finished pack. (The linter is what tells the author what remains.) A `scaffold_smoke` test asserts the skeleton has all the section headings + parseable frontmatter, not full lint-pass.

### 2.4 Contract reconciliation

Add `## Reuse discovery <!-- REQUIRED when the stack has reusable first-party code -->` to `_template.md` (it documents `reuse_hints:` with helpers/model_api/services/commands globs), matching what the packs already carry. This makes `_template.md` the complete contract the linter validates against.

---

## §3 Data flow

```
author runs:  scaffold-pack.sh <fw>   → framework-conventions/<fw>.md (skeleton from _template.md)
author fills the sections
author runs:  validate-pack.sh <fw>.md → PASS/FAIL against _lint.md contract (non-zero on fail)
author runs:  validate-pack.sh --registry → regenerates _registry.md
CI / --all:   validate-pack.sh --all + --check-registry → gate that every pack lints + registry is fresh
runtime:      scan-codebase reads _registry.md → advisory pack-coverage note in scan output (never halts)
```

---

## §4 Error handling

No new blocking halt in the pipeline. Tool-level behavior:

| Condition | Behavior |
|---|---|
| `validate-pack.sh` on a malformed pack | print each violation + reason; exit 1 (author/CI gate) |
| `validate-pack.sh --check-registry` and registry stale | print the diff; exit 1 (regen with `--registry`) |
| `scaffold-pack.sh <fw>` when `<fw>.md` exists | refuse + exit 1 (no clobber) |
| `scan-codebase` + `_registry.md` missing | skip the readiness note (advisory; never halts) |
| python-yaml unavailable for the YAML-validity check | degrade to a structural grep check + a one-line "yaml validator unavailable — structural check only" note (never a hard fail on a missing dev dep) |

### Anti-halu / discipline rails
1. The registry is generated, never hand-edited — `--check-registry` enforces freshness so it cannot silently drift from reality.
2. The linter is an author/CI gate (non-zero exit), NEVER a PreToolUse hook — it must not block an end-user's pipeline run.
3. The cross-framework leak token map lives in `_lint.md` (data), not hard-coded in the script, so it is auditable + extensible.
4. Scaffold never clobbers an existing pack.

---

## §5 Testing

Deterministic bash gate suite `tests/pack-kit/` (mirrors `tests/de-laravelize/` etc.):

1. **test-linter-rejects-bad.sh** — run `validate-pack.sh` on a deliberately-malformed fixture pack (missing a required section / bad YAML / a Laravel token in a django-declared pack) → asserts non-zero exit + the specific violation messages.
2. **test-linter-accepts-good.sh** — run `validate-pack.sh` on `laravel.md` (the reference full pack) → asserts exit 0. (If laravel.md fails, the contract or the pack is wrong — surface it.)
3. **test-template-has-reuse.sh** — `_template.md` now contains `## Reuse discovery`.
4. **test-registry-fresh.sh** — `validate-pack.sh --check-registry` exits 0 (the committed `_registry.md` matches reality); and `_registry.md` lists laravel=ready, django=thin, plus ≥1 `none` framework.
5. **test-scaffold-smoke.sh** — `scaffold-pack.sh <tmp-fw>` (into a temp/sandbox path) produces a file with all required section headings + parseable frontmatter; re-running refuses to clobber.
6. **test-linter-not-a-hook.sh** — `grep` confirms `validate-pack.sh` is NOT referenced in `plugins/mega-sdd/hooks/pre-tool-use` (stays an author tool, never a runtime gate).

Plus regression: the de-laravelize + reuse-awareness + phase-advisor suites still pass (3b touches only tooling + _template + README + a scan advisory line).

---

## Acceptance criteria

1. `validate-pack.sh <pack>` exists, executable, exits non-zero on a malformed pack (missing section / bad YAML / cross-framework leak) and 0 on `laravel.md`.
2. `_lint.md` documents the checklist + the cross-framework token map (data-driven, not hard-coded in the script).
3. `_template.md` includes the `## Reuse discovery` contract section (the v4.5.0 gap reconciled).
4. `_registry.md` is auto-generated by `validate-pack.sh --registry`, lists every detected framework with status (ready/thin/none), and `--check-registry` gates freshness.
5. `scan-codebase` surfaces a pack-coverage advisory from `_registry.md` (never halts; absent registry → silently skip).
6. `scaffold-pack.sh <fw>` produces a skeleton with all section markers + frontmatter stub, refuses to clobber, and prints next steps.
7. README "Adding a new pack" no longer says "TBD" — it points to the real `_lint.md` + `validate-pack.sh`; the Files table lists `_lint.md` + `_registry.md`.
8. No new blocking hook; the linter is never wired into PreToolUse; pipeline behavior unchanged except the one advisory scan note.
9. The `tests/pack-kit/` suite passes; de-laravelize / reuse-awareness / phase-advisor suites still pass.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Linter too strict → blocks legit packs | required-vs-conditional split; conditional sections allow explicit `_(N/A: …)_`; `laravel.md` is the always-must-pass reference (test 2) |
| Registry drifts from reality | generated, not hand-edited; `--check-registry` freshness gate (test 4) |
| Cross-framework leak check false-positives on a legit contrast example | tokens only flagged outside an explicit "contrast example" fenced block; token map in `_lint.md` is tunable |
| python-yaml not installed in some env | degrade to structural check + note, never hard-fail on a missing dev dep |
| Scaffold produces a not-fully-clean pack | by design — it's a starting point; the linter tells the author what's left; smoke test asserts structure, not full lint-pass |
| Scope creep into authoring real packs | explicitly out of scope — that's 3c |

---

## Out of scope (deferred)

- Authoring actual per-stack packs (Node/Next/Python/Go/Rust/Rails/Spring) — that is **3c**, one spec per stack, now cheap because of this kit.
- A `/mega-sdd:scaffold-pack` slash-command wrapper (the script suffices; add later if there's demand).
- Auto-fixing pack lint violations (the linter reports; the author fixes).
- Linting `_universal.md` against the framework-pack contract (it is the fallback, not a framework pack — excluded from `--all`).

---

## Spec self-review checklist

- [x] No placeholders / TBDs remain (the README's "TBD" is the thing being removed; not a spec placeholder).
- [x] Linter enforcement is consistent: author/CI gate (non-zero exit), never a PreToolUse hook (§2.1, §4, acceptance #8).
- [x] Registry is generated + freshness-gated everywhere it's described (§2.2, §4, acceptance #4).
- [x] Contract-reconciliation (`## Reuse discovery` into `_template.md`) is in scope so the linter has a complete contract (§2.4, acceptance #3).
- [x] Scope bounded to tooling; authoring real packs is 3c; no runtime behavior change beyond one advisory scan note.
- [x] Behavioral validation is deterministic (the linter/scaffold ARE deterministic scripts — unlike the LLM-agent features, these gates are real assertions, not scenario docs).
