# THALI / MESS — MASTER CODEX BUILD, SECURITY, TESTING & DEPLOYMENT PROMPT

> Paste this entire prompt into Codex/Antigravity while the intended project workspace is open. Give it access to the connected GitHub, Supabase, and Vercel integrations. The prompt asks the agent to do the work, not merely explain how.

## 0. Mission and working style

Act as the principal engineer, product designer, database/security engineer, QA lead, and DevOps engineer for this project. Take ownership from repository discovery through implementation, verification, and deployment. Prefer making safe, reversible progress over asking me questions. Do not stop after creating a plan, a mock UI, or a README. Inspect the real files and integrations, implement the complete product in the current workspace, run the available checks, fix failures, and deploy the parts that can safely be deployed.

The product has previously been called **MESS**. Use **Thali** as a temporary customer-facing working brand because it is a familiar Indian food word, but keep the brand name, logo asset, support details, links, and contact information centralized in configuration. Do not buy a domain or claim the name/domain/trademark is available. If the existing workspace has a deliberate, newer brand configuration, preserve it and report what you found.

### Non-negotiable operating rules

1. **Discover before changing.** Inspect the current workspace, git status/history, all project files, existing starter packages, design assets, installed tools, and connected integrations. Search for prior MESS/Thali handoff folders/files if they are actually accessible in this environment. Reuse good existing work; do not blindly overwrite a working project or regenerate everything from scratch.
2. **Do not touch unrelated production resources.** An account audit in a previous connected-tool check showed no GitHub repositories visible; Supabase showed an active project named `Redo` and an inactive project named `Ai with Rajnish`; Vercel showed `portfolio` and several ReDo projects. Treat these as unrelated. Re-check live state at execution time, and do NOT modify, migrate, pause, delete, expose, or deploy this product into any of those resources. Create clearly named, separate Thali resources.
3. **Use connected tools/integrations first.** Discover and use the actually available GitHub, Supabase, and Vercel tools. Do not assume tool names or that a plugin has access; inspect tool help/schema first. Use the authenticated account, not credentials guessed from prior chats.
4. **No fabricated credentials.** Never invent API keys, OAuth secrets, payment credentials, tokens, signing keys, or database passwords. Never print secrets in terminal output, chat, logs, commits, screenshots, or the final report. Do not put a Supabase service-role/secret key in browser code, Flutter, `NEXT_PUBLIC_*`, or any client app. Use platform secret managers/environment-variable forms to enter secrets where authorized.
5. **No paid spending without explicit approval.** Prefer free-tier-compatible resources and use only options with no new charges. If creating a project, enabling a service, buying a domain, switching plans, enabling paid compute, or using a feature might incur a non-zero charge, stop that one operation and explain the exact price/approval needed. Continue all other non-billing work. Never purchase a domain, add a paid plan, or activate paid recurring charges on my behalf.
6. **Do not claim a task succeeded unless verified.** Distinguish `DONE & VERIFIED`, `DONE BUT NOT VERIFIED`, `BLOCKED`, and `NOT STARTED`. Build and deploy logs, successful HTTP responses, test output, and project details are the evidence. A green-looking UI is not backend completion.
7. **Ask me only for genuinely unavoidable external actions.** Continue everything else. If GitHub/Vercel/Supabase requires me to authorize OAuth, complete a verification, accept a cost, or enter a secret that cannot be provisioned through an authorized connector, state the smallest exact action needed and why. Do not ask me to paste private keys in the chat.
8. Keep a running `docs/BUILD_STATUS.md` with implemented scope, commands run, test results, known issues, environment-variable *names* (never values), deployment state, and manual blockers. Update it as you work.

## 1. Product scope — build the real product, not a static demo

Build an Indian local-food marketplace for messes, hostel messes, restaurants, and home-tiffin providers. Initial experience is **dine-in / customer visits the provider**. Delivery-partner functionality is out of scope; do not build it or advertise delivery as available.

Target experience:
- A polished, responsive public website for discovery and provider onboarding.
- Customer web experience/PWA with responsive layouts.
- Provider dashboard/portal for operating a food business.
- Admin console for the platform operations team, protected by strict authorization.
- Flutter source for customer and provider Android apps if the starter/workspace and available tools support it. Keep mobile apps pointed at the same real backend. Do not claim APK/Play Store readiness unless a build/signing test passes. Do not build a delivery-partner app.
- A real Supabase-backed data/auth layer and a real deployment for the web app where credentials/integrations permit it.

### Customer functionality
- Sign up, sign in, sign out, and account/session handling using Supabase Auth. Begin with email/password or supported email OTP/magic link; use phone OTP or OAuth only when correctly configured. Never fake an authenticated session.
- Discover/search providers by business name and food/menu item. Support city/area filters only when real location data exists; request browser/device location only after permission.
- Provider details, address/map link, opening hours, meal slots, today’s menu, special dishes, included items, add-ons, prices, plan choices, availability, and food/business photos.
- A customer may have one or more plans, but the active provider/entitlement shown on the home screen must be unambiguous. Show the current date, today’s slots and their redemption states, plan expiry, and remaining credits where applicable.
- If there is no active plan, show a useful browse experience, daily meal prices, and a buy-today option when offered. Do not present a dead-end scan screen.
- The main Scan action opens the camera only after permission, gives manual/recovery instructions if camera access is unavailable, and displays understandable errors for invalid/expired QR, wrong provider/day/slot, no entitlement, already redeemed, or payment not confirmed.
- Customer can view subscriptions, receipts, meal redemption history, selected add-ons, renewal options, and support contact/ticket history.

### Provider onboarding and management
- Provider account registration and onboarding for `mess`, `restaurant`, `hostel_mess`, or `home_tiffin` business types.
- Business name, owner/contact details, address, coordinates or map pin, opening hours, dine-in details, applicable licence/FSSAI details and documents as appropriate, business photos, payout details where payment provider permits, and platform review/approval state.
- Meal slots are provider-configurable (breakfast, lunch, dinner, or custom name/time windows). Do not hard-code exactly three slots.
- Menus and portions: included base meal (e.g., dal, rice, roti, sabzi, salad), premium plan inclusions, optional paid extras (e.g., paneer, extra roti/rice), optional substitutions/upgrades with price differences, daily menu, sold-out state, and availability schedules.
- Provider configures which subscription types to offer, durations, credit quantity, pricing, included slots, slot-specific rules, discounts, renewal rules, capacity, cancellation policy, and clearly disclosed expiry/unused-credit terms.
- Provider home includes today’s expected meals, subscriber/attendance summaries backed by real queries, today’s QR, successful redemptions, add-ons, customer issues, plan settings, and settlement/platform-fee history. Never invent analytics, reviews, users, orders, or revenue.
- Provider can preview changes before publishing. A pending/unapproved provider must not appear as bookable/active until approved under platform rules.

### Subscription, daily meal, and redemption rules
Implement the three commercial paths cleanly:

1. **Fixed-period plan:** duration choices 15 days, 1 month, 3 months, 6 months, or 12 months. Starts at the server-confirmed purchase/activation time (or a clearly disclosed chosen start date if designed) and ends according to the stored end date, regardless of how many meals were consumed. Attendance is tracked but does not decrement meal credits. Slot/capacity limits are provider-configurable so the plan is not unlimited beyond its stated terms.
2. **Meal-credit tracker plan:** provider sells a defined credit count (example: 30 meals). Deduct exactly one credit only after a valid, successful meal redemption for a qualifying included meal. Missed days, opening the scanner, failed scans, duplicate scans, or canceled payment must not decrement credits. Plan ends when credits reach zero or the disclosed expiry time arrives, whichever occurs first. Clearly explain what happens to unused credits; never decide this silently.
3. **Daily pay-as-you-eat:** customer purchases one meal/day/slot where offered. Entitlement is created only after server-side verification of successful payment (or an explicitly configured offline/cash path recorded by authorized provider staff). Do not show a paid/active status based solely on a client redirect.

Other rules:
- Providers may offer fixed-period plans, credit plans, or both.
- A full meal redemption consumes at most one credit. Optional add-ons are separate line items/charges and must never consume an extra meal credit.
- Items included in a plan must be visible before checkout. Extras/substitutions show price and availability before confirmation. A sold-out item cannot be charged. Store the selected item/price snapshot on the order so later menu edits do not rewrite old receipts.
- Use server/database transactions or a single safe database operation for payment entitlement creation and meal redemption. Make payment/webhook handling idempotent and prevent race-condition double deductions.
- The backend, not the client device clock, decides whether a plan is active, a slot is open, a QR is valid, and credits remain.

## 2. QR security and attendance correctness

Provider generates a day-bound QR through the authenticated provider interface. A QR must be validated by the backend; never trust data encoded in a client-generated unsigned QR.

- Use a cryptographically signed, short-lived or otherwise replay-resistant token bound to provider, business date, and relevant slot/session. Prefer a rotating short-lived token if feasible. If product UX initially needs a daily QR, mitigate screenshot replay with expiry, token version/rotation, or explicit provider-side live refresh and document residual risks.
- A successful redemption must validate authenticated customer, provider approval/status, valid entitlement, date/time slot in the provider’s timezone, plan expiry, available credits, allowed meal/slot, token signature/expiry, and duplicate constraints.
- Enforce the duplicate rule in the database, not merely with a disabled button. Use transaction-safe constraints/locking so two concurrent scans cannot deduct two credits or create duplicate attendance.
- QR scan attempts that fail or are duplicates are not billable usage and never consume meal credits.
- Store a redemption ledger with timestamp, provider, customer, slot, entitlement, item/add-on snapshot, result/reason, and audit metadata. Protect it with proper RLS and minimal PII.
- Avoid relying solely on the customer scan as absolute proof of meal consumption. Design for a future provider confirmation mode, and document the limitation of scan-only validation.

## 3. Platform monetization and billing

Implement a transparent provider usage ledger based on this currently preferred pricing model, and centralize it in configuration so it can be changed without rewriting business logic:

- Charge the provider **₹25 per started block of 90 successful, unique meal redemptions per provider per local calendar day**: 1–90 valid redemptions = ₹25; 91–180 = ₹50; 181–270 = ₹75, etc. Zero valid redemptions = ₹0. This is per provider/day, not per failed scan. Display the formula clearly in provider pricing/terms and the dashboard.
- Example test: 90 successful redemptions on one day = ₹25; 91 = ₹50; 180 = ₹50; 181 = ₹75; 0 = ₹0. Across 30 days with exactly 90 redemptions each day, fee = ₹750.
- Record immutable daily counts and fee ledger entries, calculate server-side, use provider-local calendar dates and deterministic timezone handling. Reconciliations must be possible from successful redemption records.
- Prefer weekly/monthly consolidated invoices. Support manual UPI/payment checkout for invoices and optional authorized AutoPay/mandate only if a payment provider supports the use case and the provider explicitly opts in. Never attempt an unauthorized bank debit on each scan.
- Failed mandate/payment must create an outstanding invoice and notices/grace period; it must not unexpectedly erase customer meals that were already bought. Billing policy should be configurable and legally reviewed before live use.
- Never invent a Razorpay key or claim live payments are enabled without valid account credentials and verified webhook configuration. Implement Razorpay test mode if credentials are supplied through secure environment configuration. Clearly separate provider subscription/daily-meal checkout from platform billing. Never store raw card data.
- If payment credentials are absent, keep the app safe: local/test mode can use a conspicuously marked fake payment adapter with no real fulfilment; production must never mark an order paid via mock. Show checkout as unconfigured/unavailable or test-only in non-production. Record the exact variable names and the minimal next action in `docs/SETUP_BLOCKERS.md`.

## 4. Recommended architecture

Discover the existing code first and adapt sensibly; prefer the simplest maintainable architecture that matches what is already present. If no coherent implementation exists, use:

- **Web:** Next.js App Router + TypeScript + a consistent accessible component system. One deployable web app can contain public marketing/discovery, customer portal, provider portal, and admin routes if role boundaries are rigorously enforced. Use responsive mobile-first design. Do not duplicate code into three independently deployed websites without a reason.
- **Backend:** Supabase Auth, Postgres, Storage (private buckets/policies where appropriate), and Edge Functions or server routes for trusted operations/webhooks. Keep database schema and RLS changes in version-controlled SQL migrations.
- **Mobile:** Flutter customer and provider apps sharing the backend; keep dependencies pinned and include lockfiles. If mobile work cannot be built in this environment, complete source/tests/configuration and report build blocker accurately rather than claiming success.
- **Deploy:** Vercel for web and authorized Supabase resources for backend, with environment-separated preview/production settings. Choose the India region (Mumbai/ap-south-1) for new Supabase resources if free-tier/plan availability allows and no charges are introduced.
- **Repository:** create a new **private** GitHub repository named `thali-meal-marketplace` (or a better available product-specific name after checking) if none exists. Do not push to any unrelated repository. Do not commit `.env`, downloaded secret files, signing keys, Supabase service-role keys, customer data, or auth state.

Use stable, compatible, pinned dependency versions and commit lockfiles. Before choosing library APIs, check current official docs/version constraints. Do not blindly use old snippets.

## 5. Supabase schema and authorization requirements

Build normalized migrations for entities needed by the working feature set, including equivalent tables for:

- profiles/user roles stored in server-controlled data; provider/business records and onboarding/approval status;
- provider memberships/owner relationships, addresses/locations, meal slots, weekly/daily menus, menu items, portions, inventory/availability, add-ons and substitutions;
- plan definitions, plan inclusions/slot limits, customer subscriptions/entitlements, credit balances or immutable credit ledger;
- orders/order items, payment events/webhook idempotency, refunds/cancellations where implemented;
- QR/token metadata, meal redemption ledger, slot/date duplicate constraints;
- platform usage ledger, provider invoices and payments;
- support tickets and append-only audit events for sensitive admin operations.

Exact naming may differ if the existing schema is sound. Use foreign keys, constraints, sensible indexes, `created_at`/`updated_at`, status enums/check constraints where useful, and appropriate timezone-aware timestamps. Do not duplicate mutable balance state without a reconciliation ledger or a transaction-safe reason.

Security requirements:
- Enable RLS on all exposed tables. Write least-privilege policies for public discovery of approved providers/menus, customer-owned data, provider-owned businesses/data, and admin-only access.
- Do not treat a client-supplied `role`, `user_metadata`, business ID, price, fee, payment state, plan state, credit count, or QR payload as trusted. Derive authorization from server-controlled profile/role/membership data and verify all prices/statuses server-side.
- Do not rely on `TO authenticated` alone; add ownership predicates. For updates, use both `USING` and `WITH CHECK` where needed.
- Never make admin authorization depend on user-editable profile metadata. Admin must be provisioned by a secure, restricted bootstrap path or a server-managed admin assignment. No public admin signup or default admin password.
- Use Supabase publishable/anon key only in client apps where needed. Secret/service-role key stays server-side and must never have a `NEXT_PUBLIC_` prefix.
- Audit privileged operations. Protect storage uploads with content type/size validation and correct bucket policies. Avoid open buckets for private provider documents.
- Run Supabase security advisors/checks if available and fix serious findings before production.

## 6. Design direction

Use a polished Indian food/service marketplace aesthetic: warm off-white/cream background, dark navy text, restrained orange/gold accent, white surfaces, clear spacing, accessible contrast, strong typography, simple icons, subtle borders/shadows, and responsive layout. Design should feel trustworthy and operational, not like generic AI-generated SaaS.

Avoid purple gradients, excessive animation, giant cluttered hero sections, horizontal scrolling, fake counters, fake reviews, invented ratings, placeholder links, emoji in place of core interface icons, and overstuffed dashboard cards. Use the existing user-provided logo if available; do not substitute a random logo without reason. Add a proper favicon from the actual logo asset and remove unnecessary background if the correct asset is available.

Keep navigation simple and user-specific. For customers, prioritize active provider/plan, today’s meal status, nearby/browse/search, menus, scan, and history. For providers, prioritize today’s operations and the QR/attendance workflow. For admins, prioritize pending approvals, users/providers, payments/refunds, redemptions/usage billing, support, and audit trail.

Every screen must include loading, empty, error, and success states. Buttons must perform actual actions. Remove dead links and fake success toasts.

## 7. Environment and secrets setup

Create a safe `.env.example` containing names and non-secret placeholders only, along with a clear `docs/ENVIRONMENT.md`. Do not overwrite existing real `.env` files. Add `.env*` to `.gitignore` while allowing `.env.example`. Scan the repo and git history before push for exposed secrets.

Potential names (adapt based on real stack):
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` or the correct current publishable-key name
- `SUPABASE_SERVICE_ROLE_KEY` (server-only, if truly needed)
- `SUPABASE_PROJECT_REF`
- `ADMIN_BOOTSTRAP_EMAIL` (secure one-time server-side bootstrap only; do not hardcode it)
- `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` (server-side)
- `APP_BASE_URL`, `SUPPORT_EMAIL`, `PLATFORM_FEE_PER_90` and related policy config if appropriate
- `QR_SIGNING_SECRET` or equivalent managed signing secret stored only server-side
- any mobile app runtime configuration, without bundling privileged keys.

Use the connected integration’s secure variable-setting capability where it exists. For Vercel, create variables in the correct project and correct target environments, with least privilege; do not read/print values back just to verify them. For Supabase, use the official secret-management path/tools available. Do not put secrets in GitHub repository variables when an environment secret is more appropriate. Separate preview and production credentials.

For secrets that cannot be created by the integration, **do not fabricate them**. Identify whether the external provider account/verification/KYC is required, complete all non-secret setup, and give me a short checklist naming only the missing variables and exact dashboard/action needed. Never ask me to send those secrets in chat.

## 8. GitHub and deployment workflow

1. Inspect auth status of GitHub/Vercel/Supabase integrations and confirm the intended accounts/workspaces.
2. Create a new private GitHub repo if none exists; use an initial clean commit and meaningful commit messages. Use a feature branch if appropriate; do not overwrite unrelated repositories or upload compiled caches.
3. Add CI (GitHub Actions or the best platform-native approach): formatting/lint, typecheck, unit tests, database/static migration checks, frontend production build, dependency/security audit, secret scan, and relevant smoke/E2E tests. Pin CI actions/dependencies to reviewed versions where appropriate. Never give untrusted fork code access to deployment secrets.
4. Create a separate Vercel project linked to the new repo, and a separate Supabase project/database for this product if free/no-charge creation is allowed. Do not reuse the existing ReDo DB/projects. If account plan/permission blocks creation or charges apply, continue local code, migrations, tests, and repo work; document the exact blocker.
5. Apply migrations only to the new Thali Supabase project. Never run migrations against an existing unrelated project. Seed clearly labeled development fixtures only; do not seed demo users/businesses into production unless explicitly requested and clearly disclosed.
6. Configure environment-variable names and values through the authorized secure platform integrations. Production should be fail-closed if a required secret is missing.
7. Deploy a preview first if available. Run smoke tests and role/data-access checks against it. Fix problems. Deploy production only after all relevant gates pass and intended target is verified.
8. After deployment, check HTTP routes, browser console/network errors, server logs, auth callbacks, database permissions, payment/webhook configuration, and error monitoring. Do not claim live payments work when only test credentials are configured.
9. Add a small rollback/recovery note in `docs/DEPLOYMENT.md`. Keep destructive operations, database resets, deleting projects, domain purchases, paid plan changes, and irreversible migrations behind explicit confirmation.

## 9. QA plan — run, find bugs, fix, repeat

Do not stop after the first failure. Diagnose the root cause, implement the smallest correct fix, then rerun the failing check and the relevant suite. Do not repeatedly run the same failed command without changing the hypothesis. Continue until clean or until a truly external blocker remains.

Minimum automated tests:

### Auth/roles/RLS
- Logged-out customer cannot see private records or call protected routes.
- Customer A cannot read/change customer B’s profile, subscription, order, or history.
- Provider A cannot access or modify Provider B’s business, menus, subscriptions, attendance, invoices, or documents.
- A non-admin cannot access admin route/API/data.
- Changing user metadata or client-supplied role/business IDs does not grant permission.

### Plans, orders, credits, and menu
- Fixed-period plan expires by server-side end date and does not lose credit on attendance.
- Meal-credit plan decreases by exactly one only on successful valid redemption.
- Failed, duplicate, wrong-slot, wrong-provider, expired QR, unpaid orders, and canceled orders do not decrement a credit.
- Plan expires on the first of expiry time or zero credits, with displayed policy matching backend behavior.
- Daily paid entitlement is only created from verified payment/cash workflow.
- Sold-out add-on cannot be purchased; item price snapshots do not change after provider edits.
- Extras charge separately but do not deduct another full-meal credit.
- Double-click and concurrent scans/payments do not double-create entitlements or double-deduct credits.

### QR and billing
- Expired/modified/unsigned QR rejected; valid current token accepted.
- Duplicate redemption prevented by a database constraint/transaction, even under concurrent requests.
- Fee formula boundary tests: 0, 1, 90, 91, 180, 181 valid daily redemptions; failed/duplicate attempts do not count.
- Payment webhook signature validation and idempotency tested with provider test fixtures.
- Payment failures leave an unpaid/retryable invoice and never falsely confirm success.

### UX, accessibility, and operations
- Responsive mobile/tablet/desktop layouts; keyboard and focus support; accessible form labels and error feedback.
- Loading/empty/error/success states, direct URL refresh, 404 route, auth session expiry, and offline/failed-network recovery.
- Provider approval states and all role dashboards.
- Build/lint/typecheck/tests pass. Run Playwright or equivalent for primary user journeys where practical.
- Scan dependency vulnerabilities and secrets. Fix serious/high-confidence issues; record accepted residual risks.

Use realistic but clearly labeled test fixtures. Never publish fake business reviews, fake users/revenue, or fake marketplace activity as real production data.

## 10. Release acceptance criteria

Do not call the job complete until each applicable item has evidence:

- [ ] Existing workspace and prior starter files inspected; current state documented.
- [ ] New private GitHub repository exists and contains source, migrations, lockfiles, docs, and no secrets.
- [ ] New product-specific Supabase project exists (or external blocker documented), migrations applied, RLS/policies checked.
- [ ] Web public pages, customer flows, provider portal, and admin console are connected to real data/auth and protected by server-side authorization.
- [ ] Fixed-period, credit tracker, daily meal, configurable slots/menus/add-ons, and secure QR redemption rules are implemented and tested.
- [ ] Platform fee ledger uses successful unique redemptions and the stated ₹25-per-started-90-per-provider-per-day formula.
- [ ] Payment state is server-verified; no fake live payment; missing credentials are clearly documented.
- [ ] CI checks pass; production build passes; high-severity bugs fixed or listed as blockers.
- [ ] Preview deployed and smoke tested. Production deployed only if gates pass and no new paid action is required.
- [ ] Post-deploy routes/logs/basic health checked; README, setup, deployment, security, and status docs updated.
- [ ] Exact deployed URLs, repository URL, project identifiers (non-secret only), commit SHA, tests and any blockers reported.

## 11. Execution protocol

Start now. First produce a short discovery report from actual workspace and integrations, then immediately continue into implementation; do not wait for me after the report. Make a prioritized task list and work through it without asking me to approve ordinary implementation choices.

When a tool call fails, inspect its actual error and its current documented schema, then try a meaningfully different path. Stop after 2–3 repetitions of the same failure and report the real blocker rather than looping. Keep making progress on unrelated tasks.

If time/context is limited, prioritize in this order:
1. preserve/understand existing work and secure repository;
2. production-grade DB schema/RLS and real auth;
3. core subscription/daily-meal/QR transaction workflows;
4. customer marketplace + provider operations + restricted admin web;
5. automated tests/CI;
6. secure environment setup and preview/production deploy;
7. Flutter client parity, polish, observability, and extra features.

## 12. Final report format

When finished, give me:

- **Repository:** URL and branch/commit.
- **Deployment:** preview URL and production URL with honest status (`READY`, `BUILDING`, `ERROR`, or `BLOCKED`).
- **Backend:** project ref/name and region, migration/RLS status (no secrets).
- **Features actually implemented:** concise list.
- **Verification:** exact commands and test counts/results, web smoke-test result, security scan summary, and what was not tested.
- **Payment status:** not configured / test mode / live verified. Explain clearly; never imply live payment readiness without proof.
- **Missing external actions:** the smallest actionable list of missing OAuth approvals, provider account/KYC, secret variable names, or approval to incur a cost. Do not include secret values.
- **Known bugs/risks:** remaining items with severity and workaround.
- **How to run locally:** exact commands and required `.env` variable names.

Begin by inspecting the current workspace and connected integrations now. Then build, test, fix, and deploy what is safe and actually possible.
