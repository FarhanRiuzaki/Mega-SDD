# Token-efficiency audit (batch 4) — what to cut, what to keep

**Date:** 2026-06-26 · **Ships as:** v4.43.0 · **Trigger:** "token use boros — sisir mana yang perlu dan tidak perlu, se-optimal namun se-tajam mungkin."

Method: measure first (line/char counts of every loaded surface + how often each is paid), then cut only where a cut does not dull the moat. The headline finding is that **most of the plugin is not wasteful** — the review panel, skill bodies, and descriptions were measured and deliberately kept.

## The two lanes (don't conflate them)

| Lane | Paid when | Main contents | Dominates when |
|---|---|---|---|
| **Always-on** | every session **+ every compaction** | `using-mega-sdd` anchor (was 6.5KB) + 17 skill descriptions (~8KB) + gated dynamic blocks | light router use |
| **Per-run** | only during bolt execution | `bolt-dispatch-prompt.md` (478ln) + `context-enrichment.md` (422ln) × per-bolt × per-lens | heavy pipeline runs |

A correct cut-list needs both lanes. `context: fork` helps the *always-on* lane (skill body runs without inheriting main history); it does **not** reduce dispatch cost (bolt agents already get fresh context) — different levers.

## KEEP — measured, already optimal (cutting would dull the moat)

- **Review-panel risk-tiering** — `minimal`=1 lens (spec) for routine bolts, `full`=4 only on a risk signal; design lens additive only for UI units. "Routine bolts pay for one lens." Already the dominant per-run control.
- **Blind per-lens context** — each lens re-receives the unit body and NEVER another lens's verdict; review-panel.md: *"do not 'save tokens' by sharing context between lenses."* Sharing is the anti-rubber-stamp rail; cutting it breaks the moat.
- **SKILL.md bodies** — all ≤500 lines (biggest: extract-intelligence 410); progressive disclosure honored, heavy detail already in `references/*` loaded on demand.
- **Skill descriptions** — ~8KB total but carry load-bearing ID/EN trigger keywords; within the ≤1024-char budget.
- **Hook telemetry** (stop / post-tool-use) — write state files, do **not** inject context per turn (verified: no post-tool-use output in a live context). Not a token sink.
- **Dynamic SessionStart blocks** (`INSTINCT_BLOCK`, `SELF_RESOLVE_NOTICES`, `LV_DIRTY`) — each gated `if [ -n … ]`, inject only when non-empty; INSTINCT capped at 1200 chars. Already clean.

## CUT — shipped this batch

- **Lean anchor injection** (always-on, high frequency). `session-start` re-injects the anchor every session AND compaction; it now injects only the routing **core** above a `<!-- ANCHOR-CORE ends -->` marker (triggers + auto-trigger logic + the hard rule), strips the YAML frontmatter, and falls **open** to the full skill if extraction is empty. The pipeline diagram / phase-ownership / multi-PRD / red-flags stay loadable via the Skill tool. ~57% per injection (7839→3330 chars). Guard: `tests/anchor-diet/test-lean-anchor.sh` pins that every trigger + the hard rule survive — the danger of a diet is silently dropping a trigger and regressing cold-start (post-compaction) routing.
  - *Why not skip the anchor entirely on compaction?* There is no model memory across a compaction; the summary preserves task state but not routing doctrine. The anchor is re-injected because it isn't retained. So the lever is "inject less," never "inject nothing."
- **Deny-message diet** (per-trip). Trimmed the "why-it-matters" exposition from 10 of 13 PreToolUse deny reasons; kept the fix recipe + state path + every `%s` + the four phrases the wired tests assert. ~26% lighter per trip.

## NUANCED — deferred / gated

- **Fork → scan-codebase + bind-codebase** (per-run, biggest structural lever). Structurally proven but **measurement-gated** (CLAUDE.md + `moat-token-tradeoff` memory). Scaffolded this batch: `scripts/measure-fork-tokens.sh` + `research/2026-06-26-fork-token-measurement-procedure.md`. Next step is the live run, not the extension.
- **Superpowers anchor** — a separate plugin injects its own `using-superpowers` anchor alongside mega-sdd's every session/compaction. For an SDD repo, mega-sdd's anchor already routes; the superpowers one is generic doctrine, arguably redundant here. Not mega-sdd's to cut, but a real always-on cost the operator can disable/slim.

## Backlog (task #18)

Fork scan/bind live measurement → extension; per-run dispatch-context trimming (only the *exposition* in `bolt-dispatch-prompt.md` / `context-enrichment.md`, never the lens-specific slices); the superpowers-anchor decision (operator-side).
