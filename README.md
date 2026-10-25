# Thali

Thali is being built as a dine-in marketplace connecting customers with messes, restaurants, hostel messes, and home-tiffin providers. The current codebase includes a Next.js website, Supabase migration drafts, and Flutter source.

## Current release state

This repository is not production ready. Supabase and payment processing are not connected. Public listings load only approved provider records from Supabase; mess owners can submit real applications and admins can review them after backend setup. Checkout, subscriptions, and QR redemption APIs remain unavailable until their secure transactional backends are implemented. No fake user, provider, order, or payment records are used by the active app.

The admin console includes a 30-day provider free-trial policy (editable), a configurable post-trial usage-fee rate, per-provider trial adjustments/exemptions, and application review. It does not collect money. Automatic billing needs the payment integration, accounting/webhook workflow, provider consent, and end-to-end verification first.

The customer-facing working brand is **Thali**. The initial product is visit-provider/dine-in only. Delivery and delivery-partner functionality are out of scope.

## Local web app

Requirements: Node.js compatible with the lockfile and npm.

```sh
npm ci
npm run dev:web
```

The web server starts on port 3000. Authentication requires `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`; admin APIs additionally require server-only `SUPABASE_SERVICE_ROLE_KEY` and an active `admin` role in the database. The app reports an unavailable state if its backend is not configured. Do not put service-role, payment, or QR signing keys in browser-visible variables.

## Environment variable names

See `.env.example` and [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md). Payment is disabled until Razorpay credentials and a durable signed webhook implementation are configured. Do not use test credentials in production.

## Project paths

- `apps/web`: Next.js application
- `apps/mobile_customer`: customer Flutter project
- `supabase/migrations`: un-applied schema drafts; reconcile the incompatible legacy and new baseline files, review RLS, and test before using
- `docs/BUILD_STATUS.md`: verified changes and blockers
- `docs/SETUP_BLOCKERS.md`: external setup required to continue
- `docs/FINAL_KEYS_AND_SETUP_PROMPT.md`: secure key destinations and final continuation prompt

## Verification

Run `npm test` for the web unit tests. A passing unit suite does not verify live authentication, Supabase RLS, payments, deployment, or production readiness.
