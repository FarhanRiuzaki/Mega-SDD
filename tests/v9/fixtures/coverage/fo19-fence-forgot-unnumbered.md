# PRD: Wallet

## Top-up
Users top up via VA.
```bash
curl -X POST /topup -d '{"amount":50000}'

## Scheduled Transfers
Scheduled transfers MUST run at 00:05 WIB.

## Withdrawal
Withdrawals MUST be capped at Rp10.000.000 per day.

## Notifications
Example:
```
{"type":"DEBIT"}
```
