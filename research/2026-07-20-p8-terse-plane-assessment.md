# P8 terse-plane assessment — measured, and it does not pencil out

**Date:** 2026-07-20 · **Method:** advisor-guided static measurement (no live A/B) + a two-part pin-audit · **Verdict:** **DEFER P8; P9 (WAJIB accuracy) is higher user-value.**

## The question

P8 (v5.2.0) proposed terse-ing the AI-plane artifacts (vault/binding/unit) to attack standing-context residency (research §2, the 2nd cost driver). The user picked P8 over the alternatives. This assessment measures it *before* cutting — per the advisor's rule: don't silently grind a small lever.

## Finding 1 — the lever is resident, not fresh (0.1×), and small

Template *files* are the wrong target: their instructional prose is generate-time resident (loaded once via progressive disclosure), not the monotonic-residency driver. The real lever is dead human-prose in the *output* artifacts. Static split of a vault (prose-lines vs gate-token/structured-lines) put the prose fraction in the ~60% range **on a toy fixture** — but that number *overstates* the cuttable share (short factual claim lines are counted as prose; only genuinely-dead human narrative is cuttable). Weighted by the cache lens — RESIDENT 0.1× × turns-resident (bounded by the **compaction window**, not the 250-turn run) — the real-dollar value is modest, in the same class as the P7 items already deferred (kb-claims, bind-map).

## Finding 2 (decisive) — the pin-audit's second check FAILS: consumers RELY on the prose

The emitters do **not** synthesize from structured tokens — they **flatten vault prose verbatim and sha256-stamp it** as the human doc's cited source. Evidence (`emit-fsd/references/section-mapping.md`):

- §1 Overview ← `01-overview.md §Purpose + §Scope`, extraction: *"Read entire §Purpose block + §Scope block; preserve markdown formatting"*, citation `(sha256: …)`.
- §2 Goals/Non-Goals ← `01-overview.md §Goals + §Non-Goals`, *"extract … as-is"*.

So terse-ing that vault prose would:
1. Change the source bytes → **sha256 mismatch → citation drift → `[Pending]`** (breaks invariant #3, citation discipline).
2. Make the **human FSD terser to read** — directly counter to the user's own mandate that PRD/FSD/SIT are the documents the team reads.

The "narrative-synthesis switch" the spec names (emitters synthesize narrative from structured tokens instead of flattening cited prose) is **not a safe substitute**: it replaces auditable verbatim-copy-with-sha with model-generated narrative — **reintroducing the fabrication risk invariant #5 exists to prevent.** The current architecture is anti-fabrication *by construction*; the switch would trade that away for a modest resident token cut.

## Recommendation

**Defer P8.** The token thesis is substantially banked: P7's one genuine fresh-seed lever shipped (5.1.1 advisor-bundle), and extract/execute-bolts were already slice-optimized. What remains for tokens is resident-cheap and, for the vault prose specifically, entangled with the human-doc readability the user explicitly wants and with the citation/anti-fabrication moat.

Go to **P9 (v5.3.0) — the WAJIB accuracy mechanisms** (reuse gate + dep-authorization, advisory-first): this directly serves the user's HARD mandate ("akurasi code itu WAJIB, pas, expert dev") and is unambiguously high user-value, with no moat tension.

If a terse cut is still wanted later, the ONLY safe shape is trimming artifact regions that the pin-audit proves **no gate parses AND no emitter cites** — a per-vault, per-emission determination, not a template-level cut. Small, and it can ride P10 telemetry once real citation maps exist to prove what is uncited.
