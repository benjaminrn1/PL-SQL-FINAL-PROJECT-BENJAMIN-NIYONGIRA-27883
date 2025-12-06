-- ============================================
-- FUNCTION 1: CALCULATE CUSTOMER LIFETIME VALUE
-- ============================================

CREATE OR REPLACE FUNCTION fn_calculate_customer_lifetime_value(
    p_customer_id IN NUMBER
) RETURN NUMBER
IS
    v_total_spent        NUMBER := 0;
    v_order_count        NUMBER := 0;
    v_avg_order_value    NUMBER := 0;
    v_months_active      NUMBER := 0;
    v_clv                NUMBER := 0;
BEGIN
    -- Calculate total spent
    SELECT NVL(SUM(net_amount), 0), COUNT(*)
    INTO v_total_spent, v_order_count
    FROM orders
    WHERE customer_id = p_customer_id
      AND status NOT IN ('CANCELLED', 'RETURNED');
    
    -- Calculate average order value
    IF v_order_count > 0 THEN
        v_avg_order_value := v_total_spent / v_order_count;
    END IF;
    
    -- Calculate months active
    SELECT MONTHS_BETWEEN(SYSDATE, MIN(join_date))
    INTO v_months_active
    FROM customers
    WHERE customer_id = p_customer_id;
    
    -- Calculate CLV: (Avg Order Value × Purchase Frequency × Customer Lifetime)
    -- Simplified formula: total_spent / years_active × expected_years
    IF v_months_active > 0 THEN
        v_clv := (v_total_spent / v_months_active) * 12 * 3; -- Project 3 years
    END IF;
    
    RETURN ROUND(v_clv, 2);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END fn_calculate_customer_lifetime_value;
/
