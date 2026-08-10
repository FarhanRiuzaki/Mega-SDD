# scan-codebase — deep-scan gate (Steps 10.5.0, 10.5.1, 10.5.4 + 10.6)

## Contents
- Step 10.5.0 — Trigger check (+ pack-coverage advisory)
- Step 10.5.1 — Cache check (per-slice signature)
- Step 10.5.4 — Concurrency guard
- Step 10.6 — Emit codebase-map shared snapshot

Loaded by `scan-codebase` after Step 10 writes `codebase-map.md`. DEFAULT-ON when a framework is detected at MEDIUM+ confidence. No user flag required; opt-out via `--shallow-scan`. The five subagent prompt templates are a separate reference the SKILL.md router links to. The output schema lives in `plugins/mega-sdd/references/starterkit-context-schema.md`. This stage runs because §7 Framework is fully populated by Step 10.

The dispatch-side steps (10.5.1.5 manifest pre-parse → 10.5.2 subagent dispatch → 10.5.2.5 deep-read → 10.5.3 consolidation + full schema) live in the sibling **`references/deep-scan-dispatch.md`** — load it ONLY when Step 10.5.1 yields a non-empty `stale_slices`.

## Step 10.5.0 — Trigger check

```
IF framework.confidence in {high, medium}:      # string enum — the ONLY grammar Step 8.5 emits
                                                # (codebase-map §7: high | medium | low | fallback)
  → proceed to Step 10.5.1 (cache check)
ELSE (low OR fallback):
  → log "framework confidence <low|fallback>; deep-scan skipped — detection ambiguous, run scan-codebase --force-deep to override"
  → skip Step 10.5 entirely; proceed to Step 11
```

**Pack-coverage advisory (after trigger passes):** when the trigger proceeds, read `framework-conventions/_registry.md` (if absent, skip silently — never halt). If the detected framework's registry status is `thin` or `none`, emit one advisory note in the scan output:

> `pack coverage: <status> for <framework> — generic _universal fallback in use; see framework-conventions/_registry.md`

This is informational only — it surfaces that the deep-scan will use generic extraction rather than a full framework-specific pack. It never blocks the pipeline.

## Step 10.5.1 — Cache check (per-slice signature)

Mirrors the shared-snapshot reuse pattern (see `plugins/mega-sdd/references/shared-snapshot-schema.md`). Cache invalidation is per-slice: when only some inputs change (e.g., a frontend dep added in package.json), unchanged slices (auth, authz) reuse cached output; only invalidated slices (ui_ux, libs) re-dispatch.

```
1.+2. Compute per-ecosystem lock digests + digest groups — RUN the deterministic script
   (do not hand-compute hashes):

     # Resolve $PLUGIN_ROOT to the LATEST cached version (defeats stale-version anchoring;
     # see plugins/mega-sdd/references/plugin-root-resolution.md). DERIVED = this reference
     # file's own absolute path truncated before /skills/.
     DERIVED="<this reference file's absolute path, truncated before /skills/>"
     RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
     PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
     [ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
     bash "$PLUGIN_ROOT/scripts/compute-lock-digests.sh" \
       --project=<project-root> --app-ecosystem=<ecosystem of §7 Framework>

   It probes EVERY supported ecosystem's lock (php composer.lock; js package-lock/yarn/pnpm/bun;
   rust Cargo.lock; go go.sum; ruby Gemfile.lock; python poetry/uv/Pipfile/requirements;
   jvm gradle.lockfile/pom/gradle; dotnet packages.lock.json/Directory.Packages.props/*.csproj
   folded) and prints JSON:
   - locks_sha256: {<ecosystem>: <hex>}   (only ecosystems present; + lock_files provenance)
   - app_locks_digest      — locks of the APP ecosystem (ruby for Rails, go for Gin, js for Next.js)
   - frontend_locks_digest — js lock when APP ecosystem ≠ js AND a js lock exists
                             (asset/SPA layer of a non-JS app, e.g., Rails+esbuild, Laravel+Vite);
                             else = app_locks_digest
   - all_locks_digest      — every detected ecosystem folded together
3. Compute per-slice signatures:
   - src_component(<domain>) = sha256 of the RECURSIVE listing of the pack's <domain> FILE-HINT
     dirs (the same dirs/globs the subagent prompt's INPUTS-TO-READ names): one line per file,
     `<repo-relative-path>\t<mtime-epoch-seconds>`, sorted, newline-joined. Recursive so nested
     edits invalidate; listing+mtime (not content hashes) so it stays cheap; same mechanism the
     reuse slice already uses. Slice OUTPUTS are source-derived (auth entrypoints,
     authz declarations with file:line, ui tokens/config, libs usage_hint grep results), so a
     source-only edit (a controller, a policy, tailwind.config) MUST invalidate the slice —
     lock digests alone served stale slices as FULL CACHE HIT forever.
   - detector = scan-codebase <skill version from SKILL.md frontmatter> (a detector upgrade
     invalidates all slices — mirrors the memory-layer detector-versioning rail)
   - auth_sig_input = app_locks_digest + framework_pack §auth section content + sha256(lib-patterns/<fw>/auth-libs.md) + src_component(auth) + detector
   - authz_sig_input = app_locks_digest + framework_pack §authz section content + sha256(lib-patterns/<fw>/rbac-libs.md) + src_component(authz) + detector
   - ui_ux_sig_input = frontend_locks_digest + framework_pack §ui section content + sha256(lib-patterns/<fw>/ui-libs.md) + src_component(ui_ux) + detector
   - libs_sig_input = all_locks_digest + framework_pack §libs section + sha256(lib-patterns/<fw>/generic-libs.md) + src_component(libs) + detector
     (src_component(libs) = the reuse slice's first-party-source listing, reused as-is — the
     libs usage_hint entries are greps of that same source tree, so a source move/rename must
     invalidate them; no extra listing is computed)
   - reuse_sig_input = sha256(listing+mtimes of the hinted first-party source dirs) + framework_pack §Reuse discovery section content + detector
     (NOT lock files — reuse tracks first-party source, not deps; output written to reuse-index.yaml, separate from starterkit-context.yaml)
   - auth_signature = sha256(auth_sig_input); similarly for authz/ui_ux/libs/reuse
4. IF <project>/.mega-sdd/codebase/starterkit-context.yaml exists:
     a. Read its `cache_signatures:` block (v2.1 schema) OR `cache_key:` block (v1.0 schema, backward-compat).
     b. IF v1.0 schema detected → treat as "all slices stale" (full re-dispatch); migrate to v2.1 on next write.
     - IF a cached starterkit-context.yaml has schema_version < 3.1 (pre-authz `rbac:` shape) → treat the authz slice as STALE and regenerate it in the neutral shape (the rbac->authz reshape is not cache-compatible).
     c. IF v2.x schema (v2.1 current; a v2.0-era php/js-only block diffs the same way — its signature inputs changed, so its slices come out stale) → per-slice diff:
        - stale_slices = []
        - For each slice in [auth, authz, ui_ux, libs, reuse]:
            IF prior.cache_signatures.per_slice[<slice>].signature_sha256 != current_<slice>_signature:
              stale_slices.append(<slice>)
            IF prior has NO per_slice entry for <slice> (incl. a domain listed in prior
              partial_slices — failed slices get no per_slice entry, see deep-scan-dispatch.md
              Step 10.5.3 step 5):
              stale_slices.append(<slice>)
        - stale_slices ∪= prior.partial_slices   # a slice that failed last run must
          # re-dispatch — otherwise `partial: true` never self-heals (the prior signature was
          # written fresh while the OUTPUT is missing).
        - IF stale_slices is empty → FULL CACHE HIT: skip Steps 10.5.1.5 + 10.5.2 + 10.5.3 entirely
          — do NOT load `deep-scan-dispatch.md`; reuse existing starterkit-context.yaml AND existing
          reuse-index.yaml; set handoff_reused_flag = true; proceed to Step 11.
        - IF stale_slices is non-empty → PARTIAL CACHE HIT: load `references/deep-scan-dispatch.md`
          and proceed to Step 10.5.1.5 there; dispatch only stale_slices subagents in Step 10.5.2;
          consolidator merges fresh slices with cached slices in Step 10.5.3.
5. ELSE (file not present) → FULL CACHE MISS: stale_slices = [auth, authz, ui_ux, libs, reuse];
   load `references/deep-scan-dispatch.md` and proceed to Step 10.5.1.5 there.
```

Force full re-scan: `--no-cache` (existing flag; sets `stale_slices = [all]` regardless of signatures).

## Step 10.5.4 — Concurrency guard

Use the existing memory file-lock pattern (per `mega-sdd:memory` SKILL.md §file-lock: backoff + retry 3x; fail with `memory_in_use` blocker if all retries fail) on `.mega-sdd/codebase/starterkit-context.yaml`:
- Acquire exclusive lock before write.
- If lock held by concurrent scan-codebase invocation → fail fast with `memory_in_use` halt (existing halt type).
- Release lock after write.

## Step 10.6 — Emit codebase-map shared snapshot

After Step 10 codebase-map.md write completes, additionally write a shared-snapshot file per `plugins/mega-sdd/references/shared-snapshot-schema.md §scan-codebase (codebase-map snapshot)`. Enables downstream `bind-codebase` to attest map freshness with ONE sha compare — a freshness attestation, NOT a parsing shortcut (the consumer's own words: bind-codebase `auto-memory-handoff.md`); binding correctness is unchanged either way.

```
1. Compute codebase_map_sha256 = sha256(<just-written codebase-map.md>)
2. Write atomically to <project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json:
   {
     "snapshot_schema_version": "1.1",
     "snapshot_type": "codebase-map",
     "generated_by": "scan-codebase@<skill version from SKILL.md frontmatter>",
     "generated_at": "<ISO8601>",
     "scope": null,
     "files": [],
     "codebase_map_sha256": "<from step 1>",
     "source_files_sha256_map": {}
   }
   (source_files_sha256_map stays EMPTY for the codebase-map snapshot type — no consumer reads
   it, and per-file hashes already live in §2's Last_Scanned_Sha256 column; hashing every source
   file again here was write-only cost. The extracted-kb snapshot type still populates it — its
   generate-intent freshness check is a real consumer.)
3. Use temp-file + rename for atomicity (same pattern as the deep-scan-dispatch.md Step 10.5.3
   starterkit-context write).
```

If write fails (disk full / permissions): log warning + continue (snapshot is optimization, not correctness — bind-codebase falls back gracefully per shared-snapshot-schema.md §bind-codebase consumer).
