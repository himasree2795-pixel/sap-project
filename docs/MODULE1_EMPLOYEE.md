# Module 1 — Employee Management

## Target environment and compatibility

This module is written for **classic SAP GUI / classic ABAP**, using SE11, SE38, Open SQL, classic `AUTHORITY-CHECK`, and `CL_SALV_TABLE` for display. This is the intended programming model, not ABAP Cloud.

The actual SAP product and release available to the student remain **unknown**; there is no connected SAP system. The source avoids newer inline declarations, but still assumes a classic ABAP release that provides `CL_SALV_TABLE`, regular-expression `FIND`, and standard executable-report selection screens. Verify these objects and syntax in the target system's SE11/SE38 before relying on them. ABAP Cloud is not supported by this source.

## Step 1 — Table design

Create transparent, client-dependent table `ZEXP_EMP`. Use delivery class `A` for application data, data class `APPL0`, and a small initial size category. Set the table's enhancement category according to local standards.

| Field | Key | Dictionary type / length | Required | Purpose |
|---|---:|---|---:|---|
| `MANDT` | Yes | `CLNT`, 3 | Yes | Client key |
| `EMP_ID` | Yes | Data element `ZEXP_E_EMP_ID` / domain `ZEXP_D_EMP_ID`, `CHAR`, 10 | Yes | Stable employee identifier |
| `EMP_NAME` | No | `CHAR`, 80 | Yes | Employee name |
| `DEPARTMENT` | No | `CHAR`, 40 | Yes | Department |
| `DESIGNATION` | No | `CHAR`, 40 | Yes | Job designation |
| `EMAIL` | No | `ZEXP_E_EMAIL` / `ZEXP_D_EMAIL`, `CHAR`, 241 | Yes | Contact email |
| `ACTIVE` | No | `ZEXP_E_ACTIVE` / `ZEXP_D_ACTIVE`, `CHAR`, 1 | Yes | `X` active; blank inactive |
| `SAP_USER` | No | `CHAR`, 12 | Yes | SAP logon name mapping used by claim submission and manager authorization |
| `MANAGER_ID` | No | `ZEXP_E_EMP_ID`, `CHAR`, 10 | No | Direct manager employee ID; blank for top-level employees |
| `CREATED_ON` | No | `DATS`, 8 | Yes | Creation date |
| `CHANGED_ON` | No | `DATS`, 8 | Yes | Last update date; initially same as creation date |
| `CREATED_BY` | No | `CHAR`, 12 | Yes | SAP user who created the row |
| `CHANGED_BY` | No | `CHAR`, 12 | Yes | SAP user who last changed the row |

The primary key is `(MANDT, EMP_ID)`. Create a **unique secondary index** on `(MANDT, SAP_USER)` because one SAP logon must map to at most one employee in this capstone. This assumes 12-character SAP usernames; verify the username length/type used by the target release. If longer usernames are configured, enlarge `SAP_USER` consistently before activation and update the report input type through its table reference.

`SAP_USER` and `MANAGER_ID` are additional integration fields: later claim and manager modules rely on them. The creation/update dates and user IDs provide basic audit data. The application does not physically delete employee rows.

## Step 2 — Supporting objects

Reuse the shared Dictionary objects already specified by the project; create only those needed for Module 1:

1. `ZEXP_D_EMP_ID` — domain, `CHAR 10`.
2. `ZEXP_E_EMP_ID` — data element referencing `ZEXP_D_EMP_ID`.
3. `ZEXP_D_EMAIL` — domain, `CHAR 241`.
4. `ZEXP_E_EMAIL` — data element referencing `ZEXP_D_EMAIL`.
5. `ZEXP_D_ACTIVE` — domain, `CHAR 1`, fixed value `X` (active); initial blank means inactive.
6. `ZEXP_E_ACTIVE` — data element referencing `ZEXP_D_ACTIVE`.
7. `ZEXP_EMP` — transparent table defined above.
8. Unique secondary index `Z01` (or next available customer index name) on `MANDT`, `SAP_USER`.
9. `ZEXP_AUTH` — authorization object with fields `ACTVT` and `ZEXP_ROLE`; the authorization field/data element is part of the shared project security setup, not a new employee-specific object.
10. `ZEXP_EMP_MAINT` — executable report.

No search help is needed for the initial version: employee IDs and SAP usernames are entered directly, and display can show one row by employee ID or all rows in ALV. No separate data elements are needed for one-use text fields. Create these domains/data elements only if they do not already exist in the project system.

## Step 3 — Employee maintenance report

**Object:** `ZEXP_EMP_MAINT`

**Type:** Executable ABAP report (SE38)

**Purpose:** Create, display, update employee details, and set active/inactive status.

**Dependencies:** `ZEXP_EMP`, the three employee-related data elements/domains, active SALV runtime, and `ZEXP_AUTH`.

### Interface behavior

The report selection screen offers four actions:

- **Create:** Provide ID, name, department, designation, email, SAP user, and optional manager. New records start active.
- **Display:** Provide an employee ID to display one row, or leave it blank to display all employees. Requires `REPORT` role authorization.
- **Update:** Provide the employee ID and the complete desired set of required employee details. The active status is intentionally not changed by this operation. To clear a manager assignment, leave manager ID blank.
- **Status:** Provide employee ID and use the `Active` checkbox: checked activates; unchecked deactivates. The row is retained.

For update mode, required values are supplied as a complete record rather than a partial patch; this avoids accidentally saving blank required attributes. Always display the employee first if you need the existing values.

### Complete code

The complete report source is [ZEXP_EMP_MAINT.abap](../src/ZEXP_EMP_MAINT.abap). Create a report with that exact name in SE38 and enter the entire file contents. Do not paste the Markdown fences or this explanatory document into the ABAP editor.

## Step 4 — Validation

- The report requires employee ID, name, department, designation, email, and SAP username for create/update.
- It checks the email against a practical basic `local-part@domain.tld` pattern. This is not full RFC email validation and does not send a verification email.
- Duplicate employee IDs are checked before insert; the database primary key remains the final safeguard against concurrent duplicates.
- Duplicate SAP usernames are checked before save; the unique secondary index is the database safeguard.
- A supplied manager must exist and be active; an employee cannot be their own manager. A blank manager is permitted for top-level employees.
- Only `X` and blank represent active/inactive. New rows are created active; status change has a dedicated action.
- Employees cannot be physically deleted through this report.

## Step 5 — Error handling and security

Create authorization object `ZEXP_AUTH` in SU21 with activity field `ACTVT` and role field `ZEXP_ROLE`. Create the custom role authorization field in SU20 as described in the main setup guide. Configure these combinations in PFCG:

| Operation | Required values |
|---|---|
| Create | `ACTVT=01`, `ZEXP_ROLE=ADMIN` |
| Update details / change status | `ACTVT=02`, `ZEXP_ROLE=ADMIN` |
| Display | `ACTVT=03`, `ZEXP_ROLE=REPORT` |

Check both the custom object and normal program/transaction start authorization through PFCG. Restrict generic SE16/SM30/table-update access to trusted administrators; the report's checks do not protect against direct table edits by a broadly authorized user.

Input and database failures are surfaced with ABAP messages. Successful operations produce status messages. Display uses SALV and catches its specific `CX_SALV_MSG` exception; there is no broad exception catch or silent success fallback.

## Step 6 — Test cases

Execute in a development/training client after activation and role setup. These are **expected results**, not executed test results.

| # | Action | Expected result |
|---|---|---|
| 1 | Authorized admin creates a complete employee record | One row inserted, active `X`, creation/update dates set to today, user audit set |
| 2 | Admin creates the same employee ID again | Duplicate message; existing row unchanged |
| 3 | Admin creates another employee with a SAP username already assigned | Duplicate SAP-user message; no row inserted |
| 4 | Admin omits a required create field | Validation message; no row inserted |
| 5 | Admin enters malformed email such as `person@invalid` or `person.example` | Email validation message; no row inserted |
| 6 | Admin assigns nonexistent/inactive manager or self as manager | Validation message; no row inserted |
| 7 | Authorized report user displays a known ID | One matching row shown in ALV |
| 8 | Authorized report user leaves ID blank in display mode | Employee records shown in ALV |
| 9 | Authorized report user requests an unknown ID | Informational no-records message |
| 10 | Admin updates details for an existing employee | Details and last-update audit fields change; active status remains unchanged |
| 11 | Admin attempts update for an unknown employee ID | Error message; no row inserted |
| 12 | Admin unchecks Active in status mode | Active field becomes blank; row remains and last-update audit fields change |
| 13 | Admin checks Active in status mode | Active field becomes `X` |
| 14 | User without required authorization attempts each action | Authorization error; no database mutation |

## Activation / creation order

1. In SE11, create/activate `ZEXP_D_EMP_ID`, then `ZEXP_E_EMP_ID`.
2. Create/activate `ZEXP_D_EMAIL`, then `ZEXP_E_EMAIL`.
3. Create/activate `ZEXP_D_ACTIVE` with fixed value `X` (blank is the initial inactive value), then `ZEXP_E_ACTIVE`.
4. Create `ZEXP_EMP` with the fields and key above; set the client field and technical settings; add foreign-key check from `MANAGER_ID` to the employee key if supported cleanly by your release.
5. Create the unique secondary index on `(MANDT, SAP_USER)` and activate the table.
6. In SU20/SU21 create or verify the shared `ZEXP_ROLE` field and `ZEXP_AUTH` object, then configure PFCG authorizations.
7. In SE38 create `ZEXP_EMP_MAINT`, paste the complete source, run the syntax check, resolve any release-specific messages, and activate.
8. Run the manual tests above using appropriately separated admin/report users. Assign a transaction code in SE93 only if desired.

## Review checklist before considering Module 1 complete

- [ ] Confirm actual SAP product, ABAP release, and configured SAP username length.
- [ ] Confirm all reused domains/data elements either already exist or were created and activated.
- [ ] Confirm table key, required fields, technical settings, and unique SAP-user index in SE11.
- [ ] Confirm no direct employee delete option or SM30 exposure to ordinary users.
- [ ] Confirm PFCG activity/role combinations for admin and report users.
- [ ] Run SE38 syntax check and activate the report in the target system.
- [ ] Execute and document test cases 1–14 with actual results.
- [ ] Record unresolved syntax, authorization, or behavior issues before starting Module 2.

## Known limitations

- The actual SAP release is unknown; source compatibility must be checked in the target system.
- There is no SAP system available here. The source has not been compiled, activated, or executed in SAP.
- The email check is intentionally basic; it does not validate deliverability or every standards-compliant address.
- Display is read-only classic SALV; there is no search help, paging/filter dialog beyond SALV features, or dedicated edit screen.
- This report updates one employee at a time and does not preserve a full historical status/change log.
- SAP username length is assumed to be 12 characters in the table specification; confirm it against the target installation.
