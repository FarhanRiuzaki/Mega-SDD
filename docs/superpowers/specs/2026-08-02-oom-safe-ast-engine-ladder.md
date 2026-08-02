# OOM-Safe AST Engine Ladder (T1)

**Date:** 2026-08-02
**Status:** SHIPPED v5.27.0. **Ladder ORDER superseded at v5.31.0** by
`2026-08-02-reuse-first-grounding-index.md` §D2 (an unrelated heading named "D2" also
exists below — that one is this spec's own numbering, not the superseding section):
AUTO is now `ast-grep → regex` and tree-sitter is an explicit `--engine=tree-sitter`
opt-in lane. Everything else here — the probe script, the packs, the dep_missing parity,
the serial bounded smoke tests (now opt-in-lane-only), the OOM classification — still
ships as designed.
**Owner surfaces:** `scan-codebase` (engine detection + Step 5 extraction), `generate-units` (PageRank prerequisite wording), `derive-codebase-map.sh` (frontmatter contract)

## Motivation — a real incident, not a hypothetical

On the maintainer's macOS machine, a live `scan-codebase` run died with `clang: killed: 9`
(kernel OOM SIGKILL) during the Step-0 **grammar smoke test**. Root cause chain:

1. `tree-sitter query` compiles each grammar's shared library locally with clang on first
   use — the smoke test is therefore also a **compile step**, not just a probe.
2. The smoke test is model-driven prose ("for each detected language … invoke the Step 5
   query once"), and a model may batch the per-language probes into parallel Bash calls.
   Parallel clang grammar compiles on a memory-tight machine → OOM kill.
3. A killed probe reads as "language failed" → the language silently rides the per-language
   regex fallback. The design's no-silent-downgrade rail records the *tier*, but the
   *reason* (`compile OOM`, retryable) was indistinguishable from `grammar missing`
   (install problem, not retryable).

The fix must remove local compilation from the hot path, bound the compile that remains,
and make the OOM class visible by name.

**Live repro (2026-08-02, same machine, during this tranche's implementation):** even a
SINGLE serial `tree-sitter query` probe reproduced the kill — and it surfaces as
`rc=1` with `clang: error: unable to execute command: Killed: 9` on **stderr** (the
OOM victim is the clang *child*; tree-sitter itself exits 1 "Parser compilation
failed"). Classification therefore must read stderr, not just the return code, and on
this class of machine tier 2 is not a fallback — it is the only working AST path.

## DESIGN 2026-08-02 (tranche T1)

### D1 — Three-tier engine ladder

```
tier 1  tree-sitter   (.scm tag queries; per-file spawns; grammars compiled locally)
tier 2  ast-grep      (embedded grammars, static binary, ZERO compilation; one spawn total)
tier 3  regex         (v1 extraction, loud warning — unchanged last resort)
```

- `engine:` frontmatter enum becomes `tree-sitter | ast-grep | regex`.
- `precision_tier:` stays **binary** (`ast | regex`). ast-grep node boundaries are
  AST-determined, so tier-2 stamps `ast` — every downstream consumer
  (`bind-codebase` field-level diff, `implementation-state.md`, binding-contract
  PARTIAL_* verdicts) keys off `precision_tier`, so tier-2 maps inherit full binding
  precision with **zero consumer changes**.
- `grammars_used` is reused for both AST engines (= languages that actually extracted at
  AST tier); new `astgrep_version` frontmatter key (mirrors `tree_sitter_version`),
  added to the deriver's `FM_ORDER`.
- Per-language granularity is preserved: a language whose tree-sitter grammar fails
  falls to tier 2 **for that language**; a language ast-grep does not support falls to
  tier 3 for that language. The map's `engine:` records the highest tier that extracted
  ≥1 language; `precision_downgrade_reason` records per-language fallbacks.

### D2 — Engine detection becomes a deterministic script

New `scripts/probe-scan-engine.sh` replaces the prose-driven Step 0 (doctrine: prefer
scripts for deterministic operations — the OOM is prevented **by construction**, not by
prose asking the model to please run probes one at a time):

- Probes `tree-sitter` / `tree-sitter-cli`, then runs the per-language grammar smoke
  tests **serially** — never parallel, so at most ONE clang compile is in flight.
- Every probe is a bounded child process (python3 runner, hard `timeout=` per the repo's
  bounded-subprocess law; default 30s per language, grammar compile included).
- A probe killed by signal (rc 137 / negative returncode — the `killed: 9` class) is
  classified **`grammar_compile_killed`**, distinct from `grammar_missing` /
  `query_error` / `probe_timeout`. Killed/timed-out languages fall to tier 2 and the
  reason string survives into `precision_downgrade_reason`.
- Probes `ast-grep` (version captured). Emits ONE compact JSON digest:
  `{engine, grammars_used, fallbacks: [{lang, tier, reason}], tree_sitter_version,
  astgrep_version, binary_name}` — the SKILL consumes the digest instead of running
  detection prose.
- Scaffold-only / zero-source-file languages: SKIPPED (not failed) — parity with the
  existing smoke-test rule.
- `--engine=tree-sitter|ast-grep|regex` forces a tier (forced-absent → `dep_missing`
  halt, unchanged taxonomy; the halt's `required_binary` now names the forced engine).

### D3 — Tier-2 extraction contract (verified against ast-grep 0.42.3, not assumed)

Extraction runs `ast-grep scan --inline-rules "$(cat queries/astgrep/<langs>.yml)"
--json=compact <paths>` — rules carry their own `language:` field, so the whole
non-REUSE set across ALL tier-2 languages extracts in **ONE spawn total**. Verified
contract facts the docs must state (fixture-against-the-real-producer lesson):

- `range.start.line` is **0-based** → +1 before writing map anchors.
- `lines` is the FULL node text (body included) → §2 signature = first line only.
- Kind-based rules match nested definitions (methods inside classes) — wanted.
- Symbol name is parsed from the AST-bounded signature line (deterministic: the node
  kind is known); this is not a precision downgrade because the node boundary — the
  thing regex gets wrong — came from the AST.

Rule packs live in `skills/scan-codebase/queries/astgrep/<lang>.yml`, one per language,
mirroring the definition coverage of the existing `tags-<lang>.scm` files. `VERSIONS.md`
pins the tested ast-grep version.

**Spawn economics (why tier 2 is not merely a fallback):**

| engine | spawns for N files, L languages |
|---|---|
| tree-sitter | N (one per FILE) |
| ast-grep | **1** (rules are language-tagged) |
| regex (ripgrep) | L (one per LANGUAGE) |

On `OS=windows-bash` (~220 ms/spawn under EDR) tier 2 turns a 2,000-file ~7.3-minute
extraction into one spawn. The Step 5 spawn-cost gate table gains the ast-grep row; on
Windows the guidance is that tier 2 is the *preferred* AST engine, and it installs as a
static binary via scoop/winget (no cargo/brew needed on locked-down office laptops).

### D4 — PageRank prerequisite unchanged (honest skip under tier 2)

`generate-units` Step 7.5 builds its symbol graph from `@name.reference.*` captures,
which only the `.scm` queries produce. Under `engine: ast-grep` the pass **self-skips
with the same loud record** as the existing regex-tier skip (unit-body section + closing
Hand-off line), but `precision_tier` stays `ast` so binding precision is NOT dragged
down with it. Extending reference-capture parity to ast-grep is explicitly out of scope
for T1 (would need per-language call-site rule packs + resolution logic — its own
tranche if telemetry ever shows the suggestions are missed).

### D5 — Rejected alternatives (do not relitigate)

- **`tree-sitter-language-pack` (pip wheels) / WASM (`web-tree-sitter`)** — REJECTED:
  the contributor contract forbids extra runtime dependencies; the plugin is
  bash + python3-stdlib with no pip/npm environment. ast-grep reaches the same
  zero-compilation goal with a binary the plugin already documents (Hard Rules v2,
  `tooling-install.md`, `install-deps`) and that `shared-snapshot-schema.md` already
  anticipated (`captured_via: tree-sitter | ast-grep | regex-fallback`).
- **Bundling parser binaries in the plugin** — REJECTED (reaffirms the existing
  document-the-install decision in `tree-sitter-integration.md`).
- **New `sdd-repo-map` / `sdd-lint-slice` / `sdd-symbol-search` CLI commands** —
  REJECTED: v5 collapsed the public surface to three verbs; `scripts/` is the helper
  layer and its outputs are already compressed digests, never raw AST/JSON dumps.
- **Rebuilding PageRank repo-mapping / elided map / scope locking** — already shipped
  (iter6 `pagerank-targeting.md`, `codebase-map.md` §2, `target_files` whitelist gate
  B3); the external "Phase 2" plan predates reading this repo.
- **AST-aware error slicing for `execute-bolts`** — DEFERRED by scope decision
  (2026-08-02): moderate value, new surface; needs its own design + round if wanted.

### D6 — Contract details the implementation MUST honor (pre-round design review)

- SIGKILL surfaces as **both** rc 137 (shell) and negative returncode (python) — both
  classify `grammar_compile_killed`.
- `--engine=ast-grep` forced with ast-grep absent → `dep_missing` halt with
  `required_binary: ast-grep` (parity with the forced tree-sitter path; never a silent
  fall-through to regex).
- The digest carries `binary_name` (which of `tree-sitter` / `tree-sitter-cli` was
  found) so Step-5 invocations never re-probe.
- Digest/extraction rows dedupe by `(file, start.line)` — kind-based rules can
  double-match some constructs.
- `TimeoutExpired` is caught and recorded as `probe_timeout` (a reason enum value must
  be reachable, or it is prose).
- Tests must cover the ast-grep-ABSENT arm via a PATH shim — CI runners don't ship
  ast-grep, and a suite that only passes where the dev box's tooling exists is rot.

## Adversarial round disclosure (dual-blind, folded pre-ship)

Two blind reviewers (lens A: spec-vs-artifact + contract breaches; lens B: execution +
hostile-input + cross-platform), both with execution. **22 findings — 5 ship-blocking,
6 important, 11 minor — ALL folded pre-ship.** The ship-blockers:

- **A-1** the Step-0 rewrite deleted the literal rationale phrase `binary presence ≠
  working grammars` that `tests/god-review-s3/test-3e-sync-lane.sh` pins → suite red;
  phrase restored in place.
- **A-2** `halts-flags-handoff.md` (same-skill sibling ref) still carried the ENTIRE
  2-tier contract — lane-3 "downgrade to regex", 2-value `--engine=` catalog, prose-probe
  Step-0 row, tree-sitter-only dep_missing — an agent loading it would execute the old
  world; all sites rewritten to the ladder.
- **A-3** `generate-units` SKILL Step 7.5 + `task-typing.md` keyed PageRank on
  `precision_tier: ast` — under an `engine: ast-grep` map (tier IS ast) the always-loaded
  router would order the per-file `tree-sitter query` graph build, RE-OPENING the exact
  clang-OOM path on the machine class this tranche exists for; both re-keyed on
  `engine: tree-sitter`.
- **B-1** non-UTF-8 bytes on a probe's stdout/stderr (a latin-1 source file suffices)
  crashed the resolver with a raw traceback and NO digest → `errors="replace"`.
- **B-2** a repo whose only languages lack a `.scm` (kotlin/fsharp) took the scaffold arm
  and stamped `engine: tree-sitter, precision_tier: ast` while everything extracted via
  regex — a fake `ast` stamp feeding bind-codebase's field-level diff (moat-adjacent);
  the scaffold claim now requires every entry to be a SKIP.

Important folds: the D2 "reason survives into `precision_downgrade_reason`" requirement
had been silently dropped in the docs — Step 0 now stamps the per-language falls
durably and the schema comment covers both producers (A-4); scaffold skip hoisted above
the tier-2/3 branches so a zero-source language is a SKIP on every path (A-5); preflight
surfaces (`validate-preflight.sh`, `predictive-checks.md`, `chain-execution.md`) probe
ast-grep too — check renamed `ast_engine_present`, regex predicted only when BOTH
engines absent (A-6); `tool-matrix.yaml` mirrors tooling-install (A-7); `--timeout`
validated in bash → rc 2, never a traceback (B-3); `--version` parse takes the first
X.Y token, not a trailing `(sha)` (B-4). Minor folds: reason enum completed with
`binary_unrunnable` (rc 127 — npm sh-shims under Windows CreateProcess),
`engine_forced`, `no_source_file` (A-8/B-9); dedupe key gained ruleId (B-5);
duplicate/hostile `--lang` args rejected or deduped (B-6/7/8); tier-2 language set
derived from the shipped packs, not hardcoded (A-11); alias command hint +
tooling-install fallback cells (A-9/10); the test sandbox guards the `/usr/bin` leak
class explicitly after its own brew-dir leak fix (B-10). Round regression arms for
every executable class live in `test-oom-safe-engine-ladder.sh`.

Held attacks worth recording: no grandchild-pipe hang on timeout (verified on python
3.9 + 3.14); bash-3.2 `${LANG_ARGS+…}` zero-arg expansion; 30 MB stderr no-deadlock;
all 9 packs fired on fixtures with zero YAML errors / id collisions; CRLF +
no-trailing-newline concatenation seam; relative `--cwd` + spaced sample paths;
forced-engine dep_missing halts.
