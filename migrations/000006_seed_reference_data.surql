--------------------------------------------------------------------
-- StockSense Migration 000006
-- Seed/reference data
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Roles
--------------------------------------------------------------------

UPSERT role:inventory_manager SET
  code = "inventory_manager",
  name = "Inventory Manager";

UPSERT role:warehouse_staff SET
  code = "warehouse_staff",
  name = "Warehouse Staff";

--------------------------------------------------------------------
-- Document statuses
--------------------------------------------------------------------

UPSERT document_status:draft SET
  code = "draft",
  name = "Draft";

UPSERT document_status:waiting SET
  code = "waiting",
  name = "Waiting";

UPSERT document_status:ready SET
  code = "ready",
  name = "Ready";

UPSERT document_status:done SET
  code = "done",
  name = "Done";

UPSERT document_status:canceled SET
  code = "canceled",
  name = "Canceled";

--------------------------------------------------------------------
-- Stock move types
--------------------------------------------------------------------

UPSERT move_type:receipt SET
  code = "receipt",
  name = "Receipt";

UPSERT move_type:delivery SET
  code = "delivery",
  name = "Delivery";

UPSERT move_type:transfer SET
  code = "transfer",
  name = "Internal Transfer";

UPSERT move_type:adjustment SET
  code = "adjustment",
  name = "Stock Adjustment";

UPSERT move_type:initial SET
  code = "initial",
  name = "Initial Stock";

--------------------------------------------------------------------
-- Reference types for stock_move traceability
--------------------------------------------------------------------

UPSERT reference_type:receipt SET
  code = "receipt",
  name = "Receipt";

UPSERT reference_type:delivery_order SET
  code = "delivery_order",
  name = "Delivery Order";

UPSERT reference_type:internal_transfer SET
  code = "internal_transfer",
  name = "Internal Transfer";

UPSERT reference_type:stock_adjustment SET
  code = "stock_adjustment",
  name = "Stock Adjustment";

UPSERT reference_type:product_initial SET
  code = "product_initial",
  name = "Product Initial Stock";

UPSERT reference_type:manual SET
  code = "manual",
  name = "Manual Correction";

--------------------------------------------------------------------
-- Location types
--------------------------------------------------------------------

UPSERT location_type:warehouse SET
  code = "warehouse",
  name = "Warehouse";

UPSERT location_type:rack SET
  code = "rack",
  name = "Rack";

UPSERT location_type:production_floor SET
  code = "production_floor",
  name = "Production Floor";

UPSERT location_type:dock SET
  code = "dock",
  name = "Dock";

UPSERT location_type:supplier_external SET
  code = "supplier_external",
  name = "External Supplier Location";

UPSERT location_type:customer_external SET
  code = "customer_external",
  name = "External Customer Location";

UPSERT location_type:loss SET
  code = "loss",
  name = "Loss/Damaged Location";

UPSERT location_type:gain SET
  code = "gain",
  name = "Gain/Found Location";

--------------------------------------------------------------------
-- Units of measure
--------------------------------------------------------------------

UPSERT unit_of_measure:unit SET
  code = "unit",
  name = "Unit";

UPSERT unit_of_measure:kg SET
  code = "kg",
  name = "Kilogram";

UPSERT unit_of_measure:litre SET
  code = "litre",
  name = "Litre";

UPSERT unit_of_measure:metre SET
  code = "metre",
  name = "Metre";

--------------------------------------------------------------------
-- OTP purposes
--------------------------------------------------------------------

UPSERT otp_purpose:password_reset SET
  code = "password_reset",
  name = "Password Reset";

UPSERT otp_purpose:email_verification SET
  code = "email_verification",
  name = "Email Verification";

UPSERT otp_purpose:login_verification SET
  code = "login_verification",
  name = "Login Verification";

--------------------------------------------------------------------
-- Alert types
--------------------------------------------------------------------

UPSERT alert_type:low_stock SET
  code = "low_stock",
  name = "Low Stock";

UPSERT alert_type:out_of_stock SET
  code = "out_of_stock",
  name = "Out of Stock";