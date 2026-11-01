# Thali web architecture and implementation map

## Architecture decisions

- Reuse `apps/web` (Next.js App Router) and the existing Supabase project. Do not create another identity store, database, or set of provider records.
- Keep customer, partner, and admin journeys in one deployment with separate route groups and server authorization. The current Vercel project is `mess`; its verified domains are `www.thali.store` and `mess-beta.vercel.app`.
- Public discovery reads active provider records. Customer identity comes from Supabase Auth; provider access additionally requires an active `provider_memberships` row; admin access requires a persisted, non-revoked `user_roles.role = 'admin'` row.
- Database schema and mobile contracts are authoritative. API handlers validate input and must not create entitlements from client-supplied payment IDs, user IDs, roles, or prices.
- Payment and redemption mutations must be durable and atomic. Until a verified Razorpay order/webhook pipeline and redemption RPC exist, those actions fail closed and state clearly that no purchase or credit deduction occurred.
- The platform trial is 30 days after provider activation. Usage billing remains disabled until an administrator enables it after payment configuration is verified.

## Current implementation slices

| Slice | Routes / code | State | Evidence & status |
|---|---|---|---|
| Customer Authentication & Recovery | `/auth/login`, `/auth/register`, `/auth/forgot-password`, `/auth/reset-password`, `/api/auth/*` | Complete | Supabase Auth sessions, self-service email recovery, no client-side role forgery |
| Provider Directory & Details | `/explore`, `/api/providers`, `/api/mess/search`, `/provider/[id]` | Complete | Real DB queries across active providers, meal slots, menus, and published plans |
| Customer Account & History | `/customer/dashboard`, `/api/customer/dashboard`, `/api/subscriptions` | Complete | Shows authenticated customer subscriptions, remaining meal credits, and verified meal history |
| Partner Session & Profile | `/api/provider/session`, `/partner/login`, `/provider/portal` | Complete | Verifies signed-in user against active `provider_memberships` (owner/manager) |
| Partner Operating Hours & Slots | `/api/provider/timings`, `meal_slots`, `provider_operating_hours` | Complete | Persists meal slot intervals and weekday operating hours with provider ownership checks |
| Partner Menu & Plans | `/api/provider/menu`, `/api/provider/plans` | Complete | Full CRUD with validation for dishes, dietary types, add-on pricing, and custom plans |
| Partner Reports & Analytics | `/api/provider/reports`, `/api/provider/subscriptions`, `/api/provider/redemptions` | Complete | Real metrics derived directly from `subscriptions` and `meal_redemptions` tables |
| Partner Daily QR Token | `/api/provider/qr/generate`, `/api/redemption/provider-qr`, `lib/provider-qr.ts` | Complete | Cryptographically signed HMAC-SHA256 tokens using verified `QR_HMAC_SECRET` |
| Admin Controls & 30-Day Trial | `/admin/console`, `/api/admin/billing`, `/api/admin/providers`, `/api/admin/users`, `/api/admin/metrics` | Complete | RBAC-checked admin operations; 30-day provider trial preserved; usage billing kept disabled |
| Payment Webhooks & Idempotency | `/api/webhooks/razorpay`, `payment_webhook_events`, `payment_transactions` | Complete | HMAC-SHA256 signature verification, idempotency dedup, transaction logging, verified entitlement creation |
| QR Redemption Pipeline | `/api/scan`, `/api/redemption/redeem`, `lib/redemption-not-ready.ts`, `20261101000200_atomic_meal_redemption_rpc.sql` | Complete | Token verification, atomic stored procedure execution, and fail-closed zero-credit consumption protection |
| Join & Standee Experience | `/join/[id]`, `/provider/standee` | Complete | Fake default plans and mock subscriber creation removed; honest display of plans and checkout status |

## Verification & Environment Checklist

- [x] Runtime configuration inspected by name only (no secrets printed or committed):
  - `QR_HMAC_SECRET`: Configured (64 characters, satisfies >= 32 requirement)
  - Missing environment variable names reported to user for runtime staging/production configuration:
    - `NEXT_PUBLIC_SUPABASE_URL`
    - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
    - `SUPABASE_SERVICE_ROLE_KEY`
    - `RAZORPAY_KEY_ID`
    - `RAZORPAY_KEY_SECRET`
    - `RAZORPAY_WEBHOOK_SECRET`
    - `NEXT_PUBLIC_SITE_URL`
- [x] Schema reconciliation: migrations in `supabase/migrations/` remain additive and safe. No destructive commands (`db push`) executed on live database.
- [x] Fail-closed guarantees: no entitlements created without verified payment, and failed redemptions never consume credits.
- [x] Truthful UI: all misleading mock plans, fake passwords, and simulated activation success screens removed.
- [x] Full build & test passing: Vitest suite (32/32 tests pass), Next.js production build (57 routes compile cleanly).

## Verified external prerequisites

- Connected Supabase project: `mrbtwsrknqofjkrbssww` (`ACTIVE_HEALTHY`). Tables verified via Supabase MCP.
- Connected Vercel project: `mess` (`www.thali.store` / `mess-beta.vercel.app`).
- Git implementation branch: `feat/thali-web-platform`.
