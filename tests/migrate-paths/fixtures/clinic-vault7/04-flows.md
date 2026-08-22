# 04 — Flows

## User flows

### F-U-001: Patient books appointment

**Flow**:
```mermaid
flowchart TD
    A[/"book: pilih dokter + service"/] --> B["pilih tanggal + slot 15-menit"]
    B --> C["isi nama, email, phone, reason"]
    C --> D{"konfirmasi"}
    D -->|ok| E["booked, booking_channel=online"]
    E --> F["email konfirmasi + link cancel/reschedule"]
```

**Definition of Done**:
- [ ] appointment `booked` tercipta + email terkirim (AC-001)
- [ ] slot terisi tak bisa double-book (AC-002)

**Source**: PRD §Clinic.1 F-U-001 (AC1-1, AC1-2)

### F-U-002: Patient cancels appointment

**Flow**:
```mermaid
flowchart TD
    A["klik link cancel di email"] --> B{"konfirmasi"}
    B -->|ok| C["status cancelled, slot freed"]
    C --> D["halaman konfirmasi"]
```

**Definition of Done**:
- [ ] status `cancelled` + slot freed (AC-003)

**Source**: PRD §Clinic.1 F-U-002 (AC3-1)

## System flows

### F-S-001: Reminder sweep

**Flow**:
```mermaid
flowchart TD
    T(["cron"]) --> R["Query due reminders 24h ± 5 min"]
    R --> S["Send email + flip reminder_sent"]
```

**Definition of Done**:
- [ ] reminder fires once, idempotent (AC-004)

**Source**: PRD §Clinic.1 F-U-003 (AC4-1)

## Open Questions

- [ ] **OQ-CLINIC-004** [P2] [business]: If a doctor calls in sick, how does the system handle their booked appointments (auto-notify + reassign, or manual)?
