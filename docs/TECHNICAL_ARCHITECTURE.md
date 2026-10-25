# MESS Provider + Admin — Technical Architecture

## 1. Recommended architecture

- **Provider mobile app:** Flutter, feature-based structure and repository interfaces.
- **Customer mobile app:** existing MESS Flutter app; retain shared domain rules and visual system.
- **Public/provider discovery website:** Next.js + TypeScript; responsive and accessible.
- **Platform admin console:** Next.js + TypeScript; private, authenticated and role-protected.
- **Backend:** Supabase Auth + PostgreSQL + Storage, with Edge Functions or a trusted server service for sensitive transactions. If an existing backend is already in place, reuse it after an architecture audit rather than duplicating it.
- **Payments:** gateway-specific server-side adapter. Use marketplace/split settlement only after gateway account approval and legal/compliance review.
- **Monitoring:** error capture, structured logs, audit logs and alerts. Do not expose secret logs to frontends.

## 2. Application boundaries

Flutter and browser clients are untrusted. A client may request a draft change or redemption but cannot decide:
- user role/business ownership
- provider approval status
- plan price or discount validity
- subscription activation or expiry
- remaining meal credits
- current meal-slot assignment
- QR validity
- payment success/refund
- commission, ledger, settlement or payout state

Those values are read from the database and calculated/validated in trusted server code.

## 3. Domain modules

1. Identity and profiles
2. Provider application and verification
3. Business location, hours and team members
4. Meal-slot schedule
5. Menu catalogue, templates and daily overrides
6. Plan templates and included portion rules
7. Subscription activation and entitlements
8. Daily one-off meal orders
9. Provider daily QR issuance
10. Atomic meal redemption and immutable snapshots
11. Add-on checkout and payments
12. Promotion rules
13. Financial ledger and settlement reconciliation
14. Feedback moderation and support tickets
15. Admin permissions, audit logs, feature flags and incident review

## 4. Server-side transaction endpoints

Suggested endpoint names are logical examples; adapt them to the existing API conventions.

- `POST /provider/applications` — create/submit provider application
- `PATCH /provider/business` — update draft/profile fields
- `POST /provider/meal-slots` — add/update serving slots
- `PUT /provider/menu-templates` — upsert weekly template
- `PUT /provider/menus/{date}/{slot}` — publish date-specific menu
- `POST /provider/plans` — create/update unpublished plan
- `POST /provider/plans/{id}/publish` — validate and publish plan
- `POST /provider/offers` — draft offer; publish action separately validated
- `POST /provider/qr/today` — request today's QR; server creates/reuses a daily session and returns the signed payload
- `GET /provider/qr/today` — retrieve current QR status/payload for an authorized owner/counter role
- `POST /redemptions/preview` — validate QR + eligibility and return current slot/menu/pricing preview; must not deduct a credit
- `POST /redemptions/confirm` — idempotent transaction that checks entitlements/duplicate rules, charges/validates add-ons as appropriate, creates a redemption and deducts tracker credit once
- `POST /payments/create-order` — create gateway order server-side
- `POST /payments/webhook` — verify raw-body signature, deduplicate event and update payment/order/subscription in a transaction
- `GET /provider/finance/summary` — authorized ledger-based report
- `POST /admin/providers/{id}/decision` — admin role check, reason, before/after audit record, and state transition
- `POST /admin/settlements/{id}/approve` — finance role check + maker/checker controls

Use pagination and filters for listing endpoints. Return typed error codes such as `PLAN_EXPIRED`, `NO_CREDITS`, `SLOT_NOT_ACTIVE`, `ALREADY_REDEEMED`, `QR_EXPIRED`, `QR_WRONG_PROVIDER`, `ITEM_SOLD_OUT`, `PAYMENT_REQUIRED` and `ROLE_FORBIDDEN`.

## 5. Database integrity

- Store money as `numeric(12,2)` (or integer minor units consistently), never floating point.
- Use unique constraints for provider/day QR, customer/provider/slot/service-date redemption, gateway payment ID and idempotency key.
- Use DB transaction/row lock or equivalent to serialize concurrent credit deduction.
- Create a redemption record and update tracker balance atomically.
- Save immutable snapshots for plan terms, price, menu items, add-ons and commission agreement.
- Use local service date in `Asia/Kolkata` for slots and daily QR; store timestamps as `timestamptz`.
- Keep operational event timestamps and service-date fields separately.

## 6. Security model

- Enable RLS on every exposed table. RLS must be specific to ownership and role; `authenticated` alone is not sufficient authorization.
- Never use user-editable metadata as a trusted role source.
- Store privileged platform roles in a protected server-managed table and verify them on every admin endpoint.
- Use MFA for platform admins, finance access and sensitive account changes where supported.
- Keep service-role and payment secrets in server-side secret storage only.
- Validate documents and use private storage buckets with signed URLs and access logs.
- Validate payment webhooks against raw body and configured signature; deduplicate webhook events.
- Log privileged actions with actor, role, reason, entity, before/after snapshot, request ID and timestamp. Avoid storing raw secrets or unnecessary personal data in logs.
- For staff roles, enforce business-scoped permissions on the server. Cashier can display the day's QR but must not edit prices or inspect financial reports unless granted.

## 7. Admin console access model

- **Super Admin:** role management, system configuration and high-risk review, protected by MFA and audit log.
- **Operations:** provider review, menu/publication issues, redemption disputes and support routing.
- **Finance:** payment reconciliation, refunds, commission ledger and settlement approvals. Use maker/checker on payout/bank changes.
- **Support:** support tickets and minimum necessary customer/provider data; no payout or role changes.
- **Developer read-only:** service status, masked logs, migration versions and feature-flag status. No routine access to raw payment credentials or unmasked customer PII.

Don't use a client-side role dropdown as authorization. The UI may hide actions by role, but the server must reject them too.

## 8. Frontend quality criteria

- No purple gradients, pill buttons everywhere, fake metrics/reviews, AI-generated food photography, cursor gimmicks or excessive animation.
- Use provider-uploaded images only. Without one, show a neutral icon/initials tile.
- No horizontal page overflow; test small mobile widths.
- Use semantic labels, keyboard focus, high contrast and `prefers-reduced-motion` support on web.
- Every visible action navigates, changes state, submits a request or is visibly disabled with a reason.
- Distinguish loading, empty, error, success, offline, permission-denied and rejected states.
- Add page titles, meta descriptions, favicon based on the MESS logo asset, custom 404, privacy/terms pages, working footer and navigation links, and the current copyright year on website pages.

## 9. Required tests

### Provider app
- onboarding validation and saving/resume draft
- provider cannot publish before required verification/terms
- plan price and duration validation
- included and paid add-on rule previews
- custom slot and no-slot state
- QR load/expiry/revocation/error states
- responsive UI and keyboard/semantics

### Backend
- fixed-period attendance without credit deduction
- tracker credit deducted exactly once for confirmed redemption
- no-credit/expired plan rejected
- daily meal unavailable before verified payment
- duplicate and concurrent scans never double-deduct
- wrong provider/date/signature QR rejected
- overlap/closed slot handled explicitly
- sold-out add-ons cannot be purchased
- failed add-on payment does not create paid add-on or false redemption
- commission terms effective-date behavior
- webhook signature/idempotency
- RLS allowed/denied tests for each role

### Admin console
- authentication required for every route/API
- role isolation and business scope
- approve/return/suspend actions require confirmation and reason, write an audit record
- financial actions require Finance role and maker/checker where appropriate
- search, filters, empty/error states and mobile layout

## 10. Release gates

Do not release the prototype directly. First integrate real authentication, server-side APIs and storage; review migration; complete RLS and role tests; configure the gateway sandbox; validate real provider onboarding; verify backup/restore, logging, privacy, refunds and support process; then complete test builds and a limited pilot. Report untested features as `NOT TESTED`, not `PASS`.
