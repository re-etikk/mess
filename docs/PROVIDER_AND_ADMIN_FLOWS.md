# Provider App and Admin Console — Screen Flow

## Provider mobile app

### Entry and registration
1. Splash / brand mark
2. Sign in: email/phone + password; Google OAuth below OR divider; register link; forgot password
3. Create owner account / verify email or phone using configured provider
4. Select business type: Mess, Restaurant, Home Tiffin, Hostel/Canteen
5. Business identity and documents
6. Location: address search/manual entry + optional map permission/pin
7. Opening hours and closure calendar
8. Meal slots: breakfast/lunch/evening/dinner/custom; serving start/end/cutoff
9. Select models: Fixed-period, Meal-tracker or Both; daily meal option separately
10. Plan duration and price configuration
11. Menu catalogue and weekly/daily menu setup
12. Included quantities, premium items, extras, substitutions, stock and sold-out rules
13. Draft offer editor
14. Customer-facing preview and platform terms/commission agreement
15. Submit application for verification
16. Review state: Draft / In review / Needs changes / Approved / Suspended
17. Only approved and published providers can accept live purchases/redemptions

### Post-approval tabs

**Overview**
- Today's serving status and configured meal slots
- Verified redemptions by slot
- Published menu / sold-out warnings
- Active subscription count and renewals due
- Gross sales vs platform/gateway fees vs payable vs actually settled
- QR status, recent activity and action-needed queue

**Menu**
- Choose slot and date
- Start from weekly template or edit today's menu
- Add item, category, dietary labels and image uploaded by provider
- Mark included, premium-plan-only, paid add-on or substitution
- Set quantity/unit, unit price, quantity cap/stock and availability
- Preview customer view and publish

**Plans**
- Fixed-period / tracker switches (one or both)
- 15 days, 1 month, 3 months, 6 months, 12 months
- Per duration: price, eligible slots, included items/portions, tracker credits, daily limits, validity/unused-credit policy, pause/refund/cancel policy and discount
- Daily-meal capability and price per slot
- Show explicit plan comparison and customer preview

**Daily QR**
- Server-issued QR for provider + Asia/Kolkata service date
- Service date, issued/expiry time, revoked/refresh state
- Do not let local app construct a redeemable token
- Counter screen shows only the operational QR and a privacy-safe redemption result

**More**
- Subscribers, meal attendance, earnings/settlements, offers, business profile, team permissions, support tickets, policies and sign-out

## Customer interactions that provider screens must support

- Customer scans provider QR at the mess, not the reverse.
- Backend resolves current slot from provider schedule and Asia/Kolkata time.
- Included items are covered by selected plan.
- Paid add-ons and extra servings are separate priced lines.
- Tracker plan consumes one credit only on confirmed eligible meal redemption.
- Fixed-period plan records attendance without deducting credits.
- Daily meal entitlement can only exist after verified payment.

## Admin console

1. Admin signs in using configured secure auth + MFA.
2. Role resolution happens on server, not client-side switches.
3. Overview shows real server-computed provider/customer/transaction/exception totals. Development data carries a demo banner.
4. Provider applications: inspect identity, location, applicable business documents, plan/menu setup, terms/commission agreement; approve, request changes or reject with reason.
5. Providers: inspect current status, published menus/plans, operational incidents, suspensions and owner/member permissions.
6. Customers: only necessary profile/account and support data; respect data minimization.
7. Plans & menus: review publication errors, unusual price/discount changes, sold-out state and rule violations.
8. Redemptions: investigate duplicate or disputed scans with signed audit context; never edit ledger rows directly.
9. Payments & settlements: gateway status, idempotent webhooks, refunds, financial ledger, reconciliation and payout status. High-risk actions require Finance role and maker/checker.
10. Offers: inspect effective dates, discount limits, stacking and suspicious redemption.
11. Support queue: triage by category, priority and SLA.
12. Team & roles: invite/remove member, role change, MFA requirement; privileged changes audited.
13. Audit log: append-only event view for admin/provider/financial mutations.
14. System health: API/database/auth/webhook/QR status from real health checks; not static fake green indicators.
15. Feature flags: restricted, audited, server-enforced rollout controls.

## Empty and error states

- No provider business: resume onboarding
- Onboarding pending: show checklist and review state; no live sales
- No menu today: set today's menu, do not display fake food items
- Slot closed/sold out: show the state and next real service slot
- QR not issued: generate through backend or display service error; never create a local production QR
- Payment pending: don't activate subscription or mark daily order paid
- No sales history: show a calm empty state, not fabricated charts
- Permission denied: explain missing role access and log the denial appropriately
