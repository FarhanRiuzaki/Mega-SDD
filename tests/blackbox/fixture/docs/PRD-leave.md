# PRD — Leave Request Mini-App

## §3.1 Submit leave request
- AC1-1: an employee can submit a leave request with start/end dates.
- AC1-2: the request enters `submitted` status and the manager is notified.

## §3.2 Approval (maker-checker)
- AC2-1: only a `checker`-role employee who is not the maker can approve.
- AC2-2: approval writes `approvedBy` and flips status to `approved`.

## §4 Accrual
- Nightly job accrues leave balance per `accrual_rate_monthly`.

## Open question
- Which notification channel (email vs in-app) for AC1-2?
