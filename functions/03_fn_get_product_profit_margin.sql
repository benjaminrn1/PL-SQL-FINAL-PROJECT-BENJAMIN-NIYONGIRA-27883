-- ============================================
-- FUNCTION 3: GET PRODUCT PROFIT MARGIN
-- ============================================

CREATE OR REPLACE FUNCTION fn_get_product_profit_margin(
    p_product_id IN NUMBER
) RETURN NUMBER
IS
    v_unit_price   NUMBER;
    v_unit_cost    NUMBER;
    v_profit_margin NUMBER;
BEGIN
    SELECT unit_price, unit_cost
    INTO v_unit_price, v_unit_cost
    FROM products
    WHERE product_id = p_product_id;
    
    -- Calculate profit margin: ((price - cost) / price) × 100%
    IF v_unit_price > 0 THEN
        v_profit_margin := ((v_unit_price - v_unit_cost) / v_unit_price) * 100;
    ELSE
        v_profit_margin := 0;
    END IF;
    
    RETURN ROUND(v_profit_margin, 2);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        RETURN -1; -- Error indicator
END fn_get_product_profit_margin;
/
