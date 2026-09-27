# PRD: Transfer

## 3. Transfer API
### 3.1 Request
```json
{"amount": 100000, "client_ref": "abc"}

### 3.2 Scheduled Transfers
Scheduled transfers MUST execute at 00:05 WIB.

### 3.3 Idempotency
The API MUST reject a duplicate client_ref within 24h.

### 3.4 Error Codes
```
E01 Insufficient funds
```

## 4. Notifications
Push on every debit.
