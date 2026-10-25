# 06 — Security, Testing, Operations and Release Readiness

## 1. Security baseline

- Enable RLS on all exposed tables; pair policies with explicit grants/revokes.
- Do not ship service-role/secret keys in Flutter, browser bundles, public environment variables or repository history.
- Role assignment and admin access are server-controlled.
- Enforce ownership, provider membership and delivery assignment on the backend and in database policies.
- Validate all request payloads; do not trust client prices, commissions, role claims, provider IDs, credits or booking status.
- Apply rate limits to login/OTP, QR validation, webhook and checkout endpoints.
- Use secure randomness; hash short-lived tokens; redact raw tokens from logs.
- Verify webhook signatures against raw request bodies as required by the provider's current official docs.
- Store only sanitised gateway payloads and minimum necessary customer information.
- Protect address/contact details; restrict data to active operational need.
- Upload provider documents to private storage buckets with limited signed access and appropriate retention.
- Prevent IDOR/BOLA by checking authorization at every resource operation, not just route navigation.
- Admin overrides need permission, reason and immutable audit entry.
- Define secure password/OTP, session expiry and rate-limit settings based on provider capabilities.

## 2. Critical tests

### Authentication and RLS
- Anonymous user cannot read customer/private data.
- Customer A cannot read Customer B's address, subscription, payment or QR booking.
- Provider A cannot read/edit Provider B's menu, booking, membership or settlement.
- Counter staff can scan but cannot edit bank/payout settings or commission terms.
- Rider A cannot see/advance Rider B's assignment.
- Client cannot grant itself admin/provider/rider role.
- Admin-only actions fail for non-admin even if endpoint is called directly.

### Payment
- Checkout total is calculated server-side.
- Failed, pending or forged frontend callback does not activate plan.
- Invalid signature is rejected.
- Duplicate webhook does not duplicate activation, commission or ledger event.
- Out-of-order webhook cannot regress a successful transaction to failed.
- Refund is a separate recorded event and reverses appropriate amounts according to policy.
- Payment provider timeout has a safe pending/reconciliation path.

### Subscription and redemption
- Fixed-period validity and expiry-exclusive boundary.
- Month arithmetic around short months and timezone transitions.
- Daily/slot cap enforced under concurrent booking attempts.
- Meal credit does not go negative.
- Booking alone does not consume credit.
- One valid pickup scan consumes one credit exactly once.
- Expired/replayed/wrong-provider/wrong-booking QR fails.
- Concurrent requests using same token yield one success only.
- Delivery completion and redemption do not double-consume a credit.
- Provider closures, cancellation cutoffs and failed delivery follow explicit policy.

### Delivery
- Out-of-zone delivery is rejected.
- Partner must be approved/online/eligible to accept an assignment.
- Only assigned partner can confirm pickup/drop-off.
- Old partner cannot complete reassigned assignment.
- Incorrect/expired OTP fails without completing delivery.
- Duplicate completion returns existing result and makes no duplicate ledger entries.
- Rider payout equals configured formula; commission is not assumed/ hardcoded.

### Finance/commission
- 0% promotional period applies only within agreed effective dates.
- Post-promotion rate activates only after agreement acceptance and effective time.
- Provider commission base excludes delivery fee where terms say so.
- Refund/reversal calculations preserve audit history.
- Ledger and settlement totals reconcile to payment/booking source records.
- Paise arithmetic/rounding is deterministic.

### UX/quality
- No dead buttons, fake charts, placeholder links or fabricated success states.
- Loading/empty/error/retry states exist for primary routes.
- Web responsive checks and keyboard/accessibility checks.
- Flutter analyzer/test/build pass independently for each app.
- API/database errors are useful to logs but not leaking internals to users.

## 3. Observability

Log structured events with request ID and entity IDs where safe. Exclude secrets, payment signatures, raw QR/OTP, full addresses and unnecessary personal data. Monitor error rate, payment pending duration, webhook failures, QR rejects/replays, redemption latency, delivery incidents, settlement mismatch and app crashes.

Create alerts for repeated payment verification failure, duplicate ledger attempts, unusual invalid QR volume, unreconciled settlements and delivery assignment failures.

## 4. Backups and recovery

- Confirm database backup/restore capabilities for the chosen Supabase plan.
- Document who may run migrations, deploy functions and release mobile apps.
- Test restore or recovery procedure in a non-production environment.
- Keep migration history and deployment versions in source control.
- Prefer forward-fix for applied migrations; do not delete/modify production history casually.
- Document gateway outage behaviour and manual operations fallback without recording false payments/redemptions.

## 5. India launch checks

The platform team must assess and obtain qualified advice for applicable marketplace, payment aggregation/settlement, consumer protection, taxation/invoicing, privacy/data protection, labour/partner and food-safety obligations before public launch. Verify provider food business licensing/registration and platform obligations applicable to the chosen operating model. Do not state that MESS is legally compliant merely because a field for a licence number exists.

Reference points to verify during launch:
- Supabase RLS and explicit grants: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Edge Functions/secrets: https://supabase.com/docs/guides/functions
- FSSAI business registration information: https://fssai.gov.in/business/registration
- FSSAI e-commerce food business operator guidance: https://www.fssai.gov.in/upload/advisories/2018/02/5a968f14cc994189.pdf
- Selected payment gateway's current official payment, marketplace, webhook, refund and settlement documentation.

These are links to official starting points, not legal advice. Requirements depend on the exact business and fund-flow model.

## 6. Release blockers

Do not enable production transactions until all are true:
- Payment gateway account and required marketplace/settlement features are approved/configured.
- Production secrets are stored server-side.
- Production data access and RLS tests pass.
- Refund/cancellation and customer terms are published.
- Provider terms, commission/promo acceptance and payout rules are recorded.
- Provider verification and applicable food-safety requirements are checked.
- Customer support and incident ownership are assigned.
- Payment/reconciliation, redemption and delivery failure tests pass.
- Backups, logging, monitoring and a rollback/forward-fix plan exist.
- A named human explicitly approves production launch.
