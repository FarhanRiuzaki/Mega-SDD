# scan-codebase — surface scan procedure (Steps 0–10)

## Contents
- Incremental mode (`--changed-only`)
- Step 0 — Engine detection (tree-sitter multi-binary probe + regex fallback)
- Step 1 — Detect repo root
- Step 2 — Detect package manager / language
- Step 3 — Detect test framework
- Step 4 — Build tree (depth-limited) + persist the enumeration (`.scan/files.z`)
- Step 5 — Extract public interfaces (per-file invalidation gate; tree-sitter; regex/ripgrep)
- Step 6 — Extract routes
- Step 7 — Extract data models
- Step 8 — Detect naming conventions
- Step 8.5 — Detect framework (manifest fingerprints + pack resolution)
- Step 9 — Detect pattern signatures
- Step 10 — Write codebase-map.md

Loaded by `scan-codebase` for the surface scan. These steps produce `codebase-map.md` (whose section schema is the codebase-map schema). The deep-scan stage (Step 10.5.x), the default exclusion list, and the tree-sitter engine/precision detail are separate references the SKILL.md router links to.

## Incremental mode (`--changed-only`)

For the never-ending-development loop (spec `2026-06-10-living-vault-continuous-sync-design.md`): re-scan ONLY what moved since the last scan, merge into the existing map. This is what `/mega-sdd:sync` invokes.

**1. Resolve `changed_paths` (union of two channels, de-duplicated):**

```bash
# Channel A — ambient journal (in-session AI writes, even uncommitted)
#   .mega-sdd/codebase/.dirty-paths.jsonl — one JSON row per Write/Edit; read the "path" field.
# Channel B — git (manual edits, pulls, other tools)
git diff --name-only <last_scanned_commit>..HEAD   # from the prior map's frontmatter stamp
git status --porcelain                              # uncommitted working-tree changes
```

Apply the default exclusion globs to the union (a journaled `node_modules/` write is still noise). The journal is a HINT — paths that no longer exist are treated as deletions, never errors.

**2. Fallback to FULL scan (one-line chat note, no halt) when ANY of:** no prior `codebase-map.md`; **in a git repo, the git delta channel is unavailable — regardless of journal state** (prior map lacks `last_scanned_commit`, the stamp is the literal string `HEAD` (zero-commit-era stamp, see Step 10), or `git rev-parse --verify '<stamp>^{commit}'` fails): the journal only sees in-session AI writes, so manual edits/pulls since the prior scan would be invisible AND then laundered permanently by the step-3 restamp; `changed_paths` exceeds 40% of the prior map's file census (a rebase/refactor — merge math costs more than a re-walk).

**Not-a-git-repo exception:** journal-only incremental is allowed (Channel B never existed) ONLY when the journal is non-empty, with an explicit one-line stale-risk warning: "⚠️ no git history — incremental merge covers in-session writes only; edits made outside this session are not detected. Run a full scan periodically." **Not-a-git-repo AND empty journal → full scan** (there is nothing to merge; a vacuous incremental would just refresh `generated_at` and relabel a possibly-stale map as fresh).

**3. Merge semantics (per map section):**
- §2 public interfaces / §3 routes / §4 data models: re-extract entries ONLY for files in `changed_paths` (Steps 5–7 logic, scoped); carry forward all other rows byte-identical; DROP rows whose file vanished.
- §1 structure: re-walk only the directories containing changed paths.
- §5 naming / §6 patterns: recompute only if >10 source files changed (sampling-based sections are cheap to skip).
- §7 framework: re-run Step 8.5 ONLY when a package manifest is in `changed_paths`.
- Frontmatter: refresh `generated_at` + `last_scanned_commit` (current HEAD); `engine`/`precision_tier` re-probed as usual.

**4. Race-safe journal consume (rotate, don't truncate):** BEFORE processing, `mv .dirty-paths.jsonl .dirty-paths.consumed-<ts>` — appends from concurrent sessions land in a fresh journal and survive for the next run. Union any leftover `.dirty-paths.consumed-*` files from a previously crashed sync into `changed_paths` too. AFTER the map write succeeds, delete the consumed file(s); on failure leave them (next run re-unions). The deep-scan stage then runs its own per-slice cache check as normal (lock digests catch dependency changes independently).

**5. Durable changed-set hand-off (sync lane only — the forked downstream can't re-resolve).** When a vault is present (the Mode D sync lane — the same `<vault>` this skill resolves for its handoff `next_action` / Step-11 suggestion), serialize the **already-resolved `changed_paths` from step 1** (post-exclusion, one repo-relative path per line) to `<vault>/.sync-changed-paths.txt` (overwrite). Write the in-memory union — do NOT re-read the journal here: step 4 has already rotated-and-deleted it, and a second read would re-introduce the §3.7 consume race. This file is the SOLE scope channel for the two non-interactive downstream phases that accept a path scope — `detect-drift --scope=@…` (**forked**, `context: fork`) and `bind-codebase --paths=@…` (non-interactive on this lane; a fork *candidate*, NOT yet forked — spec `2026-07-30-token-and-latency-optimization.md` §Phase 5a) (`generate-units --reconcile` takes NO path arg; it reconciles from the refreshed `binding.md`, not this file): by the time they run, step 3 has advanced `last_scanned_commit` to HEAD and step 4 has deleted the journal, so `journal ∪ git diff <stamp>..HEAD` is now empty and a fork cannot reconstruct the set from ground truth. **On the step-2 full-scan fallback** (no incremental merge — no meaningful changed set) do NOT write the file and DELETE any stale one (`rm -f <vault>/.sync-changed-paths.txt`); because there is no changed set to scope, the sync-lane handoff then SKIPS the scoped detect-drift hop and continues the forced Mode D chain straight to a FULL re-bind — `next_action: mega-sdd:bind-codebase <vault> --auto` (per spec §3.8(b)(1)). **The `<vault>` is mandatory in that render, not decorative:** this branch writes no `.sync-changed-paths.txt`, so the vault path is the ONLY signal the downstream bind receives — and bind is non-interactive on this lane, so it cannot ask. Dropping it leaves a forked bind with nothing to resolve from. The authoritative shape is `references/halts-flags-handoff.md` §Hand-off (`bind-codebase <vault> --auto`); keep all three surfaces identical. A scope-less `detect-drift --auto` handoff would misfire here: detect-drift infers sync-lane membership ONLY from a `--scope=@file`, so with no scope it self-classifies as STANDALONE and emits `next_action: null`, truncating the chain before the re-bind and leaving `binding.md`/units/bolts stale vs the freshly re-scanned code (exactly the highest-divergence case). This mirrors the cold brownfield path (`scan → bind`), which likewise skips detect-drift on a from-scratch map — the full re-bind IS the reconciliation. No vault present (starterkit-first, not the sync lane) → skip; there is no changed-set consumer.

**Anti-halu rail:** carried-forward rows keep their original `Last_Scanned_Sha256`; ONLY re-extracted rows get new citations. A merge that cannot prove a row's provenance (prior map corrupt) → fall back to full scan.

## Step 0 — Engine detection (multi-binary probe)

Probe for tree-sitter via TWO binary names (different package managers ship under different names):

```bash
command -v tree-sitter || command -v tree-sitter-cli
```

- `tree-sitter` — typically when installed via `brew install tree-sitter-cli` or `cargo install tree-sitter-cli` (binary name is just `tree-sitter`).
- `tree-sitter-cli` — typically when installed via `npm install -g tree-sitter-cli` (binary may keep the package name).

Resolution:
- Found (either) → run the **grammar smoke test** BEFORE claiming the engine (binary presence ≠ working grammars — a default `brew install tree-sitter-cli` ships the CLI with ZERO grammars configured, and every query would fail "No language found"): for each detected language with a `queries/tags-<lang>.scm` AND at least one source file, invoke the Step 5 query once against one real source file. A language with zero source files yet (scaffold-only repo — a first-class scan-first mode) is SKIPPED, not counted as failed. A language whose invocation errors falls back to regex FOR THAT LANGUAGE and is excluded from `grammars_used`. At least one language passes → `engine: tree-sitter` (precision_tier `ast`); `grammars_used` lists exactly the languages that passed. ALL testable languages fail → downgrade to `engine: regex` with the same chat warning as the not-found path plus the grammar-install pointer (`queries/VERSIONS.md §Installation`). NO language was testable (scaffold-only) → keep `engine: tree-sitter` per binary presence with `grammars_used: []` (nothing was extracted either way). Stash the actual binary name found for subsequent invocations.
- Not found AND `--engine=tree-sitter` flag set → halt `dep_missing` with install commands.
- Not found AND no flag → fall back to `engine: regex`; emit chat warning: "⚠️ tree-sitter not found (probed: tree-sitter, tree-sitter-cli); using regex engine (lower precision). Install: brew install tree-sitter-cli / cargo install tree-sitter-cli / npm install -g tree-sitter-cli — or run `/mega-sdd:install-deps` to install automatically".
- Override via `--engine=tree-sitter|regex` flag.

## Step 1 — Detect repo root

Walk up from CWD until `.git` is found — test `-e` not `-d` (in a linked git worktree `.git` is a FILE pointing at the real gitdir; `git rev-parse --show-toplevel` is the canonical resolver). If none, treat CWD as root and warn user.

## Step 2 — Detect package manager / language

Probe in order (record ALL hits — multi-language projects are normal):

> **Monorepo rail (deterministic precedence — NEVER ask).** When app-root manifests exist in MULTIPLE distinct top-level dirs (e.g. `apps/web/package.json` + `apps/api/composer.json` + a root workspace file), resolve the PRIMARY scan target by this precedence, **first match wins**:
>
> | # | Rule | Outcome |
> |---|---|---|
> | 1 | **Explicit `--include=<glob>`** was passed (one or more) | The include set IS the scan target. The caller already decided; do not second-guess it. |
> | 2 | **A root manifest that owns the tree** — a manifest at the repo root declaring its own dependencies/scripts (not a bare workspace pointer: `workspaces`/`packages`-only `package.json`, a lone `pnpm-workspace.yaml`, a `go.work`, a Cargo `[workspace]` with no `[package]`) | The repo root is the primary app; the sub-app dirs are scanned as part of it. |
> | 3 | **Exactly ONE app-root manifest** below the root (every other candidate dir carries none) | That dir is the primary app. |
>
> **Residual ambiguity only** — ≥2 app-root manifests, no explicit `--include`, and no root manifest that owns them → emit the **`scan_primary_app_ambiguous`** blocker listing every candidate app root plus the exact re-run command (`--include=<glob>`), and STOP. Never guess, never scan-all-and-hope, never ask: a map that conflates several apps' routes/models binds wrongly downstream, and the choice of which app is in scope is the caller's. Multi-language inside ONE app (php+js) is normal and is **not** ambiguity — record all languages and continue.
>
> Log the resolved rule (`Primary app: <dir> (rule 2 — root manifest)`); it is a run note, not a new map field.
- `package.json` → js/ts (npm/yarn/pnpm/bun)
- `composer.json` → php/composer
- `Cargo.toml` → rust
- `go.mod` → go
- `requirements.txt` / `pyproject.toml` / `Pipfile` → python
- `Gemfile` → ruby/bundler
- `pom.xml` / `build.gradle` / `build.gradle.kts` → java/kotlin (jvm)
- `*.csproj` / `*.sln` / `*.fsproj` → csharp/fsharp (.NET; nuget) — `Directory.Packages.props` for central package mgmt
- Multiple → multi-language project; record all.

## Step 3 — Detect test framework

Grep for known imports/configs (per detected ecosystem; record all):
- **js/ts:** `jest.config.*`, `vitest.config.*`, `playwright.config.*`, `cypress.config.*`
- **php:** `phpunit.xml`, `pest.php` / `tests/Pest.php`
- **python:** `pytest.ini`, `tox.ini`, `pyproject.toml [tool.pytest.ini_options]`
- **rust:** `Cargo.toml [dev-dependencies]` + `#[cfg(test)]` modules (built-in `cargo test`)
- **go:** `*_test.go` files (built-in `go test`); `testify` in go.mod
- **ruby:** `.rspec` / `spec/spec_helper.rb` (rspec); `test/test_helper.rb` (minitest)
- **jvm:** `junit`/`junit-jupiter` in pom.xml/build.gradle deps; `src/test/java/`
- **.NET:** `xunit` / `nunit` / `MSTest.TestFramework` PackageReference in `*.csproj`; `*Tests.csproj` / `*.Tests/` projects (built-in `dotnet test`)

## Step 4 — Build tree (depth-limited) + persist the enumeration

Walk dirs up to `--depth`, respect `--exclude` (the default exclusion list is a separate reference). Output as markdown tree.

**Persist that same walk — it is the ONLY full-tree pass in the scan.** Step 5 (invalidation gate + extraction) READS the persisted list; nothing after this step re-walks the tree. Write it NUL-delimited to a DETERMINISTIC path — **not** a `mktemp -d`: each step runs as its own command invocation, so a shell variable set here is already gone by Step 5, and a `T="$(mktemp -d)"` here would leave Step 5 reading from an empty path. `SCAN_TMP` below is a literal constant, re-declared verbatim in every later block that needs it.

```bash
SCAN_TMP=".mega-sdd/codebase/.scan"; mkdir -p "$SCAN_TMP"

# The SAME walk that produced the markdown tree above — `--include` / `--exclude`
# plus the default exclusion list applied (→ `references/exclusions.md`; extend the
# prune list with EVERY entry there, and add `-name` filters for `--include`).
# NUL-delimited so spaces / UTF-8 in paths survive. Plain `find` (not `find -L`)
# because the symlink rail below forbids following directory symlinks.
#
# Prune by -name, NOT by -path './node_modules'. A './x' path pattern anchors at
# the repo ROOT, so a monorepo's packages/*/node_modules/ and sub/vendor/ are
# enumerated and hashed anyway — the exact inflation this list exists to prevent.
find . \( -type d \( -name .git -o -name .mega-sdd -o -name node_modules \
                     -o -name vendor \) \) -prune -o \
     -type f -print0 > "$SCAN_TMP/files.z"
```

`$SCAN_TMP` lives under `.mega-sdd/**`, which the walk already prunes, so `files.z` can never re-enter a later enumeration. Both it and `hashes.txt` (Step 5) are scratch: overwritten every run, safe to delete.

**Symlink rail:** do NOT follow symlinked directories (loop risk: `./link → ../ → ./link` hangs the walk). Note encountered dir symlinks in one log line; a user who needs them traversed passes explicit `--include` for the TARGET path. Files >10 MB skip tree-sitter (regex fallback or skip; log in the scan summary) — a single minified bundle must not stall extraction.

## Step 5 — Extract public interfaces

### Order of operations (fixed — the spawn-cost gate must be able to see the hashing)

1. **Enumerate** source files ONCE — Step 4's walk with `--include` / `--exclude` + the default exclusion list already applied — persisted NUL-delimited to `.mega-sdd/codebase/.scan/files.z` by **§Step 4 itself** (the command is there, in Step 4, not here) → `N_files`. Every later step READS that file; nothing re-walks the tree.
2. **Per-file invalidation gate** — ONE batched hash over that persisted list (`N_hash` = 1 spawn, see below) → resolves the REUSE set → `N_extract`.
3. **Spawn-cost gate** — budgets `N_hash + N_extract`, i.e. the TOTAL spawn bill including step 2, not just extraction.
4. **Extraction** (tree-sitter / regex) over the non-REUSE set.

Step 2 sits before step 3 only because BATCHED hashing costs ONE spawn and is unconditionally under budget. **If you cannot batch** (no `xargs`, or a per-file fallback for any reason), then `N_hash = N_files` and the spawn-cost gate MUST be evaluated BEFORE hashing with that value — an unbatched invalidation gate is exactly the runaway this gate exists to catch.

### Per-file invalidation gate (per FILE decision — ONE batched hash process, never one per file)

This gate runs BEFORE tree-sitter / regex extraction below. When `--shallow-scan` flag is set AND a prior `codebase-map.md` exists in the project, the gate compares the enumerated source files' current sha256 against the `Last_Scanned_Sha256` column in prior `codebase-map.md` §2.

**Hash the whole enumeration in ONE BATCHED invocation.** The decision is per file; the hashing is not. A hasher accepts many paths and emits one `<digest>  <path>` line each from a single process — do NOT loop the hasher one path at a time, and do NOT hash inside the per-file extraction loop. Measured on this repo's dev box (501 files, macOS): one-path-at-a-time = 501 spawns / 13,085 ms; batched via `xargs -0` = 1 hasher process / 448 ms — **29x**, and the ratio grows with N. On `OS=windows-bash` each of those spawns costs ~220 ms instead of ~26 ms, so the same loop is the difference between a sub-second gate and a multi-minute one.

Command shape:

```bash
# 0. SAME literal constant Step 4 declared — re-declared here ON PURPOSE:
#    shell variables do NOT survive between step invocations, so nothing is
#    inherited and nothing needs to be.
SCAN_TMP=".mega-sdd/codebase/.scan"

# 1. Probe the hasher ONCE — before the batch, never inside a loop.
#    sha256sum: GNU coreutils (Linux, Git Bash). shasum -a 256: macOS.
#    `command -v` is a shell builtin: no process.
HASH="sha256sum"; command -v sha256sum >/dev/null 2>&1 || HASH="shasum -a 256"

# 2. REUSE Step 4's enumeration — do NOT re-walk here. Step 4 already walked the
#    tree with --include / --exclude AND the default exclusion list applied and
#    persisted it to "$SCAN_TMP/files.z", so the normal path is a pure read that
#    costs nothing. The ONLY sanctioned fallback when that list is absent (Step 4
#    skipped, resumed run) is re-running STEP 4's walk into that same path — one
#    `find` spawn, which makes N_hash 2 instead of 1.
#    A bare `find .` is NOT the fallback: it is a second full-tree stat pass AND
#    it re-admits node_modules/ + .mega-sdd/, which inflates N_files and breaks
#    the anti-bias rail (→ `references/exclusions.md`; SKILL.md §Mandatory rails
#    "Exclude SDD outputs from the bulk walk").
if [ ! -s "$SCAN_TMP/files.z" ]; then
  mkdir -p "$SCAN_TMP"
  find . \( -type d \( -name .git -o -name .mega-sdd -o -name node_modules \
                       -o -name vendor \) \) -prune -o \
       -type f -print0 > "$SCAN_TMP/files.z"      # ← Step 4's walk, same prune list
fi

# 3. Hash the WHOLE list in ONE batched call. xargs re-splits ONLY when argv
#    would overflow, so this is 1 process for a few hundred files and roughly
#    1 per ~20k paths beyond that — never 1 per file.
#    $HASH is unquoted ON PURPOSE: it may be the two words `shasum -a 256`.
xargs -0 $HASH < "$SCAN_TMP/files.z" > "$SCAN_TMP/hashes.txt"   # ← the gate's ONLY spawn
```

Then read `$SCAN_TMP/hashes.txt` (one `<digest>  <path>` line per file) and diff it against prior §2 in-model — that comparison is pure text work, zero further spawns:
- File current sha256 == prior `Last_Scanned_Sha256` → REUSE prior §2 entries for this file; SKIP tree-sitter/regex re-extraction for it.
- File current sha256 != prior → re-extract symbols via tree-sitter/regex (logic below); update `Last_Scanned_Sha256` to current sha256.
- File not in prior map → re-extract symbols + add to §2 with current sha256.
- File in prior map but not in current repo enumeration → drop from §2 (file removed).

For a default scan (no `--shallow-scan`) OR `--no-cache` → SKIP gate entirely; `N_hash = 0`; full re-extract for every file (correctness guarantee preserved for full scans). The gate runs BEFORE per-file extraction so it actually short-circuits the expensive per-file invocations.

**Honest `OS=windows-bash` note — which regime you are in decides the advice.**
- *Unbatched* (one hasher spawn per file — the shape this section forbids): `--shallow-scan` is **net-negative** on Windows. On a 2,000-file repo with 10 changed it burns 2,000 hash spawns (~440 s) to avoid 1,990 extraction spawns (~438 s), because under an endpoint-security agent a sha256 spawn costs the same ~220 ms as a tree-sitter spawn. The "fast path" becomes the slowest step in the scan. It only pays at a very small changed fraction, and even then barely.
- *Batched* (the mandated shape above): `N_hash` = 1 (2 if Step 4's `files.z` is missing and the walk has to be redone), so `--shallow-scan` pays at any changed fraction below ~100% and should be recommended on Windows. The residual cost is one process reading every file's bytes — EDR on-access file scanning, **not measured here** and not spawn tax; do not attach a number to it.

### Spawn-cost gate (MANDATORY before extraction, both engines)

The two engines differ by **three orders of magnitude in process spawns**, and that
difference — not file count — is what decides whether a scan finishes:

| engine | invocations |
|---|---|
| `tree-sitter` | **one per FILE** |
| `regex` (ripgrep) | **one per LANGUAGE** |

On POSIX a spawn costs ~18 ms and the difference is invisible. On a Windows box with
an endpoint-security agent it is **~220 ms** (measured, `windows-team-environment`),
so a perfectly ordinary 2,000-file repo costs ~7.3 minutes of pure spawn tax under
tree-sitter and under a second under regex. This is a real field hang, not a
hypothetical.

Before Step 5 extraction, compute the **TOTAL** spawn bill — the invalidation gate's
own hashing included. Budgeting only post-invalidation extraction is how a
`--shallow-scan` run used to sail through this gate with a 2.2 s estimate while the
invalidation decision itself burned 2,000 spawns:

```
N_extract = files that will actually be extracted (after the invalidation gate)
N_hash    = spawns the invalidation gate itself costs:
              0 without --shallow-scan (gate skipped)
              1 with --shallow-scan and BATCHED hashing — the single `xargs`
                batch. The file list is REUSED from Step 4's walk
                (`.mega-sdd/codebase/.scan/files.z`), so there is no `find` and
                no `mktemp` here; those are Step 4 costs, paid with or without
                --shallow-scan. Add +1 if that list is missing and Step 4's walk
                must be redone, +1 per extra argv batch (~1 per 20k paths).
              N_files if the hashing is NOT batched — the regression this
                gate exists to catch; see §Order of operations
N_total   = N_hash + N_extract
per_spawn = 0.22s on OS=windows-bash, else 0.02s
estimate  = N_total × per_spawn  # tree-sitter only; regex extraction is
                                 # ~n_languages × per_spawn, but N_hash still counts
```

- `estimate` ≤ 60 s → proceed silently.
- `estimate` > 60 s → the gate resolves **BY LANE**. It is deterministic on every lane and
  **never a question** — the skill is non-interactive on every path. First match wins:

| # | Lane | Condition | Outcome |
|---|---|---|---|
| 1 | **Decided** | an explicit `--engine=` (either value) OR an explicit `--include=` on the invocation | Proceed. The caller already made the precision-vs-latency call; log the estimate as a one-line note, no blocker, no downgrade. |
| 2 | **Undecided STANDALONE** | a DIRECT user invocation: no explicit `--engine=`/`--include=`, and NONE of lane 3's unattended signals | Emit `scan_spawn_budget_exceeded` and STOP before extracting (YAML shape: `references/halts-flags-handoff.md`). A human invoked this run and reads its output; the precision choice is theirs. |
| 3 | **UNATTENDED — the chain lane, and every forked run** | ANY of: `--auto`; the body is running FORKED; or an orchestrator (`orchestrate-flow`, `/mega-sdd`, `/mega-sdd:sync`) dispatched this phase — which is how the Mode-D `--changed-only` sync hop arrives | **Downgrade to `--engine=regex` and RECORD it loudly** (three surfaces, below). Neither a halt nor a stall. |

**Lane 2 vs lane 3 — the test is UNATTENDED-ness, and ties go to lane 3.** `--auto` alone is
NOT a sufficient discriminator and must never be read as one: **ZERO**
`orchestrate-flow/references/routing-rules.md` rows render `--auto` on the *scan* hop — phase 1
is written as bare `scan-codebase` / `scan-codebase --changed-only`, and only the DOWNSTREAM
hops (`generate-intent … --auto`, `bind-codebase <vault> --auto`, `detect-drift … --auto`)
carry the flag, because scan is phase 1 and nothing hands IT a handoff. Reading "no `--auto`"
as "standalone" would drop every chain-dispatched scan into lane 2 and re-create exactly the
phase-1 chain halt this split exists to remove. The signals above are all decidable at
dispatch time — a forked body has no conversation history and is unattended by construction,
and a chain-driven phase is visible as such when it is dispatched. **Where they are ambiguous,
take lane 3.** The failure modes are not symmetric: a wrong lane 3 is a recoverable, loudly
stamped regex map the caller can re-run at AST precision; a wrong lane 2 is a halted chain that
produced nothing.

**Lane 1 in detail.** An explicit `--engine=` (either value) or an explicit `--include=` on
the invocation IS the caller's precision-vs-latency decision already made — honor it, log the
estimate as a one-line note, and proceed without a blocker. Re-running with any lane-2 remedy
therefore terminates: the blocker cannot loop, and neither can lane 3's recovery command.

**Lane 2 in detail.** State `N_total` (broken out as `N_hash` + `N_extract`), the estimate,
and the OS in `details`, and carry the three remedies in `next_action` as **re-run commands
the caller executes**, each with its keterangan (→
`plugins/mega-sdd/references/output-language.md §Prompt surfaces` — a halt surface owes the
same keterangan a prompt did; the obligation did not leave with the prompt).
They are remedies, NOT options awaiting a reply:
  - **`--engine=regex`** — satu panggilan per bahasa, bukan per file; selesai dalam hitungan detik. Presisi turun ke tier `regex` (bukan `ast`), dan peta mencatatnya jujur di `precision_tier`.
  - **`--engine=tree-sitter`** — lanjut dengan presisi AST penuh dan bayar biayanya (kira-kira sebesar estimasi). Masuk akal di disk cepat / POSIX, atau saat presisi lebih penting daripada latensi.
  - **`--include=<glob>`** — mempersempit himpunan file, memotong `N_extract` (dan `N_files` bersamanya). Pilih ini kalau hanya satu app/paket yang relevan.

**Lane 3 in detail — what "RECORD it loudly" means (all three surfaces, not one):**

1. **The map frontmatter (the durable surface).** `precision_tier: regex` — the field already
   exists (`references/codebase-map-schema.md`) — PLUS `precision_downgrade_reason`, a
   one-line string carrying the four facts: the estimate, `N_total` with its
   `N_hash` + `N_extract` breakdown, the OS, and the 60 s budget. Shape:

   ```yaml
   precision_tier: regex
   precision_downgrade_reason: "step-5 spawn budget: N_total=2000 (N_hash=0 + N_extract=2000) x 0.22s/spawn (os=windows-bash) = ~440s > 60s budget; --auto lane downgraded tree-sitter -> regex"
   ```

2. **One chat line**, same four facts plus the recovery command.
3. **The handoff.** `next_action.rationale` carries the exact re-run command that recovers AST
   precision — `/mega-sdd:scan-codebase --engine=tree-sitter` (pay the estimate in full) or
   `/mega-sdd:scan-codebase --include=<glob>` (narrow the set so tree-sitter fits the budget).
   `status: completed`, `blockers: []` — this is a finished scan at a stated tier, not a halt.

   Name the downstream consequence in BOTH the chat line and the rationale: at
   `precision_tier: regex`, `bind-codebase` Step 2.5 implementation-state classification falls
   back to BINARY (implemented / not) instead of field-level
   (`bind-codebase/references/implementation-state.md`). A degraded tier the consumer can see
   is the whole point of stamping it.

**Why `--auto` downgrades instead of halting — written down, not implied.**

*(a) The house rule is that `--auto` takes the SAFEST option.* Precedent:
`generate-units/references/pagerank-targeting.md` §`--auto` policy — *"`--auto` runs with
nobody watching — exactly where a 37-minute stall strands someone."* Unattended, "safest" is
neither of the alternatives. A full tree-sitter pass is a multi-hour stall (100k files ×
0.22 s ≈ 6.1 h on Windows). A blocker is a **phase-1 chain halt**: `scan-codebase` is phase 1
of nearly every brownfield row in `orchestrate-flow/references/routing-rules.md`, and **ZERO**
routing rows carry `--engine`/`--include`/`--force-large`, so a chain cannot pre-resolve this
gate the way it pre-resolves `bind-codebase <vault>` — the blocker would strand the whole
chain before a single artifact exists. On Windows the gate fires at only ~272 files, so this
is the common case, not a corner case. Safest here is finishing in seconds at a precision the
map states honestly.

*(b) This does NOT violate the no-silent-downgrade rail — that rail protects the RECORD, not
the action.* The governing sentence is `generate-units/references/pagerank-targeting.md`
§`--auto` policy: *"The `--auto` skip is not a SILENT skip — 'silently' is about the record,
not the action."* The record here is STRONGER than the one that sentence blesses: map
frontmatter (durable, machine-readable, read by every downstream consumer) + a chat line + the
handoff rationale, versus pagerank's unit body + closing summary line. Nothing is hidden, and
the map never claims a tier it did not deliver.

*(c) Why this does NOT port back to pagerank's own rail — producer vs consumer.*
`pagerank-targeting.md` §`--auto` policy forbids ITS `--auto` lane from re-scanning at regex
tier, and that stays correct: `generate-units` is a **CONSUMER** — a regex re-scan there
MUTATES `precision_tier` inside an already-written `codebase-map.md`, shared upstream state
every other consumer reads (`bind-codebase` anchors included), unrecoverable without a full
re-scan. `scan-codebase` is the **PRODUCER** of `precision_tier`: it stamps its own output, on
this run, in the same write, with the reason beside it. Producer-stamps-own-output and
consumer-mutates-upstream-state are different acts; the two rails agree.

**The no-silent-downgrade rail, restated WITH the lane split so it cannot read as
contradicted.** Do NOT downgrade the engine without a record: precision is a property the map
reports, so where a human is present — lane 2, the undecided standalone invocation — the
choice belongs to the user, and the gate hands it back as a blocker instead of making the call
for them. Lane 3 does downgrade, and it is not "silent" in the sense this rail forbids: it is
stamped in `precision_tier` + `precision_downgrade_reason`, announced in chat, and carried in
the handoff rationale with the recovery command. What the rail actually forbids — a map that
claims AST precision it did not deliver, or a tier change nobody can see — stays forbidden on
every lane. Do NOT skip the estimate on Windows because the repo "looks small" — 200 files is
already 44 s there.

The existing `>100k files` halt stays, but note it is a POSIX-era guard: at 220 ms a
100k-file repo is **6.1 hours**, so on Windows this gate fires long before that halt
is ever reached.

### If `engine: tree-sitter` (default when available)

- For each detected language, locate `queries/tags-<lang>.scm` in the plugin dir.
- For each source file: IF the per-file invalidation gate above marked it REUSE → skip; else continue.
- Invoke: `tree-sitter query queries/tags-<lang>.scm <file> --captures` per source file.
  **This is one process per file** — see the spawn-cost gate above. (Batching multiple
  paths into a single `tree-sitter query` call is the structural fix and would collapse
  N spawns to ~1 per language; it is NOT adopted here because the batched capture
  output format could not be verified — the dev machine's tree-sitter ships no compiled
  grammars. Verify on a box with working grammars before changing the invocation.)
- Parse capture output (line + col + capture name + symbol text) into the interface table.
- Capture names map: `name.definition.<kind>` → §2 (public interfaces). `name.reference.<kind>` captures are NOT persisted by scan-codebase (the map has no channel for them) — `generate-units` re-runs the same queries itself to build its file-level symbol graph (pagerank-targeting §Build), cached at `<vault>/.internal/symbol-graph.json`.
- Languages without `.scm` file → fall back to regex (graceful per-language degradation).

### If `engine: regex` (fallback)

Uses ripgrep when available for structured JSON output, falls back to GNU grep:

```bash
# Prefer ripgrep --json when installed for structured matches.
# rg ships built-in file types for ts/php/py/go/rust/ruby/java/csharp/kotlin —
# no custom type definitions needed. Invocation shape (one call per language,
# pattern from the per-language list below):
if command -v rg >/dev/null; then
  rg --type ts --json -e '<TS/JS pattern below>' <paths>
else
  # GNU grep fallback: same patterns via grep -E (no --json structure)
  grep -RnE '<pattern below>' --include='*.ts' <paths>
fi
```

Per-language patterns (engine: regex). Modifier prefixes are REPEATABLE optional
groups — `export default async function`, `final readonly class`, `async def`, Go
receiver methods, `pub async fn`, `override fun`, `record struct` are all in-scope
(the dominant real-world forms). Patterns are **POSIX-ERE-safe** (no `\w` — the
GNU/BSD `grep -E` fallback treats it as a literal; spelled classes work on rg AND grep):
- **TypeScript/JS:** `^export (default )?(async )?(abstract )?(function|class|const|let|var|interface|type|enum)` in `--include` files
- **PHP:** `^[[:space:]]*(final |abstract |readonly )*(class|interface|trait|enum|function) ` and `^[[:space:]]*(public|protected) (static |abstract |final )*function `
- **Python:** `^(class|(async )?def) ` (exclude `_private`)
- **Go:** `^func (\([^)]*\) )?[A-Z]` (exported, incl. receiver methods)
- **Rust:** `^pub(\([A-Za-z0-9_:, ]*\))? (async |unsafe |const )*(fn|struct|enum|trait|type|mod)` (covers `pub(crate)` / `pub(in crate::my_mod)`)
- **Ruby:** `^[[:space:]]*(class|module) [A-Z]` and `^[[:space:]]*def (self\.)?[A-Za-z_]`
- **Java:** `(class|interface|enum|record) [A-Z]` and `^[[:space:]]*(public|protected) [A-Za-z0-9_<>\[\], ]+ [A-Za-z0-9_]+\(`
- **C#:** `^[[:space:]]*(public|internal) (static |sealed |abstract |partial |readonly )*(class|interface|record( struct)?|struct|enum) [A-Z]` and `^[[:space:]]*(public|protected) (static |async |virtual |override |sealed )*[A-Za-z0-9_<>\[\],? ]+ [A-Za-z0-9_]+\(`
- **Kotlin:** `^[[:space:]]*(open |data |sealed |abstract |enum |annotation |inner |value )*(class|interface|object) [A-Z]` and `^[[:space:]]*(override |open |internal |public |protected |suspend |operator |infix |inline |tailrec )*fun (<[^>]+> )?[A-Za-z_]`
- **F#:** `^[[:space:]]*(type|module) [A-Z]` and `^let (rec )?[A-Za-z_]` (top-level `let` only — an indented `let` is a function-local binding, not a public symbol)

Ripgrep `--json` output is structured: emit `begin`/`match`/`end`/`summary` records; skill parses these into the interface table (faster + more reliable than text grep). See `plugins/mega-sdd/references/tooling-install.md` for ripgrep install (`brew install ripgrep` etc.); install is OPTIONAL — GNU grep fallback always works.

## Step 6 — Extract routes

Per framework signatures — one row per framework in the Step 8.5 detection table (tech-agnostic: every supported framework has an extraction signature, not just the JS/PHP ones):

| Ecosystem | Framework | Route signature |
|---|---|---|
| js/ts | Express | `app.(get\|post\|put\|delete\|patch)(` / `router.(get\|...)(` |
| js/ts | Fastify | `fastify.(get\|post\|...)(` / `.route({` |
| js/ts | NestJS | `@(Get\|Post\|Put\|Delete\|Patch)(` decorators on controller methods |
| js/ts | Next.js | files under `pages/api/**` or `app/**/route.{ts,js}` (file-based) |
| js/ts | Nuxt | files under `server/api/**` (file-based) |
| js/ts | SvelteKit | `src/routes/**/+server.{ts,js}` + `+page.server.*` (file-based) |
| js/ts | Remix | `app/routes/**` loader/action exports (file-based) |
| php | Laravel | `Route::(get\|post\|...)` in `routes/*.php` |
| php | Symfony | `#[Route(` attributes (or `@Route` annotations) |
| php | Slim | `$app->(get\|post\|...)(` |
| ruby | Rails | `config/routes.rb` — `resources :x`, `get '...'`, `namespace` |
| ruby | Sinatra | top-level `get '/...' do` / `post '...' do` |
| python | Django | `urls.py` — `path(` / `re_path(` / `include(` |
| python | FastAPI | `@app.(get\|post\|...)(` / `@router.(get\|...)(` decorators |
| python | Flask | `@app.route(` / `@bp.route(` decorators |
| go | Gin | `r.GET(` / `router.(GET\|POST\|...)(` / `group.(GET\|...)(` |
| go | Echo | `e.(GET\|POST\|...)(` |
| go | Fiber | `app.(Get\|Post\|...)(` |
| rust | Actix | `#[(get\|post\|...)("` attributes / `.route(` / `web::resource(` |
| rust | Axum | `Router::new()` + `.route("...", (get\|post\|...)(` |
| rust | Rocket | `#[(get\|post\|...)("` attributes + `routes![` |
| jvm | Spring | `@(Get\|Post\|Put\|Delete\|Patch)Mapping` / `@RequestMapping` |
| .NET | ASP.NET Core (attribute) | `[Http(Get\|Post\|Put\|Delete\|Patch)` + `[Route(` attributes on controller actions |
| .NET | ASP.NET Core (minimal API) | `app.Map(Get\|Post\|Put\|Delete\|Patch)(` / `group.Map(Get\|...)(` |

No framework match (`_universal`) — **or a matched framework with no signature row in this table** (parity rail: Step 8.5 detection MUST NOT outrun extraction) → grep generic markers (`route`, `handler`, HTTP verb + path-literal pairs) best-effort; mark §3 confidence low.

## Step 7 — Extract data models

Per ORM/persistence-pattern signatures — covering every ecosystem in the detection table:

| Ecosystem | Pattern | Model signature |
|---|---|---|
| js/ts | Prisma | `model X {` in `schema.prisma` |
| js/ts | TypeORM | `@Entity()` class decorators |
| js/ts | Sequelize | `sequelize.define(` / `extends Model` + `.init(` |
| js/ts | Drizzle | `pgTable(` / `mysqlTable(` / `sqliteTable(` |
| php | Eloquent | `class * extends Model` |
| php | Doctrine | `#[ORM\Entity]` attributes (or `@ORM\Entity` annotations) |
| ruby | ActiveRecord | `class * < ApplicationRecord` / `< ActiveRecord::Base` |
| python | Django ORM | `class X(models.Model):` |
| python | SQLAlchemy | `class X(Base):` / `(DeclarativeBase)` / `(db.Model)` |
| python | Pydantic | `class X(BaseModel):` (DTO/schema layer — record as schema, not persistence, unless no other ORM detected) |
| go | GORM | struct with `gorm.Model` embed or `gorm:"..."` field tags |
| go | sqlc/ent | `ent.Schema` / generated `models` package |
| rust | Diesel | `#[derive(Queryable` / `table! {` macro |
| rust | SeaORM | `#[derive(DeriveEntityModel` |
| jvm | JPA/Hibernate | `@Entity` (jakarta.persistence / javax.persistence) |
| .NET | EF Core | `: DbContext` class + `DbSet<` properties; `[Table(` / `[Key]` attributes on entities |

No ORM signature match for a detected ecosystem (same parity rail as Step 6) → grep generic persistence markers (entity/model class + field blocks near persistence imports) best-effort; mark §4 confidence low.

Field extraction per entity follows the same per-language tree-sitter/regex ladder as Step 5.

## Step 8 — Detect naming conventions

Sample 20+ files per language:
- File case: kebab vs camel vs snake (majority wins)
- Symbol case: camel vs snake vs Pascal
- Test file suffix: `.test.ts`, `.spec.ts`, `Test.php`

## Step 8.5 — Detect framework

Parse package manifest for framework dependency fingerprints; write to `codebase-map.md` §Framework section. Detection rules (first match wins per language):

| Manifest | Grep pattern | Framework |
|---|---|---|
| `composer.json` | `"pixinvent/vuexy-laravel-bootstrap-jetstream"` | laravel-base-26 (starterkit variant; takes precedence over plain laravel) |
| `composer.json` | `"laravel/framework"` | laravel |
| `composer.json` | `"symfony/framework-bundle"` | symfony |
| `composer.json` | `"slim/slim"` | slim |
| `package.json` | `"next"` (dependencies) | next |
| `package.json` | `"nuxt"` (dependencies) | nuxt |
| `package.json` | `"@nestjs/core"` | nestjs |
| `package.json` | `"@remix-run/"` | remix |
| `package.json` | `"@sveltejs/kit"` | sveltekit |
| `package.json` | `"express"` | express |
| `package.json` | `"fastify"` | fastify |
| `Gemfile` | `gem ['"]rails['"]` | rails |
| `Gemfile` | `gem ['"]sinatra['"]` | sinatra |
| `pyproject.toml`/`requirements.txt` | `django` | django |
| `pyproject.toml`/`requirements.txt` | `fastapi` | fastapi |
| `pyproject.toml`/`requirements.txt` | `flask` | flask |
| `go.mod` | `github.com/gin-gonic/gin` | gin |
| `go.mod` | `github.com/labstack/echo` | echo |
| `go.mod` | `github.com/gofiber/fiber` | fiber |
| `Cargo.toml` | `actix-web` | actix |
| `Cargo.toml` | `axum` | axum |
| `Cargo.toml` | `rocket` | rocket |
| `pom.xml`/`build.gradle` | `spring-boot-starter` | spring |
| `*.csproj` | `Microsoft.AspNetCore.` (or `<Project Sdk="Microsoft.NET.Sdk.Web">`) | aspnetcore |
| `*.csproj` | `Microsoft.EntityFrameworkCore` (no web SDK) | dotnet |

Extract version where regex available (e.g., `"laravel/framework": "^11.0"` → `version: "11.x"`). Output to `codebase-map.md`.

**First-match-wins ordering:** more specific starterkit packs take precedence over generic framework packs, and **meta-frameworks precede the server substrates they ship with** (a Remix express-adapter app carries both `@remix-run/` and `"express"` — matching express first would grep `app.(get|…)` and miss every file-based route).

YAML for plain Laravel detection:
```yaml
framework:
  name: laravel
  version: "11.x"
  confidence: high          # high (explicit dep), medium (transitive), low (heuristic)
  pack_path: plugins/mega-sdd/references/framework-conventions/laravel.md
  detection_source: "composer.json — laravel/framework"
```

YAML for base-laravel-26 starterkit detection (Vuexy fingerprint detected, takes precedence over plain laravel):
```yaml
framework:
  name: laravel-base-26
  version: "12.x"
  confidence: high
  pack_path: plugins/mega-sdd/references/framework-conventions/laravel-base-26.md
  detection_source: "composer.json — pixinvent/vuexy-laravel-bootstrap-jetstream + joelbutcher/socialstream"
  extends: laravel           # pack inheritance (recursive load resolves base laravel.md + _universal.md)
```

If no match → `framework: { name: "_universal", confidence: "fallback", pack_path: "plugins/mega-sdd/references/framework-conventions/_universal.md" }`.

## Step 9 — Detect pattern signatures

Heuristic grep for indicators:
- Auth: search for `middleware`, `jwt`, `session`, `@Auth` decorators
- State management: imports of `redux`, `zustand`, `mobx`, `react context`
- Error handling: ratio of `try/catch` vs `Result<T>` patterns

## Step 10 — Write codebase-map.md

Write per the codebase-map schema. Include all sections; mark genuinely empty sections as "None detected" not omitted. Frontmatter stamps `engine: tree-sitter | regex` + `precision_tier: ast | regex` so downstream `bind-codebase` knows the confidence level, plus the staleness stamp: `last_scanned_commit: $(git rev-parse --verify 'HEAD^{commit}' 2>/dev/null)` — **omit the field when the command fails** (no `.git` per Step 1, OR a fresh zero-commit repo where bare `git rev-parse HEAD` would emit the literal string "HEAD" and poison the stamp). Consumers treat a stamp equal to the literal `HEAD` as missing.

### Step 10a — Secret-scan gate (BEFORE the write)

The map can be committed or shared; symbol/route extraction can capture a hardcoded credential from a signature line. Before writing `codebase-map.md` (and before Step 10.5.3 writes `starterkit-context.yaml`), **run the deterministic redactor against the assembled artifact** (write to a temp file first, scrub, then rename into place):

```bash
# Resolve $PLUGIN_ROOT to the LATEST cached version (defeats stale-version anchoring;
# see plugins/mega-sdd/references/plugin-root-resolution.md). DERIVED = this reference
# file's own absolute path truncated before /skills/.
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"

bash "$PLUGIN_ROOT/scripts/secret-scan.sh" --redact <assembled-artifact-tmp-file>
```

- The script detects AWS keys, private-key blocks, GitHub/Slack/OpenAI-style tokens, JWT-shaped strings, and `password|secret|api_key|token = "…"` assignments; it replaces each matched VALUE with `[REDACTED-SECRET]` in place (the symbol/route row survives) and prints a JSON report of `{pattern, line, excerpt}` findings.
- Findings present → **write them to disk FIRST, then also emit one chat line.** Chat is not a durable channel: this skill is non-interactive (and forkable), so its chat is a transcript the user may never read, and the handoff schema carries `blockers[]` only — inventing a `warnings:` key is forbidden. The artifact itself keeps only `[REDACTED-SECRET]`, so **the location of the live credential would otherwise exist nowhere** and the user could not rotate it. Append (create if absent) to `<project-root>/.mega-sdd/codebase/SECRET-FINDINGS.md` — the same durable-queue move as `detect-drift`'s `PENDING-SYNC.md`, and inside `.mega-sdd/**`, which the bulk walk excludes by default so it can never feed back as scan input:

```markdown
# Secret-scan findings — rotate or relocate these credentials

> Scan menemukan pola kredensial di source. Nilainya sudah di-redact dari artefak
> mega-sdd, TAPI kredensial aslinya masih hidup di file sumber di bawah ini —
> rotasi atau pindahkan ke env/secret manager, lalu hapus barisnya dari daftar ini.

## <ISO8601 run timestamp> — <artifact that was scrubbed>
| Source | Pattern | Artifact |
|---|---|---|
| `<source file>:<line>` | `<pattern class from the report>` | `<artifact>` |
```

  Write the `file:line` + pattern class ONLY — **never the matched value**; this is a rotation worklist, not a secret store. The same durable channel is used by every scrub site (Step 10a's `codebase-map.md` and Step 10.5.3's `starterkit-context.yaml` / `reuse-index.yaml`). List the file in the handoff `artifacts[]` when it was written this run.
- This gate redacts the ARTIFACT — it never edits repo source files.
- Empty `findings` (the normal case) → write as-is, no chat output.
- **After the rename into place, refresh the map-validator state:** `bash "$PLUGIN_ROOT/scripts/validate-codebase-map.sh" --cwd=<project-root> --quiet`. The temp-file + `mv` write does not fire the PostToolUse `Write|Edit` dispatch, so this keeps `.codebase-map-state.json` fresh for `/mega-sdd:analyze` (the bind-codebase PreToolUse gate also re-validates lazily when the map is newer than its state).
