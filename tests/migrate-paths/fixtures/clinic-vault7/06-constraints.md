# 06 — Constraints

## Compliance

Patient personal data handled per applicable regional privacy regulation;
UI meets **WCAG 2.2 Level AA**.

## Non-functional requirements

| Category | Requirement | Source |
|---|---|---|
| Performance | Appointment lookup < 200ms (median) | PRD §6.2 |
| Reliability | Reminder email within 5 minutes of schedule | PRD §6.2 |
| Accessibility | WCAG 2.2 AA (contrast, focus, aria-live) | PRD §8.4 |

## Open Questions

- [ ] **OQ-CLINIC-001** [P1] [business]: Which patient-data-privacy regulation applies in our region (HIPAA / GDPR-equivalent), and what does it require for storage + email handling?
- [ ] **OQ-CLINIC-006** [P3] [tech / recommend] [conf: medium]: Doctor schedule grid — confirm Schedule-X's current free-vs-premium view split is acceptable, or budget for FullCalendar Premium.
