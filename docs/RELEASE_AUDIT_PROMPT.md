# MESS — Independent Release Audit

Audit the actual implementation independently against all MESS PRD/TRD/flow/schema/API/security documents. Do not trust prior completion claims.

Inspect and execute tests for:
- All three Flutter apps and the website/provider/admin portals.
- Authentication, trusted role assignment and tenant/provider isolation.
- Grants + RLS on every exposed table; explicit allow/deny tests for anon, customer, provider owner/manager/counter staff, delivery partner and admin access.
- Subscription expiry and credit balances, booking capacity/cutoff, cancellations and pauses.
- Payment server verification, webhook signatures/idempotency, duplicate/out-of-order events and refunds.
- QR expiry, wrong-provider, replay and concurrent redemption attacks.
- Delivery assignment authorization, reassignment, OTP/QR completion and duplicate completion.
- Commission effective dates/accepted agreements, delivery fee split, ledger reconciliation and settlements.
- Env leaks, secret exposure, dead buttons, fake data in production paths, broken routes, error/loading states and responsive layout.

Run the actual available commands and report each area as PASS, FAIL, BLOCKED or NOT TESTED with evidence. Fix all feasible critical/high-priority defects and rerun. Do not use live payments or real customer data without explicit authorization. Finish with a release-readiness report and exact blockers. Do not claim production-ready unless all release gates are verified and external approvals are confirmed.
