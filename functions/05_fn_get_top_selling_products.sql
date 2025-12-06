-- ============================================
-- FUNCTION 5: GET TOP SELLING PRODUCTS
-- ============================================

CREATE OR REPLACE FUNCTION fn_get_top_selling_products(
    p_limit IN NUMBER DEFAULT 10,
    p_months_back IN NUMBER DEFAULT 6
) RETURN SYS_REFCURSOR
IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT 
            p.product_id,
            p.product_name,
            p.category_id,
            SUM(oi.quantity) AS total_units_sold,
            SUM(oi.quantity * oi.unit_price) AS total_revenue,
            ROUND(AVG(fn_get_product_profit_margin(p.product_id)), 2) AS avg_profit_margin,
            RANK() OVER (ORDER BY SUM(oi.quantity) DESC) AS sales_rank
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.order_date >= ADD_MONTHS(SYSDATE, -p_months_back)
          AND o.status NOT IN ('CANCELLED', 'RETURNED')
        GROUP BY p.product_id, p.product_name, p.category_id
        ORDER BY total_units_sold DESC
        FETCH FIRST p_limit ROWS ONLY;
    
    RETURN v_cursor;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return empty cursor on error
        OPEN v_cursor FOR 
            SELECT NULL AS product_id, NULL AS product_name, 
                   NULL AS category_id, NULL AS total_units_sold,
                   NULL AS total_revenue, NULL AS avg_profit_margin,
                   NULL AS sales_rank
            FROM DUAL WHERE 1=0;
        RETURN v_cursor;
END fn_get_top_selling_products;
/
