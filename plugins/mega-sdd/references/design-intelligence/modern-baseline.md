# Modern UI Baseline — the floor every generated view stands on

The injectable digest for UI-bearing bolts (execute-bolts design slice, per
`context-enrichment.md §Design slice`). It is the GREENFIELD floor: when a
starterkit's scanned template exists, the template is authoritative and this
file is at most gap-fill. Distilled from `style-principles.md` + `ux-rules.md`
(ui-ux-pro-max distillation, see ATTRIBUTION.md) and aligned with Anthropic's
frontend-design philosophy: production-grade, distinctive, never default-browser
or generic-AI aesthetics.

## Non-negotiables (inject verbatim into UI bolt prompts)

1. **Design tokens first.** Define/extend a token layer (CSS custom properties
   or the framework's token mechanism) for color, spacing, radius, and type
   scale — then USE it. Hardcoded one-off hex/px values scattered per element
   are the #1 "kuno" tell. The vault `design_system.palette` is the source for
   color tokens; never invent a second palette.
2. **Spacing system, not ad-hoc gaps.** 4/8px scale (4, 8, 12, 16, 24, 32, 48,
   64). Consistent vertical rhythm; whitespace is a design element — cramped
   tables-of-inputs read as 1995.
3. **Typographic scale.** One pairing (per `design_system.typography` /
   `typography-pairings.md`), loaded properly; a modular scale (e.g. 1.25) for
   h1→small; line-height ≥1.5 body; max line length ~65–75ch. Never default
   Times/system-serif walls of text.
4. **Layout is composed, not stacked.** A real page shell: constrained content
   width (e.g. max-w + centered), header/nav, generous section spacing,
   CSS grid/flex for structure. Responsive at 375px AND desktop — mobile is a
   layout, not an afterthought.
5. **Interactive states exist.** Every button/input/link has hover, focus
   (VISIBLE focus ring), active, and disabled states. Transitions are subtle
   (~150–250ms ease) and purposeful — no state changes that just snap.
6. **Feedback states exist.** Loading (skeleton or spinner with label), empty
   ("no appointments yet" + the action to create one), and error (inline,
   human language, recovery path) — for every async surface. A blank div while
   fetching is a defect.
7. **Forms are designed.** Labels above inputs, visible focus, inline
   validation messages near the field, primary action visually dominant,
   destructive actions visually distinct + confirmed via the project's dialog
   idiom (never native `alert`/`confirm`).
8. **Accessibility floor = WCAG AA** (or the vault `design_system.a11y_level`):
   contrast ≥4.5:1 body text, semantic landmarks (header/nav/main), every
   input labelled, keyboard-reachable interactive elements, alt text.
9. **Tables are for data — styled.** Density options, right-aligned numerics,
   formatted money/dates, row hover, sticky header on long lists; on mobile,
   collapse to cards or allow horizontal scroll deliberately.
10. **Distinctive, not generic.** Commit to the vault's chosen style (e.g.
    "Accessible & Ethical + Minimalism") and express it in 2–3 memorable moves
    (a signature accent usage, a distinctive radius/elevation language, a
    typographic personality) — avoid the interchangeable bootstrap-default and
    purple-gradient-AI looks alike.

## Ceiling moves (the floor is NOT the goal — clear it, then do these)

The non-negotiables above are the FLOOR: passing them means "not broken, not
default-browser, accessible." It does NOT mean done. A view that satisfies all
10 and stops there reads as **correct but generic** — a lone centered card on an
empty page, flat hierarchy, no personality. Field finding (clinic-project): the
floor passed; the result was still "basic banget." Every UI bolt MUST also make
the page feel like a designed product:

1. **Page furniture.** A real branded header (logo/wordmark + primary nav) and a
   footer — not a bare `<h1>` over a centered card. The app should feel like it
   has a frame, not float in whitespace.
2. **Composition, not a lone card.** Fill the width with intent: a two-column
   layout (primary action + a supporting panel — summary, help, illustration,
   trust signals), a hero on landing/empty pages, or a content grid. A single
   centered 480px card on a 1280px page is the #1 "basic" tell.
3. **Iconography.** Use an icon set (lucide, heroicons, the stack's idiom) for
   actions, nav, status, and empty states. Icon + label, never icon-only for
   primary actions. Plain-text-only UIs read as unfinished.
4. **Visual hierarchy with depth.** More than one type size and weight in play;
   section headers, supporting text, and metadata visually distinct. Use
   elevation/borders/background tints to group — not everything on one flat plane.
5. **A signature.** Commit to 2–3 memorable expressions of the chosen style: a
   distinctive accent usage, a consistent radius/elevation language, an
   illustrative or photographic moment, a confident empty-state. Pick the style's
   personality and show it — don't render the interchangeable default.
6. **Motion with purpose.** Entrance/hover/transition micro-interactions
   (subtle, 150–250ms) on the primary surfaces — buttons, cards, step changes.
7. **Density that fits the product.** A clinical tool, a consumer booking flow,
   and a dashboard have different densities — match the product, don't ship the
   same sparse centered form for everything.

A design-reviewer judging a UI bolt treats "floor met, ceiling absent" as an
**Important** finding (generic/undesigned), not a pass. When a rendered
screenshot of the running view is available, judge the ceiling from the render —
the floor is provable from code, the ceiling usually is not.

## Anti-kuno tells (a match = defect; mirror of the ui-quality gate's spirit)

- Unstyled default browser controls / default link blue / default focus-less buttons.
- Layout via nested `<table>` or `<br>` stacks; no page shell (content hugging the left edge full-width).
- No spacing system: arbitrary `margin: 3px 7px 11px`, cramped forms.
- System-default typography wall (no scale, no pairing, line-height 1).
- Raw `<input>` rows with placeholder-as-label, no validation states.
- Native `alert()`/`confirm()`; raw URL text as actions ("click here").
- Unformatted data: ISO timestamps shown raw, unformatted money, raw FK ids.
- Zero hover/focus/disabled treatment; zero loading/empty/error states.
- Inline `style=` attributes everywhere instead of the token layer.

## How the slices compose (precedence)

```
starterkit scanned template     → AUTHORITATIVE (tokens/layout/idioms win)
vault design_system             → the chosen style+palette+type for greenfield
style-principles[style]         → traits + CSS keywords + anti-patterns of that style
ux-rules.md (a11y + UX rows)    → behavioral floor
THIS FILE                       → the structural floor when nothing above exists
```

A UI bolt prompt missing ALL of the above produced the audited "kuno" output —
the design slice in `context-enrichment.md` exists so that can no longer happen.
