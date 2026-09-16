<!-- PROVENANCE — masukan tim, disimpan VERBATIM (runbook LANGKAH 0: masukan owner/tim disalin utuh, tidak diparafrase).
     source file : ~/Downloads/java-code-style-rules (1).md  (diterima 2026-09-16 dari owner)
     origin      : hasil run mega-sdd di proyek backend Java (Spring) oleh tim — versi plugin saat run: [OPEN] (tanya tim; lihat research/2026-09-16-code-style-playbook-research.md §1)
     analysis    : research/2026-09-16-code-style-playbook-research.md
     Isi di bawah garis = dokumen tim apa adanya, byte-identik selain header ini. -->

---

# Java Code Generation Rules — Self-Documenting Code

## Core Principle

Write self-documenting code.

Code should clearly communicate **what** it does through meaningful names,
structure, types, and abstractions.

Comments should explain information that cannot be expressed clearly through
the code itself.

> Code explains WHAT. Comments explain WHY.

This is not just a style preference — unnecessary comments consume tokens
both when generated and every time the file re-enters context (edits, code
review, refactoring). Self-documenting code is more efficient *and* more
readable.

## Comments

### Avoid comments when the code is already clear

Do not add comments that:

- Repeat the method, variable, or class name
- Describe obvious control flow or syntax
- Translate code into natural language
- Explain standard Java behavior

```java
// BAD
// Calculate total price
int total = price * quantity;

// GOOD
int total = price * quantity;
```

```java
// BAD
// Loop through users and check if active
for (User user : users) {
    if (user.isActive()) {
        activeUsers.add(user);
    }
}

// GOOD
for (User user : users) {
    if (user.isActive()) {
        activeUsers.add(user);
    }
}
```

### Write comments when the code cannot explain itself

Comments ARE needed when they explain:

- **Why**, not what — the reasoning behind a non-obvious decision
- A workaround for a bug, limitation, or external constraint
- A business rule that isn't derivable from the code alone
- A side effect or gotcha not visible from the method signature
- `TODO` / `FIXME` markers that genuinely need tracking

```java
// GOOD
// Retry once: the payment gateway occasionally times out on first
// call due to cold-start latency on their end (see ticket PAY-482)
if (attempt == 0) {
    return retry(request);
}
```

```java
// GOOD
// Using LinkedHashMap to preserve insertion order — required by
// the export format spec (columns must match source order)
Map<String, Object> row = new LinkedHashMap<>();
```

## Javadoc

### When to skip Javadoc

Do not write Javadoc for:

- Private or package-private methods with self-explanatory names
  (`getUserById`, `calculateTotalPrice`, `isValidEmail`)
- Standard getters/setters
- Simple constructors with no special logic
- Overridden methods whose behavior is already clear from the
  interface/superclass

### When to write Javadoc

Write Javadoc only for:

- Public API consumed by other modules, teams, or external callers
- Methods with non-obvious behavior (edge cases, side effects,
  thread-safety guarantees, exceptions not implied by the name)
- Public class-level documentation for entry points

Skip `@param` / `@return` / `@throws` tags when the parameter names and
return type already make the contract obvious. Include them only when they
add information the signature doesn't already convey.

```java
// BAD — private, obvious, unnecessary Javadoc
/**
 * Method ini digunakan untuk mengambil data user berdasarkan ID.
 * @param id ID dari user yang ingin dicari
 * @return objek User jika ditemukan
 * @throws UserNotFoundException jika user tidak ditemukan
 */
private User getUserById(Long id) {
    return userRepository.findById(id)
        .orElseThrow(() -> new UserNotFoundException(id));
}

// GOOD — name and types already say everything
private User getUserById(Long id) {
    return userRepository.findById(id)
        .orElseThrow(() -> new UserNotFoundException(id));
}
```

```java
// GOOD — public API, genuinely non-obvious contract
/**
 * Reserves inventory for the given order. Reservation is held for
 * 15 minutes; if not confirmed via {@link #confirmReservation}
 * within that window, stock is released back to the pool.
 */
public ReservationResult reserveInventory(Order order) {
    ...
}
```

## Naming

Self-documenting code depends heavily on naming. Prefer specific,
descriptive names over generic ones — this removes the need for a comment
in the first place.

```java
// BAD
int d; // number of days since last login
void process(Object data);

// GOOD
int daysSinceLastLogin;
void processPayment(PaymentRequest request);
```

Guidelines:

- Booleans read as a question or state: `isValid`, `hasPermission`, `canRetry`
- Methods start with a verb that describes the action: `calculate`, `fetch`,
  `validate`, `build`
- Avoid vague names: `data`, `temp`, `obj`, `handle`, `process`, `manager`
  (unless `Manager` is genuinely the correct pattern name)
- Collections are plural: `users`, `activeOrders`

## Quick Checklist

Before finalizing generated code, check:

- [ ] No comment merely restates what the code already says
- [ ] Every remaining comment explains *why*, not *what*
- [ ] Javadoc only on public API or genuinely non-obvious methods
- [ ] No `@param`/`@return`/`@throws` that adds zero new information
- [ ] Names are specific enough that a comment isn't needed to clarify them

## Prompt Template

```
Generate kode Java untuk [deskripsi kebutuhan].

Ikuti aturan berikut:
- Self-documenting code: nama method/variable/class harus jelas tanpa
  perlu dijelaskan ulang lewat komentar
- Tanpa Javadoc kecuali untuk public API yang genuinely butuh dokumentasi
  kontrak, atau method dengan behavior non-obvious
- Tanpa inline comment untuk hal yang sudah jelas dari kode
- Komentar hanya untuk menjelaskan MENGAPA (alasan desain, workaround,
  business rule), bukan APA yang dilakukan kode
- Tanpa @param/@return/@throws yang tidak menambah informasi baru
- Kode harus langsung production-ready tanpa penjelasan tambahan
```

## Notes

Save this file as part of your system prompt or project rules
(e.g. `CLAUDE.md`, custom instructions, or the equivalent rules file in
other tools) so it applies automatically without repeating it every
request.
