# Thali Admin Progress

## Current release slice

- [x] Reviewed attached Super Admin engineering prompt and separated its requirements from the direct instruction.
- [x] Audited repository layout, stack, current admin APIs, relevant Flutter API clients, canonical migrations, auth/RBAC, and production release constraints.
- [x] Added technical audit, database map, architecture, and phased implementation plan.
- [x] Existing admin route is hidden from public navigation, `noindex`, and server-guarded by a persisted admin role.
- [x] Build the first admin information architecture slice: overview, partners, customers, and subscriptions.
- [x] Bound/paginate provider, billing-account, customer, and subscription list APIs.
- [ ] Staging verification for migrations and payment/redemption remains unavailable; production database is unchanged.

## Existing capability snapshot

- Partner approval/rejection and trial/usage billing controls: admin UI and APIs exist; queues are paginated. Audit writes are still best-effort and need a transactional path before treating approvals/billing edits as fully audited.
- Metrics: dashboard and bounded `count` queries are implemented. It reports persisted record counts only; financial amounts are intentionally omitted until ledger definitions are verified.
- Customers/subscriptions: read-only admin pages with pagination/search/status filtering are implemented. Customer phone numbers are masked.
- Operations: one role-guarded, read-only paginated view covers bookings, redemptions, payments, refunds, settlements, support tickets, and audit history; no customer note, support description, token, or full identifier is included.
- Announcements: unavailable because persisted table/API does not exist.
- Payments/refunds/settlements: schema exists, but finance UI and safe verified admin mutation paths are absent. Razorpay webhook requires repair before enablement.
- Granular staff roles/MFA/session revocation: not implemented; current role model is coarse.

## Verification evidence

- Current slice: `npm test` passed (4 files, 32 tests); `npm run build` passed on 2026-11-02 including the operations route and page. Build reports one existing `<img>` optimization warning in `src/app/provider/portal/page.tsx:693`.
- Production Supabase data/schema and production deployment were not changed.
- Usage billing is explicitly blocked in the API until payment webhook processing and ledger reconciliation are repaired and verified; entering gateway credentials alone cannot enable it.
- The Razorpay webhook endpoint now fails closed with HTTP 503 and does not mutate transaction or entitlement state until signature, idempotency, amount matching, and atomic database transitions are implemented.
- Provider approval/rejection and billing mutations are blocked on Vercel Preview deployments to prevent preview environments from writing to a production Supabase project when no staging database is configured.
- Current branch preview can be used for review, but admin access still requires an authenticated user with a current persisted admin role.
- Do not mark a module complete because a page renders; record backend and behavior evidence for each slice.

## Blocking release dependencies

1. Staging Supabase with a schema matching the active project, because production migration history is empty.
2. Verified payment order/webhook credentials and a repaired idempotent webhook path.
3. Business/policy decisions for refunds, commission changes, payouts, subscription corrections, coupons, and staff permission assignments.

## Remaining engineering slices

1. Add read-only, paginated operations views for bookings, redemptions, payments, refunds, settlements, support, and audit history after verifying exact schema fields and PII handling.
2. Add safe customer/provider management only with documented policies and append-only audit history.
3. Create the missing persisted modules (announcements, CMS, promotions/coupons, granular staff permissions) only as additive migrations after staging exists; do not simulate them in browser state.
4. Repair payment webhook idempotency, signature handling, enum/amount checks, and transactional entitlement activation before any real payment or usage billing is enabled.
