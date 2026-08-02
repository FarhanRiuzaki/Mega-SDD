# Tree-sitter Integration (owner of the 3-tier engine ladder)

## Contents
- The 3-tier ladder
- Detection (`scripts/probe-scan-engine.sh`)
- Installation guidance (`dep_missing` blocker)
- Query files (`queries/tags-<lang>.scm`) — schema + per-language coverage
- Tier-2 rule packs (`queries/astgrep/<lang>.yml`)
- Invocation
- Precision tier in codebase-map.md frontmatter
- Grammar pinning
- Fallback behavior
- Performance characteristics

`scan-codebase` uses AST-level symbol extraction with a 3-tier engine ladder; regex extraction is preserved as the loud last resort.

## The 3-tier ladder

```
tier 1  tree-sitter   .scm tag queries; one spawn per FILE; grammars compiled LOCALLY (clang)
tier 2  ast-grep      queries/astgrep rule packs; ONE spawn total; grammars EMBEDDED — zero compilation
tier 3  regex         v1 patterns; one spawn per LANGUAGE; loud warning; precision_tier: regex
```

The ladder is resolved **per language**: a language whose tree-sitter grammar fails falls to
tier 2 for that language; a language with no tier-2 rule pack falls to tier 3. Tiers 1 and 2
both stamp `precision_tier: ast` (ast-grep node boundaries are AST-determined), so every
downstream consumer of the tier (bind-codebase field-level diff) is unaffected by a 1→2 fall.

Why tier 2 exists (live incident 2026-08-02): `tree-sitter query` compiles the grammar's
shared library with clang on first use — on a memory-tight machine that compile is
OOM-killed (`clang: … Killed: 9` on stderr, tree-sitter exits rc=1 "Parser compilation
failed"). ast-grep is a static binary with embedded grammars: the clang-OOM class cannot
occur at tier 2, and on `OS=windows-bash` its one-spawn profile also erases the per-file
spawn tax (scan-procedure.md §Spawn-cost gate).

## Detection

Engine detection is a DETERMINISTIC SCRIPT, not prose: `scripts/probe-scan-engine.sh`
(scan-procedure.md §Step 0 has the invocation + digest schema). It probes both tree-sitter
binary names (`tree-sitter` — brew/cargo; `tree-sitter-cli` — npm), runs the per-language
grammar smoke tests **SERIALLY with a hard per-probe timeout** (the smoke test is also the
clang compile step — serializing it inside the script prevents the parallel-compile OOM by
construction), probes `ast-grep`, and emits one JSON digest. Per-language fallback reasons
are first-class: `grammar_compile_killed` (the OOM class — retryable, NOT an install
problem), `grammar_compile_failed`, `grammar_missing`, `query_error`, `probe_timeout`,
`binary_unrunnable` (found on PATH but not executable — e.g. npm's sh shim under Windows
CreateProcess), `no_query_file`, `tree_sitter_absent`, `engine_forced` (a forced
`--engine=ast-grep` routing past a present tier 1), and the non-fallback skip record
`no_source_file` (scaffold-only language — skipped, never failed).

- Binary presence alone proves nothing — the CLI installs with zero grammars configured.
  Only languages that pass the smoke test extract at tier 1 and appear in `grammars_used`.
- User can force a tier via `--engine=tree-sitter|ast-grep|regex`; a forced engine whose
  binary is absent HALTS `dep_missing` (never a silent fall-through).

`precision_tier: ast` is therefore a **verified** claim: it is stamped only when at least one language actually extracted through a working grammar or a tier-2 rule pack, never from binary presence alone.

## Installation guidance

If a FORCED engine's binary is not on PATH (`--engine=tree-sitter` without tree-sitter, `--engine=ast-grep` without ast-grep) OR halt-strict mode active, emit `dep_missing` blocker (`required_binary` + `install_commands` name the forced binary — the ast-grep variant installs via `brew install ast-grep` / `scoop install ast-grep` / `cargo install ast-grep` / `npm install -g @ast-grep/cli`):

```yaml
blocker:
  type: dep_missing
  emitted_at: <ISO8601>
  emitted_by: scan-codebase
  details:
    required_binary: tree-sitter
    install_commands:
      macos: "brew install tree-sitter-cli"
      linux: "cargo install tree-sitter-cli"
      windows: "scoop install tree-sitter"
      universal: "npm install -g tree-sitter-cli"
  next_action: "Install tree-sitter then re-run, OR use --engine=regex for fallback (lower precision)"
```

Design decision: document the install, don't bundle binaries (keeps the plugin small and avoids per-OS binary maintenance).

## Query files (`queries/tags-<lang>.scm`)

Tree-sitter queries written in S-expression syntax. Adapted from [Aider's tags.scm](https://github.com/Aider-AI/aider/tree/main/aider/queries).

### Schema

Each query file targets entity extraction:
- `@name.definition.<kind>` — symbol definition (function, class, method, etc.)
- `@name.reference.<kind>` — symbol reference (call site, import, etc.)

Mega-sdd's scan-codebase consumes these to populate codebase-map.md §2 (public interfaces) + §3 (routes) + §4 (data models).

### Per-language coverage (shipped query files)

- `tags-typescript.scm` — TS classes, functions, interfaces, types
- `tags-javascript.scm` — JS classes, functions, exports
- `tags-php.scm` — PHP classes, methods, traits, interfaces
- `tags-python.scm` — Python classes, functions, decorators
- `tags-rust.scm` — Rust pub fn, struct, enum, trait, impl
- `tags-go.scm` — Go func, type, method
- `tags-ruby.scm` — Ruby classes, modules, methods
- `tags-java.scm` — Java classes, interfaces, enums, records, methods
- `tags-csharp.scm` — C# classes, interfaces, records, structs, methods

Languages without `.scm` file → fall to tier 2 (rule pack present) else tier 3 (graceful degradation).

## Tier-2 rule packs (`queries/astgrep/<lang>.yml`)

Kind-based ast-grep definition rules mirroring the `.scm` coverage, one pack per language
(typescript incl. tsx, javascript, php, python, rust, go, ruby, java, csharp), verified
against ast-grep 0.42.3 (`queries/VERSIONS.md §ast-grep`). The extraction invocation, the
verified JSON contract (0-based lines, `lines` = full node text, dedupe by
`(file, start.line)`), and the `---`-separator concatenation seam live in
scan-procedure.md §Step 5 "If `engine: ast-grep`". Reference captures
(`@name.reference.*`) do NOT exist at tier 2 — and since 5.29.0 nothing consumes them
(the generate-units PageRank pass was removed; reuse now rides the write-time
`symbol_slice` in execute-bolts dispatches).

## Invocation

For each detected language in the repo:

```bash
tree-sitter query queries/tags-<lang>.scm <file> --captures
```

Output is structured (line + column + capture name + symbol text). Skill parses this into codebase-map.md tables.

## Precision tier in codebase-map.md frontmatter

```yaml
---
generated_by: mega-sdd:scan-codebase
generated_at: <ISO8601>
engine: tree-sitter | ast-grep | regex
precision_tier: ast | regex
tree_sitter_version: <version>
astgrep_version: <version>
grammars_used: ["typescript", "php"]
---
```

`bind-codebase` reads `precision_tier`:
- `ast` → claim matches are anchor-precise; binding verdicts more reliable
- `regex` → binding adds note "scan engine: regex (lower precision); manual review of edge cases recommended"

## Grammar pinning

Tree-sitter grammars evolve; bleeding-edge syntax may not parse correctly. Mitigation:

- Plugin documents tested grammar versions in `scan-codebase/queries/VERSIONS.md`
- Skill emits warning if installed grammar version differs significantly
- User can pin grammar via tree-sitter config

## Fallback behavior

A tier-1 → tier-2 fall keeps `precision_tier: ast` and is recorded per language in the
Step-0 digest's `fallbacks[]` (reason named in one chat line). Falling all the way to
tier 3 (regex):

1. Emit chat line: "⚠️ scan-codebase using regex engine (tree-sitter: <reason>, ast-grep: not found). Precision tier: regex. Install ast-grep (zero-compilation) or tree-sitter for AST-precise extraction."
2. Run v1 regex extraction (preserved unchanged from v1.2)
3. `precision_tier: regex` stamped in codebase-map.md frontmatter
4. Downstream skills (bind-codebase) treat as lower-confidence ground truth

Backward-compat: v1.2 codebase-map files (without `precision_tier` field) treated as `regex` by all downstream skills.

## Performance characteristics

| Engine | Time per 1000 files | Memory |
|---|---|---|
| Tree-sitter | ~2-5s (incremental, sub-ms per file) | ~50MB peak (+ clang grammar compile on first use — the OOM point) |
| ast-grep | ~1-3s (ONE process, parallel in-process) | ~100MB peak; NO compile step ever |
| Regex (v1) | ~5-15s (file traversal + multi-pattern match) | ~30MB peak |

AST tiers are FASTER on typical repos AND more precise. Trade-off is an install step —
and only tier 1 ever compiles anything locally.
