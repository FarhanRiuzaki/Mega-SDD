# SP3 Fork A vs B Decision Inputs — Non-Telemetry (Research-Only)

> Background research dispatched 2026-05-26 day-0 of SP2 soak window.
> NOT a decision yet — input gathering for SP3 prerequisite per spec §5.
> Telemetry inputs (Iter 68 soak data — skill hit freq, token-per-skill, tier accuracy, activation accuracy) intentionally OUT OF SCOPE here.

## Methodology

- Surveyed host runtime documentation pages (Claude Code Skills, VSCode Chat Participant API, VSCode Language Model Tool API, VSCode agent memory tool, Cline SDK, Cursor plugin spec) via WebFetch + WebSearch (May 2026).
- Cross-checked marketplace install counts, GitHub star metrics, and partner-plugin presence to gauge ecosystem maturity.
- Mapped each capability mega-sdd relies on (skill body execution, scoped memory, halt/resume, handoff contracts, plugin distribution, tool sandboxing) against each candidate host.
- Pulled regional adoption signals for SEA / Indonesia developer market (Iter 55 user context).
- All findings dated May 2026. Cite-or-mark as INFERRED — no primary mega-sdd telemetry was used.

---

## Finding 1: Host runtime capability gap matrix

Legend: **FULL** = first-class API; **PARTIAL** = workable but requires extension-side scaffolding; **NONE** = surface absent; **PREVIEW** = Microsoft / Google preview channel, not GA.

| Capability | Claude Code | Cline (v3.81+, @cline/sdk) | Cursor (3.0) | VSCode Agent Mode | Antigravity 2.0 |
|---|---|---|---|---|---|
| Skill / agent body execution from markdown | **FULL** — SKILL.md with YAML frontmatter, progressive disclosure (L1 metadata → L2 body → L3 resources), filesystem-based, loaded via bash | **PARTIAL** — `@cline/sdk` exposes plugin lifecycle hooks + custom tools; skill-as-markdown not native, must wrap | **PARTIAL** — supports SKILL.md + AGENTS.md + .mdc rules (can load Claude-style skill resources per Feb 2026 update) | **PARTIAL** — chat participants own conversation, can call LM tools, but markdown-as-prompt is extension responsibility | **PARTIAL** — Antigravity SDK + Managed Agents support subagents; skill packaging model is Antigravity-flavored, not Claude-Skill-compatible |
| Memory persistence (cross-session, scoped) | **FULL** — subagent persistent memory field, ~/.claude/skills (user) + .claude/skills (project), claude-mem ecosystem (SQLite-backed) | **FULL** — Memory Bank (projectbrief/productContext/activeContext/systemPatterns/techContext/progress.md), MCP-server-backed, durable runtime | **PARTIAL** — Project/Team/User Rules + AGENTS.md (file-based, no built-in compaction-survivor memory) | **FULL** (1.110+, GA Mar 2026) — built-in memory tool, 3 scopes (User / Repository / Session), first 200 lines auto-loaded per session | **PARTIAL** — Managed Agents have persistent state across multi-turn sessions; cross-session local memory model less documented |
| Halt protocol equivalent (structured pause/resume + next_action) | **PARTIAL** — Skills can return narrative halts; no first-class typed halt envelope; bolt halt protocol is mega-sdd-owned | **PARTIAL** — durable runtime survives UI restart, sessions can move across surfaces (closest to halt-survive semantics); no typed next_action schema | **NONE** documented — agents can pause but no structured resume hint surface | **PARTIAL** — proposed API `chat.agent.onPermissionRequest` (issue #302362) gives programmatic permission-request handling; not GA, no structured next_action | **PARTIAL** — multi-agent orchestration + scheduled background tasks imply pause/resume, but Google-proprietary contract |
| Handoff contract / typed schemas | **NONE** native — Claude Code Skills don't define an inter-skill handoff envelope; mega-sdd owns this concept | **PARTIAL** — SDK plugin lifecycle hooks can be used to enforce schemas; nothing prescriptive | **NONE** native | **PARTIAL** — tools return structured results; no handoff-between-participants contract | **PARTIAL** — Managed Agents API has structured multi-turn state; not portable |
| Plugin/extension marketplace + distribution | **FULL** — claude-plugins-official (170 plugins, 327k stars as of May 2026), claude-plugins-community, claudemarketplaces.com directory, partner plugins from GitHub/Playwright/Supabase/Figma/Vercel/Linear/Sentry/Stripe/Firebase | **PARTIAL** — VSCode Marketplace (saoudrizwan.claude-dev, 5M+ installs, 61k stars); plugin packaging via SDK newer & less established | **FULL** — official cursor/plugins spec (SKILL.md + .mdc + MCP); Cursor 3.0 Agents Window for parallel agents; proprietary | **FULL** — VSCode Marketplace (largest single dev-tool marketplace); chat participants distribute as standard VSCode extensions | **PARTIAL** — Antigravity SDK newly launched May 2026; ecosystem nascent |
| Tool execution sandboxing | **FULL** — VM environment with filesystem + bash + code exec; permissioned; settings.json gating | **FULL** — auto-approval rules, tool whitelist, MCP server isolation | **FULL** — Cursor agents respect rules-as-guardrails; CLI sandbox available | **FULL** — VSCode workspace trust + permission requests; tool API has explicit consent | **FULL** — Managed Agents run in isolated Linux env per Gemini API call |
| LLM provider lock-in | **FULL Claude** (Anthropic-only) | **NONE** — bring-your-own (Anthropic, OpenAI, Google, OpenRouter, local) | **PARTIAL** — Cursor-hosted models + BYO via settings | **PARTIAL** — Copilot default; LM Chat Provider API lets extensions register providers | **FULL Gemini** (Google-only, 3.5 Flash default) |
| Multi-agent orchestration primitive | **PARTIAL** — subagents + Task tool; parallel via prompt-level coordination | **FULL** — Cline Kanban + coordinator-with-specialists, parallel across worktrees | **FULL** — Cursor 3.0 Agents Window (parallel agents across repos: local / worktree / cloud / SSH) | **FULL** (Preview) — Agents Window (preview), companion app (Insiders-only) | **FULL** — dynamic subagents for parallel workflows native |

### Implication for Fork A (mega-sdd LAYERS over host runtimes)

- **Claude Code is the only host with full skill+memory+marketplace stack already aligned to mega-sdd's mental model.** Today's mega-sdd is essentially a Claude Code plugin because Claude Code's surfaces line up 1:1 with what mega-sdd needs.
- **VSCode Agent Mode (post-1.110) is the strongest cross-host target.** Memory tool went GA Mar 2026 with the same 3-scope model mega-sdd already uses (user/project/session ≈ user/project/vault). Chat Participant API can host skill bodies, language-model tools cover tool exec, marketplace covers distribution. Halt protocol + handoff contract remain mega-sdd's responsibility (which is fine — that's the layer mega-sdd is selling).
- **Cline is the second-strongest target.** SDK lifecycle hooks + Memory Bank pattern + 5M+ installs + open source = highest leverage non-Claude-Code surface. Memory Bank file names overlap heavily with mega-sdd's vault concept.
- **Cursor is third.** Plugin spec is structurally compatible (already accepts Claude-style SKILL.md per Feb 2026 update) but proprietary; mega-sdd would need per-rev compatibility validation.
- **Antigravity is high-risk:** brand-new SDK (May 2026), Gemini-only, model loyalty signals not yet mature. Worth tracking, not yet worth porting.
- **Cost of Fork A grows ~linearly with host count.** Each port needs: skill-body adapter, memory-API shim, halt-envelope shim, distribution package, CI matrix. Realistic Fork A v4.0.0 scope = Claude Code (existing) + VSCode Agent Mode + Cline = 3 surfaces. Cursor + Antigravity = follow-on minor releases.

### Implication for Fork B (mega-sdd OWNS its own runtime)

- **Cline already won this race.** Cline SDK launched May 2026, open-sourced, powers Cline-the-extension across VSCode + JetBrains + CLI. Building a parallel runtime competes head-on with a 5M-install incumbent that just open-sourced its harness.
- **Antigravity SDK is Google's Fork-B answer.** Standalone desktop + CLI + SDK + Managed Agents API — published May 19, 2026.
- **Fork B differentiation has to be SDD-specific.** mega-sdd's edge is anti-halu + binding + units-as-bolts. A pure runtime fork inherits a runtime-quality battle (LLM dispatch loop, permission UX, terminal control) that Cline / Anthropic / Google are already racing on.
- **Cost of Fork B is roughly constant** in host count (one runtime, one UI) but high upfront and high ongoing-maintenance vs hosts that ship features (memory compaction, parallel orchestration, browser tools) every release.

---

## Finding 2: User base composition signals

### Where mega-sdd users live today

- **Strong signal: Claude Code-first.** mega-sdd v3.45.0 ships as `plugins/mega-sdd/` in a Claude Code plugin layout (CLAUDE.md confirms). Recent commits (Iter 49-53) talk about glossary anchoring, vault.json advisory lock, predictive checks — all Claude-Code-runtime-assumed.
- **Indonesian context locked in by Iter 55 user.** CLAUDE.md memory directives are bilingual (Indonesian + English); skill triggers explicitly list Indonesian paraphrases ("pecah PRD", "siapkan context buat AI dev", "rebuild di stack baru", "jalanin unit"). User base presumption is Indonesian / SEA dev market with Claude Code or Claude.ai adopted.

### Indonesian / SEA market signals (May 2026)

- **95% of SEA developers (Indonesia, Malaysia, Singapore, Thailand, Philippines, Vietnam, India) use AI tools weekly**; >50% keep an AI assistant open at all times (Second Talent / IT Brief Asia survey of 600+ devs).
- **APAC = 40.7% of global vibe-coding tool usage.** SEA is the fastest-growing AI-code-tools region.
- **Indonesia software dev market: EUR 5.88B projected by 2030, 5.34% CAGR.** $542.9M AI investment 2020-2024 (141% growth).
- **Implication:** mega-sdd's natural user is an SEA developer who has already adopted *some* AI coding tool — not necessarily Claude Code. Multi-host reach matters for capturing the addressable market.

### Plugin ecosystem comparison (raw install counts, May 2026)

| Surface | Approx. user base | Mega-sdd presence today |
|---|---|---|
| Claude Code | Anthropic-curated marketplace, ~170 official plugins, partner plugins from major dev-tool vendors | Native (this repo) |
| Cline VSCode ext. | 5M+ installs, 61k stars (saoudrizwan.claude-dev), 8M+ developers per Cline marketing | None |
| Cursor | Closed-source IDE, large user base (Cursor 3.0 GA), proprietary | None |
| VSCode Copilot + Agent Mode | VSCode Marketplace = largest dev-tool marketplace; agent mode 1.110+ GA Mar 2026 | None |
| Antigravity 2.0 | Brand-new May 2026, $100/mo AI Ultra tier signal | None |

### Upgrade pain tolerance

- mega-sdd shipped 53 iterations in current cycle (Iter 49 → 53 visible in git log spanning weeks/days each).
- Pattern: rapid MINOR bumps with small breaking-ish internal changes accepted by user (Iter 22 introduced mutability tier markers — schema-level change shipped same iter).
- User memory note: *"Simplification + flawless — minimum new files; whole problem in one iter; atomic synchronized commits; no 'deferred to next iter' excuses."*
- **Implication:** A v4.0.0 MAJOR breaking release would be tolerated *if* it's atomic and self-contained. A long deprecation cycle would conflict with the user's stated cadence preference. → Argues for a clean Fork choice in one v4.0.0, not a phased dual-fork.

---

## Finding 3: Distribution + ecosystem moats

### Ecosystems that compound for mega-sdd

1. **Claude Code Skills + Claude Code plugin marketplace** — mega-sdd's existing home. Every Skill mega-sdd ships gets progressive-disclosure for free; every plugin gets free marketplace distribution. Mega-sdd's "atomic skill markdown body" model is a 1:1 fit with Claude Code SKILL.md. *Pure compounding.*
2. **VSCode Marketplace** — mega-sdd-as-VSCode-extension would inherit the largest dev-tool distribution channel. Memory tool, language-model tool, chat participant APIs all stable by May 2026. Compounds with the moat VSCode itself has.
3. **MCP servers** — both Cline Memory Bank and Cursor use MCP; mega-sdd could expose its vault as an MCP server and reach Cline + Cursor + VSCode + Claude Code in one surface. *Highest compounding-per-dollar candidate.*

### Zero-sum / draining ecosystems

1. **Antigravity** — Gemini-locked, brand-new, 1 week old. Investment here doesn't transfer.
2. **Cursor proprietary fork** — porting mega-sdd to Cursor's plugin spec helps Cursor users but doesn't transfer back to Claude Code or VSCode.
3. **Own-runtime (Fork B)** — every hour spent on LLM dispatch / permission UI / terminal control is an hour not spent on SDD-specific edges (binding, units, drift detection). Pure zero-sum vs Cline.

### Spec-Driven Development competitive landscape (May 2026)

mega-sdd is now competing in a crowded SDD space — *all* major coding agents shipped their own flavor:

- **GitHub Spec Kit** — 93k+ stars, v0.8.7, 30+ AI agent integrations, 4 phases (Specify/Plan/Tasks/Implement). Open source. *Biggest SDD competitor.*
- **AWS Kiro** — agentic IDE built around SDD from day 1.
- **Claude Code skills + Anthropic's own pre-built skills** — generic, not SDD-specific.
- **Cursor SDD via AGENTS.md + .mdc rules** — built-in.
- **OpenSpec, BMAD, Tessl, Google Antigravity SDD flows** — all shipping.

mega-sdd's stated edges (binding-as-validation-gate, units-as-PR-sized-bolts, anti-halu via primary/secondary ground truth, mode A vs B vault generation, KB extraction for legacy rebuilds, halt protocol, advisory locks) are still *differentiated*, but the moat narrows every quarter.

**Implication for fork choice:**

- **Fork A (layer over hosts)** = pitch mega-sdd as "the SDD layer that works on Claude Code + VSCode + Cline" — competes on portability and SDD-depth, not runtime.
- **Fork B (own runtime)** = pitch mega-sdd as "the SDD IDE" — competes head-on with Kiro, GitHub Spec Kit + Copilot, Antigravity. Runtime quality dominates the buying decision.

---

## Open questions (still telemetry-blocked, awaiting Iter 68 soak)

- **OQ-T1: Per-skill hit frequency distribution.** If 80% of mega-sdd value sits in <10 skills, Fork A is cheap (port 10 skills × 3 hosts). If hit frequency is flat across 60+ skills, Fork A cost explodes.
- **OQ-T2: Tier classification accuracy.** Tier-misclassification rate determines whether mega-sdd's correctness rails actually deliver — if accuracy <85%, the layer's value prop is weak regardless of fork.
- **OQ-T3: Activation accuracy on Indonesian paraphrases.** Validates the SEA-market thesis. If activation triggers reliably on "pecah PRD" / "siapkan context", multi-host is justified. If only English triggers work, ecosystem hopping doesn't help.
- **OQ-T4: Token-per-skill on real users.** Determines whether Fork B's "own runtime" pitch (control over context, parallel dispatch, cost optimization) is even economically meaningful vs Fork A's hosted-runtime delegation.
- **OQ-T5: Cross-session memory promotion frequency.** If users actually promote project→user memory frequently, Fork B owning the memory store has real value. If promotion is rare, host-provided memory APIs (Claude Code, VSCode 1.110+) are sufficient.

---

## Recommendation framing (NOT a decision)

### When Fork A is preferable

- mega-sdd's value is in the spec-and-binding layer, not the runtime layer.
- Iter 68 telemetry shows: limited skill set carries the value (Pareto), classification accuracy ≥ acceptable threshold, token cost is dominated by skill bodies (not dispatch overhead).
- User base shows multi-host demand (telemetry signal: requests mentioning "VSCode" / "Cursor" / "Cline" in user memory notes).
- Strategic priority = reach (capture SEA developer market across whatever IDE they already adopted).

### When Fork B is preferable

- mega-sdd's value requires runtime control mega-sdd can't get from host APIs (e.g., halt protocol requires structured next_action that no host offers natively; memory model requires features no host ships).
- Iter 68 telemetry shows: hosts' built-in memory + tool APIs leak / drop the kinds of state mega-sdd needs (e.g., predictive-check state, advisory lock state).
- Strategic priority = SDD depth and product-led differentiation (compete head-on with Kiro / GitHub Spec Kit by owning the experience).
- Willingness to commit 2-3 years of runtime engineering on top of SDD engineering.

### Hybrid framing (NOT in spec, but mentioned for completeness)

A *Fork A primary + Fork B optional CLI* split is technically feasible:
- v4.0.0 = VSCode extension (Fork A, layered on Agent Mode + memory tool); skill bodies portable from Claude Code with thin adapter.
- v4.x = optional standalone CLI runtime (Fork B-lite) for users without any host — but this duplicates effort and contradicts the user's stated "minimum new files / one iter / no deferral" preference.
- Recommendation framing only — do not adopt without explicit user sign-off at SP3 prerequisite gate.

### Decision matrix sketch (inputs to be combined with Iter 68 telemetry)

| Signal | Pushes toward Fork A | Pushes toward Fork B |
|---|---|---|
| Skill hit Pareto: top-10 skills cover ≥80% usage | **Yes** | No |
| Tier-classification accuracy ≥85% (anti-halu working) | **Yes** (value lives in the layer) | Neutral |
| Cross-host user demand (VSCode / Cline mentions) | **Strong yes** | No |
| Host memory APIs cover mega-sdd needs (Claude Code + VSCode 1.110+) | **Yes** | No |
| Halt protocol requires hints no host can express | No | **Yes** |
| Cline SDK open-sourcing 5/2026 | **Yes** (host the runtime layer for us) | No (we'd be duplicating it) |
| Mega-sdd team size + iteration cadence (Iter 1-53 in current cycle) | **Yes** (Fork A matches cadence) | No (Fork B requires sustained runtime invest) |
| SDD competitive moat narrowing (Spec Kit + Kiro + Cursor SDD) | Neutral | **Yes** (own-IDE differentiation) |
| Indonesian / SEA market = multi-IDE | **Yes** | No |

**Net read on non-telemetry inputs alone: 7 signals push Fork A, 2 push Fork B, 1 neutral.** Telemetry inputs from Iter 68 (especially OQ-T2 and OQ-T5) could flip this if hosts turn out to leak the state mega-sdd cares about. Decision must wait for soak data.

---

## Sources

- [Claude Code Skills — Agent Skills Overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Claude Code Plugin Marketplace Guide 2026](https://www.agensi.io/learn/claude-code-plugin-marketplace-guide)
- [anthropics/claude-plugins-official GitHub](https://github.com/anthropics/claude-plugins-official)
- [Claude Code Plugins | claudemarketplaces.com](https://claudemarketplaces.com/)
- [Cline 5M installs + $1M Open Source Grant](https://cline.ghost.io/5m-installs-1m-open-source-grant-program/)
- [Cline SDK upgrade — open-source agent runtime](https://cline.ghost.io/introducing-cline-sdk-the-upgraded-agent-runtime/)
- [Cline Memory Bank docs](https://docs.cline.bot/features/memory-bank)
- [Cursor Plugins Spec — GitHub](https://github.com/cursor/plugins)
- [Cursor Docs — Agent, Rules, MCP, Skills & CLI](https://cursor.com/en-US/docs)
- [Cursor Forum — Agent Plugins feature request](https://forum.cursor.com/t/agent-plugins-isolated-packaging-lifecycle-management-for-sub-agents-skills-hooks-rules-incl-agent-md-across-cursor-ide-cli/151250)
- [VSCode Chat Participant API](https://code.visualstudio.com/api/extension-guides/ai/chat)
- [VSCode Language Model Tool API](https://code.visualstudio.com/api/extension-guides/ai/tools)
- [VSCode Agent Memory — built-in tool docs](https://code.visualstudio.com/docs/copilot/agents/memory)
- [VSCode Agents Window (Preview)](https://code.visualstudio.com/docs/copilot/agents/agents-window)
- [VS Code 1.110 — Agent Plugins, Browser Tools, Session Memory (Visual Studio Magazine)](https://visualstudiomagazine.com/articles/2026/03/04/vs-code-1-110-ships-with-agent-plugins-browser-tools-and-session-memory.aspx)
- [Microsoft/vscode issue #302362 — chat.agent.onPermissionRequest proposed API](https://github.com/microsoft/vscode/issues/302362)
- [Google Antigravity 2.0 launch (Google Developers Blog)](https://developers.googleblog.com/build-with-google-antigravity-our-new-agentic-development-platform/)
- [Google Antigravity 2.0 — MarkTechPost](https://www.marktechpost.com/2026/05/19/google-launches-antigravity-2-0-at-i-o-2026-a-standalone-agent-first-platform-with-cli-sdk-managed-execution-and-enterprise-support/)
- [I/O 2026 developer highlights (Google blog)](https://blog.google/innovation-and-ai/technology/developers-tools/google-io-2026-developer-highlights/)
- [GitHub Spec Kit — Spec-Driven Development guide (MarkTechPost)](https://www.marktechpost.com/2026/05/08/9-best-ai-tools-for-spec-driven-development-in-2026-kiro-bmad-gsd-and-more-compare/)
- [Spec-Driven Development definitive guide — BCMS](https://thebcms.com/blog/spec-driven-development)
- [AI tools widely adopted by Southeast Asia & India developers — IT Brief Asia](https://itbrief.asia/story/ai-tools-widely-adopted-by-southeast-asia-india-developers)
- [Indonesia Software Development trends — Second Talent](https://www.secondtalent.com/resources/software-development-in-indonesia/)
- [AI Coding Assistant Statistics 2026 — Second Talent](https://www.secondtalent.com/resources/ai-coding-assistant-statistics/)
- [AI Code Tools Market Report 2026 — Research and Markets](https://www.researchandmarkets.com/reports/6225896/ai-code-tools-market-report)
