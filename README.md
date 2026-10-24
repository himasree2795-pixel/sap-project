# Employee Expense Reimbursement and Approval System

Classic SAP GUI ABAP capstone project source pack. This workspace is a source-and-setup pack; it is not an SAP transport and does not contain activated Dictionary objects.

## Compatibility assumption

The implementation uses classic ABAP reports, Open SQL without escaped host variables, `AUTHORITY-CHECK`, the classic number-range function module `NUMBER_GET_NEXT`, and `CL_SALV_TABLE`. It is intended for a classic AS ABAP system with SALV and number-range support (typically SAP NetWeaver 7.00 or later). The exact target release is unknown and must be confirmed before activation. It does not use ABAP Cloud syntax or APIs.

No code in this workspace has been compiled, activated, or run in SAP because no SAP system is available.

## Scope and workflow

The reports implement employee maintenance, policy maintenance, claim submission, claim validation, manager decisions, simulated reimbursement recording, and ALV reporting.

`SUBMITTED` claims are processed by validation. A valid claim becomes `PENDING_APPROVAL`; an invalid one becomes `VALIDATION_FAILED`. Managers decide pending claims. Finance records simulated reimbursements for approved claims, which then become `REIMBURSED`.

## Build order

1. Read [docs/DICTIONARY_AND_SETUP.md](docs/DICTIONARY_AND_SETUP.md).
2. Create the domains, data elements, tables, foreign-key relationships, indexes, number-range object, lock object, and authorization object documented there.
3. Activate all Dictionary and authorization prerequisites.
4. Create and activate the reports in `src/` in this order:
   1. `ZEXP_EMP_MAINT`
   2. `ZEXP_POLICY_MAINT`
   3. `ZEXP_CLAIM_SUBMIT`
   4. `ZEXP_CLAIM_VALIDATE`
   5. `ZEXP_MANAGER_APPROVAL`
   6. `ZEXP_REIMBURSE`
   7. `ZEXP_CLAIM_REPORT`
5. Create roles and assign users following the authorization guidance.
6. Use the manual test plan in [docs/TEST_PLAN.md](docs/TEST_PLAN.md).

The per-module objective, design, behavior, security, test, dependency, and limitation notes are in [docs/MODULE_GUIDE.md](docs/MODULE_GUIDE.md). The [docs/DEMO_RUNBOOK.md](docs/DEMO_RUNBOOK.md) provides sample training data and an end-to-end demonstration sequence.

For the currently developed first module, see the detailed [Module 1 Employee Management guide](docs/MODULE1_EMPLOYEE.md), including table design, exact creation order, report usage, tests, and review checklist.

The Module 2 policy design, policy-resolution rules, report usage, tests, and known integration issues are documented in the [Module 2 Expense Policy guide](docs/MODULE2_POLICY.md).

Each `.abap` file is the complete source of one executable report. In SAP GUI, create a program with the exact report name in SE38, paste the matching source, run syntax check, activate, then assign transaction codes in SE93 if desired.

## ABAP object catalog

| Exact name | Object type | Purpose | Prerequisites |
|---|---|---|---|
| `ZEXP_EMP_MAINT` | Executable report | Create, display, update, activate/deactivate employees; no permanent deletion | `ZEXP_EMP`, `ZEXP_AUTH`, SALV |
| `ZEXP_POLICY_MAINT` | Executable report | Create/display/update policies and supported categories; reject overlapping active periods | `ZEXP_CAT`, `ZEXP_POLICY`, `EZEXPPOL`, `ZEXP_AUTH`, SALV |
| `ZEXP_CLAIM_SUBMIT` | Executable report | Submit employee-owned claims and assign IDs | `ZEXP_EMP`, `ZEXP_CAT`, `ZEXP_CLAIM`, number range `ZEXP_CLM`, `ZEXP_AUTH` |
| `ZEXP_CLAIM_VALIDATE` | Executable report | Validate submitted claims and write validation history | Employee/category/policy/claim/validation tables, lock object `EZEXPCLM`, `ZEXP_AUTH` |
| `ZEXP_MANAGER_APPROVAL` | Executable report | Record one scoped approval/rejection per claim | Employee/claim/approval tables, lock object `EZEXPCLM`, `ZEXP_AUTH` |
| `ZEXP_REIMBURSE` | Executable report | Record one simulated reimbursement per approved claim | Claim/reimbursement tables, lock object `EZEXPCLM`, `ZEXP_AUTH` |
| `ZEXP_CLAIM_REPORT` | Executable report | Display claims, manager-scoped validation/approval worklists, rejected items, reimbursements, and summaries in ALV | Employee/claim/reimbursement tables, SALV, `ZEXP_AUTH` |

## Authorization setup

Create authorization field `ZEXP_ROLE` in SU20, then authorization object `ZEXP_AUTH` in SU21 with fields `ACTVT` and `ZEXP_ROLE`. Maintain role/user assignments with PFCG. The reports also enforce employee-to-user and manager-to-employee relationships in application logic. See the dictionary/setup document for the expected role/activity combinations. Module 2 requires the `POLICY` role for activities 01, 02, and 03.

## Important limitations

- This is a student-sized baseline, not a production financial application.
- No bank transfer, SAP FI posting, workflow engine, currency conversion, attachment storage, or email notification is implemented.
- Claims and decision history are retained; no permanent deletion report is provided.
- Configure a claim lock object before using reports concurrently. Database authorization and application authorization both need validation in the target system.
- The source uses classic report selection screens and SALV. User-specific screen layouts, Fiori, ABAP Cloud, and release-specific APIs are out of scope.
