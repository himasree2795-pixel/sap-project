REPORT zexp_policy_maint.

PARAMETERS:
  p_cat RADIOBUTTON GROUP obj DEFAULT 'X',
  p_pol RADIOBUTTON GROUP obj,
  p_new RADIOBUTTON GROUP act DEFAULT 'X',
  p_upd RADIOBUTTON GROUP act,
  p_cid TYPE zexp_cat-category_id OBLIGATORY,
  p_cname TYPE zexp_cat-category_name LOWER CASE,
  p_cact TYPE zexp_cat-active DEFAULT 'X',
  p_from TYPE zexp_policy-valid_from,
  p_to TYPE zexp_policy-valid_to,
  p_max TYPE zexp_policy-max_amount,
  p_curr TYPE zexp_policy-currency,
  p_pact TYPE zexp_policy-active DEFAULT 'X'.

DATA: ls_cat TYPE zexp_cat,
      ls_cat_old TYPE zexp_cat,
      ls_policy TYPE zexp_policy,
      ls_policy_old TYPE zexp_policy,
      ls_policy_candidate TYPE zexp_policy,
      lt_policies TYPE STANDARD TABLE OF zexp_policy,
      lv_category TYPE zexp_cat-category_id,
      lv_currency TYPE waers,
      lv_activity TYPE c LENGTH 2.

IF p_new = 'X'.
  lv_activity = '01'.
ELSE.
  lv_activity = '02'.
ENDIF.
AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
  ID 'ACTVT' FIELD lv_activity
  ID 'ZEXP_ROLE' FIELD 'POLICY'.
IF sy-subrc <> 0.
  MESSAGE 'Not authorized to maintain expense policies' TYPE 'E'.
ENDIF.

IF p_cat = 'X'.
  IF p_cname IS INITIAL OR ( p_cact <> 'X' AND p_cact <> space ).
    MESSAGE 'Category name is required; active must be X or blank' TYPE 'E'.
  ENDIF.
  IF p_new = 'X'.
    SELECT SINGLE category_id INTO lv_category
      FROM zexp_cat
      WHERE category_id = p_cid.
    IF sy-subrc = 0.
      MESSAGE 'Category already exists; use update mode' TYPE 'E'.
    ENDIF.
    CLEAR ls_cat.
    ls_cat-mandt = sy-mandt.
    ls_cat-category_id = p_cid.
    ls_cat-category_name = p_cname.
    ls_cat-active = p_cact.
    INSERT zexp_cat FROM ls_cat.
    IF sy-subrc <> 0.
      MESSAGE 'Category could not be created' TYPE 'E'.
    ENDIF.
    COMMIT WORK AND WAIT.
    MESSAGE 'Category created' TYPE 'S'.
  ELSE.
    SELECT SINGLE * INTO ls_cat_old
      FROM zexp_cat
      WHERE category_id = p_cid.
    IF sy-subrc <> 0.
      MESSAGE 'Category does not exist' TYPE 'E'.
    ENDIF.
    ls_cat_old-category_name = p_cname.
    ls_cat_old-active = p_cact.
    UPDATE zexp_cat FROM ls_cat_old.
    IF sy-subrc <> 0.
      MESSAGE 'Category could not be updated' TYPE 'E'.
    ENDIF.
    COMMIT WORK AND WAIT.
    MESSAGE 'Category updated' TYPE 'S'.
  ENDIF.
ELSE.
  IF p_from IS INITIAL OR p_max <= 0 OR p_curr IS INITIAL.
    MESSAGE 'Start date, positive limit, and currency are required' TYPE 'E'.
  ENDIF.
  IF p_to IS NOT INITIAL AND p_to < p_from.
    MESSAGE 'Policy end date cannot precede its start date' TYPE 'E'.
  ENDIF.
  IF p_pact <> 'X' AND p_pact <> space.
    MESSAGE 'Policy active must be X or blank' TYPE 'E'.
  ENDIF.
  SELECT SINGLE waers INTO lv_currency
    FROM tcurc
    WHERE waers = p_curr.
  IF sy-subrc <> 0.
    MESSAGE 'Currency is not configured in SAP' TYPE 'E'.
  ENDIF.
  SELECT SINGLE category_id INTO lv_category
    FROM zexp_cat
    WHERE category_id = p_cid
      AND active = 'X'.
  IF sy-subrc <> 0.
    MESSAGE 'An active category is required for a policy' TYPE 'E'.
  ENDIF.

  SELECT SINGLE * INTO ls_policy_old
    FROM zexp_policy
    WHERE category_id = p_cid
      AND valid_from = p_from.
  IF p_new = 'X' AND sy-subrc = 0.
    MESSAGE 'Policy version already exists; use update mode' TYPE 'E'.
  ELSEIF p_upd = 'X' AND sy-subrc <> 0.
    MESSAGE 'Policy version does not exist' TYPE 'E'.
  ENDIF.

  IF p_pact = 'X'.
    SELECT * INTO TABLE lt_policies
      FROM zexp_policy
      WHERE category_id = p_cid
        AND active = 'X'
        AND valid_from <> p_from.
    LOOP AT lt_policies INTO ls_policy_candidate.
      IF ( p_to IS INITIAL OR ls_policy_candidate-valid_from <= p_to )
         AND ( ls_policy_candidate-valid_to IS INITIAL
               OR ls_policy_candidate-valid_to >= p_from ).
        MESSAGE 'Active policy date ranges for a category cannot overlap' TYPE 'E'.
      ENDIF.
    ENDLOOP.
  ENDIF.

  CLEAR ls_policy.
  ls_policy-mandt = sy-mandt.
  ls_policy-category_id = p_cid.
  ls_policy-valid_from = p_from.
  ls_policy-valid_to = p_to.
  ls_policy-max_amount = p_max.
  ls_policy-currency = p_curr.
  ls_policy-active = p_pact.
  ls_policy-changed_by = sy-uname.
  ls_policy-changed_on = sy-datum.
  IF p_new = 'X'.
    INSERT zexp_policy FROM ls_policy.
    IF sy-subrc <> 0.
      MESSAGE 'Policy could not be created' TYPE 'E'.
    ENDIF.
  ELSE.
    UPDATE zexp_policy FROM ls_policy.
    IF sy-subrc <> 0.
      MESSAGE 'Policy could not be updated' TYPE 'E'.
    ENDIF.
  ENDIF.
  COMMIT WORK AND WAIT.
  MESSAGE 'Policy saved' TYPE 'S'.
ENDIF.
