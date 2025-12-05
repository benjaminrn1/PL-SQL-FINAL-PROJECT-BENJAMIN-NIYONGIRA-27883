-- ============================================
-- STEP 4: CREATE ALL TABLES (FIXED VERSION)
-- ============================================

SET SERVEROUTPUT ON
BEGIN
    DBMS_OUTPUT.PUT_LINE('Creating all 12 tables with fixed constraints...');
END;
/

-- ========== TABLE 1: CUSTOMERS ==========
CREATE TABLE customers (
    customer_id NUMBER 
        CONSTRAINT pk_customers PRIMARY KEY,
    customer_name VARCHAR2(100) 
        CONSTRAINT nn_customers_name NOT NULL,
    email VARCHAR2(100) 
        CONSTRAINT nn_customers_email NOT NULL
        CONSTRAINT uq_customers_email UNIQUE,
    phone VARCHAR2(20),
    address VARCHAR2(200),
    city VARCHAR2(50),
    country VARCHAR2(50) 
        DEFAULT 'USA',
    join_date DATE 
        DEFAULT SYSDATE 
        CONSTRAINT nn_customers_joindate NOT NULL,
    customer_segment VARCHAR2(20) 
        DEFAULT 'BRONZE' 
        CONSTRAINT nn_customers_segment NOT NULL
        CONSTRAINT chk_customers_segment 
            CHECK (customer_segment IN ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM')),
    total_spent NUMBER(12,2) 
        DEFAULT 0 
        CONSTRAINT nn_customers_totalspent NOT NULL
        CONSTRAINT chk_customers_totalspent CHECK (total_spent >= 0),
    last_order_date DATE
);

-- ========== TABLE 2: CATEGORIES ==========
CREATE TABLE categories (
    category_id NUMBER 
        CONSTRAINT pk_categories PRIMARY KEY,
    category_name VARCHAR2(50) 
        CONSTRAINT nn_categories_name NOT NULL
        CONSTRAINT uq_categories_name UNIQUE,
    parent_category_id NUMBER,
    description VARCHAR2(500)
);

-- Add self-referencing FK later to avoid circular dependency
ALTER TABLE categories ADD (
    CONSTRAINT fk_categories_parent 
        FOREIGN KEY (parent_category_id) 
        REFERENCES categories(category_id)
);

-- ========== TABLE 3: SUPPLIERS ==========
CREATE TABLE suppliers (
    supplier_id NUMBER 
        CONSTRAINT pk_suppliers PRIMARY KEY,
    supplier_name VARCHAR2(100) 
        CONSTRAINT nn_suppliers_name NOT NULL,
    contact_name VARCHAR2(100),
    email VARCHAR2(100) 
        CONSTRAINT nn_suppliers_email NOT NULL
        CONSTRAINT uq_suppliers_email UNIQUE,
    phone VARCHAR2(20),
    address VARCHAR2(200),
    city VARCHAR2(50),
    country VARCHAR2(50) 
        DEFAULT 'USA',
    payment_terms VARCHAR2(50) 
        DEFAULT 'NET30'
);

-- ========== TABLE 4: PRODUCTS ==========
CREATE TABLE products (
    product_id NUMBER 
        CONSTRAINT pk_products PRIMARY KEY,
    product_name VARCHAR2(100) 
        CONSTRAINT nn_products_name NOT NULL,
    category_id NUMBER 
        CONSTRAINT nn_products_category NOT NULL,
    unit_price NUMBER(10,2) 
        CONSTRAINT nn_products_unitprice NOT NULL
        CONSTRAINT chk_products_unitprice CHECK (unit_price > 0),
    unit_cost NUMBER(10,2) 
        CONSTRAINT nn_products_unitcost NOT NULL
        CONSTRAINT chk_products_unitcost CHECK (unit_cost > 0),
    supplier_id NUMBER 
        CONSTRAINT nn_products_supplier NOT NULL,
    stock_quantity NUMBER(10) 
        DEFAULT 0 
        CONSTRAINT nn_products_stock NOT NULL
        CONSTRAINT chk_products_stock CHECK (stock_quantity >= 0),
    reorder_level NUMBER(10) 
        DEFAULT 10 
        CONSTRAINT nn_products_reorder NOT NULL
        CONSTRAINT chk_products_reorder CHECK (reorder_level >= 0),
    status VARCHAR2(20) 
        DEFAULT 'ACTIVE' 
        CONSTRAINT nn_products_status NOT NULL
        CONSTRAINT chk_products_status 
            CHECK (status IN ('ACTIVE', 'DISCONTINUED', 'OUT_OF_STOCK')),
    created_date DATE 
        DEFAULT SYSDATE 
        CONSTRAINT nn_products_created NOT NULL
);

-- Add FKs after tables exist
ALTER TABLE products ADD (
    CONSTRAINT fk_products_category 
        FOREIGN KEY (category_id) 
        REFERENCES categories(category_id),
    CONSTRAINT fk_products_supplier 
        FOREIGN KEY (supplier_id) 
        REFERENCES suppliers(supplier_id),
    CONSTRAINT chk_products_price_cost 
        CHECK (unit_price >= unit_cost)
);

-- ========== TABLE 5: EMPLOYEES ==========
CREATE TABLE employees (
    employee_id NUMBER 
        CONSTRAINT pk_employees PRIMARY KEY,
    employee_name VARCHAR2(100) 
        CONSTRAINT nn_employees_name NOT NULL,
    department VARCHAR2(50) 
        CONSTRAINT nn_employees_dept NOT NULL,
    position VARCHAR2(50) 
        CONSTRAINT nn_employees_position NOT NULL,
    hire_date DATE 
        DEFAULT SYSDATE 
        CONSTRAINT nn_employees_hiredate NOT NULL,
    email VARCHAR2(100) 
        CONSTRAINT nn_employees_email NOT NULL
        CONSTRAINT uq_employees_email UNIQUE,
    phone VARCHAR2(20),
    manager_id NUMBER,
    is_active CHAR(1) 
        DEFAULT 'Y' 
        CONSTRAINT nn_employees_active NOT NULL
        CONSTRAINT chk_employees_active CHECK (is_active IN ('Y', 'N'))
);

-- Add self-referencing FK later
ALTER TABLE employees ADD (
    CONSTRAINT fk_employees_manager 
        FOREIGN KEY (manager_id) 
        REFERENCES employees(employee_id),
    CONSTRAINT chk_employees_not_self_manager 
        CHECK (manager_id != employee_id OR manager_id IS NULL)
);

-- ========== TABLE 6: ORDERS ==========
CREATE TABLE orders (
    order_id NUMBER 
        CONSTRAINT pk_orders PRIMARY KEY,
    customer_id NUMBER 
        CONSTRAINT nn_orders_customer NOT NULL,
    order_date DATE 
        DEFAULT SYSDATE 
        CONSTRAINT nn_orders_date NOT NULL,
    status VARCHAR2(20) 
        DEFAULT 'PENDING' 
        CONSTRAINT nn_orders_status NOT NULL
        CONSTRAINT chk_orders_status 
            CHECK (status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED')),
    total_amount NUMBER(12,2) 
        CONSTRAINT nn_orders_total NOT NULL
        CONSTRAINT chk_orders_total CHECK (total_amount > 0),
    discount_amount NUMBER(10,2) 
        DEFAULT 0 
        CONSTRAINT chk_orders_discount CHECK (discount_amount >= 0),
    tax_amount NUMBER(10,2) 
        DEFAULT 0 
        CONSTRAINT chk_orders_tax CHECK (tax_amount >= 0),
    net_amount NUMBER(12,2) 
        GENERATED ALWAYS AS (total_amount - discount_amount + tax_amount) VIRTUAL,
    shipping_address VARCHAR2(200) 
        CONSTRAINT nn_orders_shipping NOT NULL,
    billing_address VARCHAR2(200) 
        CONSTRAINT nn_orders_billing NOT NULL,
    employee_id NUMBER
);

-- Add FKs after tables exist
ALTER TABLE orders ADD (
    CONSTRAINT fk_orders_customer 
        FOREIGN KEY (customer_id) 
        REFERENCES customers(customer_id),
    CONSTRAINT fk_orders_employee 
        FOREIGN KEY (employee_id) 
        REFERENCES employees(employee_id),
    CONSTRAINT chk_orders_discount_limit 
        CHECK (discount_amount <= total_amount * 0.5)
);

-- ========== TABLE 7: ORDER_ITEMS ==========
CREATE TABLE order_items (
    order_item_id NUMBER 
        CONSTRAINT pk_order_items PRIMARY KEY,
    order_id NUMBER 
        CONSTRAINT nn_orderitems_order NOT NULL,
    product_id NUMBER 
        CONSTRAINT nn_orderitems_product NOT NULL,
    quantity NUMBER(5) 
        CONSTRAINT nn_orderitems_quantity NOT NULL
        CONSTRAINT chk_orderitems_quantity CHECK (quantity > 0),
    unit_price NUMBER(10,2) 
        CONSTRAINT nn_orderitems_unitprice NOT NULL
        CONSTRAINT chk_orderitems_unitprice CHECK (unit_price > 0),
    discount_percent NUMBER(5,2) 
        DEFAULT 0 
        CONSTRAINT chk_orderitems_discountpct CHECK (discount_percent BETWEEN 0 AND 100),
    line_total NUMBER(12,2) 
        GENERATED ALWAYS AS (quantity * unit_price * (1 - discount_percent/100)) VIRTUAL
);

ALTER TABLE order_items ADD (
    CONSTRAINT fk_orderitems_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id),
    CONSTRAINT fk_orderitems_product 
        FOREIGN KEY (product_id) 
        REFERENCES products(product_id),
    CONSTRAINT uq_orderitem_unique 
        UNIQUE (order_id, product_id)
);

-- ========== TABLE 8: PAYMENTS ==========
CREATE TABLE payments (
    payment_id NUMBER 
        CONSTRAINT pk_payments PRIMARY KEY,
    order_id NUMBER 
        CONSTRAINT nn_payments_order NOT NULL,
    payment_date DATE 
        DEFAULT SYSDATE 
        CONSTRAINT nn_payments_date NOT NULL,
    amount NUMBER(10,2) 
        CONSTRAINT nn_payments_amount NOT NULL
        CONSTRAINT chk_payments_amount CHECK (amount > 0),
    payment_method VARCHAR2(30) 
        CONSTRAINT nn_payments_method NOT NULL
        CONSTRAINT chk_payments_method 
            CHECK (payment_method IN ('CREDIT_CARD', 'DEBIT_CARD', 'PAYPAL', 'BANK_TRANSFER', 'CASH', 'CHECK')),
    transaction_id VARCHAR2(50) 
        CONSTRAINT uq_payments_transaction UNIQUE,
    status VARCHAR2(20) 
        DEFAULT 'PENDING' 
        CONSTRAINT nn_payments_status NOT NULL
        CONSTRAINT chk_payments_status 
            CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED')),
    authorization_code VARCHAR2(50)
);

ALTER TABLE payments ADD (
    CONSTRAINT fk_payments_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id)
);

-- ========== TABLE 9: SHIPMENTS ==========
CREATE TABLE shipments (
    shipment_id NUMBER 
        CONSTRAINT pk_shipments PRIMARY KEY,
    order_id NUMBER 
        CONSTRAINT nn_shipments_order NOT NULL
        CONSTRAINT uq_shipments_order UNIQUE,
    ship_date DATE,
    carrier VARCHAR2(50),
    tracking_number VARCHAR2(100) 
        CONSTRAINT uq_shipments_tracking UNIQUE,
    estimated_delivery DATE,
    actual_delivery DATE,
    shipping_cost NUMBER(10,2) 
        DEFAULT 0 
        CONSTRAINT chk_shipments_cost CHECK (shipping_cost >= 0),
    status VARCHAR2(20) 
        DEFAULT 'PENDING' 
        CONSTRAINT nn_shipments_status NOT NULL
        CONSTRAINT chk_shipments_status 
            CHECK (status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'IN_TRANSIT', 'DELIVERED', 'RETURNED'))
);

ALTER TABLE shipments ADD (
    CONSTRAINT fk_shipments_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id),
    CONSTRAINT chk_shipments_dates 
        CHECK (actual_delivery IS NULL OR actual_delivery >= ship_date)
);

-- ========== TABLE 10: PROMOTIONS ==========
CREATE TABLE promotions (
    promotion_id NUMBER 
        CONSTRAINT pk_promotions PRIMARY KEY,
    promotion_name VARCHAR2(100) 
        CONSTRAINT nn_promotions_name NOT NULL,
    discount_percent NUMBER(5,2) 
        CONSTRAINT nn_promotions_discount NOT NULL
        CONSTRAINT chk_promotions_discount CHECK (discount_percent BETWEEN 1 AND 100),
    start_date DATE 
        CONSTRAINT nn_promotions_start NOT NULL,
    end_date DATE 
        CONSTRAINT nn_promotions_end NOT NULL,
    minimum_order_amount NUMBER(10,2) 
        DEFAULT 0,
    maximum_discount NUMBER(10,2),
    applicable_category_id NUMBER
);

ALTER TABLE promotions ADD (
    CONSTRAINT fk_promotions_category 
        FOREIGN KEY (applicable_category_id) 
        REFERENCES categories(category_id),
    CONSTRAINT chk_promotions_dates 
        CHECK (end_date > start_date)
);

-- ========== TABLE 11: AUDIT_LOG ==========
CREATE TABLE audit_log (
    audit_id NUMBER 
        CONSTRAINT pk_audit_log PRIMARY KEY,
    table_name VARCHAR2(50) 
        CONSTRAINT nn_audit_tablename NOT NULL,
    record_id VARCHAR2(50) 
        CONSTRAINT nn_audit_recordid NOT NULL,
    action_type VARCHAR2(20) 
        CONSTRAINT nn_audit_action NOT NULL
        CONSTRAINT chk_audit_action 
            CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
    old_value CLOB,
    new_value CLOB,
    changed_by VARCHAR2(50) 
        DEFAULT USER 
        CONSTRAINT nn_audit_changedby NOT NULL,
    change_timestamp TIMESTAMP 
        DEFAULT SYSTIMESTAMP 
        CONSTRAINT nn_audit_timestamp NOT NULL,
    ip_address VARCHAR2(50)
);

-- ========== TABLE 12: HOLIDAYS ==========
CREATE TABLE holidays (
    holiday_id NUMBER 
        CONSTRAINT pk_holidays PRIMARY KEY,
    holiday_date DATE 
        CONSTRAINT nn_holidays_date NOT NULL
        CONSTRAINT uq_holidays_date UNIQUE,
    holiday_name VARCHAR2(100) 
        CONSTRAINT nn_holidays_name NOT NULL,
    description VARCHAR2(500),
    is_recurring CHAR(1) 
        DEFAULT 'N' 
        CONSTRAINT nn_holidays_recurring NOT NULL
        CONSTRAINT chk_holidays_recurring CHECK (is_recurring IN ('Y', 'N'))
);

-- ========== VERIFICATION ==========
PROMPT 
PROMPT ============================================
PROMPT VERIFYING TABLE CREATION...
PROMPT ============================================

SELECT 
    table_name,
    '✅ CREATED' as status,
    (SELECT COUNT(*) FROM user_constraints c 
     WHERE c.table_name = t.table_name AND c.constraint_type = 'P') as has_pk
FROM user_tables t
WHERE table_name IN (
    'CUSTOMERS', 'CATEGORIES', 'SUPPLIERS', 'PRODUCTS', 'EMPLOYEES',
    'ORDERS', 'ORDER_ITEMS', 'PAYMENTS', 'SHIPMENTS', 
    'PROMOTIONS', 'AUDIT_LOG', 'HOLIDAYS'
)
ORDER BY table_name;

PROMPT 
PROMPT ============================================
PROMPT ALL TABLES CREATED SUCCESSFULLY!
PROMPT Next: Run 02_create_indexes.sql
PROMPT ============================================
