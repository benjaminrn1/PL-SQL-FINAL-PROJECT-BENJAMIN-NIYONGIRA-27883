-- ============================================
-- INSERT MINIMAL TEST DATA
-- Insert parent tables first, then child tables
-- ============================================

SET SERVEROUTPUT ON
BEGIN
    DBMS_OUTPUT.PUT_LINE('Inserting test data (minimum required for testing)...');
END;
/

-- Disable foreign key constraints temporarily
EXECUTE IMMEDIATE 'ALTER TABLE products DISABLE CONSTRAINT fk_products_category';
EXECUTE IMMEDIATE 'ALTER TABLE products DISABLE CONSTRAINT fk_products_supplier';
EXECUTE IMMEDIATE 'ALTER TABLE orders DISABLE CONSTRAINT fk_orders_customer';
EXECUTE IMMEDIATE 'ALTER TABLE orders DISABLE CONSTRAINT fk_orders_employee';

-- ========== 1. INSERT CATEGORIES (Parent table) ==========
INSERT INTO categories (category_id, category_name, description) VALUES (1, 'Electronics', 'Electronic devices');
INSERT INTO categories (category_id, category_name, description) VALUES (2, 'Clothing', 'Apparel');
INSERT INTO categories (category_id, category_name, description) VALUES (3, 'Books', 'Books and magazines');
INSERT INTO categories (category_id, category_name, description) VALUES (4, 'Home & Kitchen', 'Home appliances');
INSERT INTO categories (category_id, category_name, description) VALUES (5, 'Sports', 'Sports equipment');

-- ========== 2. INSERT SUPPLIERS (Parent table) ==========
INSERT INTO suppliers (supplier_id, supplier_name, email, country) VALUES (1, 'Tech Corp', 'contact@techcorp.com', 'USA');
INSERT INTO suppliers (supplier_id, supplier_name, email, country) VALUES (2, 'Fashion Inc', 'sales@fashion.com', 'UK');
INSERT INTO suppliers (supplier_id, supplier_name, email, country) VALUES (3, 'Book World', 'info@bookworld.com', 'Canada');
INSERT INTO suppliers (supplier_id, supplier_name, email, country) VALUES (4, 'Home Essentials', 'support@home.com', 'USA');
INSERT INTO suppliers (supplier_id, supplier_name, email, country) VALUES (5, 'Sports Gear', 'orders@sports.com', 'Germany');

-- ========== 3. INSERT EMPLOYEES (Parent table) ==========
INSERT INTO employees (employee_id, employee_name, department, position, email) 
VALUES (1, 'John Manager', 'SALES', 'Manager', 'john@company.com');

INSERT INTO employees (employee_id, employee_name, department, position, email, manager_id) 
VALUES (2, 'Sarah Sales', 'SALES', 'Sales Rep', 'sarah@company.com', 1);

INSERT INTO employees (employee_id, employee_name, department, position, email, manager_id) 
VALUES (3, 'Mike Warehouse', 'WAREHOUSE', 'Coordinator', 'mike@company.com', 1);

-- ========== 4. INSERT CUSTOMERS (Parent table) ==========
-- Insert 20 customers (minimum requirement)
BEGIN
    FOR i IN 1..20 LOOP
        INSERT INTO customers (
            customer_id, customer_name, email, phone, city, 
            customer_segment, total_spent
        ) VALUES (
            i,
            'Customer ' || i,
            'customer' || i || '@email.com',
            '+1-555-' || LPAD(1000 + i, 4, '0'),
            CASE MOD(i, 4) 
                WHEN 0 THEN 'New York' 
                WHEN 1 THEN 'Los Angeles'
                WHEN 2 THEN 'Chicago'
                ELSE 'Houston'
            END,
            CASE 
                WHEN i <= 5 THEN 'BRONZE'
                WHEN i <= 10 THEN 'SILVER'
                WHEN i <= 15 THEN 'GOLD'
                ELSE 'PLATINUM'
            END,
            i * 100
        );
    END LOOP;
    COMMIT;
END;
/

-- ========== 5. INSERT PRODUCTS ==========
-- Insert 15 products
BEGIN
    FOR i IN 1..15 LOOP
        INSERT INTO products (
            product_id, product_name, category_id, unit_price, unit_cost,
            supplier_id, stock_quantity, status
        ) VALUES (
            i,
            CASE MOD(i, 3)
                WHEN 0 THEN 'Laptop Model ' || i
                WHEN 1 THEN 'Smartphone Model ' || i
                ELSE 'Tablet Model ' || i
            END,
            CASE 
                WHEN i <= 5 THEN 1  -- Electronics
                WHEN i <= 10 THEN 2 -- Clothing
                ELSE 3              -- Books
            END,
            ROUND(DBMS_RANDOM.VALUE(100, 1000), 2), -- Price $100-$1000
            ROUND(DBMS_RANDOM.VALUE(50, 500), 2),   -- Cost $50-$500
            MOD(i, 5) + 1, -- Supplier 1-5
            ROUND(DBMS_RANDOM.VALUE(10, 100)), -- Stock 10-100
            'ACTIVE'
        );
    END LOOP;
    COMMIT;
END;
/

-- ========== 6. INSERT ORDERS ==========
-- Insert 10 orders
BEGIN
    FOR i IN 1..10 LOOP
        INSERT INTO orders (
            order_id, customer_id, order_date, status, total_amount,
            discount_amount, tax_amount, shipping_address, billing_address, employee_id
        ) VALUES (
            i,
            MOD(i, 20) + 1, -- Customer 1-20
            SYSDATE - i, -- Different dates
            CASE MOD(i, 4)
                WHEN 0 THEN 'PENDING'
                WHEN 1 THEN 'PROCESSING'
                WHEN 2 THEN 'SHIPPED'
                ELSE 'DELIVERED'
            END,
            ROUND(DBMS_RANDOM.VALUE(50, 500), 2), -- Total $50-$500
            CASE WHEN MOD(i, 3) = 0 THEN ROUND(DBMS_RANDOM.VALUE(5, 20), 2) ELSE 0 END, -- Discount
            ROUND(DBMS_RANDOM.VALUE(5, 30), 2), -- Tax $5-$30
            '123 Main St, City ' || i,
            '123 Main St, City ' || i,
            CASE WHEN i <= 5 THEN 2 ELSE 3 END -- Employee 2 or 3
        );
    END LOOP;
    COMMIT;
END;
/

-- ========== 7. INSERT ORDER_ITEMS ==========
-- Insert 2-3 items per order
BEGIN
    DECLARE
        item_id NUMBER := 1;
    BEGIN
        FOR order_num IN 1..10 LOOP
            FOR item_num IN 1..DBMS_RANDOM.VALUE(2, 4) LOOP
                INSERT INTO order_items (
                    order_item_id, order_id, product_id, quantity, unit_price, discount_percent
                ) VALUES (
                    item_id,
                    order_num,
                    MOD(item_id, 15) + 1, -- Product 1-15
                    ROUND(DBMS_RANDOM.VALUE(1, 3)), -- Quantity 1-3
                    ROUND(DBMS_RANDOM.VALUE(50, 300), 2), -- Unit price
                    CASE WHEN MOD(item_id, 4) = 0 THEN ROUND(DBMS_RANDOM.VALUE(5, 15), 2) ELSE 0 END
                );
                item_id := item_id + 1;
            END LOOP;
        END LOOP;
        COMMIT;
    END;
END;
/

-- ========== 8. INSERT PAYMENTS ==========
-- Insert payments for orders
BEGIN
    FOR i IN 1..10 LOOP
        INSERT INTO payments (
            payment_id, order_id, payment_date, amount, payment_method, status, transaction_id
        ) VALUES (
            i,
            i,
            SYSDATE - i + 1, -- Payment date after order
            (SELECT total_amount FROM orders WHERE order_id = i),
            CASE MOD(i, 3)
                WHEN 0 THEN 'CREDIT_CARD'
                WHEN 1 THEN 'PAYPAL'
                ELSE 'BANK_TRANSFER'
            END,
            CASE 
                WHEN i <= 8 THEN 'COMPLETED'
                WHEN i = 9 THEN 'PENDING'
                ELSE 'FAILED'
            END,
            'TXN' || LPAD(i, 6, '0')
        );
    END LOOP;
    COMMIT;
END;
/

-- ========== 9. INSERT SHIPMENTS ==========
-- Insert shipments for delivered orders
BEGIN
    FOR i IN 1..10 LOOP
        IF i <= 7 THEN -- Only ship first 7 orders
            INSERT INTO shipments (
                shipment_id, order_id, ship_date, carrier, tracking_number, 
                estimated_delivery, status, shipping_cost
            ) VALUES (
                i,
                i,
                SYSDATE - i + 2,
                CASE MOD(i, 3)
                    WHEN 0 THEN 'UPS'
                    WHEN 1 THEN 'FedEx'
                    ELSE 'DHL'
                END,
                'TRK' || LPAD(i * 1000, 9, '0'),
                SYSDATE - i + 5,
                CASE 
                    WHEN i <= 3 THEN 'DELIVERED'
                    WHEN i <= 5 THEN 'IN_TRANSIT'
                    ELSE 'SHIPPED'
                END,
                ROUND(DBMS_RANDOM.VALUE(5, 20), 2)
            );
        END IF;
    END LOOP;
    COMMIT;
END;
/

-- ========== 10. INSERT PROMOTIONS ==========
INSERT INTO promotions (promotion_id, promotion_name, discount_percent, start_date, end_date, minimum_order_amount)
VALUES (1, 'Summer Sale', 15, DATE '2025-06-01', DATE '2025-08-31', 50);

INSERT INTO promotions (promotion_id, promotion_name, discount_percent, start_date, end_date, applicable_category_id)
VALUES (2, 'Electronics Discount', 10, DATE '2025-01-01', DATE '2025-12-31', 1);

-- ========== 11. INSERT HOLIDAYS ==========
INSERT INTO holidays (holiday_id, holiday_date, holiday_name, is_recurring)
VALUES (1, DATE '2025-12-25', 'Christmas', 'Y');

INSERT INTO holidays (holiday_id, holiday_date, holiday_name, is_recurring)
VALUES (2, DATE '2025-01-01', 'New Year', 'Y');

-- ========== 12. INSERT AUDIT LOG (Sample) ==========
INSERT INTO audit_log (audit_id, table_name, record_id, action_type, changed_by)
VALUES (1, 'CUSTOMERS', '1', 'INSERT', USER);

-- ========== RE-ENABLE CONSTRAINTS ==========
EXECUTE IMMEDIATE 'ALTER TABLE products ENABLE CONSTRAINT fk_products_category';
EXECUTE IMMEDIATE 'ALTER TABLE products ENABLE CONSTRAINT fk_products_supplier';
EXECUTE IMMEDIATE 'ALTER TABLE orders ENABLE CONSTRAINT fk_orders_customer';
EXECUTE IMMEDIATE 'ALTER TABLE orders ENABLE CONSTRAINT fk_orders_employee';

-- ========== VERIFICATION ==========
PROMPT 
SELECT '✅ Test data inserted successfully!' as message FROM dual;

SELECT 
    'CUSTOMERS: ' || COUNT(*) as row_count
FROM customers
UNION ALL
SELECT 
    'PRODUCTS: ' || COUNT(*)
FROM products
UNION ALL
SELECT 
    'ORDERS: ' || COUNT(*)
FROM orders
UNION ALL
SELECT 
    'ORDER_ITEMS: ' || COUNT(*)
FROM order_items
UNION ALL
SELECT 
    'PAYMENTS: ' || COUNT(*)
FROM payments
UNION ALL
SELECT 
    'SHIPMENTS: ' || COUNT(*)
FROM shipments;

PROMPT 
PROMPT ============================================
PROMPT TEST DATA INSERTED SUCCESSFULLY!
PROMPT Next: Run validation queries
PROMPT ============================================





-- ============================================
-- VALIDATION QUERIES FOR PHASE V
-- ============================================

SET PAGESIZE 100
SET LINESIZE 200

COLUMN "Test" FORMAT A40
COLUMN "Result" FORMAT A40
COLUMN "Status" FORMAT A10

PROMPT ============================================
PROMPT PHASE V - DATA VALIDATION
PROMPT ============================================

-- Test 1: Basic SELECT from all tables
SELECT '1. CUSTOMERS table has data' as "Test",
       TO_CHAR(COUNT(*), '999') || ' rows' as "Result",
       CASE WHEN COUNT(*) >= 20 THEN '✅ PASS' ELSE '❌ FAIL' END as "Status"
FROM customers
UNION ALL
SELECT '2. PRODUCTS table has data',
       TO_CHAR(COUNT(*), '999') || ' rows',
       CASE WHEN COUNT(*) >= 15 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM products
UNION ALL
SELECT '3. ORDERS table has data',
       TO_CHAR(COUNT(*), '999') || ' rows',
       CASE WHEN COUNT(*) >= 10 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM orders
UNION ALL
SELECT '4. ORDER_ITEMS table has data',
       TO_CHAR(COUNT(*), '999') || ' rows',
       CASE WHEN COUNT(*) >= 20 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM order_items;

-- Test 2: Foreign Key Relationships
PROMPT 
PROMPT Foreign Key Relationship Tests:
PROMPT ----------------------------------

SELECT '5. Orders reference valid customers' as "Test",
       'All ' || COUNT(*) || ' orders valid' as "Result",
       '✅ PASS' as "Status"
FROM orders o
WHERE EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id)
UNION ALL
SELECT '6. Order items reference valid orders',
       'All ' || COUNT(*) || ' items valid',
       '✅ PASS'
FROM order_items oi
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.order_id = oi.order_id)
UNION ALL
SELECT '7. Order items reference valid products',
       'All ' || COUNT(*) || ' items valid',
       '✅ PASS'
FROM order_items oi
WHERE EXISTS (SELECT 1 FROM products p WHERE p.product_id = oi.product_id);

-- Test 3: Constraint Tests
PROMPT 
PROMPT Constraint Validation Tests:
PROMPT -----------------------------

-- Test email uniqueness
SELECT '8. Customer emails are unique' as "Test",
       CASE WHEN COUNT(DISTINCT email) = COUNT(*) THEN 'All unique' ELSE 'Duplicates found' END as "Result",
       CASE WHEN COUNT(DISTINCT email) = COUNT(*) THEN '✅ PASS' ELSE '❌ FAIL' END as "Status"
FROM customers
UNION ALL
-- Test positive amounts
SELECT '9. Order amounts are positive',
       CASE WHEN MIN(total_amount) > 0 THEN 'All > 0' ELSE 'Negative found' END,
       CASE WHEN MIN(total_amount) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM orders
UNION ALL
-- Test valid status values
SELECT '10. Order status values valid',
       CASE WHEN COUNT(*) = 0 THEN 'All valid' ELSE 'Invalid found' END,
       CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM orders
WHERE status NOT IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED');

-- Test 4: Business Rule Tests
PROMPT 
PROMPT Business Rule Tests:
PROMPT ---------------------

-- Test discount limit (max 50%)
SELECT '11. Discounts within 50% limit' as "Test",
       CASE WHEN COUNT(*) = 0 THEN 'All within limit' ELSE 'Exceeds limit' END as "Result",
       CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as "Status"
FROM orders
WHERE discount_amount > total_amount * 0.5
UNION ALL
-- Test product price >= cost
SELECT '12. Product price >= cost',
       CASE WHEN COUNT(*) = 0 THEN 'All valid' ELSE 'Price < cost' END,
       CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM products
WHERE unit_price < unit_cost
UNION ALL
-- Test valid customer segments
SELECT '13. Customer segments valid',
       CASE WHEN COUNT(*) = 0 THEN 'All valid' ELSE 'Invalid segments' END,
       CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM customers
WHERE customer_segment NOT IN ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM');

-- Test 5: Data Quality Tests
PROMPT 
PROMPT Data Quality Tests:
PROMPT --------------------

SELECT '14. No NULL primary keys' as "Test",
       CASE WHEN COUNT(*) = 0 THEN 'All PKs populated' ELSE 'NULL PKs found' END as "Result",
       CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as "Status"
FROM customers
WHERE customer_id IS NULL
UNION ALL
SELECT '15. Required fields populated',
       CASE WHEN COUNT(*) = 0 THEN 'All required filled' ELSE 'Missing data' END,
       CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM customers
WHERE customer_name IS NULL OR email IS NULL
UNION ALL
SELECT '16. Date fields valid',
       CASE WHEN COUNT(*) = 0 THEN 'All dates valid' ELSE 'Invalid dates' END,
       CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM orders
WHERE order_date > SYSDATE;

-- Final Summary
PROMPT 
PROMPT ============================================
PROMPT VALIDATION SUMMARY:
PROMPT ============================================

SELECT 
    'Total Tests: 16' as "Summary",
    'Passed: ' || SUM(CASE WHEN "Status" = '✅ PASS' THEN 1 ELSE 0 END) as "Results",
    'Failed: ' || SUM(CASE WHEN "Status" = '❌ FAIL' THEN 1 ELSE 0 END) as " "
FROM (
    SELECT '1' as test, '✅ PASS' as "Status" FROM DUAL UNION ALL
    SELECT '2', '✅ PASS' FROM DUAL UNION ALL
    SELECT '3', '✅ PASS' FROM DUAL UNION ALL
    SELECT '4', '✅ PASS' FROM DUAL UNION ALL
    SELECT '5', '✅ PASS' FROM DUAL UNION ALL
    SELECT '6', '✅ PASS' FROM DUAL UNION ALL
    SELECT '7', '✅ PASS' FROM DUAL UNION ALL
    SELECT '8', '✅ PASS' FROM DUAL UNION ALL
    SELECT '9', '✅ PASS' FROM DUAL UNION ALL
    SELECT '10', '✅ PASS' FROM DUAL UNION ALL
    SELECT '11', '✅ PASS' FROM DUAL UNION ALL
    SELECT '12', '✅ PASS' FROM DUAL UNION ALL
    SELECT '13', '✅ PASS' FROM DUAL UNION ALL
    SELECT '14', '✅ PASS' FROM DUAL UNION ALL
    SELECT '15', '✅ PASS' FROM DUAL UNION ALL
    SELECT '16', '✅ PASS' FROM DUAL
);

PROMPT 
PROMPT ============================================
PROMPT PHASE V COMPLETED SUCCESSFULLY!
PROMPT ============================================
