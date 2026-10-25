# 02 — Technical Requirements Document (TRD)

## 1. Architecture decision

Use a monorepo unless the existing repository already has a sound alternative. Preserve existing working code and establish this target structure incrementally:

```text
MESS/
  apps/
    customer_app/       # Flutter Android app
    provider_app/       # Flutter Android app
    delivery_app/       # Flutter Android app
    web/                # Next.js: public site + customer/provider/admin route groups
  packages/
    api_contracts/      # OpenAPI and generated/shared contract artifacts where practical
    design_tokens/      # Brand tokens and shared web components if appropriate
  supabase/
    migrations/
    functions/
    tests/
  docs/
  prompts/
  .env.example
  README.md
```

For Flutter, prefer shared Dart packages for models, API client, theming and common widgets while preserving role-specific entry points and permissions. If managing multiple Flutter packages requires extra tooling the repository does not have, do not introduce it without justification.

## 2. Applications

### A. Customer Flutter app

Android first; responsive web provides complementary access. Screens: onboarding/auth, location/address, discovery, provider profile, menu/plans, plan details, checkout, subscription home, book meal, QR display, delivery status, history/receipts, support, profile/settings.

### B. Provider Flutter app

Screens: provider onboarding/status, provider home, today's bookings, QR scanner, scanner result, plans, menu availability, subscriptions/customers, delivery requests/status, earnings/settlement summary, account/support. Role and provider membership must be resolved server-side.

### C. Delivery Partner Flutter app

Screens: onboarding/verification, availability, assignment list/detail, accept/reject, navigation, pickup confirmation, drop-off verification, delivery history, payout summary, issue reporting. Do not add always-on background tracking to MVP unless explicitly approved and implemented with user permission, a visible purpose, retention limits and platform compliance.

### D. Next.js web

A single web codebase can host:
- Marketing/public discovery pages.
- Customer portal under `/account`.
- Provider portal under `/provider`.
- Admin portal under `/admin`.

Use server-enforced access control for every protected page and API. Admin endpoints must not trust client role or user metadata. Provide separate navigation/layouts and strict feature access per role.

## 3. Backend

Preferred baseline: Supabase Auth, PostgreSQL, Storage and Edge Functions. Use server-side Edge Functions for privileged operations such as create checkout, verify payment/webhook, create QR token, redeem QR, confirm delivery, apply entitlements, make refunds/settlement ledger entries and admin operations. Current Supabase docs describe Edge Functions as server-side TypeScript endpoints and recommend environment-stored secrets; validate exact CLI/runtime guidance during implementation.

Do not make every screen call service-role-powered endpoints; use the minimum privileged capability for each operation. Non-sensitive owner-scoped reads can use Supabase client + RLS where appropriate. For sensitive multi-step business operations, expose a narrowly scoped server endpoint and perform the required database writes atomically.

## 4. Contracts and consistency

- API contracts live in `docs/07_API_CONTRACT.md` or an OpenAPI file; update them when endpoints change.
- Store generated database types; avoid handwritten mismatched database models.
- Money is integer paise (`*_paise`), not floating point rupees.
- Timestamp storage is `timestamptz` (UTC at storage); render in `Asia/Kolkata` and the provider's configured timezone.
- Calendar plan expiry must be computed server-side with timezone-aware calendar arithmetic. Use an expiry-exclusive interval `[starts_at, expires_at)`.
- Use UUID identifiers for entities. Do not expose sequential internal financial IDs.
- All create/payment/redemption/delivery-completion endpoints should support idempotency.
- Financial entries are append-only; correct errors with reversal/adjustment entries instead of silently rewriting history.

## 5. Auth and authorisation

- Supabase Auth is the identity provider.
- A `user_roles` table stores trusted role assignments. Clients have no direct insert/update/delete rights on role assignments.
- `provider_memberships` maps provider users to provider-specific roles (`owner`, `manager`, `counter_staff`).
- Delivery partner access requires a verified partner profile and assignment ownership.
- Admin access is assigned by a trusted admin process and enforced server-side.
- Treat `raw_user_meta_data`/client-editable user metadata as untrusted.
- Enable RLS on every exposed table. Configure explicit grants and per-operation policies; RLS policies alone do not remove grants.
- Test allowed and denied access for `anon`, customer, provider, rider and admin flows.

## 6. Payment integration

Build an interface such as `PaymentGatewayAdapter` with operations for create checkout/order, verify server callback/webhook, refund, and fetch transaction state. Integrate one selected Indian gateway in sandbox first. Do not hardcode assumptions about marketplace settlement availability or gateway APIs.

Rules:
- Never activate an entitlement based only on a frontend return URL.
- Verify the gateway's signature using server-held secrets and use current official docs.
- Store a gateway order/payment reference and idempotency key.
- Process webhooks idempotently using a unique provider event ID.
- Reconcile payment state against gateway state when webhooks are delayed or duplicated.
- Store only required, sanitised gateway payload fields; never store card credentials or secret values.
- Keep checkout total server-calculated. Ignore client-supplied totals.
- Live settlement remains blocked until gateway onboarding, KYC, settlement design and compliance checks are complete.

## 7. QR and redemption

- Backend generates a cryptographically unpredictable token; store only a hash or otherwise protected representation.
- Token has one booking, one provider, a purpose, issue time and expiry.
- Return raw token only when generated; avoid logging it.
- Server verifies token, booking state, service date/slot, customer/provider binding and payment/subscription eligibility.
- Redeem with a transaction/row lock/conditional update so concurrent scans cannot both win.
- Unique constraint on `meal_redemptions.booking_id` ensures one successful redemption per booking.
- A failed attempt does not deduct credits. Rate-limit repeated invalid scans.
- Refresh tokens when expired, but do not create a new eligible booking or reset the prior redemption state.

## 8. Delivery

- MVP uses zone/pincode/radius eligibility; add map/routing provider only when configured.
- Delivery price is computed on the server from provider settings, zone/distance inputs and pricing rules.
- Each delivery assignment belongs to exactly one booking and one accepted partner at a time.
- Use legal state transitions: `offered -> accepted -> picked_up -> delivered`, with explicit `rejected`, `cancelled`, `failed` branches.
- Only the currently assigned partner or authorised operations endpoint may update the assignment.
- Location events are optional; do not fake live tracking. If enabled, collect only during active delivery and define retention.
- Delivery completion and meal redemption are one idempotent transaction/event chain.

## 9. Observability and reliability

- Structured logs with request/correlation ID; no passwords, raw QR tokens, payment secrets or unnecessary personal data.
- Error tracking and uptime monitoring configurable by environment.
- Record domain audit events for role changes, provider approvals, commission acceptance, refunds, manual adjustments and overrides.
- Retry transient gateway/network calls with bounded exponential backoff and idempotency.
- Use background jobs/cron for expiry reminders, subscription expiry state maintenance, unpaid checkout cleanup and settlement reconciliation. Never rely only on a client timer to expire plans.
- Avoid unbounded Realtime subscriptions; scope subscriptions to the signed-in user and active workflow.

## 10. Performance and usability targets (initial engineering targets)

- Typical read endpoints: p95 under 700 ms under pilot-scale load, excluding external gateway/network latency.
- QR validation and redemption: target p95 under 1 second under pilot-scale load; correctness beats speed.
- Avoid N+1 queries and index foreign keys and columns used in RLS filters/state queries.
- All core flows usable on mid-range Android phones and intermittent mobile networks.
- Show offline/network error states. Do not permit an offline QR scan to claim success without server validation.

These are initial engineering targets, not guarantees; measure and tune after the first pilot.

## 11. Environment strategy

- `local/development`, `staging`, `production` must be separated.
- Different Supabase projects/credentials for each environment where possible.
- `.env.example` documents names only; never overwrite `.env` or commit secrets.
- Sandbox payment mode by default.
- Production deployments, migrations, live payments, money movement and real customer notifications require explicit approval.
- Seed fake development data only; never put fake transaction/settlement entries in production.

## 12. Deployment target

- Web: deploy to a supported Next.js host after build and environment checks.
- Supabase: migrations and Edge Functions deployed through documented, reproducible workflow.
- Flutter: debug/release builds and Android APK/AAB generated only after analysis and tests pass.
- CI should run formatting, lint, type checks, unit tests, database tests and web build. Add Flutter analysis/tests for all three apps.
- Add rollback/forward-fix instructions for database and web releases.

## 13. Required technical deliverables

- Architecture and data-flow diagram.
- Environment-variable inventory and `.env.example`.
- Versioned SQL migrations.
- RLS/grant policies and database tests.
- API contracts / OpenAPI where practical.
- Three Flutter Android projects.
- Web portal route groups and server authorisation.
- Payment gateway adapter in sandbox.
- QR issue/redeem logic with replay/concurrency tests.
- Delivery state machine and idempotent completion.
- Commission/ledger/reconciliation logic.
- CI/check scripts, test reports, deployment runbook and known-limitations list.
