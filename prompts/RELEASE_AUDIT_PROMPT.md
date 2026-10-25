# MESS Provider/Admin — Independent Release Audit

Independently audit the current repository against `ANTIGRAVITY_MASTER_PROMPT.md`. Do not trust a previous claim that something is complete.

## Run real checks
- Flutter format, `flutter analyze`, unit/widget/integration tests, debug Android build.
- Next.js typecheck, lint, production build, mobile/responsive browser checks.
- SQL migration apply in a disposable/staging database and inspect RLS policies/advisors.
- Provider onboarding from start to submitted review state.
- Approved provider publishes a menu, configures fixed/tracker/daily options and creates a real backend-issued daily QR.
- Customer scans provider QR; validate slot, menu, plan entitlement, included portions and extras.
- Verify fixed-period visit does not consume tracker credits; tracker consumes exactly one on confirmed redemption; daily meal requires verified payment.
- Test duplicate and concurrent scans, wrong provider/date/signature, out-of-slot, sold-out item, payment failure and webhook replay.
- Admin role isolation, approval/rejection reason, finance maker/checker, audit log append-only behavior and developer masked logs.
- Verify no secrets in git/client bundles; no RLS bypass; no dead links/buttons; no mobile horizontal overflow; no fake metrics/images/reviews.

For every critical category, report PASS, FAIL, BLOCKED or NOT TESTED with the exact command and evidence. Fix feasible high-impact defects and rerun. Never fabricate results. Finish with remaining release blockers, required environment variables, staging steps, backup/rollback plan and recommended pilot criteria. Do not run live payments or alter production data without explicit authorization.
