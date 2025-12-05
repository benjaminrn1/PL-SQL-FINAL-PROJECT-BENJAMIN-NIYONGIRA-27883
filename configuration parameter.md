-- Show current settings
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
SHOW PARAMETER processes;
SHOW PARAMETER sessions;

-- Optimize memory for PL/SQL
ALTER SYSTEM SET PLSQL_CODE_TYPE = 'NATIVE' SCOPE=SPFILE;
ALTER SYSTEM SET PLSQL_OPTIMIZE_LEVEL = 2 SCOPE=BOTH;

-- ========== PERFORMANCE SETTINGS ==========
-- Set cursor sharing
ALTER SYSTEM SET CURSOR_SHARING = 'FORCE' SCOPE=SPFILE;


-- Set optimizer settings
ALTER SYSTEM SET OPTIMIZER_MODE = 'ALL_ROWS' SCOPE=BOTH;
ALTER SYSTEM SET QUERY_REWRITE_ENABLED = TRUE SCOPE=BOTH;

-- Set parallel execution
ALTER SYSTEM SET PARALLEL_MAX_SERVERS = 4 SCOPE=SPFILE;
ALTER SYSTEM SET PARALLEL_MIN_SERVERS = 2 SCOPE=SPFILE;


-- ========== SECURITY SETTINGS ==========
-- Password policies
ALTER PROFILE DEFAULT LIMIT
    PASSWORD_LIFE_TIME 90
    PASSWORD_GRACE_TIME 7
    PASSWORD_REUSE_TIME 365
    PASSWORD_REUSE_MAX 5
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LOCK_TIME 1;

-- Enable auditing
AUDIT ROLE BY ACCESS;
AUDIT SYSTEM GRANT BY ACCESS;
AUDIT PROFILE BY ACCESS;




-- ========== TABLESPACE MONITORING ==========
-- Enable tablespace monitoring
EXEC DBMS_SERVER_ALERT.SET_THRESHOLD(
    metrics_id => DBMS_SERVER_ALERT.TABLESPACE_PCT_FULL,
    warning_operator => DBMS_SERVER_ALERT.OPERATOR_GE,
    warning_value => '85',
    critical_operator => DBMS_SERVER_ALERT.OPERATOR_GE,
    critical_value => '97',
    observation_period => 1,
    consecutive_occurrences => 1,
    instance_name => NULL,
    object_type => DBMS_SERVER_ALERT.OBJECT_TYPE_TABLESPACE,
    object_name => 'SALES_DATA'
);



-- ========== CREATE PROFILE FOR APPLICATION ==========
CREATE PROFILE sales_app_profile LIMIT
    SESSIONS_PER_USER 10
    CPU_PER_SESSION UNLIMITED
    CPU_PER_CALL 300000
    CONNECT_TIME 480
    IDLE_TIME 30
    LOGICAL_READS_PER_SESSION DEFAULT
    LOGICAL_READS_PER_CALL 10000
    PRIVATE_SGA 256K
    COMPOSITE_LIMIT 5000000;
    
    
    -- Assign profile to app user
ALTER USER sales_app PROFILE sales_app_profile;

-- ========== CREATE ROLLBACK SEGMENTS ==========
-- Create rollback tablespace
CREATE TABLESPACE rbs_ts
DATAFILE 'rbs01.dbf'
SIZE 50M
AUTOEXTEND ON NEXT 25M MAXSIZE 200M
EXTENT MANAGEMENT LOCAL;


-- ========== ENABLE STATISTICS COLLECTION ==========
-- Enable automatic statistics collection
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('SALES_ADMIN', 
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
    cascade => TRUE,
    degree => DBMS_STATS.AUTO_DEGREE);



-- ========== CREATE SERVICE FOR DATABASE ==========
-- Create database service
BEGIN
    DBMS_SERVICE.CREATE_SERVICE(
        service_name => 'SALES_SERVICE',
        network_name => 'SALES_SERVICE',
        aq_ha_notifications => TRUE,
        failover_method => 'BASIC',
        failover_type => 'SELECT',
        failover_retries => 180,
        failover_delay => 5
    );
    
    DBMS_SERVICE.START_SERVICE('SALES_SERVICE');
END;
/
    
    


-- ========== VERIFY CONFIGURATION ==========
-- Display all parameters
SELECT name, value, isdefault
FROM v$parameter
WHERE name IN (
    'sga_target', 'pga_aggregate_target', 'processes',
    'sessions', 'db_block_size', 'compatible',
    'open_cursors', 'cursor_sharing'
)
ORDER BY name;   



-- Display tablespace usage
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024, 2) as total_mb,
       ROUND(SUM(maxbytes)/1024/1024, 2) as max_mb,
       ROUND((SUM(bytes) - SUM(free_bytes))/SUM(bytes)*100, 2) as pct_used
FROM (
    SELECT tablespace_name, bytes, maxbytes, 0 as free_bytes
    FROM dba_data_files
    UNION ALL
    SELECT tablespace_name, 0, 0, bytes
    FROM dba_free_space
)
GROUP BY tablespace_name
ORDER BY tablespace_name;

COMMIT;
