# Reuse-First Grounding Index (R1–R3) + the de-load knife (D1–D2)

**Date:** 2026-08-02
**Status:** DESIGN — umbrella spec; ships tranche-per-release
**Ship order:** `R1+R2 ✅ v5.28.0 (b53d007) → D1 ✅ v5.29.0 (PageRank removal) → R3 (dup sweep hardening) → D2 (ast-grep primary)`
**Horizon (own spec later, not this one):** D3 scan-as-a-service — bind-codebase consuming
the index claim-scoped instead of loading the whole map; deliberately NOT designed here.

## Motivation — the operator's original intent, restated

The scan layer exists so that agents **reuse existing code and follow existing patterns
instead of inventing new code**. The 2026-08-02 critical audit found the plugin serves that
intent only partially, and pays for the wrong things:

- The reuse loop EXISTS end-to-end (deep-scan → `reuse-index.yaml` → dispatch injection
  "PRIMARY reuse lookup" → `validate-reuse-duplication.sh` advisory → code-quality lens),
  but its **coverage is the deep-scan slices only** (auth/authz/ui/libs). Generic helpers —
  the symbols agents most often reinvent — are in NO index that reaches a bolt dispatch.
  `codebase-map.md` §2 has them, but §2 feeds binding, never dispatches.
- The post-write duplication check is **exact-name match** against the slice index only
  (`getUserBalance` reinvented as `fetchUserBalance` passes), surfaced only via
  `/mega-sdd:analyze` (which the lean profile skips).
- **PageRank targeting never served the goal**: file-level (not symbol), advisory (bolts
  ignore it), human-promoted, requires `engine: tree-sitter` — and tier 1 is dead on both
  real operator environments (macOS: grammar compile OOM, live incident 2026-08-02;
  Windows/EDR: one-spawn-per-file ≈ 37 min at 10k files). ~280 doc lines + a spawn-cost
  gate exist solely to stop this advisory feature from hanging machines.
- Post-T1 (`2026-08-02-oom-safe-ast-engine-ladder.md`), a FULL-repo symbol extraction is
  **one ast-grep spawn and zero model tokens** — the "full scan is expensive" premise is
  dead at the extraction layer. What remains expensive is model-mediated copying and
  whole-map loading; neither is needed for reuse.

Native-capability line (the operator's standing rule — do not rebuild what Claude Code
does natively): agentic search already finds *relevant* code well; what it does NOT give is
(a) deterministic, exhaustive, auditable coverage, and (b) the right existing symbols
placed in the implementer's context at write time. R1–R3 build exactly those two things
and nothing else. Where a workspace has LSP configured, LSP may serve interactive lookup —
it is env-dependent, so it can inform but never replace the deterministic index.

## DESIGN 2026-08-02 — R1: the script-owned symbol index

`scripts/build-symbol-index.sh [--cwd=<dir>] [--out=<path>] [--timeout=<sec>]` writes
`.mega-sdd/codebase/symbol-index.json` (registered in `references/paths.md`):

- **Enumeration:** `git ls-files` (tracked files; deterministic, .gitignore-respecting,
  one spawn) filtered to the extensions of the shipped `queries/astgrep/*.yml` packs;
  non-git fallback = `find` with the scan default prune list. Committed `vendor/`-style
  dirs are excluded by the same default exclusion prefixes applied to the file list
  (exclusions.md is the owner).
- **Extraction:** ONE bounded `ast-grep scan --inline-rules <concatenated packs>
  --json=compact` over the enumerated list (chunked only if argv overflows; timeout
  mandatory per the bounded-subprocess law; ast-grep absent → exit 3 + a one-line stderr
  reason — the caller records honesty, never fakes an index).
- **Schema:** `{generated_by, generated_at, head_commit, astgrep_version, file_count,
  symbol_count, symbols: [{name, kind, file, line, signature, lang}]}` — line 1-based (+1 from the
  0-based contract), signature = first node line trimmed capped 200 chars, name parsed
  from the AST-bounded signature (deterministic per kind), rows deduped
  `(file, line, ruleId)` and **sorted (file, line, kind)** so identical input → identical
  bytes (fixture-stable).
- **Not hook-guarded:** the index is recomputable derived state consumed as ADVISORY reuse
  material; no gate trusts it (that line moves only if/when D3 makes it a grounding
  substrate — its own spec).
- **Honest coverage bound:** a file ast-grep cannot parse (or a multi-MB file it declines)
  yields zero rows SILENTLY — coverage is symbol-level, never per-file attested;
  `file_count` counts enumerated files, not parsed ones. JS/TS arrow-function and
  function-expression bindings ARE covered (`variable_declarator has arrow_function /
  function_expression` rules, added at round fold — the dominant modern style was
  invisible to the declaration-kind rules).

`scripts/query-symbol-index.sh [--cwd=] [--file=<prefix>] [--dir=<prefix>] [--name=<substr>]
[--kind=] [--limit=N]` — pure-read filter over the JSON, compact
`file:line<TAB>kind<TAB>name<TAB>signature` lines. Query logic is testable against a
hand-written index fixture — no ast-grep needed on CI.

## DESIGN 2026-08-02 — R2: dispatch-time reuse retrieval

`build-dispatch-prompt.sh` gains a sibling block to the existing reuse-index injection:

- **Ensure-fresh is the CONTROLLER'S batch-level step, not the builder's** (amended at
  round fold: the builder's zero-python-subprocess law + measured spawn budget predate
  this spec and win): execute-bolts runs `scripts/build-symbol-index.sh` ONCE per run in
  batch setup, BEFORE the per-bolt loop — never inside it (a per-bolt full-repo pass is
  the spawn-regression class this repo shipped fixes for twice). Exit 3 (ast-grep absent)
  → proceed; any OTHER non-zero → say so in chat and proceed (the index is advisory —
  bolts must not block on it) with the stale/absent state visible in the dispatch. The
  builder itself never probes HEAD: the `index@<head8>` stamp is provenance, and the
  absent-index case is a RECORDED omission naming the build command.
- **Deterministic retrieval, V1 scope:** (a) every symbol defined IN the unit's
  `target_files` ("you are editing next to these — extend them"), then (b) symbols in the
  SAME DIRECTORIES as target_files. **Cap 40 rows AT LEVEL 0** (the cap is the emitted
  default, not merely a truncation rung) + "+N more — query via
  scripts/query-symbol-index.sh" overflow pointer; budget rungs 20 → 10 → floor below it.
  No model-chosen search terms — the retrieval rule is code, so it cannot find only what
  it expects.
- **Injection block:** `### Existing symbols (REUSE — extend, don't recreate)` with
  `file:line kind name — signature` rows, placed adjacent to the reuse-index block so the
  implementer sees slice patterns AND concrete nearby symbols together.

## DESIGN — R3: duplication sweep hardening (own tranche)

`validate-reuse-duplication.sh` upgraded: compare newly-added symbols against the FULL
symbol index (not just the slice index); matching = exact name + case/edit-shape variants
(camel/snake equivalence, verb-synonym prefix list get/fetch/load/find, same-suffix root);
output stays ADVISORY but is additionally handed to the code-quality review lens as
mechanical evidence rows in its dispatch (the panel's duplication mandate finally gets
data instead of hope). Never a hook (doctrine: gates > rules > hooks; duplication is
judgment-adjacent — a reviewer decision, not a deterministic block).

## DESIGN — D1: PageRank targeting removal (own tranche)

Remove Step 7.5 + `pagerank-targeting.md` + the symbol-graph cache + its spawn-cost gate
(generate-units side). Rationale is the audit above; `target_files` remain
binding-citation-derived (the only enforced path — B3 whitelist unchanged). R2 is the
functional replacement AT THE RIGHT LAYER (symbols at write time, not files at authoring
time). Removal is a behavior change: spec note per surface, trigger-test updates, and the
`--skip-pagerank` flag becomes an accepted no-op for one major cycle (flag-compat rule).

## DESIGN — D2: ast-grep becomes tier 1 (own tranche, after D1)

With PageRank gone, `.scm` reference captures have no consumer; tree-sitter's remaining
value over ast-grep is zero for this pipeline while its costs remain (manual grammar
setup nobody does — default installs ship ZERO grammars; local clang compiles — the OOM
class; one-spawn-per-file — the EDR hang class). Ladder becomes
`ast-grep → tree-sitter (opt-in) → regex` or tree-sitter drops to explicit `--engine=`
only. T1's probe script, packs, dep_missing parity and regex fallback all survive; the
grammar smoke-test machinery is what dies. Decision deferred to its own tranche AFTER D1
proves no `.scm` consumer remains.

## Rejected / bounded (do not relitigate)

- **Model-chosen reuse retrieval** (let the implementer grep for reuse candidates) —
  REJECTED as the *recorded mechanism*: it finds what it expects; the injected set must
  come from a deterministic rule. The implementer may still search beyond it natively.
- **A reuse HOOK (blocking duplication)** — REJECTED: duplication is judgment-adjacent;
  false-positive blocks would train operators to bypass. Advisory + panel evidence is the
  ceiling.
- **LSP as substrate** — env-dependent (needs configured language servers per machine);
  fine as an interactive aid, never the deterministic grounding/reuse substrate.
- **Embedding/vector similarity for R3** — new runtime dependency class; the shape/name
  heuristics cover the dominant reinvention patterns at zero dependency cost.

## Adversarial round disclosures

Per tranche, filled at fold time, AFTER each round actually runs — never pre-written.

### Tranche R1+R2 round (dual-blind, 2 reviewers with execution — 17 findings, ALL folded)

Ship-blocking (2): **A-F1** the spec's "cap 40 rows" was silently rewritten into a mere
budget rung — under-budget dispatches emitted ALL rows (spec-loosened-to-fit-code, the
repo's #1 hunted class); level 0 now carries the cap. **B-1** a tracked file named
`-r.py` was argv-injected into ast-grep and killed the whole build (exit 4, stale index
persists) — `--` now ends option parsing.

Important: the ensure-fresh contract moved builder→controller-batch (the builder's
zero-python-subprocess law + measured spawn budget predate this spec and win) and the
spec was amended to say so (A-F2); the §Symbol slice doc was trapped inside the
reuse-slice pseudocode fence — no heading, no ToC, dead anchor (A-F3); `--dir` was
implemented as exact-dirname against a documented prefix, and the test had transcribed
the code, not the spec (A-F4); fixed-count chunking overflowed ARG_MAX on deep paths
with an uncaught OSError → byte-budget chunks + rc 4 (A-F5/B-2); the "ONCE PER RUN"
index build sat inside the per-bolt Step 4.5 block guarded only by a comment → moved to
batch-setup item 5 (A-F6); C# attribute lines stole the symbol name (`[HttpGet]` →
name=HttpGet) → signature source is now the NODE's own text with attribute/annotation
lines skipped (B-3); JS/TS arrow + function-expression bindings were invisible to the
declaration-kind rules — the dominant modern style got zero reuse coverage → verified
`variable_declarator has arrow_function/function_expression` rules added (B-4); a
newline/backtick in the UNGUARDED index minted its own markdown lines inside the
implementer prompt → every interpolated field collapses to one sanitized line (B-5).

Minor folds: query hardened (corrupt index → rc 3 not a traceback, None cells, TSV
cells stripped of tabs/newlines, BrokenPipe clean — B-6); huge/unparseable files
disclosed as a silent symbol-level coverage bound (B-7); empty-tracked git repo no
longer falls into the gitignore-blind find fallback (B-8); `bin`/`build`/`target`-class
names pruned at top level only — cargo's `src/bin/*.rs` is real source (B-9);
root-level target files documented as bounded noise (B-10); exclusion list completed
from exclusions.md (A-F7); shape-test D4 extended to 10 sections (A-F8); tier-3 tie
order made explicit in CASCADE_ORDER (A-F9); a shifted line pin refreshed (A-F10).

Held attacks worth recording: spaces/quotes/unicode/newline filenames; worktree
`.git`-file; symlink loops; 10k-file build 1.95s / 30k-symbol dispatch 0.24s;
truncations[] names symbol_slice; nslash parity on `.\`-style target paths;
bash-3.2 clean; test idempotent, litter-free, green with ast-grep fully hidden.

### Tranche D1 round (dual-blind, 2 reviewers — 9 distinct findings, ALL folded; the two lenses CONVERGED independently on the same core set)

Ship-blocking (both lenses, independently): **scan-codebase SKILL.md Step 5 still TAUGHT
the removed pass** ("generate-units builds its own symbol graph from the same queries") —
the tranche had fixed both of that skill's references but missed the always-loaded SKILL
body itself, and the removal test could not see it (its sweep was filename-literal).
Folding it surfaced a BONUS stale survivor in the same paragraph: the Step-5 lane-3 prose
still carried the PRE-v5.27.0 contract ("downgrade to --engine=regex", "either value") —
now aligned with the ladder.

Important: the halt-vs-warning summary re-asserted the confirm gate two paragraphs below
its own tombstone; the new INT-6 paths.md detector was a TAUTOLOGY (`grep -q` piped into
`grep -v` — the fail branch was unreachable; proven against a resurrected fixture — the
detector-as-no-op class, caught by the round exactly as designed); README's architecture
Mermaid + layout tree still advertised the pass; the 5.29.0 version cited by every
tombstone must land in the same ship commit (manifests + CHANGELOG — release mechanics,
by design).

Minor: task-typing/starterkit-derivation stale step lists (7.5 in routing lines); the
removal test hardened — extensionless `pagerank-targeting` spelling, commands/ + agents/
in the sweep, and a PROSE sweep (no live surface may TEACH the pass; tombstones exempt by
wording, historical records out of scope); scan-codebase skill version bumped for its
reference edits.

Verified held: flag-compat (nothing mechanically rejects `--skip-pagerank`); legacy
`## PageRank suggestions` sections in existing vaults pass every validator (no
unknown-section whitelist); CI's find-based discovery drops the deleted suite cleanly and
picks up the successor; 20+ adjacent suites green; the replacement (`symbol_slice`) is
real and every tombstone qualifies it honestly as a different-layer replacement.
