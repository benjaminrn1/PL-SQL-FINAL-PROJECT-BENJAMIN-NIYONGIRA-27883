-- ============================================
-- AUDIT QUERIES
-- Monitoring, compliance and security audits
-- ============================================

-- 1. AUDIT TRAIL REVIEW
-- ----------------------

-- 1.1 Complete Audit Trail
SELECT 
    audit_id,
    employee_id,
    action_type,
    table_name,
    record_id,
    day_of_week,
    is_holiday,
    is_weekday,
    status,
    error_message,
    session_user,
    TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS timestamp,
    ip_address
FROM employee_audit_log
ORDER BY audit_id DESC;

-- 1.2 Recent Audit Entries (Last 24 hours)
SELECT 
    audit_id,
    employee_id,
    action_type,
    table_name,
    status,
    error_message,
    TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS timestamp,
    session_user
FROM employee_audit_log
WHERE action_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
ORDER BY action_timestamp DESC;

-- 2. COMPLIANCE VIOLATIONS
-- -------------------------

-- 2.1 All Rule Violations
SELECT 
    audit_id,
    employee_id,
    (SELECT employee_name FROM employees e WHERE e.employee_id = eal.employee_id) AS employee_name,
    action_type,
    table_name,
    record_id,
    day_of_week,
    is_holiday,
    is_weekday,
    status,
    error_message,
    TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS violation_time,
    session_user
FROM employee_audit_log eal
WHERE status = 'DENIED'
ORDER BY action_timestamp DESC;

-- 2.2 Holiday Violations Specifically
SELECT 
    audit_id,
    employee_id,
    (SELECT employee_name FROM employees e WHERE e.employee_id = eal.employee_id) AS employee_name,
    action_type,
    table_name,
    h.holiday_name,
    TO_CHAR(h.holiday_date, 'YYYY-MM-DD') AS holiday_date,
    error_message,
    TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS violation_time
FROM employee_audit_log eal
JOIN holidays h ON TRUNC(eal.action_timestamp) = h.holiday_date
WHERE eal.status = 'DENIED'
AND eal.is_holiday = 'Y'
ORDER BY action_timestamp DESC;

-- 2.3 Weekday Violations
SELECT 
    audit_id,
    employee_id,
    (SELECT employee_name FROM employees e WHERE e.employee_id = eal.employee_id) AS employee_name,
    action_type,
    table_name,
    record_id,
    day_of_week,
    error_message,
    TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS violation_time,
    session_user
FROM employee_audit_log eal
WHERE status = 'DENIED'
AND is_weekday = 'Y'
AND is_holiday = 'N'
ORDER BY action_timestamp DESC;

-- 3. USER ACTIVITY AUDITS
-- ------------------------

-- 3.1 User Session Activity
SELECT 
    session_user,
    COUNT(*) AS total_actions,
    MIN(action_timestamp) AS first_action,
    MAX(action_timestamp) AS last_action,
    SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed_actions,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS denied_actions,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS error_actions,
    ROUND((MAX(action_timestamp) - MIN(action_timestamp)) * 24 * 60, 2) AS session_duration_minutes
FROM employee_audit_log
GROUP BY session_user
ORDER BY total_actions DESC;

-- 3.2 Employee-Specific Audit Trail
SELECT 
    audit_id,
    eal.action_type,
    eal.table_name,
    eal.record_id,
    eal.day_of_week,
    eal.status,
    eal.error_message,
    TO_CHAR(eal.action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS timestamp,
    eal.session_user,
    eal.ip_address
FROM employee_audit_log eal
WHERE eal.employee_id = &ENTER_EMPLOYEE_ID
ORDER BY eal.action_timestamp DESC;

-- 4. SECURITY AUDITS
-- -------------------

-- 4.1 Unusual Activity Detection
SELECT 
    employee_id,
    COUNT(*) AS actions_last_hour,
    TO_CHAR(MAX(action_timestamp), 'YYYY-MM-DD HH24:MI:SS') AS last_action,
    LISTAGG(action_type, ', ') WITHIN GROUP (ORDER BY action_timestamp) AS action_sequence
FROM employee_audit_log
WHERE action_timestamp >= SYSTIMESTAMP - INTERVAL '1' HOUR
GROUP BY employee_id
HAVING COUNT(*) > 5  -- More than 5 actions per hour is unusual
ORDER BY actions_last_hour DESC;

-- 4.2 Failed Authentication/Authorization Attempts
SELECT 
    audit_id,
    employee_id,
    action_type,
    table_name,
    status,
    error_message,
    session_user,
    ip_address,
    TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS attempt_time
FROM employee_audit_log
WHERE status IN ('DENIED', 'ERROR')
AND error_message LIKE '%not authorized%' 
   OR error_message LIKE '%permission%'
   OR error_message LIKE '%access denied%'
ORDER BY action_timestamp DESC;

-- 5. AUDIT SUMMARY REPORTS
-- -------------------------

-- 5.1 Daily Audit Summary
SELECT 
    TRUNC(action_timestamp) AS audit_date,
    TO_CHAR(TRUNC(action_timestamp), 'Day') AS day_name,
    COUNT(*) AS total_entries,
    SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS denied,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS errors,
    COUNT(DISTINCT employee_id) AS unique_employees,
    COUNT(DISTINCT session_user) AS unique_users,
    ROUND(SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS denial_rate
FROM employee_audit_log
GROUP BY TRUNC(action_timestamp), TO_CHAR(TRUNC(action_timestamp), 'Day')
ORDER BY audit_date DESC;

-- 5.2 Monthly Compliance Report
SELECT 
    TO_CHAR(action_timestamp, 'YYYY-MM') AS month,
    COUNT(*) AS total_audits,
    SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS compliant,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS non_compliant,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS system_errors,
    ROUND(SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS compliance_percentage,
    COUNT(DISTINCT employee_id) AS employees_monitored,
    COUNT(DISTINCT table_name) AS tables_monitored
FROM employee_audit_log
GROUP BY TO_CHAR(action_timestamp, 'YYYY-MM')
ORDER BY month DESC;

-- 6. DATA INTEGRITY CHECKS
-- -------------------------

-- 6.1 Orphaned Audit Records (no matching employee)
SELECT 
    eal.audit_id,
    eal.employee_id,
    eal.action_type,
    eal.table_name,
    eal.status,
    TO_CHAR(eal.action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS timestamp
FROM employee_audit_log eal
LEFT JOIN employees e ON eal.employee_id = e.employee_id
WHERE e.employee_id IS NULL
ORDER BY eal.action_timestamp DESC;

-- 6.2 Missing/Audit Gaps Detection
WITH date_series AS (
    SELECT TRUNC(MIN(action_timestamp)) + LEVEL - 1 AS audit_date
    FROM employee_audit_log
    CONNECT BY TRUNC(MIN(action_timestamp)) + LEVEL - 1 <= TRUNC(SYSDATE)
)
SELECT 
    ds.audit_date,
    TO_CHAR(ds.audit_date, 'Day') AS day_name,
    COUNT(eal.audit_id) AS audit_count
FROM date_series ds
LEFT JOIN employee_audit_log eal ON TRUNC(eal.action_timestamp) = ds.audit_date
GROUP BY ds.audit_date
HAVING COUNT(eal.audit_id) = 0
ORDER BY ds.audit_date DESC;

-- 7. AUDIT ARCHIVING QUERIES
-- ---------------------------

-- 7.1 Records Ready for Archiving (older than 90 days)
SELECT 
    COUNT(*) AS records_to_archive,
    MIN(action_timestamp) AS oldest_record,
    MAX(action_timestamp) AS newest_record,
    TO_CHAR(MIN(action_timestamp), 'YYYY-MM-DD') AS archive_from_date
FROM employee_audit_log
WHERE action_timestamp < SYSTIMESTAMP - INTERVAL '90' DAY;

-- 7.2 Archive Preparation Query
SELECT 
    audit_id,
    employee_id,
    action_type,
    table_name,
    record_id,
    status,
    error_message,
    session_user,
    TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS original_timestamp
FROM employee_audit_log
WHERE action_timestamp < SYSTIMESTAMP - INTERVAL '90' DAY
ORDER BY audit_id;

-- 8. AUDIT CONFIGURATION CHECK
-- -----------------------------

-- 8.1 Check Trigger Status
SELECT 
    trigger_name,
    table_name,
    status,
    TO_CHAR(created, 'YYYY-MM-DD') AS created_date
FROM user_triggers
WHERE table_name IN ('TEST_EMPLOYEE_ACTIONS', 'EMPLOYEES')
ORDER BY table_name, trigger_name;

-- 8.2 Audit Table Structure Verification
SELECT 
    column_name,
    data_type,
    data_length,
    nullable,
    column_id
FROM user_tab_columns
WHERE table_name = 'EMPLOYEE_AUDIT_LOG'
ORDER BY column_id;
