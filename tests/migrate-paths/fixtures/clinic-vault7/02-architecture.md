# 02 — Architecture

Next.js 16 (App Router) full-stack: Server Components for reads, Server
Actions for mutations, Route Handlers for the cron trigger + email-token
endpoints. Staff auth via Better Auth; patients unauthenticated (one-time
signed email token).

## §Surfaces

| Surface | Route | Auth |
|---|---|---|
| Booking wizard | `/book` | public (rate-limited) |
| Cancel via token | `/api/appointments/[id]/cancel` | one-time signed token |
| Doctor schedule | `/staff/schedule` | Better Auth (`doctor`) |
| Reminder cron | `/api/cron/reminders` | `CRON_SECRET` |

## Open Questions

- [ ] **OQ-CLINIC-002** [P1] [business]: Should patients see other patients' names in any schedule view? (privacy implications)
- [ ] **OQ-CLINIC-005** [P2] [tech / recommend] [conf: high]: Deployment target — Vercel (Bun beta + Vercel Cron) or self-hosted (Node + croner)?
