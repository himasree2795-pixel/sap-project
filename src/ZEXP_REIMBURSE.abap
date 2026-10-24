REPORT zexp_reimburse.

PARAMETERS:
  p_claim TYPE zexp_claim-claim_id OBLIGATORY,
  p_ref TYPE zexp_reimb-reference OBLIGATORY,
  p_amt TYPE zexp_reimb-amount OBLIGATORY,
  p_cur TYPE zexp_reimb-currency OBLIGATORY,
  p_date TYPE zexp_reimb-reimbursed_on DEFAULT sy-datum.

DATA: ls_claim TYPE zexp_claim,
      ls_reimb TYPE zexp_reimb,
      lv_existing TYPE zexp_reimb-claim_id,
      lv_ref_existing TYPE zexp_reimb-reference.

AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
  ID 'ACTVT' FIELD '02'
  ID 'ZEXP_ROLE' FIELD 'FINANCE'.
IF sy-subrc <> 0.
  MESSAGE 'Not authorized to record reimbursements' TYPE 'E'.
ENDIF.
IF p_amt <= 0 OR p_ref IS INITIAL OR p_cur IS INITIAL OR p_date IS INITIAL.
  MESSAGE 'Reference, positive amount, currency, and date are required' TYPE 'E'.
ENDIF.
IF p_date > sy-datum.
  MESSAGE 'Reimbursement record date cannot be in the future' TYPE 'E'.
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
IF ls_claim-status <> 'APPROVED'.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Only approved claims can be reimbursed' TYPE 'E'.
ENDIF.
IF p_amt <> ls_claim-amount OR p_cur <> ls_claim-currency.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Reimbursement amount and currency must match the approved claim' TYPE 'E'.
ENDIF.

SELECT SINGLE claim_id INTO lv_existing
  FROM zexp_reimb
  WHERE claim_id = p_claim.
IF sy-subrc = 0.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'A reimbursement already exists for this claim' TYPE 'E'.
ENDIF.
SELECT SINGLE reference INTO lv_ref_existing
  FROM zexp_reimb
  WHERE reference = p_ref.
IF sy-subrc = 0.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Reimbursement reference is already in use' TYPE 'E'.
ENDIF.

CLEAR ls_reimb.
ls_reimb-mandt = sy-mandt.
ls_reimb-claim_id = p_claim.
ls_reimb-reference = p_ref.
ls_reimb-amount = p_amt.
ls_reimb-currency = p_cur.
ls_reimb-reimbursed_on = p_date.
ls_reimb-status = 'RECORDED'.
ls_reimb-recorded_by = sy-uname.

INSERT zexp_reimb FROM ls_reimb.
IF sy-subrc <> 0.
  ROLLBACK WORK.
  CALL FUNCTION 'DEQUEUE_EZEXPCLM'
    EXPORTING mandt = sy-mandt claim_id = p_claim.
  MESSAGE 'Reimbursement record could not be saved' TYPE 'E'.
ENDIF.
ls_claim-status = 'REIMBURSED'.
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
MESSAGE 'Simulated reimbursement recorded; no bank transfer or FI posting was made' TYPE 'S'.
