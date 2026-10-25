Perform an independent release-readiness audit of MESS. Do not trust previous completion claims without evidence.

Inspect and test the customer app, provider app/portal, website, admin, migrations, RLS, auth, menus/portions/add-ons, fixed-period plans, meal-tracker plans, daily purchase, provider date QR, customer camera scanner, slot detection, idempotent redemption, payment verification/webhooks, ledger, refunds, support/legal pages and responsive UI.

Run actual available checks: `flutter analyze`, `flutter test`, Android debug build, web lint/type/build/tests, backend migration checks and security/RLS tests. Inspect at small phone widths and verify all navigation, links and buttons. No fake reviews/counters, dead links, placeholder copy, horizontal scroll, hardcoded production prices, exposed secrets or client-side-only authorization are acceptable.

For each critical feature report PASS, FAIL, BLOCKED or NOT TESTED with brief evidence. Fix all feasible critical/high issues and rerun affected checks. Do not use real money or live user data in tests. Clearly distinguish demo-mode functionality from production-enabled integrations. Finish with release blockers and exact required secrets/configuration, without publishing secret values.
