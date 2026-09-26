--------------------------------------------------------------------
-- StockSense Migration 000003
-- Master data: warehouse, location, product, supplier, customer
--------------------------------------------------------------------

DEFINE TABLE warehouse SCHEMAFULL;

DEFINE FIELD code ON TABLE warehouse TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE warehouse TYPE string ASSERT $value != "";
DEFINE FIELD is_active ON TABLE warehouse TYPE bool VALUE true;
DEFINE FIELD created_at ON TABLE warehouse TYPE datetime VALUE time::now();

DEFINE INDEX warehouse_code_unique ON TABLE warehouse FIELDS code UNIQUE;

--------------------------------------------------------------------
-- Locations belong to warehouses.
-- Location types can include warehouse, rack, production floor,
-- supplier/customer external locations, damaged/loss locations, etc.
--------------------------------------------------------------------

DEFINE TABLE location SCHEMAFULL;

DEFINE FIELD warehouse ON TABLE location TYPE option<record<warehouse>>;
DEFINE FIELD location_type ON TABLE location TYPE record<location_type>;
DEFINE FIELD code ON TABLE location TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE location TYPE string ASSERT $value != "";
DEFINE FIELD is_active ON TABLE location TYPE bool VALUE true;
DEFINE FIELD created_at ON TABLE location TYPE datetime VALUE time::now();

DEFINE INDEX location_warehouse_code_unique ON TABLE location FIELDS warehouse, code UNIQUE;
DEFINE INDEX location_type_idx ON TABLE location FIELDS location_type;

--------------------------------------------------------------------
-- Product categories and products
--------------------------------------------------------------------

DEFINE TABLE product_category SCHEMAFULL;

DEFINE FIELD code ON TABLE product_category TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE product_category TYPE string ASSERT $value != "";

DEFINE INDEX product_category_code_unique ON TABLE product_category FIELDS code UNIQUE;

DEFINE TABLE product SCHEMAFULL;

DEFINE FIELD sku ON TABLE product TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE product TYPE string ASSERT $value != "";
DEFINE FIELD category ON TABLE product TYPE record<product_category>;
DEFINE FIELD uom ON TABLE product TYPE record<unit_of_measure>;
DEFINE FIELD description ON TABLE product TYPE option<string>;
DEFINE FIELD initial_qty ON TABLE product TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD initial_location ON TABLE product TYPE option<record<location>>;
DEFINE FIELD is_active ON TABLE product TYPE bool VALUE true;
DEFINE FIELD created_at ON TABLE product TYPE datetime VALUE time::now();

DEFINE INDEX product_sku_unique ON TABLE product FIELDS sku UNIQUE;
DEFINE INDEX product_category_idx ON TABLE product FIELDS category;
DEFINE INDEX product_uom_idx ON TABLE product FIELDS uom;

--------------------------------------------------------------------
-- Suppliers and customers
--------------------------------------------------------------------

DEFINE TABLE supplier SCHEMAFULL;

DEFINE FIELD code ON TABLE supplier TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE supplier TYPE string ASSERT $value != "";

DEFINE INDEX supplier_code_unique ON TABLE supplier FIELDS code UNIQUE;

DEFINE TABLE customer SCHEMAFULL;

DEFINE FIELD code ON TABLE customer TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE customer TYPE string ASSERT $value != "";

DEFINE INDEX customer_code_unique ON TABLE customer FIELDS code UNIQUE;

--------------------------------------------------------------------
-- Reordering rules can be defined per product and location.
--------------------------------------------------------------------

DEFINE TABLE reorder_rule SCHEMAFULL;

DEFINE FIELD product ON TABLE reorder_rule TYPE record<product>;
DEFINE FIELD location ON TABLE reorder_rule TYPE record<location>;
DEFINE FIELD min_qty ON TABLE reorder_rule TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD reorder_qty ON TABLE reorder_rule TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD max_qty ON TABLE reorder_rule TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD lead_time_days ON TABLE reorder_rule TYPE int VALUE 0 ASSERT $value >= 0;
DEFINE FIELD created_at ON TABLE reorder_rule TYPE datetime VALUE time::now();

DEFINE INDEX reorder_rule_product_location_unique ON TABLE reorder_rule FIELDS product, location UNIQUE;
DEFINE INDEX reorder_rule_product_idx ON TABLE reorder_rule FIELDS product;
DEFINE INDEX reorder_rule_location_idx ON TABLE reorder_rule FIELDS location;
