# Dictionary and SAP setup

## Naming and type conventions

All custom names begin with `ZEXP_`. Create technical fields using the types below (or equivalent local data elements). Set tables to client-dependent delivery class `A`, data class `APPL0`, and size category appropriate for a small capstone. All primary keys start with `MANDT`.

Use `CHAR`/`NUMC` and `DATS`/`TIMS` types as specified. Monetary amounts use `CURR 15,2` with the matching currency field as reference in SE11. In reports the currency is `WAERS`. Use uppercase fixed values for status fields.

## Domains and data elements

Create these shared objects in SE11 before the tables:

| Domain | Type / length | Values |
|---|---|---|
| `ZEXP_D_EMP_ID` | CHAR 10 | Employee ID |
| `ZEXP_D_CLAIM_ID` | CHAR 12 | Claim number |
| `ZEXP_D_CATEGORY` | CHAR 10 | Category ID |
| `ZEXP_D_STATUS` | CHAR 20 | `SUBMITTED`, `VALIDATION_FAILED`, `PENDING_APPROVAL`, `APPROVED`, `REJECTED`, `REIMBURSED`, `RECORDED` |
| `ZEXP_D_ACTIVE` | CHAR 1 | `X` active, blank inactive |
| `ZEXP_D_EMAIL` | CHAR 241 | Email address |
| `ZEXP_D_REFERENCE` | CHAR 30 | Reimbursement reference |
| `ZEXP_D_AUTH_ROLE` | CHAR 10 | `ADMIN`, `EMPLOYEE`, `MANAGER`, `FINANCE`, `POLICY`, `REPORT` |

Create same-named data elements `ZEXP_E_EMP_ID`, `ZEXP_E_CLAIM_ID`, `ZEXP_E_CATEGORY`, `ZEXP_E_STATUS`, `ZEXP_E_ACTIVE`, `ZEXP_E_EMAIL`, `ZEXP_E_REFERENCE`, and `ZEXP_E_AUTH_ROLE` referencing their respective domains. Additional short text fields may use built-in `CHAR` data elements. Use currency data element `WAERS` and date/time elements `DATS` and `TIMS`.

## Tables

Create the tables in the order listed. All fields listed as key are part of the key, including `MANDT`.

### `ZEXP_EMP` — employee master

| Field | Key | Type | Notes |
|---|---:|---|---|
| `MANDT` | X | CLNT 3 | Client |
| `EMP_ID` | X | `ZEXP_E_EMP_ID` | Stable employee identifier |
| `EMP_NAME` | | CHAR 80 | Required |
| `DEPARTMENT` | | CHAR 40 | Required |
| `DESIGNATION` | | CHAR 40 | Required |
| `EMAIL` | | `ZEXP_E_EMAIL` | Required |
| `ACTIVE` | | `ZEXP_E_ACTIVE` | X or blank |
| `SAP_USER` | | CHAR 12 | SAP username; required unique secondary index |
| `MANAGER_ID` | | `ZEXP_E_EMP_ID` | Self-reference to employee |
| `CREATED_BY` | | CHAR 12 | SAP username audit |
| `CREATED_ON` | | DATS | Audit |
| `CHANGED_BY` | | CHAR 12 | SAP username audit |
| `CHANGED_ON` | | DATS | Audit |

Add a foreign key from `MANAGER_ID` to `ZEXP_EMP-EMP_ID` if the Dictionary setup allows the self-reference cleanly. Do not permit physical deletion through the application.

### `ZEXP_CAT` — expense categories

| Field | Key | Type | Notes |
|---|---:|---|---|
| `MANDT` | X | CLNT 3 | Client |
| `CATEGORY_ID` | X | `ZEXP_E_CATEGORY` | Seed IDs: TRAVEL, FOOD, ACCOM, LOCAL |
| `CATEGORY_NAME` | | CHAR 40 | Display name |
| `ACTIVE` | | `ZEXP_E_ACTIVE` | X or blank |

Create the initial category records with `ZEXP_POLICY_MAINT`: `TRAVEL` / Travel, `FOOD` / Food, `ACCOM` / Accommodation, and `LOCAL` / Local transportation. Set each active.

### `ZEXP_POLICY` — effective-dated policy limits

| Field | Key | Type | Notes |
|---|---:|---|---|
| `MANDT` | X | CLNT 3 | Client |
| `CATEGORY_ID` | X | `ZEXP_E_CATEGORY` | Foreign key to `ZEXP_CAT` |
| `VALID_FROM` | X | DATS | Inclusive start date |
| `VALID_TO` | | DATS | Inclusive end date |
| `MAX_AMOUNT` | | CURR 15,2 | Reference `CURRENCY` |
| `CURRENCY` | | WAERS | Policy currency |
| `ACTIVE` | | `ZEXP_E_ACTIVE` | X or blank |
| `CHANGED_BY` | | CHAR 12 | SAP username audit |
| `CHANGED_ON` | | DATS | Audit |

### `ZEXP_CLAIM` — claim header

| Field | Key | Type | Notes |
|---|---:|---|---|
| `MANDT` | X | CLNT 3 | Client |
| `CLAIM_ID` | X | `ZEXP_E_CLAIM_ID` | Internal number range |
| `EMP_ID` | | `ZEXP_E_EMP_ID` | Foreign key to `ZEXP_EMP` |
| `CATEGORY_ID` | | `ZEXP_E_CATEGORY` | Foreign key to `ZEXP_CAT` |
| `AMOUNT` | | CURR 15,2 | Reference `CURRENCY` |
| `CURRENCY` | | WAERS | Claim currency |
| `EXPENSE_DATE` | | DATS | Date incurred |
| `DESCRIPTION` | | CHAR 200 | Required |
| `SUBMITTED_ON` | | DATS | Submission date |
| `STATUS` | | `ZEXP_E_STATUS` | See status values in README |
| `POLICY_VALID_FROM` | | DATS | Policy snapshot key after validation |
| `CREATED_BY` | | CHAR 12 | SAP username audit |
| `CREATED_ON` | | DATS | Audit |

Add indexes for `EMP_ID`, `STATUS`, `CATEGORY_ID`, and `SUBMITTED_ON`.

### `ZEXP_VALID` — validation attempts

| Field | Key | Type | Notes |
|---|---:|---|---|
| `MANDT` | X | CLNT 3 | Client |
| `CLAIM_ID` | X | `ZEXP_E_CLAIM_ID` | Foreign key to claim |
| `VALIDATION_NO` | X | NUMC 3 | Increment per claim |
| `RESULT` | | CHAR 1 | `P` pass, `F` fail |
| `RESULT_TEXT` | | CHAR 200 | Explanation |
| `POLICY_VALID_FROM` | | DATS | Policy version checked |
| `VALIDATED_BY` | | CHAR 12 | SAP username audit |
| `VALIDATED_ON` | | DATS | Audit |
| `VALIDATED_AT` | | TIMS | Audit |

### `ZEXP_APPROVAL` — one final decision per claim

| Field | Key | Type | Notes |
|---|---:|---|---|
| `MANDT` | X | CLNT 3 | Client |
| `CLAIM_ID` | X | `ZEXP_E_CLAIM_ID` | Foreign key to claim |
| `APPROVER_ID` | | `ZEXP_E_EMP_ID` | Manager employee |
| `DECISION` | | CHAR 1 | `A` approve, `R` reject |
| `REJECTION_REASON` | | CHAR 200 | Required for rejection |
| `DECIDED_ON` | | DATS | Audit |
| `DECIDED_AT` | | TIMS | Audit |

### `ZEXP_REIMB` — simulated reimbursement record

| Field | Key | Type | Notes |
|---|---:|---|---|
| `MANDT` | X | CLNT 3 | Client |
| `CLAIM_ID` | X | `ZEXP_E_CLAIM_ID` | Primary key also prevents duplicate |
| `REFERENCE` | | `ZEXP_E_REFERENCE` | Required, unique secondary index |
| `AMOUNT` | | CURR 15,2 | Reference `CURRENCY` |
| `CURRENCY` | | WAERS | Must match claim |
| `REIMBURSED_ON` | | DATS | Record date |
| `STATUS` | | `ZEXP_E_STATUS` | `RECORDED` only; not a bank/FI status |
| `RECORDED_BY` | | CHAR 12 | SAP username audit |

Add foreign keys from `ZEXP_CLAIM` to employee/category, and from validation, approval, reimbursement tables to claim. Configure the monetary reference fields exactly in SE11.

## Number range and locking

1. In SNRO create number range object `ZEXP_CLM` (object names are limited on some releases; this name is intentionally short and still uses the project prefix). Create internal interval `01`, for example `000000000001` through `999999999999`. The report uses `NUMBER_GET_NEXT`.
2. In SE11 create lock object `EZEXPCLM` on table `ZEXP_CLAIM`, key `MANDT` and `CLAIM_ID`, with exclusive lock. Activation generates enqueue/dequeue function modules `ENQUEUE_EZEXPCLM` and `DEQUEUE_EZEXPCLM`.

SAP lock-object names follow the generated `E...` naming convention, so `EZEXPCLM` is the technical exception to the `ZEXP_` prefix. The current report code serializes claim validation, approval, and reimbursement with these lock calls. Do not activate those reports before the lock object has been generated.

## Authorization

In SU20 create authorization field `ZEXP_ROLE` based on data element `ZEXP_E_AUTH_ROLE`. In SU21 create authorization object `ZEXP_AUTH` with fields `ACTVT` and `ZEXP_ROLE`. Use the following application combinations in PFCG:

| Role | ACTVT | Purpose |
|---|---|---|
| `EMPLOYEE` | `01` | Submit own claims |
| `ADMIN` | `01`, `02` | Create/update employee master |
| `POLICY` | `01`, `02` | Create/update categories and policy |
| `MANAGER` | `02` | Validate/decide scoped claims |
| `FINANCE` | `02` | Record reimbursement |
| `REPORT` | `03` | View reports |

The code checks the custom object and separately checks the employee SAP user / manager relationship. Authorization values and role names are case-sensitive.
