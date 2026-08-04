# v6.0.1 — field-test hardening (simkredit findings)

**Date:** 2026-08-04
**Status:** DESIGN — implementation in progress
**Source:** first real-project run of 6.0.0 (simkredit, Next.js + NestJS pnpm monorepo, vault `simkredit-v1`, 2026-08-04). The operator's session verified every analyze FAIL against its source; five findings survived verification — 4 plugin defects + 1 deriver gap. This spec fixes all five. Patch release: no surface change, no grammar break, no gate weakened; every fix REDUCES false signal without opening a gate.

## F1 — dirty journal records out-of-repo writes → false `maintenance_sync`

**Defect.** `hooks/post-tool-use` journals every Write/Edit whose path is not under `.mega-sdd/`; the repo-relativization `DIRTY_REL="${FILE_PATH#"$PROJECT_ROOT"/}"` NO-OPS when the path is outside the project root (scratchpad `/private/tmp/...`, `~/.claude/.../memory/*.md`), so ABSOLUTE out-of-repo paths land in `.dirty-paths.jsonl`. `derive-state` counts journal rows as a change signal → `maintenance_sync` proposed on a repo where nothing moved. Field impact: EVERY session that uses a scratchpad poisons the signal.

**Fix (both ends — writer stops the bleed, consumer heals existing journals):**
- Writer (`hooks/post-tool-use`): journal ONLY when `$FILE_PATH` is under `$PROJECT_ROOT/` (literal prefix test BEFORE the strip); out-of-tree writes are skipped silently.
- Consumers: `state_probes.probe_dirty_journal` counts only relative-path rows (POSIX `/…` AND Windows `C:\…` absolutes excluded; unparseable rows still count — unknown is never silently ignored), and `derive-changed-paths.sh` gains the same Windows-drive guard (its POSIX `os.path.isabs` missed `C:/…` rows) — existing poisoned journals stop signaling without manual cleanup.
- **Disclosed limitation:** the prefix test is textual — a symlink-divergent spelling of the project root (or a relative `file_path`) journals nothing. The journal is an advisory HINT unioned with the git channel, which covers those writes once committed; canonicalization is deliberate non-scope.

## F2 — bolt-orphans gate blocks on a PRIOR vault generation's commits

**Defect.** The orphan scan (`validate-bolt-artifacts.sh --orphan-scan`) walks 300 commits for `type(U-XXX):` unit attributions and flags any id that exists in the CURRENT vault without a bolt-report. Unit ids restart at U-001 per vault generation, so commits from a DELETED prior vault collide with the new generation's ids → the gate blocks execute-bolts on evidence that belongs to different work.

**Fix (deterministic generation scoping via non-extra target intersection — ROUND-CORRECTED):** the first design justified itself with "B3 guarantees every legit bolt commit touches `target_files`, so a real orphan always intersects" — **that claim was logically unsound** (B3 guarantees `touched ⊆ targets ∪ extras`, which does not imply `touched ∩ targets ≠ ∅`; both round lanes built live extras-only dodges, a provable regression vs HEAD). The shipped conditions:

- A commit is an advisory `bolt_commit_generation_mismatch` (state-file `extras`, never a FAIL) ONLY when it touched at least one NON-SANCTIONED file AND none of its non-sanctioned files hits the current unit's `target_files` — positive evidence of different work. The intersection is GLOB-AWARE via the same `postflight_rules._glob_match` B3 uses (round: exact-string compare turned a glob-target real orphan into an advisory).
- Everything else stays BLOCKING: empty `target_files`, empty touched sets, and extras-only commits (tests/, `.mega-sdd/`, vault trees — the dodge shape). Unknown ≠ mismatch.
- Monorepo: touched files are PREFIX-stripped to project-relative before intersecting (walk_log emits git-root-relative names).
- The advisory detail says "consistent with a prior vault generation", never asserts it as fact.

**Disclosed residual (out of scope for this patch):** a prior-generation commit touching NON-sanctioned files (the simkredit lockfile shape) still trips **B3** (`whitelist_violation`) — B3 got no generation scoping here because relaxing a BLOCKING gate needs its own design + round, not a patch rider. The field remedy for that shape remains unit renumbering; extending generation scoping to B3/B1 is a candidate follow-up spec.

## F3 — starterkit-conformance treats prose `location` values as paths

**Defect.** Pack pattern fields may carry PROSE (`_universal`: `"colocated — a module with a test lives in a folder holding index.ts + index.test.ts"`; multi-root alternations with ` | `). `validate-starterkit-conformance.sh` does `tp.startswith(loc) / loc in tp` → prose never matches → EVERY file flagged, including files that satisfy the convention.

**Fix (path-shaped guard):** a `location` value participates in the path check ONLY if it is path-shaped — no spaces, no em-dash, no `|`. A non-path-shaped value SKIPs that check with an honest per-pattern note in the state file (`location_checks_skipped: {pattern: value}`) — never a violation, never silent. Multi-root values (`a | b`) are split on `|` and pass if ANY root matches, provided every alternative is itself path-shaped after trimming. **Matching semantics per site are UNCHANGED (round fold):** the shared helper takes a per-pattern mode — controller/request/test keep their historical startswith-or-substring tolerance; data_model stays startswith-only (the first cut silently loosened it and flipped a previously-correct violation). Also disclosed: `test.location` now honors the `"null"` sentinel like the other three sites (a wrong-verdict fix, previously undocumented).

## F4 — constitution-propagation reads binding claim ids as constitution clauses

**Defect.** The clause regex `[A-F]-\d{3}` also matches binding CLAIM ids (`C-009` — same shape). On a vault whose constitution uses the `§A1` style, the validator collected 19 claim ids from binding.md and demanded units cite them as "constitution clauses" — pure namespace collision.

**Fix (census-gated):** an id extracted from binding.md counts as a constitution clause ONLY if that exact id appears in the vault's `constitution.md` as a clause DEFINITION (list item / heading / bold at line start with a separator — round fold: a bare full-text findall let one prose cross-reference "see binding C-009" re-poison the census). The census glob also reads `<vault>/_meta/constitution.md` (deliberate widening — the emit builders already read that location). Zero census ids → the validator SKIPs with a NEW honest note naming the grammar situation (§-style constitutions have nothing this validator can key on); the advisory `constitution_no_clauses` WARN lives in the sibling `validate-constitution.sh`, unchanged.

## F5 — JSON-only OQ fields present in markdown are not derived

**Defect.** `scan_query` / `recommendation` / `rationale` / `scan_citations` / `fallback_if_wrong` are patch-lane fields; when the authored patch never landed (regenerated vault, manual authoring), the fields exist as hint lines INSIDE the OQ's markdown block but `derive-vault-json.sh` ignores them → `validate-vault-oqs` FAILs on OQs whose markdown is complete. Same family as the earlier `category: null` finding.

**Fix (md-hint fallback, lowest precedence — ROUND-HARDENED):** `vault_md.py` gains `parse_oq_field_hints(md)` — per-OQ-block DEDICATED hint lines for exactly those five fields, **anchored to line start** (round: unanchored, "…the vendor recommendation: keep REST" inside a question text was captured as an authored field) and **code-fence-aware** (round: a ```-fenced example beat the real hint). Backticks/quotes stripped; `scan_citations` splits on commas into the schema's array. The deriver applies hints LAST and fills a key only when it is absent **or null** (round: a carried `"scan_query": null` — the exact category:null precedent shape — made the fix inert). Precedence stays **skeleton > prior carry-forward > patch > md-hint**; the five fields are not in `DERIVED_OQ`, so the anti-laundering lanes are untouched. Cross-count guards unaffected (fields, not entries).

## Non-goals (disclosed)

- `oq_count_sync` WARN (roll-up index lags vault.json) — a per-project authoring lag, not a plugin defect; the WARN is the correct surface.
- §-style constitution grammar support (`§A1`) — the constitution validators stay keyed on `X-NNN`; a §-style project gets the honest SKIP/WARN (F4 makes it quiet instead of wrong). A grammar extension is its own spec if demanded.
- The orphan-scan `next_action` retroactive-backfill wording stays for TRUE current-generation orphans (audit trail genuinely lost); generation mismatches no longer reach it.

## Proof tests

`tests/surface/test-p4b-field-hardening.sh` (NEW): F1 writer skips an out-of-tree path + journals an in-tree one, consumer ignores absolute rows; F2 zero-overlap commit → advisory extra + PASS, overlapping commit without report → FAIL, empty-target verify unit stays blocking; F3 prose location → skip note + no violation, path-shaped still enforces, `a | b` alternation; F4 claim-id-only binding + §-style constitution → SKIP not FAIL, real clause census still enforces; F5 md-hint derives when patch absent, patch/carried value wins over a conflicting hint.
