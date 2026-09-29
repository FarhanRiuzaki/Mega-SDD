# Hidden acceptance checklist — xs (PRD `research/2026-09-10-p0-baseline/prd-3screen-xs.md`)

Never shown to an arm. Given to the blind scorer only (`benchmarks/scripts/blind-score.sh`).
Each item is PASS or FAIL with evidence (file:line, a command and its output, or both).
Judge against the PRD text, not against any other document in the repo.

| id | criterion |
|---|---|
| X1 | Beranda: organisation title, one-sentence tagline, three main services (title + one paragraph each) read from a configuration file, and a button/link to the Kontak page |
| X2 | Responsive at 375px wide and on desktop (layout classes/breakpoints or CSS that adapt; no fixed desktop-only widths that overflow 375px) |
| X3 | Tentang Kami: 2–3 static profile paragraphs, a team list (name + role, from configuration, no photos), and a link back to Beranda |
| X4 | Kontak form fields: nama required ≤100 chars, email required and valid format, pesan required ≤2000 chars |
| X5 | Validation happens on the SERVER (server action / route handler / API), not only in the browser |
| X6 | DoD: a valid message is stored in a `contact_messages` table/collection with `created_at` |
| X7 | A success message is shown on the same page after a valid submit |
| X8 | DoD: an invalid email is rejected with an error shown at the email field |
| X9 | DoD: the form keeps the entered values after a failed validation |
| X10 | Every form field has a label; keyboard navigation works (native controls or equivalent) |
| X11 | Visitor input is escaped when displayed; no raw HTML from visitors is rendered (no `dangerouslySetInnerHTML` on user data) |
| X12 | The repo's own test suite passes at HEAD (run it; a missing test script counts as FAIL) and `npm run build` succeeds |
