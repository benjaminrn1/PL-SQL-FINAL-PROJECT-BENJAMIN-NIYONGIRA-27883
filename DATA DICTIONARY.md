# DATA DICTIONARY
## Customer Order & Sales Analytics System
**Student:** Benjamin Niyongira  (ID: 27883)
**Date:** November 2025

---

## TABLE 1: CUSTOMERS
**Description:** Stores information about customers who place orders

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| CUSTOMER_ID | NUMBER | 10 | NOT NULL | PK | - | Unique identifier for each customer |
| CUSTOMER_NAME | VARCHAR2 | 100 | NOT NULL | - | - | Full name of the customer |
| EMAIL | VARCHAR2 | 100 | NOT NULL | UNIQUE | - | Email address for communication |
| PHONE | VARCHAR2 | 20 | NULL | - | - | Contact phone number |
| ADDRESS | VARCHAR2 | 200 | NULL | - | - | Street address |
| CITY | VARCHAR2 | 50 | NULL | - | - | City of residence |
| COUNTRY | VARCHAR2 | 50 | NULL | - | 'USA' | Country (defaults to USA) |
| JOIN_DATE | DATE | - | NOT NULL | - | SYSDATE | Date customer registered |
| CUSTOMER_SEGMENT | VARCHAR2 | 20 | NOT NULL | CHECK | 'BRONZE' | Customer tier level |
| TOTAL_SPENT | NUMBER | 12,2 | NOT NULL | - | 0 | Total amount spent by customer |
| LAST_ORDER_DATE | DATE | - | NULL | - | - | Date of most recent order |

**Business Rules:**
1. CUSTOMER_SEGMENT must be: BRONZE, SILVER, GOLD, or PLATINUM
2. EMAIL must be unique across all customers
3. JOIN_DATE cannot be in the future
4. TOTAL_SPENT must be ≥ 0

---

## TABLE 2: PRODUCTS
**Description:** Stores information about products available for sale

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| PRODUCT_ID | NUMBER | 10 | NOT NULL | PK | - | Unique identifier for each product |
| PRODUCT_NAME | VARCHAR2 | 100 | NOT NULL | - | - | Name of the product |
| CATEGORY_ID | NUMBER | 10 | NOT NULL | FK → CATEGORIES | - | Product category |
| UNIT_PRICE | NUMBER | 10,2 | NOT NULL | CHECK > 0 | - | Current selling price |
| UNIT_COST | NUMBER | 10,2 | NOT NULL | CHECK > 0 | - | Purchase cost from supplier |
| SUPPLIER_ID | NUMBER | 10 | NOT NULL | FK → SUPPLIERS | - | Supplier of the product |
| STOCK_QUANTITY | NUMBER | 10 | NOT NULL | - | 0 | Current inventory count |
| REORDER_LEVEL | NUMBER | 10 | NOT NULL | - | 10 | Minimum stock before reorder |
| STATUS | VARCHAR2 | 20 | NOT NULL | CHECK | 'ACTIVE' | Product status |
| CREATED_DATE | DATE | - | NOT NULL | - | SYSDATE | Date product was added |

**Business Rules:**
1. UNIT_PRICE must be greater than UNIT_COST
2. STATUS must be: ACTIVE, DISCONTINUED, or OUT_OF_STOCK
3. REORDER_LEVEL must be ≥ 0
4. STOCK_QUANTITY must be ≥ 0

---

## TABLE 3: ORDERS
**Description:** Stores order header information

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| ORDER_ID | NUMBER | 10 | NOT NULL | PK | - | Unique order identifier |
| CUSTOMER_ID | NUMBER | 10 | NOT NULL | FK → CUSTOMERS | - | Customer who placed order |
| ORDER_DATE | DATE | - | NOT NULL | - | SYSDATE | Date order was placed |
| STATUS | VARCHAR2 | 20 | NOT NULL | CHECK | 'PENDING' | Current order status |
| TOTAL_AMOUNT | NUMBER | 12,2 | NOT NULL | CHECK > 0 | - | Gross order amount |
| DISCOUNT_AMOUNT | NUMBER | 10,2 | NOT NULL | - | 0 | Discount applied |
| TAX_AMOUNT | NUMBER | 10,2 | NOT NULL | - | 0 | Tax calculated |
| NET_AMOUNT | NUMBER | 12,2 | NOT NULL | - | - | Final payable amount |
| SHIPPING_ADDRESS | VARCHAR2 | 200 | NOT NULL | - | - | Delivery address |
| BILLING_ADDRESS | VARCHAR2 | 200 | NOT NULL | - | - | Billing address |
| EMPLOYEE_ID | NUMBER | 10 | NULL | FK → EMPLOYEES | - | Sales representative |

**Business Rules:**
1. STATUS must follow sequence: PENDING → PROCESSING → SHIPPED → DELIVERED
2. NET_AMOUNT = TOTAL_AMOUNT - DISCOUNT_AMOUNT + TAX_AMOUNT
3. ORDER_DATE cannot be in the future
4. DISCOUNT_AMOUNT cannot exceed 50% of TOTAL_AMOUNT

---

## TABLE 4: ORDER_ITEMS
**Description:** Stores individual line items within an order

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| ORDER_ITEM_ID | NUMBER | 10 | NOT NULL | PK | - | Unique line item identifier |
| ORDER_ID | NUMBER | 10 | NOT NULL | FK → ORDERS | - | Parent order reference |
| PRODUCT_ID | NUMBER | 10 | NOT NULL | FK → PRODUCTS | - | Product ordered |
| QUANTITY | NUMBER | 5 | NOT NULL | CHECK > 0 | - | Quantity ordered |
| UNIT_PRICE | NUMBER | 10,2 | NOT NULL | CHECK > 0 | - | Price at time of order |
| DISCOUNT_PERCENT | NUMBER | 5,2 | NOT NULL | - | 0 | Line item discount percentage |
| LINE_TOTAL | NUMBER | 12,2 | NOT NULL | - | - | Calculated line total |

**Business Rules:**
1. LINE_TOTAL = QUANTITY × UNIT_PRICE × (1 - DISCOUNT_PERCENT/100)
2. DISCOUNT_PERCENT must be between 0 and 100
3. QUANTITY must be ≥ 1
4. UNIT_PRICE must match PRODUCTS.UNIT_PRICE at order time

---

## TABLE 5: PAYMENTS
**Description:** Stores payment transactions for orders

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| PAYMENT_ID | NUMBER | 10 | NOT NULL | PK | - | Unique payment identifier |
| ORDER_ID | NUMBER | 10 | NOT NULL | FK → ORDERS | - | Associated order |
| PAYMENT_DATE | DATE | - | NOT NULL | - | SYSDATE | Date payment was made |
| AMOUNT | NUMBER | 10,2 | NOT NULL | CHECK > 0 | - | Payment amount |
| PAYMENT_METHOD | VARCHAR2 | 30 | NOT NULL | CHECK | - | Payment type |
| TRANSACTION_ID | VARCHAR2 | 50 | NULL | UNIQUE | - | Gateway transaction ID |
| STATUS | VARCHAR2 | 20 | NOT NULL | CHECK | 'PENDING' | Payment status |
| AUTHORIZATION_CODE | VARCHAR2 | 50 | NULL | - | - | Bank authorization code |

**Business Rules:**
1. PAYMENT_METHOD must be: CREDIT_CARD, DEBIT_CARD, PAYPAL, BANK_TRANSFER, or CASH
2. STATUS must be: PENDING, COMPLETED, FAILED, or REFUNDED
3. AMOUNT cannot exceed order NET_AMOUNT
4. TRANSACTION_ID must be unique if provided

---

## TABLE 6: SHIPMENTS
**Description:** Stores shipping and delivery information

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| SHIPMENT_ID | NUMBER | 10 | NOT NULL | PK | - | Unique shipment identifier |
| ORDER_ID | NUMBER | 10 | NOT NULL | FK → ORDERS | - | Associated order |
| SHIP_DATE | DATE | - | NULL | - | - | Date shipped |
| CARRIER | VARCHAR2 | 50 | NULL | - | - | Shipping company |
| TRACKING_NUMBER | VARCHAR2 | 100 | NULL | UNIQUE | - | Package tracking number |
| ESTIMATED_DELIVERY | DATE | - | NULL | - | - | Expected delivery date |
| ACTUAL_DELIVERY | DATE | - | NULL | - | - | Actual delivery date |
| SHIPPING_COST | NUMBER | 10,2 | NOT NULL | - | 0 | Shipping charge |
| STATUS | VARCHAR2 | 20 | NOT NULL | CHECK | 'PENDING' | Shipment status |

**Business Rules:**
1. STATUS must be: PENDING, PROCESSING, SHIPPED, IN_TRANSIT, DELIVERED, or RETURNED
2. SHIP_DATE cannot be in the future
3. ACTUAL_DELIVERY cannot be before SHIP_DATE
4. Free shipping if ORDER.NET_AMOUNT > 100

---

## TABLE 7: EMPLOYEES
**Description:** Stores employee information

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| EMPLOYEE_ID | NUMBER | 10 | NOT NULL | PK | - | Unique employee identifier |
| EMPLOYEE_NAME | VARCHAR2 | 100 | NOT NULL | - | - | Full name of employee |
| DEPARTMENT | VARCHAR2 | 50 | NOT NULL | CHECK | - | Department name |
| POSITION | VARCHAR2 | 50 | NOT NULL | - | - | Job title |
| HIRE_DATE | DATE | - | NOT NULL | - | SYSDATE | Employment start date |
| EMAIL | VARCHAR2 | 100 | NOT NULL | UNIQUE | - | Work email address |
| PHONE | VARCHAR2 | 20 | NULL | - | - | Work phone number |
| MANAGER_ID | NUMBER | 10 | NULL | FK → EMPLOYEES | - | Reporting manager |
| IS_ACTIVE | CHAR | 1 | NOT NULL | CHECK | 'Y' | Active status flag |

**Business Rules:**
1. DEPARTMENT must be: SALES, WAREHOUSE, FINANCE, ADMIN, or IT
2. IS_ACTIVE must be: 'Y' or 'N'
3. HIRE_DATE cannot be in the future
4. MANAGER_ID cannot reference self

---

## TABLE 8: SUPPLIERS
**Description:** Stores supplier/vendor information

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| SUPPLIER_ID | NUMBER | 10 | NOT NULL | PK | - | Unique supplier identifier |
| SUPPLIER_NAME | VARCHAR2 | 100 | NOT NULL | - | - | Company name |
| CONTACT_NAME | VARCHAR2 | 100 | NULL | - | - | Primary contact person |
| EMAIL | VARCHAR2 | 100 | NOT NULL | UNIQUE | - | Contact email |
| PHONE | VARCHAR2 | 20 | NULL | - | - | Contact phone |
| ADDRESS | VARCHAR2 | 200 | NULL | - | - | Business address |
| CITY | VARCHAR2 | 50 | NULL | - | - | City |
| COUNTRY | VARCHAR2 | 50 | NULL | - | 'USA' | Country |
| PAYMENT_TERMS | VARCHAR2 | 50 | NULL | - | 'NET30' | Payment terms |

**Business Rules:**
1. EMAIL must be unique across suppliers
2. PAYMENT_TERMS must be: NET15, NET30, NET45, or NET60
3. COUNTRY defaults to USA

---

## TABLE 9: CATEGORIES
**Description:** Stores product category information

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| CATEGORY_ID | NUMBER | 10 | NOT NULL | PK | - | Unique category identifier |
| CATEGORY_NAME | VARCHAR2 | 50 | NOT NULL | UNIQUE | - | Category name |
| PARENT_CATEGORY_ID | NUMBER | 10 | NULL | FK → CATEGORIES | - | Parent category for hierarchy |
| DESCRIPTION | VARCHAR2 | 500 | NULL | - | - | Category description |

**Business Rules:**
1. CATEGORY_NAME must be unique
2. PARENT_CATEGORY_ID cannot reference self
3. Maximum hierarchy depth: 3 levels

---

## TABLE 10: PROMOTIONS
**Description:** Stores promotional campaigns and discounts

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| PROMOTION_ID | NUMBER | 10 | NOT NULL | PK | - | Unique promotion identifier |
| PROMOTION_NAME | VARCHAR2 | 100 | NOT NULL | - | - | Promotion name |
| DISCOUNT_PERCENT | NUMBER | 5,2 | NOT NULL | CHECK | - | Discount percentage |
| START_DATE | DATE | - | NOT NULL | - | - | Promotion start date |
| END_DATE | DATE | - | NOT NULL | - | - | Promotion end date |
| MINIMUM_ORDER_AMOUNT | NUMBER | 10,2 | NULL | - | 0 | Minimum order to qualify |
| MAXIMUM_DISCOUNT | NUMBER | 10,2 | NULL | - | - | Maximum discount amount |
| APPLICABLE_CATEGORY_ID | NUMBER | 10 | NULL | FK → CATEGORIES | - | Applicable category |

**Business Rules:**
1. END_DATE must be after START_DATE
2. DISCOUNT_PERCENT must be between 1 and 100
3. Promotion must be active on ORDER_DATE to apply

---

## TABLE 11: AUDIT_LOG
**Description:** Tracks all system changes for auditing

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| AUDIT_ID | NUMBER | 10 | NOT NULL | PK | - | Unique audit record identifier |
| TABLE_NAME | VARCHAR2 | 50 | NOT NULL | - | - | Name of modified table |
| RECORD_ID | VARCHAR2 | 50 | NOT NULL | - | - | ID of modified record |
| ACTION_TYPE | VARCHAR2 | 20 | NOT NULL | CHECK | - | Type of operation |
| OLD_VALUE | CLOB | - | NULL | - | - | Previous value (JSON format) |
| NEW_VALUE | CLOB | - | NULL | - | - | New value (JSON format) |
| CHANGED_BY | VARCHAR2 | 50 | NOT NULL | - | USER | User who made change |
| CHANGE_TIMESTAMP | TIMESTAMP | - | NOT NULL | - | SYSTIMESTAMP | Time of change |
| IP_ADDRESS | VARCHAR2 | 50 | NULL | - | - | User's IP address |

**Business Rules:**
1. ACTION_TYPE must be: INSERT, UPDATE, or DELETE
2. CHANGE_TIMESTAMP cannot be in the future
3. OLD_VALUE is NULL for INSERT operations
4. NEW_VALUE is NULL for DELETE operations

---

## TABLE 12: HOLIDAYS
**Description:** Stores business holidays for restriction rules

| Column Name | Data Type | Size | Nullable | Constraints | Default | Description |
|-------------|-----------|------|----------|-------------|---------|-------------|
| HOLIDAY_ID | NUMBER | 10 | NOT NULL | PK | - | Unique holiday identifier |
| HOLIDAY_DATE | DATE | - | NOT NULL | UNIQUE | - | Holiday date |
| HOLIDAY_NAME | VARCHAR2 | 100 | NOT NULL | - | - | Name of holiday |
| DESCRIPTION | VARCHAR2 | 500 | NULL | - | - | Holiday description |
| IS_RECURRING | CHAR | 1 | NOT NULL | CHECK | 'N' | Recurring annual holiday |

**Business Rules:**
1. HOLIDAY_DATE must be unique
2. IS_RECURRING must be: 'Y' or 'N'
3. Holidays cannot be on weekends (handled by application)
