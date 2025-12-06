-- ============================================
-- COMPREHENSIVE TEST FOR PHASE VI
-- ============================================

SET SERVEROUTPUT ON
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    -- Test variables
    v_order_id      NUMBER;
    v_error_msg     VARCHAR2(4000);
    v_success       BOOLEAN;
    v_message       VARCHAR2(4000);
    v_revenue       NUMBER;
    v_order_count   NUMBER;
    v_avg_order_val NUMBER;
    v_top_product   VARCHAR2(100);
    v_top_customer  VARCHAR2(100);
    v_invoice_text  CLOB;
    v_refund_amount NUMBER;
    v_return_id     NUMBER;
    v_clv           NUMBER;
    v_credit_check  VARCHAR2(4000);
    v_profit_margin NUMBER;
    v_sales_pred    NUMBER;
    
    -- Cursor variables
    v_cursor        SYS_REFCURSOR;
    v_product_id    NUMBER;
    v_product_name  VARCHAR2(100);
    v_units_sold    NUMBER;
    v_product_revenue NUMBER;
    
    -- Package test variables
    v_sales_report  sales_analytics_pkg.t_sales_report;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('COMPREHENSIVE PHASE VI TEST');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Create test data if needed
    DECLARE
        v_test_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_test_count FROM orders WHERE customer_id = 1001;
        IF v_test_count < 3 THEN
            DBMS_OUTPUT.PUT_LINE('Creating test orders...');
            
            -- Create multiple test orders
            FOR i IN 1..3 LOOP
                DECLARE
                    v_ids SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1, 2, 3);
                    v_qty SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(i, i*2, 1);
                BEGIN
                    proc_create_order(
                        p_customer_id => 1001,
                        p_product_ids => v_ids,
                        p_quantities => v_qty,
                        p_shipping_addr => 'Test Address ' || i,
                        p_order_id => v_order_id,
                        p_error_msg => v_error_msg
                    );
                    
                    IF v_error_msg = 'SUCCESS' THEN
                        -- Update some orders to different statuses
                        IF i = 1 THEN
                            UPDATE orders SET status = 'DELIVERED' WHERE order_id = v_order_id;
                        ELSIF i = 2 THEN
                            UPDATE orders SET status = 'SHIPPED' WHERE order_id = v_order_id;
                        END IF;
                    END IF;
                END;
            END LOOP;
            COMMIT;
        END IF;
    END;
    
    -- Test 1: Test all procedures
    DBMS_OUTPUT.PUT_LINE('=== TEST 1: ALL PROCEDURES ===');
    
    -- Get latest order
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    DBMS_OUTPUT.PUT_LINE('Testing with order: ' || v_order_id);
    
    -- Test PROC_UPDATE_ORDER_STATUS
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('1. Testing PROC_UPDATE_ORDER_STATUS:');
    proc_update_order_status(
        p_order_id => v_order_id,
        p_new_status => 'PROCESSING',
        p_success => v_success,
        p_message => v_message
    );
    DBMS_OUTPUT.PUT_LINE('   Result: ' || v_message);
    
    -- Test PROC_CALCULATE_DAILY_REVENUE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. Testing PROC_CALCULATE_DAILY_REVENUE:');
    proc_calculate_daily_revenue_simple(
        p_report_date => SYSDATE,
        p_revenue => v_revenue,
        p_order_count => v_order_count,
        p_avg_order_val => v_avg_order_val,
        p_top_product => v_top_product,
        p_top_customer => v_top_customer,
        p_message => v_message
    );
    DBMS_OUTPUT.PUT_LINE('   Result: ' || v_message);
    DBMS_OUTPUT.PUT_LINE('   Revenue: $' || v_revenue);
    
    -- Test PROC_GENERATE_INVOICE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. Testing PROC_GENERATE_INVOICE:');
    proc_generate_invoice(
        p_order_id => v_order_id,
        p_success => v_success,
        p_message => v_message,
        p_invoice_text => v_invoice_text
    );
    DBMS_OUTPUT.PUT_LINE('   Result: ' || v_message);
    
    -- Test PROC_PROCESS_RETURN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('4. Testing PROC_PROCESS_RETURN:');
    proc_process_return(
        p_order_id => v_order_id,
        p_product_id => 2,
        p_return_quantity => 1,
        p_return_reason => 'Test return',
        p_refund_amount => v_refund_amount,
        p_return_id => v_return_id,
        p_success => v_success,
        p_message => v_message
    );
    DBMS_OUTPUT.PUT_LINE('   Result: ' || v_message);
    
    -- Test 2: Test all functions
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST 2: ALL FUNCTIONS ===');
    
    -- Test customer lifetime value
    v_clv := fn_calculate_customer_lifetime_value(1001);
    DBMS_OUTPUT.PUT_LINE('1. Customer Lifetime Value: $' || v_clv);
    
    -- Test credit validation
    v_credit_check := fn_validate_credit_limit(1001, 500);
    DBMS_OUTPUT.PUT_LINE('2. Credit Check: ' || v_credit_check);
    
    -- Test profit margin
    v_profit_margin := fn_get_product_profit_margin(1);
    DBMS_OUTPUT.PUT_LINE('3. Product Profit Margin: ' || v_profit_margin || '%');
    
    -- Test sales prediction
    v_sales_pred := fn_predict_sales_trend(1);
    DBMS_OUTPUT.PUT_LINE('4. Next Month Sales Prediction: $' || v_sales_pred);
    
    -- Test top selling products function
    DBMS_OUTPUT.PUT_LINE('5. Top Selling Products:');
    v_cursor := fn_get_top_selling_products(5, 6);
    LOOP
        FETCH v_cursor INTO v_product_id, v_product_name, v_order_id, 
                            v_units_sold, v_product_revenue, v_profit_margin, v_order_count;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('   - ' || v_product_name || ': ' || v_units_sold || ' units, $' || v_product_revenue);
    END LOOP;
    CLOSE v_cursor;
    
    -- Test 3: Test package
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST 3: SALES ANALYTICS PACKAGE ===');
    
    -- Test package procedures
    sales_analytics_pkg.generate_sales_report(
        p_start_date => SYSDATE - 30,
        p_end_date => SYSDATE,
        p_report_out => v_sales_report
    );
    
    DBMS_OUTPUT.PUT_LINE('1. Sales Report:');
    DBMS_OUTPUT.PUT_LINE('   Period: ' || TO_CHAR(v_sales_report.period_start, 'YYYY-MM-DD') || 
                       ' to ' || TO_CHAR(v_sales_report.period_end, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('   Revenue: $' || v_sales_report.total_revenue);
    DBMS_OUTPUT.PUT_LINE('   Orders: ' || v_sales_report.total_orders);
    DBMS_OUTPUT.PUT_LINE('   Top Product: ' || v_sales_report.top_product);
    
    -- Test YoY growth
    DBMS_OUTPUT.PUT_LINE('2. Year-over-Year Growth: ' || 
                         sales_analytics_pkg.calculate_yoy_growth() || '%');
    
    -- Test update customer segments
    DBMS_OUTPUT.PUT_LINE('3. Updating customer segments...');
    sales_analytics_pkg.update_customer_segments;
    
    -- Test performance report
    DBMS_OUTPUT.PUT_LINE('4. Generating performance report:');
    sales_analytics_pkg.generate_performance_report('SUMMARY');
    
    -- Test 4: Window Functions Examples
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST 4: WINDOW FUNCTIONS ===');
    
    DBMS_OUTPUT.PUT_LINE('1. Customer Ranking by Total Spent:');
    FOR r IN (
        SELECT 
            c.customer_id,
            c.customer_name,
            SUM(o.net_amount) AS total_spent,
            RANK() OVER (ORDER BY SUM(o.net_amount) DESC) AS customer_rank,
            ROUND((SUM(o.net_amount) / SUM(SUM(o.net_amount)) OVER ()) * 100, 2) AS percent_of_total
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.status NOT IN ('CANCELLED', 'RETURNED')
        GROUP BY c.customer_id, c.customer_name
        ORDER BY total_spent DESC
        FETCH FIRST 5 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('   Rank ' || r.customer_rank || ': ' || 
                           r.customer_name || ' - $' || r.total_spent || 
                           ' (' || r.percent_of_total || '%)');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. Monthly Sales with Moving Average:');
    FOR r IN (
        SELECT 
            TO_CHAR(order_date, 'YYYY-MM') AS month,
            SUM(net_amount) AS monthly_sales,
            AVG(SUM(net_amount)) OVER (
                ORDER BY TO_CHAR(order_date, 'YYYY-MM')
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ) AS three_month_moving_avg,
            LAG(SUM(net_amount)) OVER (ORDER BY TO_CHAR(order_date, 'YYYY-MM')) AS prev_month_sales
        FROM orders
        WHERE status NOT IN ('CANCELLED', 'RETURNED')
          AND order_date >= ADD_MONTHS(SYSDATE, -12)
        GROUP BY TO_CHAR(order_date, 'YYYY-MM')
        ORDER BY month DESC
        FETCH FIRST 6 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('   ' || r.month || ': $' || r.monthly_sales || 
                           ' | Moving Avg: $' || ROUND(NVL(r.three_month_moving_avg, 0), 2) ||
                           ' | Prev: $' || NVL(r.prev_month_sales, 0));
    END LOOP;
    
    -- Test 5: Cursor Example
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST 5: EXPLICIT CURSOR ===');
    
    DECLARE
        CURSOR c_customer_orders IS
            SELECT 
                c.customer_name,
                o.order_id,
                o.order_date,
                o.total_amount,
                o.status,
                COUNT(oi.order_item_id) AS item_count
            FROM customers c
            JOIN orders o ON c.customer_id = o.customer_id
            LEFT JOIN order_items oi ON o.order_id = oi.order_id
            WHERE c.customer_id = 1001
            GROUP BY c.customer_name, o.order_id, o.order_date, o.total_amount, o.status
            ORDER BY o.order_date DESC;
        
        v_customer_name VARCHAR2(100);
        v_order_date    DATE;
        v_total_amount  NUMBER;
        v_status        VARCHAR2(20);
        v_item_count    NUMBER;
    BEGIN
        OPEN c_customer_orders;
        DBMS_OUTPUT.PUT_LINE('Customer Order History:');
        LOOP
            FETCH c_customer_orders INTO v_customer_name, v_order_id, v_order_date, 
                                        v_total_amount, v_status, v_item_count;
            EXIT WHEN c_customer_orders%NOTFOUND;
            
            DBMS_OUTPUT.PUT_LINE('   Order ' || v_order_id || ': ' || 
                               TO_CHAR(v_order_date, 'YYYY-MM-DD') || 
                               ', $' || v_total_amount || 
                               ', ' || v_status || 
                               ', ' || v_item_count || ' items');
        END LOOP;
        CLOSE c_customer_orders;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VI TEST COMPLETED SUCCESSFULLY!');
    DBMS_OUTPUT.PUT_LINE('============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Test Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
END;
/
