# Bolts Summary — Company Profile Mini

**Generated**: 2026-09-14T17:10:31Z (mega-sdd execute-bolts 7.37.1)
**Batch**: --all --lite (lane lite: JIT bind per wave, W2 unit-level readiness)
**Duration**: ~70 min wall (2026-09-14 23:15 → 2026-09-15 00:25 +07:00)
**Avg AI confidence**: 0.85
**Result**: 6/6 done · 0 halted · 0 quarantined · full suite GREEN (`pnpm test`, HEAD c58d43c)

## Status table

| Unit | Title | Status | Duration | Retries | Confidence | Halt type | Commit |
|---|---|---|---|---|---|---|---|
| U-001 | Open the three public company-profile routes in the proxy guard | ✓ done | 289s | 0 | 0.8 | — | a707a54 |
| U-002 | Add the static company-profile content config | ✓ done | 144s | 0 | 0.9 | — | bd6002d |
| U-003 | Build the public Beranda page | ✓ done | 610s | 0 | 0.8 | — | 3e41580 |
| U-004 | Build the public Tentang Kami page | ✓ done | 611s | 1 (spec ❌ fix round) | 0.9 | — | b5ca3ca, 8a58e39 |
| U-005 | Add the contact-message schema and the server-validating submit route | ✓ done | 540s | 0 (+ L0 prettier follow-up) | 0.85 | — | b243a5b, 9c81f94 |
| U-006 | Build the public Kontak page with the contact form | ✓ done | 908s | 0 | 0.85 | — | 37ff5eb, cdbdccb |

## Halts open (0)

None. The one blocking halt of the run — `binding_conflict` on U-006 (C-U006-A06, anchor `user.repository.ts:1-20` vs a 19-line file) — was resolved KEEP_CODE via `write-unit-binding.sh --resolve` (runner-assumed; unit anchor corrected to `:1-19`, commit 1b87a24; re-bind 10 CONFIRMED / 0 CONFLICT).

## Karantina (0)

No unit was quarantined (no DEFER-class halt fired).

## Hard rule violations across batch (by rule)

| Rule | Source | Violations | Resolution |
|---|---|---|---|
| (all 18 rules across 6 units) | units ## Hard rules | 0 | post-flight pass on every unit |

## Gates run

- JIT bind (3.9) per wave: 3 binds — wave-1 21 fs + 4 symbol claims, wave-2 13 fs, U-006 10 fs + 1 symbol; `text_claims=0` every time → zero model tokens for binding.
- L0 code gates (own-commit ranges): pass for all units (U-005 prettier fix + U-004 fix commit re-scanned).
- Review panel: U-001/U-002 minimal (spec); U-003/U-006 standard + design; U-005 full; U-004 full + design (round 1 spec ❌ → fix round → escape-hatch full re-panel → clear). Every ledger written by merge-panel-findings.sh; all gates `clear`.
- Post-flight Hard rules + B4 acceptance: pass on every unit's final head. B2 full suite: green (`_batch-suite.json`, head c58d43c).
- In-run gate intervention: U-003/U-004 dispatch was blocked once with `panel_evidence_missing` until U-005's panel ledger was merged (gate honoured, not bypassed).

## Self-assessment summary (uncertain decisions across batch)

- U-001: "Exact pathname matching for the three open routes (no trailing-slash/prefix tolerance)" — fallback: If OQ-AR-1 resolves to nested paths, switch to pathname.startsWith(route) or a segment check
- U-001: "Test-first order not strictly followed; red phase re-verified post-hoc by reverting proxy.ts" — fallback: None needed — red/green evidence for the final files is accurate
- U-002: "3 about paragraphs (PRD allows 2–3); placeholder text marked [PLACEHOLDER]" — fallback: Edit the strings in src/configs/companyProfile/index.ts
- U-003: "HomeView carries 'use client' although it uses no hooks" — fallback: drop the directive to make HomeView a Server Component and confirm with pnpm build
- U-003: "Responsive behavior (375px / desktop) verified only via Grid size classes" — fallback: add a browser-level viewport test (confidence for the responsive claim capped at MEDIUM)
- U-003: "metadata.description uses the config tagline" — fallback: remove the description field
- U-004: "Advisory findings F-4..F-7, F-9, F-10 left untouched in fix round 1" — fallback: Follow-up commit: add a .MuiAvatar-root null assertion (F-4), drop data-testid and query within the 'Profil perusahaan' region (F-5), use Container ma
- U-005: "email trimmed before validation (unit specified trim for name and message only)" — fallback: remove .trim() from the email chain
- U-005: "Provisional Indonesian error copy + envelope message 'Data yang dikirim tidak valid. Periksa kembali isian form.'" — fallback: edit strings in contact.schema.ts / route.ts once copy is final
- U-005: "Handler typed with standard Request, not NextRequest" — fallback: change the parameter type to NextRequest; no behavior change
- U-006: "Reset the form to empty after a successful submit." — fallback: Drop the onSuccess resetForm call in ContactForm so the values stay after success too.
- U-006: "A new attempt that fails client validation clears the previous success/error banner (handleSubmit's onInvalid calls mutation.reset)." — fallback: Remove the onInvalid argument from handleSubmit.
- U-006: "Fields carry MUI `required` (visible asterisk + native required/aria-required). The tests reach them by EXACT label-derived accessible name — getByRol" — fallback: Remove `required` from the three fields and drop the three toBeRequired() assertions; the exact-name queries stay valid either way.
- U-006: "Added a metadata description and a one-line intro, both my own copy, and an overline with companyProfile.name." — fallback: Delete the description / intro Typography; the spec only requires the title and the Kontak heading.

## Acceptance-test concerns

- U-005: Tests cannot confirm the upstream accepts this body (field names, caller-supplied created_at); relies on the runner-assumed OQ-DM-1 contract pending backend confirmation.
- U-003 (implementer return): jsdom has no layout engine — the 375px/desktop responsiveness is proven only at the Grid-class level; a browser test at 375px/1280px would close it.
- U-004 (implementer return): public reachability without a session and the 375px layout are not exercised by the view test (U-001's proxy test covers the route guard).

## Important advisory findings (non-gating, recorded in findings.json)

- U-005 F-2 — public unauthenticated POST `/api/v1/contact-messages` has no body-size cap / rate limit / CAPTCHA (route.ts:25). Recommended follow-up before production.
- U-005 F-4/F-5 — feature types drop the house `I`/`T` prefixes (types/index.ts:5,24).
- U-003 F-6/F-7 — test alias import instead of `'.'`; `@configs` vs `@/configs` alias split.
- U-004 F-4/F-11 — the D-002 no-photo test only checks `img`, so an MUI Avatar would slip through; F-16 h2→h6 heading skip; F-17 hard-coded 1100px width; F-18 "ceiling absent" vs HomeView.
- U-006 F-7 — page-level assertions inside the ContactForm test; F-10 Kontak is a lone centered card (no page shell / back link).
- Lens conflict for human review: U-004 design F-18 asks for iconography/depth that the U-004 round-1 spec lens ruled out of scope (F-2/F-3).

## Runner assumptions (headless benchmark — owner absent)

- OQ-DM-1 [P1 business] → resolved (plan): `contact_messages` is owned by the upstream API; the app validates server-side and forwards via `apiServer` to `POST /v1/contact-messages` with a server-stamped `created_at`. **Backend contract confirmation still required.**
- Deferred P2 OQs kept deferred; units implemented their provisional behaviour (no TBD prompt answered on the owner's behalf).
- `binding_conflict` C-U006-A06 → KEEP_CODE (spec citation error, no code change).

## Deferred open questions (4)

- OQ-AR-1 [P2, tech/recommend] — final URLs for the three public pages (provisional `/beranda`, `/tentang-kami`, `/kontak`; `/` still redirects to `/home`).
- OQ-FL-1 [P2, business] — final per-field error copy (provisional text mirrors the PRD rules).
- OQ-FL-2 [P2, business] — no navigation leads to Tentang Kami (none was invented).
- OQ-CN-1 [P2, business] — how/who measures "< 2 s on 3G".

Jawab kapan saja: `resolve-oq`.

## Next steps

- detect-drift (auto-gate, hybrid, DEFAULT-ON) → then `/mega-sdd:analyze`.
- Resolve deferred OQs with `resolve-oq`; confirm the OQ-DM-1 upstream contract with the backend team.
- Consider a follow-up unit for the U-005 F-2 abuse-surface hardening and the U-004 F-4 avatar test gap.
