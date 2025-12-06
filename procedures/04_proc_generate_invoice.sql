-- ============================================
-- PROCEDURE 4: GENERATE INVOICE FOR ORDER (FIXED)
-- ============================================

CREATE OR REPLACE PROCEDURE proc_generate_invoice(
    p_order_id      IN NUMBER,
    p_include_tax   IN BOOLEAN DEFAULT TRUE,
    p_output_type   IN VARCHAR2 DEFAULT 'SCREEN',  -- 'SCREEN', 'TEXT', 'HTML'
    p_invoice_text  OUT CLOB,
    p_success       OUT BOOLEAN,
    p_message       OUT VARCHAR2
)
IS
    -- Record types for invoice data
    v_order_id          NUMBER;
    v_customer_id       NUMBER;
    v_customer_name     VARCHAR2(100);
    v_customer_email    VARCHAR2(100);
    v_customer_address  VARCHAR2(200);
    v_customer_city     VARCHAR2(50);
    v_customer_country  VARCHAR2(50);
    v_order_date        DATE;
    v_order_status      VARCHAR2(20);
    v_total_amount      NUMBER;
    v_discount_amount   NUMBER;
    v_tax_amount        NUMBER;
    v_net_amount        NUMBER;
    v_shipping_address  VARCHAR2(200);
    v_billing_address   VARCHAR2(200);
    v_payment_status    VARCHAR2(20);
    
    -- For invoice items
    TYPE t_invoice_item IS RECORD (
        line_number   NUMBER,
        product_name  VARCHAR2(100),
        quantity      NUMBER,
        unit_price    NUMBER,
        discount_pct  NUMBER,
        line_total    NUMBER
    );
    
    TYPE t_invoice_items IS TABLE OF t_invoice_item;
    v_invoice_items  t_invoice_items;
    
    -- Other variables
    v_invoice_number VARCHAR2(50);
    v_subtotal       NUMBER := 0;
    v_total_tax      NUMBER := 0;
    v_total_discount NUMBER := 0;
    v_grand_total    NUMBER := 0;
    v_payment_count  NUMBER := 0;
    v_paid_amount    NUMBER := 0;
    v_balance_due    NUMBER := 0;
    v_text_output    CLOB;
    
    -- Cursor for invoice items
    CURSOR c_invoice_items IS
        SELECT 
            ROW_NUMBER() OVER (ORDER BY oi.order_item_id) AS line_number,
            p.product_name,
            oi.quantity,
            oi.unit_price,
            oi.discount_percent,
            oi.line_total
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        WHERE oi.order_id = p_order_id
        ORDER BY oi.order_item_id;
    
    -- Function to format currency
    FUNCTION format_currency(p_amount NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN '$' || TO_CHAR(p_amount, 'FM999,999,999.00');
    END format_currency;
    
    -- Function to format date
    FUNCTION format_date(p_date DATE) RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(p_date, 'Mon DD, YYYY');
    END format_date;
    
    -- Function to generate text invoice
    FUNCTION generate_text_invoice RETURN CLOB IS
        v_text CLOB;
        v_line_text VARCHAR2(4000);
    BEGIN
        -- Start building invoice text
        v_text := '==================================================' || CHR(10) ||
                  '                   INVOICE                         ' || CHR(10) ||
                  '==================================================' || CHR(10) ||
                  'Invoice #: ' || v_invoice_number || CHR(10) ||
                  'Order #: ' || p_order_id || CHR(10) ||
                  'Date: ' || format_date(v_order_date) || CHR(10) ||
                  'Status: ' || v_order_status || CHR(10) ||
                  'Payment Status: ' || v_payment_status || CHR(10) ||
                  CHR(10) ||
                  'BILL TO:' || CHR(10) ||
                  '--------' || CHR(10) ||
                  v_customer_name || CHR(10) ||
                  v_customer_email || CHR(10) ||
                  v_customer_address || ', ' || v_customer_city || ', ' || v_customer_country || CHR(10) ||
                  CHR(10) ||
                  'SHIP TO:' || CHR(10) ||
                  '--------' || CHR(10) ||
                  v_shipping_address || CHR(10) ||
                  CHR(10) ||
                  '==================================================' || CHR(10) ||
                  'Line  Description                     Qty  Price      Total' || CHR(10) ||
                  '----  ------------------------------  ---  ---------  ----------' || CHR(10);
        
        -- Add invoice items
        FOR i IN 1..v_invoice_items.COUNT LOOP
            v_line_text := LPAD(v_invoice_items(i).line_number, 4) || '  ' ||
                          RPAD(SUBSTR(v_invoice_items(i).product_name, 1, 30), 31) || '  ' ||
                          LPAD(v_invoice_items(i).quantity, 3) || '  ' ||
                          LPAD(format_currency(v_invoice_items(i).unit_price), 9) || '  ' ||
                          LPAD(format_currency(v_invoice_items(i).line_total), 10) || CHR(10);
            
            v_text := v_text || v_line_text;
        END LOOP;
        
        -- Add totals
        v_text := v_text ||
                  '==================================================' || CHR(10) ||
                  'Subtotal:                                       ' || 
                  LPAD(format_currency(v_subtotal), 13) || CHR(10) ||
                  'Discount:                                       ' || 
                  LPAD(format_currency(v_total_discount), 13) || CHR(10);
        
        IF p_include_tax THEN
            v_text := v_text ||
                      'Tax (' || ROUND((v_total_tax/v_subtotal)*100, 2) || '%):' || 
                      '                                       ' || 
                      LPAD(format_currency(v_total_tax), 13) || CHR(10);
        END IF;
        
        v_text := v_text ||
                  '--------------------------------------------------' || CHR(10) ||
                  'Total:                                          ' || 
                  LPAD(format_currency(v_grand_total), 13) || CHR(10) ||
                  CHR(10) ||
                  'Payment Summary:' || CHR(10) ||
                  '----------------' || CHR(10) ||
                  'Amount Paid:                                    ' || 
                  LPAD(format_currency(v_paid_amount), 13) || CHR(10) ||
                  'Balance Due:                                    ' || 
                  LPAD(format_currency(v_balance_due), 13) || CHR(10) ||
                  '==================================================' || CHR(10) ||
                  CHR(10) ||
                  'Thank you for your business!' || CHR(10) ||
                  'Please pay within 30 days.' || CHR(10) ||
                  'For questions, contact: sales@company.com' || CHR(10);
        
        RETURN v_text;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Error generating invoice text: ' || SQLERRM;
    END generate_text_invoice;
    
    -- Function to generate HTML invoice
    FUNCTION generate_html_invoice RETURN CLOB IS
        v_html CLOB;
    BEGIN
        v_html := '<!DOCTYPE html>' || CHR(10) ||
                  '<html>' || CHR(10) ||
                  '<head>' || CHR(10) ||
                  '<title>Invoice ' || v_invoice_number || '</title>' || CHR(10) ||
                  '<style>' || CHR(10) ||
                  '  body { font-family: Arial, sans-serif; margin: 40px; }' || CHR(10) ||
                  '  .invoice-header { border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }' || CHR(10) ||
                  '  .invoice-details { margin-bottom: 30px; }' || CHR(10) ||
                  '  table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }' || CHR(10) ||
                  '  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }' || CHR(10) ||
                  '  th { background-color: #f2f2f2; }' || CHR(10) ||
                  '  .total-section { float: right; width: 300px; }' || CHR(10) ||
                  '  .amount { text-align: right; }' || CHR(10) ||
                  '</style>' || CHR(10) ||
                  '</head>' || CHR(10) ||
                  '<body>' || CHR(10) ||
                  '<div class="invoice-header">' || CHR(10) ||
                  '<h1>INVOICE</h1>' || CHR(10) ||
                  '<p>Invoice #: ' || v_invoice_number || '</p>' || CHR(10) ||
                  '<p>Order #: ' || p_order_id || '</p>' || CHR(10) ||
                  '<p>Date: ' || format_date(v_order_date) || '</p>' || CHR(10) ||
                  '<p>Status: ' || v_order_status || '</p>' || CHR(10) ||
                  '</div>' || CHR(10) ||
                  CHR(10) ||
                  '<div class="invoice-details">' || CHR(10) ||
                  '<div style="float: left; width: 45%;">' || CHR(10) ||
                  '<h3>Bill To:</h3>' || CHR(10) ||
                  '<p>' || v_customer_name || '<br>' || CHR(10) ||
                  v_customer_email || '<br>' || CHR(10) ||
                  v_customer_address || ', ' || v_customer_city || ', ' || v_customer_country || '</p>' || CHR(10) ||
                  '</div>' || CHR(10) ||
                  CHR(10) ||
                  '<div style="float: right; width: 45%;">' || CHR(10) ||
                  '<h3>Ship To:</h3>' || CHR(10) ||
                  '<p>' || v_shipping_address || '</p>' || CHR(10) ||
                  '</div>' || CHR(10) ||
                  '<div style="clear: both;"></div>' || CHR(10) ||
                  '</div>' || CHR(10) ||
                  CHR(10) ||
                  '<table>' || CHR(10) ||
                  '<tr>' || CHR(10) ||
                  '<th>#</th>' || CHR(10) ||
                  '<th>Product</th>' || CHR(10) ||
                  '<th>Quantity</th>' || CHR(10) ||
                  '<th>Unit Price</th>' || CHR(10) ||
                  '<th>Total</th>' || CHR(10) ||
                  '</tr>' || CHR(10);
        
        -- Add items
        FOR i IN 1..v_invoice_items.COUNT LOOP
            v_html := v_html ||
                     '<tr>' || CHR(10) ||
                     '<td>' || v_invoice_items(i).line_number || '</td>' || CHR(10) ||
                     '<td>' || v_invoice_items(i).product_name || '</td>' || CHR(10) ||
                     '<td>' || v_invoice_items(i).quantity || '</td>' || CHR(10) ||
                     '<td>' || format_currency(v_invoice_items(i).unit_price) || '</td>' || CHR(10) ||
                     '<td>' || format_currency(v_invoice_items(i).line_total) || '</td>' || CHR(10) ||
                     '</tr>' || CHR(10);
        END LOOP;
        
        v_html := v_html ||
                  '</table>' || CHR(10) ||
                  CHR(10) ||
                  '<div class="total-section">' || CHR(10) ||
                  '<table>' || CHR(10) ||
                  '<tr>' || CHR(10) ||
                  '<td><strong>Subtotal:</strong></td>' || CHR(10) ||
                  '<td class="amount">' || format_currency(v_subtotal) || '</td>' || CHR(10) ||
                  '</tr>' || CHR(10) ||
                  '<tr>' || CHR(10) ||
                  '<td><strong>Discount:</strong></td>' || CHR(10) ||
                  '<td class="amount">' || format_currency(v_total_discount) || '</td>' || CHR(10) ||
                  '</tr>' || CHR(10);
        
        IF p_include_tax THEN
            v_html := v_html ||
                      '<tr>' || CHR(10) ||
                      '<td><strong>Tax (' || ROUND((v_total_tax/v_subtotal)*100, 2) || '%):</strong></td>' || CHR(10) ||
                      '<td class="amount">' || format_currency(v_total_tax) || '</td>' || CHR(10) ||
                      '</tr>' || CHR(10);
        END IF;
        
        v_html := v_html ||
                  '<tr style="border-top: 2px solid #333;">' || CHR(10) ||
                  '<td><strong>Total:</strong></td>' || CHR(10) ||
                  '<td class="amount"><strong>' || format_currency(v_grand_total) || '</strong></td>' || CHR(10) ||
                  '</tr>' || CHR(10) ||
                  '<tr>' || CHR(10) ||
                  '<td><strong>Amount Paid:</strong></td>' || CHR(10) ||
                  '<td class="amount">' || format_currency(v_paid_amount) || '</td>' || CHR(10) ||
                  '</tr>' || CHR(10) ||
                  '<tr>' || CHR(10) ||
                  '<td><strong>Balance Due:</strong></td>' || CHR(10) ||
                  '<td class="amount"><strong>' || format_currency(v_balance_due) || '</strong></td>' || CHR(10) ||
                  '</tr>' || CHR(10) ||
                  '</table>' || CHR(10) ||
                  '</div>' || CHR(10) ||
                  CHR(10) ||
                  '<div style="clear: both; margin-top: 50px;">' || CHR(10) ||
                  '<p>Thank you for your business! Please pay within 30 days.</p>' || CHR(10) ||
                  '<p>For questions, contact: sales@company.com</p>' || CHR(10) ||
                  '</div>' || CHR(10) ||
                  '</body>' || CHR(10) ||
                  '</html>';
        
        RETURN v_html;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '<html><body>Error generating HTML invoice: ' || SQLERRM || '</body></html>';
    END generate_html_invoice;
    
BEGIN
    -- Initialize outputs
    p_success := FALSE;
    p_message := NULL;
    p_invoice_text := NULL;
    
    DBMS_OUTPUT.PUT_LINE('Generating invoice for Order ID: ' || p_order_id);
    
    -- Step 1: Get order information
    BEGIN
        SELECT 
            o.order_id,
            o.customer_id,
            c.customer_name,
            c.email,
            c.address,
            c.city,
            c.country,
            o.order_date,
            o.status,
            o.total_amount,
            o.discount_amount,
            o.tax_amount,
            o.net_amount,
            o.shipping_address,
            o.billing_address,
            NVL((SELECT MAX(status) FROM payments WHERE order_id = o.order_id), 'UNPAID')
        INTO 
            v_order_id,
            v_customer_id,
            v_customer_name,
            v_customer_email,
            v_customer_address,
            v_customer_city,
            v_customer_country,
            v_order_date,
            v_order_status,
            v_total_amount,
            v_discount_amount,
            v_tax_amount,
            v_net_amount,
            v_shipping_address,
            v_billing_address,
            v_payment_status
        FROM orders o
        JOIN customers c ON o.customer_id = c.customer_id
        WHERE o.order_id = p_order_id;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_message := 'Order ID ' || p_order_id || ' not found';
            RETURN;
    END;
    
    -- Step 2: Get invoice items
    OPEN c_invoice_items;
    FETCH c_invoice_items BULK COLLECT INTO v_invoice_items;
    CLOSE c_invoice_items;
    
    IF v_invoice_items.COUNT = 0 THEN
        p_message := 'No items found for order ' || p_order_id;
        RETURN;
    END IF;
    
    -- Step 3: Calculate totals
    FOR i IN 1..v_invoice_items.COUNT LOOP
        v_subtotal := v_subtotal + (v_invoice_items(i).quantity * v_invoice_items(i).unit_price);
        v_total_discount := v_total_discount + 
            ((v_invoice_items(i).quantity * v_invoice_items(i).unit_price) * 
             v_invoice_items(i).discount_pct / 100);
    END LOOP;
    
    -- Use stored tax amount or calculate if needed
    v_total_tax := v_tax_amount;
    IF v_total_tax IS NULL AND p_include_tax THEN
        v_total_tax := v_subtotal * 0.08; -- 8% tax if not stored
    END IF;
    
    v_grand_total := v_subtotal - v_total_discount + v_total_tax;
    
    -- Step 4: Get payment information
    SELECT 
        COUNT(*),
        NVL(SUM(amount), 0)
    INTO 
        v_payment_count,
        v_paid_amount
    FROM payments 
    WHERE order_id = p_order_id 
      AND status = 'COMPLETED';
    
    v_balance_due := v_grand_total - v_paid_amount;
    
    -- Step 5: Generate invoice number
    v_invoice_number := 'INV-' || TO_CHAR(v_order_date, 'YYYYMM') || 
                       '-' || LPAD(p_order_id, 6, '0');
    
    -- Step 6: Generate invoice text based on output type
    IF UPPER(p_output_type) = 'SCREEN' OR UPPER(p_output_type) = 'TEXT' THEN
        p_invoice_text := generate_text_invoice();
    ELSIF UPPER(p_output_type) = 'HTML' THEN
        p_invoice_text := generate_html_invoice();
    ELSE
        p_message := 'Invalid output type: ' || p_output_type;
        RETURN;
    END IF;
    
    -- Step 7: Display to screen if requested
    IF UPPER(p_output_type) = 'SCREEN' THEN
        DBMS_OUTPUT.PUT_LINE('===============================================');
        DBMS_OUTPUT.PUT_LINE('               INVOICE GENERATED               ');
        DBMS_OUTPUT.PUT_LINE('===============================================');
        DBMS_OUTPUT.PUT_LINE('Invoice #: ' || v_invoice_number);
        DBMS_OUTPUT.PUT_LINE('Order #: ' || p_order_id);
        DBMS_OUTPUT.PUT_LINE('Date: ' || format_date(v_order_date));
        DBMS_OUTPUT.PUT_LINE('Status: ' || v_order_status);
        DBMS_OUTPUT.PUT_LINE('Payment Status: ' || v_payment_status);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Customer: ' || v_customer_name);
        DBMS_OUTPUT.PUT_LINE('Email: ' || v_customer_email);
        DBMS_OUTPUT.PUT_LINE('Address: ' || v_customer_address || ', ' || v_customer_city || ', ' || v_customer_country);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Shipping Address: ' || v_shipping_address);
        DBMS_OUTPUT.PUT_LINE('Billing Address: ' || v_billing_address);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Line  Product                     Qty  Price      Total');
        DBMS_OUTPUT.PUT_LINE('----  -------------------------  ----  ---------  ----------');
        
        FOR i IN 1..v_invoice_items.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(
                LPAD(v_invoice_items(i).line_number, 4) || '  ' ||
                RPAD(SUBSTR(v_invoice_items(i).product_name, 1, 25), 26) || '  ' ||
                LPAD(v_invoice_items(i).quantity, 4) || '  ' ||
                LPAD(format_currency(v_invoice_items(i).unit_price), 9) || '  ' ||
                LPAD(format_currency(v_invoice_items(i).line_total), 10)
            );
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Subtotal:                             ' || LPAD(format_currency(v_subtotal), 21));
        DBMS_OUTPUT.PUT_LINE('Discount:                             ' || LPAD(format_currency(v_total_discount), 21));
        
        IF p_include_tax THEN
            DBMS_OUTPUT.PUT_LINE('Tax (' || ROUND((v_total_tax/v_subtotal)*100, 2) || '%):' || 
                               '                          ' || LPAD(format_currency(v_total_tax), 21));
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Grand Total:                          ' || LPAD(format_currency(v_grand_total), 21));
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Amount Paid:                          ' || LPAD(format_currency(v_paid_amount), 21));
        DBMS_OUTPUT.PUT_LINE('Balance Due:                          ' || LPAD(format_currency(v_balance_due), 21));
        DBMS_OUTPUT.PUT_LINE('===============================================');
    END IF;
    
    -- Step 8: Create invoice record (if invoices table exists)
    BEGIN
        INSERT INTO invoices (
            invoice_id,
            invoice_number,
            order_id,
            invoice_date,
            customer_id,
            subtotal_amount,
            discount_amount,
            tax_amount,
            total_amount,
            payment_status,
            generated_by,
            generation_date
        )
        VALUES (
            NVL((SELECT MAX(invoice_id) + 1 FROM invoices), 1000),
            v_invoice_number,
            p_order_id,
            SYSDATE,
            v_customer_id,
            v_subtotal,
            v_total_discount,
            v_total_tax,
            v_grand_total,
            v_payment_status,
            USER,
            SYSTIMESTAMP
        );
        
        DBMS_OUTPUT.PUT_LINE('Invoice saved to database');
    EXCEPTION
        WHEN OTHERS THEN
            -- If invoices table doesn't exist, just continue
            DBMS_OUTPUT.PUT_LINE('Note: Invoices table not found, invoice not saved to database');
    END;
    
    -- Success
    COMMIT;
    p_success := TRUE;
    p_message := 'Invoice ' || v_invoice_number || ' generated successfully for order ' || p_order_id;
    
    DBMS_OUTPUT.PUT_LINE(p_message);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_success := FALSE;
        p_message := 'Error generating invoice: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
END proc_generate_invoice;
/






-- ============================================
-- SIMPLE TEST FOR PROC_GENERATE_INVOICE
-- ============================================

SET SERVEROUTPUT ON

DECLARE
    v_invoice_text CLOB;
    v_success      BOOLEAN;
    v_message      VARCHAR2(4000);
    v_order_id     NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing invoice generation...');
    
    -- Get any order with items
    BEGIN
        SELECT MIN(order_id) INTO v_order_id
        FROM orders o
        WHERE EXISTS (
            SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id
        );
        
        DBMS_OUTPUT.PUT_LINE('Found order ID: ' || v_order_id);
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No orders found. Creating test order...');
            
            -- Create simple test order
            INSERT INTO orders (
                order_id, customer_id, order_date, status,
                total_amount, discount_amount, tax_amount,
                shipping_address, billing_address
            )
            VALUES (
                9999, 1001, SYSDATE, 'DELIVERED',
                129.97, 10.00, 9.60,
                '123 Test St, Test City', '123 Test St, Test City'
            );
            
            INSERT INTO order_items (
                order_item_id, order_id, product_id, quantity, unit_price, discount_percent
            )
            VALUES (99991, 9999, 1, 1, 99.99, 5);
            
            INSERT INTO order_items (
                order_item_id, order_id, product_id, quantity, unit_price, discount_percent
            )
            VALUES (99992, 9999, 2, 1, 29.99, 0);
            
            v_order_id := 9999;
            COMMIT;
    END;
    
    -- Generate invoice
    proc_generate_invoice(
        p_order_id      => v_order_id,
        p_include_tax   => TRUE,
        p_output_type   => 'SCREEN',
        p_invoice_text  => v_invoice_text,
        p_success       => v_success,
        p_message       => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test Result:');
    DBMS_OUTPUT.PUT_LINE('Success: ' || CASE WHEN v_success THEN 'YES' ELSE 'NO' END);
    DBMS_OUTPUT.PUT_LINE('Message: ' || v_message);
    
    -- Show if invoice text was generated
    IF v_invoice_text IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Invoice text length: ' || DBMS_LOB.GETLENGTH(v_invoice_text) || ' characters');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('You may need to create the invoices table first.');
END;
/
