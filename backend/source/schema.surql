-- StockSense keeps editable operational documents separate from the managed
-- stock ledger. A validated operation atomically owns its ledger effects.

DEFINE TABLE OVERWRITE unit_of_measure SCHEMAFULL;
DEFINE FIELD OVERWRITE code ON unit_of_measure TYPE string
    ASSERT string::matches($value, /^[A-Za-z][A-Za-z0-9._-]{0,15}$/) COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE name ON unit_of_measure TYPE string ASSERT string::len(string::trim($value)) > 0 COMMENT '@rebase-audit';
DEFINE INDEX OVERWRITE unit_of_measure_code ON unit_of_measure FIELDS code UNIQUE;

DEFINE TABLE OVERWRITE product_category SCHEMAFULL;
DEFINE FIELD OVERWRITE name ON product_category TYPE string ASSERT string::len(string::trim($value)) > 0 COMMENT '@rebase-audit';
DEFINE INDEX OVERWRITE product_category_name ON product_category FIELDS name UNIQUE;

DEFINE TABLE OVERWRITE warehouse SCHEMAFULL;
DEFINE FIELD OVERWRITE name ON warehouse TYPE string ASSERT string::len(string::trim($value)) > 0 COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE code ON warehouse TYPE string ASSERT string::len(string::trim($value)) > 0 COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE active ON warehouse TYPE bool DEFAULT true COMMENT '@rebase-audit';
DEFINE INDEX OVERWRITE warehouse_code ON warehouse FIELDS code UNIQUE;

DEFINE TABLE OVERWRITE stock_location SCHEMAFULL
    COMMENT '@rebase-validate fn::stocksense::location_validate';
DEFINE FIELD OVERWRITE warehouse ON stock_location TYPE record<warehouse> REFERENCE ON DELETE REJECT READONLY COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE parent ON stock_location TYPE option<record<stock_location>> DEFAULT NONE REFERENCE ON DELETE REJECT COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE name ON stock_location TYPE string ASSERT string::len(string::trim($value)) > 0 COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE code ON stock_location TYPE string ASSERT string::len(string::trim($value)) > 0 COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE active ON stock_location TYPE bool DEFAULT true COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE z_stock ON stock_location TYPE object COMMENT '@rebase-tree-root @rebase-tree-key datetime';
DEFINE INDEX OVERWRITE stock_location_code ON stock_location FIELDS warehouse, code UNIQUE;

DEFINE FUNCTION OVERWRITE fn::stocksense::location_validate($row: object) {
    IF $row.parent != NONE AND $row.parent.warehouse != $row.warehouse { THROW 'STOCKSENSE_LOCATION_WAREHOUSE_MISMATCH'; };
    LET $quantity = $row.z_stock.summary.measures.quantity.min_prefix ?? 0dec;
    IF $quantity < 0dec { THROW 'STOCKSENSE_LOCATION_NEGATIVE_STOCK'; };
} PERMISSIONS FULL;

DEFINE TABLE OVERWRITE product SCHEMAFULL
    COMMENT '@rebase-validate fn::stocksense::product_validate';
DEFINE FIELD OVERWRITE name ON product TYPE string ASSERT string::len(string::trim($value)) > 0 COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE sku ON product TYPE string ASSERT string::len(string::trim($value)) > 0 READONLY COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE category ON product TYPE option<record<product_category>> DEFAULT NONE REFERENCE ON DELETE REJECT COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE unit ON product TYPE record<unit_of_measure> REFERENCE ON DELETE REJECT READONLY COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE reorder_point ON product TYPE decimal DEFAULT 0dec ASSERT $value >= 0dec COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE active ON product TYPE bool DEFAULT true COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE z_stock ON product TYPE object COMMENT '@rebase-tree-root @rebase-tree-key datetime';
DEFINE INDEX OVERWRITE product_sku ON product FIELDS sku UNIQUE;

DEFINE FUNCTION OVERWRITE fn::stocksense::product_validate($row: object) {
    LET $summary = $row.z_stock.summary;
    IF ($summary.measures.quantity.min_prefix ?? 0dec) < 0dec { THROW 'STOCKSENSE_PRODUCT_NEGATIVE_STOCK'; };
} PERMISSIONS FULL;

DEFINE TABLE OVERWRITE stock_position SCHEMAFULL
    COMMENT '@rebase-validate fn::stocksense::position_validate';
DEFINE FIELD OVERWRITE product ON stock_position TYPE record<product> REFERENCE ON DELETE REJECT READONLY COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE location ON stock_position TYPE record<stock_location> REFERENCE ON DELETE REJECT READONLY COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE z_stock ON stock_position TYPE object COMMENT '@rebase-tree-root @rebase-tree-key datetime';
DEFINE INDEX OVERWRITE stock_position_dimension ON stock_position FIELDS product, location UNIQUE;
DEFINE FUNCTION OVERWRITE fn::stocksense::position_validate($row: object) {
    IF ($row.z_stock.summary.measures.quantity.min_prefix ?? 0dec) < 0dec { THROW 'STOCKSENSE_POSITION_NEGATIVE_STOCK'; };
    IF $row.location.active != true OR $row.product.active != true { THROW 'STOCKSENSE_POSITION_INACTIVE'; };
} PERMISSIONS FULL;

DEFINE FUNCTION OVERWRITE fn::stocksense::adjustment_delta($source: record, $product: record, $location: record, $counted: decimal) {
    LET $position = (SELECT VALUE id FROM stock_position WHERE product = $product AND location = $location)[0];
    IF $position = NONE { THROW 'STOCKSENSE_POSITION_REQUIRED'; };
    LET $balance = $position.z_stock.summary.measures.quantity.sum ?? 0dec;
    RETURN $counted - $balance;
} PERMISSIONS FULL;

DEFINE FUNCTION OVERWRITE fn::stocksense::position_id($product: record, $location: record) {
    LET $position = (SELECT VALUE id FROM stock_position WHERE product = $product AND location = $location)[0];
    IF $position = NONE { THROW 'STOCKSENSE_POSITION_REQUIRED'; };
    RETURN $position;
} PERMISSIONS FULL;

DEFINE FUNCTION OVERWRITE fn::stocksense::operation_outputs($row: object) {
    IF $row.status != 'done' { RETURN []; };
    LET $outputs = $row.lines.map(|$line| {
        LET $quantity = IF $row.kind = 'adjustment'
            THEN fn::stocksense::adjustment_delta($row.id, $line.product, $row.location, $line.counted_quantity)
            ELSE $line.quantity END;
        LET $role_out = IF $row.kind = 'transfer' THEN $line.line_key + '_out' ELSE $line.line_key END;
        LET $role_in = $line.line_key + '_in';
        LET $line_base = {
            owned_by: $row.owned_by, operation: $row.id, product: $line.product,
            effective_at: $row.effective_at, kind: $row.kind
        };
        IF $row.kind = 'receipt' {
            LET $position = fn::stocksense::position_id($line.product, $row.location);
            RETURN [{ id: type::record('stock_ledger', [$row.id, $role_out]), role: $role_out,
                data: object::extend($line_base, { location: $row.location, position: $position, quantity_delta: $quantity }) }];
        } ELSE IF $row.kind = 'delivery' {
            LET $position = fn::stocksense::position_id($line.product, $row.location);
            RETURN [{ id: type::record('stock_ledger', [$row.id, $role_out]), role: $role_out,
                data: object::extend($line_base, { location: $row.location, position: $position, quantity_delta: -$quantity }) }];
        } ELSE IF $row.kind = 'adjustment' {
            LET $position = fn::stocksense::position_id($line.product, $row.location);
            RETURN [{ id: type::record('stock_ledger', [$row.id, $role_out]), role: $role_out,
                data: object::extend($line_base, { location: $row.location, position: $position, quantity_delta: $quantity }) }];
        } ELSE {
            LET $source_position = fn::stocksense::position_id($line.product, $row.from_location);
            LET $destination_position = fn::stocksense::position_id($line.product, $row.to_location);
            RETURN [
                { id: type::record('stock_ledger', [$row.id, $role_out]), role: $role_out,
                  data: object::extend($line_base, { location: $row.from_location, position: $source_position, quantity_delta: -$quantity }) },
                { id: type::record('stock_ledger', [$row.id, $role_in]), role: $role_in,
                  data: object::extend($line_base, { location: $row.to_location, position: $destination_position, quantity_delta: $quantity }) }
            ];
        };
    });
    RETURN array::flatten($outputs);
} PERMISSIONS FULL;

DEFINE FUNCTION OVERWRITE fn::stocksense::operation_validate($row: object) {
    IF $row.status NOT IN ['draft', 'waiting', 'ready', 'done', 'canceled'] { THROW 'STOCKSENSE_INVALID_STATUS'; };
    IF $row.status = 'done' AND array::len($row.lines) = 0 { THROW 'STOCKSENSE_LINES_REQUIRED'; };
    IF $row.status = 'done' AND $row.effective_at > time::now() { THROW 'STOCKSENSE_CANNOT_POST_FUTURE_OPERATION'; };
    IF array::len(array::distinct($row.lines.map(|$line| $line.line_key))) != array::len($row.lines) { THROW 'STOCKSENSE_DUPLICATE_LINE_KEY'; };
    IF $row.kind IN ['receipt', 'delivery', 'adjustment'] AND $row.location = NONE { THROW 'STOCKSENSE_LOCATION_REQUIRED'; };
    IF $row.kind = 'transfer' AND ($row.from_location = NONE OR $row.to_location = NONE OR $row.from_location = $row.to_location) {
        THROW 'STOCKSENSE_TRANSFER_LOCATIONS_INVALID';
    };
    IF $row.kind = 'adjustment' {
        LET $products = $row.lines.map(|$line| $line.product);
        IF array::len(array::distinct($products)) != array::len($products) { THROW 'STOCKSENSE_DUPLICATE_ADJUSTMENT_PRODUCT'; };
        IF $row.lines.any(|$line| $line.counted_quantity = NONE OR $line.counted_quantity < 0dec) { THROW 'STOCKSENSE_COUNT_INVALID'; };
    } ELSE IF $row.lines.any(|$line| $line.quantity = NONE OR $line.quantity <= 0dec) {
        THROW 'STOCKSENSE_QUANTITY_INVALID';
    };
    IF $row.status = 'done' AND $row.kind = 'transfer' AND
        ($row.from_location.active != true OR $row.to_location.active != true) { THROW 'STOCKSENSE_LOCATION_INACTIVE'; };
} PERMISSIONS FULL;

DEFINE TABLE OVERWRITE stock_operation SCHEMAFULL
    COMMENT '@rebase-required-outputs fn::stocksense::operation_outputs @rebase-validate fn::stocksense::operation_validate';
DEFINE FIELD OVERWRITE kind ON stock_operation TYPE string ASSERT $value IN ['receipt', 'delivery', 'transfer', 'adjustment'] COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE status ON stock_operation TYPE string DEFAULT 'draft' ASSERT $value IN ['draft', 'waiting', 'ready', 'done', 'canceled'] COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE reference ON stock_operation TYPE option<string> DEFAULT NONE COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE party_name ON stock_operation TYPE option<string> DEFAULT NONE COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE location ON stock_operation TYPE option<record<stock_location>> DEFAULT NONE REFERENCE ON DELETE REJECT COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE from_location ON stock_operation TYPE option<record<stock_location>> DEFAULT NONE REFERENCE ON DELETE REJECT COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE to_location ON stock_operation TYPE option<record<stock_location>> DEFAULT NONE REFERENCE ON DELETE REJECT COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE effective_at ON stock_operation TYPE datetime DEFAULT time::now() COMMENT '@rebase-audit';
DEFINE FIELD OVERWRITE lines ON stock_operation TYPE array<object> DEFAULT [];
DEFINE FIELD OVERWRITE lines.*.line_key ON stock_operation TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD OVERWRITE lines.*.product ON stock_operation TYPE record<product>;
DEFINE FIELD OVERWRITE lines.*.quantity ON stock_operation TYPE option<decimal> DEFAULT NONE;
DEFINE FIELD OVERWRITE lines.*.counted_quantity ON stock_operation TYPE option<decimal> DEFAULT NONE;
DEFINE FIELD OVERWRITE created_by_name ON stock_operation TYPE option<string> DEFAULT NONE COMMENT '@rebase-audit';

DEFINE EVENT OVERWRITE stock_operation_status ON TABLE stock_operation
WHEN $event = 'UPDATE' AND $before.status != $after.status THEN {
    IF !(
        ($before.status = 'draft' AND $after.status IN ['waiting', 'ready', 'canceled'])
        OR ($before.status = 'waiting' AND $after.status IN ['ready', 'canceled'])
        OR ($before.status = 'ready' AND $after.status IN ['done', 'canceled'])
    ) { THROW 'STOCKSENSE_INVALID_STATUS_TRANSITION'; };
};

DEFINE EVENT OVERWRITE stock_operation_done_immutable ON TABLE stock_operation
WHEN ($before.status = 'done' AND ($event = 'DELETE' OR $before.status != $after.status OR $before.kind != $after.kind
    OR $before.location != $after.location OR $before.from_location != $after.from_location
    OR $before.to_location != $after.to_location OR $before.effective_at != $after.effective_at
    OR $before.lines != $after.lines)) THEN { THROW 'STOCKSENSE_DONE_OPERATION_IMMUTABLE'; };

DEFINE TABLE OVERWRITE stock_ledger SCHEMAFULL PERMISSIONS NONE
    COMMENT '@rebase-managed-output @rebase-members fn::stocksense::ledger_members';
DEFINE FIELD OVERWRITE rebase_managed_source ON stock_ledger TYPE string COMMENT '@rebase-system';
DEFINE FIELD OVERWRITE rebase_managed_role ON stock_ledger TYPE string COMMENT '@rebase-system';
DEFINE FIELD OVERWRITE operation ON stock_ledger TYPE record<stock_operation> REFERENCE ON DELETE REJECT;
DEFINE FIELD OVERWRITE product ON stock_ledger TYPE record<product> REFERENCE ON DELETE REJECT;
DEFINE FIELD OVERWRITE location ON stock_ledger TYPE record<stock_location> REFERENCE ON DELETE REJECT;
DEFINE FIELD OVERWRITE position ON stock_ledger TYPE record<stock_position> REFERENCE ON DELETE REJECT;
DEFINE FIELD OVERWRITE kind ON stock_ledger TYPE string;
DEFINE FIELD OVERWRITE quantity_delta ON stock_ledger TYPE decimal;
DEFINE FIELD OVERWRITE effective_at ON stock_ledger TYPE datetime;
DEFINE FIELD OVERWRITE z_product ON stock_ledger TYPE option<object> COMMENT '@rebase-tree-node @rebase-tree-key datetime @rebase-tree-owner product.z_stock';
DEFINE FIELD OVERWRITE z_location ON stock_ledger TYPE option<object> COMMENT '@rebase-tree-node @rebase-tree-key datetime @rebase-tree-owner stock_location.z_stock';
DEFINE FIELD OVERWRITE z_position ON stock_ledger TYPE option<object> COMMENT '@rebase-tree-node @rebase-tree-key datetime @rebase-tree-owner stock_position.z_stock';

DEFINE FUNCTION OVERWRITE fn::stocksense::ledger_members($row: object) {
    RETURN [
        fn::tree::member($row.id, 'z_product', $row.product, 'z_stock', $row.effective_at,
            { quantity: $row.quantity_delta }, { location: $row.location, kind: $row.kind }, {}, false),
        fn::tree::member($row.id, 'z_location', $row.location, 'z_stock', $row.effective_at,
            { quantity: $row.quantity_delta }, { product: $row.product, kind: $row.kind }, {}, false),
        fn::tree::member($row.id, 'z_position', $row.position, 'z_stock', $row.effective_at,
            { quantity: $row.quantity_delta }, { kind: $row.kind }, {}, false)
    ];
} PERMISSIONS NONE;

DEFINE FUNCTION OVERWRITE fn::stocksense::move_history(
    $kind: option<string>, $location: option<record<stock_location>>,
    $product: option<record<product>>, $limit: int
) {
    IF !$auth { THROW 'STOCKSENSE_AUTH_REQUIRED'; };
    LET $bounded = math::clamp($limit, 1, 250);
    RETURN (SELECT id, operation, product, location, kind, quantity_delta, effective_at
        FROM stock_ledger
        WHERE <string>owned_by IN $auth.z_access_index
          AND ($kind = NONE OR kind = $kind)
          AND ($location = NONE OR location = $location)
          AND ($product = NONE OR product = $product)
        ORDER BY effective_at DESC, id DESC LIMIT $bounded);
} PERMISSIONS FULL;

-- OTP email is sent directly from the database. The only credential lookup is
-- a fixed root-only record; no API key or caller-supplied URL is accepted.
DEFINE FUNCTION OVERWRITE fn::stocksense::send_email_code($identity: record<authentication_email>) {
    LET $target = (SELECT * FROM type::record($identity))[0];
    IF $target = NONE { RETURN NONE; };
    LET $principal = (SELECT * FROM type::record($target.principal))[0];
    IF $principal = NONE OR $principal.login_access != true { RETURN NONE; };
    LET $config = (SELECT * FROM rebase_email_delivery_config:stocksense)[0];
    IF $config = NONE OR $config.api_key = NONE { THROW 'STOCKSENSE_EMAIL_NOT_CONFIGURED'; };
    LET $prior = (SELECT * FROM authentication_challenge
        WHERE target = $target.id AND consumed_at = NONE)[0];
    IF $prior != NONE AND $prior.created_at > time::now() - 1m { RETURN NONE; };
    LET $code = <string>rand::int(100000, 999999);
    IF $prior = NONE {
        CREATE authentication_challenge SET
            principal = $principal.id, target = $target.id,
            principal_revision = $principal.authentication_revision,
            target_revision = $target.revision,
            code_hash = crypto::argon2::generate($code), attempts = 0,
            expires_at = time::now() + 10m, delivery_nonce = rand::uuid();
    } ELSE {
        UPDATE $prior.id SET
            principal_revision = $principal.authentication_revision,
            target_revision = $target.revision,
            code_hash = crypto::argon2::generate($code), attempts = 0,
            consumed_at = NONE, expires_at = time::now() + 10m,
            delivery_nonce = rand::uuid();
    };
    LET $sent = http::post('https://api.brevo.com/v3/smtp/email', {
        sender: { name: 'StockSense', email: 'divy.r.vora14@gmail.com' },
        to: [{ email: $target.address }],
        subject: 'Your StockSense verification code',
        textContent: 'Your StockSense code is ' + $code + '. It expires in 10 minutes.',
        htmlContent: '<p>Your StockSense code is <strong>' + $code + '</strong>.</p><p>It expires in 10 minutes.</p>'
    }, { 'api-key': $config.api_key, 'Content-Type': 'application/json' });
    RETURN true;
} PERMISSIONS FULL;

-- Each signup receives a private company group with only StockSense permissions.
-- Root-owned email delivery credentials are provisioned separately.
DEFINE ACCESS OVERWRITE stocksense_signup ON DATABASE TYPE RECORD
    SIGNUP {
        LET $username = string::lowercase(string::trim($identifier ?? ''));
        LET $email_value = string::lowercase(string::trim($email ?? ''));
        LET $name_value = string::trim($name ?? '');
        LET $workspace_value = string::trim($workspace ?? '');
        IF !string::matches($username, /^[a-z0-9][a-z0-9_.-]{8,31}$/)
            OR !string::is_email($email_value) OR string::len($name_value) = 0
            OR string::len($workspace_value) = 0 OR string::len($password ?? '') < 8 { RETURN NONE; };
        IF array::len(SELECT id FROM rebase_user WHERE username = $username) > 0
            OR array::len(SELECT id FROM authentication_email WHERE address = $email_value) > 0 { RETURN NONE; };
        LET $roles = [
            'node_select',
            'warehouse_select', 'warehouse_create', 'warehouse_update', 'warehouse_delete',
            'stock_location_select', 'stock_location_create', 'stock_location_update', 'stock_location_delete',
            'stock_position_select', 'stock_position_create', 'stock_position_update', 'stock_position_delete',
            'product_category_select', 'product_category_create', 'product_category_update', 'product_category_delete',
            'unit_of_measure_select', 'unit_of_measure_create', 'unit_of_measure_update', 'unit_of_measure_delete',
            'product_select', 'product_create', 'product_update', 'product_delete',
            'stock_operation_select', 'stock_operation_create', 'stock_operation_update', 'stock_operation_delete'
        ];
        LET $team = CREATE ONLY rebase_group SET name = $workspace_value,
            role = $roles, parents = [rebase_group:root];
        LET $user = CREATE ONLY rebase_user SET
            name = $name_value, username = $username,
            password = crypto::argon2::generate($password), parents = [$team.id];
        CREATE ONLY authentication_email SET principal = $user.id,
            address = $email_value, priority = 100;
        LET $identity = (SELECT VALUE id FROM authentication_email
            WHERE address = $email_value)[0];
        fn::stocksense::send_email_code($identity);
        RETURN $user.id;
    }
    SIGNIN {
        LET $identifier_value = string::lowercase(string::trim($identifier ?? ''));
        LET $username_user = (SELECT VALUE id FROM rebase_user WHERE username = $identifier_value AND login_access = true)[0];
        LET $email_user = (SELECT VALUE principal FROM authentication_email
            WHERE address = $identifier_value AND verified_revision = revision AND principal.login_access = true)[0];
        LET $principal = IF $email_user != NONE THEN $email_user ELSE $username_user END;
        LET $account = IF $principal = NONE THEN NONE ELSE (SELECT * FROM type::record($principal))[0] END;
        IF $account = NONE OR $account.password = NONE OR $password = NONE
            OR !crypto::argon2::compare($account.password, $password) { RETURN NONE; };
        LET $verified = (SELECT VALUE id FROM authentication_email WHERE principal = $principal AND verified_revision = revision).len();
        IF $verified = 0 { RETURN NONE; };
        RETURN $principal;
    }
    AUTHENTICATE { IF !$auth OR !$auth.login_access { RETURN NONE; }; RETURN $auth; }
    DURATION FOR SESSION 8h, FOR TOKEN 1h;

-- Asking for a reset code deliberately returns no session. SurrealDB commits
-- the one-time email request while signin remains unauthenticated.
DEFINE ACCESS OVERWRITE stocksense_recovery ON DATABASE TYPE RECORD
    SIGNIN {
        LET $identifier_value = string::lowercase(string::trim($identifier ?? ''));
        LET $identity = (SELECT VALUE id FROM authentication_email
            WHERE address = $identifier_value)[0];
        IF $identity != NONE { fn::stocksense::send_email_code($identity); };
        RETURN NONE;
    }
    DURATION FOR SESSION 1m, FOR TOKEN 1m;
