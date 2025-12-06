-- ============================================
-- WINDOW FUNCTIONS FOR AUDIT MONITORING
-- ============================================

-- 1. Sequential Pattern Detection (for suspicious activity)
SELECT 
    employee_id,
    action_timestamp,
    action_type,
    table_name,
    status,
    LAG(action_type, 1) OVER (
        PARTITION BY employee_id 
        ORDER BY action_timestamp
    ) AS prev_action_1,
    LAG(action_type, 2) OVER (
        PARTITION BY employee_id 
        ORDER BY action_timestamp
    ) AS prev_action_2,
    LEAD(action_type, 1) OVER (
        PARTITION BY employee_id 
        ORDER BY action_timestamp
    ) AS next_action_1,
    CASE 
        WHEN action_type = 'DELETE' 
             AND LAG(action_type, 1) OVER (PARTITION BY employee_id ORDER BY action_timestamp) = 'UPDATE'
             AND LAG(action_type, 2) OVER (PARTITION BY employee_id ORDER BY action_timestamp) = 'INSERT'
        THEN 'SUSPICIOUS_PATTERN'
        WHEN COUNT(*) OVER (
            PARTITION BY employee_id 
            ORDER BY action_timestamp 
            RANGE BETWEEN INTERVAL '5' MINUTE PRECEDING AND CURRENT ROW
        ) > 10
        THEN 'HIGH_FREQUENCY'
        ELSE 'NORMAL'
    END AS activity_pattern
FROM employee_audit_log
ORDER BY employee_id, action_timestamp DESC;

-- 2. Audit Volume Alerts (detect spikes)
SELECT 
    audit_hour,
    audit_count,
    LAG(audit_count, 1) OVER (ORDER BY audit_hour) AS previous_hour_count,
    ROUND(
        (audit_count - LAG(audit_count, 1) OVER (ORDER BY audit_hour)) * 100.0 /
        NULLIF(LAG(audit_count, 1) OVER (ORDER BY audit_hour), 0),
        2
    ) AS hour_over_hour_change_percent,
    AVG(audit_count) OVER (
        ORDER BY audit_hour 
        ROWS BETWEEN 23 PRECEDING AND CURRENT ROW
    ) AS twentyfour_hour_moving_avg,
    CASE 
        WHEN audit_count > 2 * AVG(audit_count) OVER (
            ORDER BY audit_hour 
            ROWS BETWEEN 23 PRECEDING AND CURRENT ROW
        )
        THEN 'VOLUME_SPIKE_ALERT'
        ELSE 'NORMAL'
    END AS volume_alert
FROM (
    SELECT 
        TRUNC(action_timestamp, 'HH24') AS audit_hour,
        COUNT(*) AS audit_count
    FROM employee_audit_log
    WHERE action_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
    GROUP BY TRUNC(action_timestamp, 'HH24')
)
ORDER BY audit_hour DESC;

-- 3. Compliance Trend by Employee (for performance reviews)
SELECT 
    employee_id,
    audit_week,
    compliance_rate,
    ROUND(
        AVG(compliance_rate) OVER (
            PARTITION BY employee_id 
            ORDER BY audit_week 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS four_week_moving_avg,
    ROUND(
        compliance_rate - AVG(compliance_rate) OVER (
            PARTITION BY employee_id 
            ORDER BY audit_week 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS deviation_from_trend,
    CASE 
        WHEN compliance_rate < 0.8 * AVG(compliance_rate) OVER (
            PARTITION BY employee_id 
            ORDER BY audit_week 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        )
        THEN 'PERFORMANCE_DECLINE'
        WHEN compliance_rate > 1.2 * AVG(compliance_rate) OVER (
            PARTITION BY employee_id 
            ORDER BY audit_week 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        )
        THEN 'PERFORMANCE_IMPROVEMENT'
        ELSE 'STABLE'
    END AS performance_trend
FROM (
    SELECT 
        employee_id,
        TRUNC(action_timestamp, 'IW') AS audit_week,
        ROUND(
            SUM(CASE WHEN status = 'ALLOWED' THEN 1 ELSE 0 END) * 100.0 /
            NULLIF(COUNT(*), 0),
            2
        ) AS compliance_rate
    FROM employee_audit_log
    WHERE employee_id IS NOT NULL
    GROUP BY employee_id, TRUNC(action_timestamp, 'IW')
)
ORDER BY employee_id, audit_week DESC;

-- 4. Session Analysis with Window Functions
SELECT 
    session_user,
    audit_date,
    session_start,
    session_end,
    session_duration_minutes,
    actions_per_session,
    ROW_NUMBER() OVER (
        PARTITION BY session_user 
        ORDER BY session_duration_minutes DESC
    ) AS session_length_rank,
    RANK() OVER (
        PARTITION BY audit_date 
        ORDER BY actions_per_session DESC
    ) AS daily_activity_rank,
    AVG(session_duration_minutes) OVER (
        PARTITION BY session_user
    ) AS avg_session_length,
    AVG(actions_per_session) OVER (
        PARTITION BY session_user
    ) AS avg_actions_per_session
FROM (
    SELECT 
        session_user,
        TRUNC(MIN(action_timestamp)) AS audit_date,
        MIN(action_timestamp) AS session_start,
        MAX(action_timestamp) AS session_end,
        ROUND(
            EXTRACT(MINUTE FROM (MAX(action_timestamp) - MIN(action_timestamp))) +
            EXTRACT(HOUR FROM (MAX(action_timestamp) - MIN(action_timestamp))) * 60,
            2
        ) AS session_duration_minutes,
        COUNT(*) AS actions_per_session
    FROM employee_audit_log
    GROUP BY session_user, 
             TRUNC(action_timestamp),
             FLOOR(EXTRACT(HOUR FROM action_timestamp) / 4) -- 4-hour session windows
)
ORDER BY session_user, session_start DESC;
