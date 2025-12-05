# DATABASE CREATION DOCUMENTATION
## Customer Order & Sales Analytics System

### Project Information
- **Student:** Benjamin (ID: 27883)
- **Course:** Database Development with PL/SQL (INSY 8311)
- **Institution:** Adventist University of Central Africa (AUCA)
- **Lecturer:** Eric Maniraquha
- **Date:** November 2025
- **Phase:** IV - Database Creation

### Database Details
- **Database Name:** `tue_27883_benjamin_SalesAnalytics_DB`
- **Type:** Oracle Pluggable Database (PDB)
- **Admin User:** `ben_admin` / `1234`
- **Application User:** `sales_app` / `1234`
- **Reader User:** `sales_reader` / `1234`

### File Structure

### Execution Order
1. **01_create_database.sql** - Creates PDB, tablespaces, users
2. **02_configuration_parameters.sql** - Configures database parameters
3. **03_project_structure.sql** - Creates sequences, synonyms, metadata

### Tablespace Configuration
| Tablespace | Size | Purpose | Autoextend |
|------------|------|---------|------------|
| SALES_DATA | 500M | Main data storage | Yes, up to 2G |
| SALES_INDEX | 200M | Index storage | Yes, up to 1G |
| SALES_TEMP | 100M | Temporary operations | Yes, up to 500M |
| SALES_UNDO | 200M | Undo transactions | Yes, up to 1G |
| AUDIT_TS | 100M | Audit log storage | Yes, up to 500M |

### User Privileges
| Username | Role | Privileges |
|----------|------|------------|
| BEN_ADMIN | DBA | Full database access |
| SALES_APP | Application | Create tables, procedures, limited DML |
| SALES_READER | Read-only | SELECT only on all tables |

### Database Parameters Configured
- **SGA_TARGET:** 512M
- **PGA_AGGREGATE_TARGET:** 256M
- **PROCESSES:** 300
- **SESSIONS:** 450
- **UNDO_RETENTION:** 900 seconds
- **ARCHIVELOG:** Enabled

### Verification Steps
After running all scripts, verify:

1. **Database exists:**
   ```sql
   SELECT name, open_mode FROM v$database;
