# PRD: Payment Gateway — Merchant Settlement

## 1. Overview
Merchants receive card and QRIS payments and are settled to their bank account.

## 2. Instant Settlement
Settlement runs every 15 minutes for merchants on the Instant plan.

## 3. Deferred & Scheduled Settlement
Merchants on the Standard plan are settled once per business day.

### 3.1 Cut-off Time
Transactions captured after 21:00 WIB roll into the next business day's batch.

### 3.2 Holiday Calendar
No batch runs on national holidays; the batch after a holiday carries every pending day.

### 3.3 Settlement Report
Each batch produces a CSV report per merchant, sent by e-mail at 07:00 WIB.

## 4. Transaction Statuses

### 4.1 Pending
The acquirer has authorised the payment but has not captured it yet.

### 4.2 Deferred
The capture is postponed because the issuer is in its end-of-day window; it is retried every 10 minutes for up to 6 hours.

### 4.3 Settled
The funds have reached the merchant's account.
