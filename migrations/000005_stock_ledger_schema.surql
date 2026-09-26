--------------------------------------------------------------------
-- StockSense Migration 000005
-- Stock ledger, balances, alerts
--------------------------------------------------------------------

--------------------------------------------------------------------
-- stock_move is the immutable ledger.
--
-- Recommended application rule:
-- - Do not update or delete stock_move records.
-- - Create correction moves instead.
--
-- For receipts:
--   source_location can be an external supplier location.
--   destination_location is the receiving location.
--
-- For deliveries:
--   source_location is the shipping location.
--   destination_location can be an external customer location.
--
-- For adjustments:
--   loss/damage can move from stock location to loss location.
--   gain can move from gain location to stock location.
--------------------------------------------------------------------

DEFINE TABLE stock_move SCHEMAFULL;

DEFINE FIELD move_at ON TABLE stock_move TYPE datetime VALUE time::now();
DEFINE FIELD product ON TABLE stock_move TYPE record<product>;
DEFINE FIELD source_location ON TABLE stock_move TYPE option<record<location>>;
DEFINE FIELD destination_location ON TABLE stock_move TYPE option<record<location>>;
DEFINE FIELD qty ON TABLE stock_move TYPE decimal ASSERT $value > 0;
DEFINE FIELD move_type ON TABLE stock_move TYPE record<move_type>;
DEFINE FIELD reference_type ON TABLE stock_move TYPE record<reference_type>;
DEFINE FIELD reference ON TABLE stock_move TYPE option<record>;
DEFINE FIELD reference_line ON TABLE stock_move TYPE option<record>;
DEFINE FIELD created_by ON TABLE stock_move TYPE record<user>;
DEFINE FIELD created_at ON TABLE stock_move TYPE datetime VALUE time::now();

DEFINE INDEX stock_move_product_idx ON TABLE stock_move FIELDS product;
DEFINE INDEX stock_move_source_location_idx ON TABLE stock_move FIELDS source_location;
DEFINE INDEX stock_move_destination_location_idx ON TABLE stock_move FIELDS destination_location;
DEFINE INDEX stock_move_move_type_idx ON TABLE stock_move FIELDS move_type;
DEFINE INDEX stock_move_reference_type_idx ON TABLE stock_move FIELDS reference_type;
DEFINE INDEX stock_move_reference_idx ON TABLE stock_move FIELDS reference;
DEFINE INDEX stock_move_move_at_idx ON TABLE stock_move FIELDS move_at;

--------------------------------------------------------------------
-- stock_balance is the current quantity projection.
--
-- In a strict ledger-only design, this can be derived from stock_move.
-- In practice, keep this table updated transactionally whenever
-- a stock_move is created.
--------------------------------------------------------------------

DEFINE TABLE stock_balance SCHEMAFULL;

DEFINE FIELD product ON TABLE stock_balance TYPE record<product>;
DEFINE FIELD location ON TABLE stock_balance TYPE record<location>;
DEFINE FIELD qty_on_hand ON TABLE stock_balance TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD qty_reserved ON TABLE stock_balance TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD updated_at ON TABLE stock_balance TYPE datetime VALUE time::now();

DEFINE INDEX stock_balance_product_location_unique ON TABLE stock_balance FIELDS product, location UNIQUE;
DEFINE INDEX stock_balance_product_idx ON TABLE stock_balance FIELDS product;
DEFINE INDEX stock_balance_location_idx ON TABLE stock_balance FIELDS location;

--------------------------------------------------------------------
-- Stock alerts
--------------------------------------------------------------------

DEFINE TABLE stock_alert SCHEMAFULL;

DEFINE FIELD product ON TABLE stock_alert TYPE record<product>;
DEFINE FIELD location ON TABLE stock_alert TYPE record<location>;
DEFINE FIELD alert_type ON TABLE stock_alert TYPE record<alert_type>;
DEFINE FIELD created_at ON TABLE stock_alert TYPE datetime VALUE time::now();
DEFINE FIELD resolved_at ON TABLE stock_alert TYPE option<datetime>;

DEFINE INDEX stock_alert_product_location_idx ON TABLE stock_alert FIELDS product, location;
DEFINE INDEX stock_alert_alert_type_idx ON TABLE stock_alert FIELDS alert_type;
DEFINE INDEX stock_alert_created_at_idx ON TABLE stock_alert FIELDS created_at;
