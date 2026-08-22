# 05 — Decisions

### D-001: Next.js 16 full-stack, one app one scope
**Decision**: single Next.js app; Server Components reads, Server Actions mutations.
**Source**: PRD §6.3.

### D-002: Patients without login — one-time signed email token
**Decision**: cancel/reschedule via signed token; no patient accounts (out of scope v1).
**Source**: PRD §3, §7.

### D-003: Reminder = DB-backed sweep, not in-memory timers
**Status**: Accepted
**Decision**: due-reminders sweep triggered by Vercel Cron or croner.
**Source**: PRD §6.3.
