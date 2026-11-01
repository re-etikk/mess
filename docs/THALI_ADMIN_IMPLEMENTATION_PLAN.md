# Thali Admin Implementation Plan

## Scope

Build the Super Admin operations panel from the attached master prompt on the existing `apps/web` + shared Supabase backend. Customer and partner Flutter applications keep their current contracts. This document distinguishes implemented, partial, missing, and intentionally blocked work; it does not claim every module is already production-ready.

## Work breakdown

| ID | Work item | Files/areas | Backend / DB | Acceptance criteria | State |
|---|---|---|---|---|---|
| A0 | Codebase and security audit | `docs/THALI_ADMIN_TECHNICAL_AUDIT.md`, existing app/API/migration code | Read-only inspection | Stack, auth, API, schema, workflow, risk and release boundaries documented | Done |
| A1 | Database/domain map | `docs/THALI_ADMIN_DATABASE_MAP.md` | Existing canonical migrations only | Existing vs missing logical entities and enum semantics recorded; no duplicate schema proposed | Done |
| A2 | Architecture and module plan | `docs/THALI_ADMIN_ARCHITECTURE.md`, this file | One backend and session-first policy | Data flow, domains, least privilege, release plan defined | Done |
| A3 | Progress tracking | `docs/THALI_ADMIN_PROGRESS.md` | None | Current work, blocked items, evidence updated as slices land | Done |
| F1 | Private admin shell | `apps/web/src/app/admin/console/**`, reusable admin components | Reuse `requireAdmin` | No public Admin link; server route gate + per-API guard; responsive sidebar/header | Implemented; preview verification pending |
| F2 | Overview | `/api/admin/metrics`, admin dashboard UI | Bounded real queries, documented measure definitions | Real loading/empty/error state; no fake metrics; GMV/fees/settlements separate | Implemented; staging verification pending |
| P1 | Partner queue/directory | `/api/admin/providers`, partner UI | Existing providers, memberships, documents, billing | Server pagination/search/status; reasoned approval/rejection; no unsupported status | Partial |
| C1 | Customer directory | `/api/admin/users`, customer UI | `profiles`, `user_roles`, customer relations | Paged/searchable, masked PII; no fake block action | Partial |
| S1 | Subscriptions | `/api/admin/subscriptions`, subscription UI | `subscriptions`, plans, redemptions | Bounded paging/filter; no manual entitlement edits without a domain transaction | Partial |
| O1 | Orders and redemptions | `/api/admin/operations`, read-only operations UI | `meal_bookings`, `meal_redemptions`; QR event gap documented | Bounded/paginated; failed scans not invented | Read-only slice implemented; preview/schema verification pending |
| FN1 | Transactions/refunds/ledger/settlements | `/api/admin/operations`, read-only operations UI | Existing finance tables | Actual enums, paise conversion, read-only until webhook and refund path verified | Read-only list slice implemented; ledger reconciliation pending |
| ST1 | Support operations | `/api/admin/operations`, read-only operations UI | `support_tickets`, existing statuses | Assignment/status changes validated and audited; no dead buttons | Read-only list slice implemented; mutations pending |
| GOV1 | Audit/roles/system status | `/api/admin/operations`, read-only operations UI | `audit_logs`; role permission schema gap | Append-only read view; granular roles only after safe migration design | Read-only audit slice implemented; granular RBAC pending |
| INT1 | Announcements/coupons/CMS | Future integration boundary | No persisted tables found | Do not display successful controls until a persisted schema/API exists | Blocked on business/schema design |
| SEC1 | Payment/refund/payout hardening | webhook, refund and settlement services | Existing schema, gateway configuration | Signed/idempotent verified events, atomic status/ledger/audit; staging tests pass | Blocked on staging/gateway validation |

## Dependencies and sequencing

1. Finish F1 and F2 before exposing module navigation.
2. Harden list contracts and query caps, then implement P1/C1/S1/O1 read-only surfaces.
3. Implement finance read views only after every measure is defined against `financial_ledger_entries` and source tables.
4. Add mutation workflows only if existing status/policy supports them and same-transaction audit is possible.
5. Defer table/permission additions until a staging Supabase project can replay/validate the actual schema. Do not apply migrations to production.

## Verification approach

- Unit: query parsing, masking, pagination bounds, metric definitions, authorization helpers.
- Integration: unauthorized/role denied; paginated data mirrors Supabase records; writes are audited and rolled back on failure.
- Build: `npm run build`; lint and typecheck in `apps/web`.
- Regression: Flutter clients' existing API requests remain compatible; no API route is repurposed or removed.
- Release: inspect branch preview; staging schema, payment webhook and QR concurrency tests before PR becomes merge-ready.

## Explicitly unsupported until proven

Staff-role assignment, customer blocking, refund initiation, payout approval, commission editing, subscription pause/correction, coupon/campaign/CMS mutation, and integration secret management are not to be faked or guessed. Provide read-only records or honest unavailable states until policy, backend, and audit guarantees exist.
