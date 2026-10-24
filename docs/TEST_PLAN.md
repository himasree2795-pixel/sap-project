# Manual test plan

Run in a non-production client only. First create categories, an active manager and employee, and an effective policy in a single currency. Assign SAP users and roles. Use SE38 for each report.

| Test | Setup / action | Expected result |
|---|---|---|
| Employee create | Admin creates employee with required fields | Record created; no deletion function exists |
| Employee update | Admin changes designation or status | Existing row updated; audit user/date updated |
| Unauthorized maintenance | User without `ADMIN` runs employee report | Authorization message; no database change |
| Policy create | `POLICY` user creates an active category limit | Policy row created |
| Policy validation | Submit amount equal to limit and then above limit | Equal-to-limit passes; above-limit fails validation |
| Missing claim data | Omit description/category/date or use non-positive amount | Submission refused with field-specific message |
| Inactive employee | Inactive employee submits | Submission refused; no claim row |
| Employee ownership | Different SAP user submits for another employee | Submission refused |
| Successful claim | Active employee submits valid claim | New number-range ID; status `SUBMITTED` |
| Manager validation queue | Assigned manager selects submitted-claims worklist | Only that manager's direct reports are shown |
| Claim validation | Manager validates submitted valid claim | Validation row `P`; claim moves to `PENDING_APPROVAL` |
| Invalid category/policy | Deactivate category or remove matching policy, then validate | Validation row `F`; claim moves to `VALIDATION_FAILED` |
| Duplicate validation | Validate same claim after it is no longer `SUBMITTED` | No duplicate processing; status remains unchanged |
| Scoped approval | Manager tries a claim outside their employee scope | Refused; no approval row |
| Manager approval worklist | Assigned manager selects pending-approval worklist | Only their own direct reports' pending claims are shown |
| Approve | Correct manager approves a pending claim | One approval row; claim moves to `APPROVED` |
| Reject without reason | Manager chooses reject and leaves reason empty | Refused; no decision row |
| Duplicate decision | Try deciding an already decided claim | Refused; existing decision remains |
| Reimbursement | Finance records matching amount/currency and unique reference | One `RECORDED` reimbursement; claim moves to `REIMBURSED` |
| Duplicate reimbursement | Record reimbursement for same claim again | Refused; one reimbursement row remains |
| Reports | Run each ALV view and summaries | Correct filters/data; totals reconcile to selected rows |
| Concurrency | Two users act on the same claim simultaneously | Lock prevents overlapping processing |

Because no SAP system is available, these are expected manual checks, not completed test results.
