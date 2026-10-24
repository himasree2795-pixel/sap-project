REPORT zexp_claim_report.

TYPES: BEGIN OF ty_claim_view,
         claim_id TYPE zexp_claim-claim_id,
         emp_id TYPE zexp_claim-emp_id,
         emp_name TYPE zexp_emp-emp_name,
         department TYPE zexp_emp-department,
         category_id TYPE zexp_claim-category_id,
         amount TYPE zexp_claim-amount,
         currency TYPE zexp_claim-currency,
         expense_date TYPE zexp_claim-expense_date,
         submitted_on TYPE zexp_claim-submitted_on,
         status TYPE zexp_claim-status,
         rejection_reason TYPE zexp_approval-rejection_reason,
       END OF ty_claim_view,
       BEGIN OF ty_reimb_view,
         claim_id TYPE zexp_reimb-claim_id,
         emp_id TYPE zexp_claim-emp_id,
         emp_name TYPE zexp_emp-emp_name,
         department TYPE zexp_emp-department,
         category_id TYPE zexp_claim-category_id,
         reference TYPE zexp_reimb-reference,
         amount TYPE zexp_reimb-amount,
         currency TYPE zexp_reimb-currency,
         reimbursed_on TYPE zexp_reimb-reimbursed_on,
         reimb_status TYPE zexp_reimb-status,
       END OF ty_reimb_view,
       BEGIN OF ty_summary,
         group_name TYPE zexp_emp-department,
         currency TYPE waers,
         claim_count TYPE i,
         total_amount TYPE zexp_claim-amount,
       END OF ty_summary.

DATA: lt_claims TYPE STANDARD TABLE OF ty_claim_view,
      ls_claim TYPE ty_claim_view,
      lt_reimbursements TYPE STANDARD TABLE OF ty_reimb_view,
      lt_summary TYPE SORTED TABLE OF ty_summary
        WITH UNIQUE KEY group_name currency,
      ls_summary TYPE ty_summary,
      ls_manager TYPE zexp_emp,
      lo_alv TYPE REF TO cl_salv_table,
      lv_status TYPE zexp_claim-status,
      lv_group TYPE zexp_emp-department.

PARAMETERS:
  p_all RADIOBUTTON GROUP vw DEFAULT 'X',
  p_subm RADIOBUTTON GROUP vw,
  p_pend RADIOBUTTON GROUP vw,
  p_rej RADIOBUTTON GROUP vw,
  p_reimb RADIOBUTTON GROUP vw,
  p_dept RADIOBUTTON GROUP vw,
  p_cats RADIOBUTTON GROUP vw.
SELECT-OPTIONS:
  s_emp FOR ls_claim-emp_id,
  s_date FOR ls_claim-expense_date,
  s_cat FOR ls_claim-category_id.

IF p_pend = 'X' OR p_subm = 'X'.
  AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
    ID 'ACTVT' FIELD '02'
    ID 'ZEXP_ROLE' FIELD 'MANAGER'.
  IF sy-subrc <> 0.
    MESSAGE 'Not authorized to view the manager worklist' TYPE 'E'.
  ENDIF.
  SELECT SINGLE * INTO ls_manager
    FROM zexp_emp
    WHERE sap_user = sy-uname
      AND active = 'X'.
  IF sy-subrc <> 0.
    MESSAGE 'Current SAP user is not an active manager employee' TYPE 'E'.
  ENDIF.
ELSE.
  AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
    ID 'ACTVT' FIELD '03'
    ID 'ZEXP_ROLE' FIELD 'REPORT'.
  IF sy-subrc <> 0.
    MESSAGE 'Not authorized to view expense reports' TYPE 'E'.
  ENDIF.
ENDIF.

IF p_reimb = 'X'.
  SELECT r~claim_id c~emp_id e~emp_name e~department c~category_id
         r~reference r~amount r~currency r~reimbursed_on r~status
    INTO TABLE lt_reimbursements
    FROM zexp_reimb AS r
    INNER JOIN zexp_claim AS c ON c~claim_id = r~claim_id
    INNER JOIN zexp_emp AS e ON e~emp_id = c~emp_id
    WHERE c~emp_id IN s_emp
      AND c~expense_date IN s_date
      AND c~category_id IN s_cat.
  IF lt_reimbursements IS INITIAL.
    MESSAGE 'No reimbursements match the selected filters' TYPE 'S'.
    RETURN.
  ENDIF.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_reimbursements ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Could not create reimbursement ALV' TYPE 'E'.
  ENDTRY.
  RETURN.
ENDIF.

IF p_pend = 'X'.
  lv_status = 'PENDING_APPROVAL'.
ELSEIF p_subm = 'X'.
  lv_status = 'SUBMITTED'.
ELSEIF p_rej = 'X'.
  lv_status = 'REJECTED'.
ELSE.
  CLEAR lv_status.
ENDIF.

IF p_pend = 'X' OR p_subm = 'X'.
  SELECT c~claim_id c~emp_id e~emp_name e~department c~category_id
         c~amount c~currency c~expense_date c~submitted_on c~status
         a~rejection_reason
    INTO TABLE lt_claims
    FROM zexp_claim AS c
    INNER JOIN zexp_emp AS e ON e~emp_id = c~emp_id
    LEFT OUTER JOIN zexp_approval AS a ON a~claim_id = c~claim_id
    WHERE c~emp_id IN s_emp
      AND c~expense_date IN s_date
      AND c~category_id IN s_cat
      AND c~status = lv_status
      AND e~manager_id = ls_manager-emp_id.
ELSE.
  SELECT c~claim_id c~emp_id e~emp_name e~department c~category_id
         c~amount c~currency c~expense_date c~submitted_on c~status
         a~rejection_reason
    INTO TABLE lt_claims
    FROM zexp_claim AS c
    INNER JOIN zexp_emp AS e ON e~emp_id = c~emp_id
    LEFT OUTER JOIN zexp_approval AS a ON a~claim_id = c~claim_id
    WHERE c~emp_id IN s_emp
      AND c~expense_date IN s_date
      AND c~category_id IN s_cat.
  IF p_rej = 'X'.
    DELETE lt_claims WHERE status <> lv_status.
  ENDIF.
ENDIF.

IF lt_claims IS INITIAL.
  MESSAGE 'No claims match the selected filters' TYPE 'S'.
  RETURN.
ENDIF.

IF p_dept = 'X' OR p_cats = 'X'.
  LOOP AT lt_claims INTO ls_claim.
    IF p_dept = 'X'.
      lv_group = ls_claim-department.
    ELSE.
      lv_group = ls_claim-category_id.
    ENDIF.
    READ TABLE lt_summary INTO ls_summary
      WITH TABLE KEY group_name = lv_group
                     currency = ls_claim-currency.
    IF sy-subrc = 0.
      DELETE TABLE lt_summary FROM ls_summary.
      ls_summary-claim_count = ls_summary-claim_count + 1.
      ls_summary-total_amount = ls_summary-total_amount + ls_claim-amount.
      INSERT ls_summary INTO TABLE lt_summary.
    ELSE.
      CLEAR ls_summary.
      ls_summary-group_name = lv_group.
      ls_summary-currency = ls_claim-currency.
      ls_summary-claim_count = 1.
      ls_summary-total_amount = ls_claim-amount.
      INSERT ls_summary INTO TABLE lt_summary.
    ENDIF.
  ENDLOOP.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_summary ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Could not create summary ALV' TYPE 'E'.
  ENDTRY.
ELSE.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_claims ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Could not create claims ALV' TYPE 'E'.
  ENDTRY.
ENDIF.
