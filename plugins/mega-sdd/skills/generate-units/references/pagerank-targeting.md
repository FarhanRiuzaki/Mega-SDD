# PageRank Symbol-Graph Targeting

`generate-units` uses personalized PageRank on a file-level symbol-reference graph to auto-rank candidate `target_files` per unit. Adapted from [Aider's repo-map](https://aider.chat/2023/10/22/repomap.html) (45k ⭐ proven at scale).

## Why

In v1.5, `target_files` populated from binding citations + manual unit-author input. Misses files that share symbols with the unit's domain (e.g., a unit on Auth flow may need to touch `routes/api.php` even if not explicitly cited in binding).

PageRank ranks files by their "centrality" to a set of seed files (the binding citations); top-K candidates surface as suggestions.

## Detection prerequisites

Requires `engine: tree-sitter` in `codebase-map.md` frontmatter. If precision tier is `regex`, PageRank is SKIPPED — fallback to binding-only target_files.

## Algorithm

### Step 1 — Build symbol-reference graph

From tree-sitter scan output:

- Nodes = files in repo
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

- Symbol graph build: ~1s for repos <1000 files; ~5-10s for repos <10000 files
- PageRank computation: <500ms per unit on typical repo size
- Total cost per unit: ~1-2s additional vs v1.5

For very large repos (>50k files), `--skip-pagerank` flag disables the suggestion pass; falls back to v1.5 behavior.

## Caching

Symbol graph is cached at `<vault>/.internal/symbol-graph.json` (canonical per paths.md) per `scan-codebase` run. Re-used across all units in the same vault. Invalidated when `codebase-map.md` is regenerated.

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
