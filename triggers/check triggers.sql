-- Check if functions exist and are valid
SELECT 
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM user_objects
WHERE object_type IN ('FUNCTION', 'TRIGGER')
  AND object_name LIKE '%AUDIT%' 
   OR object_name LIKE '%RESTRICTION%'
   OR object_name LIKE '%CHECK%'
ORDER BY object_type, object_name;

-- Check triggers specifically
SELECT 
    trigger_name,
    trigger_type,
    triggering_event,
    table_name,
    status,
    description
FROM user_triggers
WHERE table_name = 'ORDERS'
ORDER BY trigger_name;

-- Test the functions
SELECT 'LOG_AUDIT_ENTRY Test: ' || 
       log_audit_entry('TEST_TABLE', 'TEST_OP', USER, 'old', 'new', 'Y', 'test') 
FROM dual;

SELECT 'GET_OLD_VALUES_STR Test: ' || 
       get_old_values_str(999, 888, 'TEST_STATUS', 1234.56) 
FROM dual;

-- Test check_employee_restriction function
SELECT check_employee_restriction(1, 'INSERT') FROM dual;

-- Test check_if_weekday
BEGIN
    IF check_if_weekday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('Today is a WEEKDAY');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Today is a WEEKEND');
    END IF;
END;
/

-- Test check_if_holiday
BEGIN
    IF check_if_holiday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('Today is a HOLIDAY');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Today is NOT a holiday');
    END IF;
END;
/
