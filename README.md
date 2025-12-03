I'll help you create a comprehensive **Customer Order & Sales Analytics System** project following all 8 phases of your capstone requirements. Let's build this step-by-step:

## **CUSTOMER ORDER & SALES ANALYTICS SYSTEM**
*Student: [Your Name], ID: [Your Student ID]*

---

## **PHASE I: PROBLEM STATEMENT & PRESENTATION**

### **Problem Definition:**
- **Issue:** Companies struggle with fragmented order data, manual sales tracking, and lack of real-time analytics for decision-making
- **Context:** E-commerce/retail business needing centralized order management with BI capabilities
- **Target Users:** Sales managers, inventory planners, marketing teams, executives
- **Goals:** Automate order processing, track sales performance, predict trends, optimize inventory
- **BI Potential:** Real-time dashboards showing sales trends, customer segmentation, product performance, seasonal patterns

**Presentation Slides:** Create 5 slides covering:
1. Title Slide
2. Problem Overview
3. Business Impact
4. Solution Architecture
5. Expected Outcomes

---

## **PHASE II: BUSINESS PROCESS MODELING**

### **Scope:**
Order-to-cash process including:
1. Customer registration
2. Product catalog management
3. Order placement
4. Payment processing
5. Order fulfillment
6. Shipping and delivery
7. Returns management
8. Sales reporting

### **Key Entities:**
- **Actors:** Customers, Sales Reps, Warehouse Staff, Managers
- **Systems:** CRM, Payment Gateway, Inventory System
- **Departments:** Sales, Warehouse, Finance, Marketing

### **UML/BPMN Diagram:**
Create swimlane diagram showing:
- Customer actions vs. System actions
- Decision points (payment approved? inventory available?)
- Data flows between entities

---

## **PHASE III: LOGICAL MODEL DESIGN**

### **ER Diagram Entities:**
1. **CUSTOMERS** (Customer_ID PK, Name, Email, Join_Date, Segment)
2. **PRODUCTS** (Product_ID PK, Name, Category, Price, Cost, Supplier_ID)
3. **ORDERS** (Order_ID PK, Customer_ID FK, Order_Date, Status, Total_Amount)
4. **ORDER_ITEMS** (Order_Item_ID PK, Order_ID FK, Product_ID FK, Quantity, Unit_Price)
5. **PAYMENTS** (Payment_ID PK, Order_ID FK, Payment_Date, Amount, Method)
6. **SHIPMENTS** (Shipment_ID PK, Order_ID FK, Ship_Date, Carrier, Tracking_Number)
7. **EMPLOYEES** (Employee_ID PK, Name, Department, Hire_Date)
8. **SUPPLIERS** (Supplier_ID PK, Name, Contact_Info)

### **3NF Normalization:**
- Separate tables for entities
- No transitive dependencies
- All non-key attributes depend on PK

### **Data Dictionary:**
Create comprehensive table with columns, types, constraints, descriptions

### **BI Considerations:**
- **Fact Tables:** ORDERS, ORDER_ITEMS, PAYMENTS
- **Dimension Tables:** CUSTOMERS, PRODUCTS, TIME, EMPLOYEES
- **Slow Changing Dimensions:** Customer segmentation changes, product category updates
- **Audit Trail:** Track price changes, status updates

---

## **PHASE IV: DATABASE CREATION**

### **Database Name:**
`[GroupDay]_[StudentID]_[YourName]_SalesAnalytics_DB`
Example: `mon_12345_John_SalesAnalytics_DB`

### **Configuration Scripts:**
```sql
-- Create tablespaces
CREATE TABLESPACE sales_data 
DATAFILE 'sales_data01.dbf' SIZE 500M AUTOEXTEND ON;

CREATE TABLESPACE sales_index 
DATAFILE 'sales_index01.dbf' SIZE 200M AUTOEXTEND ON;

-- Create user
CREATE USER sales_admin IDENTIFIED BY [YourFirstName]
DEFAULT TABLESPACE sales_data
QUOTA UNLIMITED ON sales_data;

-- Grant privileges
GRANT CONNECT, RESOURCE, DBA TO sales_admin;
```

---

## **PHASE V: TABLE IMPLEMENTATION**

### **CREATE TABLE Scripts:**
```sql
-- CUSTOMERS table
CREATE TABLE customers (
    customer_id NUMBER(10) PRIMARY KEY,
    customer_name VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    phone VARCHAR2(20),
    address VARCHAR2(200),
    city VARCHAR2(50),
    country VARCHAR2(50),
    join_date DATE DEFAULT SYSDATE,
    customer_segment VARCHAR2(20),
    CONSTRAINT chk_segment CHECK (customer_segment IN ('Bronze','Silver','Gold','Platinum'))
);

-- ORDERS table
CREATE TABLE orders (
    order_id NUMBER(10) PRIMARY KEY,
    customer_id NUMBER(10) REFERENCES customers(customer_id),
    order_date DATE NOT NULL,
    status VARCHAR2(20) DEFAULT 'PENDING',
    total_amount NUMBER(10,2) NOT NULL,
    discount_amount NUMBER(10,2) DEFAULT 0,
    net_amount NUMBER(10,2) GENERATED ALWAYS AS (total_amount - discount_amount) VIRTUAL,
    CONSTRAINT chk_status CHECK (status IN ('PENDING','PROCESSING','SHIPPED','DELIVERED','CANCELLED'))
);

-- Create all other tables similarly...
```

### **Data Insertion:**
Insert 500+ realistic records per main table with varied data:
- Customers from different segments
- Orders across multiple years
- Products across categories
- Different payment methods
- Various shipment statuses

### **Test Queries:**
```sql
-- Verify data
SELECT COUNT(*) AS total_customers FROM customers;
SELECT * FROM orders WHERE ROWNUM <= 10;

-- Test joins
SELECT c.customer_name, o.order_id, o.total_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id;

-- Test aggregations
SELECT customer_segment, COUNT(*) AS customer_count, 
       AVG(total_amount) AS avg_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY customer_segment;
```

---

## **PHASE VI: PL/SQL DEVELOPMENT**

### **Procedures (5 required):**
1. **PROC_CREATE_ORDER** - Creates new order with validation
2. **PROC_UPDATE_ORDER_STATUS** - Updates status with audit
3. **PROC_CALCULATE_REVENUE** - Calculates daily/weekly revenue
4. **PROC_GENERATE_INVOICE** - Generates invoice for order
5. **PROC_PROCESS_RETURN** - Handles product returns

### **Functions (5 required):**
1. **FN_CALCULATE_DISCOUNT** - Calculates discount based on customer tier
2. **FN_GET_CUSTOMER_LIFETIME_VALUE** - Calculates LTV
3. **FN_VALIDATE_CREDIT** - Checks customer credit limit
4. **FN_GET_PRODUCT_PROFIT_MARGIN** - Calculates profit percentage
5. **FN_PREDICT_SALES_TREND** - Predicts next month sales

### **Package:**
```sql
CREATE OR REPLACE PACKAGE sales_analytics_pkg AS
    -- Procedures
    PROCEDURE generate_sales_report(p_start_date DATE, p_end_date DATE);
    PROCEDURE update_customer_tier(p_customer_id NUMBER);
    
    -- Functions
    FUNCTION calculate_yoy_growth RETURN NUMBER;
    FUNCTION get_top_products(p_limit NUMBER) RETURN SYS_REFCURSOR;
    
    -- Cursors
    CURSOR c_monthly_sales IS
        SELECT TRUNC(order_date, 'MM') AS month,
               SUM(total_amount) AS monthly_sales
        FROM orders
        GROUP BY TRUNC(order_date, 'MM');
END sales_analytics_pkg;
```

### **Window Functions:**
```sql
-- Rank customers by total purchases
SELECT customer_id, customer_name,
       SUM(total_amount) AS total_spent,
       RANK() OVER (ORDER BY SUM(total_amount) DESC) AS customer_rank,
       LAG(SUM(total_amount)) OVER (ORDER BY SUM(total_amount) DESC) AS prev_customer_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY customer_id, customer_name;

-- Moving average of sales
SELECT order_date, total_amount,
       AVG(total_amount) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS weekly_moving_avg
FROM orders;
```

---

## **PHASE VII: ADVANCED PROGRAMMING & AUDITING**

### **Business Rule Implementation:**
**Restriction:** Employees cannot process refunds on weekends or holidays

### **Holiday Table:**
```sql
CREATE TABLE holidays (
    holiday_date DATE PRIMARY KEY,
    holiday_name VARCHAR2(100),
    description VARCHAR2(200)
);
```

### **Audit Log Table:**
```sql
CREATE TABLE order_audit_log (
    audit_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action_type VARCHAR2(20),
    table_name VARCHAR2(50),
    record_id NUMBER,
    old_value VARCHAR2(4000),
    new_value VARCHAR2(4000),
    changed_by VARCHAR2(50),
    change_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP,
    ip_address VARCHAR2(50)
);
```

### **Compound Trigger:**
```sql
CREATE OR REPLACE TRIGGER trg_order_refund_restriction
FOR INSERT OR UPDATE ON refunds
COMPOUND TRIGGER
    
    -- Declaration section
    TYPE t_audit_info IS RECORD (
        action_type VARCHAR2(20),
        order_id NUMBER,
        amount NUMBER
    );
    
    TYPE t_audit_table IS TABLE OF t_audit_info;
    g_audit_records t_audit_table := t_audit_table();
    
    -- Before each row
    BEFORE EACH ROW IS
    BEGIN
        -- Check if today is weekend
        IF TO_CHAR(SYSDATE, 'DY') IN ('SAT', 'SUN') THEN
            RAISE_APPLICATION_ERROR(-20001, 
                'Refunds cannot be processed on weekends');
        END IF;
        
        -- Check if today is holiday
        IF EXISTS (SELECT 1 FROM holidays 
                   WHERE holiday_date = TRUNC(SYSDATE)) THEN
            RAISE_APPLICATION_ERROR(-20002, 
                'Refunds cannot be processed on holidays');
        END IF;
        
        -- Store audit info
        g_audit_records.EXTEND;
        g_audit_records(g_audit_records.LAST).action_type := 
            CASE WHEN INSERTING THEN 'INSERT' ELSE 'UPDATE' END;
        g_audit_records(g_audit_records.LAST).order_id := :NEW.order_id;
        g_audit_records(g_audit_records.LAST).amount := :NEW.refund_amount;
    END BEFORE EACH ROW;
    
    -- After statement
    AFTER STATEMENT IS
    BEGIN
        FOR i IN 1..g_audit_records.COUNT LOOP
            INSERT INTO order_audit_log 
                (action_type, table_name, record_id, changed_by)
            VALUES (
                g_audit_records(i).action_type,
                'REFUNDS',
                g_audit_records(i).order_id,
                USER
            );
        END LOOP;
    END AFTER STATEMENT;
    
END trg_order_refund_restriction;
```

---

## **PHASE VIII: FINAL DOCUMENTATION & BI**

### **GitHub Repository Structure:**
```
sales-analytics-system/
├── README.md
├── database/
│   ├── scripts/
│   │   ├── 01_create_database.sql
│   │   ├── 02_create_tables.sql
│   │   ├── 03_insert_data.sql
│   │   ├── 04_procedures_functions.sql
│   │   └── 05_triggers_packages.sql
│   └── documentation/
│       ├── data_dictionary.md
│       └── architecture_diagram.png
├── business_intelligence/
│   ├── bi_requirements.md
│   ├── dashboard_mockups/
│   └── kpi_definitions.md
├── queries/
│   ├── analytical_queries.sql
│   ├── audit_queries.sql
│   └── data_validation.sql
└── screenshots/
    ├── er_diagram.png
    ├── database_objects.png
    └── test_results.png
```

### **Business Intelligence Implementation:**

#### **KPIs to Track:**
1. **Sales Performance:** Monthly Revenue, YoY Growth
2. **Customer Metrics:** Customer Lifetime Value, Retention Rate
3. **Product Metrics:** Top Selling Products, Profit Margins
4. **Operational Metrics:** Order Fulfillment Time, Return Rate

#### **Dashboard Mockups:**
1. **Executive Dashboard:**
   - Revenue trend chart
   - Top 10 customers
   - Product category performance
   - Regional sales heatmap

2. **Operational Dashboard:**
   - Orders by status
   - Pending shipments
   - Inventory levels
   - Return analysis

3. **Customer Analytics Dashboard:**
   - Customer segmentation
   - Purchase frequency
   - Average order value by segment
   - Churn risk indicators

### **Analytical Queries:**
```sql
-- Customer segmentation analysis
SELECT 
    customer_segment,
    COUNT(DISTINCT o.customer_id) AS customer_count,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_order_value,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT o.customer_id) AS avg_orders_per_customer
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- Sales trend analysis with window functions
SELECT 
    TO_CHAR(order_date, 'YYYY-MM') AS sales_month,
    SUM(total_amount) AS monthly_sales,
    LAG(SUM(total_amount)) OVER (ORDER BY TO_CHAR(order_date, 'YYYY-MM')) AS prev_month_sales,
    ROUND(((SUM(total_amount) - 
           LAG(SUM(total_amount)) OVER (ORDER BY TO_CHAR(order_date, 'YYYY-MM'))) /
           LAG(SUM(total_amount)) OVER (ORDER BY TO_CHAR(order_date, 'YYYY-MM'))) * 100, 2) AS growth_percentage
FROM orders
GROUP BY TO_CHAR(order_date, 'YYYY-MM')
ORDER BY sales_month;
```

### **Presentation Slides (10 slides):**

1. **Title Slide:** Project title, your name, date, AUCA logo
2. **Problem Statement:** Fragmented sales data, manual processes, lack of insights
3. **Solution Overview:** Centralized order management with BI capabilities
4. **Database Design:** ER diagram showing 8 main entities
5. **Business Process:** Swimlane diagram of order-to-cash process
6. **Technical Implementation:** PL/SQL procedures, functions, packages
7. **Advanced Features:** Triggers, auditing, security rules
8. **BI & Analytics:** Dashboard mockups, KPIs defined
9. **Results & Testing:** Screenshots of working system, test results
10. **Conclusion & Q&A:** Lessons learned, future enhancements

---

## **SUBMISSION CHECKLIST:**

- [ ] All code is original and tested
- [ ] GitHub repository is properly organized with meaningful commits
- [ ] Screenshots include project name
- [ ] PowerPoint is exactly 10 slides
- [ ] All 8 phases completed
- [ ] BI implementation included
- [ ] Submitted before December 7, 2025 deadline

---

## **PROJECT COMPLEXITY ENHANCEMENTS (for bonus points):**

1. **Predictive Analytics:** Implement sales forecasting using historical data
2. **Real-time Monitoring:** Create alert system for unusual sales patterns
3. **Integration:** Simulate API calls to external payment gateways
4. **Advanced Security:** Implement row-level security for different user roles
5. **Performance Optimization:** Use materialized views for frequently accessed reports

This comprehensive plan covers all requirements from your document. Each phase builds upon the previous one, creating a production-ready Customer Order & Sales Analytics System with full BI capabilities.
