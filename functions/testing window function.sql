-- File: 06_test_window_functions.sql
SET SERVEROUTPUT ON;
SET PAGESIZE 1000;
SET LINESIZE 200;

DECLARE
    v_test_date DATE := SYSDATE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TESTING WINDOW FUNCTIONS ===');
    DBMS_OUTPUT.PUT_LINE('Test Date: ' || TO_CHAR(v_test_date, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: Customer Ranking
    DBMS_OUTPUT.PUT_LINE('--- Test 1: Customer Ranking by Spending ---');
    FOR rec IN (
        SELECT customer_id, customer_name, total_spent, spending_rank
        FROM (
            SELECT 
                customer_id,
                first_name || ' ' || last_name as customer_name,
                total_spent,
                RANK() OVER (ORDER BY total_spent DESC) as spending_rank
            FROM customers
            WHERE status = 'ACTIVE'
        )
        WHERE ROWNUM <= 5
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            'Rank ' || rec.spending_rank || ': ' || 
            rec.customer_name || ' - $' || TO_CHAR(rec.total_spent, '999,999.99')
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 2: Product Sales Ranking by Category
    DBMS_OUTPUT.PUT_LINE('--- Test 2: Top Products by Category ---');
    FOR rec IN (
        SELECT category_name, product_name, total_sales, sales_rank_in_category
        FROM (
            SELECT 
                c.category_name,
                p.product_name,
                NVL(SUM(oi.quantity * oi.unit_price), 0) as total_sales,
                ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY NVL(SUM(oi.quantity * oi.unit_price), 0) DESC) as sales_rank_in_category
            FROM products p
            JOIN categories c ON p.category_id = c.category_id
            LEFT JOIN order_items oi ON p.product_id = oi.product_id
            LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status = 'DELIVERED'
            GROUP BY p.category_id, c.category_name, p.product_name
        )
        WHERE sales_rank_in_category <= 3
        ORDER BY category_name, sales_rank_in_category
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            rec.category_name || ' - #' || rec.sales_rank_in_category || ': ' ||
            rec.product_name || ' - $' || TO_CHAR(rec.total_sales, '999,999.99')
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 3: Monthly Sales Trend
    DBMS_OUTPUT.PUT_LINE('--- Test 3: Monthly Sales Trend (Last 6 Months) ---');
    FOR rec IN (
        SELECT 
            month_year,
            total_sales,
            prev_month_sales,
            monthly_growth_percent,
            three_month_avg
        FROM (
            SELECT 
                month_year,
                total_sales,
                LAG(total_sales) OVER (ORDER BY month_year) as prev_month_sales,
                ROUND(((total_sales - LAG(total_sales) OVER (ORDER BY month_year)) / 
                      NULLIF(LAG(total_sales) OVER (ORDER BY month_year), 0)) * 100, 2) as monthly_growth_percent,
                AVG(total_sales) OVER (ORDER BY month_year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as three_month_avg
            FROM (
                SELECT 
                    TO_CHAR(order_date, 'YYYY-MM') as month_year,
                    SUM(total_amount) as total_sales
                FROM orders
                WHERE order_status = 'DELIVERED'
                  AND order_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -6)
                GROUP BY TO_CHAR(order_date, 'YYYY-MM')
            )
        )
        ORDER BY month_year DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            rec.month_year || ': $' || TO_CHAR(rec.total_sales, '999,999.99') ||
            ' | Growth: ' || NVL(TO_CHAR(rec.monthly_growth_percent), 'N/A') || '%' ||
            ' | 3-Month Avg: $' || TO_CHAR(rec.three_month_avg, '999,999.99')
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== WINDOW FUNCTIONS TESTING COMPLETED ===');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error testing window functions: ' || SQLERRM);
END;
/
