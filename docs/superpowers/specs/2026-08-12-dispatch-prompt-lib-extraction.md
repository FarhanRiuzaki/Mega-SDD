# build-dispatch-prompt.sh `_lib` extraction — phase 0: the golden parity harness

**Date:** 2026-08-12
**Status:** P0 SHIPPED v6.7.1 (2026-08-12, 53c16f3 + CI-fix e714b55, CI green BOTH host classes, suite 220/220) — round 2B/2M/3m + the post-round CI catch, ALL folded (§Round disclosure); P1+ extraction ladder OPEN, gated on this harness
**Source:** proposals doc `2026-08-11-morning-proposals.md §(a)` (USER: "gas" on the recommendation — Option 2, opportunistic extraction **with the parity harness built FIRST**; precedent: `_lib/postflight_rules.py`, B1 recompute v4.62.0).
**Version:** 6.7.1 (patch — a NEW test surface + goldens; ZERO builder-code change in this phase).

**Why harness-first (binding).** `build-dispatch-prompt.sh` is 194KB / 3,713 lines on the bolt-dispatch moat path, token cost 0 (executed, never read) — the upside of extraction is purely maintainability, so the ONLY acceptable risk level for refactoring it is "provably byte-identical". The existing shape suite (`tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` §H) proves *intra-version* determinism; extraction needs *cross-version* identity against a RECORDED corpus — golden files committed to the repo, regenerated only by explicit human-reviewed intent.

## P0 — `tests/dispatch-parity/test-dispatch-prompt-golden.sh` (this ship)

- **Three fixtures, deliberately FRAMEWORK-LESS** (no `framework_pack`, no manifest → pack resolution SKIPs): goldens must pin BUILDER logic, never plugin pack content — a `laravel.md` edit must not break them. Pack-injection behavior stays covered by the shape suite's §A (live-validator parity), not duplicated here.
  - `f1-minimal` — no optional inputs at all (the §D anti-fabrication shape: omissions cited, nothing invented).
  - `f2-ui` — ui-bearing unit + starterkit `ui_ux` tokens + vault `design_system` (no pack): design-slice file + T2 design sections exercised.
  - `f3-hardrules` — modify-type unit, 3 target files, DO-NOT + SIGNATURE-LOCK Hard rules with a decision citation: freezes the hard-rule + whitelist assembly seams (the ones extraction touches first). *(An `f3-oversize` variant was tried and dropped: 111KB of filler produced `truncations: []` — the cap lane never fired, so the golden froze nothing distinctive at 114KB of repo weight; the cap/truncation lane stays owned by the shape suite.)*
- **Golden corpus committed** per fixture: normalized `dispatch-prompt.md`, normalized stdout JSON (`--explain` form), normalized `stderr`, the builder's complete `emitted-paths.txt` (full-tree before/after sweep — a stray file from a future extraction is itself a golden divergence), `exit-code`, and `design-slice.md` where emitted. Normalization = fixture-root/plugin-root prefixes → `@PROJ@`/`@PLUGIN@`, **un-normalized byte counters (`file_total`/`file_bytes`) → `@N@`, and the plugin version stamp → `@VER@`** (both round-BLOCKER classes, live-proven: without them the corpus pinned the recording machine's path lengths and the current release number). `t1_bytes`/`t2_bytes`/`total_bytes` are path-independent and stay pinned. Corpus-frozen plugin docs, disclosed: the f2 golden embeds the builder-INJECTED bodies of `ui-design-heuristics.md` + `design-intelligence/{style-principles,ux-rules}.md` rows — that injection is a builder seam extraction must preserve, so edits there legitimately regen f2.
- **Arms**: per-fixture golden identity (file + stdout + slice); double-run determinism (pre-golden sanity); a self-check arm that tampers one byte of a golden COPY and must see the comparator fail (no vacuous pass); exit-code pins (0 for all three fixtures).
- **Regeneration is explicit and manual**: `GOLDEN_REGEN=1 bash …` rewrites the corpus; the header mandates that a regen commit states WHY the output legitimately changed. CI never regens. This friction is the point — every intended builder-output change becomes a reviewed diff of the corpus.
- **Interpreter + host classes**: resolve via `_lib/resolve-python.sh` like the sibling suites (the Windows alias-stub lesson); every builder call `</dev/null`.

## P1+ — opportunistic extraction (NOT this ship; each move = its own round)

Ladder rules, binding for every future move:
1. Extract a module ONLY when that section is being edited anyway (proposals guidance), into `scripts/_lib/dispatch_<module>.py`, bash stays the thin CLI.
2. The golden suite must pass UNCHANGED (byte-identical corpus) before AND after the move — a regen accompanying an extraction commit is a red flag by definition.
3. One module per commit; shape suite + cascade suite + golden suite green in between.
4. The spawn budget in the builder header is re-measured after any move that adds an exec (the ~220ms/spawn fleet constraint).

## Round disclosure (single blind reviewer, breakage-focused — test-only surface)

2 BLOCKERS / 2 MAJORS / 3 minors, ALL folded, each blocker live-proven both broken and fixed: **B1** goldens encoded absolute-path byte LENGTHS via `file_total`/`file_bytes` (the counters measure the un-normalized file) — 6 FAILs from any other checkout path, CI dead on arrival; fixed by counter tokenization, proven green from a moved copy. **B2** the plugin version stamp (`mega-sdd v6.7.0`) was a golden byte — every release (including this one) would redden its own harness and force the routine regens the doctrine forbids; fixed by `@VER@` tokenization, proven green at a fake 9.9.9 bump. **M1** f2 froze three injected plugin docs against the harness's own "no plugin content" principle → resolved by DISCLOSURE (the injection is a seam worth freezing), not elision. **M2** the new-artifact sweep only saw a curated copy list → replaced by a full-tree before/after `emitted-paths.txt` that is itself a golden. Minors: all-or-nothing regen staging (a mid-regen builder failure no longer half-writes the corpus), stderr normalized before commit, self-check arm guards its inputs. Reviewer's CLEAN list confirmed: corpus hygiene (zero machine strings), no vacuous-pass paths, regen not CI-reachable, POSIX portability, and that f1/f2/f3 freeze structurally different assembly seams.

**Post-round CI catch (53c16f3 red, folded 2026-08-12):** one more length-sensitive counter survived the round — `inline_core_bytes` measures the un-normalized `inline_core` (which embeds the absolute dispatch path); every artifact was byte-identical on ubuntu EXCEPT that one field, off by exactly the mac↔ubuntu mktemp path-length delta (44). The moved-copy proof had missed it because same-machine mktemp paths share a LENGTH even when their text differs. Folded: `inline_core_bytes` → `@N@`, plus a STANDING `path-length independence` arm (rebuild f1 under a different-length root; normalized outputs must be identical) — the class guard a moved-copy check cannot provide.

## Non-goals (this ship)

Zero edits to `build-dispatch-prompt.sh`; no `_lib` module created; no pack-bearing golden (deliberate — see above); no golden for halt exits (2/4 publish no artifact — nothing stable to freeze; the shape suite owns those paths).
