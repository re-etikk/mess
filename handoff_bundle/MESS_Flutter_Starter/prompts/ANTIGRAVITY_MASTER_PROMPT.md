# ANTIGRAVITY MASTER PROMPT — MESS PRODUCT INTEGRATION

You are the senior Flutter engineer, product engineer, backend engineer, UI/UX engineer, QA engineer and security reviewer responsible for finishing MESS. You must inspect and work in the existing repository; do not start an unrelated app and do not discard existing working code without reason.

## Product and scope

MESS is a student/customer meal-subscription and in-person meal-redemption platform for local messes, hostels and tiffin providers. **Delivery is out of scope for the current launch.** Customers eat at the provider's premises. The customer app scans a QR that is generated/displayed by the mess/provider app. Never reverse this direction.

The supplied `MESS_Flutter_Starter` code is a UI/navigation starter and state-machine demonstration. Use it as a starting point, merge it into the real project carefully, then connect every screen to the real backend. It currently uses `DemoMessRepository`, demo authentication and test checkout. Do not mistake those for production integrations.

## Non-negotiable design direction

- Brand name: MESS. Use the existing logo reference in `assets/branding/mess_logo_reference.png` as the visual source for app icon/website favicon, adapted professionally.
- Brand style: warm cream/off-white, dark navy, restrained orange and muted green success states.
- Professional, compact but not cramped. Consistent spacing, typography, control sizes, accessible labels and precise alignment.
- No purple gradients, pill-shaped controls everywhere, fake ratings/reviews, fake metrics/counters, vague hero copy, emoji icons, unnecessary animation, fake AI-generated food photography, cursor animations or “made with AI” labels.
- Use provider-uploaded images only. If no image is available, show a clean neutral icon placeholder, not fabricated food photos.
- No horizontal scrolling. Verify small-width layouts and safe areas. Add press feedback and subtle, short page transitions, but do not make the interface noisy.
- Every visible button, link, card action and navigation item must work or be clearly disabled with a reason. No placeholder actions silently doing nothing.
- Add clear loading, empty, success, error, offline and permission-denied states.
- App starts at login. Login offers manual email/phone + password, primary Sign in, Forgot password, then “Continue with Google” beneath an OR divider and a Register link. Google OAuth must be real/configured before release; never fake success.

## Required customer application screens

1. Login.
2. Register.
3. Forgot/reset password.
4. First-run location selection, with manual selection and optional permission request. Location permission denial must not block manual search.
5. Customer home dashboard with two dynamic states: active plan and no active plan.
6. Search by provider/mess name, dish name, cuisine and location; functional filters for meal slot, plan type, open status and relevant menu availability.
7. Provider detail with provider-supplied information, current day's menu, meal timings, included portions, paid extras/substitutions and plan options.
8. Plan selection and plan detail.
9. Daily meal checkout.
10. Subscription checkout and order confirmation.
11. Customer QR scanner (must scan provider QR).
12. Redemption result: confirmed, already redeemed, invalid/expired QR, out-of-slot, no entitlement, no credits, closed provider, network/server error.
13. Active subscription details and meal balance.
14. Meal redemption/history.
15. Profile, location, support, terms, privacy and sign-out.
16. Proper empty, expired-plan, exhausted-credit and offline states.

Keep bottom navigation predictable: Home, Search, central Scan, Plans, Profile. History is reachable from Profile and plan detail. Preserve deep/back navigation and restore sensible tab state.

## Home page rules

### Active subscription user
- Header with MESS mark, chosen location and notifications.
- Compact search bar for mess or food.
- One active-plan summary: selected provider, plan type, included meal slots, expiry date and (only for tracker plans) total/used/remaining meal credits.
- Today's date and only the meal slots offered by that provider.
- Each meal slot displays its provider-configured serving time and status: Upcoming, Available, Redeemed, Ended, Not in plan or Unavailable.
- A prominent central Scan action. It must only open the camera when a valid subscription with remaining credits or a verified paid daily-meal entitlement exists. If a tracker has zero credits or the plan expired, gate the scanner and offer Renew/Buy today's meal/View plans instead.
- A compact “Today's menu” list, not a large bulky promo card. It must show which items/portions are included and clearly mark extra-price items. Only show the appropriate meal slot and today's provider data.
- Nearby providers ranked by actual availability/relevance/distance, not invented popularity or fake ratings.

### No subscription user
- Do not display an active-plan card with fabricated values.
- Show a concise “Find a meal today” entry point and discoverable mess/food search.
- Show today's available menus with actual daily price, included menu/portion information and a “Buy today's meal” action where the provider offers daily purchase.
- Show provider plans without unlocking scan access. Scanner tap must explain the prerequisite and direct the user to a daily purchase or plan.

## Business rules: implement on the server, mirror in client UI

### Provider configuration/onboarding
Provider register flow must let each mess choose to offer:
- Fixed-period subscription.
- Meal-tracker subscription.
- Either one or both.

Daily pay-as-you-eat is a separate provider capability that can be enabled/disabled per meal slot.

For every enabled subscription model, provider configures durations of 15 days, 1 month, 3 months, 6 months and 12 months, each with provider-approved price, eligible meal slots, portion/inclusion rules, validity rules and optional discount. Never hardcode the same prices for every provider. Validate dates, non-negative prices, slot choices and required fields before publishing.

Provider then configures:
1. Business identity, address, opening/closure times and required food-business registration details.
2. Meal-slot schedule (breakfast/lunch/dinner/custom), local service time, cutoff and serving window.
3. A weekly recurring menu template and date/slot-specific overrides.
4. Included items, portion quantities, optional extras, substitutions/upgrades, quantity limits and stock availability.
5. Plans, policy text, prices and discount approvals.
6. Review customer-facing preview, accept platform terms and submit for review/publication.

### Plan model A: fixed-period
- Starts at confirmed activation; 1/3/6/12-month durations use calendar-month arithmetic so a plan started on the 25th normally expires on the corresponding day of the next eligible month, clamping to month-end when that day does not exist. Use a clearly defined Asia/Kolkata date-boundary policy.
- Does not deduct meal credits.
- Still records attendance/redemption and prevents duplicate redemption according to provider-configured daily slot limits.
- A valid fixed-period plan does not imply unlimited meals. Enforce eligible slots and per-slot limits.

### Plan model B: meal tracker
- Stores total credits, used credits and remaining credits.
- A credit is deducted only after a confirmed eligible meal redemption.
- Skipping a day consumes no credits.
- Validity end date and credits are both enforced; the plan stops when the first limit is reached. Show expiry/unused-credit terms before purchase.
- When credits reach zero, the app must block scanning/redemption and show renew/re-purchase actions. Do not show the scanner as eligible.

### Daily meal purchase
- The provider may sell a single meal only for configured slot(s), and may set a different price by slot.
- A daily entitlement is created only after a verified payment result, ideally confirmed by a signed server-to-server gateway webhook.
- It is bound to provider, service date, meal slot and customer. It can be redeemed once.

### Menus, fixed portions, special food and extras
Support provider-configurable rules without custom code per mess:
- Included items and quantities (e.g. 4 roti, one rice serving, dal, sabzi).
- Premium items included only for certain plans.
- Optional paid special dishes (e.g. paneer) with prices and stock/availability.
- Extra portions charged by item/unit (extra roti, rice or repeat serving).
- Allowed substitutions/upgrades and the price difference, if the provider offers them.
- Items marked sold out/unavailable; do not charge for unavailable items.
- Display an item/portion/price breakdown before payment. Respect the plan rules at the redemption/order endpoint. Never assume that all provider menus are interchangeable.
- Add-ons are separate line items and must not deduct an extra meal credit. They must be associated with the eligible meal/order. Avoid double collection or a base meal being falsely marked redeemed when add-on payment fails.
- Store immutable price/quantity/inclusion snapshots for completed orders and redemptions. Future menu edits must not rewrite history.

## QR generation and redemption — critical

Provider-side app/dashboard generates one date-bound QR token per provider per service day. The same QR may remain visible all day; it must never be a static provider ID alone. Use an unpredictable, signed/tokenized value bound to provider and service date. Server validates signature/expiry and never relies on client validation alone.

Customer-side exact flow:
1. Student opens MESS and taps the central Scan action.
2. If no valid subscription/credits or no verified daily entitlement exists, do not open camera; show Renew/View plans/Buy today's meal.
3. Camera scans the QR displayed by the mess, not a customer-generated QR.
4. Backend validates the QR token, provider, date, customer's eligibility, selected plan entitlement, meal slots, redemption policy, provider opening/closure status and duplicate restrictions.
5. Determine the current meal slot using provider-configured timetable and server time in Asia/Kolkata. If no slot is active or slots overlap ambiguously, return a clear message or ask the student to choose from valid slots. Never silently assign breakfast/lunch/dinner by a hardcoded generic time.
6. Show the actual provider menu for the current slot, clearly separate included portions and extras, and collect optional add-on choices/charges if the provider allows it.
7. Confirm redemption using one atomic server-side operation. For tracker plans deduct one credit, for fixed-period plans record attendance without credit deduction, and for daily plans consume the one-time entitlement.
8. On success show provider, slot, date/time and balance. On error show a specific reason and preserve state.

Must prevent replay/concurrency: add database uniqueness/transactional controls for the allowed redemption key (customer + provider + local service date + meal slot, adjusted only if provider rules permit more). Two concurrent scans must not deduct two credits. Provider's QR reuse across the day must still permit each eligible customer to redeem their own allowed slot.

Local demo payloads such as `MESS_DEMO|...` may only exist in demo mode. Never accept these in production. Never mark a meal redeemed on the client before the server confirms it.

## Payments and revenue
- Implement a payment service abstraction and use a real, approved gateway sandbox during integration.
- A front-end success screen/redirect is not proof of payment. Verify transaction status server-side and through signed webhooks. Add idempotency and reconciliation.
- Split/ledger the subscription price, platform commission, provider payable, add-ons, refunds and settlement separately.
- The initial business proposal is 0% commission for the first two months and then an agreed, configurable 2–5% provider commission. This must be transparently agreed by providers and recorded; do not silently start fees or retroactively change completed transactions.
- No delivery functionality for the current release.
- Do not place secrets in the Flutter app, public environment variables or committed files. Add `.env.example` without real secrets and document missing onboarding/credentials.

## Architecture requirements
- Preserve the existing architecture where sane, but separate UI, models, state, repositories, auth, payment, QR validation and server APIs.
- Use typed models and repository/service interfaces. `DemoMessRepository` is only for local UI testing and must be replaced with real API/Supabase backed implementation.
- If Supabase is the existing backend: verify current official docs, create versioned migrations, enable Row Level Security on exposed tables, write ownership/role-specific policies, and test allowed and denied access. Never expose `service_role` in the app. Put sensitive redemption/payment logic in a trusted server function or backend transaction.
- Keep authoritative prices, roles, meal balances, slot times, provider policies and payment status on the server.
- Avoid one giant file. Use feature-based folders, reusable components, a design system and typed navigation.
- Use semantic buttons, accessibility labels, validation and reasonable error recovery.

## Website and provider/admin surfaces
Inspect the repository and the previous product blueprint for existing web assets before building. The connected product must include:
- Public customer website: provider discovery, menu/plan details, legal pages, support and responsive navigation.
- Customer web account/plan/history where intended by product requirements.
- Provider portal and/or provider Flutter app: registration, provider-selected plan setup, daily menu/portion/add-on management, today's QR display, attendance and settlement views.
- Admin dashboard: provider review, reports, disputes, payment/commission ledger, configuration and audit logs.
- Reuse a shared backend and business rules; no duplicate pricing or redemption logic in web and app.
- No horizontal scrolling, broken links, dead buttons, fake counters or placeholder text. Add mobile menu, clickable logo, page titles, meta descriptions, custom 404, footer/legal links, correct copyright year and favicon based on the supplied MESS logo reference.
- Privacy/Terms screens must be clearly treated as draft until reviewed; do not fabricate compliance claims.

## Iterate without stopping at the first mockup
Work in phases. At each phase:
1. Inspect repository/code/schema/current runtime.
2. Write/refresh the task checklist and dependency map.
3. Implement the next complete user journey, including loading, success and error cases.
4. Run formatter, analyzer, type checks, unit and integration tests that are available.
5. Run app/web and inspect at phone, small phone and desktop widths as applicable.
6. Fix all discovered errors and rerun tests.
7. Update checklist with verified status only.
8. Continue to the next phase. After two or three identical failures, investigate logs/docs rather than retrying blindly.

Recommended build order:
1. Audit the current repo and merge supplied Flutter starter without overwriting user configuration.
2. Lock down models and server-side rules for plans, meal slots, menus, portions, extras and entitlement.
3. Database migrations, RLS, auth and provider onboarding.
4. Customer login/register and common navigation.
5. Home states with and without a subscription; search and provider details.
6. Provider plan/menu setup and daily QR generation.
7. Customer scanner and atomic redemption, then tracker balance/history.
8. Plan/daily meal purchase, add-ons, sandbox payment webhook verification and refund handling.
9. Provider attendance and admin financial views.
10. Public website and responsive/customer web surfaces; connect to same APIs.
11. Security, accessibility, regression, release build and documentation.

## Acceptance tests that must actually run
- A fixed-period plan records allowed daily slot redemption but never reduces credits.
- Tracker plan consumes exactly one credit after successful scan; skipped days consume zero.
- No-credit/expired/no-plan user cannot redeem and scanner access is gated.
- Daily meal entitlement is unavailable before verified payment.
- One QR works during its service date for different eligible customers, but cannot be reused to redeem the same customer's same slot twice.
- Concurrent scans cannot double deduct.
- Wrong provider/date/signature and out-of-slot scans fail with a readable reason.
- Included food and all extras/quantities/prices match the selected plan and day's provider menu.
- Sold-out items cannot be purchased. Add-on payment failure does not create a false paid add-on/redemption.
- Search by provider name and by food item both work.
- All navigation/buttons are actionable; no overflow or horizontal scroll on small screens.
- Payment webhook signature/idempotency, refunds, role isolation, RLS and audit trail pass tests.
- Run `flutter analyze`, `flutter test`, and a debug Android build when Flutter/platform SDKs are available. Also run all web checks if web code is present.

## Report honestly
Do not say “complete” unless you executed the relevant checks. If a credential, external approval or unavailable runtime blocks work, finish independent tasks and state the exact blocker. At the end report changed files, implemented journeys, tests actually executed and outcomes, unresolved bugs, required environment variables, setup commands, and production blockers.

Start by inspecting the repository and reading the supplied starter README. Then begin implementation; do not stop after creating another plan.
