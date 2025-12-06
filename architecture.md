# Database Architecture Documentation

## Project Overview
**Project Name:** Employee Action Restriction & Audit System  
**Database:** Oracle Database 21c  
**Schema:** `{Your_Project_Schema}`  
**Developer:** {Your Name}  
**Student ID:** {Your Student ID}  
**Date:** December 2025

## System Architecture

### 1. High-Level Architecture

```sql
┌─────────────────────────────────────────────────────────────┐
│ Application Layer │
│ ┌─────────────┐ ┌─────────────┐ ┌──────────────────┐ │
│ │ UI/Forms │ │ Reports │ │ BI Dashboards │ │
│ └─────────────┘ └─────────────┘ └──────────────────┘ │
└───────────────────────────┬─────────────────────────────────┘
│
┌───────────────────────────▼─────────────────────────────────┐
│ PL/SQL API Layer │
│ ┌─────────────┐ ┌─────────────┐ ┌──────────────────┐ │
│ │ Procedures │ │ Functions │ │ Packages │ │
│ └─────────────┘ └─────────────┘ └──────────────────┘ │
└───────────────────────────┬─────────────────────────────────┘
│
┌───────────────────────────▼─────────────────────────────────┐
│ Trigger Layer │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Simple Triggers │ Compound Triggers │ DDL Triggers│ │
│ └──────────────────────────────────────────────────────┘ │
└───────────────────────────┬─────────────────────────────────┘
│
┌───────────────────────────▼─────────────────────────────────┐
│ Core Database Layer │
│ ┌─────────────┐ ┌─────────────┐ ┌──────────────────┐ │
│ │ Tables │ │ Indexes │ │ Constraints │ │
│ └─────────────┘ └─────────────┘ └──────────────────┘ │
└───────────────────────────┬─────────────────────────────────┘
│
┌───────────────────────────▼─────────────────────────────────┐
│ Storage Layer │
│ ┌─────────────┐ ┌─────────────┐ ┌──────────────────┐ │
│ │ Tablespaces │ │ Datafiles │ │ Redo Logs │ │
│ └─────────────┘ └─────────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```


### 2. Database Schema Structure

#### 2.1 Core Tables
```sql
-- Main business entities
EMPLOYEES
├── employee_id (PK)
├── employee_name
├── department
├── position
├── email
├── restriction_applied
└── hire_date

TEST_EMPLOYEE_ACTIONS
├── action_id (PK)
├── employee_id (FK → EMPLOYEES)
├── action_date
├── action_type
├── description
├── amount
└── status

HOLIDAYS
├── holiday_id (PK)
├── holiday_date
├── holiday_name
├── description
├── is_returning
└── created_date
│
┌───────────────────────────▼─────────────────────────────────┐
│ Storage Layer │
│ ┌─────────────┐ ┌─────────────┐ ┌──────────────────┐ │
│ │ Tablespaces │ │ Datafiles │ │ Redo Logs │ │
│ └─────────────┘ └─────────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
