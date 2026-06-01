# UI design quality heuristics (stack-agnostic)

> **Purpose.** Injected as inline context into a `ui_ux`-relevance bolt dispatch prompt
> (execute-bolts Step 4.5.b-starterkit.inject). It is the `frontend-design` bridge as
> INJECTED TEXT — NOT a prose instruction to invoke the `frontend-design` skill (prose-only
> Skill-invoke wire-ups historically no-op'd; see `plugins/mega-sdd/CLAUDE.md` Fork A).
>
> **Stack-agnostic.** This file names NO framework, templating language, or CSS library. It
> describes WHAT a production-grade view must achieve; the concrete HOW (layout extend,
> component library, formatting helpers) comes from the injected starterkit slice (design
> tokens + view/component exemplar) alongside this text. Pair the two: the exemplar shows
> the project's idiom; these heuristics keep the bolt from shipping generic scaffold output.
>
> **Anti-hallucination.** Apply these to data and affordances that the unit + vault flows
> already establish. Never invent fields, statuses, copy, or brand voice not grounded in the
> unit spec / vault. If a required affordance has no source (e.g. no design system), that is
> an Open Question for generate-intent — not a value to make up here.

## 1. Visual hierarchy

- Lead with the user's primary task. The most important action or datum is the most prominent
  (size, weight, position, contrast) — not buried in a uniform grid of equal-weight rows.
- Group related fields; separate unrelated ones with whitespace, not just borders.
- One clear primary action per screen; secondary/destructive actions are visually demoted.
- Use the project's design tokens (injected colors/spacing/fonts) for emphasis — do not
  hardcode ad-hoc hex values or one-off spacing.

## 2. Show every state (not just the happy path)

A non-trivial view MUST handle, with intentional UI, each state the flow can produce:

- **Empty** — a list/collection with zero rows shows a purposeful empty state (what it is, how
  to add the first item), never a bare blank table.
- **Loading** — long-running fetches/actions show a spinner/skeleton/disabled affordance, never
  a frozen or silently-empty screen.
- **Error** — failures surface a human-readable message + a recovery path, via the project's
  notification idiom (the injected `notification` lib), never a raw stack trace, a silent
  no-op, or a native browser dialog.
- **Partial / pending** — workflow items mid-process (awaiting approval, in review) show their
  human-readable status, not a raw enum/integer.

## 3. Human-readable values

- **Labels** are human language, not column names. Relabel `customer_id` → "Customer",
  `created_at` → "Created", a `Str::title(column)`-style "Customer Id" is a tell.
- **Foreign keys** render the related entity's display field (its name/title), resolved via the
  relation — never the raw id/UUID.
- **Money / numbers** are formatted (thousands separator, currency, fixed decimals) — never a
  raw float.
- **Dates / timestamps** are formatted for humans (and null-safe — a missing timestamp shows a
  placeholder, not a crash or the literal "null").
- **Statuses / enums** map to human-readable labels (+ a color/badge from the design tokens
  where the design system defines one).

## 4. Accessibility (a11y)

- Every interactive control is reachable and operable by keyboard; focus order is logical.
- Form inputs have associated labels; icon-only buttons have an accessible name.
- Color is never the SOLE carrier of meaning (pair it with text/icon).
- Sufficient text/background contrast (follow the design system; if undefined, that is an OQ —
  do not guess a WCAG value).
- Images/icons that convey meaning have alt text; decorative ones are marked decorative.

## 5. Consistency

- Reuse the project's layout, components, spacing scale, and notification idiom (from the
  injected exemplar + tokens) — do not introduce a parallel bespoke style.
- Sibling screens (index/detail/create/edit of the same or analogous entities) share structure,
  label wording, and action placement. A user who learned one should recognize the next.
- Match the established responsive behavior (the exemplar's breakpoint idiom) so the view works
  on the project's target viewports, not only desktop.

## 6. Pre-ship self-check (the bolt should be able to answer "yes" to each)

1. Is the primary task obvious within a glance (hierarchy)?
2. Are empty / loading / error / pending states all handled intentionally?
3. Are all labels humanized, all FKs resolved to display fields, all money/dates/statuses
   formatted and null-safe?
4. Is it keyboard-operable, labeled, and not color-only?
5. Does it reuse the project's layout/components/tokens and match its responsive idiom?
6. Is every datum/affordance grounded in the unit spec + vault flows (nothing invented)?
