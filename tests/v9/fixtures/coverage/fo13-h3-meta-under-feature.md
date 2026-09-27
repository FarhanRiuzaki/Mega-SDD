# PRD: Transfer
## 3. BI-FAST Transfer
Customers MUST transfer via BI-FAST.
### 3.1 Scope
Only IDR, only accounts at BI-FAST participant banks; amounts > Rp250.000.000 MUST be rejected.
### 3.2 Non-Functional Requirements
Inquiry MUST time out at 10 s; the transfer MUST be idempotent on client_ref.
### 3.3 Data Model
transfer.client_ref MUST be unique per customer.
