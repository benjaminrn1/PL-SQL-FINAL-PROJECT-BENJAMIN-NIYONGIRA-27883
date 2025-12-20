-- Trigger 1: SIMPLIFIED BEFORE INSERT Trigger
CREATE OR REPLACE TRIGGER orders_before_insert_restriction
BEFORE INSERT ON orders
FOR EACH ROW
DECLARE
    v_error_message VARCHAR2(500);
    v_audit_id NUMBER;
BEGIN
    -- Only check if employee_id is provided
    IF :NEW.employee_id IS NOT NULL THEN
        v_error_message := check_employee_restriction(:NEW.employee_id, 'INSERT');
        
        IF v_error_message IS NOT NULL THEN
            -- Log the blocked attempt
            v_audit_id := log_audit_entry(
                p_table_name => 'ORDERS',
                p_operation_type => 'BLOCKED',
                p_user_name => USER,
                p_new_values => 'Attempted INSERT: Emp ' || :NEW.employee_id || ', Cust ' || :NEW.customer_id,
                p_success_flag => 'N',
                p_error_message => v_error_message
            );
            
            -- Log to violations table (direct insert)
            INSERT INTO business_rule_violations (
                rule_name, user_name, table_name, operation_type,
                attempted_values, error_message
            ) VALUES (
                'WEEKDAY_HOLIDAY_RESTRICTION',
                USER,
                'ORDERS',
                'INSERT',
                'Emp_ID: ' || :NEW.employee_id || ', Cust_ID: ' || :NEW.customer_id,
                v_error_message
            );
            
            -- Raise application error to block the operation
            RAISE_APPLICATION_ERROR(-20050, v_error_message);
        ELSE
            -- Log successful check
            v_audit_id := log_audit_entry(
                p_table_name => 'ORDERS',
                p_operation_type => 'INSERT',
                p_user_name => USER,
                p_new_values => 'Employee ' || :NEW.employee_id || ' INSERT check passed'
            );
        END IF;
    END IF;
END orders_before_insert_restriction;
/

-- Trigger 2: SIMPLIFIED BEFORE UPDATE Trigger
CREATE OR REPLACE TRIGGER orders_before_update_restriction
BEFORE UPDATE ON orders
FOR EACH ROW
DECLARE
    v_error_message VARCHAR2(500);
    v_audit_id NUMBER;
    v_old_values_str VARCHAR2(500);
    v_new_values_str VARCHAR2(500);
BEGIN
    -- Only check if employee_id is being set or changed
    IF :NEW.employee_id IS NOT NULL THEN
        
        v_error_message := check_employee_restriction(:NEW.employee_id, 'UPDATE');
        
        IF v_error_message IS NOT NULL THEN
            -- Create strings for old and new values
            v_old_values_str := get_old_values_str(
                :OLD.order_id, :OLD.employee_id, :OLD.order_status, :OLD.total_amount
            );
            
            v_new_values_str := 'Order: ' || :NEW.order_id || 
                               ', Emp: ' || :NEW.employee_id || 
                               ', Status: ' || :NEW.order_status;
            
            -- Log the blocked attempt
            v_audit_id := log_audit_entry(
                p_table_name => 'ORDERS',
                p_operation_type => 'BLOCKED',
                p_user_name => USER,
                p_old_values => v_old_values_str,
                p_new_values => v_new_values_str,
                p_success_flag => 'N',
                p_error_message => v_error_message
            );
            
            -- Log to violations table
            INSERT INTO business_rule_violations (
                rule_name, user_name, table_name, operation_type,
                attempted_values, error_message
            ) VALUES (
                'WEEKDAY_HOLIDAY_RESTRICTION',
                USER,
                'ORDERS',
                'UPDATE',
                'Order: ' || :NEW.order_id || ', Emp: ' || :NEW.employee_id,
                v_error_message
            );
            
            -- Raise application error
            RAISE_APPLICATION_ERROR(-20051, v_error_message);
        END IF;
    END IF;
END orders_before_update_restriction;
/

-- Trigger 3: SIMPLIFIED BEFORE DELETE Trigger
CREATE OR REPLACE TRIGGER orders_before_delete_restriction
BEFORE DELETE ON orders
FOR EACH ROW
DECLARE
    v_error_message VARCHAR2(500);
    v_audit_id NUMBER;
    v_old_values_str VARCHAR2(500);
BEGIN
    -- Only check if order has an employee assigned
    IF :OLD.employee_id IS NOT NULL THEN
        v_error_message := check_employee_restriction(:OLD.employee_id, 'DELETE');
        
        IF v_error_message IS NOT NULL THEN
            -- Create string for old values
            v_old_values_str := get_old_values_str(
                :OLD.order_id, :OLD.employee_id, :OLD.order_status, :OLD.total_amount
            );
            
            -- Log the blocked attempt
            v_audit_id := log_audit_entry(
                p_table_name => 'ORDERS',
                p_operation_type => 'BLOCKED',
                p_user_name => USER,
                p_old_values => v_old_values_str,
                p_success_flag => 'N',
                p_error_message => v_error_message
            );
            
            -- Log to violations table
            INSERT INTO business_rule_violations (
                rule_name, user_name, table_name, operation_type,
                attempted_values, error_message
            ) VALUES (
                'WEEKDAY_HOLIDAY_RESTRICTION',
                USER,
                'ORDERS',
                'DELETE',
                'Order: ' || :OLD.order_id || ', Emp: ' || :OLD.employee_id,
                v_error_message
            );
            
            -- Raise application error
            RAISE_APPLICATION_ERROR(-20052, v_error_message);
        END IF;
    END IF;
END orders_before_delete_restriction;
/

-- Trigger 4: SIMPLIFIED Compound Trigger (Optional - can skip if too complex)
CREATE OR REPLACE TRIGGER orders_compound_audit_trigger
FOR INSERT OR UPDATE OR DELETE ON orders
COMPOUND TRIGGER

    -- Simple collection to count operations
    TYPE t_count_rec IS RECORD (
        inserts NUMBER := 0,
        updates NUMBER := 0,
        deletes NUMBER := 0
    );
    
    v_counts t_count_rec;
    
    -- Before each row
    BEFORE EACH ROW IS
    BEGIN
        NULL; -- Do nothing in before each row
    END BEFORE EACH ROW;
    
    -- After statement
    AFTER STATEMENT IS
        v_total_ops NUMBER;
    BEGIN
        v_total_ops := v_counts.inserts + v_counts.updates + v_counts.deletes;
        
        IF v_total_ops > 0 THEN
            -- Log batch operation
            log_audit_entry(
                p_table_name => 'ORDERS',
                p_operation_type => 'BATCH',
                p_user_name => USER,
                p_new_values => 'Batch: I=' || v_counts.inserts || 
                              ', U=' || v_counts.updates || 
                              ', D=' || v_counts.deletes
            );
        END IF;
        
        -- Reset counts
        v_counts.inserts := 0;
        v_counts.updates := 0;
        v_counts.deletes := 0;
        
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Silent fail for audit
    END AFTER STATEMENT;
    
    -- After each row (for counting)
    AFTER EACH ROW IS
    BEGIN
        IF INSERTING THEN
            v_counts.inserts := v_counts.inserts + 1;
        ELSIF UPDATING THEN
            v_counts.updates := v_counts.updates + 1;
        ELSIF DELETING THEN
            v_counts.deletes := v_counts.deletes + 1;
        END IF;
    END AFTER EACH ROW;
    
END orders_compound_audit_trigger;
/
