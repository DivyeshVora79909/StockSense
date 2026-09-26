-- REBASE: ownership, RLS, and flags
DEFINE TABLE OVERWRITE unit_of_measure SCHEMAFULL PERMISSIONS
    FOR select WHERE 'unit_of_measure_select' IN $auth.permissions AND (!!visibility OR readers_index CONTAINSANY $auth.z_access_index OR <string>owned_by IN $auth.z_access_index)
    FOR create WHERE 'unit_of_measure_create' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR update WHERE 'unit_of_measure_update' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR delete WHERE 'unit_of_measure_delete' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.dominates);

DEFINE FIELD OVERWRITE owned_by ON TABLE unit_of_measure TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE unit_of_measure TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE unit_of_measure TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE unit_of_measure TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE unit_of_measure TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE unit_of_measure TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE unit_of_measure TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON unit_of_measure WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.code != $after.code OR $before.name != $after.name OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

DEFINE TABLE OVERWRITE product_category SCHEMAFULL PERMISSIONS
    FOR select WHERE 'product_category_select' IN $auth.permissions AND (!!visibility OR readers_index CONTAINSANY $auth.z_access_index OR <string>owned_by IN $auth.z_access_index)
    FOR create WHERE 'product_category_create' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR update WHERE 'product_category_update' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR delete WHERE 'product_category_delete' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.dominates);

DEFINE FIELD OVERWRITE owned_by ON TABLE product_category TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE product_category TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE product_category TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE product_category TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE product_category TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE product_category TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE product_category TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON product_category WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.name != $after.name OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

DEFINE TABLE OVERWRITE warehouse SCHEMAFULL PERMISSIONS
    FOR select WHERE 'warehouse_select' IN $auth.permissions AND (!!visibility OR readers_index CONTAINSANY $auth.z_access_index OR <string>owned_by IN $auth.z_access_index)
    FOR create WHERE 'warehouse_create' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR update WHERE 'warehouse_update' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR delete WHERE 'warehouse_delete' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.dominates);

DEFINE FIELD OVERWRITE owned_by ON TABLE warehouse TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE warehouse TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE warehouse TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE warehouse TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE warehouse TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE warehouse TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE warehouse TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON warehouse WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.name != $after.name OR $before.code != $after.code OR $before.active != $after.active OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

DEFINE TABLE OVERWRITE stock_location SCHEMAFULL PERMISSIONS
    FOR select WHERE 'stock_location_select' IN $auth.permissions AND (!!visibility OR readers_index CONTAINSANY $auth.z_access_index OR <string>owned_by IN $auth.z_access_index)
    FOR create WHERE 'stock_location_create' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR update WHERE 'stock_location_update' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR delete WHERE 'stock_location_delete' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.dominates);

DEFINE FIELD OVERWRITE owned_by ON TABLE stock_location TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE stock_location TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE stock_location TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE stock_location TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE stock_location TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE stock_location TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE stock_location TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON stock_location WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.warehouse != $after.warehouse OR $before.parent != $after.parent OR $before.name != $after.name OR $before.code != $after.code OR $before.active != $after.active OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

DEFINE TABLE OVERWRITE product SCHEMAFULL PERMISSIONS
    FOR select WHERE 'product_select' IN $auth.permissions AND (!!visibility OR readers_index CONTAINSANY $auth.z_access_index OR <string>owned_by IN $auth.z_access_index)
    FOR create WHERE 'product_create' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR update WHERE 'product_update' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR delete WHERE 'product_delete' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.dominates);

DEFINE FIELD OVERWRITE owned_by ON TABLE product TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE product TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE product TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE product TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE product TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE product TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE product TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON product WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.name != $after.name OR $before.sku != $after.sku OR $before.category != $after.category OR $before.unit != $after.unit OR $before.reorder_point != $after.reorder_point OR $before.active != $after.active OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

DEFINE TABLE OVERWRITE stock_position SCHEMAFULL PERMISSIONS
    FOR select WHERE 'stock_position_select' IN $auth.permissions AND (!!visibility OR readers_index CONTAINSANY $auth.z_access_index OR <string>owned_by IN $auth.z_access_index)
    FOR create WHERE 'stock_position_create' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR update WHERE 'stock_position_update' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR delete WHERE 'stock_position_delete' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.dominates);

DEFINE FIELD OVERWRITE owned_by ON TABLE stock_position TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE stock_position TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE stock_position TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE stock_position TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE stock_position TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE stock_position TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE stock_position TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON stock_position WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.product != $after.product OR $before.location != $after.location OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

DEFINE TABLE OVERWRITE stock_operation SCHEMAFULL PERMISSIONS
    FOR select WHERE 'stock_operation_select' IN $auth.permissions AND (!!visibility OR readers_index CONTAINSANY $auth.z_access_index OR <string>owned_by IN $auth.z_access_index)
    FOR create WHERE 'stock_operation_create' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR update WHERE 'stock_operation_update' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.parent_groups OR owned_by IN $auth.dominates)
    FOR delete WHERE 'stock_operation_delete' IN $auth.permissions AND (owned_by = $auth OR owned_by IN $auth.dominates);

DEFINE FIELD OVERWRITE owned_by ON TABLE stock_operation TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE stock_operation TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE stock_operation TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE stock_operation TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE stock_operation TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE stock_operation TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE stock_operation TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON stock_operation WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.kind != $after.kind OR $before.status != $after.status OR $before.reference != $after.reference OR $before.party_name != $after.party_name OR $before.location != $after.location OR $before.from_location != $after.from_location OR $before.to_location != $after.to_location OR $before.effective_at != $after.effective_at OR $before.lines != $after.lines OR $before.created_by_name != $after.created_by_name OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

DEFINE TABLE OVERWRITE stock_ledger SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE owned_by ON TABLE stock_ledger TYPE record<rebase_user | rebase_group> ASSERT record::exists($value) REFERENCE ON DELETE REJECT PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE $value = $before OR $before = $auth OR $before IN $auth.dominates;
DEFINE FIELD OVERWRITE readers_index ON TABLE stock_ledger TYPE array<string> VALUE [] PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON TABLE stock_ledger TYPE datetime VALUE $before OR time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON TABLE stock_ledger TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END PERMISSIONS FOR select, create WHERE true FOR update NONE;
DEFINE FIELD OVERWRITE created_by ON TABLE stock_ledger TYPE option<record<rebase_user>> VALUE $before OR $auth READONLY;
DEFINE FIELD OVERWRITE updated_by ON TABLE stock_ledger TYPE option<record<rebase_user>> PERMISSIONS FOR select WHERE true FOR create, update NONE;
DEFINE FIELD OVERWRITE system_ping ON TABLE stock_ledger TYPE datetime DEFAULT time::now() PERMISSIONS FOR update NONE;

DEFINE EVENT OVERWRITE rebase_touch ON stock_ledger WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND ($before.operation != $after.operation OR $before.product != $after.product OR $before.location != $after.location OR $before.position != $after.position OR $before.kind != $after.kind OR $before.quantity_delta != $after.quantity_delta OR $before.effective_at != $after.effective_at OR $before.owned_by != $after.owned_by)) THEN {
    UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE;
};

