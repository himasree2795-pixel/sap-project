REPORT zexp_emp_maint.

PARAMETERS:
  p_new RADIOBUTTON GROUP act DEFAULT 'X',
  p_upd RADIOBUTTON GROUP act,
  p_emp TYPE zexp_emp-emp_id OBLIGATORY,
  p_name TYPE zexp_emp-emp_name LOWER CASE,
  p_dept TYPE zexp_emp-department LOWER CASE,
  p_desig TYPE zexp_emp-designation LOWER CASE,
  p_email TYPE zexp_emp-email LOWER CASE,
  p_user TYPE zexp_emp-sap_user,
  p_mgr TYPE zexp_emp-manager_id,
  p_active TYPE zexp_emp-active DEFAULT 'X'.

DATA: ls_emp TYPE zexp_emp,
      ls_existing TYPE zexp_emp,
      lv_manager TYPE zexp_emp-emp_id,
      lv_activity TYPE c LENGTH 2.

IF p_new = 'X'.
  lv_activity = '01'.
ELSE.
  lv_activity = '02'.
ENDIF.
AUTHORITY-CHECK OBJECT 'ZEXP_AUTH'
  ID 'ACTVT' FIELD lv_activity
  ID 'ZEXP_ROLE' FIELD 'ADMIN'.
IF sy-subrc <> 0.
  MESSAGE 'Not authorized to maintain employees' TYPE 'E'.
ENDIF.

IF p_active <> 'X' AND p_active <> space.
  MESSAGE 'Active must be X or blank' TYPE 'E'.
ENDIF.

IF p_name IS INITIAL OR p_dept IS INITIAL OR p_desig IS INITIAL
   OR p_email IS INITIAL OR p_user IS INITIAL.
  MESSAGE 'Name, department, designation, email, and SAP user are required' TYPE 'E'.
ENDIF.

IF p_mgr IS NOT INITIAL.
  IF p_mgr = p_emp.
    MESSAGE 'An employee cannot be their own reporting manager' TYPE 'E'.
  ENDIF.
  SELECT SINGLE emp_id INTO lv_manager
    FROM zexp_emp
    WHERE emp_id = p_mgr
      AND active = 'X'.
  IF sy-subrc <> 0.
    MESSAGE 'Reporting manager must be an existing active employee' TYPE 'E'.
  ENDIF.
ENDIF.

SELECT SINGLE emp_id INTO lv_manager
  FROM zexp_emp
  WHERE sap_user = p_user
    AND emp_id <> p_emp.
IF sy-subrc = 0.
  MESSAGE 'SAP user is already assigned to another employee' TYPE 'E'.
ENDIF.

IF p_new = 'X'.
  SELECT SINGLE emp_id INTO ls_existing-emp_id
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
  ls_emp-active = p_active.
  ls_emp-sap_user = p_user.
  ls_emp-manager_id = p_mgr.
  ls_emp-created_by = sy-uname.
  ls_emp-created_on = sy-datum.
  ls_emp-changed_by = sy-uname.
  ls_emp-changed_on = sy-datum.
  INSERT zexp_emp FROM ls_emp.
  IF sy-subrc <> 0.
    MESSAGE 'Employee could not be created' TYPE 'E'.
  ENDIF.
  COMMIT WORK AND WAIT.
  MESSAGE 'Employee created' TYPE 'S'.
ELSE.
  SELECT SINGLE * INTO ls_existing
    FROM zexp_emp
    WHERE emp_id = p_emp.
  IF sy-subrc <> 0.
    MESSAGE 'Employee does not exist' TYPE 'E'.
  ENDIF.

  ls_existing-emp_name = p_name.
  ls_existing-department = p_dept.
  ls_existing-designation = p_desig.
  ls_existing-email = p_email.
  ls_existing-active = p_active.
  ls_existing-sap_user = p_user.
  ls_existing-manager_id = p_mgr.
  ls_existing-changed_by = sy-uname.
  ls_existing-changed_on = sy-datum.
  UPDATE zexp_emp FROM ls_existing.
  IF sy-subrc <> 0.
    MESSAGE 'Employee could not be updated' TYPE 'E'.
  ENDIF.
  COMMIT WORK AND WAIT.
  MESSAGE 'Employee updated' TYPE 'S'.
ENDIF.
