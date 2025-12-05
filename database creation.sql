connect / as sysdba
-- Main data tablespace
CREATE TABLESPACE sales_data
DATAFILE 'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/sales_data01.dbf'
SIZE 500M
AUTOEXTEND ON NEXT 100M MAXSIZE 2G
EXTENT MANAGEMENT LOCAL
SEGMENT SPACE MANAGEMENT AUTO;


-- Index tablespace
CREATE TABLESPACE sales_index
DATAFILE 'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/sales_index01.dbf'
SIZE 200M
AUTOEXTEND ON NEXT 50M MAXSIZE 1G
EXTENT MANAGEMENT LOCAL
SEGMENT SPACE MANAGEMENT AUTO;

-- Temporary tablespace for sorting operations
CREATE TEMPORARY TABLESPACE sales_temp
TEMPFILE 'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/sales_temp01.dbf'
SIZE 100M
AUTOEXTEND ON NEXT 50M MAXSIZE 500M
EXTENT MANAGEMENT LOCAL;


-- Undo tablespace
CREATE UNDO TABLESPACE sales_undo
DATAFILE 'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/sales_undo01.dbf'
SIZE 200M
AUTOEXTEND ON NEXT 50M MAXSIZE 1G
RETENTION GUARANTEE;




CREATE USER ben_admin IDENTIFIED BY 1234
DEFAULT TABLESPACE sales_data
TEMPORARY TABLESPACE sales_temp
QUOTA UNLIMITED ON sales_data
QUOTA UNLIMITED ON sales_index
ACCOUNT UNLOCK
PASSWORD EXPIRE;



-- Grant privileges
GRANT CONNECT, RESOURCE, DBA TO ben_admin;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, 
      CREATE PROCEDURE, CREATE TRIGGER, CREATE SEQUENCE,
      CREATE TYPE, CREATE MATERIALIZED VIEW TO ben_admin;
GRANT UNLIMITED TABLESPACE TO ben_admin;



-- Enable archive logging
ALTER DATABASE ARCHIVELOG;

-- Set memory parameters
ALTER SYSTEM SET SGA_TARGET=512M SCOPE=SPFILE;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET=256M SCOPE=SPFILE;
ALTER SYSTEM SET PROCESSES=300 SCOPE=SPFILE;
ALTER SYSTEM SET SESSIONS=450 SCOPE=SPFILE;



ALTER SYSTEM SET UNDO_RETENTION=900 SCOPE=BOTH;


ALTER DATABASE DATAFILE 
    'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/sales_data01.dbf'
    AUTOEXTEND ON MAXSIZE 2G;


ALTER DATABASE DATAFILE 
    'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/sales_index01.dbf'
    AUTOEXTEND ON MAXSIZE 1G;
    
    
-- ========== STEP 5: CREATE APPLICATION USER ==========
CREATE USER sales_app IDENTIFIED BY 1234
DEFAULT TABLESPACE sales_data
TEMPORARY TABLESPACE sales_temp
QUOTA 500M ON sales_data
QUOTA 200M ON sales_index
ACCOUNT UNLOCK;



-- Grant application privileges
GRANT CONNECT, RESOURCE TO sales_app;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE SEQUENCE TO sales_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ben_admin. * TO sales_app;




-- ========== STEP 6: CREATE READ-ONLY USER FOR REPORTS ==========
CREATE USER sales_reader IDENTIFIED BY reader123
DEFAULT TABLESPACE sales_data
TEMPORARY TABLESPACE sales_temp
QUOTA 10M ON sales_data
ACCOUNT UNLOCK;

GRANT CREATE SESSION TO sales_reader;
GRANT SELECT ANY TABLE TO sales_reader;




-- ========== STEP 7: VERIFY DATABASE CREATION ==========

-- Display database information
SELECT name, open_mode, log_mode 
FROM v$database;

-- Display tablespace information
SELECT tablespace_name, file_name, bytes/1024/1024 as size_mb, 
       autoextensible, maxbytes/1024/1024 as max_size_mb
FROM dba_data_files
ORDER BY tablespace_name;

-- Display user information
SELECT username, account_status, default_tablespace, 
       temporary_tablespace, created
FROM dba_users
WHERE username IN ('BEN_ADMIN', 'SALES_APP', 'SALES_READER');




-- ========== STEP 8: CREATE DIRECTORY FOR EXTERNAL FILES ==========
CREATE OR REPLACE DIRECTORY data_pump_dir AS 'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/dpdump/';
CREATE OR REPLACE DIRECTORY log_dir AS 'C:\oracle19c\oradata\ORCL\pdbseed\PL_SQL_EXAM/logs/';

GRANT READ, WRITE ON DIRECTORY data_pump_dir TO ben_admin;
GRANT READ, WRITE ON DIRECTORY log_dir TO ben_admin;

-- ========== STEP 9: CREATE TABLESPACE FOR AUDIT DATA ==========
CREATE TABLESPACE audit_ts
DATAFILE 'audit_data01.dbf'
SIZE 100M
AUTOEXTEND ON NEXT 50M MAXSIZE 500M
EXTENT MANAGEMENT LOCAL
SEGMENT SPACE MANAGEMENT AUTO;

-- ========== STEP 10: ENABLE AUDITING ==========
AUDIT ALL BY ben_admin BY ACCESS;
AUDIT CREATE TABLE, DROP TABLE, ALTER TABLE BY ben_admin;
AUDIT INSERT, UPDATE, DELETE ON ben_admin.* BY ACCESS;

-- Display audit configuration
SELECT audit_option, success, failure
FROM dba_stmt_audit_opts
WHERE user_name = 'BEN_ADMIN' OR user_name IS NULL;

COMMIT;



