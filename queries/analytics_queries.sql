-- ============================================
-- WINDOW FUNCTION ENHANCEMENTS FOR DATA RETRIEVAL
-- ============================================

-- 1. ROW_NUMBER() - Number each employee's actions chronologically
SELECT 
    e.employee_id,
    e.employee_name,
    tea.action_id,
    tea.action_date,
    tea.action_type,
    ROW_NUMBER() OVER (
        PARTITION BY e.employee_id 
        ORDER BY tea.action_date DESC
    ) AS action_sequence,
    LAG(tea.action_type) OVER (
        PARTITION BY e.employee_id 
        ORDER BY tea.action_date
    ) AS previous_action,
    LEAD(tea.action_type) OVER (
        PARTITION BY e.employee_id 
        ORDER BY tea.action_date
    ) AS next_action
FROM employees e
JOIN test_employee_actions tea ON e.employee_id = tea.employee_id
ORDER BY e.employee_id, tea.action_date DESC;

-- 2. RANK() - Rank employees by activity within department
SELECT 
    department,
    employee_id,
    employee_name,
    COUNT(eal.audit_id) AS total_actions,
    RANK() OVER (
        PARTITION BY department 
        ORDER BY COUNT(eal.audit_id) DESC
    ) AS activity_rank_dept,
    DENSE_RANK() OVER (
        ORDER BY COUNT(eal.audit_id) DESC
    ) AS activity_rank_overall,
    ROUND(
        COUNT(eal.audit_id) * 100.0 / 
        SUM(COUNT(eal.audit_id)) OVER (PARTITION BY department),
        2
    ) AS percentage_of_dept_activity
FROM employees e
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
GROUP BY department, employee_id, employee_name
ORDER BY department, activity_rank_dept;

-- 3. LAG/LEAD - Compare current vs previous day activity
SELECT 
    TRUNC(action_timestamp) AS audit_date,
    COUNT(*) AS daily_attempts,
    LAG(COUNT(*)) OVER (ORDER BY TRUNC(action_timestamp)) AS previous_day_attempts,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY TRUNC(action_timestamp)) AS day_over_day_change,
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY TRUNC(action_timestamp))) * 100.0 /
        NULLIF(LAG(COUNT(*)) OVER (ORDER BY TRUNC(action_timestamp)), 0),
        2
    ) AS percentage_change,
    AVG(COUNT(*)) OVER (
        ORDER BY TRUNC(action_timestamp) 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS seven_day_moving_avg
FROM employee_audit_log
GROUP BY TRUNC(action_timestamp)
ORDER BY audit_date DESC;

-- 4. NTILE() - Divide employees into activity quartiles
SELECT 
    employee_id,
    employee_name,
    department,
    action_count,
    NTILE(4) OVER (ORDER BY action_count DESC) AS activity_quartile,
    CASE NTILE(4) OVER (ORDER BY action_count DESC)
        WHEN 1 THEN 'High Activity'
        WHEN 2 THEN 'Medium-High Activity'
        WHEN 3 THEN 'Medium-Low Activity'
        WHEN 4 THEN 'Low Activity'
    END AS activity_category
FROM (
    SELECT 
        e.employee_id,
        e.employee_name,
        e.department,
        COUNT(eal.audit_id) AS action_count
    FROM employees e
    LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
    GROUP BY e.employee_id, e.employee_name, e.department
);

-- 5. FIRST_VALUE/LAST_VALUE - First and last audit for each employee
SELECT 
    e.employee_id,
    e.employee_name,
    FIRST_VALUE(eal.action_timestamp) OVER (
        PARTITION BY e.employee_id 
        ORDER BY eal.action_timestamp
    ) AS first_audit_time,
    LAST_VALUE(eal.action_timestamp) OVER (
        PARTITION BY e.employee_id 
        ORDER BY eal.action_timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_audit_time,
    FIRST_VALUE(eal.status) OVER (
        PARTITION BY e.employee_id 
        ORDER BY eal.action_timestamp
    ) AS first_audit_status,
    LAST_VALUE(eal.status) OVER (
        PARTITION BY e.employee_id 
        ORDER BY eal.action_timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_audit_status
FROM employees e
LEFT JOIN employee_audit_log eal ON e.employee_id = eal.employee_id
ORDER BY e.employee_id, eal.action_timestamp;
