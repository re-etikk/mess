# MESS Provider App — Product Requirements Document

## 1. Purpose

Give mess owners, restaurants, canteens and home-based tiffin services one reliable place to set up their business, define the way they serve food, publish subscription plans, manage today's menu, display the daily provider QR, record customer meal redemptions, and reconcile earnings.

MESS is not a delivery app in the current release. The customer visits the provider and scans the QR displayed at the counter.

## 2. Provider types

The first onboarding step asks which service the provider operates:

- Student mess / regular thali
- Hotel or restaurant with subscription meals
- Home-based tiffin service (customer visits the listed pickup/serving point for this release)
- Hostel, college or workplace canteen

Provider type changes labels/defaults, not the core data model. Every provider must enter the actual serving location, address, city, operating schedule and contact information. GPS is optional if manual address search is available. The business should not publish until required verification is completed.

## 3. Roles

- **Owner:** business identity, documents, plans, menu, prices, offers, reports, approved payout details, team access.
- **Manager:** daily service operations, menu availability, attendance and customer support. No owner transfer or payout-bank change by default.
- **Cashier / counter staff:** display today's QR and view limited redemption results. Cannot modify plan pricing or access financial reports by default.
- **Menu editor:** menu items, portions, daily overrides and sold-out status only.
- **Finance viewer:** authorized sales, fees, settlement and export views; no payment destination changes.
- **Platform operations/admin:** provider verification, dispute investigation and platform configuration via separate web console and protected server APIs.

## 4. Onboarding flow

1. **Account:** email/phone + password or Google OAuth. Real authentication is required before production. No fake OAuth success.
2. **Business type and identity:** business name, owner contact, phone/email, business type and applicable food-business registration details.
3. **Location:** full address, locality, city, state, postal code, optional map pin/lat-long, operating area for discovery (no delivery zone in current release).
4. **Opening schedule:** weekdays, opening/closing times, holiday/closure dates.
5. **Meal slots:** breakfast, lunch, evening snacks, dinner or custom slots; starts/ends, cutoff, eligible days and per-slot redemption rule. Avoid ambiguous overlapping slots.
6. **Commercial model:** Fixed-period, Meal-tracker, or Both. Daily pay-as-you-eat is configured separately per meal slot.
7. **Plan durations/prices:** 15 days, 1 month, 3 months, 6 months, 12 months. Each duration has an owner-entered price, included meal slots, included portions, validity, discounts, pause and cancellation policy.
8. **Menu and portions:** reusable menu items, weekly menu template, date/slot menu, included quantities, optional paid extras, premium-plan-only items, substitutions/upgrades, stock and sold-out state.
9. **Offers:** optional discount code with validity, eligible plans, minimum order, usage limits and stacking rules.
10. **Preview and terms:** provider sees the exact customer-facing plan/menu/price. Accepts current provider terms and commission agreement. Submit for review.
11. **Approval and publish:** only eligible, approved provider data is discoverable. Draft/pending/rejected providers can edit but not sell live subscriptions.

## 5. Subscription models

### A. Fixed-period

- Valid for the selected duration after confirmed payment/activation.
- Does not consume a meal-credit balance.
- Still creates a redemption/attendance record for every valid meal.
- Must enforce included meal slots and configured per-slot daily limits. It must not imply unlimited serving.
- Calendar-month arithmetic for 1/3/6/12 months should be defined centrally; a plan started on the 25th expires on the corresponding date or month-end-clamped equivalent.

### B. Meal tracker

- Has a purchase credit count (e.g. 30 meals), current used count and remaining count.
- One credit is deducted only after a server-confirmed eligible redemption.
- A skipped day consumes no credit.
- Has a validity end date and credit balance; subscription ends at the first applicable limit. Terms must say what happens to unused credits.
- When credits reach zero, redemption is blocked and renewal/purchase actions are shown.

### C. Daily pay-as-you-eat

- Provider enables/disables daily sales per meal slot.
- Customer selects a specific date/slot and sees current menu + base price + optional extras.
- Creates a redeemable entitlement only after server-verified payment.
- Entitlement is bound to customer, provider, service date and slot; it is redeemable once.

## 6. Plan durations and prices

Offer durations only where the provider has configured them: 15 days, 1 month, 3 months, 6 months and 12 months. Never set common prices for all providers. Calculate and display total cost, per-meal equivalent when meaningful, discount amount, included slots, limits, pause policy, expiry, refund/cancellation terms and unused-credit policy. A longer plan can be discounted but savings must derive from a real provider-approved comparison price.

## 7. Menus, included quantities and extras

Every provider uses a single configurable rule engine; no custom code per mess.

- **Included base items:** e.g. dal 1 serving, rice 1 serving, roti 4 pieces, sabzi 1 serving, salad.
- **Plan-specific inclusion:** e.g. paneer included only in premium plan.
- **Paid special item:** e.g. paneer special +₹30 per serving.
- **Extra portion:** extra roti ₹5 per piece, extra rice ₹10 per serving.
- **Substitution/upgrade:** permitted only if provider enables it and the price difference is clear.
- **Availability:** quantity caps and stock are optional but, if configured, must be enforced. Sold-out items cannot be charged.
- **Snapshots:** purchased price, quantity, plan inclusion and item labels are saved to orders/redemptions and cannot change when the provider updates future menus.
- Add-ons are separately itemized and do not deduct another meal credit. A base meal and its extras must have clear payment/redemption states to prevent false charges.

## 8. Daily QR and attendance

- Backend issues one tokenized QR for a provider per local service date. Provider can display the same daily QR at the counter all day.
- The QR is not a static provider ID. It must be bound to provider + service date, signed or otherwise unforgeable and revocable.
- Customer app scans provider's QR. Provider app never scans a customer-generated QR in this workflow.
- Server resolves meal slot using provider-defined timetable and Asia/Kolkata service date. Ambiguous overlap returns a clear choice/error, not a guessed slot.
- Eligibility, plan credits, slot limits, provider status, payment status and duplicate keys are checked in one atomic server transaction.
- Unique redemption constraint: customer + business + service date + meal slot (unless provider's approved policy explicitly permits otherwise).
- Fixed-period redemption records attendance without credit deduction; tracker reduces one credit; daily entitlement is consumed exactly once.

## 9. Dashboard requirements

Overview should show only meaningful provider data:
- Today's redemptions by slot and slot status
- Today’s published menu and sold-out items
- Active subscriptions and renewals due
- Gross transaction value clearly distinguished from net payable/settled payouts
- Platform fee and gateway fee separately
- Recent redemptions and exceptions
- QR status for today
- Support, payment reconciliation and verification alerts

All financial/operational figures must come from live repository data. During development, label all sample fixture screens `DEMO`; never ship invented metrics or fake reviews.

## 10. Earnings and commission

Initial commercial proposal: 0% platform commission for the first two months, followed by an agreed, configurable 2–5% commission. This needs a provider-accepted agreement with effective date and rate. Fee calculations use immutable ledger entries and exact agreement terms. Do not retroactively alter completed transactions, silently start charging, or represent gross sales as profit. Gateway fee, refund and payout status must be separate.

## 11. Offers and promotions

Provider may create draft offers with:
- unique code and title
- fixed amount or percentage discount
- start/end date and timezone
- eligible plans/durations or daily meal slots
- minimum spend
- total redemption limit and per-customer limit
- first purchase / renewal condition, if supported
- stacking rule (default false)
- active, scheduled, paused, expired status

Server validates every promotion at checkout. Never display an unapproved draft as live or apply a discount only on the client.

## 12. Acceptance criteria

- Provider can register as mess, restaurant, home tiffin or canteen and store the actual location.
- Provider selects fixed-period, tracker or both and can separately enable daily meal for configured slots.
- Provider can create all required durations with explicit approved price/slots/rules.
- Provider can set included quantity, premium inclusion, paid extras, substitution, stock and sold-out state.
- Provider can draft/publish an offer with server-side validation.
- Provider can view today's server-issued QR; a demo QR must never redeem in production.
- Provider can see only authorized customers/redemptions and accurate earnings/payout states.
- Every privileged operation is server-authorized and audited.
