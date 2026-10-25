# Thali external setup blockers

No secrets are requested in chat.

## Verified state (2026-10-25)

- No Git remote is configured in this checkout; repository creation/push was not performed.
- Supabase project listing failed with a network transport error; project access is unverified and no project/migration was changed.
- GitHub and Vercel integrations/CLIs are unavailable in this session; no deploy was made.
- The web app's production build, type-check, lint, unit tests, and Flutter shell tests pass, but the web production dependency audit reports 1 critical and 2 high advisories. A reviewed framework/dependency migration is required before release.
- Authenticated provider applications, admin provider review, live approved-provider discovery, and trial-policy controls are implemented in code but cannot work until the matching migrations/backend are configured.
- Customer/provider purchasing, payment collection, subscription/booking writes, QR issuance/redemption, and real redemption metering are still unavailable (HTTP 503/404). Mobile runtime entrypoints are backend-unavailable shells. Legacy reference/demo source remains only in the supplied starter/handoff material, outside active app entrypoints.
- The active migration folder contains incompatible legacy and new schema baselines. Do not apply it until a single migration baseline and target-project history are reconciled.
- Consequently this is a launch-preparation shell, not a production-proven application. Dependency audit still has 1 critical and 2 high production advisories. Do not enable backend auth or deploy until migration history, security updates, backend workflows, review, and end-to-end tests are complete.

## Required Codex connections

1. GitHub: authorize repository creation and push access for a new private Thali repository.
2. Supabase: authorize access to create a separate Thali project. Choose Mumbai only if it remains free/no-charge for the account.
3. Vercel: authorize a separate project and environment-variable management for that repository.

## Required server-side environment variables

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `NEXT_PUBLIC_BACKEND_ENABLED=true` only after security review
- `QR_SIGNING_SECRET`

Payment is intentionally not configured. If test checkout is later enabled, configure `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and `RAZORPAY_WEBHOOK_SECRET` only through a secure environment manager after the provider account is ready.
