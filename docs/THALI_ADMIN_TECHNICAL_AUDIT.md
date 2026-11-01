# Thali Admin Technical Audit

**Audit basis:** repository source and committed Supabase migrations, plus the previously inspected live project metadata/schema summary. The live project has no recorded migration history; this document does not treat repository migrations as deployed schema.

## Current architecture

- `apps/mobile_customer`, `apps/mobile_provider`, and `apps/mobile_delivery` are Flutter clients. Customer and provider clients call the Next.js API hosted by the `mess` Vercel project.
- `apps/web` is Next.js 14 App Router with TypeScript, React 18, Tailwind, Supabase JS/SSR, Zod, and Vitest. There is no separate API service in this repository.
- Supabase is the shared Auth/Postgres/storage backend. `apps/web/src/lib/supabase/server.ts` creates cookie sessions; `admin.ts` owns the server-only service-role client and `requireAdmin` authorization helper.
- The production admin entry is intentionally unlinked from public navigation. `/admin/console` is `noindex` and its server layout verifies the authenticated session and non-revoked `user_roles.role = 'admin'` before rendering. Admin APIs repeat authorization.
- Vercel Git integration creates branch previews. Production is on `main`; the current implementation branch/PR remains separate and must not be merged until schema and payment/redemption prerequisites are resolved.

## Repository map

| Area | Location | Notes |
|---|---|---|
| Customer Flutter app | `apps/mobile_customer/` | Calls `/api/auth/*`, `/api/mess/search`, `/api/scan`, `/api/subscription/*`, `/api/meal/daily_purchase`, and support APIs. |
| Partner Flutter app | `apps/mobile_provider/` | Calls provider login/profile/menu/plan/timing/order/QR/subscriber/report APIs. |
| Delivery Flutter app | `apps/mobile_delivery/` | Separate client; delivery schema exists but is not a current admin-console workflow. |
| Web/admin UI | `apps/web/src/app/` | Next App Router, provider portal and protected `/admin/console`. |
| API routes | `apps/web/src/app/api/` | Auth, provider, customer, payment/webhook, redemption, support, and admin handlers. |
| Shared server logic | `apps/web/src/lib/` | Supabase clients, role checks, validation, QR cryptography, provider auth, platform helpers. |
| Database migrations | `supabase/migrations/` | Core schema, billing, platform, commerce, permissions, menu and redemption changes. `archive/` and `review_drafts/` are not the canonical migration stream. |
| Existing contracts/docs | `docs/` | API contract, security matrix, schema, implementation, flows, and release docs. |

## Identity and authorization

- Supabase Auth is the identity provider; `profiles` references `auth.users`.
- `user_roles` uses `app_role` (`customer`, `provider`, `delivery_partner`, `admin`, `support`) and revocation timestamps. `requireAdmin` trusts only a current authenticated user plus a non-revoked database admin role; user metadata is not an authorization source.
- Provider APIs additionally resolve provider membership and provider status. The existing admin product has one broad `admin` role, not the prompt's granular staff permission model.
- Admin APIs use the server-only service-role client only after `requireAdmin`; it must never reach browser bundles.
- Route guard and API authorization are present. MFA, step-up authorization, granular RBAC, admin session revocation tooling, and maker/checker approval are not implemented.

## Existing API inventory relevant to admin

| Capability | Existing endpoint | Current state |
|---|---|---|
| Provider review/list | `GET/PATCH /api/admin/providers` | Real pending/active records; approve/reject with reason; audit insert is attempted but audit failure does not roll back the provider update. No server pagination/search yet. |
| Legacy provider approval | `POST /api/admin/approve_provider` | Retired with 410; no fallback mutation. |
| Trial and usage billing | `GET/PATCH /api/admin/billing` | Real platform settings and provider billing accounts. Billing enablement fails closed when Razorpay configuration names are missing. |
| Overview counts | `GET /api/admin/metrics` | Real DB queries, but existing redemption and financial queries read unbounded row sets; finance semantics need correction before presenting as net revenue. |
| User directory | `GET /api/admin/users` | Real paginated profiles, but lacks search/filter/role scope and returns unmasked phone data. |
| Subscriptions | `GET /api/admin/subscriptions` | Real data but fixed 100-row limit, no pagination/filter, and selects all columns. |
| Announcements | `GET /api/announcements` | Explicitly unavailable (503); no persisted announcement table exists. |
| Payment webhook | `POST /api/webhooks/razorpay` | High risk: webhook id fallback is timestamp-based, timing-safe compare can throw on unequal lengths, amount/status are not safely reconciled, write errors are ignored, and code writes `paid` although schema enum is `succeeded`. Keep finance actions read-only/fail-closed until repaired and staging verified. |
| Payment compatibility webhook | `POST /api/payments/webhook` | Deliberately returns 503 and does not mutate entitlements. |
| Support | `POST /api/support/ticket` | Ticket creation exists; admin list/assignment/resolution UI/API not found. |

## Database/domain map

The canonical schema defines these persisted domains (not every requested product feature has a backing object):

- Identity: `profiles`, `user_roles`, `customer_addresses`.
- Partner: `providers`, `provider_memberships`, `provider_compliance_documents`, `provider_service_areas`, `provider_operating_hours`.
- Catalogue: `meal_slots`, `menu_items`, `subscription_plans`, `plan_meal_slots`.
- Entitlements/orders: `subscriptions`, `meal_bookings`, `qr_redemption_tokens`, `meal_redemptions`.
- Payments/finance: `payment_transactions`, `payment_webhook_events`, `refunds`, `platform_commission_rules`, `commercial_agreements`, `financial_ledger_entries`, `provider_settlements`, `provider_settlement_items`, `delivery_payouts`.
- Engagement/operations: `notifications`, `support_tickets`, `audit_logs`, `idempotency_records`, plus delivery assignment/location tables.
- Platform billing migration adds `platform_billing_settings` and `provider_billing_accounts` (30-day default trial; usage pricing disabled by default).

Missing/partial logical capabilities: announcement/campaign/CMS/coupon persistence, customer account suspension state, granular admin permission assignments, immutable mutation audit enforcement, refund processing orchestration, customer/order analytics aggregates, admin support operations, and verified payment/reconciliation workflow. Do not create duplicate tables or invent policy to fill these gaps.

## Business workflow findings

- Provider application: authenticated user submits through `submit_provider_application`; provider + owner membership are persisted in `pending_review`; approval is admin-only; activation trigger starts the configured provider trial.
- Partner menu/plans: provider CRUD APIs exist; admins should moderate policy violations rather than replace routine partner editing.
- Customer discovery/subscription: mobile clients call existing APIs; checkout/payment activation is intentionally fail-closed until gateway order creation/webhook processing are verified.
- QR redemption: short-lived signed provider QR is verified server-side; atomic redemption is represented by a new migration but is not applied/verified in staging. No admin credit reset should be added without an audited transaction.
- Settlement: schema contains ledger/settlement records, but no confirmed payout gateway workflow or verified admin payout mutation path exists. Treat as read-only until reviewed.

## Security and operational risks

1. No usable staging database/migration history is currently available; production migrations must not be applied blindly.
2. Razorpay webhook must be repaired and integration-tested before billing, refunds, or payment status controls can be enabled.
3. Current admin role is coarse; do not expose the full finance/support/marketing functions to arbitrary staff without a persisted permission model.
4. Personal data in admin lists needs masking, scoped access, and audit-aware exports.
5. Heavy dashboard sums should be calculated by bounded queries or reviewed aggregate functions, not by downloading entire transaction tables.
6. A persisted audit row should be part of the same database transaction as each sensitive change; best implemented through a transaction/RPC after schema review.

## Release boundary

Current changes are preview-only on the feature branch. No production deployment, migration, billing activation, refund, payout, or role mutation is authorized by this audit. Preview readiness does not prove production integrations are configured.
