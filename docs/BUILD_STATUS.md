# Thali build status

Updated: 2026-10-25 (Asia/Kolkata)

## Current discovery

- Existing workspace contains a Next.js app, Supabase migration drafts, a customer Flutter app, and extracted handoff material in `handoff_bundle/`.
- The current Git repository has an initial commit, while the implementation files are untracked. No remote repository is configured or verified in this session.
- The previous implementation describes delivery/rider workflows and percentage commissions. Those conflict with the current Thali brief, which is dine-in only and charges providers INR 25 per started block of 90 successful unique daily redemptions.

## Implemented this session

- Extracted the supplied handoff ZIP without overwriting the existing implementation.
- Opened the workspace in Codex.
- Switched the default customer-facing brand configuration to `Thali`.
- Removed the production fallback QR signing secret. Production token signing now fails closed unless `QR_SIGNING_SECRET` (32+ characters) is configured; the only fallback is isolated to the test process.
- Added the deterministic provider daily usage-fee calculator and boundary coverage for 0, 1, 90, 91, 180, and 181 valid redemptions.
- Updated `.env.example` with blank backend/key placeholders and removed an invented default city.
- Removed demo-prefilled login and fake registration redirects. Web login/signup now use Supabase Auth; roles are not selected by the client during signup.
- Removed sample provider, customer, subscription, order, payment, analytics, and audit data from the live web routes and dashboard screens.
- Replaced mock-backed checkout, webhook, booking, admin metrics, and QR APIs with explicit `503`/`404` responses. Provider discovery now reads only active provider records from Supabase RLS.
- Replaced the customer and provider Flutter app entry points with honest backend-unavailable screens, and the delivery app with an out-of-scope screen. Updated their widget tests to assert these states.
- Deleted `supabase/seed.sql`, which contained invented customer/provider/transaction data.
- Rewrote README claims to accurately state current implementation and blockers.
- Removed the production in-memory store and the SQL development seed containing fabricated provider/customer/payment data. Unit tests now cover only cryptographic primitives and the fee boundaries.
- Removed the unsigned `MESS_DEMO` QR acceptance path.
- Replaced stale marketing, FAQ, privacy, terms, and refund statements with accurate pre-launch notices; no invented support details, operating claims, or unreviewed commercial/legal commitments remain on the active web routes.
- Disabled location filters until real provider location records are available.
- Added explicit `NEXT_PUBLIC_BACKEND_ENABLED=true` opt-in; Supabase browser/server clients remain disabled by default even if an old local env file happens to contain credentials.
- Removed the dormant fake customer Flutter app implementation (demo providers, test sign-in, fabricated purchases and unsigned demo QR path); the mobile app now contains only its honest backend-unavailable entrypoint and its widget test.
- Added a one-month provider free-trial policy migration. Trial begins only when an actual provider is activated; active real providers are initialized at migration rollout. The admin can edit future default trial length/rate and per-provider end date/exemption, with server-verified admin role checks and audit-log writes.
- Replaced the admin console placeholder with a live-data-only billing controls screen. It displays an empty state when there are no provider accounts and clearly states that payment collection is not yet implemented.
- Added authenticated real provider applications, admin approve/reject actions with mandatory audit reason, and public discovery restricted to approved active provider rows. Approving a real application starts its trial through the migration trigger.
- Added eligibility/fee calculator tests for free trial, exemption, billing-off, and post-trial usage.
- Added key destinations and a safe continuation prompt in `docs/FINAL_KEYS_AND_SETUP_PROMPT.md`.
- Re-ran the web production build after these changes; compilation, type checking, and generation of all 30 routes pass.
- Removed old customer Flutter prototype screens/data/repositories and their feature tests; only the honest unavailable app entrypoint/widget test remains. The separately supplied handoff/starter reference material is preserved and still contains legacy example source, but is not part of active app entrypoints.

## Verification

- `npm test` — PASS: 1 file, 13 tests.
- `flutter test` in `apps/mobile_customer` — PASS: 1 backend-unavailable shell test (prototype source/tests removed).
- `flutter test` in `apps/mobile_provider` — PASS: 1 test.
- `flutter test` in `apps/mobile_delivery` — PASS: 1 test.
- `npm run build` in `apps/web` — PASS: optimized production build, type-check, all 30 routes generated.
- `npm run lint` in `apps/web` — PASS with no warnings or errors.
- `npm test` in `apps/web` — PASS: 13 tests.
- `npm audit --omit=dev` in `apps/web` — FAIL: 3 production dependency advisories (Next.js critical; PostCSS and Zod high). npm's suggested remediation includes a breaking Next.js 16 upgrade and Zod 4 migration; these were not applied without a migration and compatibility pass.

## External integration state

- GitHub and Vercel CLIs are not installed; their connected tools are not available to this Codex session. No repo creation, push, or deployment was attempted.
- Supabase CLI is installed, but `supabase projects list` failed with a network transport error. No project access was verified and no migration was applied.
- No unrelated cloud resource was accessed or modified.

## Known blockers and next work

1. Make GitHub/Supabase/Vercel integrations available to this task session. Create separate Thali resources only after confirming free/no-charge options.
2. Reconcile migration history and replace the incomplete migration baseline before applying it to a verified Thali Supabase project.
3. Remove legacy delivery/rider routes, types, schema, and percentage-commission model from the repository (not only from the app entrypoints). Old handoff source and starter bundle still contain reference/prototype material but are not used by active app entrypoints.
4. Upgrade vulnerable production dependencies with a reviewed Next.js 16/React 19 and Zod 4 migration, then rerun tests/build/audit.
5. Finish customer/provider account dashboards and CRUD, redemption tracking and fee accrual, then add authenticated integration/RLS/transaction tests. Current tests do not prove a real production flow.
6. Automatic payment collection is not implemented. Add it only after provider consent/terms, invoices, webhooks/idempotency, retries, reconciliations, test-mode verification, and secure payment keys are in place.
7. Create a separate Thali project/repository, configure verified secrets through connected integrations, apply reviewed migrations, and deploy only after access and billing status are verifiable.
8. Reconcile the legacy `001_initial_schema.sql` and newer core migration before applying any SQL: they define incompatible schemas. Review the intended migration baseline and migration history first; do not blindly apply the current migration folder to a production project.
