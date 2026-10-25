# Database Security Test Plan

Before production, add executable pgTAP/Supabase tests for every exposed table and privileged transaction.

Minimum roles/fixtures:
- anonymous visitor
- customer A and customer B
- provider A owner, provider A manager and provider A counter staff
- provider B owner
- delivery partner A and delivery partner B
- admin/support server context

Required tests:
1. Anonymous can read only published/active public catalogue columns; cannot read profiles, addresses, subscriptions, bookings, payments, QR, ledger or audit rows.
2. Customer A cannot read or mutate Customer B's private records.
3. Provider A cannot read or edit Provider B's private records/settlement.
4. Counter staff cannot change plan pricing, commission terms, compliance verification or payout settings unless explicitly granted.
5. Delivery partner A cannot access or progress an assignment belonging to B.
6. Clients cannot insert role assignments, raw redemption records, payment statuses, commission rules, settlement rows, audit logs or webhook events directly.
7. Payment webhook replay does not duplicate subscription activation or ledger entries.
8. Concurrent QR redeem attempts produce exactly one success and one credit deduction.
9. Delivery completion and meal redemption are idempotent.
10. Explicit grants are checked alongside RLS; policies must not be the only security measure.

The initial migration intentionally leaves sensitive tables without direct client grants. Use narrowly scoped server-side functions for those operations, or add SELECT policies only after a documented data-exposure review. Run the current Supabase database test workflow (`supabase test db`, after verifying CLI version/support) and record results in the release report.
