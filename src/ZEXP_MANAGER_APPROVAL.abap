REPORT zexp_manager_approval.

PARAMETERS:
  p_claim TYPE zexp_claim-claim_id OBLIGATORY,
  p_appr RADIOBUTTON GROUP dec DEFAULT 'X',
  p_rej RADIOBUTTON GROUP dec,
  p_reason TYPE zexp_approval-rejection_reason LOWER CASE.

DATA: ls_claim TYPE zexp_claim,
      ls_employee TYPE zexp_emp,
      ls_manager TYPE zexp_emp,
      ls_approval TYPE zexp_approval.

AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
  ID 'ACTVT' FIELD '02'
  ID 'ZEXP_ROLE' FIELD 'MANAGER'.
IF sy-subrc <> 0.
  MESSAGE 'Not authorized to decide claims' TYPE 'E'.
ENDIF.
IF p_rej = 'X' AND p_reason IS INITIAL.
  MESSAGE 'A rejection reason is required' TYPE 'E'.
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
IF ls_claim-status <> 'PENDING_APPROVAL'.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Only pending claims can receive a decision' TYPE 'E'.
ENDIF.

SELECT SINGLE * INTO ls_employee
  FROM zexp_emp
  WHERE emp_id = ls_claim-emp_id.
IF sy-subrc <> 0 OR ls_employee-manager_id <> ls_manager-emp_id.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'You are not the assigned manager for this employee' TYPE 'E'.
ENDIF.

SELECT SINGLE claim_id INTO ls_approval-claim_id
  FROM zexp_approval
  WHERE claim_id = p_claim.
IF sy-subrc = 0.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'A decision has already been recorded for this claim' TYPE 'E'.
ENDIF.

CLEAR ls_approval.
ls_approval-mandt = sy-mandt.
ls_approval-claim_id = p_claim.
ls_approval-approver_id = ls_manager-emp_id.
IF p_appr = 'X'.
  ls_approval-decision = 'A'.
  ls_claim-status = 'APPROVED'.
ELSE.
  ls_approval-decision = 'R'.
  ls_approval-rejection_reason = p_reason.
  ls_claim-status = 'REJECTED'.
ENDIF.
ls_approval-decided_on = sy-datum.
ls_approval-decided_at = sy-uzeit.

INSERT zexp_approval FROM ls_approval.
IF sy-subrc <> 0.
  ROLLBACK WORK.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Approval decision could not be saved' TYPE 'E'.
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
MESSAGE 'Claim decision recorded' TYPE 'S'.
