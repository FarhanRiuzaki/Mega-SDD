# mega-sdd skills — structured gap audit (2026-06-24)

**Method:** 4 parallel read-only probes (pipeline/lifecycle, enforcement-doctrine, anti-hallucination/tech-agnosticism, self-testing/cohesion) → advisor challenge → the 2 candidate-Criticals verified directly against source (1 confirmed, 1 refuted). Findings graded *after* that filter — subagent claims that didn't survive verification were dropped or corrected.

## Thesis (one axis)

**mega-sdd's "anti-hallucination by construction" holds in proportion to available ground truth.**
- **Brownfield / binding** (ground truth = codebase-map): deterministic checks, genuine moat, tested fail-closed. Strong.
- **Greenfield / Mode B / vault prose / OQ recommendations** (no ground truth): enforcement degrades to prose + one LLM advisor checking another LLM. Not a bug — the honest **boundary** of the claim. Should be stated, not buried.

## Verified Criticals

- **.NET invisible to the scanner — CONFIRMED.** `grep csproj|.sln|nuget|dotnet` in `skills/scan-codebase/` returns nothing. A .NET repo isn't probed → falls through to `_universal`. AST queries exist for 8 langs (php, ts, js, py, go, java, ruby, rust); non-AST stacks get regex → binary binding (no `PARTIAL_FIELDS_*`). The "works for ANY stack" claim has a real hole. → `scan-codebase/queries/`, `scan-procedure.md §8.5`.
- **"Moat fails open on corrupt/missing state" — REFUTED.** Direct read of `hooks/pre-tool-use`: the binding→units moat is **fail-closed** on corrupt state (L322, covered by passing `tests/moat/test-moat-corrupt-fail-closed.sh`) AND on missing-python3 (`FB_MOAT` fallback L78–80 denies unless state attests PASS). The probe misread the short-circuit. Residual truth is the Minor below.

## Real gaps (tiered, post-verification)

### Important
1. **Tech-agnostic leak — .NET invisible; non-AST stacks silently degraded** (verified above). The flagship coverage gap.
2. **No CI.** No `.github/workflows`; moat + 18 trigger tests + graph suite run only manually → a PR touching the gate can merge unverified.
3. **Router NL-routing gap.** 6 skills — `analyze, memory, graph, emit-fsd, emit-agents-md, install-deps` — are reachable only by explicit `/command`, not via natural-language triggers in `using-mega-sdd`. "check consistency" / "impact of X" won't route. *(Partially fixed 2026-06-24 — see Changelog 4.32.0.)*
4. **No full suite re-run after a multi-unit batch** — units pass individually, integration can break unseen. Reconcile with `--parallel` liveness: if parallel isn't wired yet, this is *latent*, activating when it ships.

### Minor
5. Non-moat code-delivery gates (render-test, flow-coverage, sibling-consistency) treat **absent** state as allow — a PostToolUse validator that crashes on missing python3 silently skips *that* gate. The binding→units moat is exempt (hardened). Partly by-design ("never evaluated").
6. `generate-units` CONFLICT refusal is prose; the *enforced* gate sits one step later at `execute-bolts` (defense-in-depth holds — a conflict reaches a unit but not code). "Fire one step earlier?" not "moat hole."
7. Provenance asymmetry: KB carries `[VERIFIED]/[INFERRED]`; vault OQ *recommendations* don't — an LLM rec reads identically to stakeholder input.

### This session's own debt (proof the audit is real)
The graph layer shipped this session created three findings: `validate-binding-json.sh` is an **orphan** (wired as prose only; feeds a deletable cache → Minor); `graph` has **no trigger test**; `graph` has **no router entry** (consciously skipped in its Task 6 — finding #3 revisits that). The plugin's growth-debt dynamic bit its own new commits.

## Considered & rejected (with reason)
- *No PR/CI/deploy stage* — scope; spec→code pipeline, not CD.
- *Graph-as-gate* — deliberate out-of-chain design.
- *Vault unbounded growth* — by-design history preservation.
- *Vault-prose citation not deterministically enforced* — inherent to LLM generation; the binding gate is the backstop (this is the thesis, not a defect).

## Recommended next targets (by leverage)
1. **#1 .NET / non-AST coverage** — add `.csproj/.sln/nuget` manifest probes + a .NET framework-conventions pack + regex patterns. Biggest credibility win for the "any stack" claim.
2. **#2 CI** — a `.github/workflows` that runs moat + trigger + graph suites; cheap, high regression-protection.
3. **#3 router NL-routing** — partially addressed 4.32.0.
