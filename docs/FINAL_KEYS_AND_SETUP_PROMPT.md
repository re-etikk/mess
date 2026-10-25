# Thali: keys, setup, and final handoff prompt

Never paste secret values into this chat, source code, screenshots, or GitHub. Enter them only in the provider's secure dashboard or the named local ignored env file. `SUPABASE_SERVICE_ROLE_KEY`, Razorpay secrets, and `QR_SIGNING_SECRET` must never use a `NEXT_PUBLIC_` name.

## Variables and destinations

| Variable | Source / purpose | Destination |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL | Vercel Production + Preview + Development; local `apps/web/.env.local` for local testing |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase publishable/anon client key | Same environments; safe for browser use, protected by RLS |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase server-only service-role secret | Vercel server environment only; local ignored `.env.local` only if local admin APIs need testing |
| `NEXT_PUBLIC_BACKEND_ENABLED` | Explicit fail-closed app switch; set to `true` only after backend review | Vercel and local `.env.local` after migrations/RLS/auth are verified |
| `QR_SIGNING_SECRET` | Server-only random secret, at least 32 bytes of entropy | Vercel server environment and ignored local `.env.local`; generate separately per environment |
| `RAZORPAY_KEY_ID` | Razorpay merchant key ID | Vercel server environment after merchant account approval |
| `RAZORPAY_KEY_SECRET` | Razorpay private API secret | Vercel server environment only |
| `RAZORPAY_WEBHOOK_SECRET` | Razorpay webhook signing secret | Vercel server environment only; must match the webhook endpoint configuration |

The platform billing policy defaults in the migration are a 30-day free trial, then ₹25 per started block of 90 successful unique daily redemptions. An administrator can change trial length/rate and exempt individual providers in the admin console. Automatic payment collection is **not implemented or enabled**; the admin screen explicitly reports this. Do not charge until billing, invoices/receipts, webhook idempotency, failed-payment handling, provider terms/consent, and reconciliation are reviewed and tested.

## Initial admin account

After the database baseline and auth signup are verified, an authorized project owner must bootstrap the first admin from the Supabase SQL Editor. Replace the email with the exact, verified account that should own Thali administration, and inspect the affected row before running. Never use user-editable metadata as the admin authorization source; the role is persisted in `user_roles`.

```sql
insert into public.profiles (id, display_name)
select id, coalesce(nullif(raw_user_meta_data ->> 'full_name', ''), 'Thali admin')
from auth.users
where lower(email) = lower('YOUR_VERIFIED_ADMIN_EMAIL')
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
select id, 'admin'::public.app_role
from auth.users
where lower(email) = lower('YOUR_VERIFIED_ADMIN_EMAIL')
on conflict (user_id, role) do update
set revoked_at = null, granted_at = now();
```

## Prompt to continue after connections are available

> Continue the Thali project from this workspace. First read `README.md`, `docs/BUILD_STATUS.md`, `docs/SETUP_BLOCKERS.md`, and `docs/FINAL_KEYS_AND_SETUP_PROMPT.md`. Use the already connected GitHub, Supabase, and Vercel integrations. Do not ask me to paste secrets in chat. Create/use only dedicated Thali resources; confirm the selected plans are free/no-charge before provisioning, and ask me before any paid resource or payment collection is enabled. Verify the app-specific Supabase project and Vercel project before every mutation. Review the new provider trial/billing migration and all RLS/authorization rules, run Supabase advisors, and apply migrations only to the dedicated Thali project after verifying no existing user data will be overwritten. Create the initial admin role only for the account I identify in the secure Supabase dashboard; never trust user-editable metadata for roles. Add secrets using Vercel's protected environment-variable UI/connector or CLI without echoing values; keep service-role, QR, and Razorpay secrets server-only. Run tests, Flutter tests, build, lint, and dependency audit; resolve critical/high advisories before production. Do not claim production-ready while provider/customer CRUD, QR redemptions, real usage-fee accrual, payment collection, and end-to-end security tests remain incomplete. Deploy a preview first, verify flows with real test accounts, then ask before production promotion. At the end, list each exact variable name and secure destination I must fill if automation cannot do it, and report unresolved work without inventing credentials or data.
