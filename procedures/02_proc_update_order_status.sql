-- ============================================
         PROC_UPDATE_ORDER_STATUS
-- ============================================

CREATE OR REPLACE PROCEDURE proc_update_order_status(
    p_order_id      IN NUMBER,
    p_new_status    IN VARCHAR2,
    p_updated_by    IN VARCHAR2 DEFAULT USER,
    p_notes         IN VARCHAR2 DEFAULT NULL,
    p_success       OUT BOOLEAN,
    p_message       OUT VARCHAR2
)
IS
    v_old_status      VARCHAR2(20);
    v_customer_id     NUMBER;
    v_ip_address      VARCHAR2(50) := '127.0.0.1';
    
    -- Function to validate status transition
    FUNCTION validate_status_transition(
        p_from_status IN VARCHAR2,
        p_to_status   IN VARCHAR2
    ) RETURN BOOLEAN 
    IS
    BEGIN
        -- Check for NULL status
        IF p_from_status IS NULL OR p_to_status IS NULL THEN
            RETURN FALSE;
        END IF;
        
        -- Define allowed transitions with ELSE clause
        RETURN CASE p_from_status
            WHEN 'PENDING' THEN
                p_to_status IN ('PROCESSING', 'CANCELLED')
            WHEN 'PROCESSING' THEN
                p_to_status IN ('SHIPPED', 'CANCELLED')
            WHEN 'SHIPPED' THEN
                p_to_status IN ('DELIVERED', 'RETURNED')
            WHEN 'DELIVERED' THEN
                p_to_status IN ('RETURNED')
            WHEN 'CANCELLED' THEN
                FALSE  -- Cannot change from cancelled
            WHEN 'RETURNED' THEN
                FALSE  -- Cannot change from returned
            ELSE
                FALSE  -- Handle any other status values
        END;
    END validate_status_transition;
    
BEGIN
    -- Initialize outputs
    p_success := FALSE;
    p_message := NULL;
    
    DBMS_OUTPUT.PUT_LINE('DEBUG: Starting status update for order ' || p_order_id);
    DBMS_OUTPUT.PUT_LINE('DEBUG: Requested new status: ' || p_new_status);
    
    -- Step 1: Validate input status
    IF p_new_status NOT IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED') THEN
        p_message := 'Invalid status: ' || p_new_status;
        DBMS_OUTPUT.PUT_LINE('DEBUG: ' || p_message);
        RETURN;
    END IF;
    
    -- Step 2: Get current order details
    BEGIN
        SELECT status, customer_id 
        INTO v_old_status, v_customer_id
        FROM orders 
        WHERE order_id = p_order_id;
        
        DBMS_OUTPUT.PUT_LINE('DEBUG: Current status: ' || v_old_status);
        DBMS_OUTPUT.PUT_LINE('DEBUG: Customer ID: ' || v_customer_id);
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_message := 'Order ID ' || p_order_id || ' not found';
            DBMS_OUTPUT.PUT_LINE('DEBUG: ' || p_message);
            RETURN;
    END;
    
    -- Check if current status is NULL
    IF v_old_status IS NULL THEN
        p_message := 'Current order status is NULL';
        DBMS_OUTPUT.PUT_LINE('DEBUG: ' || p_message);
        RETURN;
    END IF;
    
    -- Step 3: Check if status is actually changing
    IF v_old_status = p_new_status THEN
        p_success := TRUE;
        p_message := 'Order status is already ' || p_new_status;
        DBMS_OUTPUT.PUT_LINE('DEBUG: ' || p_message);
        RETURN;
    END IF;
    
    -- Step 4: Validate status transition
    IF NOT validate_status_transition(v_old_status, p_new_status) THEN
        p_message := 'Invalid status transition: ' || v_old_status || ' -> ' || p_new_status;
        DBMS_OUTPUT.PUT_LINE('DEBUG: ' || p_message);
        RETURN;
    END IF;
    
    -- Step 5: Additional business rules
    IF p_new_status = 'SHIPPED' THEN
        -- Check if shipment exists
        DECLARE
            v_shipment_exists NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_shipment_exists
            FROM shipments 
            WHERE order_id = p_order_id;
            
            IF v_shipment_exists = 0 THEN
                p_message := 'Cannot ship order without shipment record';
                DBMS_OUTPUT.PUT_LINE('DEBUG: ' || p_message);
                RETURN;
            END IF;
            DBMS_OUTPUT.PUT_LINE('DEBUG: Shipment record found');
        END;
    END IF;
    
    IF p_new_status = 'CANCELLED' THEN
        -- Check if order can be cancelled (within 24 hours)
        DECLARE
            v_order_date DATE;
            v_hours_elapsed NUMBER;
        BEGIN
            SELECT order_date INTO v_order_date
            FROM orders 
            WHERE order_id = p_order_id;
            
            v_hours_elapsed := (SYSDATE - v_order_date) * 24;
            
            IF v_hours_elapsed > 24 THEN
                p_message := 'Order cannot be cancelled after 24 hours. Hours elapsed: ' || ROUND(v_hours_elapsed, 2);
                DBMS_OUTPUT.PUT_LINE('DEBUG: ' || p_message);
                RETURN;
            END IF;
            DBMS_OUTPUT.PUT_LINE('DEBUG: Cancellation within allowed time');
        END;
    END IF;
    
    -- Start transaction
    SAVEPOINT before_update;
    
    -- Update the order status
    UPDATE orders 
    SET status = p_new_status
    WHERE order_id = p_order_id;
    
    DBMS_OUTPUT.PUT_LINE('DEBUG: Order status updated in database');
    
    -- Handle status-specific actions
    CASE p_new_status
        WHEN 'CANCELLED' THEN
            -- Restore inventory
            DBMS_OUTPUT.PUT_LINE('DEBUG: Restoring inventory...');
            FOR item IN (
                SELECT product_id, quantity
                FROM order_items
                WHERE order_id = p_order_id
            ) LOOP
                UPDATE products 
                SET stock_quantity = stock_quantity + item.quantity
                WHERE product_id = item.product_id;
                DBMS_OUTPUT.PUT_LINE('DEBUG: Restored ' || item.quantity || ' units for product ' || item.product_id);
            END LOOP;
            
        WHEN 'DELIVERED' THEN
            -- Update customer's last order date
            DBMS_OUTPUT.PUT_LINE('DEBUG: Updating customer last order date...');
            UPDATE customers 
            SET last_order_date = SYSDATE
            WHERE customer_id = v_customer_id;
            
        WHEN 'SHIPPED' THEN
            -- Update shipment status
            DBMS_OUTPUT.PUT_LINE('DEBUG: Updating shipment status...');
            UPDATE shipments 
            SET status = 'SHIPPED',
                ship_date = SYSDATE
            WHERE order_id = p_order_id;
    END CASE;
    
    -- Record audit log
    DBMS_OUTPUT.PUT_LINE('DEBUG: Recording audit log...');
    INSERT INTO audit_log (
        audit_id,
        table_name,
        record_id,
        action_type,
        old_value,
        new_value,
        changed_by,
        change_timestamp,
        ip_address
    )
    VALUES (
        audit_seq.NEXTVAL,
        'ORDERS',
        TO_CHAR(p_order_id),
        'UPDATE',
        v_old_status,
        p_new_status,
        p_updated_by,
        SYSTIMESTAMP,
        v_ip_address
    );
    
    -- Log additional notes if provided
    IF p_notes IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('DEBUG: Recording additional notes...');
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
            'ORDERS',
            TO_CHAR(p_order_id),
            'NOTE',
            NULL,
            p_notes,
            p_updated_by,
            SYSTIMESTAMP
        );
    END IF;
    
    -- Success
    COMMIT;
    p_success := TRUE;
    p_message := 'Order status updated from ' || v_old_status || ' to ' || p_new_status;
    DBMS_OUTPUT.PUT_LINE('DEBUG: Success! ' || p_message);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO before_update;
        p_success := FALSE;
        p_message := 'Error: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE('DEBUG: Exception: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('DEBUG: Error Code: ' || SQLCODE);
END proc_update_order_status;
/





-- ============================================
-- DIAGNOSTIC TEST SCRIPT
-- ============================================

SET SERVEROUTPUT ON

DECLARE
    v_success BOOLEAN;
    v_message VARCHAR2(4000);
    v_order_id NUMBER;
    
    -- Check current order status
    PROCEDURE check_order_status(p_order_id NUMBER) IS
        v_status VARCHAR2(20);
        v_date DATE;
    BEGIN
        BEGIN
            SELECT status, order_date 
            INTO v_status, v_date
            FROM orders 
            WHERE order_id = p_order_id;
            
            DBMS_OUTPUT.PUT_LINE('Current order ' || p_order_id || ':');
            DBMS_OUTPUT.PUT_LINE('  Status: ' || v_status);
            DBMS_OUTPUT.PUT_LINE('  Date: ' || TO_CHAR(v_date, 'YYYY-MM-DD HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('  Age (hours): ' || ROUND((SYSDATE - v_date) * 24, 2));
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Order ' || p_order_id || ' not found');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error checking order: ' || SQLERRM);
        END;
    END;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== DIAGNOSTIC TEST ===');
    
    -- Get the latest order
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    
    IF v_order_id IS NOT NULL THEN
        -- Check current state
        check_order_status(v_order_id);
        
        -- Test 1: Show all possible status values
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('=== Testing Status Validation ===');
        
        -- Check what status values exist
        DBMS_OUTPUT.PUT_LINE('All status values in orders table:');
        FOR r IN (SELECT DISTINCT status FROM orders ORDER BY status) LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || r.status);
        END LOOP;
        
        -- Test the procedure with current order
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('=== Testing PROC_UPDATE_ORDER_STATUS ===');
        
        -- First, let's see what the current status is
        DECLARE
            v_current_status VARCHAR2(20);
        BEGIN
            SELECT status INTO v_current_status
            FROM orders WHERE order_id = v_order_id;
            
            DBMS_OUTPUT.PUT_LINE('Current status: ' || v_current_status);
            
            -- Try to update to a valid next status
            IF v_current_status = 'PENDING' THEN
                proc_update_order_status(
                    p_order_id => v_order_id,
                    p_new_status => 'PROCESSING',
                    p_updated_by => 'DIAGNOSTIC_TEST',
                    p_success => v_success,
                    p_message => v_message
                );
            ELSIF v_current_status = 'PROCESSING' THEN
                -- Create a shipment first
                BEGIN
                    INSERT INTO shipments (
                        shipment_id, order_id, carrier, tracking_number, status
                    )
                    VALUES (
                        shipment_seq.NEXTVAL, v_order_id, 'UPS', 'TEST123', 'PENDING'
                    );
                    COMMIT;
                    DBMS_OUTPUT.PUT_LINE('Created test shipment');
                EXCEPTION
                    WHEN OTHERS THEN NULL;
                END;
                
                proc_update_order_status(
                    p_order_id => v_order_id,
                    p_new_status => 'SHIPPED',
                    p_updated_by => 'DIAGNOSTIC_TEST',
                    p_success => v_success,
                    p_message => v_message
                );
            ELSE
                DBMS_OUTPUT.PUT_LINE('Cannot test from status: ' || v_current_status);
                RETURN;
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('Result: ' || v_message);
            DBMS_OUTPUT.PUT_LINE('Success: ' || CASE WHEN v_success THEN 'YES' ELSE 'NO' END);
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Order not found');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        END;
        
    ELSE
        DBMS_OUTPUT.PUT_LINE('No orders found. Creating a test order...');
        
        -- Create a test order
        DECLARE
            v_err_msg VARCHAR2(4000);
            v_ids SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1);
            v_qty SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1);
        BEGIN
            proc_create_order(
                p_customer_id => 1001,
                p_product_ids => v_ids,
                p_quantities => v_qty,
                p_shipping_addr => '123 Test St',
                p_order_id => v_order_id,
                p_error_msg => v_err_msg
            );
            
            IF v_err_msg = 'SUCCESS' THEN
                DBMS_OUTPUT.PUT_LINE('Created test order: ' || v_order_id);
                
                -- Now test the update
                proc_update_order_status(
                    p_order_id => v_order_id,
                    p_new_status => 'PROCESSING',
                    p_updated_by => 'TEST_USER',
                    p_success => v_success,
                    p_message => v_message
                );
                
                DBMS_OUTPUT.PUT_LINE('Update Result: ' || v_message);
                DBMS_OUTPUT.PUT_LINE('Success: ' || CASE WHEN v_success THEN 'YES' ELSE 'NO' END);
            ELSE
                DBMS_OUTPUT.PUT_LINE('Failed to create order: ' || v_err_msg);
            END IF;
        END;
    END IF;
    
    -- Show audit trail
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== AUDIT TRAIL ===');
    
    FOR a IN (
        SELECT audit_id, action_type, old_value, new_value, changed_by,
               TO_CHAR(change_timestamp, 'YYYY-MM-DD HH24:MI:SS') as change_time
        FROM audit_log 
        WHERE table_name = 'ORDERS' 
        ORDER BY audit_id DESC
        FETCH FIRST 5 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(a.audit_id || ': ' || a.action_type || ' - ' || 
                           a.old_value || ' -> ' || a.new_value || 
                           ' by ' || a.changed_by || ' at ' || a.change_time);
    END LOOP;
    
END;
/
