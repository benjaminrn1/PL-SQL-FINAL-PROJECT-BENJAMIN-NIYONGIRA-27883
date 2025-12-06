-- ============================================
-- SIMPLIFIED PROC_CALCULATE_DAILY_REVENUE --
-- ============================================

CREATE OR REPLACE PROCEDURE proc_calculate_daily_revenue_simple(
    p_report_date   IN DATE DEFAULT TRUNC(SYSDATE),
    p_show_details  IN BOOLEAN DEFAULT FALSE,
    p_revenue       OUT NUMBER,
    p_order_count   OUT NUMBER,
    p_avg_order_val OUT NUMBER,
    p_top_product   OUT VARCHAR2,
    p_top_customer  OUT VARCHAR2,
    p_message       OUT VARCHAR2
)
IS
    v_total_revenue    NUMBER := 0;
    v_total_orders     NUMBER := 0;
    v_avg_order_value  NUMBER := 0;
    v_max_order_value  NUMBER := 0;
    v_min_order_value  NUMBER := 0;
    v_cancelled_orders NUMBER := 0;
    v_returned_orders  NUMBER := 0;
    v_completed_orders NUMBER := 0;
    v_completion_rate  NUMBER := 0;
    v_revenue_biz_hours NUMBER := 0;
    
    -- Simple query results
    TYPE t_hourly_rec IS RECORD (
        hour_of_day     NUMBER,
        order_count     NUMBER,
        hourly_revenue  NUMBER,
        avg_order_value NUMBER
    );
    
    TYPE t_hourly_table IS TABLE OF t_hourly_rec;
    v_hourly_data t_hourly_table;
    
BEGIN
    -- Initialize outputs
    p_revenue := 0;
    p_order_count := 0;
    p_avg_order_val := 0;
    p_top_product := 'N/A';
    p_top_customer := 'N/A';
    p_message := NULL;
    
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('DAILY REVENUE REPORT');
    DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(p_report_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('============================================');
    
    -- Calculate basic metrics using simple queries
    -- 1. Basic revenue metrics
    BEGIN
        SELECT 
            NVL(SUM(CASE WHEN status NOT IN ('CANCELLED', 'RETURNED') THEN net_amount ELSE 0 END), 0),
            COUNT(*),
            NVL(AVG(CASE WHEN status NOT IN ('CANCELLED', 'RETURNED') THEN net_amount END), 0),
            NVL(MAX(CASE WHEN status NOT IN ('CANCELLED', 'RETURNED') THEN net_amount END), 0),
            NVL(MIN(CASE WHEN status NOT IN ('CANCELLED', 'RETURNED') THEN net_amount END), 0),
            COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END),
            COUNT(CASE WHEN status = 'RETURNED' THEN 1 END)
        INTO 
            v_total_revenue,
            v_total_orders,
            v_avg_order_value,
            v_max_order_value,
            v_min_order_value,
            v_cancelled_orders,
            v_returned_orders
        FROM orders
        WHERE TRUNC(order_date) = TRUNC(p_report_date);
        
        p_revenue := v_total_revenue;
        p_order_count := v_total_orders;
        p_avg_order_val := v_avg_order_value;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_message := 'No orders found for date: ' || TO_CHAR(p_report_date, 'YYYY-MM-DD');
            RETURN;
    END;
    
    -- 2. Get top product
    BEGIN
        SELECT product_name INTO p_top_product
        FROM (
            SELECT p.product_name
            FROM order_items oi
            JOIN products p ON oi.product_id = p.product_id
            JOIN orders o ON oi.order_id = o.order_id
            WHERE TRUNC(o.order_date) = TRUNC(p_report_date)
              AND o.status NOT IN ('CANCELLED', 'RETURNED')
            GROUP BY p.product_name
            ORDER BY SUM(oi.quantity) DESC
        ) WHERE ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_top_product := 'No products sold';
    END;
    
    -- 3. Get top customer
    BEGIN
        SELECT customer_name INTO p_top_customer
        FROM (
            SELECT c.customer_name
            FROM orders o
            JOIN customers c ON o.customer_id = c.customer_id
            WHERE TRUNC(o.order_date) = TRUNC(p_report_date)
              AND o.status NOT IN ('CANCELLED', 'RETURNED')
            GROUP BY c.customer_name
            ORDER BY SUM(o.net_amount) DESC
        ) WHERE ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_top_customer := 'No customers';
    END;
    
    -- Display summary
    DBMS_OUTPUT.PUT_LINE('SUMMARY METRICS:');
    DBMS_OUTPUT.PUT_LINE('----------------');
    DBMS_OUTPUT.PUT_LINE('Total Revenue:      $' || TO_CHAR(p_revenue, 'FM999,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('Total Orders:       ' || p_order_count);
    DBMS_OUTPUT.PUT_LINE('Avg Order Value:    $' || TO_CHAR(p_avg_order_val, 'FM999,999.99'));
    DBMS_OUTPUT.PUT_LINE('Max Order Value:    $' || TO_CHAR(v_max_order_value, 'FM999,999.99'));
    DBMS_OUTPUT.PUT_LINE('Min Order Value:    $' || TO_CHAR(v_min_order_value, 'FM999,999.99'));
    DBMS_OUTPUT.PUT_LINE('Cancelled Orders:   ' || v_cancelled_orders);
    DBMS_OUTPUT.PUT_LINE('Returned Orders:    ' || v_returned_orders);
    DBMS_OUTPUT.PUT_LINE('Top Product:        ' || p_top_product);
    DBMS_OUTPUT.PUT_LINE('Top Customer:       ' || p_top_customer);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 4. Get hourly data using BULK COLLECT
    SELECT 
        TO_NUMBER(TO_CHAR(order_date, 'HH24')),
        COUNT(*),
        SUM(net_amount),
        ROUND(AVG(net_amount), 2)
    BULK COLLECT INTO v_hourly_data
    FROM orders
    WHERE TRUNC(order_date) = TRUNC(p_report_date)
      AND status NOT IN ('CANCELLED', 'RETURNED')
    GROUP BY TO_CHAR(order_date, 'HH24')
    ORDER BY 1;
    
    -- Display hourly breakdown
    IF v_hourly_data.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('HOURLY BREAKDOWN:');
        DBMS_OUTPUT.PUT_LINE('-----------------');
        DBMS_OUTPUT.PUT_LINE('Hour  Orders  Revenue      Avg Order');
        DBMS_OUTPUT.PUT_LINE('----  ------  -----------  ----------');
        
        FOR i IN 1..v_hourly_data.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(
                LPAD(v_hourly_data(i).hour_of_day, 4) || '  ' ||
                LPAD(v_hourly_data(i).order_count, 6) || '  ' ||
                LPAD('$' || TO_CHAR(v_hourly_data(i).hourly_revenue, 'FM999,999.99'), 11) || '  ' ||
                LPAD('$' || TO_CHAR(v_hourly_data(i).avg_order_value, 'FM999.99'), 10)
            );
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No hourly data available.');
    END IF;
    
    -- 5. Additional metrics
    BEGIN
        -- Completion rate
        SELECT COUNT(*) INTO v_completed_orders
        FROM orders
        WHERE TRUNC(order_date) = TRUNC(p_report_date)
          AND status IN ('DELIVERED', 'SHIPPED');
        
        IF p_order_count > 0 THEN
            v_completion_rate := ROUND((v_completed_orders / p_order_count) * 100, 2);
        END IF;
        
        -- Business hours revenue
        SELECT NVL(SUM(net_amount), 0) INTO v_revenue_biz_hours
        FROM orders
        WHERE TRUNC(order_date) = TRUNC(p_report_date)
          AND status NOT IN ('CANCELLED', 'RETURNED')
          AND TO_NUMBER(TO_CHAR(order_date, 'HH24')) BETWEEN 9 AND 17;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ADDITIONAL METRICS:');
        DBMS_OUTPUT.PUT_LINE('-------------------');
        DBMS_OUTPUT.PUT_LINE('Order Completion Rate:     ' || v_completion_rate || '%');
        DBMS_OUTPUT.PUT_LINE('Business Hours Revenue:    $' || TO_CHAR(v_revenue_biz_hours, 'FM999,999.99'));
        DBMS_OUTPUT.PUT_LINE('Avg Revenue per Hour:      $' || 
            TO_CHAR(CASE WHEN p_order_count > 0 THEN p_revenue / 24 ELSE 0 END, 'FM999,999.99'));
        
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Ignore errors in additional metrics
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('REPORT COMPLETED SUCCESSFULLY');
    DBMS_OUTPUT.PUT_LINE('============================================');
    
    p_message := 'Daily revenue report generated for ' || TO_CHAR(p_report_date, 'YYYY-MM-DD');
    
EXCEPTION
    WHEN OTHERS THEN
        p_message := 'Error generating report: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
END proc_calculate_daily_revenue_simple;
/






-- ============================================
-- QUICK TEST FOR SIMPLE VERSION
-- ============================================

SET SERVEROUTPUT ON

DECLARE
    v_revenue       NUMBER;
    v_order_count   NUMBER;
    v_avg_order_val NUMBER;
    v_top_product   VARCHAR2(100);
    v_top_customer  VARCHAR2(100);
    v_message       VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing simplified daily revenue procedure...');
    
    proc_calculate_daily_revenue_simple(
        p_report_date   => SYSDATE,
        p_show_details  => FALSE,
        p_revenue       => v_revenue,
        p_order_count   => v_order_count,
        p_avg_order_val => v_avg_order_val,
        p_top_product   => v_top_product,
        p_top_customer  => v_top_customer,
        p_message       => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('RESULTS:');
    DBMS_OUTPUT.PUT_LINE('--------');
    DBMS_OUTPUT.PUT_LINE('Revenue: $' || v_revenue);
    DBMS_OUTPUT.PUT_LINE('Orders: ' || v_order_count);
    DBMS_OUTPUT.PUT_LINE('Avg Order: $' || v_avg_order_val);
    DBMS_OUTPUT.PUT_LINE('Top Product: ' || v_top_product);
    DBMS_OUTPUT.PUT_LINE('Top Customer: ' || v_top_customer);
    DBMS_OUTPUT.PUT_LINE('Message: ' || v_message);
END;
/
