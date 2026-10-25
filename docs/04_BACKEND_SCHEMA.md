# 04 — Backend Schema and Data Rules

The corresponding proposed SQL migration is at `supabase/migrations/20261024000100_mess_core_schema.sql`. Review and run it only after comparing it with the actual repository, current Supabase/Postgres version and test environment.

## 1. Schema principles

- PostgreSQL is the source of truth for roles, entitlements, booking/payment state, redemption and financial ledger.
- All user-facing entities use UUID primary keys.
- Money is integer paise; display as INR only in clients.
- All stored timestamps are `timestamptz`. Store service-day separately where local meal dates matter.
- Historical pricing/terms on a transaction are snapshots; do not retroactively change old booking totals when a plan price changes.
- Use foreign keys, CHECK constraints, unique constraints and appropriate indexes.
- Financial activity is auditable and effectively append-only; corrections use reversals/adjustments.
- Apply RLS and explicit grants for every exposed table; no broad `authenticated can do everything` policy.

## 2. Main entities

| Entity | Purpose / important fields |
|---|---|
| `profiles` | Application profile for an auth user; no client-editable role field |
| `user_roles` | Trusted role assignments: customer, provider, delivery partner, admin, support |
| `customer_addresses` | Customer-owned saved addresses and delivery instructions |
| `providers` | Business profile, owner/status, timezone, contact, food licence/reference and approval state |
| `provider_memberships` | Maps user to provider with owner/manager/counter-staff permissions |
| `provider_service_areas` | Pincode/locality/zone or radius used for discovery and delivery eligibility |
| `provider_operating_hours` | Weekly schedule and closure windows |
| `meal_slots` | Lunch/dinner/etc. windows, cutoffs, capacity and active state |
| `menu_items` | Provider-owned meals/combos, description, price and availability |
| `subscription_plans` | Fixed-period or meal-credit plans, price, duration/credits, terms and status |
| `plan_meal_slots` | Slot eligibility for a plan |
| `subscriptions` | Customer purchase snapshot, start/expiry/status, initial/remaining credits |
| `meal_bookings` | One meal booking for a subscription or single-meal purchase; pickup/delivery and price snapshot |
| `qr_redemption_tokens` | Hashed, purpose-bound, short-lived one-time token per booking |
| `meal_redemptions` | Immutable record of successful meal redemption/handover; unique booking |
| `delivery_partner_profiles` | Partner verification/availability and payout onboarding status |
| `delivery_assignments` | Booking-to-partner relationship and legal delivery state transitions |
| `delivery_location_events` | Optional short-retention delivery location samples; only when tracking is enabled |
| `payment_transactions` | Gateway order/payment reference, purpose, amount, state and idempotency key |
| `payment_webhook_events` | Gateway event ID, verification state, processing outcome and sanitized metadata |
| `refunds` | Separate refund records tied to a payment transaction |
| `platform_commission_rules` | Effective-dated, configurable basis-point rules by transaction category/provider |
| `commercial_agreements` | Accepted commission/promotion terms, version, rate and dates |
| `financial_ledger_entries` | Provider/platform/rider/gateway financial event ledger |
| `provider_settlements` | Period totals and status for provider settlements |
| `provider_settlement_items` | Ledger entries included in a settlement |
| `delivery_payouts` | Delivery partner payout/adjustment records |
| `notifications` | In-app notifications and read status |
| `support_tickets` | Customer/provider/rider issues, assigned staff and resolution |
| `audit_logs` | Sensitive actions and overrides, actor, subject, reason and timestamp |
| `idempotency_records` | Durable idempotency keys for critical operations where needed |

## 3. Core relational rules

- A provider owner/manager/counter staff record must reference one provider and a trusted user.
- A subscription must reference the provider and plan that were purchased, and should retain price/terms snapshots.
- `fixed_period` subscriptions have start/expiry timestamps; meal-credit plans also have initial/remaining credits.
- A meal booking belongs to one customer and one provider; it may reference a subscription or be a single-meal purchase, never both without explicit modelling.
- Delivery requires a valid delivery address snapshot and a delivery fee. Pickup does not have a delivery fee.
- A QR token has a single booking, provider and purpose; raw tokens are never stored in a table or logged.
- `meal_redemptions.booking_id` is unique. A booking cannot be redeemed twice.
- Each payment webhook provider event ID is unique; duplicate webhooks must return the prior processing result.
- A delivery assignment must refer to a valid booking and an authorised delivery partner.
- Commission rule is selected by effective date and transaction category; applied rate and base amount are copied into ledger/settlement records.
- Refund entries never erase original payment or ledger records.

## 4. Money and commission

Use `BIGINT` paise values for all amounts. Use integer basis points for percentages: 2% = 200 bps, 3% = 300 bps, 5% = 500 bps, 20% = 2000 bps. Round according to a single documented server-side rule; record calculated commission base and amount for audit.

Separate at minimum:
- Food/plan amount.
- Amount covered by an existing subscription (not charged a second time).
- Discount.
- Tax if applicable and configured by qualified advice.
- Delivery charge.
- Gateway fee (as reported by gateway where available).
- Provider commission.
- Platform delivery fee/commission.
- Rider payout.
- Refund/reversal.
- Provider net payable and rider net payable.

Do not assume all these amounts are known at checkout; estimates and final reconciliation may differ. Clearly label estimates. Never use a client-provided amount as authoritative.

## 5. Transaction boundaries

### Payment verification
1. Verify gateway callback/webhook signature.
2. Insert or claim unique event/idempotency key.
3. Fetch/verify authoritative gateway order/payment state.
4. Lock the associated pending transaction/booking/subscription.
5. Apply state change once; activate subscription or mark booking paid.
6. Insert financial ledger entry/commission calculation as appropriate.
7. Mark webhook processed and return success.

### Pickup redemption
1. Hash incoming token and locate unexpired unconsumed token.
2. Lock token and booking.
3. Verify actor membership for the exact provider.
4. Verify booking/subscription/slot/payment eligibility.
5. Insert one redemption record with unique booking ID.
6. Decrease one meal credit if applicable, with a guard against balance < 0.
7. Mark token used and booking redeemed.
8. Commit as one transaction.

### Delivery completion
1. Verify authenticated partner and exact active assignment.
2. Verify valid one-time OTP/QR, assignment status and booking eligibility.
3. Lock assignment and booking.
4. Insert delivery completion event and redemption once.
5. Decrease meal credit if applicable.
6. Write rider/provider/platform ledger entries according to agreed rule.
7. Commit atomically; duplicate request returns prior result.

## 6. RLS matrix (policy intent)

| Data | Public/anon | Customer | Provider staff | Delivery partner | Admin/support |
|---|---|---|---|---|---|
| Active public provider/menu/plan | Read public fields only | Read | Own provider + public | Public fields only | Server-authorized |
| Own profile/addresses | None | Own rows | Own profile | Own profile | Restricted support/admin |
| Subscriptions | None | Own rows | Own provider subscriptions, minimal fields | None | Server-authorized |
| Bookings | None | Own rows | Own provider bookings | Only active assigned bookings, minimal fields | Server-authorized |
| QR tokens | None | No raw stored token access; get token through endpoint | Validate through endpoint, no bulk token read | Validate delivery token through endpoint | No raw token access; audit metadata only |
| Redemptions | None | Own history | Own provider history | Only assigned delivery history | Server-authorized |
| Payments/ledger/settlements | None | Own transaction/receipt fields | Own provider summarized finance/settlements | Own payout summaries | Restricted server-authorized access |
| Roles/memberships | None | Read own role/membership as needed | Read own provider membership | Read own verification state | Mutations via admin service only |
| Audit/webhook/raw gateway events | None | None | None | None | Restricted server-side only |

This is an intent matrix, not a substitute for executable policies. Build `supabase/tests` tests for allowed and denied cases across all roles. Do not enable production until RLS/grant audit is clean.

## 7. Schema evolution rules

- Use new timestamped migration files; do not hand-edit already-applied production migrations.
- Test migrations on a development/staging database first.
- Avoid destructive migrations without explicit approval, backup and rollback/forward-fix plan.
- Re-generate client types after schema changes.
- Add tests for new constraints, grants, RLS and transaction logic.
