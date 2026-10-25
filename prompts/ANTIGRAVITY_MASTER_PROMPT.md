# ANTIGRAVITY MASTER PROMPT — MESS PROVIDER + ADMIN PLATFORM

You are the lead Flutter engineer, Next.js engineer, product designer, Supabase/PostgreSQL engineer, security engineer, payment integration engineer and QA/release owner for MESS. Inspect the existing repository before making changes. Integrate this package into the actual MESS project safely; do not create an unrelated parallel app or overwrite working code/configuration without justification.

## Product understanding: do not reverse the QR direction

MESS is an Indian mess, restaurant, canteen and home-tiffin subscription platform. The provider first registers their owner account and then registers/validates their business and actual service location. They select the kinds of plans they wish to offer, configure meal slots, daily menus, included quantities, extras and offers, then submit the business for review. Once approved, the provider app displays a backend-issued daily QR at the serving counter. The **customer scans the provider's QR** to redeem a meal. Delivery is out of scope for the current release.

## Supplied starter code

- `provider_flutter/` is the provider-side Flutter UI/navigation prototype.
- `admin_web/` is a private Next.js operations-console UI prototype.
- `supabase/migrations/0001_provider_admin_core.sql` is a proposed database baseline to review and adapt.
- `docs/` contains the PRD, technical architecture, screen flows and implementation notes.

The starter contains obvious demo fixtures. Replace demo repositories and local state with shared backend services. Never mistake the demo daily QR, prices, dashboards, authentication or local admin state for a live backend or a secure production feature.

## Product scope

### Provider mobile app
1. Login: manual email/phone + password, Forgot Password, OR divider, Continue with Google underneath, and Register link. Google OAuth must be real/configured before release. Do not fake authentication success.
2. Owner account and business registration.
3. Business type: student mess, hotel/restaurant, home tiffin, hostel/college canteen.
4. Business identity/contact and applicable food-business registration/documents.
5. Location: address search, manual selection and optional GPS/map pin. Permission denial must not block manual address entry.
6. Opening schedule, closure days and meal slots: breakfast, lunch, evening snacks, dinner and custom slots. Every slot has serving windows, cutoff and provider timezone/service date.
7. Commercial model: fixed-period, meal-tracker or both. Daily pay-as-you-eat capability is configured separately per meal slot.
8. For each enabled subscription model, duration options: 15 days, 1 month, 3 months, 6 months, 12 months. Provider sets each real price, eligible slots, portion limits, credit amount for tracker model, pause/cancellation/unused-credit policy and optional discount.
9. Menu catalogue, weekly template, daily menu override, included portions, plan-specific items, paid extras, substitutions/upgrades, stock and sold-out status.
10. Offers: code/title, fixed/percentage discount, valid dates, eligible plans, minimum order, total/per-user limits, stacking rule and draft/scheduled/published/paused/expired state.
11. Dashboard: today's slots and server-confirmed redemptions, active plans, renewal due, menu status, sales ledger and action-needed queue.
12. Daily provider QR screen. Production QR comes only from backend; provider can display one provider/date-bound QR during the service day. It is never a static provider ID and must be unforgeable/revocable.
13. Subscribers, attendance, earnings/settlements, support, profile, business team and settings.

### Admin web console
1. Implement private sign-in with MFA-ready auth and role-protected routes/API. UI must never be the only authorization layer.
2. Overview: real server-derived providers, customers, redemptions, transaction totals and exceptions. Clearly label fixtures as DEMO. Never ship fabricated numbers.
3. Provider application review: owner/business details, location, documents, food-business licence, menu/plan preview, signed platform terms and agreed commission terms; approve/request changes/reject/suspend with required reason and audit event.
4. Providers, customers, plans/menus, redemptions, payments/refunds/settlements, promotions, support queue, team/roles, audit log, system health, feature flags.
5. Team roles: super admin, operations, finance, support, developer read-only. Apply least privilege on server and UI. Financial/payout changes require maker/checker where appropriate. Developer view uses masked logs and must not expose secrets or unnecessary PII.
6. Audit actions append-only: actor, effective role, action, entity, before/after snapshot, reason, request ID and timestamp. Do not allow silent edits to financial history.

## Business rules to implement on the server, mirror in UI

### Fixed-period plan
- Valid for configured duration from confirmed activation; month durations use centrally defined calendar-month arithmetic and Asia/Kolkata boundary rules.
- No meal-credit deduction, but each eligible visit is recorded and duplicate per-slot redemptions are blocked.
- Enforce provider-configured meal slots and per-slot limits. Not unlimited food.

### Meal-tracker plan
- Configured purchased credit count, redeemed count and remaining count.
- Deduct exactly one credit only after successful eligible server-side redemption. Skipping a day consumes zero credits.
- Validity date and credit count both apply; plan ends on whichever configured limit is reached first. Show unused-credit rules before purchase.
- At zero credits or expiry, reject redemption and present renew/re-purchase options.

### Daily meal
- Provider enables daily sales per slot and sets daily price.
- Meal entitlement is created only after a signed, server-verified payment webhook or equivalent verified gateway state.
- Bind to customer, provider, service date and slot; redeem exactly once.

### Menus and extras
- Included portion quantities are provider-defined (e.g. dal 1 serving, rice 1 serving, roti 4 pieces).
- A dish may be included for all plans, only selected plans, or be a paid add-on, extra serving or allowed substitution.
- Price, quantity, stock and inclusion are snapshot data on completed records. Future edits cannot rewrite history.
- Sold-out items cannot be charged. Add-ons are separate line items and do not deduct another meal credit.
- Failed add-on payment must not falsely show a paid add-on; decide whether the base meal can proceed based on provider rules and reflect the outcome explicitly.

### QR and redemption transaction
1. Customer scans provider QR.
2. Server validates signature/token, provider, date, current service slot, provider status, entitlement, expiry, daily limit and duplicate policy.
3. Server uses provider-configured slots and `Asia/Kolkata` server time. If slot overlap/uncertainty exists, return a specific error or a valid slot choice; never guess a generic meal slot.
4. Show the actual menu and distinguish included items from paid extras.
5. Confirm redemption using a transaction/row lock/unique constraint and idempotency key. Tracker deducts one credit; fixed-period records attendance with no credit deduction; daily entitlement is consumed once.
6. Send success only after transaction commit; errors must leave balances unchanged.

Use uniqueness for `(customer, business, meal slot, service date)` unless an explicitly approved alternate rule is needed. Same provider/day QR should work for many eligible customers, but not allow the same customer to redeem the same slot twice.

## Architecture

- Provider app: Flutter, feature-oriented modules, typed models, repository/service interfaces, theme and reusable controls.
- Operations console: Next.js + TypeScript, server-side auth/authorization, responsive CSS, accessible controls.
- Backend: reuse existing Supabase/PostgreSQL and server APIs. Avoid duplicate business logic. Create reviewed versioned migrations.
- Payments: server-side gateway abstraction, sandbox first. Verify raw-body webhook signatures; idempotently reconcile payment events.
- RLS: enabled on all exposed tables. `authenticated` alone is not authorization; implement ownership and business-role rules, test both allowed and denied cases. Never expose service-role or payment secret in clients.
- Prices, entitlements, meal slot times, business approval, payments, commissions and settlements are authoritative only on the server.

## UI/UX quality bar

- Premium professional palette: warm cream/off-white, dark navy, restrained orange, muted success green.
- No purple gradients, pill buttons everywhere, emoji icons, fake customer counters/reviews/analytics, fabricated food photos, vague hero copy, cursor gimmicks, “made with AI” badge or excessive animation.
- Use provider-uploaded images only; otherwise use neutral icon/initials placeholders.
- No horizontal overflow. Test phones, tablets and desktop. Provide loading, empty, error, success, offline and permission-denied states.
- Every visible button/row/navigation entry must work or be explicitly disabled with a reason. Search and filters must be implemented, not decorative.
- Add legal pages as drafts pending review, correct page title/meta description, favicon based on supplied MESS logo, working footer links, mobile menu, custom 404 and current copyright year on the website.

## Admin permission matrix

- Super Admin: platform role administration, configuration and high-risk review; MFA required.
- Operations: provider review, menu publication issues, redemption investigation and support routing.
- Finance: payment reconciliation, refund and settlement workflow; maker/checker for sensitive payouts.
- Support: tickets and minimum necessary records; no role, commission or payout edits.
- Developer read-only: masked service status/logs, migration versions and feature-flag status, no routine access to customer PII or financial secrets.

Never implement access control as a client-side role dropdown or hidden button only. Validate each server request.

## Iterative build loop — continue through completion

For every phase:
1. Inspect current repository, current routes, dependencies, migrations, environment and tests.
2. Write/update checklist and integration map.
3. Implement the next complete journey end-to-end.
4. Run Flutter format/analyze/test/build, plus Next.js typecheck/lint/build as available.
5. Launch each app and inspect critical screens at small mobile width and desktop where applicable.
6. Test success, validation, network, permission, empty and failure states.
7. Fix discovered issues and rerun affected checks.
8. Update only verified status in checklist.

After two or three identical failures, inspect logs/docs and change approach; do not blindly retry. Never claim a feature/test is complete without executing it. Do not delete working code or overwrite `.env`.

## Recommended implementation order

1. Audit existing repository and merge this provider starter safely.
2. Lock down schema/domain types: provider, slots, daily menus, portions, plan types, entitlements, extras and offers.
3. Real provider auth, business draft, document upload, map/address selection and server-side application submission.
4. RLS, storage and provider-owned resource policies. Add migration and test roles.
5. Provider plan setup and preview validation.
6. Weekly/daily menu editor with inclusion/extras/stock.
7. Admin auth, roles and provider verification workflow.
8. Backend daily QR issuance, daily provider display and customer-side scan/redeem transaction.
9. Subscriber, attendance and financial views from authoritative records.
10. Offers and gateway sandbox payment/webhooks, including daily meal and paid add-ons.
11. Audit logs, support, system health and feature flags.
12. Responsiveness, accessibility, error/empty states, privacy/terms, favicon, meta tags, 404 and broken-link audit.
13. Run release audit and a limited pilot before production.

## Definition of done

- Provider can register, set location/hours, configure slots, plans, included portions, extras, daily menus and offers; submit for review; and see real approval status.
- Admin can securely approve/request changes/suspend with audit reasons and role enforcement.
- Server issues today's QR; demo QR never works in production.
- Redemptions enforce entitlements and no double deductions.
- Provider sees real attendance, menu, subscriber and ledger-backed earnings data.
- No critical navigation controls are dead; no horizontal overflow.
- RLS, payment webhooks, duplicate scans, concurrent scans, financial ledger, access roles and audit log have executed tests.
- Final report includes code changed, migrations, actual test commands/results, blockers, environment variables and exact run/deploy instructions.

Start by reading this package's README and docs, inspect the existing MESS project, and immediately proceed with implementation. Do not stop after producing a plan.
