# 07 — API Contract Responsibilities (MVP)

This is a domain-level contract, not a claim that routes already exist. Antigravity should implement typed request/response schemas and preferably maintain an OpenAPI 3.1 file matching the implemented endpoints. All paths below are illustrative; preserve consistency once selected.

## API conventions

- JSON over HTTPS for application APIs.
- Use standard status codes and structured errors such as `{ "code": "QR_ALREADY_REDEEMED", "message": "This meal has already been redeemed", "request_id": "..." }`.
- Require an authenticated session for non-public routes.
- Include `Idempotency-Key` for create checkout, booking, refund, QR redemption and delivery completion where appropriate.
- Server-derived values override client values.
- Use pagination for list endpoints.
- Never return raw gateway secrets, raw token hashes, other customers' personal details, or internal stack traces.

## Customer / discovery

- `GET /providers?locality=&pincode=&pickup=&delivery=&q=` — active public providers only.
- `GET /providers/{providerId}` — public profile, schedules, published plans/menu, supported service modes.
- `GET /providers/{providerId}/plans` — published plans and clear policy summaries.
- `GET /me` — own profile and permitted role list.
- `GET /me/addresses`; `POST /me/addresses`; `PATCH /me/addresses/{id}`; `DELETE /me/addresses/{id}` — own addresses only.

## Checkout / subscription

- `POST /checkout/subscriptions` — input: plan ID, selected duration if plan supports it, idempotency key. Server reads price and terms, creates pending subscription/payment transaction and returns checkout instructions.
- `POST /checkout/single-meal` — input: provider ID, menu item ID, slot/date, fulfillment mode, optional address ID and idempotency key. Server validates availability and calculates the total, including any amount covered by a subscription so the same food is never charged twice.
- `POST /payments/{gateway}/webhook` — signature-verified gateway event; idempotent event processing.
- `GET /payments/{transactionId}` — caller sees only permitted fields; reconcile pending state when appropriate.
- `POST /subscriptions/{id}/pause` and `/resume` — only if pause policy allows; server derives eligibility and expiry updates.
- `GET /me/subscriptions`; `GET /me/subscriptions/{id}` — own subscription and entitlement state.

## Meal booking / QR

- `POST /meal-bookings` — input: subscription ID or single meal reference, date, slot, pickup/delivery, optional address ID, idempotency key. Server validates schedule/capacity and does not deduct credit.
- `GET /me/meal-bookings` — customer-owned list.
- `POST /meal-bookings/{id}/qr` — only booking owner can request a short-lived pickup QR; ensure booking is eligible and state permits issue.
- `POST /redemptions/validate-and-redeem` — authenticated provider staff submits token; server resolves exact provider from staff membership, validates all rules and atomically redeems once. Do not trust provider ID sent by client.
- `GET /providers/me/redemptions` — provider-scoped redemption history, paginated.

## Delivery

- `POST /delivery/quote` — booking/address/provider data; returns server-calculated fee, estimated zone/range if supported and quote expiry.
- `POST /delivery/assignments/{id}/accept` — verified eligible partner accepts if assignment is still open.
- `POST /delivery/assignments/{id}/reject` — reject with reason code.
- `POST /delivery/assignments/{id}/pickup` — current assigned partner confirms pickup.
- `POST /delivery/assignments/{id}/complete` — current assigned partner submits OTP/QR; server completes once and redeems the meal atomically.
- `POST /delivery/assignments/{id}/report-issue` — issue category and safe details.
- `GET /delivery/me/assignments`; `GET /delivery/me/earnings` — own assignments and payout summaries only.

## Provider operations

- `POST /provider/applications`; `GET /provider/me`.
- `PATCH /provider/me/profile`; `PATCH /provider/me/hours`.
- `POST /provider/me/menu-items`; `PATCH /provider/me/menu-items/{id}`; `POST /provider/me/plans`; `PATCH /provider/me/plans/{id}`.
- `GET /provider/me/bookings?date=&slot=&status=` — provider-scoped.
- `POST /provider/me/bookings/{id}/ready` — only allowed state transition.
- `GET /provider/me/settlements`; `GET /provider/me/financial-summary` — provider scoped and no gateway secrets.
- `POST /provider/me/commercial-agreement/accept` — records explicit version/rate/effective terms, with server-derived identity and timestamp.

## Admin/operations

Admin routes are server-protected and need stronger audit logging:
- `GET /admin/providers?status=`; `POST /admin/providers/{id}/approve`; `POST /admin/providers/{id}/reject`.
- `GET /admin/delivery-partners?status=`; verification actions.
- `GET /admin/transactions`; `GET /admin/bookings/{id}/audit`.
- `POST /admin/refunds` — only after verifying underlying gateway/refund policy; idempotent.
- `POST /admin/commission-rules`; `POST /admin/promotions`.
- `GET /admin/settlements/reconciliation`; `GET /admin/audit-logs`.
- Support ticket assignment/resolution endpoints.

## Error codes to standardise

`UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION_ERROR`, `PROVIDER_INACTIVE`, `PLAN_UNAVAILABLE`, `SUBSCRIPTION_INACTIVE`, `SUBSCRIPTION_EXPIRED`, `MEAL_CREDIT_EXHAUSTED`, `SLOT_UNAVAILABLE`, `BOOKING_CUTOFF_PASSED`, `OUT_OF_DELIVERY_AREA`, `PAYMENT_PENDING`, `PAYMENT_FAILED`, `PAYMENT_NOT_VERIFIED`, `QR_EXPIRED`, `QR_INVALID`, `QR_ALREADY_REDEEMED`, `WRONG_PROVIDER`, `ASSIGNMENT_NOT_ACTIVE`, `DELIVERY_OTP_INVALID`, `IDEMPOTENCY_CONFLICT`, `RATE_LIMITED`, `INTERNAL_ERROR`.

## Required endpoint tests

For every endpoint, test valid request, invalid payload, unauthenticated request, wrong-role request, cross-tenant ID substitution, repeated idempotency key, concurrent request and relevant external provider failure.
