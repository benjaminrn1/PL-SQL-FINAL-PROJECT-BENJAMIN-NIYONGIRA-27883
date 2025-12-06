-- ============================================
-- CREATE RETURN-RELATED TABLES (FIXED VERSION)
-- ============================================

-- Returns table
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE returns (
            return_id          NUMBER PRIMARY KEY,
            order_id           NUMBER NOT NULL,
            product_id         NUMBER NOT NULL,
            return_date        DATE DEFAULT SYSDATE,
            return_quantity    NUMBER NOT NULL,
            return_reason      VARCHAR2(200) NOT NULL,
            return_type        VARCHAR2(20) DEFAULT ''REFUND'',
            refund_amount      NUMBER(10,2) DEFAULT 0,
            restocking_fee     NUMBER(10,2) DEFAULT 0,
            status             VARCHAR2(20) DEFAULT ''PENDING'',
            processed_by       VARCHAR2(50) DEFAULT USER,
            exchange_product_id NUMBER,
            notes              VARCHAR2(500),
            created_date       TIMESTAMP DEFAULT SYSTIMESTAMP
        )';
    DBMS_OUTPUT.PUT_LINE('Returns table created');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('Returns table already exists');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Error creating returns table: ' || SQLERRM);
        END IF;
END;
/

-- Add constraints separately
BEGIN
    EXECUTE IMMEDIATE '
        ALTER TABLE returns 
        ADD CONSTRAINT chk_return_type 
        CHECK (return_type IN (''REFUND'', ''EXCHANGE'', ''CREDIT''))';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
    EXECUTE IMMEDIATE '
        ALTER TABLE returns 
        ADD CONSTRAINT chk_return_status 
        CHECK (status IN (''PENDING'', ''PROCESSED'', ''DENIED'', ''CANCELLED''))';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
    EXECUTE IMMEDIATE '
        ALTER TABLE returns 
        ADD CONSTRAINT fk_return_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id)';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
    EXECUTE IMMEDIATE '
        ALTER TABLE returns 
        ADD CONSTRAINT fk_return_product 
        FOREIGN KEY (product_id) 
        REFERENCES products(product_id)';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Refunds table
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE refunds (
            refund_id          NUMBER PRIMARY KEY,
            return_id          NUMBER NOT NULL,
            order_id           NUMBER NOT NULL,
            refund_date        DATE DEFAULT SYSDATE,
            refund_amount      NUMBER(10,2) NOT NULL,
            refund_method      VARCHAR2(30) DEFAULT ''ORIGINAL_PAYMENT'',
            status             VARCHAR2(20) DEFAULT ''PENDING'',
            processed_by       VARCHAR2(50) DEFAULT USER,
            transaction_id     VARCHAR2(50),
            notes              VARCHAR2(500)
        )';
    DBMS_OUTPUT.PUT_LINE('Refunds table created');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('Refunds table already exists');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Error creating refunds table: ' || SQLERRM);
        END IF;
END;
/

-- Add constraints
BEGIN
    EXECUTE IMMEDIATE '
        ALTER TABLE refunds 
        ADD CONSTRAINT chk_refund_method 
        CHECK (refund_method IN (''ORIGINAL_PAYMENT'', ''STORE_CREDIT'', ''CHECK''))';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
    EXECUTE IMMEDIATE '
        ALTER TABLE refunds 
        ADD CONSTRAINT chk_refund_status 
        CHECK (status IN (''PENDING'', ''COMPLETED'', ''FAILED''))';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Exchanges table
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE exchanges (
            exchange_id         NUMBER PRIMARY KEY,
            return_id           NUMBER NOT NULL,
            original_product_id NUMBER NOT NULL,
            exchange_product_id NUMBER NOT NULL,
            exchange_date       DATE DEFAULT SYSDATE,
            status              VARCHAR2(20) DEFAULT ''PENDING'',
            processed_by        VARCHAR2(50) DEFAULT USER,
            notes               VARCHAR2(500)
        )';
    DBMS_OUTPUT.PUT_LINE('Exchanges table created');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('Exchanges table already exists');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Error creating exchanges table: ' || SQLERRM);
        END IF;
END;
/

-- Add constraints
BEGIN
    EXECUTE IMMEDIATE '
        ALTER TABLE exchanges 
        ADD CONSTRAINT chk_exchange_status 
        CHECK (status IN (''PENDING'', ''PROCESSED'', ''CANCELLED''))';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Add missing columns to customers table
DECLARE
    column_exists NUMBER;
BEGIN
    -- Check and add store_credit
    SELECT COUNT(*) INTO column_exists 
    FROM user_tab_columns 
    WHERE table_name = 'CUSTOMERS' AND column_name = 'STORE_CREDIT';
    
    IF column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE customers ADD (store_credit NUMBER(10,2) DEFAULT 0)';
        DBMS_OUTPUT.PUT_LINE('Added store_credit column to customers');
    ELSE
        DBMS_OUTPUT.PUT_LINE('store_credit column already exists');
    END IF;
    
    -- Check and add total_returns
    SELECT COUNT(*) INTO column_exists 
    FROM user_tab_columns 
    WHERE table_name = 'CUSTOMERS' AND column_name = 'TOTAL_RETURNS';
    
    IF column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE customers ADD (total_returns NUMBER DEFAULT 0)';
        DBMS_OUTPUT.PUT_LINE('Added total_returns column to customers');
    ELSE
        DBMS_OUTPUT.PUT_LINE('total_returns column already exists');
    END IF;
    
    -- Check and add last_return_date
    SELECT COUNT(*) INTO column_exists 
    FROM user_tab_columns 
    WHERE table_name = 'CUSTOMERS' AND column_name = 'LAST_RETURN_DATE';
    
    IF column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE customers ADD (last_return_date DATE)';
        DBMS_OUTPUT.PUT_LINE('Added last_return_date column to customers');
    ELSE
        DBMS_OUTPUT.PUT_LINE('last_return_date column already exists');
    END IF;
    
    -- Check and add total_refund_amount
    SELECT COUNT(*) INTO column_exists 
    FROM user_tab_columns 
    WHERE table_name = 'CUSTOMERS' AND column_name = 'TOTAL_REFUND_AMOUNT';
    
    IF column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE customers ADD (total_refund_amount NUMBER(12,2) DEFAULT 0)';
        DBMS_OUTPUT.PUT_LINE('Added total_refund_amount column to customers');
    ELSE
        DBMS_OUTPUT.PUT_LINE('total_refund_amount column already exists');
    END IF;
    
END;
/

-- Create sequences
DECLARE
    seq_exists NUMBER;
BEGIN
    -- Check and create return_seq
    SELECT COUNT(*) INTO seq_exists FROM user_sequences WHERE sequence_name = 'RETURN_SEQ';
    IF seq_exists = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE return_seq START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE';
        DBMS_OUTPUT.PUT_LINE('return_seq created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('return_seq already exists');
    END IF;
    
    -- Check and create refund_seq
    SELECT COUNT(*) INTO seq_exists FROM user_sequences WHERE sequence_name = 'REFUND_SEQ';
    IF seq_exists = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE refund_seq START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE';
        DBMS_OUTPUT.PUT_LINE('refund_seq created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('refund_seq already exists');
    END IF;
    
    -- Check and create exchange_seq
    SELECT COUNT(*) INTO seq_exists FROM user_sequences WHERE sequence_name = 'EXCHANGE_SEQ';
    IF seq_exists = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE exchange_seq START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE';
        DBMS_OUTPUT.PUT_LINE('exchange_seq created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('exchange_seq already exists');
    END IF;
END;
/





-- ============================================
-- PROCEDURE 5: PROCESS PRODUCT RETURN (FIXED)
-- ============================================

CREATE OR REPLACE PROCEDURE proc_process_return(
    p_order_id        IN NUMBER,
    p_product_id      IN NUMBER,
    p_return_quantity IN NUMBER,
    p_return_reason   IN VARCHAR2,
    p_return_type     IN VARCHAR2 DEFAULT 'REFUND',  -- 'REFUND', 'EXCHANGE', 'CREDIT'
    p_processed_by    IN VARCHAR2 DEFAULT USER,
    p_notes           IN VARCHAR2 DEFAULT NULL,
    p_refund_amount   OUT NUMBER,
    p_return_id       OUT NUMBER,
    p_success         OUT BOOLEAN,
    p_message         OUT VARCHAR2
)
IS
    -- Variables for order and product information
    v_customer_id          NUMBER;
    v_order_status         VARCHAR2(20);
    v_order_date           DATE;
    v_total_amount         NUMBER;
    v_net_amount           NUMBER;
    v_product_name         VARCHAR2(100);
    v_product_status       VARCHAR2(20);
    v_original_quantity    NUMBER;
    v_unit_price           NUMBER;
    v_line_total           NUMBER;
    v_days_since_order     NUMBER;
    
    -- Variables for validation
    v_max_return_days      NUMBER := 30;  -- 30-day return policy
    v_return_allowed       BOOLEAN := FALSE;
    v_refund_percentage    NUMBER := 100; -- Default 100% refund
    
    -- Variables for processing
    v_available_quantity   NUMBER;
    v_restocking_fee       NUMBER := 0;
    v_refund_tax           NUMBER := 0;
    v_total_refund         NUMBER := 0;
    v_exchange_product_id  NUMBER := NULL;
    v_temp_return_type     VARCHAR2(20);  -- Use temp variable for assignment
    
    -- Custom exceptions
    invalid_order_exception    EXCEPTION;
    invalid_product_exception  EXCEPTION;
    invalid_quantity_exception EXCEPTION;
    return_period_exception    EXCEPTION;
    product_discontinued_exception EXCEPTION;
    
    -- Cursor to check if product was in the order
    CURSOR c_order_product IS
        SELECT oi.quantity, oi.unit_price, oi.line_total
        FROM order_items oi
        WHERE oi.order_id = p_order_id
          AND oi.product_id = p_product_id;
    
    -- Cursor to get similar products for exchange
    CURSOR c_similar_products(p_category_id NUMBER) IS
        SELECT product_id, product_name, unit_price
        FROM products
        WHERE category_id = p_category_id
          AND status = 'ACTIVE'
          AND product_id != p_product_id
        ORDER BY unit_price;
    
BEGIN
    -- Initialize outputs
    p_success := FALSE;
    p_message := NULL;
    p_refund_amount := 0;
    p_return_id := NULL;
    v_temp_return_type := p_return_type;  -- Use temp variable
    
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('PROCESSING RETURN REQUEST');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('Order ID: ' || p_order_id);
    DBMS_OUTPUT.PUT_LINE('Product ID: ' || p_product_id);
    DBMS_OUTPUT.PUT_LINE('Return Quantity: ' || p_return_quantity);
    DBMS_OUTPUT.PUT_LINE('Return Reason: ' || p_return_reason);
    DBMS_OUTPUT.PUT_LINE('Return Type: ' || p_return_type);
    
    -- Step 1: Validate return quantity
    IF p_return_quantity <= 0 THEN
        p_message := 'Return quantity must be greater than 0';
        RAISE invalid_quantity_exception;
    END IF;
    
    -- Step 2: Get order information
    BEGIN
        SELECT 
            customer_id, 
            order_date, 
            status,
            total_amount,
            net_amount
        INTO 
            v_customer_id,
            v_order_date,
            v_order_status,
            v_total_amount,
            v_net_amount
        FROM orders
        WHERE order_id = p_order_id;
        
        -- Check if order is eligible for return
        IF v_order_status NOT IN ('DELIVERED', 'SHIPPED') THEN
            p_message := 'Order status (' || v_order_status || ') is not eligible for return';
            RAISE invalid_order_exception;
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_message := 'Order ID ' || p_order_id || ' not found';
            RAISE invalid_order_exception;
    END;
    
    -- Step 3: Check return period
    v_days_since_order := SYSDATE - v_order_date;
    
    IF v_days_since_order > v_max_return_days THEN
        p_message := 'Return period expired. Order is ' || ROUND(v_days_since_order) || 
                     ' days old (max ' || v_max_return_days || ' days)';
        RAISE return_period_exception;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Days since order: ' || ROUND(v_days_since_order) || ' (max: ' || v_max_return_days || ')');
    
    -- Step 4: Get product information and validate
    BEGIN
        SELECT product_name, status
        INTO v_product_name, v_product_status
        FROM products
        WHERE product_id = p_product_id;
        
        -- Check if product is active (not discontinued)
        -- Note: We need to convert VARCHAR2 status to BOOLEAN for comparison
        IF v_product_status != 'ACTIVE' THEN
            p_message := 'Product ' || v_product_name || ' is ' || v_product_status || ' and cannot be returned';
            RAISE product_discontinued_exception;
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_message := 'Product ID ' || p_product_id || ' not found';
            RAISE invalid_product_exception;
    END;
    
    -- Step 5: Check if product was in the order
    OPEN c_order_product;
    FETCH c_order_product INTO v_original_quantity, v_unit_price, v_line_total;
    
    IF c_order_product%NOTFOUND THEN
        CLOSE c_order_product;
        p_message := 'Product ' || v_product_name || ' was not found in order ' || p_order_id;
        RAISE invalid_product_exception;
    END IF;
    
    CLOSE c_order_product;
    
    -- Step 6: Validate return quantity
    IF p_return_quantity > v_original_quantity THEN
        p_message := 'Return quantity (' || p_return_quantity || 
                     ') exceeds original quantity (' || v_original_quantity || ')';
        RAISE invalid_quantity_exception;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Product: ' || v_product_name);
    DBMS_OUTPUT.PUT_LINE('Original Quantity: ' || v_original_quantity);
    DBMS_OUTPUT.PUT_LINE('Unit Price: $' || v_unit_price);
    DBMS_OUTPUT.PUT_LINE('Line Total: $' || v_line_total);
    
    -- Step 7: Calculate refund amount based on return type and conditions
    -- Calculate percentage of order this line represents
    IF v_net_amount > 0 THEN
        v_refund_percentage := (v_line_total / v_net_amount) * 100;
    ELSE
        v_refund_percentage := 100;
    END IF;
    
    -- Apply business rules for refund calculation
    IF v_temp_return_type = 'REFUND' THEN
        -- Full refund minus restocking fee if applicable
        v_restocking_fee := CASE 
            WHEN UPPER(p_return_reason) LIKE '%CHANGED MIND%' THEN v_line_total * 0.10  -- 10% restocking fee
            WHEN UPPER(p_return_reason) LIKE '%NO LONGER NEED%' THEN v_line_total * 0.05  -- 5% restocking fee
            ELSE 0
        END;
        
        v_total_refund := (v_line_total * (p_return_quantity / v_original_quantity)) - v_restocking_fee;
        
    ELSIF v_temp_return_type = 'EXCHANGE' THEN
        -- No refund, just exchange
        v_total_refund := 0;
        
        -- Find similar product for exchange (simplified - would need more logic)
        DECLARE
            v_category_id NUMBER;
        BEGIN
            SELECT category_id INTO v_category_id
            FROM products
            WHERE product_id = p_product_id;
            
            -- Get first similar product as exchange
            FOR sim_prod IN c_similar_products(v_category_id) LOOP
                v_exchange_product_id := sim_prod.product_id;
                EXIT;
            END LOOP;
            
            IF v_exchange_product_id IS NULL THEN
                p_message := 'No similar products available for exchange';
                v_temp_return_type := 'REFUND'; -- Fallback to refund
                v_total_refund := v_line_total * (p_return_quantity / v_original_quantity);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_temp_return_type := 'REFUND'; -- Fallback to refund
                v_total_refund := v_line_total * (p_return_quantity / v_original_quantity);
        END;
        
    ELSIF v_temp_return_type = 'CREDIT' THEN
        -- Store credit for future purchases
        v_total_refund := v_line_total * (p_return_quantity / v_original_quantity);
        
    ELSE
        p_message := 'Invalid return type: ' || v_temp_return_type;
        RAISE invalid_order_exception;
    END IF;
    
    -- Ensure refund is not negative
    IF v_total_refund < 0 THEN
        v_total_refund := 0;
    END IF;
    
    -- Round to 2 decimal places
    v_total_refund := ROUND(v_total_refund, 2);
    p_refund_amount := v_total_refund;
    
    DBMS_OUTPUT.PUT_LINE('Refund Amount: $' || v_total_refund);
    IF v_restocking_fee > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Restocking Fee: $' || v_restocking_fee);
    END IF;
    
    -- Step 8: Start transaction
    SAVEPOINT before_return;
    
    -- Step 9: Create return record
    INSERT INTO returns (
        return_id,
        order_id,
        product_id,
        return_date,
        return_quantity,
        return_reason,
        return_type,
        refund_amount,
        restocking_fee,
        status,
        processed_by,
        exchange_product_id,
        notes
    )
    VALUES (
        return_seq.NEXTVAL,
        p_order_id,
        p_product_id,
        SYSDATE,
        p_return_quantity,
        p_return_reason,
        v_temp_return_type,
        v_total_refund,
        v_restocking_fee,
        'PROCESSED',
        p_processed_by,
        v_exchange_product_id,
        p_notes
    )
    RETURNING return_id INTO p_return_id;
    
    DBMS_OUTPUT.PUT_LINE('Return ID created: ' || p_return_id);
    
    -- Step 10: Update inventory (restock)
    UPDATE products
    SET stock_quantity = stock_quantity + p_return_quantity
    WHERE product_id = p_product_id;
    
    DBMS_OUTPUT.PUT_LINE('Inventory updated: +' || p_return_quantity || ' units for product ' || p_product_id);
    
    -- Step 11: Process refund if applicable
    IF v_total_refund > 0 AND v_temp_return_type IN ('REFUND', 'CREDIT') THEN
        INSERT INTO refunds (
            refund_id,
            return_id,
            order_id,
            refund_date,
            refund_amount,
            refund_method,
            status,
            processed_by
        )
        VALUES (
            refund_seq.NEXTVAL,
            p_return_id,
            p_order_id,
            SYSDATE,
            v_total_refund,
            CASE v_temp_return_type 
                WHEN 'REFUND' THEN 'ORIGINAL_PAYMENT'
                WHEN 'CREDIT' THEN 'STORE_CREDIT'
            END,
            'COMPLETED',
            p_processed_by
        );
        
        DBMS_OUTPUT.PUT_LINE('Refund processed: $' || v_total_refund);
        
        -- If store credit, update customer credit
        IF v_temp_return_type = 'CREDIT' THEN
            UPDATE customers
            SET store_credit = NVL(store_credit, 0) + v_total_refund
            WHERE customer_id = v_customer_id;
            
            DBMS_OUTPUT.PUT_LINE('Store credit added to customer ' || v_customer_id);
        END IF;
    END IF;
    
    -- Step 12: Update order status if all items returned
    DECLARE
        v_total_items          NUMBER;
        v_returned_items       NUMBER;
        v_remaining_items      NUMBER;
    BEGIN
        -- Get total items in order
        SELECT SUM(quantity)
        INTO v_total_items
        FROM order_items
        WHERE order_id = p_order_id;
        
        -- Get total returned items (including this return)
        SELECT SUM(return_quantity)
        INTO v_returned_items
        FROM returns
        WHERE order_id = p_order_id
          AND status = 'PROCESSED';
        
        v_remaining_items := v_total_items - NVL(v_returned_items, 0);
        
        IF v_remaining_items <= 0 THEN
            -- All items returned, update order status
            UPDATE orders
            SET status = 'RETURNED'
            WHERE order_id = p_order_id;
            
            DBMS_OUTPUT.PUT_LINE('All items returned. Order status updated to RETURNED');
        ELSE
            -- Partial return, update order notes
            UPDATE orders
            SET status = 'PARTIALLY_RETURNED'
            WHERE order_id = p_order_id;
            
            DBMS_OUTPUT.PUT_LINE('Partial return. ' || v_remaining_items || ' items remaining. Order status updated to PARTIALLY_RETURNED');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Note: Error updating order status: ' || SQLERRM);
    END;
    
    -- Step 13: Log audit trail
    BEGIN
        INSERT INTO audit_log (
            audit_id,
            table_name,
            record_id,
            action_type,
            old_value,
            new_value,
            changed_by,
            change_timestamp
        )
        VALUES (
            audit_seq.NEXTVAL,
            'RETURNS',
            TO_CHAR(p_return_id),
            'INSERT',
            NULL,
            'Return processed: ' || p_return_quantity || ' units of ' || v_product_name || 
            ' for $' || v_total_refund || ' refund',
            p_processed_by,
            SYSTIMESTAMP
        );
        DBMS_OUTPUT.PUT_LINE('Audit log recorded');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Note: Audit log not recorded: ' || SQLERRM);
    END;
    
    -- Step 14: Handle exchange if applicable
    IF v_temp_return_type = 'EXCHANGE' AND v_exchange_product_id IS NOT NULL THEN
        BEGIN
            -- Create exchange record
            INSERT INTO exchanges (
                exchange_id,
                return_id,
                original_product_id,
                exchange_product_id,
                exchange_date,
                status,
                processed_by
            )
            VALUES (
                exchange_seq.NEXTVAL,
                p_return_id,
                p_product_id,
                v_exchange_product_id,
                SYSDATE,
                'PROCESSED',
                p_processed_by
            );
            
            DBMS_OUTPUT.PUT_LINE('Exchange created for product ' || v_exchange_product_id);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Note: Exchange not recorded: ' || SQLERRM);
        END;
    END IF;
    
    -- Step 15: Update customer return history
    BEGIN
        UPDATE customers
        SET total_returns = NVL(total_returns, 0) + 1,
            last_return_date = SYSDATE,
            total_refund_amount = NVL(total_refund_amount, 0) + v_total_refund
        WHERE customer_id = v_customer_id;
        
        DBMS_OUTPUT.PUT_LINE('Customer return history updated');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Note: Customer history not updated: ' || SQLERRM);
    END;
    
    -- Success
    COMMIT;
    p_success := TRUE;
    p_message := 'Return processed successfully. Return ID: ' || p_return_id || 
                 ', Refund Amount: $' || v_total_refund;
    
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('RETURN PROCESSING COMPLETED');
    DBMS_OUTPUT.PUT_LINE('============================================');
    
EXCEPTION
    WHEN invalid_order_exception THEN
        ROLLBACK TO before_return;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || p_message);
        
    WHEN invalid_product_exception THEN
        ROLLBACK TO before_return;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || p_message);
        
    WHEN invalid_quantity_exception THEN
        ROLLBACK TO before_return;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || p_message);
        
    WHEN return_period_exception THEN
        ROLLBACK TO before_return;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || p_message);
        
    WHEN product_discontinued_exception THEN
        ROLLBACK TO before_return;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || p_message);
        
    WHEN OTHERS THEN
        ROLLBACK TO before_return;
        p_success := FALSE;
        p_message := 'Error processing return: ' || SQLERRM;
        
        DBMS_OUTPUT.PUT_LINE('UNEXPECTED ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
END proc_process_return;
/





-- ============================================
-- SIMPLE TEST FOR PROC_PROCESS_RETURN
-- ============================================

SET SERVEROUTPUT ON

DECLARE
    v_refund_amount NUMBER;
    v_return_id     NUMBER;
    v_success       BOOLEAN;
    v_message       VARCHAR2(4000);
    v_order_id      NUMBER;
    v_product_id    NUMBER := 2;  -- Mouse
    
    -- Create a simple test order
    FUNCTION create_test_return_order RETURN NUMBER IS
        v_order_id NUMBER;
    BEGIN
        -- Create order
        INSERT INTO orders (
            order_id, customer_id, order_date, status,
            total_amount, discount_amount, tax_amount,
            shipping_address, billing_address
        )
        VALUES (
            order_seq.NEXTVAL, 1001, SYSDATE - 7, 'DELIVERED',
            99.97, 0, 7.99,
            'Test Return Address', 'Test Return Address'
        )
        RETURNING order_id INTO v_order_id;
        
        -- Add order items
        INSERT INTO order_items (
            order_item_id, order_id, product_id, quantity, unit_price
        )
        VALUES (order_item_seq.NEXTVAL, v_order_id, 1, 1, 99.99);
        
        INSERT INTO order_items (
            order_item_id, order_id, product_id, quantity, unit_price
        )
        VALUES (order_item_seq.NEXTVAL, v_order_id, 2, 2, 29.99);
        
        -- Add payment
        INSERT INTO payments (
            payment_id, order_id, payment_date, amount,
            payment_method, status
        )
        VALUES (
            payment_seq.NEXTVAL, v_order_id, SYSDATE - 7, 107.96,
            'CREDIT_CARD', 'COMPLETED'
        );
        
        COMMIT;
        RETURN v_order_id;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error creating test order: ' || SQLERRM);
            RETURN NULL;
    END;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TESTING PROC_PROCESS_RETURN ===');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Create or find test order
    BEGIN
        -- Look for an existing order
        SELECT MIN(o.order_id) INTO v_order_id
        FROM orders o
        WHERE o.status = 'DELIVERED'
          AND EXISTS (
            SELECT 1 FROM order_items oi 
            WHERE oi.order_id = o.order_id 
            AND oi.product_id = v_product_id
          );
        
        IF v_order_id IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Creating test order...');
            v_order_id := create_test_return_order();
            
            IF v_order_id IS NULL THEN
                DBMS_OUTPUT.PUT_LINE('Failed to create test order');
                RETURN;
            END IF;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Using Order ID: ' || v_order_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            RETURN;
    END;
    
    -- Show initial state
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Initial inventory for product ' || v_product_id || ':');
    BEGIN
        DECLARE
            v_product_name VARCHAR2(100);
            v_stock_qty    NUMBER;
        BEGIN
            SELECT product_name, stock_quantity 
            INTO v_product_name, v_stock_qty
            FROM products 
            WHERE product_id = v_product_id;
            
            DBMS_OUTPUT.PUT_LINE(v_product_name || ': ' || v_stock_qty || ' units');
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error getting inventory: ' || SQLERRM);
    END;
    
    -- Test 1: Simple refund
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST 1: SIMPLE REFUND ===');
    
    proc_process_return(
        p_order_id        => v_order_id,
        p_product_id      => v_product_id,
        p_return_quantity => 1,
        p_return_reason   => 'Defective product',
        p_return_type     => 'REFUND',
        p_processed_by    => 'TESTER',
        p_notes          => 'Test return',
        p_refund_amount   => v_refund_amount,
        p_return_id       => v_return_id,
        p_success         => v_success,
        p_message         => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_message);
    DBMS_OUTPUT.PUT_LINE('Success: ' || CASE WHEN v_success THEN 'YES' ELSE 'NO' END);
    
    IF v_success THEN
        DBMS_OUTPUT.PUT_LINE('Return ID: ' || v_return_id);
        DBMS_OUTPUT.PUT_LINE('Refund Amount: $' || v_refund_amount);
        
        -- Show updated inventory
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Updated inventory for product ' || v_product_id || ':');
        BEGIN
            DECLARE
                v_product_name VARCHAR2(100);
                v_stock_qty    NUMBER;
            BEGIN
                SELECT product_name, stock_quantity 
                INTO v_product_name, v_stock_qty
                FROM products 
                WHERE product_id = v_product_id;
                
                DBMS_OUTPUT.PUT_LINE(v_product_name || ': ' || v_stock_qty || ' units');
            END;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error getting inventory: ' || SQLERRM);
        END;
    END IF;
    
    -- Test 2: Store credit
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST 2: STORE CREDIT ===');
    
    proc_process_return(
        p_order_id        => v_order_id,
        p_product_id      => v_product_id,
        p_return_quantity => 1,
        p_return_reason   => 'Wrong size',
        p_return_type     => 'CREDIT',
        p_processed_by    => 'TESTER',
        p_refund_amount   => v_refund_amount,
        p_return_id       => v_return_id,
        p_success         => v_success,
        p_message         => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_message);
    DBMS_OUTPUT.PUT_LINE('Success: ' || CASE WHEN v_success THEN 'YES' ELSE 'NO' END);
    
    -- Test 3: Invalid quantity (should fail)
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST 3: INVALID QUANTITY (SHOULD FAIL) ===');
    
    proc_process_return(
        p_order_id        => v_order_id,
        p_product_id      => v_product_id,
        p_return_quantity => 10,  -- More than ordered
        p_return_reason   => 'Defective',
        p_return_type     => 'REFUND',
        p_processed_by    => 'TESTER',
        p_refund_amount   => v_refund_amount,
        p_return_id       => v_return_id,
        p_success         => v_success,
        p_message         => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_message);
    DBMS_OUTPUT.PUT_LINE('Success: ' || CASE WHEN v_success THEN 'YES' ELSE 'NO' END);
    
    -- Verify data was created
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== VERIFYING DATA ===');
    
    -- Check returns table
    DECLARE
        v_return_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_return_count
        FROM returns 
        WHERE order_id = v_order_id;
        
        DBMS_OUTPUT.PUT_LINE('Total returns for order ' || v_order_id || ': ' || v_return_count);
        
        IF v_return_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Return details:');
            FOR r IN (
                SELECT return_id, product_id, return_quantity, refund_amount, status
                FROM returns 
                WHERE order_id = v_order_id
                ORDER BY return_date
            ) LOOP
                DBMS_OUTPUT.PUT_LINE('  ID: ' || r.return_id || 
                                   ', Product: ' || r.product_id || 
                                   ', Qty: ' || r.return_quantity || 
                                   ', Refund: $' || r.refund_amount || 
                                   ', Status: ' || r.status);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error checking returns: ' || SQLERRM);
    END;
    
    -- Check refunds table
    BEGIN
        DECLARE
            v_refund_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_refund_count
            FROM refunds 
            WHERE order_id = v_order_id;
            
            DBMS_OUTPUT.PUT_LINE('Total refunds for order ' || v_order_id || ': ' || v_refund_count);
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Note: refunds table may not exist or have data');
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST COMPLETED ===');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Test error: ' || SQLERRM);
END;
/
