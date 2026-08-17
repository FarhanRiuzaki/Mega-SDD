# A5 — agent_type-scoped PreToolUse fast path: EVALUATED, REJECTED (on the record)

**Context:** candidate A5 of the adoption scan (`research/2026-08-17-claude-code-delta-adoption-scan.md`), greenlit for a spec 2026-08-17. The premise: read-only review-panel lenses "pay the full gate aggregator on every Bash call" — scope the write-guard battery by the new `agent_type` hook input and save spawns on the Windows/CrowdStrike fleet.

## What the recon + measurement showed

1. **The premise is false.** The expensive path (BRANCH 1 — the gate aggregator with its seven re-derivations) is **Skill-matcher-scoped**: it fires only on `Skill` tool calls, which panel lenses never make (`tools: Read, Grep, Glob, Bash`). Lenses never touch it today.
2. **What a lens Bash call actually pays** (measured, macOS, benign `grep` payload through the real hook): **3 python spawns**, of which (a) the stdin parse — the *prerequisite* for reading `agent_type` at all, unavoidable under any scoping design — and (b) the BRANCH 2 anti-self-bypass battery.
3. **BRANCH 2 is exactly the guard a Bash-capable agent must keep.** The scan's "read-only lens" framing looked at the `tools:` allowlist, not at what Bash reaches: a prompt-injected lens can `echo > postflight.json` like any other shell. Skipping the write-guard for lens `agent_type`s opens the forged-evidence class the guard exists for — and `agent_type` is harness-supplied input, so a fail-closed absent/unknown handler (mandatory) reruns the full battery anyway.

## Verdict

**Do not build.** Safely skippable residual ≤1 spawn per lens Bash call against a fail-open risk class on the moat's evidence artifacts. The Windows spawn-cost problem this aimed at was already addressed at the right layer (v5.22–5.24 resolver cache + batching; the P1 statusMessage makes the residual visible instead of silent). Do not re-litigate without evidence that lens Bash traffic is a material share of fleet hook time.

*Third evaluated-reject of the 2026-08-17 sweep (after P2b, c1) — same lesson each time: measure the actual path before pricing the cut.*
