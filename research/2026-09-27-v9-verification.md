# mega-sdd 9.0: what is verified, how, and what is not

**Date:** 2026-09-27

**Question from the owner:** "how do I know what was done is right and verified, not assumed?"

**Answer:** Nothing below rests on the implementer's own report. Every claim was re-checked in one
of three ways:
- an **independent falsification audit**: agents that did not do the work, each told to *refute* one
  claim, working in clean copies of the commit, with commands and output as evidence;
- **live runs of the 9.0 tree**;
- **tests that fail on the pre-fix code**.

Where the audit found a defect, it was fixed. The fix has a failing-first test, and a second
reviewer reproduced the original defect on the pre-fix code. Where something is still unverified,
it is listed in §5.

Commits: `6727b30f` (9.0.0), `1ab6c43e` (P1b), `2ee41ce8` (verification fixes + smoke), and the
commit carrying this document.

## 1. The independent audit (workflow `v9-independent-verification`, 10 agents, HEAD `1ab6c43e`)

| # | Claim | Verdict | Defect found | Status |
|---|---|---|---|---|
| V1 | The committed HEAD passes the whole CI loop, the manifests agree, and the packs validate | **CONFIRMED** (2 clean clones: 294/0) | Nothing in the code. The machine's Xcode licence prompt broke git/python mid-run, which caused 24 false failures in one run | — |
| V2 | Every number in the reports matches the raw data | **PARTIAL**: all table medians and ranges match; `compare-arms.py` reproduces `REPORT.md` / `compare.json` byte for byte | About 11 misstated figures in the prose, e.g. token ratio "9–20×" (really 11–54× total), clinic classic historical "102 min" (really 301.4), rubric drift "≤4" (really up to 8), HTML share, rounding, C1–C8 vs C1–C10, and a claim that one routed-v1 run skipped delivery-check (all three ran it) | fixed in `2ee41ce8` |
| V3 | The relocation lost no normative contract text | **CONFIRMED**: 190 MUST/NEVER/HALT lines diffed; 118 verbatim, 72 hand-reviewed, each mapped to a spec decision or a removed component | Two headers said "verbatim" for trimmed files | fixed |
| V4 | Invariant #2: an unresolved CONFLICT blocks its unit | **PARTIAL**: holds on a fresh vault (the real hook denied the dispatch; after resolution it allowed it) | **Regression:** on a migrated layout-2 vault, a never-resolved CONFLICT stopped blocking after `rebind-units --units=all` | fixed + `tests/v9/test-migrated-conflict-blocks.sh` |
| V5 | The gateway contract is intact | **CONFIRMED**: the hooks give byte-identical output to the pre-work commit across 22 inputs; all announce tags are verbatim | The doc's announce counts were wrong (13, not 14); plan's adversarial-review subagents had no trace line (true before 9.0 too) | fixed |
| V6 | Routing and preflight work as designed | **PARTIAL** | The plan-coverage rail was enforced only in `--predictive` mode, so the hook let `execute-bolts` through on a coverage FAIL; a legacy vault without `vault.json` routed to direct; a removed-skill FATAL was skipped without `.mega-sdd/` | fixed + tests |
| V7 | `extract-intelligence` → `plan --kb` works on a realistic KB | **PARTIAL** | `validate-plan-coverage --kb` was **fail-open** (it dropped real requirement headings; fenced headings were counted) | fixed + 14 edge cases in `tests/v9/test-kb-to-plan.sh` |
| V8 | No claim goes beyond the measured data | **PARTIAL** | "anti-hallucination by construction" was stated for every lane; the marketing keyword was still in the manifests; "on par" was not scoped to greenfield | fixed + `tests/v9/test-honesty-docs.sh` |
| V9 | The commits contain only intended changes | **CONFIRMED** | One stale mention of a deleted script; one stale CHANGELOG note | fixed |

**Found by the critic after the fixes:** plan coverage in **PRD mode** (not only `--kb`) matched
meta sections by prefix. A PRD with 4 uncovered MUST requirements ("Background Jobs", "Versioned
Receipts", "Source of Funds Check", "Scope-based Access Control") passed. The same prefix match
failed in the other direction too: numbered meta sections ("§Clinic.2 Non-Functional
Requirements", "1. Context", "6. Out of scope") were counted as requirements.
- **First fix:** match the whole heading. Two independent attackers then broke it in both
  directions. That led to the redesign described in §4.

## 2. Live runs of the 9.0 tree (smoke, n=1 each; not benchmarks)

Data: `benchmarks/results/v9-smoke/`. Working repos: `/private/tmp/claude-501/mega-sdd-bench/work-v9/`.

| Run | Lane | Time | Cost | Subagents | `.mega-sdd` lines | AC | Critical / Important | Rubric | Delivery-check | Trace |
|---|---|---|---|---|---|---|---|---|---|---|
| xs routed-1 (`1ab6c43e`) | direct | 2.4 min | $1.05 | 0 | 0 | 12/12 | 0/0 | 94 | PASS 5/5 | `mega-sdd-trace:direct` |
| xs guarded-1 (`1ab6c43e`) | guarded (plan → execute-bolts → detect-drift) | 26.9 min | $13.10 | 18 | 4,642 | 12/12 | 0/2 | 86 | PASS, D5 WARN (a page with no link) | skill tags; 18/18 dispatch prompts carry the line |
| xs-oq routed-1 (`2ee41ce8`) | assisted (one open business item) | 4.2 min | $1.62 | 1 (the blind review) | 0 | not scored | — | — | PASS | `mega-sdd-trace:assisted` + `mega-sdd-trace:assisted-review` |

**What these runs show about 9.0:**
- Every lane runs end to end on the committed tree.
- No removed skill is ever invoked.
- The result contract (criterion → test table, `VERDICT: PASS` quoted, assumptions, commits)
  appears in all three final reports.
- The guarded run's delivery fix worked: the missing `npm test` script was added in a
  `fix(delivery)` commit.
- The assisted run surfaced its open business question in the first line, as a conservative,
  reversible assumption, before any code was written.

**What they do not show:** a quality advantage for guarded. In this run it scored lower (86 vs 94,
2 Important: no link to a page, and an uncaught save error). That matches every measured block (§3).

## 3. Measured result quality, all blocks

These runs used the pre-9.0 tree, except the smoke run. Blind scoring throughout.

| Scenario | Direct / assisted / vanilla | Pipeline |
|---|---|---|
| xs | AC 12/12, 0/0, rubric 93–96 | lite/classic 11/12, rubric 82–84; 9.0 guarded smoke 12/12, 0/2, rubric 86 |
| clinic | AC 10/10, rubric 90–91 | lite 9–10/10, rubric 85 |
| brownfield (seeded traps) | AC 13/13, traps 5/5, rubric 91–93 | guarded AC 13/13, traps 5/5, rubric 89–91, at 6× the cost |

The pipeline never scored higher. Its extra defects come from splitting work across units.

## 4. The plan-coverage gate: attacked, then redesigned

**The loop (workflow `v9-coverage-gate-hardening`, 3 rounds).** Each round had one implementer
followed by two fresh attackers: one looking for **fail-open** cases (a requirement heading passes
with no unit), one for **fail-closed** cases (a non-requirement blocks the plan). The results:

| round | fail-open HIGH | fail-closed HIGH | script lines |
|---|---|---|---|
| 1 | 3 | 2 | 305 |
| 2 | 3 | 2 | 456 |
| 3 | 2 | 3 | 588 |

Every fix moved the error to the other side. Examples from the last round:
- "Open Questions" sections were forced as requirements by "Whether SSO is required".
- A descriptive "must" in Background forced a cascade of intro sections.
- "Out of Scope (Post-MVP)" lost its exclusion.
- A To-Be flow H3 under "Latar Belakang" was silently excluded.
- Feature sections named "Timeline", "Approvals" and "Sources" were excluded together with their
  H3s.

**Conclusion:** deciding whether a heading "is meta" by heuristics does not converge.

**Redesign: declared coverage** (spec §7 #13, workflow `coverage-declared-redesign`). Every H2/H3,
parsed as CommonMark does, must carry an explicit decision:
- a unit's `prd_source` names it;
- a `[business]` OQ names it with `[covers: <ref>]`; or
- it is declared in `context.md` under `## Coverage exclusions` with a real reason.

The gate checks that the decision exists and never judges what a heading means. A silent omission
becomes a reviewable line, and a false block costs one line.

**Hardening after the redesign:** two more attack rounds (fail-open, and friction plus contract),
each followed by a fix round. Residual limits:
- a requirement written inside valid top-of-file YAML frontmatter is hidden;
- a heading in a raw HTML block is censused even when CommonMark renders none (one extra
  declaration);
- H4+ headings belong to the enclosing anchor unless that anchor is a pure container;
- a differential fuzz against commonmark.js missed 3 headings in 30,000 random documents.

**Friction, measured by planning the real PRDs:**
- 5 declarations for xs;
- 4 for brownfield;
- about 9 for clinic;
- about 12 for the PRD template.

**Migration impact:** 9 of the 14 bench vaults FAIL until they add declarations, and 3 are exempt
(layout-2). The gate prints paste-ready lines.

**Cost of the change:** 182 → 804 lines (286 for the gate plus the shared 518-line
`_lib/prd_headings.py`). This is recorded as a defect-fix raise in the complexity budget.
Tests: `tests/v9/test-plan-coverage-prd.sh` has 287 checks, 72 of them RED on the pre-redesign
script; `tests/v9/test-kb-to-plan.sh` has 64.

## 5. Not verified yet (be explicit)

1. **The measured benchmarks (§3) ran on the pre-9.0 tree.** On 9.0 there are only the three smoke
   runs above, at n=1.
2. **The CONFLICT gate has never fired in a live 9.0 run.** It has fired only on hand-built
   fixtures (V4). The seeded-trap brownfield block has not been re-run on 9.0.
3. **Not run live on 9.0:**
   - the clinic scenario;
   - an existing-code project on the assisted lane (the 9.0 default for brownfield);
   - `extract-intelligence` → `plan --kb` → `execute-bolts` end to end (V7 exercised the scripts
     only);
   - `/mega-sdd:sync`, `diff-vault` → `plan --regenerate`, and `resolve-oq --binding`;
   - `migrate-paths` on a real user vault.
4. **The docs lanes on a 9.0-born vault:**
   - `emit-fsd`'s entities / modules / public-interfaces sections read the codebase map, and nothing
     produces that map any more, so those sections will show `[Pending — codebase-map.md absent]`;
   - `emit-agents-md` also reads the map.

   This is a known gap for a follow-up. The CHANGELOG notes it.
5. **Linux CI.** Every check ran on macOS. The branch is not pushed, so the CI workflow has never
   run on these commits.
6. **Upgrading from an installed 8.x.** Not tested. This machine still has 8.7.2 installed, and its
   session hooks wrote an untracked `.mega-sdd/` into this repo; that folder is not part of the
   commits.
7. **Headless only.** The interactive batched ask and a human answering a CONFLICT halt were never
   exercised.

## 6. Re-check it yourself

```bash
R="/Users/riuzaki/Private Space/Sunny Go/PROJECT-APPS/mega-sdd-github"
export DEVELOPER_DIR=/Library/Developer/CommandLineTools          # avoids the Xcode-licence noise
T=$(mktemp -d); git clone -q --no-hardlinks "$R" "$T/repo"; cd "$T/repo"
# the v9 pins (routing, delivery check, trace contract, result contract, KB, coverage, migrated CONFLICT, honesty)
for t in tests/v9/*.sh tests/lanes/test-lanes.sh; do bash "$t" >/dev/null 2>&1 && echo "ok  $t" || echo "FAIL $t"; done
# the whole CI loop (~7 min; 0 FAILED expected, and grep 'Xcode license' must be empty)
find plugins/mega-sdd/tests tests \( -name 'test-*.sh' -o -name '*.test.sh' \) | grep -vE 'test-registry-fresh|test-all-full-ready|test-all-green' | sort \
  | while read t; do bash "$t" </dev/null >>"$T/loop.log" 2>&1 || echo "FAILED: $t"; done
# every benchmark table reproduces from raw data
python3 benchmarks/scripts/compare-arms.py benchmarks/results/vanilla-ab/manifest.json --json "$T/c.json" --md "$T/r.md" >/dev/null && cmp "$T/c.json" benchmarks/results/vanilla-ab/compare.json && echo tables-identical
# which plugin each run actually loaded
grep -h '^purity=' benchmarks/results/*/*/*/run.meta | sort | uniq -c
# the 9.0 live runs deliver (repos are under /private/tmp; they vanish on reboot)
for a in xs-routed-1 xs-guarded-1 xs-oq-routed-1; do bash plugins/mega-sdd/scripts/delivery-check.sh --cwd=/private/tmp/claude-501/mega-sdd-bench/work-v9/$a | tail -1; done
```
