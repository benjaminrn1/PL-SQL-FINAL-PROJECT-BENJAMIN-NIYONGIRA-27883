-- ============================================
-- FUNCTION 4: PREDICT SALES TREND
-- ============================================

CREATE OR REPLACE FUNCTION fn_predict_sales_trend(
    p_months_ahead IN NUMBER DEFAULT 1
) RETURN NUMBER
IS
    v_avg_monthly_sales NUMBER;
    v_seasonal_factor   NUMBER := 1.0;
    v_current_month     NUMBER;
    v_predicted_sales   NUMBER;
BEGIN
    -- Calculate average monthly sales from last 12 months
    SELECT AVG(monthly_sales)
    INTO v_avg_monthly_sales
    FROM (
        SELECT EXTRACT(MONTH FROM order_date) AS month,
               SUM(net_amount) AS monthly_sales
        FROM orders
        WHERE order_date >= ADD_MONTHS(SYSDATE, -12)
          AND status NOT IN ('CANCELLED', 'RETURNED')
        GROUP BY EXTRACT(MONTH FROM order_date)
    );
    
    -- Get current month
    v_current_month := EXTRACT(MONTH FROM SYSDATE);
    
    -- Apply seasonal factors (simplified example)
    CASE v_current_month
        WHEN 11 THEN v_seasonal_factor := 1.5;  -- November (Black Friday)
        WHEN 12 THEN v_seasonal_factor := 2.0;  -- December (Christmas)
        WHEN 1  THEN v_seasonal_factor := 1.3;  -- January (New Year)
        WHEN 7  THEN v_seasonal_factor := 1.2;  -- July (Summer)
        ELSE v_seasonal_factor := 1.0;
    END CASE;
    
    -- Predict sales
    v_predicted_sales := v_avg_monthly_sales * v_seasonal_factor;
    
    RETURN ROUND(v_predicted_sales, 2);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        RETURN -1;
END fn_predict_sales_trend;
/
