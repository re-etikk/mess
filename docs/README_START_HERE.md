# MESS — Antigravity Handoff Pack

This folder is the product and engineering source of truth for building **MESS**, a food/mess/tiffin subscription marketplace for India.

## Read these files in order

1. `docs/01_PRD.md` — what to build, who it serves, business rules and scope.
2. `docs/02_TRD.md` — target architecture, stack, environments and system requirements.
3. `docs/03_APP_WEBSITE_FLOWS.md` — user journeys and state transitions for all apps and web portals.
4. `docs/04_BACKEND_SCHEMA.md` — entity model, invariants and API boundaries.
5. `docs/07_API_CONTRACT.md` — endpoint responsibilities and request/response expectations.
6. `docs/05_IMPLEMENTATION_PLAN.md` — phase order, dependencies and acceptance gates.
7. `docs/06_SECURITY_TESTING_RELEASE.md` — security, tests, operations and launch gates.
8. `supabase/migrations/20261024000100_mess_core_schema.sql` — proposed initial database migration. Review it against the actual repository and current Supabase docs before applying.
9. `prompts/ANTIGRAVITY_MASTER_PROMPT.md` — paste this into Antigravity after opening the repository root.
10. `prompts/LOOP_CONTINUE_PROMPT.md` and `prompts/RELEASE_AUDIT_PROMPT.md` — use to continue and independently audit work.

## Product decisions already made

- Brand: **MESS**. Tagline: **Your Meals. Your Choice.**
- Three separate Flutter Android apps: Customer, Provider, Delivery Partner.
- One Next.js web application may contain the public site/customer portal, provider portal, and admin portal in separately protected route groups. Keep route-level authorization and UI boundaries clear.
- Shared backend: Supabase Auth + PostgreSQL + Storage + server-side Edge Functions. Do not duplicate core business rules across clients.
- Food plans: fixed-period subscription and meal-credit subscription. Daily pay-as-you-eat is a single-meal purchase, not an unlimited subscription.
- Pickup and delivery are both supported. Delivery charge is separate from food price and subscription entitlement.
- Launch offer: 0% provider platform commission for the first 2 months under clear written terms. Thereafter, configurable 2–5% provider commission, only after the provider agrees. 3% can be used as a test default in development, not as an unchangeable production rate.
- Delivery partner/platform fee split is configurable and needs local economics validation. Do not hardcode a 20% rider deduction.
- Payment confirmation, QR redemption, meal-credit deduction, delivery completion, settlements and refunds are server-authoritative.

## Important build discipline

This pack is an implementation brief, not a claim that external integrations are approved. Use sandbox payments until gateway onboarding, KYC, settlement model and required compliance checks are complete. Never put secret/service-role keys in a client app. Never mark a feature complete without running the relevant tests.

Supabase's current guidance says exposed tables need explicit grants and RLS policies; policies do not replace grants. Verify the migration and access policies with current official docs and tests before production. References: https://supabase.com/docs/guides/database/postgres/row-level-security and https://supabase.com/docs/guides/functions.

## Instructions for Antigravity

- Inspect the existing workspace first. Preserve working code and configuration.
- Treat the docs as requirements, but improve the design when there is a clear technical reason; update the docs and explain any material deviation.
- Implement in phases. Keep a task ledger with status: NOT STARTED / IN PROGRESS / BLOCKED / VERIFIED.
- A screen with mocked data is not a complete feature. Connect flows end-to-end or clearly label the remaining integration as blocked.
- Stop before destructive database operations, production deployments, live payments, or real user notifications unless explicitly authorized.
