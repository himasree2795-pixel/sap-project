# End-to-end demo runbook

This runbook is for a development or training SAP client. Use fictitious people and a configured currency. It complements, but does not replace, [TEST_PLAN.md](TEST_PLAN.md).

## Before the demo

1. Complete the SE11, SNRO, SU20/SU21, and lock-object setup in [DICTIONARY_AND_SETUP.md](DICTIONARY_AND_SETUP.md).
2. Confirm the currency you will use exists in `TCURC`. Replace `INR` below if your training system does not have it configured.
3. Assign distinct SAP users to the following roles in PFCG:

   | Demo identity | Required authorization |
   |---|---|
   | Employee A | `ZEXP_AUTH`: `ACTVT=01`, `ZEXP_ROLE=EMPLOYEE` |
   | Manager A | `ZEXP_AUTH`: `ACTVT=02`, `ZEXP_ROLE=MANAGER` |
   | Finance user | `ZEXP_AUTH`: `ACTVT=02`, `ZEXP_ROLE=FINANCE` |
   | Policy maintainer | `ZEXP_AUTH`: `ACTVT=01,02,03`, `ZEXP_ROLE=POLICY` |
   | Employee administrator | `ZEXP_AUTH`: `ACTVT=01,02`, `ZEXP_ROLE=ADMIN` |
   | Report user | `ZEXP_AUTH`: `ACTVT=03`, `ZEXP_ROLE=REPORT` |

   Role values in the custom object are not a substitute for assigning the appropriate SAP transactions/program access in the role.

4. Create these employee records using `ZEXP_EMP_MAINT`. Use the real SAP usernames for your own training users; the sample email domain `.invalid` is intentionally non-routable.

   | Employee ID | Name | Department | Designation | Email | SAP user | Manager ID |
   |---|---|---|---|---|---|---|
   | `MGR001` | Morgan Manager | Operations | Team Manager | `morgan@example.invalid` | `<manager SAP user>` | blank |
   | `EMP001` | Alex Employee | Operations | Analyst | `alex@example.invalid` | `<employee SAP user>` | `MGR001` |
   | `EMP002` | Casey Employee | Operations | Analyst | `casey@example.invalid` | `<second employee SAP user>` | `MGR001` |

   The employee SAP user must exactly match `SY-UNAME` at runtime. The manager's employee record must have the same SAP user as the user taking manager actions.

5. Create categories using `ZEXP_POLICY_MAINT`, selecting category mode and create:

   | Category ID | Category name | Active |
   |---|---|---|
   | `TRAVEL` | Travel | X |
   | `FOOD` | Food | X |
   | `ACCOM` | Accommodation | X |
   | `LOCAL` | Local transportation | X |

6. Create active policies in policy mode, using a start date no later than the expense dates used in the demo and a matching configured currency:

   | Policy ID | Category | Example limit | Currency |
   |---|---|---:|---|
   | `TRV-INR-01` | `TRAVEL` | 10000.00 | `INR` |
   | `FOD-INR-01` | `FOOD` | 2000.00 | `INR` |
   | `ACC-INR-01` | `ACCOM` | 8000.00 | `INR` |
   | `LOC-INR-01` | `LOCAL` | 1000.00 | `INR` |

   These amounts are illustrative training data, not recommended company policy. Select dates that satisfy the system's date validation and the policy effective dates.

## Demonstration flow

### Successful claim to reimbursement

1. Log in as Employee A and run `ZEXP_CLAIM_SUBMIT`.
2. Submit a `FOOD` claim for `750.00`, currency `INR`, an expense date on or before today and within the policy dates, and a short description such as `Team lunch`.
3. Note the claim ID displayed by the report.
4. Log in as Manager A and run `ZEXP_CLAIM_REPORT`; select the submitted-claims worklist. Confirm only direct reports are shown.
5. Run `ZEXP_CLAIM_VALIDATE` with the claim ID. A valid claim becomes `PENDING_APPROVAL`.
6. In `ZEXP_CLAIM_REPORT`, select the pending-approval worklist and confirm the claim is visible to Manager A.
7. Run `ZEXP_MANAGER_APPROVAL` and approve the claim.
8. Log in as the Finance user and run `ZEXP_REIMBURSE`. Enter the claim ID, a unique training reference such as `TRAIN-0001`, the exact approved amount/currency, and today's date.
9. Run `ZEXP_CLAIM_REPORT` with the reimbursements view and confirm the record. This records a simulation only; it does not transfer money or create an SAP FI document.

### Rejection path

1. Submit another valid claim as Employee A and note its ID.
2. Validate it as Manager A.
3. Decide to reject it in `ZEXP_MANAGER_APPROVAL`, providing a clear reason such as `Receipt details do not support the expense`.
4. Select the rejected-claims view in `ZEXP_CLAIM_REPORT`; confirm the claim and rejection reason are displayed.

### Validation failure path

1. Submit a claim above the active limit, for example a `FOOD` claim of `2500.00` against the example limit.
2. Validate it as Manager A.
3. Confirm a failed validation result and `VALIDATION_FAILED` status. It cannot proceed through the approval report in this initial implementation.

## Evidence to capture for a capstone demonstration

- SE11 active status for each custom table, the generated lock object, and the relevant foreign keys/indexes.
- SNRO interval configuration, with no need to expose unrelated system configuration.
- PFCG roles and a successful/denied authorization example.
- Screenshots or exported ALV results for the submitted, pending, rejected, reimbursement, department-summary, and category-summary views.
- A written test-results copy of `TEST_PLAN.md` with actual outcomes and any deviations. Do not mark tests as passed until observed in SAP.

## Known demo constraints

- Update mode in employee/policy maintenance still requires all fields used by that report; enter the complete desired record rather than leaving unchanged fields blank.
- The report set is a classic executable-report interface, not a menu-driven application. Claim IDs are entered manually between steps.
- Manager scope is direct-report-only; no delegation or hierarchy roll-up is implemented.
- Reports have not been activated or tested in an SAP system. Resolve all syntax-check and activation messages in the target release before using the runbook.
