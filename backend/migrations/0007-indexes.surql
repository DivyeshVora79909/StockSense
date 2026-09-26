-- STOCKSENSE: indexes
DEFINE INDEX OVERWRITE idx_unit_of_measure_owned_by ON TABLE unit_of_measure FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_unit_of_measure_readers ON TABLE unit_of_measure FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_product_category_owned_by ON TABLE product_category FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_product_category_readers ON TABLE product_category FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_warehouse_owned_by ON TABLE warehouse FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_warehouse_readers ON TABLE warehouse FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_stock_location_owned_by ON TABLE stock_location FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_stock_location_readers ON TABLE stock_location FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_stock_location_warehouse ON TABLE stock_location FIELDS warehouse;
DEFINE INDEX OVERWRITE idx_stock_location_parent ON TABLE stock_location FIELDS parent;
DEFINE INDEX OVERWRITE idx_product_owned_by ON TABLE product FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_product_readers ON TABLE product FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_product_category ON TABLE product FIELDS category;
DEFINE INDEX OVERWRITE idx_product_unit ON TABLE product FIELDS unit;
DEFINE INDEX OVERWRITE idx_stock_position_owned_by ON TABLE stock_position FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_stock_position_readers ON TABLE stock_position FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_stock_position_product ON TABLE stock_position FIELDS product;
DEFINE INDEX OVERWRITE idx_stock_position_location ON TABLE stock_position FIELDS location;
DEFINE INDEX OVERWRITE idx_stock_operation_owned_by ON TABLE stock_operation FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_stock_operation_readers ON TABLE stock_operation FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_stock_operation_location ON TABLE stock_operation FIELDS location;
DEFINE INDEX OVERWRITE idx_stock_operation_from_location ON TABLE stock_operation FIELDS from_location;
DEFINE INDEX OVERWRITE idx_stock_operation_to_location ON TABLE stock_operation FIELDS to_location;
DEFINE INDEX OVERWRITE idx_stock_ledger_owned_by ON TABLE stock_ledger FIELDS owned_by;
DEFINE INDEX OVERWRITE idx_stock_ledger_readers ON TABLE stock_ledger FIELDS readers_index.*;
DEFINE INDEX OVERWRITE idx_stock_ledger_operation ON TABLE stock_ledger FIELDS operation;
DEFINE INDEX OVERWRITE idx_stock_ledger_product ON TABLE stock_ledger FIELDS product;
DEFINE INDEX OVERWRITE idx_stock_ledger_location ON TABLE stock_ledger FIELDS location;
DEFINE INDEX OVERWRITE idx_stock_ledger_position ON TABLE stock_ledger FIELDS position;


