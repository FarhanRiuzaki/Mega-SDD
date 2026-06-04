# scan-codebase — default exclusions & include/exclude flags

## Contents
- Why exclude SDD outputs (anti-hallucination rail)
- Default exclusion list (grouped by ecosystem)
- Targeted reads by explicit path
- Override flags

Loaded by `scan-codebase` Step 4 (build tree) and the Step 5 extraction walk. The scan walks every path NOT matching the default exclusion globs. The list is grouped by ecosystem for maintainability — implementation treats it as a flat allowlist applied to the `find` / `tree-sitter` walk. User `--exclude` flags are **appended** to these defaults (not replacing); `--no-default-excludes` opts out entirely.

## Why exclude SDD outputs from the bulk scan

`.mega-sdd/` contains INTENT (vaults, KB, units) — not code. Scan's job is mapping REALITY; reading vault during scan creates confirmation bias (the map silently "agrees" with vault claims that never got verified against source). Reconciliation between intent and reality is `bind-codebase`'s job, not scan's. This exclusion is an **anti-hallucination rail**, not just noise-reduction.

### Targeted reads still happen by explicit path

Orthogonal to the bulk-walk exclude list — these are read by name, not discovered via glob walk, so the exclusion does not block them:

- `.mega-sdd/memory/conventions.md` — past convention detections (Memory layer; skip re-detect for `status: established`).
- `.mega-sdd/codebase/starterkit-context.yaml` — deep-scan cache (Step 10.5.1; cache-hit short-circuit when lock files unchanged).

Do NOT add other `.mega-sdd/` files as targeted reads without explicit spec amendment — the bias risk is real.

## Default exclusion list

**Dependency managers (all ecosystems):**
- `node_modules/**` (npm/yarn/pnpm)
- `vendor/**` (composer, go modules, ruby bundler — when vendored)
- `.pnpm-store/**`, `.yarn/**` (yarn berry / pnpm caches)
- `bower_components/**` (legacy)

**Build / dist output:**
- `dist/**`, `build/**`, `out/**` (generic + Next.js export + IntelliJ)
- `target/**` (Rust + Maven/Java)
- `bin/**`, `obj/**` (.NET / Eclipse)
- `*.class`, `*.jar`, `*.war` (Java compiled — file glob)
- `*.pyc`, `*.pyo` (Python compiled)

**Framework caches:**
- `.next/**`, `.nuxt/**`, `.svelte-kit/**`, `.astro/**` (JS meta-frameworks)
- `.turbo/**`, `.parcel-cache/**`, `.cache/**` (build tool caches)
- `.gradle/**`, `.mvn/**` (JVM build tool caches)
- `storage/framework/**`, `bootstrap/cache/**` (Laravel runtime caches)
- `public/build/**`, `public/hot/**` (Laravel Vite/Mix output)

**Virtualenvs / language sandboxes:**
- `.venv/**`, `venv/**`, `env/**` (Python)
- `__pycache__/**` (Python bytecode)
- `.bundle/**`, `vendor/bundle/**` (Ruby)

**Test / coverage / lint artifacts:**
- `coverage/**`, `.nyc_output/**`, `htmlcov/**` (JS + Python coverage)
- `.pytest_cache/**`, `.mypy_cache/**`, `.ruff_cache/**`, `.tox/**` (Python tooling)
- `*.egg-info/**` (Python packaging artifacts)

**Version control / IDE / OS:**
- `.git/**`, `.svn/**`, `.hg/**` (VCS internals)
- `.idea/**`, `.vs/**` (IntelliJ + Visual Studio)
- `.vscode/**` (VS Code workspace settings — exclude by default; user can `--include=.vscode/**` if project ships shared config worth scanning)
- `.DS_Store`, `Thumbs.db` (OS noise)

**Logs / temp:**
- `*.log`, `logs/**`, `tmp/**`, `temp/**`

**Mega-SDD self-reference (avoid scanning own outputs):**
- `.mega-sdd/**` (canonical layout)
- `bound-vault/**`, `units/**`, `bolts/**`, `codebase-map.md` (legacy paths — back-compat exclusion so re-scan doesn't re-ingest prior outputs)
- `docs/mega-sdd/**`, `docs/knowledge-base/**`

## Override flags

- `--exclude=<glob>` appends to this list (most common usage — add project-specific noise like `public/storage/**`).
- `--no-default-excludes` disables the entire default list (rare; use when scanning a dependency tree intentionally).
- `--include=<glob>` is evaluated AFTER excludes — to scan a normally-excluded path, combine `--no-default-excludes` with explicit `--include`.
