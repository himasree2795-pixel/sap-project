# Module-by-module implementation guide

This guide maps the capstone requirements to the project objects. Full executable report sources are in `src/`; exact SE11 field layouts and setup steps are in [DICTIONARY_AND_SETUP.md](DICTIONARY_AND_SETUP.md). Create and activate Dictionary/auth prerequisites before creating reports.

## Module 1 — Employee Management

- **A. Objective:** Maintain employee identity and reporting relationships without permanent deletion.
- **B. Requirements:** Create, display, update employee details; change active/inactive status; bind a SAP user; optionally assign a manager.
- **C. Database:** `ZEXP_EMP` with `(MANDT, EMP_ID)` key, required identity fields, dates and user audit; unique secondary index on `SAP_USER`.
- **D. Object order:** Activate reused employee ID, email, and active-status domains/data elements; create and activate table and index; configure `ZEXP_AUTH`; create report.
- **E. Code:** `ZEXP_EMP_MAINT` (`src/ZEXP_EMP_MAINT.abap`), executable report. Full build and activation steps are in [MODULE1_EMPLOYEE.md](MODULE1_EMPLOYEE.md).
- **F. Behavior:** Four actions: create, display one/all in SALV, update full details without changing status, and activate/deactivate. No delete path exists.
- **G. Validation:** Required fields, basic email format, duplicate employee ID/SAP user, active existing manager, and no self-manager assignment are checked.
- **H. Security:** `ZEXP_AUTH` requires `ADMIN` with activity 01 for create and 02 for update/status; `REPORT` activity 03 for display. Restrict direct table maintenance.
- **I. Test:** Use the Module 1 test table and review checklist in `MODULE1_EMPLOYEE.md`.
- **J. Dependencies:** Common Dictionary and authorization objects. `SAP_USER` and `MANAGER_ID` are retained for later claim/manager modules.
- **K. Limitations:** SAP release unknown; no syntax check/activation/runtime test possible; email validation is basic; no historical change log.

## Module 2 — Expense Policy Management

- **A. Objective:** Maintain supported categories and category/currency-specific limits.
- **B. Requirements:** Create/display/update policies, activate/deactivate categories and policies, and reject overlapping active periods.
- **C. Database:** `ZEXP_CAT`; `ZEXP_POLICY` keyed by `(MANDT, POLICY_ID)` with category, currency, positive limit, active flag, and validity dates.
- **D. Object order:** Activate policy ID domain/data element, table, category foreign key, currency reference and lookup index; generate `EZEXPPOL`; configure auth; create report.
- **E. Code:** `ZEXP_POLICY_MAINT` (`src/ZEXP_POLICY_MAINT.abap`), executable report. Full design and test details are in [MODULE2_POLICY.md](MODULE2_POLICY.md).
- **F. Behavior:** Supports fixed categories `TRAVEL`, `FOOD`, `ACCOM`, and `LOCAL`; policy resolution must match category, currency, active status, and expense date exactly.
- **G. Validation:** Positive limit, configured currency, consistent dates, active category, unique policy ID, and no overlap between active ranges for the same category/currency.
- **H. Security:** `POLICY` role with activities 01/02/03. The report uses a coarse client-level policy lock; restrict direct table maintenance.
- **I. Test:** Exercise valid/exceeded limits, inactive/missing policies, invalid dates, overlap rejection, display, and authorization per `MODULE2_POLICY.md`.
- **J. Dependencies:** Shared Dictionary/auth objects and `ZEXP_CAT`; claim validation later depends on this table design.
- **K. Limitations:** Currency conversion and historical change log are not implemented. Existing validator draft uses an older policy key and requires reconciliation.

## Module 3 — Expense Claim Submission

- **A. Objective:** Let an active employee submit a uniquely numbered expense claim.
- **B. Requirements:** Capture category, amount, currency, expense date, and description; set submission date and initial status.
- **C. Database:** `ZEXP_CLAIM`, linked to employee/category and using number range `ZEXP_CLM`.
- **D. Object order:** Activate the claim table and foreign keys; create SNRO object/interval; create `ZEXP_AUTH`; then create report.
- **E. Code:** `ZEXP_CLAIM_SUBMIT` (`src/ZEXP_CLAIM_SUBMIT.abap`), executable report.
- **F. Behavior:** Checks employee ownership against `SY-UNAME`, assigns a claim ID, stores `SUBMITTED`, and displays the assigned ID.
- **G. Validation:** Required fields, positive amount, non-future expense date, configured currency, active employee, and active category.
- **H. Security:** `EMPLOYEE` role with activity 01; an employee may submit only for their own SAP user mapping.
- **I. Test:** Submit a valid claim, then try an inactive employee, another employee's ID, blank description, zero amount, and future date.
- **J. Dependencies:** Employee/category/policy setup must exist. Policy limit evaluation is persisted by Module 4.
- **K. Limitations:** No receipt upload, drafts, claim editing after submission, currency conversion, or employee self-service UI.

## Module 4 — Expense Validation

- **A. Objective:** Record a validation result and route each submitted claim to approval or a validation-failed state.
- **B. Requirements:** Check employee active status, category active status, expense-date policy, policy currency, and maximum amount.
- **C. Database:** Reads `ZEXP_EMP`, `ZEXP_CAT`, `ZEXP_POLICY`, `ZEXP_CLAIM`; inserts `ZEXP_VALID`; updates claim status and policy snapshot.
- **D. Object order:** Activate all referenced tables and `EZEXPCLM` lock object before the report.
- **E. Code:** `ZEXP_CLAIM_VALIDATE` (`src/ZEXP_CLAIM_VALIDATE.abap`), executable report. The manager worklist is the `SUBMITTED` view of `ZEXP_CLAIM_REPORT`.
- **F. Behavior:** A pass sets `PENDING_APPROVAL`; a failure sets `VALIDATION_FAILED`; every attempt is persisted with user/date/time and message.
- **G. Validation:** Only `SUBMITTED` claims can be processed; required data, manager scope, employee/category status, policy coverage, currency, and limit are checked.
- **H. Security:** Requires `MANAGER` activity 02 and limits work to the current manager's employees. Locking serializes concurrent claim processing.
- **I. Test:** Validate a valid claim, above-limit claim, missing-policy claim, inactive employee, and claim outside manager scope.
- **J. Dependencies:** Modules 1–3 and the lock object.
- **K. Limitations:** One manager processes one entered claim ID at a time; failures are final in this baseline, with no correction/resubmission UI.

## Module 5 — Manager Approval

- **A. Objective:** Record one final manager approval or rejection for each validated claim.
- **B. Requirements:** Approve/reject pending claims; require a rejection reason; record approver and timestamp.
- **C. Database:** Reads/updates `ZEXP_CLAIM`; inserts one `ZEXP_APPROVAL` row per claim.
- **D. Object order:** Activate claim/approval tables, foreign key, `EZEXPCLM`, and authorization object; then create report.
- **E. Code:** `ZEXP_MANAGER_APPROVAL` (`src/ZEXP_MANAGER_APPROVAL.abap`); pending worklist is in `ZEXP_CLAIM_REPORT`.
- **F. Behavior:** Inserts decision and updates claim to `APPROVED` or `REJECTED` within a lock-protected operation.
- **G. Validation:** Requires `PENDING_APPROVAL`, manager/employee relationship, no existing decision, and a rejection reason for rejection.
- **H. Security:** Requires `MANAGER` activity 02; claim is scoped to the manager employee ID linked to current SAP user.
- **I. Test:** Approve one claim, reject another with/without a reason, try a second decision, and try another manager's claim.
- **J. Dependencies:** Modules 1 and 4, approval table, lock object, and authorization configuration.
- **K. Limitations:** One final decision, no delegation, escalations, multi-level approvals, or change history for amended decisions.

## Module 6 — Reimbursement Management

- **A. Objective:** Record a finance user's simulated reimbursement for an approved claim.
- **B. Requirements:** Store reference, amount, currency, date, status, and recording user; prevent duplicate claim/reference.
- **C. Database:** Reads/updates `ZEXP_CLAIM`; inserts `ZEXP_REIMB`, keyed by claim.
- **D. Object order:** Activate claim/reimbursement tables, unique reference index, `EZEXPCLM`, and authorization object; then create report.
- **E. Code:** `ZEXP_REIMBURSE` (`src/ZEXP_REIMBURSE.abap`), executable report.
- **F. Behavior:** Saves `RECORDED` and changes claim to `REIMBURSED`; explicitly does not transfer funds or post FI.
- **G. Validation:** Requires approved status, positive matching amount, matching currency, valid non-future date, unused claim and unique reference.
- **H. Security:** Requires `FINANCE` activity 02; lock and database unique indexes protect duplicate processing.
- **I. Test:** Record a reimbursement, then retry the claim, reuse its reference, mismatch amount/currency, or use an unapproved claim.
- **J. Dependencies:** Modules 3 and 5, reimbursement table, lock object, and finance authorization.
- **K. Limitations:** Simulation only; no bank integration, FI document, payment batch, cancellation, or partial payment.

## Module 7 — ALV Reporting

- **A. Objective:** Provide claim, workflow, reimbursement, department, and category views.
- **B. Requirements:** Filters by employee/date/category; manager-scoped submitted/pending worklists; rejected reason; currency-aware totals.
- **C. Database:** Read-only access to employee, claim, approval, and reimbursement tables.
- **D. Object order:** Activate report dependencies and SALV runtime before creating report.
- **E. Code:** `ZEXP_CLAIM_REPORT` (`src/ZEXP_CLAIM_REPORT.abap`), executable report using `CL_SALV_TABLE`.
- **F. Behavior:** Radio selection chooses claims, submitted worklist, pending worklist, rejected claims, reimbursements, or grouped summary.
- **G. Validation:** Empty results are reported; summaries keep currencies separate and count claims.
- **H. Security:** Managers see only their employees in manager worklists; the remaining reporting views require `REPORT` activity 03.
- **I. Test:** Compare row counts, manager scope, rejection reasons, filter behavior, and category/department totals to source tables.
- **J. Dependencies:** Modules 1–6 and SALV.
- **K. Limitations:** Classic list-style SALV, no saved variants/custom charts, and no currency conversion.

## Module 8 — Testing and Integration

- **A. Objective:** Verify each module independently before integrated demonstration.
- **B. Requirements:** Exercise valid/invalid input, status transitions, authorization, duplicate prevention, and report reconciliation.
- **C. Database:** Uses all project tables; tests should use a non-production client and isolated sample employee IDs.
- **D. Object order:** Complete setup and activate all dependent objects, then perform tests in workflow order.
- **E. Code:** No dedicated test report; use the executable reports and manual steps in [TEST_PLAN.md](TEST_PLAN.md).
- **F. Behavior:** Follow employee setup → policy setup → submit → validate → decide → record reimbursement → report.
- **G. Validation:** Record actual observed result against each expected result in the manual test plan.
- **H. Security:** Test with distinct employee, manager, finance, policy, admin, and reporting users; never test by granting broad production access.
- **I. Test:** The detailed expected outcomes are in `TEST_PLAN.md`.
- **J. Dependencies:** All prior modules and a configured SAP client.
- **K. Limitations:** These tests have not been run; no SAP system is currently available for activation or runtime verification.
