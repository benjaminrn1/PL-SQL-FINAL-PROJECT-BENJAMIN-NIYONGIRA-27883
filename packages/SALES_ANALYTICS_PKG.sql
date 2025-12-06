-- ============================================
-- SALES ANALYTICS PACKAGE (FIXED VERSION)
-- ============================================

CREATE OR REPLACE PACKAGE sales_analytics_pkg AS
    -- TYPE DEFINITIONS
    TYPE t_sales_report IS RECORD (
        period_start    DATE,
        period_end      DATE,
        total_revenue   NUMBER,
        total_orders    NUMBER,
        avg_order_value NUMBER,
        top_product     VARCHAR2(100),
        top_customer    VARCHAR2(100)
    );
    
    TYPE t_customer_metrics IS RECORD (
        customer_id        NUMBER,
        customer_name      VARCHAR2(100),
        lifetime_value     NUMBER,
        order_count        NUMBER,
        avg_order_value    NUMBER,
        last_order_date    DATE
    );
    
    TYPE t_product_stats IS RECORD (
        product_id        NUMBER,
        product_name      VARCHAR2(100),
        units_sold        NUMBER,
        total_revenue     NUMBER,
        profit_margin     NUMBER
    );
    
    -- CURSORS
    CURSOR c_monthly_sales(p_months_back NUMBER DEFAULT 12) IS
        SELECT 
            TRUNC(order_date, 'MM') AS month,
            COUNT(*) AS order_count,
            SUM(net_amount) AS revenue,
            AVG(net_amount) AS avg_order_value
        FROM orders
        WHERE order_date >= ADD_MONTHS(SYSDATE, -p_months_back)
          AND status NOT IN ('CANCELLED', 'RETURNED')
        GROUP BY TRUNC(order_date, 'MM')
        ORDER BY month DESC;
    
    -- PROCEDURES
    PROCEDURE generate_sales_report(
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_report_out OUT t_sales_report
    );
    
    PROCEDURE update_customer_segments;
    
    PROCEDURE analyze_product_performance(
        p_category_id IN NUMBER DEFAULT NULL,
        p_results  OUT SYS_REFCURSOR
    );
    
    -- FUNCTIONS
    FUNCTION calculate_yoy_growth RETURN NUMBER;
    
    FUNCTION get_top_performers(
        p_limit    IN NUMBER DEFAULT 10,
        p_type     IN VARCHAR2  -- 'CUSTOMERS' or 'PRODUCTS'
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION calculate_conversion_rate(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) RETURN NUMBER;
    
    -- UTILITY PROCEDURES
    PROCEDURE bulk_update_prices(
        p_category_id IN NUMBER,
        p_percentage  IN NUMBER
    );
    
    PROCEDURE generate_performance_report(
        p_report_type IN VARCHAR2 DEFAULT 'SUMMARY'
    );
    
END sales_analytics_pkg;
/

CREATE OR REPLACE PACKAGE BODY sales_analytics_pkg AS
    
    -- Generate sales report
    PROCEDURE generate_sales_report(
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_report_out OUT t_sales_report
    ) IS
    BEGIN
        -- Set report period
        p_report_out.period_start := p_start_date;
        p_report_out.period_end := p_end_date;
        
        -- Calculate basic metrics
        SELECT 
            NVL(SUM(net_amount), 0),
            NVL(COUNT(*), 0),
            NVL(AVG(net_amount), 0)
        INTO 
            p_report_out.total_revenue,
            p_report_out.total_orders,
            p_report_out.avg_order_value
        FROM orders
        WHERE order_date BETWEEN p_start_date AND p_end_date
          AND status NOT IN ('CANCELLED', 'RETURNED');
        
        -- Get top product
        BEGIN
            SELECT p.product_name
            INTO p_report_out.top_product
            FROM (
                SELECT p.product_name
                FROM order_items oi
                JOIN products p ON oi.product_id = p.product_id
                JOIN orders o ON oi.order_id = o.order_id
                WHERE o.order_date BETWEEN p_start_date AND p_end_date
                  AND o.status NOT IN ('CANCELLED', 'RETURNED')
                GROUP BY p.product_name
                ORDER BY SUM(oi.quantity) DESC
            ) p
            WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_report_out.top_product := 'N/A';
        END;
        
        -- Get top customer
        BEGIN
            SELECT c.customer_name
            INTO p_report_out.top_customer
            FROM (
                SELECT c.customer_name
                FROM orders o
                JOIN customers c ON o.customer_id = c.customer_id
                WHERE o.order_date BETWEEN p_start_date AND p_end_date
                  AND o.status NOT IN ('CANCELLED', 'RETURNED')
                GROUP BY c.customer_name
                ORDER BY SUM(o.net_amount) DESC
            ) c
            WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_report_out.top_customer := 'N/A';
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_report_out.total_revenue := 0;
            p_report_out.total_orders := 0;
            p_report_out.avg_order_value := 0;
            p_report_out.top_product := 'ERROR';
            p_report_out.top_customer := 'ERROR';
    END generate_sales_report;
    
    -- Update customer segments based on spending
    PROCEDURE update_customer_segments IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Updating customer segments...');
        
        FOR cust IN (
            SELECT c.customer_id,
                   NVL(SUM(o.net_amount), 0) AS total_spent,
                   COUNT(o.order_id) AS order_count
            FROM customers c
            LEFT JOIN orders o ON c.customer_id = o.customer_id
                AND o.status NOT IN ('CANCELLED', 'RETURNED')
            GROUP BY c.customer_id
        ) LOOP
            -- Update segment based on total spent
            UPDATE customers
            SET customer_segment = CASE
                WHEN cust.total_spent >= 10000 THEN 'PLATINUM'
                WHEN cust.total_spent >= 5000  THEN 'GOLD'
                WHEN cust.total_spent >= 1000  THEN 'SILVER'
                WHEN cust.total_spent > 0      THEN 'BRONZE'
                ELSE 'NEW'
            END,
            total_spent = cust.total_spent
            WHERE customer_id = cust.customer_id;
        END LOOP;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Customer segments updated successfully');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error updating segments: ' || SQLERRM);
            ROLLBACK;
    END update_customer_segments;
    
    -- Analyze product performance
    PROCEDURE analyze_product_performance(
        p_category_id IN NUMBER DEFAULT NULL,
        p_results  OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_results FOR
            SELECT 
                p.product_id,
                p.product_name,
                cat.category_name,
                NVL(SUM(oi.quantity), 0) AS units_sold,
                NVL(SUM(oi.quantity * oi.unit_price), 0) AS revenue,
                ROUND(NVL(AVG(fn_get_product_profit_margin(p.product_id)), 0), 2) AS profit_margin,
                RANK() OVER (ORDER BY NVL(SUM(oi.quantity), 0) DESC) AS sales_rank
            FROM products p
            LEFT JOIN categories cat ON p.category_id = cat.category_id
            LEFT JOIN order_items oi ON p.product_id = oi.product_id
            LEFT JOIN orders o ON oi.order_id = o.order_id
                AND o.status NOT IN ('CANCELLED', 'RETURNED')
            WHERE (p_category_id IS NULL OR p.category_id = p_category_id)
            GROUP BY p.product_id, p.product_name, cat.category_name
            ORDER BY units_sold DESC NULLS LAST;
    END analyze_product_performance;
    
    -- Calculate year-over-year growth
    FUNCTION calculate_yoy_growth RETURN NUMBER IS
        v_current_year_sales NUMBER;
        v_previous_year_sales NUMBER;
        v_growth_pct NUMBER;
    BEGIN
        -- Current year sales
        SELECT NVL(SUM(net_amount), 0)
        INTO v_current_year_sales
        FROM orders
        WHERE EXTRACT(YEAR FROM order_date) = EXTRACT(YEAR FROM SYSDATE)
          AND status NOT IN ('CANCELLED', 'RETURNED');
        
        -- Previous year sales
        SELECT NVL(SUM(net_amount), 0)
        INTO v_previous_year_sales
        FROM orders
        WHERE EXTRACT(YEAR FROM order_date) = EXTRACT(YEAR FROM SYSDATE) - 1
          AND status NOT IN ('CANCELLED', 'RETURNED');
        
        -- Calculate growth percentage
        IF v_previous_year_sales > 0 THEN
            v_growth_pct := ((v_current_year_sales - v_previous_year_sales) / 
                            v_previous_year_sales) * 100;
        ELSE
            v_growth_pct := 100; -- If no sales last year
        END IF;
        
        RETURN ROUND(v_growth_pct, 2);
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END calculate_yoy_growth;
    
    -- Get top performers
    FUNCTION get_top_performers(
        p_limit IN NUMBER DEFAULT 10,
        p_type  IN VARCHAR2
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        IF UPPER(p_type) = 'CUSTOMERS' THEN
            OPEN v_cursor FOR
                SELECT 
                    c.customer_id,
                    c.customer_name,
                    c.customer_segment,
                    NVL(SUM(o.net_amount), 0) AS total_spent,
                    COUNT(o.order_id) AS order_count,
                    ROUND(NVL(AVG(o.net_amount), 0), 2) AS avg_order_value
                FROM customers c
                LEFT JOIN orders o ON c.customer_id = o.customer_id
                    AND o.status NOT IN ('CANCELLED', 'RETURNED')
                GROUP BY c.customer_id, c.customer_name, c.customer_segment
                ORDER BY total_spent DESC
                FETCH FIRST p_limit ROWS ONLY;
                
        ELSIF UPPER(p_type) = 'PRODUCTS' THEN
            OPEN v_cursor FOR
                SELECT 
                    p.product_id,
                    p.product_name,
                    cat.category_name,
                    NVL(SUM(oi.quantity), 0) AS units_sold,
                    NVL(SUM(oi.quantity * oi.unit_price), 0) AS revenue,
                    ROUND(NVL(fn_get_product_profit_margin(p.product_id), 0), 2) AS profit_margin
                FROM products p
                LEFT JOIN categories cat ON p.category_id = cat.category_id
                LEFT JOIN order_items oi ON p.product_id = oi.product_id
                LEFT JOIN orders o ON oi.order_id = o.order_id
                    AND o.status NOT IN ('CANCELLED', 'RETURNED')
                GROUP BY p.product_id, p.product_name, cat.category_name, p.unit_price, p.unit_cost
                ORDER BY revenue DESC
                FETCH FIRST p_limit ROWS ONLY;
        ELSE
            -- Return empty cursor for invalid type
            OPEN v_cursor FOR 
                SELECT NULL FROM DUAL WHERE 1=0;
        END IF;
        
        RETURN v_cursor;
    END get_top_performers;
    
    -- Calculate conversion rate (simplified)
    FUNCTION calculate_conversion_rate(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) RETURN NUMBER IS
        v_total_visits   NUMBER;
        v_total_orders   NUMBER;
        v_conversion_rate NUMBER;
    BEGIN
        -- Get order count
        SELECT COUNT(*)
        INTO v_total_orders
        FROM orders
        WHERE order_date BETWEEN p_start_date AND p_end_date
          AND status NOT IN ('CANCELLED', 'RETURNED');
        
        -- Simulate visits (in real system, this would come from web analytics)
        -- Assuming each order corresponds to 10 website visits
        v_total_visits := v_total_orders * 10;
        
        -- Calculate conversion rate
        IF v_total_visits > 0 THEN
            v_conversion_rate := (v_total_orders / v_total_visits) * 100;
        ELSE
            v_conversion_rate := 0;
        END IF;
        
        RETURN ROUND(v_conversion_rate, 2);
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END calculate_conversion_rate;
    
    -- Bulk update prices
    PROCEDURE bulk_update_prices(
        p_category_id IN NUMBER,
        p_percentage  IN NUMBER
    ) IS
        v_updated_count NUMBER := 0;
        v_category_name VARCHAR2(100);
    BEGIN
        -- Get category name for logging
        BEGIN
            SELECT category_name INTO v_category_name
            FROM categories
            WHERE category_id = p_category_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_category_name := 'Unknown Category';
        END;
        
        -- Update prices for products in the specified category
        UPDATE products
        SET unit_price = unit_price * (1 + p_percentage / 100)
        WHERE category_id = p_category_id;
        
        v_updated_count := SQL%ROWCOUNT;
        
        -- Log the update
        DBMS_OUTPUT.PUT_LINE('Updated ' || v_updated_count || 
                           ' products in category: ' || v_category_name);
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error updating prices: ' || SQLERRM);
            ROLLBACK;
    END bulk_update_prices;
    
    -- Generate performance report
    PROCEDURE generate_performance_report(
        p_report_type IN VARCHAR2 DEFAULT 'SUMMARY'
    ) IS
        v_total_revenue   NUMBER;
        v_total_orders    NUMBER;
        v_avg_order_value NUMBER;
        v_yoy_growth      NUMBER;
        v_temp_customer_id  NUMBER;
        v_temp_customer_name VARCHAR2(100);
        v_temp_total_spent  NUMBER;
        v_temp_order_count  NUMBER;
        v_temp_avg_order_value NUMBER;
        v_temp_product_id    NUMBER;
        v_temp_product_name  VARCHAR2(100);
        v_temp_units_sold    NUMBER;
        v_temp_revenue       NUMBER;
        v_temp_profit_margin NUMBER;
        v_customer_cursor  SYS_REFCURSOR;
        v_product_cursor   SYS_REFCURSOR;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('============================================');
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE REPORT - ' || UPPER(p_report_type));
        DBMS_OUTPUT.PUT_LINE('============================================');
        
        -- Get basic metrics
        SELECT 
            NVL(SUM(net_amount), 0),
            COUNT(*),
            NVL(AVG(net_amount), 0)
        INTO 
            v_total_revenue,
            v_total_orders,
            v_avg_order_value
        FROM orders
        WHERE status NOT IN ('CANCELLED', 'RETURNED');
        
        -- Get YoY growth
        v_yoy_growth := calculate_yoy_growth();
        
        -- Display summary
        DBMS_OUTPUT.PUT_LINE('Total Revenue:      $' || TO_CHAR(v_total_revenue, 'FM999,999,999.00'));
        DBMS_OUTPUT.PUT_LINE('Total Orders:       ' || v_total_orders);
        DBMS_OUTPUT.PUT_LINE('Avg Order Value:    $' || TO_CHAR(v_avg_order_value, 'FM999,999.99'));
        DBMS_OUTPUT.PUT_LINE('YoY Growth:         ' || v_yoy_growth || '%');
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Show top performers if detailed report
        IF UPPER(p_report_type) = 'DETAILED' THEN
            DBMS_OUTPUT.PUT_LINE('TOP 5 CUSTOMERS:');
            DBMS_OUTPUT.PUT_LINE('----------------');
            
            v_customer_cursor := get_top_performers(5, 'CUSTOMERS');
            LOOP
                FETCH v_customer_cursor INTO v_temp_customer_id, v_temp_customer_name, 
                                              v_temp_customer_name, v_temp_total_spent, 
                                              v_temp_order_count, v_temp_avg_order_value;
                EXIT WHEN v_customer_cursor%NOTFOUND;
                
                DBMS_OUTPUT.PUT_LINE(
                    v_temp_customer_name || ' - $' || 
                    TO_CHAR(v_temp_total_spent, 'FM999,999.00') || 
                    ' (' || v_temp_order_count || ' orders)'
                );
            END LOOP;
            CLOSE v_customer_cursor;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('TOP 5 PRODUCTS:');
            DBMS_OUTPUT.PUT_LINE('---------------');
            
            v_product_cursor := get_top_performers(5, 'PRODUCTS');
            LOOP
                FETCH v_product_cursor INTO v_temp_product_id, v_temp_product_name, 
                                              v_temp_customer_name, v_temp_units_sold, 
                                              v_temp_revenue, v_temp_profit_margin;
                EXIT WHEN v_product_cursor%NOTFOUND;
                
                DBMS_OUTPUT.PUT_LINE(
                    v_temp_product_name || ' - ' || v_temp_units_sold || 
                    ' units sold, $' || TO_CHAR(v_temp_revenue, 'FM999,999.00')
                );
            END LOOP;
            CLOSE v_product_cursor;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('============================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error generating report: ' || SQLERRM);
    END generate_performance_report;
    
END sales_analytics_pkg;
/
