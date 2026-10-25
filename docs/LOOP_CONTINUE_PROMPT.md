# MESS — Continue the Build Loop

Continue the existing MESS project; do not restart from scratch or repeat a status summary.

Read the current checklist and inspect code, app runtime, database migrations, test results and logs. Select the highest-priority incomplete requirement from the PRD/TRD/flow docs. Implement that feature end-to-end, connect UI to the real backend, run the relevant formatting/lint/type/analyzer/tests, exercise the workflow and inspect failures. Fix defects and rerun affected tests. Review security, role boundaries, RLS, data integrity, idempotency and error states. Update checklist with only verified evidence, then immediately continue to the next incomplete item.

Do not replace real integrations with fake success states. Do not overwrite existing configuration. If blocked by credentials/approval, complete independent work and document the exact blocker. After 2–3 failed attempts, investigate docs/logs and change strategy. Continue until all feasible acceptance criteria are verified or the next action truly requires user input.
