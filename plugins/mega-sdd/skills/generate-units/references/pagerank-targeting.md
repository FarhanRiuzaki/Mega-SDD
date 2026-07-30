# PageRank Symbol-Graph Targeting

## Contents
- Why
- Detection prerequisites
- Spawn-cost gate (MANDATORY before building the symbol graph)
  - `N` — the canonical definition (single owner; zero-spawn source = `codebase-map.md` §2)
  - `--auto` policy
- Algorithm (Steps 1–5)
- Output integration
- Performance
- Caching
- Anti-hallucination rails
- References

`generate-units` uses personalized PageRank on a file-level symbol-reference graph to auto-rank candidate `target_files` per unit. Adapted from [Aider's repo-map](https://aider.chat/2023/10/22/repomap.html) (45k ⭐ proven at scale).

## Why

In v1.5, `target_files` populated from binding citations + manual unit-author input. Misses files that share symbols with the unit's domain (e.g., a unit on Auth flow may need to touch `routes/api.php` even if not explicitly cited in binding).

PageRank ranks files by their "centrality" to a set of seed files (the binding citations); top-K candidates surface as suggestions.

## Detection prerequisites

Requires `engine: tree-sitter` in `codebase-map.md` frontmatter. If precision tier is `regex`, PageRank is SKIPPED — fallback to binding-only target_files.

## Spawn-cost gate (MANDATORY before building the symbol graph)

Building the graph is **not** a cheap read of the scan output. `scan-codebase` persists
only `name.definition.*` captures (`scan-codebase/references/scan-procedure.md §If engine:
tree-sitter`) — the `name.reference.*` captures this graph is made of are NOT persisted, so
Step 1 below **re-runs `tree-sitter query` once per FILE across the ENTIRE source set** —
every member of `N` (defined once, below), not just the files that changed since the scan:

| pass | invocations |
|---|---|
| symbol-graph build (Step 1) | **one per FILE in `N` — the entire source set** |
| PageRank itself (Step 3) | in-process, **zero spawns** |

On POSIX a spawn costs ~18 ms and the whole build is invisible. On a Windows box with an
endpoint-security agent it is **~220 ms** (measured, `windows-team-environment`), so an
ordinary 2,000-source-file repo costs ~7.3 minutes of pure spawn tax and a 10,000-source-file
repo ~37 minutes. This is a real field hang, not a hypothetical.

### `N` — the canonical definition (this section is the single owner)

Every other surface that mentions this gate (`SKILL.md` Step 7.5, `task-typing.md §Step 7.5`,
`halt-protocol.md §Confirm gates`) POINTS here and does not restate the definition. One
definition, one place.

**`N` is the excluded source-file set** — the source files `scan-codebase` enumerated after
applying its default exclusion list plus any `--include` / `--exclude`
(`scan-codebase/references/exclusions.md` is the owner of that list). Two things `N` is NOT:

- **Not "total repo files."** A bare walk re-admits `node_modules/`, `vendor/`, `dist/`,
  `build/`, `.mega-sdd/` — precisely what the anti-bias rail excludes. On a 900-source-file
  JS repo with a fat `node_modules/` that inflation fires this gate spuriously, and a gate
  that cries wolf gets dismissed. Those files are not graph nodes either, so counting them
  is wrong twice.
- **Not `N_extract`** — the post-invalidation subset `scan-codebase`'s own spawn-cost gate
  budgets. The symbol graph needs every node, not just the files that changed since the last
  scan. That mismatch is why scan-codebase's gate structurally cannot cover this pass.

**Near-zero-spawn source (mandatory — never walk the tree to decide whether the walk is too
expensive).** `generate-units` has no enumeration of its own, so computing `N` by walking
would BE the cost this gate exists to avoid. Two tiers, in order — take the first that
applies:

**Tier 1 — EXACT, preferred.** `scan-codebase` Step 4 persists its enumeration (the excluded
source-file set, `--include`/`--exclude` already applied) NUL-delimited to a DETERMINISTIC
path, `.mega-sdd/codebase/.scan/files.z`
(`scan-codebase/references/scan-procedure.md §Step 4`). When that file exists, count it:

```bash
awk 'BEGIN{RS="\0"} $0!=""{n++} END{print n+0}' .mega-sdd/codebase/.scan/files.z
```

**One spawn**, and the count is `N` exactly — this is the same set the walk produced, so
there is no floor/ceiling question at all.

**Tier 2 — FLOOR, fallback only.** `files.z` is scratch: `scan-procedure.md §Step 4` states
it is "overwritten every run, safe to delete", so it can legitimately be absent (a map
carried over from an earlier session, a cleaned working tree). Then and only then:

> **`N` ≈ the number of DISTINCT values in the `File` column of `codebase-map.md` §2 (Public
> interfaces).** A pure text read of a file already in context — **zero spawns.**

Under `--shallow-scan` the REUSE branch KEEPS prior §2 rows, so §2 still covers the whole
enumerated set rather than only the re-extracted subset.

Tier 2 has two documented undercounts, both biased toward NOT firing the gate — so both get
a rail. **These rails apply to Tier 2 only; Tier 1 is exact and needs neither:**

- §2 carries only files that yielded ≥1 public symbol. A source file with no public
  interface is still a graph node but has no §2 row → treat the count as a **FLOOR**, never
  a ceiling.
- `truncated_sections: ["2"]` in the map frontmatter means the 200-per-category extraction
  cap fired and §2 is INCOMPLETE. A floor off an incomplete table is meaningless → **take
  the ASK branch regardless of the count** (under `--auto`, apply the §`--auto` policy
  below).

```
N         = distinct `File` values in codebase-map.md §2 — the excluded source-file set;
            a FLOOR, and `truncated_sections` containing "2" forces the ASK branch;
            N = 0 when a valid <vault>/.internal/symbol-graph.json cache exists
per_spawn = 0.22s on OS=windows-bash, else 0.02s
estimate  = N × per_spawn
```

- `estimate` ≤ 60 s → proceed silently (a warm cache is always 0 s — the gate fires once
  per vault, not once per unit).
- `estimate` > 60 s → **AskUserQuestion before building** (INTERACTIVE lane only — under
  `--auto` do not reach this prompt; jump to §`--auto` policy below). State N, the estimate,
  and the OS. Options, each with its keterangan (→
  `plugins/mega-sdd/references/output-language.md §Prompt surfaces`):
  - **`--skip-pagerank`** **(recommended — Step 7.5 dilewati sepenuhnya; `target_files`
    tetap dari binding citations. Yang hilang cuma saran advisory: PageRank suggestions
    memang informational dan `execute-bolts` mengabaikannya (§Output integration), jadi
    tidak ada correctness yang hilang.)**
  - **Continue building the graph** — saran symbol-graph penuh, biayanya kira-kira sebesar
    estimate di atas. Dibayar SEKALI per vault (hasilnya di-cache di
    `<vault>/.internal/symbol-graph.json` dan dipakai ulang oleh semua unit), lalu batal
    saat `codebase-map.md` diregenerasi.
  - **Re-scan at regex tier** — jalankan ulang `/mega-sdd:scan-codebase --engine=regex`;
    `precision_tier` jadi `regex` sehingga Step 7.5 self-skip permanen. Konsekuensinya
    LEBIH LUAS dari Step 7.5: seluruh §2 `codebase-map.md` turun ke presisi regex untuk
    SEMUA consumer hilir (`bind-codebase` anchors ikut terdampak), jadi pilih ini hanya
    kalau memang mau map yang lebih murah, bukan sekadar mau melewati PageRank.

### `--auto` policy (the gate must NOT be a no-op in the autonomous lane)

`--auto` runs with nobody watching — exactly where a 37-minute stall strands someone. Per the
house rule (`SKILL.md` Step 0.5 / Step 7.6, `task-typing.md §Prompt frequency control`)
`--auto` takes the SAFEST option, which here is option 1, `--skip-pagerank`:

- `estimate` ≤ 60 s → build normally (unchanged; the gate never fires).
- `estimate` > 60 s → **SKIP the suggestion pass and keep generating units.** Do NOT block on
  `AskUserQuestion` (an unattended prompt is a hang wearing a different hat) and do NOT
  re-scan at regex tier.

**The `--auto` skip is not a SILENT skip — "silently" is about the record, not the action.**
The skip MUST be declared in both surfaces that report the pass:

1. Every affected unit body still carries its `## PageRank suggestions` section, with the
   skip recorded in place of the suggestions — N, the estimate, the OS, and the rerun path:

   ```markdown
   ## PageRank suggestions (review)

   SKIPPED by the Step 7.5 spawn-cost gate under `--auto`: N=2,000 source files (codebase-map
   §2) × 0.22 s/spawn (OS=windows-bash) ≈ 7.3 min estimated symbol-graph build, over the 60 s
   budget. `target_files` above are from binding citations only — nothing was dropped from
   them, only the advisory suggestions were not computed.
   To get the suggestions, re-run without `--auto` and choose "Continue building the graph".
   ```

2. The run's closing Hand-off summary line (`SKILL.md §Hand-off`) states the same four facts
   — gate, N, estimate, OS — so the skip is visible without opening a unit.

   The handoff YAML schema (`references/auto-and-memory.md §Handoff emission`) has **no
   warnings channel** — do NOT invent one. A confirm gate adds NO `blockers[]` entry, leaves
   `status: completed`, and NEVER sets `status: halted`: it is not a halt, and `status:
   halted` is reserved for the enumerated halt codes.

**Under `--auto` the regex tier is never picked.** That asymmetry is what resolves the
tension with the no-silent-downgrade rail below, and it is deliberate: skipping the pass is
per-vault, recoverable on the next run, and RECORDED in both surfaces above, whereas
re-scanning at regex tier MUTATES `precision_tier` in `codebase-map.md` — shared upstream
state every downstream consumer reads (`bind-codebase` anchors included), and not recoverable
without a full re-scan. An unattended run must never make that call.

Do NOT silently downgrade to `--skip-pagerank` or to the regex tier: `precision_tier` is a
property the map reports and the suggestion pass is a property the unit body reports, so
the choice belongs to the user. The ONE carve-out is the `--auto` policy above, and it is not
an exception to this rail: the pass is skipped but RECORDED (unit body + the closing Hand-off
summary line — never an invented handoff schema field), and
the tier is never touched. Do NOT skip the estimate on Windows because the repo "looks
small" — 272 files is already 60 s there.

## Algorithm

### Step 1 — Build symbol-reference graph

From tree-sitter scan output:

- Nodes = the excluded source-file set — `N` exactly as §Spawn-cost gate defines it (the set
  `scan-codebase` enumerated, read from `codebase-map.md` §2), NOT a bare walk of the repo
- Edges = symbol references between files
  - File A → File B edge if A imports B OR A references symbol defined in B (per ITER6-OQ-3: bidirectional, weighted)
- Edge weight = count of refs (more refs = higher weight)
- Build using `.scm` captures `@name.reference.<kind>` resolved against `@name.definition.<kind>` locations

### Step 2 — Seed files per unit

For each unit candidate's `vault_source` section, identify seed files:
1. Binding citations (claims marked CONFIRMED in `binding.md` with file:line anchors)
2. Existing `target_files` (if user pre-populated)

Seed set typically 1-5 files per unit.

### Step 3 — Personalized PageRank

Run PageRank algorithm with personalization vector = seed files:

- Restart probability (α) = 0.15 (standard PageRank damping)
- Personalization: uniform weight across seed files
- Iterations: 30 (sufficient convergence for typical repos)

Output: each file in the graph has a rank ∈ [0, 1]. Higher = more central to seed set.

### Step 4 — Surface top-K candidates

- Filter to K = 5 highest-ranked NON-SEED files (configurable via `--target-suggestions=N`)
- Skip files already in `target_files`
- Skip files in `--exclude` patterns (default node_modules, vendor, dist, build)

### Step 5 — Render-pass suggestion (per generate-units Step 12.5)

For each candidate file, surface in unit body as a `## PageRank suggestions` block (informational, NOT auto-added to target_files):

```markdown
## PageRank suggestions (review)

Files ranked highly relevant by symbol-graph analysis:
- `src/Http/Middleware/Authenticate.php` (rank: 0.42, refs to: User model, Auth pattern at routes/api.php:34)
- `tests/Feature/AuthTest.php` (rank: 0.31, refs to: existing auth tests; may need updates)
- `app/Providers/AuthServiceProvider.php` (rank: 0.28, refs to: auth-related bindings)

ACTION: Review each. To promote any to `target_files`, edit the unit's `target_files:` frontmatter list manually.
```

User reviews; promotes selected suggestions to `target_files` via frontmatter edit. NEVER silently rewritten (anti-halu rail).

## Output integration

PageRank suggestions appear in unit body before `## Out of scope`. They are INFORMATIONAL only — never enforced at bolt time. `execute-bolts` ignores the suggestions section; only `target_files` (frontmatter whitelist) is enforced.

## Performance

**The build cost is OS-conditional and dominated by process spawns, not by files.** A
single-number estimate here is a defect: the same repo differs by an order of magnitude
between POSIX and a Windows box with endpoint security, and a POSIX-calibrated figure is
exactly what let this pass ship ungated. Always quote the OS. Cost is `per_spawn` (above)
times one spawn per node, i.e. per member of `N` (the excluded source-file set — §Spawn-cost
gate owns the definition):

| N (source files) | POSIX (0.02 s/spawn) | windows-bash (0.22 s/spawn) |
|---|---|---|
| 272 | ~5 s | **60 s — gate threshold** |
| 1,000 | ~20 s | ~3.7 min |
| 10,000 | ~3.3 min | **~37 min** |
| 50,000 | ~17 min | ~3.1 hours |

- PageRank computation itself: in-process, no spawns — <500 ms per unit on typical repo size.
- Graph build is paid ONCE per vault (cached, §Caching), not once per unit.

`--skip-pagerank` disables the suggestion pass entirely (falls back to v1.5 behavior). It
is not a `>50k files` escape hatch: the spawn-cost gate above offers it as soon as the
estimate crosses 60 s — **~272 files on windows-bash**, ~3,000 on POSIX.

## Caching

Symbol graph is cached at `<vault>/.internal/symbol-graph.json` (canonical per paths.md), built by `generate-units` itself on first use (§Build steps above — scan-codebase does NOT persist reference captures). Re-used across all units in the same vault. Invalidated when `codebase-map.md` is regenerated.

## Anti-hallucination rails

- Suggestions surface in unit body as a labeled section
- Each suggestion CITES rank + reason (which symbols it references)
- User must MANUALLY promote to `target_files` (no silent add)
- `execute-bolts` ignores suggestions section; only target_files frontmatter is enforced
- `--skip-pagerank` flag disables entirely (graceful degradation)
- PageRank requires `engine: tree-sitter` (skips on regex codebase-map)

## References

- Aider repo-map: https://aider.chat/2023/10/22/repomap.html (PageRank algorithm)
- Tree-sitter integration: `scan-codebase/references/tree-sitter-integration.md` (Swap #1)
- Design spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.3
