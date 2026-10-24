# Module 2 — Expense Policy Management

## Design and dependencies

This module extends the project’s classic SAP GUI ABAP design. It uses `ZEXP_` names, client-dependent transparent tables, classic Open SQL, `AUTHORITY-CHECK`, and SALV display. The SAP product/release is still unknown; see the [Module 1 compatibility notes](MODULE1_EMPLOYEE.md#target-environment-and-compatibility). No assumption is made that Module 1 has been activated or tested.

`ZEXP_POLICY` has a stable policy ID as its primary key. Policy applicability is determined by **category + currency + active status + inclusive expense-date range**. For any one category/currency pair, active policy date ranges must not overlap. This permits distinct currency limits without selecting a policy for the wrong currency.

The report locks policy data for the current client while it checks conflicts and writes changes. This deliberately coarse client-level lock prevents two instances of this report from concurrently creating overlapping policies. Restrict direct table maintenance; manual table edits and other programs that do not use the same lock can still bypass the rule.

Dependencies:

- `ZEXP_CAT` is the existing project category master. It must contain the supported IDs `TRAVEL`, `FOOD`, `ACCOM`, and `LOCAL`.
- `ZEXP_D_CATEGORY` / `ZEXP_E_CATEGORY`, `ZEXP_D_ACTIVE` / `ZEXP_E_ACTIVE`, and the shared `ZEXP_AUTH` authorization object.
- `ZEXP_E_POLICY_ID` / `ZEXP_D_POLICY_ID`, added for this module.
- SAP currency configuration in `TCURC`.
- SALV runtime for policy/category display.
- Lock object `EZEXPPOL`, generated enqueue/dequeue function modules.

There is no dependency on a working employee report. Employee information is not read or changed by this module.

## Step 1 — Database table design

Create transparent client-dependent table `ZEXP_POLICY`, delivery class `A`, data class `APPL0`, with the following fields:

| Field | Key | Type / length | Notes |
|---|---:|---|---|
| `MANDT` | Yes | `CLNT`, 3 | Client |
| `POLICY_ID` | Yes | `ZEXP_E_POLICY_ID`, based on `ZEXP_D_POLICY_ID` (`CHAR`, 12) | Stable identifier supplied at create time; never changes on update |
| `CATEGORY_ID` | No | `ZEXP_E_CATEGORY`, `CHAR`, 10 | Foreign key to `ZEXP_CAT-CATEGORY_ID` |
| `MAX_AMOUNT` | No | `CURR`, 15 digits / 2 decimals | Positive limit; set currency reference to `CURRENCY` |
| `CURRENCY` | No | `WAERS`, SAP currency key | Policy applies only to this currency |
| `ACTIVE` | No | `ZEXP_E_ACTIVE`, `CHAR`, 1 | `X` active; blank inactive |
| `VALID_FROM` | No | `DATS`, 8 | Inclusive start date |
| `VALID_TO` | No | `DATS`, 8 | Inclusive end date; initial means no end date |
| `CHANGED_BY` | No | `CHAR`, 12 | SAP username audit field |
| `CHANGED_ON` | No | `DATS`, 8 | Last update date |

Primary key: `(MANDT, POLICY_ID)`. Create non-unique secondary index `Z01` (or the next available customer index name) on `(MANDT, CATEGORY_ID, CURRENCY, ACTIVE, VALID_FROM)`. The `CURR` field must reference the `CURRENCY` field in SE11.

Policy IDs are manually supplied and unique within a client. Example IDs: `TRAVEL-INR-01`, `FOOD-INR-01`; ensure IDs fit the 12-character field, or choose shorter IDs such as `TRV-INR-01`.

## Step 2 — Supporting Dictionary/security objects

Create in this order if not already present:

1. `ZEXP_D_POLICY_ID` — domain, `CHAR 12`.
2. `ZEXP_E_POLICY_ID` — data element referencing `ZEXP_D_POLICY_ID`.
3. `ZEXP_POLICY` — transparent table as specified above.
4. Foreign key from `ZEXP_POLICY-CATEGORY_ID` to `ZEXP_CAT-CATEGORY_ID`.
5. Secondary index `Z01` on category, currency, active status, and start date (including `MANDT`).
6. Lock object `EZEXPPOL` on `ZEXP_POLICY`, with `MANDT` as the only lock argument. A generic client-level lock serializes the overlap-check/save operation.
7. Authorization configuration: `ZEXP_AUTH` must allow `POLICY` with activity 01 (create), 02 (update), and 03 (display).
8. `ZEXP_POLICY_MAINT` — executable report.

Reuse `ZEXP_D_CATEGORY`, `ZEXP_E_CATEGORY`, `ZEXP_D_ACTIVE`, `ZEXP_E_ACTIVE`, and `ZEXP_AUTH`; do not recreate them. No search help or policy number-range object is needed. This implementation uses a user-entered policy identifier and SALV display.

## Category setup

The policy report also provides controlled category creation, display, and status updates using the existing `ZEXP_CAT` table. Only the required IDs and canonical names are accepted:

| ID | Name |
|---|---|
| `TRAVEL` | Travel |
| `FOOD` | Food |
| `ACCOM` | Accommodation |
| `LOCAL` | Local Transportation |

Create each category before creating its policies. Category deactivation does not delete associated policies. Claims must not use a policy when the category itself is inactive.

## Step 3 — Maintenance/report implementation

**Object:** `ZEXP_POLICY_MAINT`

**Object type:** Executable report in SE38

**Purpose:** Create/display/update policies; create/display/deactivate/activate the fixed expense categories.

**Dependencies:** `ZEXP_POLICY`, `ZEXP_CAT`, policy/category/active data elements, `ZEXP_AUTH`, generated `EZEXPPOL` lock modules, configured SAP currencies, and SALV.

The complete source is [ZEXP_POLICY_MAINT.abap](../src/ZEXP_POLICY_MAINT.abap). Create a report with this exact name in SE38 and paste the whole file.

### Report actions

The report has radio choices for **Policy** or **Category**, and **Create**, **Display**, or **Update**:

- Policy create/update requires policy ID, category, positive limit, currency, valid-from date, and active flag; valid-to is optional.
- A policy's identifier is stable. Update loads by policy ID and replaces the supplied policy details; supply all fields.
- Policy display shows all policies if policy ID is blank, or one matching ID. Category display shows all categories or one matching ID.
- Category creation accepts only the four fixed IDs and creates the canonical name as active. Category update uses the Active checkbox to activate/deactivate; names are controlled by the canonical list.
- There is no delete action.

## Step 4 — Validation and policy resolution

### Write-time checks

- Policy ID, category, currency, start date, and positive maximum are required.
- If an end date is supplied, it must be on or after the start date. Both endpoints are inclusive.
- Currency must exist in SAP `TCURC`.
- Category must exist and be active when creating/updating a policy.
- Policy ID must be unique for create and must already exist for update.
- Active overlapping ranges are rejected for the same category and currency. An inactive policy does not participate in selection and may have an overlapping range.
- Updates that activate a policy are subject to the same overlap test.
- Policy mutation is protected by the client-level enqueue lock from the beginning of the read/check/write operation through commit.

### Claim-time selection contract

For a claim, use the claim’s **expense date**, not submission or approval date. Select policies where:

1. `CATEGORY_ID` equals the claim category.
2. `CURRENCY` equals the claim currency exactly; no currency conversion or fallback is attempted.
3. `ACTIVE = 'X'`.
4. `VALID_FROM <= EXPENSE_DATE`, and (`VALID_TO` is initial or `VALID_TO >= EXPENSE_DATE`).
5. The category itself is active in `ZEXP_CAT`.

Exactly one matching policy is required. If none matches, validation must fail closed: record “no applicable active policy” and do not send the claim for approval. If more than one matches, record an ambiguity/configuration error and do not send the claim for approval. Never select an arbitrary row or simply the latest policy date to hide a conflict. The maintenance report prevents overlaps for writes through itself; the claim validator still needs the cardinality check to guard against legacy/direct table changes.

The current project validator predates this policy-ID schema and may not activate unchanged: it selects a policy by category/date and then checks currency afterward. Before policy-aware claim validation is used, reconcile its query to match **category and currency together**, fail unless exactly one row matches, and persist the selected `POLICY_ID` as a claim/validation snapshot. That validator integration belongs in the later validation module, not in this Module 2 report.

## Step 5 — Error handling and security

`ZEXP_POLICY_MAINT` checks `ZEXP_AUTH` before action:

| Operation | Authorization |
|---|---|
| Create policy/category | `ACTVT=01`, `ZEXP_ROLE=POLICY` |
| Update policy/category status | `ACTVT=02`, `ZEXP_ROLE=POLICY` |
| Display policy/category | `ACTVT=03`, `ZEXP_ROLE=POLICY` |

Assign these values and report-start access in PFCG. Do not give ordinary users direct `SM30`, `SE16` update, or equivalent table maintenance access. The lock coordinates this program only, not other programs that ignore it.

Invalid input is rejected with explicit error messages. Insert/update failures are reported rather than treated as success. Specific SALV creation errors are caught and surfaced. The code does not include a delete operation or a broad exception catch.

## Step 6 — Test cases

Expected results only; no SAP execution has occurred.

| # | Test | Expected result |
|---|---|---|
| 1 | Create each required category | Four canonical category rows exist and are active |
| 2 | Attempt unsupported category ID | Rejected; no category row created |
| 3 | Create active FOOD policy with valid currency/date and positive limit | One policy saved |
| 4 | Create policy with zero or negative maximum | Rejected; no policy saved |
| 5 | Create policy with unknown SAP currency | Rejected; no policy saved |
| 6 | Create policy whose end date precedes its start | Rejected; no policy saved |
| 7 | Create a second active FOOD policy with same currency and overlapping inclusive dates | Rejected; existing policy unchanged |
| 8 | Create active FOOD policy with a different currency over the same dates | Allowed; currency is part of the selection key |
| 9 | Create an inactive FOOD policy overlapping an active policy | Allowed but inactive policy must never be selected |
| 10 | Update inactive policy to active while its range overlaps | Rejected |
| 11 | Create valid sequential active policies with non-overlapping ranges | Allowed; date boundary is inclusive |
| 12 | Display all policies / a known policy ID | SALV displays expected rows |
| 13 | Display unknown policy ID | Informational no-records message |
| 14 | Deactivate category and attempt to create a policy for it | Policy save rejected; existing policies remain stored |
| 15 | Claim matches exactly one category/currency/date active policy | Claim validator should use that policy and compare amount; this becomes an integration test after validator reconciliation |
| 16 | Claim has no exact active policy match | Claim validation fails closed; no approval transition |
| 17 | Two applicable policies are found due to direct table manipulation | Claim validation reports ambiguity and fails closed |
| 18 | User without POLICY role/action runs create, update, or display | Authorization error; no database mutation |

## Activation / creation order

1. Confirm or create the shared category and active domains/data elements.
2. Create/activate `ZEXP_D_POLICY_ID` and `ZEXP_E_POLICY_ID`.
3. In SE11 create `ZEXP_POLICY`, primary key `(MANDT, POLICY_ID)`, all fields above, and `MAX_AMOUNT` currency reference to `CURRENCY`.
4. Add its category foreign key and non-unique lookup index; activate the table.
5. Create/activate lock object `EZEXPPOL` with `MANDT` as its lock argument. Confirm generated function modules `ENQUEUE_EZEXPPOL` and `DEQUEUE_EZEXPPOL`.
6. Configure PFCG role `POLICY` for activities 01, 02, and 03, plus report-start authorization.
7. In SE38 create `ZEXP_POLICY_MAINT`, paste source, run syntax check, resolve release-specific issues, and activate.
8. Create/display the four category records, then create policies, and execute the test cases.

## Integration assumptions and unresolved issues

- Module 1 employee report, table, and authorization setup are **not assumed to work**. This module depends on the `ZEXP_CAT` table and shared category/active/auth objects being created and activated separately.
- The project’s existing `ZEXP_POLICY` design used category + start date as the primary key and did not store a policy identifier. This Module 2 design changes the key to `(MANDT, POLICY_ID)`. Existing prototype data must be migrated/recreated before activating this schema; do not expect automatic conversion.
- The existing claim validation report references the old policy shape and has not been reconciled here. It must be updated before integrated claims can use this policy table.
- Add `POLICY_ID` to the claim/validation snapshot design before treating a validation result as reproducible against the exact policy version. The prior draft only stored `POLICY_VALID_FROM`.
- SAP usernames and ABAP release are unconfirmed. This module does not need the employee username field, but depends on classic SALV, `TCURC`, generated enqueue modules, and authorization-field configuration.
- No SAP Dictionary object has been created or activated here. The ABAP source has not been syntax-checked or run in SAP.

## Review checklist before Module 3

- [ ] Confirm SAP product/release and verify source syntax in SE38.
- [ ] Confirm `ZEXP_CAT` and shared category/active/auth objects exist in the target client.
- [ ] Review/activate `ZEXP_POLICY` with policy ID key, currency reference, category foreign key, and lookup index.
- [ ] Activate `EZEXPPOL`; verify generated function module signatures match report calls.
- [ ] Configure and test POLICY create/update/display authorizations.
- [ ] Run Module 2 test cases and record actual outcomes.
- [ ] Resolve the documented policy-schema migration and validator snapshot work before claim integration.
- [ ] Do not start Module 3 until Module 2 design/code review and unresolved issues are recorded.
