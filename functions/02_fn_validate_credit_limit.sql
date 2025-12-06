-- ============================================
-- FUNCTION 2: VALIDATE CREDIT LIMIT
-- ============================================

CREATE OR REPLACE FUNCTION fn_validate_credit_limit(
    p_customer_id IN NUMBER,
    p_order_amount IN NUMBER
) RETURN VARCHAR2
IS
    v_customer_tier     VARCHAR2(20);
    v_credit_limit      NUMBER := 0;
    v_current_balance   NUMBER := 0;
    v_available_credit  NUMBER := 0;
BEGIN
    -- Get customer tier and set credit limits
    SELECT customer_segment
    INTO v_customer_tier
    FROM customers
    WHERE customer_id = p_customer_id;
    
    -- Set credit limits based on tier
    CASE v_customer_tier
        WHEN 'PLATINUM' THEN v_credit_limit := 10000;
        WHEN 'GOLD'     THEN v_credit_limit := 5000;
        WHEN 'SILVER'   THEN v_credit_limit := 2000;
        WHEN 'BRONZE'   THEN v_credit_limit := 500;
        ELSE v_credit_limit := 100;
    END CASE;
    
    -- Calculate current balance (unpaid orders)
    SELECT NVL(SUM(net_amount), 0)
    INTO v_current_balance
    FROM orders
    WHERE customer_id = p_customer_id
      AND status NOT IN ('CANCELLED', 'RETURNED')
      AND order_id NOT IN (
          SELECT order_id FROM payments WHERE status = 'COMPLETED'
      );
    
    v_available_credit := v_credit_limit - v_current_balance;
    
    -- Validate
    IF p_order_amount <= v_available_credit THEN
        RETURN 'APPROVED: Available credit: $' || v_available_credit;
    ELSE
        RETURN 'DENIED: Order amount ($' || p_order_amount || 
               ') exceeds available credit ($' || v_available_credit || ')';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END fn_validate_credit_limit;
/
