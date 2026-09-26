--------------------------------------------------------------------
-- StockSense Migration 000004
-- Operational documents:
-- receipts, delivery orders, internal transfers, adjustments
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Receipts: incoming stock
--------------------------------------------------------------------

DEFINE TABLE receipt SCHEMAFULL;

DEFINE FIELD number ON TABLE receipt TYPE string ASSERT $value != "";
DEFINE FIELD supplier ON TABLE receipt TYPE record<supplier>;
DEFINE FIELD destination_location ON TABLE receipt TYPE record<location>;
DEFINE FIELD status ON TABLE receipt TYPE record<document_status>;
DEFINE FIELD created_by ON TABLE receipt TYPE record<user>;
DEFINE FIELD scheduled_at ON TABLE receipt TYPE option<datetime>;
DEFINE FIELD validated_at ON TABLE receipt TYPE option<datetime>;
DEFINE FIELD created_at ON TABLE receipt TYPE datetime VALUE time::now();

DEFINE INDEX receipt_number_unique ON TABLE receipt FIELDS number UNIQUE;
DEFINE INDEX receipt_supplier_idx ON TABLE receipt FIELDS supplier;
DEFINE INDEX receipt_destination_location_idx ON TABLE receipt FIELDS destination_location;
DEFINE INDEX receipt_status_idx ON TABLE receipt FIELDS status;
DEFINE INDEX receipt_created_by_idx ON TABLE receipt FIELDS created_by;

DEFINE TABLE receipt_line SCHEMAFULL;

DEFINE FIELD receipt ON TABLE receipt_line TYPE record<receipt>;
DEFINE FIELD product ON TABLE receipt_line TYPE record<product>;
DEFINE FIELD qty_expected ON TABLE receipt_line TYPE decimal ASSERT $value > 0;
DEFINE FIELD qty_received ON TABLE receipt_line TYPE decimal VALUE 0 ASSERT $value >= 0 AND $value <= qty_expected;

DEFINE INDEX receipt_line_receipt_product_unique ON TABLE receipt_line FIELDS receipt, product UNIQUE;
DEFINE INDEX receipt_line_receipt_idx ON TABLE receipt_line FIELDS receipt;
DEFINE INDEX receipt_line_product_idx ON TABLE receipt_line FIELDS product;

--------------------------------------------------------------------
-- Delivery orders: outgoing stock
--------------------------------------------------------------------

DEFINE TABLE delivery_order SCHEMAFULL;

DEFINE FIELD number ON TABLE delivery_order TYPE string ASSERT $value != "";
DEFINE FIELD customer ON TABLE delivery_order TYPE record<customer>;
DEFINE FIELD source_location ON TABLE delivery_order TYPE record<location>;
DEFINE FIELD status ON TABLE delivery_order TYPE record<document_status>;
DEFINE FIELD created_by ON TABLE delivery_order TYPE record<user>;
DEFINE FIELD scheduled_at ON TABLE delivery_order TYPE option<datetime>;
DEFINE FIELD validated_at ON TABLE delivery_order TYPE option<datetime>;
DEFINE FIELD created_at ON TABLE delivery_order TYPE datetime VALUE time::now();

DEFINE INDEX delivery_order_number_unique ON TABLE delivery_order FIELDS number UNIQUE;
DEFINE INDEX delivery_order_customer_idx ON TABLE delivery_order FIELDS customer;
DEFINE INDEX delivery_order_source_location_idx ON TABLE delivery_order FIELDS source_location;
DEFINE INDEX delivery_order_status_idx ON TABLE delivery_order FIELDS status;
DEFINE INDEX delivery_order_created_by_idx ON TABLE delivery_order FIELDS created_by;

DEFINE TABLE delivery_line SCHEMAFULL;

DEFINE FIELD delivery_order ON TABLE delivery_line TYPE record<delivery_order>;
DEFINE FIELD product ON TABLE delivery_line TYPE record<product>;
DEFINE FIELD qty_ordered ON TABLE delivery_line TYPE decimal ASSERT $value > 0;
DEFINE FIELD qty_reserved ON TABLE delivery_line TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD qty_done ON TABLE delivery_line TYPE decimal VALUE 0 ASSERT $value >= 0;

DEFINE INDEX delivery_line_order_product_unique ON TABLE delivery_line FIELDS delivery_order, product UNIQUE;
DEFINE INDEX delivery_line_order_idx ON TABLE delivery_line FIELDS delivery_order;
DEFINE INDEX delivery_line_product_idx ON TABLE delivery_line FIELDS product;

--------------------------------------------------------------------
-- Internal transfers
--------------------------------------------------------------------

DEFINE TABLE internal_transfer SCHEMAFULL;

DEFINE FIELD number ON TABLE internal_transfer TYPE string ASSERT $value != "";
DEFINE FIELD source_location ON TABLE internal_transfer TYPE record<location>;
DEFINE FIELD destination_location ON TABLE internal_transfer TYPE record<location>;
DEFINE FIELD status ON TABLE internal_transfer TYPE record<document_status>;
DEFINE FIELD created_by ON TABLE internal_transfer TYPE record<user>;
DEFINE FIELD scheduled_at ON TABLE internal_transfer TYPE option<datetime>;
DEFINE FIELD validated_at ON TABLE internal_transfer TYPE option<datetime>;
DEFINE FIELD created_at ON TABLE internal_transfer TYPE datetime VALUE time::now();

DEFINE INDEX internal_transfer_number_unique ON TABLE internal_transfer FIELDS number UNIQUE;
DEFINE INDEX internal_transfer_source_location_idx ON TABLE internal_transfer FIELDS source_location;
DEFINE INDEX internal_transfer_destination_location_idx ON TABLE internal_transfer FIELDS destination_location;
DEFINE INDEX internal_transfer_status_idx ON TABLE internal_transfer FIELDS status;
DEFINE INDEX internal_transfer_created_by_idx ON TABLE internal_transfer FIELDS created_by;

DEFINE TABLE transfer_line SCHEMAFULL;

DEFINE FIELD internal_transfer ON TABLE transfer_line TYPE record<internal_transfer>;
DEFINE FIELD product ON TABLE transfer_line TYPE record<product>;
DEFINE FIELD qty_requested ON TABLE transfer_line TYPE decimal ASSERT $value > 0;
DEFINE FIELD qty_moved ON TABLE transfer_line TYPE decimal VALUE 0 ASSERT $value >= 0;

DEFINE INDEX transfer_line_transfer_product_unique ON TABLE transfer_line FIELDS internal_transfer, product UNIQUE;
DEFINE INDEX transfer_line_transfer_idx ON TABLE transfer_line FIELDS internal_transfer;
DEFINE INDEX transfer_line_product_idx ON TABLE transfer_line FIELDS product;

--------------------------------------------------------------------
-- Stock adjustments
--------------------------------------------------------------------

DEFINE TABLE stock_adjustment SCHEMAFULL;

DEFINE FIELD number ON TABLE stock_adjustment TYPE string ASSERT $value != "";
DEFINE FIELD location ON TABLE stock_adjustment TYPE record<location>;
DEFINE FIELD status ON TABLE stock_adjustment TYPE record<document_status>;
DEFINE FIELD reason ON TABLE stock_adjustment TYPE option<string>;
DEFINE FIELD created_by ON TABLE stock_adjustment TYPE record<user>;
DEFINE FIELD counted_at ON TABLE stock_adjustment TYPE option<datetime>;
DEFINE FIELD validated_at ON TABLE stock_adjustment TYPE option<datetime>;
DEFINE FIELD created_at ON TABLE stock_adjustment TYPE datetime VALUE time::now();

DEFINE INDEX stock_adjustment_number_unique ON TABLE stock_adjustment FIELDS number UNIQUE;
DEFINE INDEX stock_adjustment_location_idx ON TABLE stock_adjustment FIELDS location;
DEFINE INDEX stock_adjustment_status_idx ON TABLE stock_adjustment FIELDS status;
DEFINE INDEX stock_adjustment_created_by_idx ON TABLE stock_adjustment FIELDS created_by;

DEFINE TABLE adjustment_line SCHEMAFULL;

DEFINE FIELD stock_adjustment ON TABLE adjustment_line TYPE record<stock_adjustment>;
DEFINE FIELD product ON TABLE adjustment_line TYPE record<product>;
DEFINE FIELD system_qty ON TABLE adjustment_line TYPE decimal VALUE 0 ASSERT $value >= 0;
DEFINE FIELD counted_qty ON TABLE adjustment_line TYPE decimal ASSERT $value >= 0;
DEFINE FIELD variance_qty ON TABLE adjustment_line TYPE decimal VALUE $this.counted_qty - $this.system_qty ASSERT $value = $this.counted_qty - $this.system_qty;

DEFINE INDEX adjustment_line_adjustment_product_unique ON TABLE adjustment_line FIELDS stock_adjustment, product UNIQUE;
DEFINE INDEX adjustment_line_adjustment_idx ON TABLE adjustment_line FIELDS stock_adjustment;
DEFINE INDEX adjustment_line_product_idx ON TABLE adjustment_line FIELDS product;
