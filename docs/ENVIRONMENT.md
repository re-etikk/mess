# Environment configuration

Copy `.env.example` to a local environment file only after creating the matching Thali services. Keep `.env.local` private; never paste credential values into chat or commit them.

## Authentication

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## Server only

- `SUPABASE_SERVICE_ROLE_KEY` (only if a reviewed server-side operation requires it)
- `QR_SIGNING_SECRET` (at least 32 random characters)
- `NEXT_PUBLIC_BACKEND_ENABLED=true` only after auth, migration, RLS, and admin role setup are reviewed

The 30-day trial and usage-fee policy are stored in Supabase and controlled through the admin console; there is no separate environment variable for the rate.

## Payments

Checkout and webhooks are disabled. Configure these only after creating and verifying the Thali payment account and implementing server-side order creation, signed webhook processing, durable idempotency, and entitlement transactions:

- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`

No test or placeholder secret is accepted as production configuration. Publishable Supabase values may be used in the browser; service-role, QR-signing, and payment secrets must remain server side.
