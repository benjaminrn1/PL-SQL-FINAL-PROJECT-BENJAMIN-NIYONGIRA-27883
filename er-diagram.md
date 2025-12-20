```
┌─────────────────────────────────────────────────────────┐
│               ER DIAGRAM LEGEND                         │
├─────────────────────────────────────────────────────────┤
│ (PK) = Primary Key    (FK) = Foreign Key    (UK) = Unique│
│ ┌────┐ = Entity       ────► = Relationship               │
└─────────────────────────────────────────────────────────┘

                           ┌─────────────────┐
                           │     ORDERS      │
                           │  (Transaction)  │
                           ├─────────────────┤
                           │ order_id (PK)   │
                           │ customer_id (FK)│◄─────┐
                           │ employee_id (FK)│◄──┐  │
                           │ order_date      │   │  │
                           │ total_amount    │   │  │
                           │ order_status    │   │  │
                           │ payment_status  │   │  │
                           └─────────────────┘   │  │
         1 │                 M │                1 │  │ 1
          ┌┴───────────────────┴┐                ┌┴──┴─┐
          │                     │                │     │
┌─────────────────┐   ┌─────────────────┐ ┌─────────────────┐
│   CUSTOMERS     │   │  ORDER_ITEMS    │ │   EMPLOYEES     │
│   (Master)      │   │   (Bridge)      │ │   (Master)      │
├─────────────────┤   ├─────────────────┤ ├─────────────────┤
│ customer_id (PK)│   │ order_item_id   │ │ employee_id (PK)│
│ first_name      │   │ order_id (FK)   │ │ first_name      │
│ last_name       │   │ product_id (FK) │ │ last_name       │
│ email (UK)      │   │ quantity        │ │ email (UK)      │
│ customer_tier   │   │ unit_price      │ │ department      │
│ total_spent     │   │ discount_%      │ │ status          │
└─────────────────┘   └─────────────────┘ └─────────────────┘
          │                     │ M                  │
          │ 1                   └───►                │ 1
          │                                      ┌───┴───┐
          │                                      │       │
┌─────────────────┐   ┌─────────────────┐ ┌─────────────────┐
│    PAYMENTS     │   │    PRODUCTS     │ │ EMPLOYEE_REST   │
│   (Transaction) │   │   (Master)      │ │   (Reference)   │
├─────────────────┤   ├─────────────────┤ ├─────────────────┤
│ payment_id (PK) │   │ product_id (PK) │ │ restriction_id  │
│ order_id (FK)   │   │ product_name    │ │ employee_id (FK)│
│ customer_id (FK)│   │ category_id (FK)│ │ restriction_type│
│ amount          │   │ supplier_id (FK)│ │ is_active       │
│ payment_method  │   │ unit_price      │ └─────────────────┘
│ status          │   │ stock_quantity  │         │
└─────────────────┘   └─────────────────┘         │
          │                1 │ M                  │ 1
          │                 ┌┴───────────────────┴┐
          │                 │                     │
┌─────────────────┐   ┌─────────────────┐ ┌─────────────────┐
│   SHIPMENTS     │   │   CATEGORIES    │ │   SUPPLIERS     │
│   (Transaction) │   │   (Reference)   │ │   (Reference)   │
├─────────────────┤   ├─────────────────┤ ├─────────────────┤
│ shipment_id (PK)│   │ category_id (PK)│ │ supplier_id (PK)│
│ order_id (FK)   │   │ category_name   │ │ supplier_name   │
│ tracking_number │   │ description     │ │ contact_person  │
│ shipment_status │   │ parent_category │ │ email           │
│ carrier         │   └─────────────────┘ └─────────────────┘
└─────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  AUDIT & SYSTEM TABLES                  │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐│
│ │   AUDIT_LOG     │  │    HOLIDAYS     │  │ VIOLATIONS  ││
│ ├─────────────────┤  ├─────────────────┤  ├─────────────┤│
│ │ audit_id (PK)   │  │ holiday_id (PK) │  │ violation_id││
│ │ table_name      │  │ holiday_name    │  │ rule_name   ││
│ │ operation_type  │  │ holiday_date    │  │ user_name   ││
│ │ user_name       │  │ country         │  │ table_name  ││
│ │ timestamp       │  │ is_recurring    │  │ error_msg   ││
│ │ success_flag    │  │ description     │  │ resolved    ││
│ └─────────────────┘  └─────────────────┘  └─────────────┘│
└─────────────────────────────────────────────────────────┘

                      BUSINESS RULES:
      ┌─────────────────────────────────────────────┐
      │ Employees CANNOT Insert/Update/Delete on:   │
      │ 1. WEEKDAYS (Mon-Fri)                       │
      │ 2. PUBLIC HOLIDAYS (from holidays table)    │
      │ Implementation: Triggers + Audit Log        │
      └─────────────────────────────────────────────┘
