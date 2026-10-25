# MESS Provider/Admin — Continue Loop Prompt

Continue the existing MESS project. Do not restart from scratch or repeat a status report.

Inspect the current git diff, task checklist, provider Flutter flows, admin web routes, migrations, RLS policies, runtime logs and test results. Select the highest-priority incomplete requirement from `ANTIGRAVITY_MASTER_PROMPT.md` and implement it end-to-end.

For this iteration:
1. Connect UI action to the repository/API and actual state transition.
2. Add validation, loading, success, empty and error states.
3. Verify role/ownership and data-integrity rules on the server.
4. Run the relevant formatter, analyzer, typecheck, unit/integration/browser tests.
5. Start the app and inspect the exact flow at small phone width and desktop where applicable.
6. Fix failures, rerun tests and update the checklist with tested status only.

Prioritize: provider registration and verification, meal-slot rules, fixed/tracker/daily model separation, portions and add-ons, server-issued daily QR, atomic redemption, payment verification, admin role enforcement, ledger accuracy, and audit logs.

Do not use fabricated production values, local-only authorization, client-generated redeemable QR, fake payment success, fake analytics or food images not uploaded by the provider. If blocked by credential/approval, complete independent work and record the exact blocker. After two or three identical errors, inspect logs/docs and change the approach. Continue until the next action genuinely requires the user or all feasible criteria are verified.
