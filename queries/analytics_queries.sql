-- ============================================
-- ANALYTICS QUERIES
-- Business Intelligence and reporting queries
-- ============================================

-- 1. KEY PERFORMANCE INDICATORS (KPIs)
-- -------------------------------------

-- KPI 1: Overall System Compliance Rate
SELECT 
    'System Compliance Rate' AS kpi_name,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS compliant_attempts,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS non_compliant_attempts,
    ROUND(SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS compliance_rate
FROM employee_audit_log;

-- KPI 2: Daily Restriction Effectiveness
SELECT 
    TRUNC(action_timestamp) AS date,
    TO_CHAR(action_timestamp, 'Day') AS day_name,
    COUNT(*) AS daily_attempts,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS prevented_actions,
    SUM(CASE WHEN is_holiday = 'Y' AND status = 'DENIED' THEN 1 ELSE 0 END) AS holiday_preventions,
    SUM(CASE WHEN is_weekday = 'Y' AND status = 'DENIED' THEN 1 ELSE 0 END) AS weekday_preventions
FROM employee_audit_log
GROUP BY TRUNC(action_timestamp), TO_CHAR(action_timestamp, 'Day')
ORDER BY date DESC;

-- KPI 3: Employee Compliance Ranking
SELECT 
    e.employee_id,
    e.employee_name,
    e.department,
    COUNT(eal.audit_id) AS total_actions,
    SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed_actions,
    SUM(CASE WHEN eal.status = 'DENIED' THEN 1 ELSE 0 END) AS denied_actions,
    CASE 
        WHEN COUNT(eal.audit_id) = 0 THEN 'No Activity'
        WHEN SUM(CASE WHEN eal.status = 'DENIED' THEN 1 ELSE 0 END) = 0 THEN 'Fully Compliant'
        WHEN SUM(CASE WHEN eal.status = 'DENIED' THEN 1 ELSE 0 END) <= 2 THEN 'Mostly Compliant'
        ELSE 'Needs Attention'
    END AS compliance_status,
    ROUND(SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(eal.audit_id), 0), 2) AS compliance_score
FROM employees e
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
GROUP BY e.employee_id, e.employee_name, e.department
ORDER BY compliance_score DESC NULLS LAST;

-- 2. TREND ANALYSIS
-- ------------------

-- 2.1 Weekly Activity Trends
SELECT 
    TRUNC(action_timestamp, 'IW') AS week_start,
    TO_CHAR(TRUNC(action_timestamp, 'IW'), 'YYYY-MM-DD') || ' to ' || 
    TO_CHAR(TRUNC(action_timestamp, 'IW') + 6, 'YYYY-MM-DD') AS week_range,
    day_of_week,
    COUNT(*) AS attempts,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS denials,
    ROUND(SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS denial_rate
FROM employee_audit_log
GROUP BY TRUNC(action_timestamp, 'IW'), day_of_week
ORDER BY week_start DESC, 
    CASE day_of_week 
        WHEN 'MON' THEN 1
        WHEN 'TUE' THEN 2
        WHEN 'WED' THEN 3
        WHEN 'THU' THEN 4
        WHEN 'FRI' THEN 5
        WHEN 'SAT' THEN 6
        WHEN 'SUN' THEN 7
    END;

-- 2.2 Hourly Activity Pattern
SELECT 
    EXTRACT(HOUR FROM action_timestamp) AS hour_of_day,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed,
    SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END) AS denied,
    ROUND(AVG(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) * 100, 2) AS success_rate
FROM employee_audit_log
GROUP BY EXTRACT(HOUR FROM action_timestamp)
ORDER BY hour_of_day;

-- 3. DEPARTMENTAL ANALYSIS
-- -------------------------

-- 3.1 Department Compliance Comparison
SELECT 
    e.department,
    COUNT(DISTINCT e.employee_id) AS employee_count,
    COUNT(eal.audit_id) AS total_attempts,
    SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) AS allowed,
    SUM(CASE WHEN eal.status = 'DENIED' THEN 1 ELSE 0 END) AS denied,
    ROUND(SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(eal.audit_id), 0), 2) AS compliance_rate,
    ROUND(COUNT(eal.audit_id) * 1.0 / COUNT(DISTINCT e.employee_id), 2) AS attempts_per_employee
FROM employees e
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
GROUP BY e.department
ORDER BY compliance_rate DESC;

-- 3.2 Department Restriction Analysis
SELECT 
    e.department,
    SUM(CASE WHEN e.restriction_applied = 'Y' THEN 1 ELSE 0 END) AS restricted_employees,
    SUM(CASE WHEN e.restriction_applied = 'N' THEN 1 ELSE 0 END) AS unrestricted_employees,
    SUM(CASE WHEN eal.status = 'DENIED' AND e.restriction_applied = 'Y' THEN 1 ELSE 0 END) AS restricted_denials,
    SUM(CASE WHEN eal.status = 'DENIED' AND e.restriction_applied = 'N' THEN 1 ELSE 0 END) AS unrestricted_denials
FROM employees e
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
GROUP BY e.department
ORDER BY restricted_denials DESC;

-- 4. ADVANCED WINDOW FUNCTIONS
-- -----------------------------

-- 4.1 Rolling 7-Day Compliance Rate
SELECT 
    date,
    total_attempts,
    compliant_attempts,
    compliance_rate,
    ROUND(AVG(compliance_rate) OVER (
        ORDER BY date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7day_avg
FROM (
    SELECT 
        TRUNC(action_timestamp) AS date,
        COUNT(*) AS total_attempts,
        SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) AS compliant_attempts,
        ROUND(SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
              NULLIF(COUNT(*), 0), 2) AS compliance_rate
    FROM employee_audit_log
    GROUP BY TRUNC(action_timestamp)
)
ORDER BY date DESC;

-- 4.2 Employee Ranking Within Department
SELECT 
    e.department,
    e.employee_id,
    e.employee_name,
    COUNT(eal.audit_id) AS total_actions,
    RANK() OVER (PARTITION BY e.department ORDER BY COUNT(eal.audit_id) DESC) AS activity_rank,
    ROUND(SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(eal.audit_id), 0), 2) AS compliance_rate,
    RANK() OVER (PARTITION BY e.department ORDER BY 
        ROUND(SUM(CASE WHEN eal.status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 / 
              NULLIF(COUNT(eal.audit_id), 0), 2) DESC) AS compliance_rank
FROM employees e
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
GROUP BY e.department, e.employee_id, e.employee_name
ORDER BY e.department, activity_rank;

-- 5. PREDICTIVE/ANALYTICAL QUERIES
-- ---------------------------------

-- 5.1 Holiday Impact Analysis
SELECT 
    h.holiday_name,
    TO_CHAR(h.holiday_date, 'YYYY-MM-DD') AS holiday_date,
    (SELECT COUNT(*) 
     FROM employee_audit_log 
     WHERE TRUNC(action_timestamp) = h.holiday_date) AS attempts_on_day,
    (SELECT COUNT(*) 
     FROM employee_audit_log 
     WHERE TRUNC(action_timestamp) = h.holiday_date - 1) AS attempts_day_before,
    (SELECT COUNT(*) 
     FROM employee_audit_log 
     WHERE TRUNC(action_timestamp) = h.holiday_date + 1) AS attempts_day_after,
    ROUND(((SELECT COUNT(*) FROM employee_audit_log WHERE TRUNC(action_timestamp) = h.holiday_date) * 100.0 /
           NULLIF((SELECT COUNT(*) FROM employee_audit_log WHERE TRUNC(action_timestamp) = h.holiday_date - 1), 0)), 2) 
    AS activity_change_percent
FROM holidays h
WHERE h.holiday_date >= ADD_MONTHS(SYSDATE, -3)
ORDER BY h.holiday_date DESC;

-- 5.2 Peak Activity Periods
WITH hourly_stats AS (
    SELECT 
        EXTRACT(HOUR FROM action_timestamp) AS hour,
        TO_CHAR(action_timestamp, 'DY') AS day,
        COUNT(*) AS attempts,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage_of_total
    FROM employee_audit_log
    GROUP BY EXTRACT(HOUR FROM action_timestamp), TO_CHAR(action_timestamp, 'DY')
)
SELECT 
    hour,
    day,
    attempts,
    percentage_of_total,
    RANK() OVER (ORDER BY attempts DESC) AS activity_rank
FROM hourly_stats
ORDER BY attempts DESC;
