Continue the MESS project from the current repository state. Do not restart from scratch, do not repeat a status report, and do not overwrite working user code.

Inspect the current task checklist, source files, backend schema/migrations, app/browser state, logs and latest test results. Pick the highest-priority incomplete requirement from `ANTIGRAVITY_MASTER_PROMPT.md` and implement it end-to-end.

After each meaningful change:
1. Run formatter, analyzer/type checks and relevant tests.
2. Run the affected app/web flow and verify its visible result.
3. Test negative/error cases as well as success.
4. Fix failures and rerun the affected checks.
5. Check role authorization, meal/credit integrity, duplicate QR redemption, payment verification and responsive UI as appropriate.
6. Update the checklist with PASS/FAIL/BLOCKED/NOT TESTED only when supported by actual results.
7. Continue automatically to the next incomplete item.

Do not fake an auth, payment, webhook, scanner or backend success. Do not mark demo adapter behavior as production functionality. If a credential or external approval is needed, complete independent work and document the precise blocker. If the same approach fails two or three times, inspect the actual error and choose a different approach.

Continue until all feasible criteria in the master prompt have been implemented and verified. Return the actual modified files, tests run, failures remaining and the single most important next action.
