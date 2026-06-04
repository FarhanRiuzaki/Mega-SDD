# Mega-SDD — Architecture Modernization Audit

**Date:** 2026-06-04
**Baseline audited:** mega-sdd v3.72.0 (Iter 80), 477 commits
**Question from author:** Is the current architecture outdated or unsound vs. current Claude Code / Anthropic guidance? If so, make a radical change — maximize the platform, stay true to the "skills" idea, and learn from how *superpowers* works.
**Method:** Direct file read of the whole plugin + primary-source verification against Anthropic's published Skill-authoring guidance and the current superpowers release (v5.1.0). Adversarial lens — "designed ≠ working," consistent with the project's own Iter-67 integrity discipline.
**Scope:** Analysis + redesign proposal only. No code changed.

---

## 0. Verdict (TL;DR)

**The core *idea* is sound and, in places, ahead of the field. The *implementation* is outdated and over-built. A radical restructure is warranted — but as a disciplined "lean-core" rebuild that preserves the moat, not a throw-everything-away rewrite.**

Three sentences for the busy reader:

1. **The grounding moat is real and worth protecting.** Spec→code binding with CONFIRMED/CONFLICT/OQ verdicts, sha256 citation discipline, the halt taxonomy, mutability tiers — no competitor (superpowers, Spec Kit, GSD, BMAD, Kiro) grounds specs against live code at this depth. Keep it.

2. **Almost everything *around* the moat now fights the platform.** 9 of 16 skills exceed Anthropic's 500-line SKILL.md ceiling (the biggest is 2.6×); the progressive-disclosure model you designed was never enforced; descriptions are stuffed with version archaeology that Anthropic explicitly says to remove; there are ~2,400 lines of hook shell (one synchronous on the hot path) and ~40 bespoke validators; and there are 25 slash commands while the framework you admire (superpowers) just *deleted* all of its commands. This is the textbook profile of an accretion-heavy plugin.

3. **The project already learned the single most important lesson — it just over-corrected.** The "Fork A/B honesty reset" correctly found that prose can't enforce behavior. The fix (deterministic hooks) was right in principle, but the response piled on so much bash/hook machinery that the cure became the new disease: brittle, slow, and unmaintainable. Superpowers' "gates > rules > hooks" hierarchy is the missing discipline.

So: **outdated in mechanism, sound in intent.** The rest of this document quantifies that and proposes "Mega-SDD v4 — lean core."

---

## 1. What I examined

Full plugin tree at `plugins/mega-sdd/`: all 16 `SKILL.md` files + their `references/`, all 25 commands, all 4 hook scripts, all ~40 `scripts/validate-*.sh`, the `references/` pack, `CLAUDE.md`, `plugin.json`, `marketplace.json`, the `_vendored/` superpowers skills, and the prior internal audit (`research/2026-05-27-consistency-and-capability-audit.md`).

Primary sources for "current best practice":
- Anthropic, *Skill authoring best practices* (platform.claude.com) — the canonical guidance.
- Claude Code *Plugins reference* (code.claude.com) — current component model.
- superpowers v5.1.0 (github.com/obra/superpowers) + Jesse Vincent's design essays (blog.fsck.com).

---

## 2. The numbers (context & maintenance economics)

Everything below is a direct line count from the current tree.

| Surface | Scale | Best-practice reference | Status |
|---|---|---|---|
| SKILL.md bodies (16 skills) | **8,758 lines**, avg 547 | "≤ 500 lines per SKILL.md" | **9/16 over the ceiling** |
| Largest SKILL.md | `generate-intent` **1,285** | ≤ 500 | **2.6× over** |
| Skill reference files | 10,469 lines | load on demand only | not enforced (see §3.1) |
| Worst per-invocation load | `generate-intent` 1,285 + 2,585 refs = **3,870 lines** | "every token competes" | loads ~unconditionally |
| Validator scripts (~40) | **8,302 lines** of bash | — | fragile surface (see §3.3) |
| Hook scripts (4) | **2,404 lines** (`pre-tool-use` 730, synchronous) | superpowers: **1 hook, bootstrap only** | hot-path cost (see §3.3) |
| Slash commands (25) | 1,753 lines | superpowers: **0** (deleted in 5.1) | sprawl (see §3.4) |
| `agents/` directory | **absent** | first-class CC component | gap (see §3.5) |
| `CLAUDE.md` | 375 lines, mostly retraction notes | lean contributor guide | narrative debt (see §3.6) |
| Changelog | **588 KB** (331 KB live + 257 KB archive) | — | narrative debt |
| Version of record | `plugin.json` 3.72.0 vs `marketplace.json` 1.3.0 | one source of truth | **mismatch** |

Total hand-maintained plugin surface is **~38,000 lines**. Superpowers delivers a comparable-ambition methodology in ~14 thin skills and a single bootstrap hook. That gap is the headline.

---

## 3. Audit against current guidance

### 3.1 Skills are 2–2.6× oversized, and the fix you designed was never switched on

Anthropic's guidance is explicit and quantitative: *"Keep SKILL.md body under 500 lines"* and *"the context window is a public good… once Claude loads it, every token competes."* The mechanism is progressive disclosure — a thin SKILL.md that points to reference files Claude reads **only when needed**.

Current state:

- 9 of 16 skills exceed 500 lines: `generate-intent` 1,285, `execute-bolts` 1,189, `generate-units` 903, `orchestrate-flow` 771, `scan-codebase` 723, `detect-drift` 669, `bind-codebase` 591, `resolve-oq` 561, `diff-vault` 522.
- You *did* design the correct fix — the **3-tier context model** (HOT/SPECIALIST/COLD) plus `skill-tier-manifest.yaml`. But `references/3-tier-context-model.md` states plainly: *"Iter 64 ships the DECLARATIONS only. Skill bodies in Iter 64 still load all refs unconditionally as before. Lazy-loading enforcement = Iter 66."* — and Iter 66 was then **parked as "Fork-B-future."**

So the single most expensive problem in the plugin (per-turn context cost) was correctly diagnosed, a fix was specified, and the fix was shelved. When `generate-intent` triggers, it can pull ~3,870 lines into context in one shot. That is the opposite of how skills are meant to work, and it directly undercuts your own economics track (which memory says is the current priority).

### 3.2 Descriptions carry version archaeology — a double violation

Skill metadata (`name` + `description`) is the **only** part of every skill that is *always* in context. Anthropic says descriptions should state *what it does and when to use it*, third person, and explicitly: **"Avoid time-sensitive information."** superpowers goes further — description should say **only when to use it, never what it does**, because Claude will sometimes follow the description instead of reading the skill.

Current descriptions are the inverse. Example (`generate-intent`):

> "…(v1.3+, Iter 1) OQs carry `category`… (v1.4+, Iter 2) Auto-classifier… (v1.14+, Iter 35) `--phase=N` flag…"

This is changelog text living in the always-loaded system prompt. It violates "concise," violates "no time-sensitive info," and burns context on every session for every skill. The `using-mega-sdd` and `execute-bolts` descriptions have the same problem. **Every "vN+, Iter N" string in a description should be deleted.**

### 3.3 Hooks: the right lesson, the wrong dosage

The "Fork A/B reset" in `CLAUDE.md` is, genuinely, good engineering judgment: *"the failure mode was 'prose tells the model to invoke a script; model may or may not.' The fix is moving the trigger out of prose: hooks fire deterministically."* That is correct and aligned with the platform.

But the response over-corrected into a second failure mode — **enforcement sprawl**:

- ~40 validator scripts, **8,302 lines of bash**, plus **2,404 lines** of hook shell across 4 files.
- `pre-tool-use` is **730 lines with 31 embedded Python blocks and 18 conditional "branches," registered `async: false`** — i.e. it runs **synchronously on every `Skill` and `Bash` tool call**. Every branch is latency and a failure surface on the hot path. A crash or a slow branch there taxes *every* tool call in the session.
- This is precisely the surface superpowers refuses to build. Their stated hierarchy is **rule → gate → hook**: prefer a self-evaluated blocking "gate" in skill prose; reserve real hooks for the few things that *must* be machine-deterministic. They ship **one** hook (SessionStart bootstrap) and zero PreToolUse/PostToolUse enforcement.

The lesson is not "delete all hooks." It's that deterministic enforcement should be **rare and load-bearing** — reserved for the 1–3 invariants that are both critical and genuinely un-promptable (your binding-conflict gate is the legitimate case). Everything else currently wired into hooks/validators is either advisory (belongs in a single user-invoked `/analyze`, the Spec Kit pattern your own recovery map already flags) or should be a gate in prose.

### 3.4 Command sprawl (25 commands)

Skills already auto-discover and Claude can invoke them by context; a slash command is just a thin manual entry point. 25 of them (1,753 lines) is a maintenance and discoverability tax, and most duplicate a skill trigger. The framework you admire concluded the same thing harder: superpowers **deprecated commands in 5.0 and removed them entirely in 5.1**, routing everything through skill auto-trigger. You don't have to go to zero, but ~25 → ~5 (the pipeline verbs only) is the right order of magnitude.

### 3.5 No first-class subagents

Claude Code's current component model is **skills, agents, hooks, MCP, LSP, monitors.** `agents/` is a first-class directory: a subagent is a named `.md` with its own prompt and (optionally) its own model. Mega-SDD has **no `agents/` directory**. The subagent prompts that *do* exist (the implementer / spec-reviewer / code-quality-reviewer prompts, the wave-extraction dispatch) live as vendored markdown or inline strings inside giant skills. Promoting them to real `agents/*.md` is both idiomatic and lets you set cheap models per role — exactly the "cheapest capable model" economics superpowers uses for subagent-driven development.

### 3.6 Narrative & accretion debt

- **`CLAUDE.md` (375 lines)** is mostly a museum of retracted claims ("RETRACTED at Iter 67.5," "PARKED Fork-B-future") and dual-EP classifier rules that the same file says aren't enforced. A contributor — human or AI — must read ~900 words of iteration history before touching anything. Anthropic's "avoid time-sensitive information / old patterns go in a collapsed section" guidance applies to `CLAUDE.md` too.
- **588 KB of changelog** in the working tree. Git already is the changelog.
- **80+ "Iter" numbers** are load-bearing in prose across skills, refs, and descriptions. They encode *when* something shipped, which no reader needs at runtime.
- **Version mismatch** (3.72.0 vs 1.3.0) means there is no single source of truth for "what version is this."

None of this changes behavior, but all of it is cognitive weight that makes the system feel — and audit as — older and more fragile than its ideas deserve.

---

## 4. What the project gets RIGHT (protect these)

A radical change must not be a hatchet job. These are genuine assets, several unmatched by the benchmarks:

1. **Spec↔code grounding (the binding phase).** Claim-by-claim CONFIRMED / CONFLICT / OQ verdicts with codebase anchors + an Implementation State Map. No other framework does this. This is the moat.
2. **Anti-hallucination citation discipline.** sha256-stamped `.citation-map.json`, `[Pending — X]` instead of fabrication. The strongest doc-layer anti-hallucination mechanism in the comparison set.
3. **The "prose doesn't enforce" insight itself.** Hard-won and correct. The redesign keeps deterministic enforcement — just *much* less of it, aimed only where it's load-bearing.
4. **The binding-conflict hard gate.** A real, legitimate use of PreToolUse blocking: don't let units/bolts proceed over an unresolved spec/code conflict. Keep this one.
5. **Halt taxonomy (C1/C2/C3) and mutability tiers ([LOCKED]/[INTENT]/[ARTIFACT]).** Strong domain vocabulary for rebuild scenarios; keep as design vocabulary, slimmed.
6. **Battle-tested domain knowledge.** The validators encode real lessons from the Bank Mega TF-Import pilot. The *knowledge* is valuable even where the *delivery mechanism* (40 bash scripts) is wrong.

---

## 5. What superpowers teaches (and what to adopt)

superpowers v5.1.0 is the right north star for *mechanism* (not for dropping your grounding moat — it has none). Adopt:

- **Thin skills + enforced progressive disclosure.** Word budgets: getting-started/anchor skills < 150–200 words; other skills target < 500 lines hard. Heavy material → reference files, loaded on demand. No `@`-links (they force-load).
- **"Gates > rules > hooks."** Default to a self-checked gate in prose; escalate to a hook only for un-promptable invariants. Invert today's ratio.
- **Description = when, not what.** Strip the archaeology; one or two present-tense sentences of trigger conditions.
- **Subagent-driven execution as the default.** Fresh-context subagent per task, two-stage review (spec-compliance then code-quality), cheapest capable model per role. You already vendor this — promote it to first-class `agents/`.
- **Skill = technique, not narrative.** Skills describe a reusable method, not the story of how TF-Import got fixed once.
- **TDD-for-skills.** Before adding/keeping a skill: show the agent failing the task *without* it (RED), write the minimal skill (GREEN), close loopholes (REFACTOR). This is the antidote to accretion — it forces deletion of anything that doesn't earn its tokens.
- **Kill commands; lean on auto-trigger.**

---

## 6. The radical redesign — "Mega-SDD v4: lean core"

The shape: **same pipeline, same moat, a fraction of the surface.** Concrete targets, not vibes.

### 6.1 Skills
- **Every SKILL.md ≤ 500 lines, hot-path skills ≤ ~200.** Move procedure detail into `references/*.md` that load on demand. Target: cut the 8,758-line skill body total by **50–65%**.
- **Enforce the 3-tier model you already designed** (turn on what was parked): SKILL.md = HOT router; everything else SPECIALIST/COLD, pulled by step or grep. This is a context-economics win and serves the in-flight economics track directly.
- **Rewrite all 16 descriptions** to when-not-what, zero version strings.
- **Consider consolidation:** `diff-vault` + `detect-drift` are both "reconcile vault vs. a changed reality" — candidate merge. `analyze` becomes the single consistency surface (below). Net target ~12–13 skills.

### 6.2 Enforcement (the big one)
- **One consolidated `/mega-sdd:analyze`** runs all consistency checks and emits one report (Spec Kit `/analyze` pattern — already named as a gap in `fork-a-recovery-map.md`). This absorbs the bulk of the ~40 validators as internal passes, user-invoked, off the hot path.
- **Keep 1–3 true hook-enforced invariants only** — chiefly the binding-conflict gate. Demote everything else from PreToolUse to either `/analyze` or a prose gate.
- **Collapse 4 hook scripts → 1 thin dispatcher**; make the surviving PreToolUse branch tiny and fast (it should read one state file and decide, nothing more). Target: hook shell **2,404 → < 400 lines**; validator bash **8,302 → < 2,500** behind `/analyze`.

### 6.3 Subagents
- Add `agents/`: `implementer.md`, `spec-reviewer.md`, `code-quality-reviewer.md`, `domain-extractor.md` (wave worker). Assign cheap models to mechanical roles. Make `execute-bolts` and `extract-intelligence` *dispatch* these rather than carry 1,000+ inline lines.

### 6.4 Commands
- **25 → ~5:** `auto`, `analyze`, and the few pipeline verbs that genuinely need a manual entry point. Everything else rides skill auto-trigger.

### 6.5 Narrative reset
- New lean `CLAUDE.md`: contracts + invariants only; retractions/iteration history → a single collapsed "history" appendix or just git.
- Truncate `CHANGELOG.md` to recent; archive the rest out of the tree.
- Purge "Iter N / vN+" strings from all runtime prose (skills, descriptions, refs).
- One version source of truth; fix the 3.72.0/1.3.0 mismatch; reset to a clean **v4.0.0**.

### 6.6 Target profile

| Surface | Now | v4 target |
|---|---|---|
| SKILL.md total | 8,758 | ~3,500 |
| Largest skill | 1,285 | ≤ 500 |
| Hook shell | 2,404 (4 files) | < 400 (1 file) |
| Validators | 8,302 (~40, hot-path) | < 2,500 behind `/analyze` |
| Commands | 25 | ~5 |
| `agents/` | 0 | 4 |
| Always-loaded description bloat | high | zero version strings |

---

## 7. How to get there (migration strategy)

**Recommendation: strangler refactor on a clean `v4` branch — not a from-scratch rewrite.** Rationale: the moat logic (binding contracts, halt taxonomy, the validators' domain knowledge) is battle-tested on a real pilot; a zero-base rewrite risks losing that. But it must be aggressive-deletion refactor, not gentle editing, or the accretion returns.

Phase it so each step ships independently and the riskiest change is last:

- **Phase 1 — Skill slimming + turn on progressive disclosure.** Highest ROI, lowest risk, and it *is* economics work (directly serves the current priority track). Rewrite descriptions here too. No behavior change, large context-cost drop.
- **Phase 2 — Enforcement consolidation.** Build `/mega-sdd:analyze`; move ~37 validators behind it; cut hooks to the 1–3 load-bearing invariants + 1 dispatcher. This is where the fragility leaves the hot path.
- **Phase 3 — Subagents + command cull.** Promote `agents/`; wire `execute-bolts`/`extract-intelligence` to dispatch; drop ~20 commands.
- **Phase 4 — Narrative reset + v4.0.0 cut.** Clean `CLAUDE.md`, archive changelog, purge iteration strings, fix versioning.

Validate each phase with the discipline the project already values: real-run on the TF-Import artifacts (`tests/fixtures/code-delivery/**`), and a TDD-for-skills pressure test before keeping any slimmed skill.

---

## 8. Decisions for you (business gates)

The technical path is clear and is mine to drive; these are the judgment calls that are yours:

1. **Scope of radical:** full v4 lean-core (all 4 phases) vs. Phase 1–2 only (slim + de-risk enforcement, defer the rest)?
2. **Sequencing vs. the economics track:** Phase 1 *is* economics work — fold it into the current track, or run v4 as its own track?
3. **Moat boundary:** confirm the non-negotiables to preserve byte-for-byte (binding verdicts, citation discipline, binding-conflict gate) so the deletion pass can be ruthless about everything else.

---

## Appendix — Sources

- Anthropic, *Skill authoring best practices* — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices ("≤ 500 lines"; "context window is a public good"; "avoid time-sensitive information"; description = what + when, third person, ≤ 1024 chars; references one level deep).
- Claude Code, *Plugins reference* — https://code.claude.com/docs/en/plugins-reference (components: skills, agents, hooks, MCP, LSP, monitors; skills auto-discovered and Claude-invocable).
- superpowers v5.1.0 — https://github.com/obra/superpowers ; design essays https://blog.fsck.com/2026/04/07/rules-and-gates/ , https://blog.fsck.com/2026/05/04/superpowers-5.1/ (one bootstrap hook; gates > rules > hooks; commands removed; subagent-driven default; description = when-not-what; TDD-for-skills).
- Internal: `plugins/mega-sdd/CLAUDE.md` (Fork A/B reset), `references/3-tier-context-model.md` (lazy-load declared-not-enforced), `research/2026-05-27-consistency-and-capability-audit.md` (prior benchmark), line counts from the live tree (2026-06-04).
