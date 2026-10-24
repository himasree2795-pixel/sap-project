REPORT zexp_claim_submit.

PARAMETERS:
  p_emp TYPE zexp_claim-emp_id OBLIGATORY,
  p_cat TYPE zexp_claim-category_id OBLIGATORY,
  p_amt TYPE zexp_claim-amount OBLIGATORY,
  p_cur TYPE zexp_claim-currency OBLIGATORY,
  p_date TYPE zexp_claim-expense_date OBLIGATORY,
  p_desc TYPE zexp_claim-description LOWER CASE OBLIGATORY.

DATA: ls_employee TYPE zexp_emp,
      ls_category TYPE zexp_cat,
      ls_claim TYPE zexp_claim,
      lv_number TYPE zexp_claim-claim_id,
      lv_currency TYPE waers,
      lv_subrc TYPE sy-subrc.

AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
  ID 'ACTVT' FIELD '01'
  ID 'ZEXP_ROLE' FIELD 'EMPLOYEE'.
IF sy-subrc <> 0.
  MESSAGE 'Not authorized to submit an expense claim' TYPE 'E'.
ENDIF.

IF p_amt <= 0.
  MESSAGE 'Claim amount must be greater than zero' TYPE 'E'.
ENDIF.
IF p_date > sy-datum.
  MESSAGE 'Expense date cannot be in the future' TYPE 'E'.
ENDIF.
IF p_desc IS INITIAL.
  MESSAGE 'Description is required' TYPE 'E'.
ENDIF.
SELECT SINGLE waers INTO lv_currency
  FROM tcurc
  WHERE waers = p_cur.
IF sy-subrc <> 0.
  MESSAGE 'Currency is not configured in SAP' TYPE 'E'.
ENDIF.

SELECT SINGLE * INTO ls_employee
  FROM zexp_emp
  WHERE emp_id = p_emp
    AND active = 'X'.
IF sy-subrc <> 0.
  MESSAGE 'Employee does not exist or is inactive' TYPE 'E'.
ENDIF.
IF ls_employee-sap_user <> sy-uname.
  MESSAGE 'Employees may submit claims only for their own employee ID' TYPE 'E'.
ENDIF.

SELECT SINGLE * INTO ls_category
  FROM zexp_cat
  WHERE category_id = p_cat
    AND active = 'X'.
IF sy-subrc <> 0.
  MESSAGE 'Expense category does not exist or is inactive' TYPE 'E'.
ENDIF.

CALL FUNCTION 'NUMBER_GET_NEXT'
  EXPORTING
    nr_range_nr = '01'
    object = 'ZEXP_CLM'
  IMPORTING
    number = lv_number
  EXCEPTIONS
    interval_not_found = 1
    number_range_not_intern = 2
    object_not_found = 3
    quantity_is_0 = 4
    quantity_is_not_1 = 5
    interval_overflow = 6
    buffer_overflow = 7
    OTHERS = 8.
lv_subrc = sy-subrc.
IF lv_subrc <> 0.
  MESSAGE 'Claim number could not be assigned; check SNRO object ZEXP_CLM interval 01' TYPE 'E'.
ENDIF.

CLEAR ls_claim.
ls_claim-mandt = sy-mandt.
ls_claim-claim_id = lv_number.
ls_claim-emp_id = p_emp.
ls_claim-category_id = p_cat.
ls_claim-amount = p_amt.
ls_claim-currency = p_cur.
ls_claim-expense_date = p_date.
ls_claim-description = p_desc.
ls_claim-submitted_on = sy-datum.
ls_claim-status = 'SUBMITTED'.
ls_claim-created_by = sy-uname.
ls_claim-created_on = sy-datum.

INSERT zexp_claim FROM ls_claim.
IF sy-subrc <> 0.
  ROLLBACK WORK.
  MESSAGE 'Claim could not be saved' TYPE 'E'.
ENDIF.
COMMIT WORK AND WAIT.
WRITE: / 'Claim submitted successfully. Claim ID:', lv_number,
       / 'The assigned manager must validate it before approval.'.
MESSAGE 'Claim submitted successfully' TYPE 'S'.
