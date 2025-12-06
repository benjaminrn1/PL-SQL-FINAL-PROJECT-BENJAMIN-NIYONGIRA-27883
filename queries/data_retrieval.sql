-- ============================================
-- DATA RETRIEVAL QUERIES
-- Basic to advanced data retrieval operations
-- ============================================

-- 1. BASIC DATA RETRIEVAL
-- -----------------------
-- 1.1 Retrieve all employees with their department info
SELECT 
    e.employee_id,
    e.employee_name,
    e.department,
    e.position,
    e.email,
    e.restriction_applied,
    TO_CHAR(e.hire_date, 'YYYY-MM-DD') AS hire_date
FROM employees e
ORDER BY e.department, e.employee_name;

-- 1.2 Get all test employee actions with employee details
SELECT 
    tea.action_id,
    tea.employee_id,
    e.employee_name,
    tea.action_type,
    tea.description,
    tea.amount,
    tea.status,
    TO_CHAR(tea.action_date, 'YYYY-MM-DD HH24:MI:SS') AS action_date
FROM test_employee_actions tea
JOIN employees e ON tea.employee_id = e.employee_id
ORDER BY tea.action_date DESC;

-- 1.3 Retrieve upcoming holidays
SELECT 
    holiday_id,
    holiday_name,
    TO_CHAR(holiday_date, 'YYYY-MM-DD Day') AS holiday_date,
    description,
    is_returning,
    TO_CHAR(created_date, 'YYYY-MM-DD') AS created_date
FROM holidays
WHERE holiday_date >= TRUNC(SYSDATE)
ORDER BY holiday_date;

-- 1.4 Get employee count by department
SELECT 
    department,
    COUNT(*) AS employee_count,
    SUM(CASE WHEN restriction_applied = 'Y' THEN 1 ELSE 0 END) AS restricted_count,
    SUM(CASE WHEN restriction_applied = 'N' THEN 1 ELSE 0 END) AS unrestricted_count
FROM employees
GROUP BY department
ORDER BY employee_count DESC;

-- 2. ADVANCED QUERIES WITH JOINS
-- --------------------------------
-- 2.1 Employee actions with audit trail
SELECT 
    e.employee_id,
    e.employee_name,
    tea.action_id,
    tea.action_type AS table_action,
    tea.amount,
    tea.status AS action_status,
    eal.action_type AS audit_action,
    eal.status AS audit_status,
    TO_CHAR(eal.action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS audit_time
FROM employees e
LEFT JOIN test_employee_actions tea ON e.employee_id = tea.employee_id
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
    AND tea.action_id = eal.record_id
ORDER BY eal.action_timestamp DESC NULLS LAST;

-- 2.2 Daily audit summary
SELECT 
    TRUNC(action_timestamp) AS audit_date,
    action_type,
    status,
    COUNT(*) AS attempt_count,
    SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed_count,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS denied_count,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS error_count
FROM employee_audit_log
GROUP BY TRUNC(action_timestamp), action_type, status
ORDER BY audit_date DESC, action_type;

-- 3. COMPLEX FILTERING
-- ---------------------
-- 3.1 Find denied actions with details
SELECT 
    eal.audit_id,
    eal.employee_id,
    e.employee_name,
    eal.action_type,
    eal.table_name,
    eal.record_id,
    eal.day_of_week,
    eal.is_holiday,
    eal.is_weekday,
    eal.error_message,
    TO_CHAR(eal.action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS denied_time
FROM employee_audit_log eal
LEFT JOIN employees e ON eal.employee_id = e.employee_id
WHERE eal.status = 'DENIED'
ORDER BY eal.action_timestamp DESC;

-- 3.2 Find actions attempted on holidays
SELECT 
    eal.*,
    h.holiday_name,
    e.employee_name
FROM employee_audit_log eal
LEFT JOIN holidays h ON TRUNC(eal.action_timestamp) = h.holiday_date
LEFT JOIN employees e ON eal.employee_id = e.employee_id
WHERE eal.is_holiday = 'Y'
ORDER BY eal.action_timestamp DESC;

-- 4. AGGREGATION QUERIES
-- -----------------------
-- 4.1 Monthly audit statistics
SELECT 
    TO_CHAR(action_timestamp, 'YYYY-MM') AS month,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS denied,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS errors,
    ROUND(AVG(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) * 100, 2) AS success_rate
FROM employee_audit_log
GROUP BY TO_CHAR(action_timestamp, 'YYYY-MM')
ORDER BY month DESC;

-- 4.2 Employee activity summary
SELECT 
    e.employee_id,
    e.employee_name,
    e.department,
    COUNT(eal.audit_id) AS total_actions,
    SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed_actions,
    SUM(CASE WHEN eal.status = 'DENIED' THEN 1 ELSE 0 END) AS denied_actions,
    ROUND(SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(eal.audit_id), 0), 2) AS success_percentage
FROM employees e
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
GROUP BY e.employee_id, e.employee_name, e.department
ORDER BY total_actions DESC;

-- 5. SUBQUERY EXAMPLES
-- ---------------------
-- 5.1 Employees with most denied attempts
SELECT 
    employee_id,
    employee_name,
    department,
    (SELECT COUNT(*) 
     FROM employee_audit_log eal 
     WHERE eal.employee_id = e.employee_id 
     AND eal.status = 'DENIED') AS denied_count,
    (SELECT COUNT(*) 
     FROM employee_audit_log eal 
     WHERE eal.employee_id = e.employee_id) AS total_attempts
FROM employees e
WHERE (SELECT COUNT(*) 
       FROM employee_audit_log eal 
       WHERE eal.employee_id = e.employee_id 
       AND eal.status = 'DENIED') > 0
ORDER BY denied_count DESC;

-- 5.2 Current month's holiday activity
SELECT 
    h.holiday_date,
    h.holiday_name,
    (SELECT COUNT(*) 
     FROM employee_audit_log eal 
     WHERE TRUNC(eal.action_timestamp) = h.holiday_date
     AND eal.is_holiday = 'Y') AS attempts_on_holiday,
    (SELECT COUNT(*) 
     FROM employee_audit_log eal 
     WHERE TRUNC(eal.action_timestamp) = h.holiday_date
     AND eal.status = 'DENIED') AS denied_on_holiday
FROM holidays h
WHERE EXTRACT(MONTH FROM h.holiday_date) = EXTRACT(MONTH FROM SYSDATE)
ORDER BY h.holiday_date;
