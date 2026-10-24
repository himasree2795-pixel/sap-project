REPORT zexp_policy_maint.

PARAMETERS:
  p_policy RADIOBUTTON GROUP obj DEFAULT 'X',
  p_categ RADIOBUTTON GROUP obj.

PARAMETERS:
  p_new RADIOBUTTON GROUP act DEFAULT 'X',
  p_disp RADIOBUTTON GROUP act,
  p_upd RADIOBUTTON GROUP act.

PARAMETERS:
  p_id TYPE zexp_policy-policy_id,
  p_cid TYPE zexp_policy-category_id,
  p_max TYPE zexp_policy-max_amount,
  p_curr TYPE zexp_policy-currency,
  p_from TYPE zexp_policy-valid_from,
  p_to TYPE zexp_policy-valid_to,
  p_act AS CHECKBOX DEFAULT 'X'.

DATA: ls_policy TYPE zexp_policy,
      ls_existing_policy TYPE zexp_policy,
      ls_candidate TYPE zexp_policy,
      lt_policies TYPE STANDARD TABLE OF zexp_policy,
      lt_categories TYPE STANDARD TABLE OF zexp_cat,
      ls_category TYPE zexp_cat,
      lv_currency TYPE waers,
      lv_category_name TYPE zexp_cat-category_name,
      lv_activity TYPE c LENGTH 2,
      lv_error TYPE c LENGTH 120,
      lv_locked TYPE c LENGTH 1,
      lo_alv TYPE REF TO cl_salv_table.

START-OF-SELECTION.
  PERFORM check_authority.

  IF p_policy = 'X'.
    IF p_disp = 'X'.
      PERFORM display_policies.
    ELSE.
      PERFORM maintain_policy.
    ENDIF.
  ELSE.
    IF p_disp = 'X'.
      PERFORM display_categories.
    ELSE.
      PERFORM maintain_category.
    ENDIF.
  ENDIF.

FORM check_authority.
  IF p_disp = 'X'.
    lv_activity = '03'.
  ELSEIF p_new = 'X'.
    lv_activity = '01'.
  ELSE.
    lv_activity = '02'.
  ENDIF.

  AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
    ID 'ACTVT' FIELD lv_activity
    ID 'ZEXP_ROLE' FIELD 'POLICY'.
  IF sy-subrc <> 0.
    MESSAGE 'Not authorized for this policy operation' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM display_policies.
  IF p_id IS INITIAL.
    SELECT * INTO TABLE lt_policies
      FROM zexp_policy
      ORDER BY policy_id.
  ELSE.
    SELECT * INTO TABLE lt_policies
      FROM zexp_policy
      WHERE policy_id = p_id
      ORDER BY policy_id.
  ENDIF.

  IF lt_policies IS INITIAL.
    MESSAGE 'No policy records found for the selection' TYPE 'S'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_policies ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Policy list could not be displayed in ALV' TYPE 'E'.
  ENDTRY.
ENDFORM.

FORM display_categories.
  IF p_cid IS INITIAL.
    SELECT * INTO TABLE lt_categories
      FROM zexp_cat
      ORDER BY category_id.
  ELSE.
    SELECT * INTO TABLE lt_categories
      FROM zexp_cat
      WHERE category_id = p_cid
      ORDER BY category_id.
  ENDIF.

  IF lt_categories IS INITIAL.
    MESSAGE 'No category records found for the selection' TYPE 'S'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_categories ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Category list could not be displayed in ALV' TYPE 'E'.
  ENDTRY.
ENDFORM.

FORM maintain_category.
  IF p_cid IS INITIAL.
    MESSAGE 'Category ID is required' TYPE 'E'.
  ENDIF.

  PERFORM validate_category_id.

  IF p_act <> 'X' AND p_act <> space.
    MESSAGE 'Category status must be active or inactive' TYPE 'E'.
  ENDIF.

  PERFORM lock_policy_client.

  SELECT SINGLE * INTO ls_category
    FROM zexp_cat
    WHERE category_id = p_cid.

  IF p_new = 'X'.
    IF sy-subrc = 0.
      lv_error = 'Category already exists; use update mode'.
      PERFORM fail_locked USING lv_error.
    ENDIF.
    CLEAR ls_category.
    ls_category-mandt = sy-mandt.
    ls_category-category_id = p_cid.
    ls_category-category_name = lv_category_name.
    ls_category-active = 'X'.
    INSERT zexp_cat FROM ls_category.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      lv_error = 'Category could not be created'.
      PERFORM fail_locked USING lv_error.
    ENDIF.
    COMMIT WORK AND WAIT.
    PERFORM unlock_policy_client.
    MESSAGE 'Category created and activated' TYPE 'S'.
  ELSE.
    IF sy-subrc <> 0.
      lv_error = 'Category does not exist; use create mode'.
      PERFORM fail_locked USING lv_error.
    ENDIF.
    ls_category-category_name = lv_category_name.
    ls_category-active = p_act.
    UPDATE zexp_cat FROM ls_category.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      lv_error = 'Category could not be updated'.
      PERFORM fail_locked USING lv_error.
    ENDIF.
    COMMIT WORK AND WAIT.
    PERFORM unlock_policy_client.
    MESSAGE 'Category updated' TYPE 'S'.
  ENDIF.
ENDFORM.

FORM maintain_policy.
  IF p_id IS INITIAL OR p_cid IS INITIAL OR p_from IS INITIAL
     OR p_max <= 0 OR p_curr IS INITIAL.
    MESSAGE 'Policy ID, category, start date, positive limit, and currency are required' TYPE 'E'.
  ENDIF.
  IF p_to IS NOT INITIAL AND p_to < p_from.
    MESSAGE 'Validity end date cannot precede its start date' TYPE 'E'.
  ENDIF.
  IF p_act <> 'X' AND p_act <> space.
    MESSAGE 'Policy status must be active or inactive' TYPE 'E'.
  ENDIF.
  PERFORM validate_category_id.

  SELECT SINGLE waers INTO lv_currency
    FROM tcurc
    WHERE waers = p_curr.
  IF sy-subrc <> 0.
    MESSAGE 'Currency is not configured in SAP' TYPE 'E'.
  ENDIF.

  PERFORM lock_policy_client.

  SELECT SINGLE * INTO ls_existing_policy
    FROM zexp_policy
    WHERE policy_id = p_id.

  IF p_new = 'X' AND sy-subrc = 0.
    lv_error = 'Policy ID already exists; use update mode'.
    PERFORM fail_locked USING lv_error.
  ELSEIF p_upd = 'X' AND sy-subrc <> 0.
    lv_error = 'Policy ID does not exist; use create mode'.
    PERFORM fail_locked USING lv_error.
  ENDIF.

  SELECT SINGLE category_id INTO ls_category-category_id
    FROM zexp_cat
    WHERE category_id = p_cid
      AND active = 'X'.
  IF sy-subrc <> 0.
    lv_error = 'Policy requires an existing active category'.
    PERFORM fail_locked USING lv_error.
  ENDIF.

  IF p_act = 'X'.
    SELECT * INTO TABLE lt_policies
      FROM zexp_policy
      WHERE category_id = p_cid
        AND currency = p_curr
        AND active = 'X'.

    LOOP AT lt_policies INTO ls_candidate.
      IF ls_candidate-policy_id <> p_id.
        IF ( p_to IS INITIAL OR ls_candidate-valid_from <= p_to )
           AND ( ls_candidate-valid_to IS INITIAL
                 OR ls_candidate-valid_to >= p_from ).
          lv_error = 'Active policy dates overlap for this category and currency'.
          PERFORM fail_locked USING lv_error.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDIF.

  CLEAR ls_policy.
  ls_policy-mandt = sy-mandt.
  ls_policy-policy_id = p_id.
  ls_policy-category_id = p_cid.
  ls_policy-max_amount = p_max.
  ls_policy-currency = p_curr.
  ls_policy-active = p_act.
  ls_policy-valid_from = p_from.
  ls_policy-valid_to = p_to.
  ls_policy-changed_by = sy-uname.
  ls_policy-changed_on = sy-datum.

  IF p_new = 'X'.
    INSERT zexp_policy FROM ls_policy.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      lv_error = 'Policy could not be created; check its ID and table constraints'.
      PERFORM fail_locked USING lv_error.
    ENDIF.
  ELSE.
    UPDATE zexp_policy FROM ls_policy.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      lv_error = 'Policy could not be updated'.
      PERFORM fail_locked USING lv_error.
    ENDIF.
  ENDIF.

  COMMIT WORK AND WAIT.
  PERFORM unlock_policy_client.
  MESSAGE 'Policy saved' TYPE 'S'.
ENDFORM.

FORM validate_category_id.
  CASE p_cid.
    WHEN 'TRAVEL'.
      lv_category_name = 'Travel'.
    WHEN 'FOOD'.
      lv_category_name = 'Food'.
    WHEN 'ACCOM'.
      lv_category_name = 'Accommodation'.
    WHEN 'LOCAL'.
      lv_category_name = 'Local Transportation'.
    WHEN OTHERS.
      MESSAGE 'Use TRAVEL, FOOD, ACCOM, or LOCAL as category ID' TYPE 'E'.
  ENDCASE.
ENDFORM.

FORM lock_policy_client.
  CALL FUNCTION 'ENQUEUE_EZEXPPOL'
    EXPORTING
      mandt = sy-mandt
      _wait = 'X'
    EXCEPTIONS
      foreign_lock = 1
      system_failure = 2
      OTHERS = 3.
  IF sy-subrc <> 0.
    MESSAGE 'Policy data is locked or the policy lock failed' TYPE 'E'.
  ENDIF.
  lv_locked = 'X'.
ENDFORM.

FORM unlock_policy_client.
  IF lv_locked = 'X'.
    CALL FUNCTION 'DEQUEUE_EZEXPPOL'
      EXPORTING
        mandt = sy-mandt.
    lv_locked = space.
  ENDIF.
ENDFORM.

FORM fail_locked USING iv_message TYPE c.
  PERFORM unlock_policy_client.
  MESSAGE iv_message TYPE 'E'.
ENDFORM.
