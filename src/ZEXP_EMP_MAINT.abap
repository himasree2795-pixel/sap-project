REPORT zexp_emp_maint.

PARAMETERS:
  p_new RADIOBUTTON GROUP act DEFAULT 'X',
  p_disp RADIOBUTTON GROUP act,
  p_upd RADIOBUTTON GROUP act,
  p_stat RADIOBUTTON GROUP act.

PARAMETERS:
  p_emp TYPE zexp_emp-emp_id,
  p_name TYPE zexp_emp-emp_name LOWER CASE,
  p_dept TYPE zexp_emp-department LOWER CASE,
  p_desig TYPE zexp_emp-designation LOWER CASE,
  p_email TYPE zexp_emp-email LOWER CASE,
  p_user TYPE zexp_emp-sap_user,
  p_mgr TYPE zexp_emp-manager_id,
  p_act AS CHECKBOX DEFAULT 'X'.

DATA: ls_emp TYPE zexp_emp,
      ls_manager TYPE zexp_emp,
      lt_employees TYPE STANDARD TABLE OF zexp_emp,
      lv_activity TYPE c LENGTH 2,
      lv_role TYPE c LENGTH 10,
      lv_email TYPE zexp_emp-email,
      lo_alv TYPE REF TO cl_salv_table.

START-OF-SELECTION.
  PERFORM check_authority.

  IF p_new = 'X'.
    PERFORM create_employee.
  ELSEIF p_disp = 'X'.
    PERFORM display_employees.
  ELSEIF p_upd = 'X'.
    PERFORM update_employee.
  ELSE.
    PERFORM change_status.
  ENDIF.

FORM check_authority.
  IF p_new = 'X'.
    lv_activity = '01'.
    lv_role = 'ADMIN'.
  ELSEIF p_disp = 'X'.
    lv_activity = '03'.
    lv_role = 'REPORT'.
  ELSE.
    lv_activity = '02'.
    lv_role = 'ADMIN'.
  ENDIF.

  AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
    ID 'ACTVT' FIELD lv_activity
    ID 'ZEXP_ROLE' FIELD lv_role.
  IF sy-subrc <> 0.
    MESSAGE 'Not authorized for this employee operation' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM validate_employee_data.
  IF p_emp IS INITIAL OR p_name IS INITIAL OR p_dept IS INITIAL
     OR p_desig IS INITIAL OR p_email IS INITIAL OR p_user IS INITIAL.
    MESSAGE 'ID, name, department, designation, email, and SAP user are required' TYPE 'E'.
  ENDIF.

  lv_email = p_email.
  PERFORM validate_email USING lv_email.

  IF p_mgr IS NOT INITIAL.
    IF p_mgr = p_emp.
      MESSAGE 'An employee cannot be their own reporting manager' TYPE 'E'.
    ENDIF.

    SELECT SINGLE * INTO ls_manager
      FROM zexp_emp
      WHERE emp_id = p_mgr
        AND active = 'X'.
    IF sy-subrc <> 0.
      MESSAGE 'Reporting manager must be an existing active employee' TYPE 'E'.
    ENDIF.
  ENDIF.

  CLEAR ls_manager.
  SELECT SINGLE * INTO ls_manager
    FROM zexp_emp
    WHERE sap_user = p_user
      AND emp_id <> p_emp.
  IF sy-subrc = 0.
    MESSAGE 'SAP user is already assigned to another employee' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM validate_email USING iv_email TYPE zexp_emp-email.
  FIND REGEX '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    IN iv_email.
  IF sy-subrc <> 0.
    MESSAGE 'Enter an email address in a basic user@domain.example format' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM create_employee.
  PERFORM validate_employee_data.

  SELECT SINGLE emp_id INTO ls_emp-emp_id
    FROM zexp_emp
    WHERE emp_id = p_emp.
  IF sy-subrc = 0.
    MESSAGE 'Employee ID already exists; use update mode' TYPE 'E'.
  ENDIF.

  CLEAR ls_emp.
  ls_emp-mandt = sy-mandt.
  ls_emp-emp_id = p_emp.
  ls_emp-emp_name = p_name.
  ls_emp-department = p_dept.
  ls_emp-designation = p_desig.
  ls_emp-email = p_email.
  ls_emp-active = 'X'.
  ls_emp-sap_user = p_user.
  ls_emp-manager_id = p_mgr.
  ls_emp-created_by = sy-uname.
  ls_emp-created_on = sy-datum.
  ls_emp-changed_by = sy-uname.
  ls_emp-changed_on = sy-datum.

  INSERT zexp_emp FROM ls_emp.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    MESSAGE 'Create failed; check employee ID and unique SAP-user constraint' TYPE 'E'.
  ENDIF.
  COMMIT WORK AND WAIT.
  MESSAGE 'Employee created as active' TYPE 'S'.
ENDFORM.

FORM display_employees.
  IF p_emp IS INITIAL.
    SELECT * INTO TABLE lt_employees
      FROM zexp_emp
      ORDER BY emp_id.
  ELSE.
    SELECT * INTO TABLE lt_employees
      FROM zexp_emp
      WHERE emp_id = p_emp
      ORDER BY emp_id.
  ENDIF.

  IF lt_employees IS INITIAL.
    MESSAGE 'No employee records found for the selection' TYPE 'S'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_employees ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Employee list could not be displayed in ALV' TYPE 'E'.
  ENDTRY.
ENDFORM.

FORM update_employee.
  PERFORM validate_employee_data.

  SELECT SINGLE * INTO ls_emp
    FROM zexp_emp
    WHERE emp_id = p_emp.
  IF sy-subrc <> 0.
    MESSAGE 'Employee does not exist; use create mode' TYPE 'E'.
  ENDIF.

  ls_emp-emp_name = p_name.
  ls_emp-department = p_dept.
  ls_emp-designation = p_desig.
  ls_emp-email = p_email.
  ls_emp-sap_user = p_user.
  ls_emp-manager_id = p_mgr.
  ls_emp-changed_by = sy-uname.
  ls_emp-changed_on = sy-datum.

  UPDATE zexp_emp FROM ls_emp.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    MESSAGE 'Employee could not be updated' TYPE 'E'.
  ENDIF.
  COMMIT WORK AND WAIT.
  MESSAGE 'Employee details updated; active status was left unchanged' TYPE 'S'.
ENDFORM.

FORM change_status.
  IF p_emp IS INITIAL.
    MESSAGE 'Employee ID is required for a status change' TYPE 'E'.
  ENDIF.

  SELECT SINGLE * INTO ls_emp
    FROM zexp_emp
    WHERE emp_id = p_emp.
  IF sy-subrc <> 0.
    MESSAGE 'Employee does not exist' TYPE 'E'.
  ENDIF.

  IF p_act = 'X'.
    ls_emp-active = 'X'.
  ELSE.
    ls_emp-active = space.
  ENDIF.
  ls_emp-changed_by = sy-uname.
  ls_emp-changed_on = sy-datum.

  UPDATE zexp_emp FROM ls_emp.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    MESSAGE 'Employee status could not be changed' TYPE 'E'.
  ENDIF.
  COMMIT WORK AND WAIT.

  IF p_act = 'X'.
    MESSAGE 'Employee activated' TYPE 'S'.
  ELSE.
    MESSAGE 'Employee deactivated; the record was retained' TYPE 'S'.
  ENDIF.
ENDFORM.
