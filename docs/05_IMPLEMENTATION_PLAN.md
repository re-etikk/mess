# 05 — Implementation Plan and Verification Gates

## 1. Build strategy

Build in vertically complete slices, not as a large set of disconnected screens. The target is three Flutter apps plus a website/portals, but the first priority is one complete customer-to-provider transaction end-to-end. Keep a living checklist and loop after every phase: inspect → implement → run checks → exercise flow → fix → rerun → mark verified.

## 2. Phase plan

### Phase 0 — Repository discovery and decisions
**Tasks**
- Inspect repo, existing app(s), package manager, Flutter/Node versions and existing design.
- Check environment files without printing secrets; record missing configuration variable names only.
- Map implemented vs missing requirements.
- Decide monorepo layout based on existing work; avoid destructive rewrite.
- Create `docs/DECISIONS.md`, task checklist and local run instructions.

**Exit gate:** architecture plan and repo inventory exist; no working code/config deleted.

### Phase 1 — Foundations and design system
- Set brand tokens for MESS (navy, orange/gold, warm cream, white, restrained green).
- Set responsive web shell and separate route groups.
- Build shared Flutter UI/API/model packages where useful.
- Set environment validation and `.env.example`.
- Configure lint, formatting, type checks, Flutter analyzer and test commands.

**Exit gate:** web build and each Flutter project scaffold can run; no fake “production-ready” integration claims.

### Phase 2 — Database, auth and security first
- Review proposed SQL and create versioned migrations using actual Supabase CLI workflow.
- Add tables, constraints, indexes, grants and RLS.
- Implement profile and trusted role assignment.
- Implement provider membership isolation and rider assignment rules.
- Add policy tests for allowed and denied access.

**Exit gate:** DB migrations apply to dev cleanly; RLS tests run and pass for core data boundaries.

### Phase 3 — Provider onboarding and public discovery
- Provider apply/edit profile, service area, opening hours, slots, menu and plan editor.
- Provider status/approval workflow.
- Public website discovery, provider detail, plans and transparent policy display.
- Seed development-only test providers.

**Exit gate:** approved provider can publish a plan; public site shows only active/published eligible provider content.

### Phase 4 — Customer purchase + payment sandbox
- Customer auth/address.
- Plan detail/checkout and single-meal checkout.
- Gateway adapter and sandbox checkout creation.
- Signed callback/webhook verification and idempotency.
- Purchase receipt, pending/failed/success states.

**Exit gate:** subscription stays inactive before verified success; duplicate callback doesn't duplicate activation or ledger entries.

### Phase 5 — Meal booking, QR redemption and balances
- Fixed-period subscription expiry and per-day/slot limits.
- Meal-credit entitlement/ledger logic.
- Meal booking calendar/cutoffs/capacity.
- QR issuance, scanner, result screen and redemption transaction.
- History and provider today's bookings.

**Exit gate:** valid scan redeems once; replay, expiry, wrong provider and concurrent scans fail without duplicate deduction.

### Phase 6 — Delivery and payouts/fees
- Delivery zone/pincode support and fee quote.
- Customer delivery checkout with separate food/delivery amounts.
- Delivery partner onboarding/approval/availability.
- Assignment accept/reject, pickup, OTP/QR drop-off and status timeline.
- Atomic delivery completion + meal redemption.
- Rider/provider/platform ledger entries; payout reporting.

**Exit gate:** no delivery marked delivered without server verification; credits are not double-deducted; out-of-zone cases are rejected.

### Phase 7 — Finance, commissions and admin
- Configurable provider commission and 2-month promo agreements.
- Terms acceptance and effective date handling.
- Financial ledger, refund records, provider settlements and rider payouts.
- Admin verification, ticket triage, dispute/search tools and audit logs.

**Exit gate:** test transactions produce correct expected ledger/commission/settlement totals, including refunds and promotion expiry.

### Phase 8 — Complete all app and web surfaces
- Wire customer app, provider app and delivery app to already tested contracts.
- Complete mobile UX, push/in-app notification adapter and retry/loading states.
- Complete public website, customer portal, provider portal and admin portal.
- Avoid rebuilding business logic separately in each client.

**Exit gate:** same critical rules behave consistently across app and web; role access tests pass.

### Phase 9 — Hardening, QA and pilot
- Unit/integration/E2E/security tests.
- Build and run all Flutter apps, web build and Supabase tests.
- Check mobile layouts and web routes.
- Add crash/error monitoring and backups/runbook.
- Test with fake/sandbox data and small controlled provider pilot.
- Measure metrics in PRD; fix highest-impact problems.

**Exit gate:** no known critical/high security bugs, core acceptance criteria pass, external blockers documented, production launch explicitly approved.

## 3. Task-tracking format

Every task must have:
- ID and phase.
- Description.
- Dependencies.
- Files/routes/database changes.
- Test command(s).
- Status: `NOT STARTED`, `IN PROGRESS`, `BLOCKED`, `VERIFIED`.
- Evidence of verification (actual command result / test case).

Do not mark `VERIFIED` because code was written. It must have been run and checked.

## 4. Continuous loop prompt

After each phase, Antigravity should:
1. Inspect repository diffs and runtime state.
2. Compare implementation against PRD/TRD/flow and schema docs.
3. Select the highest-priority unfinished item or failure.
4. Implement only a coherent slice.
5. Run lint/type/analyzer/tests/build appropriate to changed code.
6. Exercise the user flow manually/browser automation if available.
7. Review security and error paths.
8. Fix failures and rerun affected checks.
9. Update checklist, decisions and remaining blockers.
10. Continue without repeating work already verified.

After 2–3 failed attempts on the same issue, inspect logs/docs and change the approach; do not repeat a failing command indefinitely.

## 5. Priority order when time/context is limited

P0: auth/role boundaries, payments, entitlements, QR replay prevention, delivery completion, RLS and money ledger.  
P1: provider onboarding, plan management, customer discovery/checkout, history and admin verification.  
P2: notifications, refined analytics, map/live tracking and aesthetic polish.

Never trade P0 correctness for a more polished UI.

## 6. Suggested demo script

1. Sign in as a seeded customer and browse active provider.
2. Buy a meal-credit plan with sandbox payment.
3. Confirm no activation before server payment verification.
4. Book a pickup meal and show QR.
5. Sign in as provider counter staff and scan it.
6. Confirm exactly one credit is consumed and history updates.
7. Replay the same QR and confirm rejection.
8. Create a second booking for delivery and pay delivery fee in sandbox.
9. Assign a seeded rider, accept, mark picked up and complete OTP.
10. Confirm single meal redemption, delivery status and ledger entries.
11. Sign in as provider owner and view commission/payout summary.
12. Sign in as admin and inspect audit trail.
