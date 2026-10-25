# 01 — Product Requirements Document (PRD)

**Product:** MESS  
**Tagline:** Your Meals. Your Choice.  
**Document status:** Build brief v1.0  
**Initial market:** College students, hostel/PG residents, young professionals and local tiffin customers in India.

## 1. Product summary

MESS is a local food subscription marketplace connecting customers with hotels, messes, restaurants and individual tiffin providers. Customers can buy a fixed-period meal plan, a meal-credit plan or a one-time meal. They choose pickup or paid delivery. Each eligible meal is recorded using a secure QR/OTP redemption flow, so the customer, provider and platform have a consistent record of meals used, balance, delivery and payment.

MESS is not merely a QR scanner. The core product is subscription management + verified meal redemption + optional delivery + provider operations.

## 2. Problem statement

Customers often pay for meals through informal monthly arrangements with limited visibility into plan expiry, meals used, holidays, delivery charges and complaints. Providers often track subscriptions and meal consumption manually. Customers and providers need a lightweight system that creates clear records without adding excessive work to the meal handover.

## 3. Product goals

1. Let a customer discover and compare nearby participating providers and plans.
2. Make plan conditions, dates, meal limits, cancellation terms and total charges visible before purchase.
3. Record each successful meal handover exactly once.
4. Support both pickup and paid delivery without mixing delivery charges with subscription food entitlement.
5. Give providers a fast workflow for plans, bookings, QR scans, customers, earnings and settlements.
6. Give delivery partners a simple assignment/pickup/drop-off workflow with privacy boundaries.
7. Give admins operational oversight, disputes, verification and financial reconciliation.
8. Test provider adoption and renewals before optimising commission or expanding geographically.

## 4. Non-goals for MVP

- National multi-city operations at launch.
- In-house rider fleet employment or vehicle management.
- Complex route optimisation or guaranteed real-time GPS in every build.
- AI recommendations, calorie tracking, social features or meal reviews as launch blockers.
- Full accounting software for providers.
- Unlimited meal plans without daily caps.
- Cash settlement through a personal bank account or unverified manual payout workflow.
- Claiming a QR proves the customer physically ate the meal; it proves a recorded redemption/handover event.

## 5. User roles

| Role | Needs | Primary surfaces |
|---|---|---|
| Customer | Find plans, pay, book, collect or receive food, track entitlements and resolve problems | Customer Flutter app + public/customer website |
| Provider owner/manager | Onboard business, publish plans, manage slots, redeem meals, check earnings | Provider Flutter app + provider web portal |
| Provider counter staff | Scan and validate a meal quickly, without seeing unnecessary financial/customer data | Provider Flutter app, restricted permissions |
| Delivery partner | Accept work, see assignment details, confirm pickup/delivery, see payout | Delivery Flutter app |
| Admin/operations | Verify providers, resolve issues, configure commissions, reconcile payments, audit activity | Admin web portal |
| Support staff | Investigate assigned tickets with least privilege | Restricted admin route group |

One person may hold multiple roles only if explicitly assigned by a trusted backend/admin process. Never infer roles from editable frontend profile metadata.

## 6. Core customer journeys

### 6.1 Discover and purchase
1. Customer enters location/address or selects a locality/pincode.
2. Browse eligible, active providers and their plans/menu.
3. View provider details, service hours, ratings only if real reviews exist, plan price, duration, meal slots, daily limits, holidays, pickup/delivery support and policies.
4. Select plan or a single meal.
5. Choose pickup or delivery where supported.
6. Review full price breakdown and terms.
7. Complete sandbox/live gateway checkout as configured.
8. Backend verifies payment before marking the purchase active/paid.
9. Show receipt and next steps.

### 6.2 Plan types

**A. Fixed-period subscription**
- Durations: 1, 3, 6 and 12 months (provider-configurable).
- Expires at a server-computed timestamp based on calendar-month arithmetic in the configured timezone. Interval is start-inclusive and expiry-exclusive.
- Meal count does not reduce a credit balance because the plan is time-based; however, daily/per-slot redemption limits still apply.
- Customer may eat zero or many eligible meals during the active period, subject to limits and provider schedule.

**B. Meal-credit subscription**
- Customer buys a defined number of meals (e.g. a configured 30-meal plan).
- A credit is consumed only after valid pickup redemption or successful delivery completion.
- A booking/reservation alone does not consume the credit.
- No-show/cancellation policy must be shown before purchase. MVP default: do not automatically deduct a credit merely because the customer did not arrive; record a missed/cancelled event and let policy rules govern exceptions.
- Prevent simultaneous bookings from overselling a scarce slot where capacity limits exist.

**C. Daily single meal (pay-as-you-eat)**
- Customer purchases a specific meal/menu item without a longer subscription.
- Price can be higher than equivalent subscription value.
- Payment must be verified before the order is treated as paid/accepted.
- Any included delivery fee is shown separately.

Do not label meal-credit tracking as GPS/live location tracking. It is meal usage tracking. Delivery location tracking is a separate feature.

### 6.3 Pickup redemption
1. Customer creates/opens an eligible booking.
2. Backend issues a short-lived, one-time QR token bound to the booking and provider.
3. Provider staff scans it while authenticated and authorised for that provider.
4. Backend validates customer, provider, slot/date, subscription/payment state, token expiry and prior redemption.
5. One atomic server transaction changes the booking to redeemed, inserts the redemption event and decreases meal credits if applicable.
6. Provider sees a clear success result and customer balance/history refreshes.
7. Replays, wrong-provider scans and concurrent duplicate scans fail without another deduction.

### 6.4 Delivery
1. Customer chooses delivery and an eligible address.
2. Backend checks provider coverage, availability, service hours and slot cutoff.
3. Checkout shows food/subscription amount and delivery charge separately.
4. A delivery order is created and payment for any due amount is verified.
5. A delivery partner is assigned/accepts the order.
6. Partner sees only information needed for the active assignment.
7. Partner confirms pickup, then completes drop-off using server-validated OTP/QR.
8. Backend atomically marks delivery complete and redeems the meal once.
9. Customer sees order status and receipt; provider sees completion and settlement ledger entry.

If a subscription covers the food, the customer must not be charged for the same food a second time. Delivery fee remains a separate payable item.

## 7. Provider capabilities

- Apply to join and submit business/contact/food licence details where applicable.
- Admin verification and activation.
- Manage business profile, address, operating hours, service areas and meal slots.
- Create/publish/pause meal plans and menu items.
- Set price, duration, meal credits, per-day/slot caps, holidays, booking cutoff, cancellation policy and delivery eligibility.
- View today's bookings and expected meals.
- Scan/validate QR codes and see success/failure reason.
- View active subscriptions, meal history, complaints and customer notes necessary for service.
- See gross sales, platform commission, refunds, net payable and settlement status as distinct values.
- View and accept explicit commercial agreement/commission terms before fee activation.

## 8. Delivery partner capabilities

- Apply and complete onboarding/verification required by the operating model.
- Online/offline availability toggle.
- View only eligible assignments.
- Accept/reject assignment, confirm pickup, update status and complete delivery.
- Read delivery instructions and navigate to drop-off.
- Access only the minimum customer contact/address data while assignment is active.
- View delivery history, earnings, adjustments, payout status and support options.
- Report failed delivery, unsafe address, customer unavailable or provider delay.

## 9. Website requirements

Public site: home, locality/provider discovery, provider profile, plan comparison, FAQ, support/contact, about, terms, privacy, cancellation/refund policy and food-safety/partner information as appropriate.

Customer portal: sign in, addresses, subscriptions, meal booking, QR/OTP, history, payments, delivery tracking/status, support and renewal.

Provider portal: onboarding, business profile, menu/plans, bookings/redemption activity, customers, delivery settings, earnings and settlements.

Admin portal: provider/rider approvals, user/support management, plan/content moderation, booking/redemption investigation, payment/refund/settlement views, commission rules, launch promotions and audit history.

All role portals must be protected server-side. Hiding a menu item in the UI is not authorization.

## 10. Commercial rules

- First 2 months: 0% provider commission promotional period, only under clear written/accepted terms.
- After the promotion: configurable 2–5% provider commission. Use 3% only as a test default if needed; do not bake it into code.
- Commission applies only to eligible transaction categories and terms explicitly agreed with each provider.
- Configure effective start/end timestamps, agreement version, accepted_at and rate in basis points.
- Delivery fee, rider payout and platform delivery fee are separate ledger values. A proposed 20% delivery-side commission is not final until rider willingness and per-trip economics are tested.
- Never deduct a provider commission twice or calculate commission from amounts that policy excludes (e.g. refunded amount, delivery fee if the provider commission is only on food).

## 11. MVP success metrics

Instrument these from the first pilot:
- Providers approved, active providers, and provider retention.
- Customer signups and first paid subscriptions.
- Paid conversion by provider/plan.
- First meal redemption rate and meals redeemed per active subscriber.
- Subscription renewal/retention by cohort.
- Failed/replayed QR scans and duplicate deduction count (target: zero duplicate deductions).
- Delivery acceptance, successful delivery, cancellation and incident rates.
- On-time meal readiness where measurable.
- Gross booking value, platform revenue, gateway cost, refunds, provider payable, rider payable and contribution margin.
- Support tickets per 100 bookings.

Do not optimise downloads alone; use completed paid subscriptions and repeat usage.

## 12. MVP acceptance criteria

- A real test user can discover a provider, view plan terms and complete a sandbox checkout.
- Payment success is confirmed server-side before activation.
- Fixed-period subscriptions expire on server-computed time and enforce daily/slot caps.
- Meal-credit purchases consume exactly one credit per successful meal redemption/delivery completion.
- Valid QR succeeds once; expired, replayed, wrong-provider and concurrent replay cases fail safely.
- Delivery charge is independently calculated and shown; subscription-covered food is not double charged.
- Provider and rider data boundaries are tested.
- Provider commission uses the agreed effective rule and produces auditable entries.
- Admin can review a payment, redemption, dispute and settlement trail.
- Critical flows work on mobile and web with loading, error, empty and success states.
