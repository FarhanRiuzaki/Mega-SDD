## Design system (UI-bearing unit — per context-enrichment.md §Design slice)


Design system: style=clinical, trustworthy, anti-generic — brand color on high-signal elements only · palette=primary teal-700 #0E7490 (white foreground, 5.36:1); accent/success green-700 #15803D (5.02:1); raw #0891B2 / #16A34A only for fills, charts and icon accents · typography=humanist sans body with a real type scale; optional serif display headers · a11y=WCAG 2.2 AA — source: vault.json design_system (provenance excluded, audit-only)
UX floor: (ux-rules.md — Accessibility/Forms/Feedback rows)
  - Accessibility/Color Contrast: DO Minimum 4.5:1 ratio for normal text; DON'T Low contrast text [High]
  - Accessibility/Color Only: DO Use icons/text in addition to color; DON'T Red/green only for error/success [High]
  - Accessibility/Alt Text: DO Descriptive alt text for meaningful images; DON'T Empty or missing alt attributes [High]
  - Accessibility/Heading Hierarchy: DO Use sequential heading levels h1-h6; DON'T Skip heading levels or misuse for styling [Medium]
  - Accessibility/ARIA Labels: DO Add aria-label for icon-only buttons; DON'T Icon buttons without labels [High]
  - Accessibility/Keyboard Navigation: DO Tab order matches visual order; DON'T Keyboard traps or illogical tab order [High]
  - Accessibility/Screen Reader: DO Use semantic HTML and ARIA properly; DON'T Div soup with no semantics [Medium]
  - Accessibility/Form Labels: DO Use label with for attribute or wrap input; DON'T Placeholder-only inputs [High]
  - Accessibility/Error Messages: DO Use aria-live or role=alert for errors; DON'T Visual-only error indication [High]
  - Accessibility/Skip Links: DO Provide skip to main content link; DON'T No skip link on nav-heavy pages [Medium]
  - Forms/Input Labels: DO Always show label above or beside input; DON'T Placeholder as only label [High]
  - Forms/Error Placement: DO Show error below related input; DON'T Single error message at top of form [Medium]
  - Forms/Inline Validation: DO Validate on blur for most fields; DON'T Validate only on submit [Medium]
  - Forms/Input Types: DO Use email tel number url etc; DON'T Text input for everything [Medium]
  - Forms/Autofill Support: DO Use autocomplete attribute properly; DON'T Block or ignore autofill [Medium]
  - Forms/Required Indicators: DO Use asterisk or (required) text; DON'T No indication of required fields [Medium]
  - Forms/Password Visibility: DO Toggle to show/hide password; DON'T No visibility toggle [Medium]
  - Forms/Submit Feedback: DO Show loading then success/error state; DON'T No feedback after submit [High]
  - Forms/Input Affordance: DO Use distinct input styling; DON'T Inputs that look like plain text [Medium]
  - Forms/Mobile Keyboards: DO Use inputmode attribute; DON'T Default keyboard for all inputs [Medium]
  - Feedback/Loading Indicators: DO Show spinner/skeleton for operations > 300ms; DON'T No feedback during loading [High]
  - Feedback/Empty States: DO Show helpful message and action; DON'T Blank empty screens [Medium]
  - Feedback/Error Recovery: DO Provide clear next steps; DON'T Error without recovery path [Medium]
  - Feedback/Progress Indicators: DO Step indicators or progress bar; DON'T No indication of progress [Medium]
  - Feedback/Toast Notifications: DO Auto-dismiss after 3-5 seconds; DON'T Toasts that never disappear [Medium]
  - Feedback/Confirmation Messages: DO Brief success message; DON'T Silent success [Medium]
  - Accessibility/Motion Sensitivity: DO Respect prefers-reduced-motion; DON'T Force scroll effects [High]
Modern baseline (non-negotiables — the FLOOR):
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
Ceiling moves (clear the floor, then DO these — a floor-only view is "basic/generic"):
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
Anti-kuno tells (a match in your output = defect):
- Unstyled default browser controls / default link blue / default focus-less buttons.
- Layout via nested `<table>` or `<br>` stacks; no page shell (content hugging the left edge full-width).
- No spacing system: arbitrary `margin: 3px 7px 11px`, cramped forms.
- System-default typography wall (no scale, no pairing, line-height 1).
- Raw `<input>` rows with placeholder-as-label, no validation states.
- Native `alert()`/`confirm()`; raw URL text as actions ("click here").
- Unformatted data: ISO timestamps shown raw, unformatted money, raw FK ids.
- Zero hover/focus/disabled treatment; zero loading/empty/error states.
- Inline `style=` attributes everywhere instead of the token layer.
