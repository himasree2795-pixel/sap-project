REPORT zexp_claim_validate.

PARAMETERS p_claim TYPE zexp_claim-claim_id OBLIGATORY.

DATA: ls_claim TYPE zexp_claim,
      ls_employee TYPE zexp_emp,
      ls_manager TYPE zexp_emp,
      ls_category TYPE zexp_cat,
      ls_policy TYPE zexp_policy,
      ls_policy_candidate TYPE zexp_policy,
      lt_policies TYPE STANDARD TABLE OF zexp_policy,
      ls_validation TYPE zexp_valid,
      lv_validation_no TYPE n LENGTH 3,
      lv_last_no TYPE i,
      lv_policy_found TYPE c LENGTH 1,
      lv_result_text TYPE zexp_valid-result_text,
      lv_result TYPE zexp_valid-result.

AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
  ID 'ACTVT' FIELD '02'
  ID 'ZEXP_ROLE' FIELD 'MANAGER'.
IF sy-subrc <> 0.
  MESSAGE 'Not authorized to validate claims' TYPE 'E'.
ENDIF.
SELECT SINGLE * INTO ls_manager
  FROM zexp_emp
  WHERE sap_user = sy-uname
    AND active = 'X'.
IF sy-subrc <> 0.
  MESSAGE 'Current SAP user is not an active manager employee' TYPE 'E'.
ENDIF.

CALL FUNCTION 'ENQUEUE_EZEXPCLM'
  EXPORTING
    mandt = sy-mandt
    claim_id = p_claim
    _wait = 'X'
  EXCEPTIONS
    foreign_lock = 1
    system_failure = 2
    OTHERS = 3.
IF sy-subrc <> 0.
  MESSAGE 'Claim is locked or could not be locked' TYPE 'E'.
ENDIF.

SELECT SINGLE * INTO ls_claim
  FROM zexp_claim
  WHERE claim_id = p_claim.
IF sy-subrc <> 0.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Claim does not exist' TYPE 'E'.
ENDIF.
IF ls_claim-status <> 'SUBMITTED'.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Only submitted claims can be validated' TYPE 'E'.
ENDIF.
SELECT SINGLE * INTO ls_employee
  FROM zexp_emp
  WHERE emp_id = ls_claim-emp_id.
IF sy-subrc <> 0 OR ls_employee-manager_id <> ls_manager-emp_id.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'You are not the assigned manager for this employee' TYPE 'E'.
ENDIF.

lv_result = 'F'.
IF ls_claim-emp_id IS INITIAL OR ls_claim-category_id IS INITIAL
   OR ls_claim-expense_date IS INITIAL OR ls_claim-description IS INITIAL.
  lv_result_text = 'Claim is missing required employee, category, date, or description data'.
ELSEIF ls_claim-amount <= 0.
  lv_result_text = 'Claim amount must be positive'.
ELSEIF ls_claim-expense_date > sy-datum.
  lv_result_text = 'Expense date cannot be in the future'.
ELSE.
  SELECT SINGLE * INTO ls_employee
    FROM zexp_emp
    WHERE emp_id = ls_claim-emp_id
      AND active = 'X'.
  IF sy-subrc <> 0.
    lv_result_text = 'Employee is missing or inactive'.
  ELSE.
    SELECT SINGLE * INTO ls_category
      FROM zexp_cat
      WHERE category_id = ls_claim-category_id
        AND active = 'X'.
    IF sy-subrc <> 0.
      lv_result_text = 'Category is missing or inactive'.
    ELSE.
      SELECT * INTO TABLE lt_policies
        FROM zexp_policy
        WHERE category_id = ls_claim-category_id
          AND valid_from <= ls_claim-expense_date
          AND active = 'X'.
      CLEAR lv_policy_found.
      CLEAR ls_policy.
      LOOP AT lt_policies INTO ls_policy_candidate.
        IF ls_policy_candidate-valid_to IS INITIAL
           OR ls_policy_candidate-valid_to >= ls_claim-expense_date.
          IF lv_policy_found IS INITIAL
             OR ls_policy_candidate-valid_from > ls_policy-valid_from.
            ls_policy = ls_policy_candidate.
            lv_policy_found = 'X'.
          ENDIF.
        ENDIF.
      ENDLOOP.
      IF lv_policy_found IS INITIAL.
        lv_result_text = 'No active policy covers the expense date'.
      ELSEIF ls_policy-currency <> ls_claim-currency.
        lv_result_text = 'Claim currency must match the policy currency'.
      ELSEIF ls_claim-amount > ls_policy-max_amount.
        lv_result_text = 'Claim amount exceeds the policy limit'.
      ELSE.
        lv_result = 'P'.
        lv_result_text = 'Claim passed employee, category, date, currency, and limit checks'.
      ENDIF.
    ENDIF.
  ENDIF.
ENDIF.

SELECT MAX( validation_no ) INTO lv_last_no
  FROM zexp_valid
  WHERE claim_id = p_claim.
IF lv_last_no >= 999.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Validation attempt limit reached' TYPE 'E'.
ENDIF.
lv_last_no = lv_last_no + 1.
lv_validation_no = lv_last_no.

CLEAR ls_validation.
ls_validation-mandt = sy-mandt.
ls_validation-claim_id = p_claim.
ls_validation-validation_no = lv_validation_no.
ls_validation-result = lv_result.
ls_validation-result_text = lv_result_text.
IF lv_result = 'P'.
  ls_validation-policy_valid_from = ls_policy-valid_from.
  ls_claim-policy_valid_from = ls_policy-valid_from.
  ls_claim-status = 'PENDING_APPROVAL'.
ELSE.
  ls_claim-status = 'VALIDATION_FAILED'.
ENDIF.
ls_validation-validated_by = sy-uname.
ls_validation-validated_on = sy-datum.
ls_validation-validated_at = sy-uzeit.

INSERT zexp_valid FROM ls_validation.
IF sy-subrc <> 0.
  ROLLBACK WORK.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Validation result could not be recorded' TYPE 'E'.
ENDIF.
UPDATE zexp_claim FROM ls_claim.
IF sy-subrc <> 0.
  ROLLBACK WORK.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Claim status could not be updated' TYPE 'E'.
ENDIF.
COMMIT WORK AND WAIT.
CALL FUNCTION 'DEQUEUE_EZEXPCLM'
  EXPORTING mandt = sy-mandt claim_id = p_claim.

IF lv_result = 'P'.
  MESSAGE 'Claim validated and sent for approval' TYPE 'S'.
ELSE.
  MESSAGE lv_result_text TYPE 'S' DISPLAY LIKE 'E'.
ENDIF.
