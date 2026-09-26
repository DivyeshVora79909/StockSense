-- STOCKSENSE: audit log
DEFINE EVENT OVERWRITE stocksense_audit_unit_of_measure ON TABLE unit_of_measure
    WHEN $event IN ['CREATE', 'DELETE'] OR ($event = 'UPDATE' AND (($before.code ?? NONE) != ($after.code ?? NONE) OR ($before.name ?? NONE) != ($after.name ?? NONE))) THEN {
        LET $audit_changed_fields = [IF ($before.code ?? NONE) != ($after.code ?? NONE) THEN 'code' ELSE NONE END, IF ($before.name ?? NONE) != ($after.name ?? NONE) THEN 'name' ELSE NONE END].filter(|$field| $field != NONE);
        LET $audit_before = IF $event = 'CREATE' THEN NONE ELSE { code: $before.code, name: $before.name } END;
        LET $audit_after = IF $event = 'DELETE' THEN NONE ELSE { code: $after.code, name: $after.name } END;
        CREATE audit_mutation CONTENT {
            at: time::now(),
            event: $event,
            table_name: 'unit_of_measure',
            target: IF $event = 'DELETE' THEN $before.id ELSE $after.id END,
            actor: $auth,
            changed_fields: $audit_changed_fields,
            before: $audit_before,
            after: $audit_after
        };
    };

DEFINE EVENT OVERWRITE stocksense_audit_product_category ON TABLE product_category
    WHEN $event IN ['CREATE', 'DELETE'] OR ($event = 'UPDATE' AND (($before.name ?? NONE) != ($after.name ?? NONE))) THEN {
        LET $audit_changed_fields = [IF ($before.name ?? NONE) != ($after.name ?? NONE) THEN 'name' ELSE NONE END].filter(|$field| $field != NONE);
        LET $audit_before = IF $event = 'CREATE' THEN NONE ELSE { name: $before.name } END;
        LET $audit_after = IF $event = 'DELETE' THEN NONE ELSE { name: $after.name } END;
        CREATE audit_mutation CONTENT {
            at: time::now(),
            event: $event,
            table_name: 'product_category',
            target: IF $event = 'DELETE' THEN $before.id ELSE $after.id END,
            actor: $auth,
            changed_fields: $audit_changed_fields,
            before: $audit_before,
            after: $audit_after
        };
    };

DEFINE EVENT OVERWRITE stocksense_audit_warehouse ON TABLE warehouse
    WHEN $event IN ['CREATE', 'DELETE'] OR ($event = 'UPDATE' AND (($before.name ?? NONE) != ($after.name ?? NONE) OR ($before.code ?? NONE) != ($after.code ?? NONE) OR ($before.active ?? NONE) != ($after.active ?? NONE))) THEN {
        LET $audit_changed_fields = [IF ($before.name ?? NONE) != ($after.name ?? NONE) THEN 'name' ELSE NONE END, IF ($before.code ?? NONE) != ($after.code ?? NONE) THEN 'code' ELSE NONE END, IF ($before.active ?? NONE) != ($after.active ?? NONE) THEN 'active' ELSE NONE END].filter(|$field| $field != NONE);
        LET $audit_before = IF $event = 'CREATE' THEN NONE ELSE { name: $before.name, code: $before.code, active: $before.active } END;
        LET $audit_after = IF $event = 'DELETE' THEN NONE ELSE { name: $after.name, code: $after.code, active: $after.active } END;
        CREATE audit_mutation CONTENT {
            at: time::now(),
            event: $event,
            table_name: 'warehouse',
            target: IF $event = 'DELETE' THEN $before.id ELSE $after.id END,
            actor: $auth,
            changed_fields: $audit_changed_fields,
            before: $audit_before,
            after: $audit_after
        };
    };

DEFINE EVENT OVERWRITE stocksense_audit_stock_location ON TABLE stock_location
    WHEN $event IN ['CREATE', 'DELETE'] OR ($event = 'UPDATE' AND (($before.warehouse ?? NONE) != ($after.warehouse ?? NONE) OR ($before.parent ?? NONE) != ($after.parent ?? NONE) OR ($before.name ?? NONE) != ($after.name ?? NONE) OR ($before.code ?? NONE) != ($after.code ?? NONE) OR ($before.active ?? NONE) != ($after.active ?? NONE))) THEN {
        LET $audit_changed_fields = [IF ($before.warehouse ?? NONE) != ($after.warehouse ?? NONE) THEN 'warehouse' ELSE NONE END, IF ($before.parent ?? NONE) != ($after.parent ?? NONE) THEN 'parent' ELSE NONE END, IF ($before.name ?? NONE) != ($after.name ?? NONE) THEN 'name' ELSE NONE END, IF ($before.code ?? NONE) != ($after.code ?? NONE) THEN 'code' ELSE NONE END, IF ($before.active ?? NONE) != ($after.active ?? NONE) THEN 'active' ELSE NONE END].filter(|$field| $field != NONE);
        LET $audit_before = IF $event = 'CREATE' THEN NONE ELSE { warehouse: $before.warehouse, parent: $before.parent, name: $before.name, code: $before.code, active: $before.active } END;
        LET $audit_after = IF $event = 'DELETE' THEN NONE ELSE { warehouse: $after.warehouse, parent: $after.parent, name: $after.name, code: $after.code, active: $after.active } END;
        CREATE audit_mutation CONTENT {
            at: time::now(),
            event: $event,
            table_name: 'stock_location',
            target: IF $event = 'DELETE' THEN $before.id ELSE $after.id END,
            actor: $auth,
            changed_fields: $audit_changed_fields,
            before: $audit_before,
            after: $audit_after
        };
    };

DEFINE EVENT OVERWRITE stocksense_audit_product ON TABLE product
    WHEN $event IN ['CREATE', 'DELETE'] OR ($event = 'UPDATE' AND (($before.name ?? NONE) != ($after.name ?? NONE) OR ($before.sku ?? NONE) != ($after.sku ?? NONE) OR ($before.category ?? NONE) != ($after.category ?? NONE) OR ($before.unit ?? NONE) != ($after.unit ?? NONE) OR ($before.reorder_point ?? NONE) != ($after.reorder_point ?? NONE) OR ($before.active ?? NONE) != ($after.active ?? NONE))) THEN {
        LET $audit_changed_fields = [IF ($before.name ?? NONE) != ($after.name ?? NONE) THEN 'name' ELSE NONE END, IF ($before.sku ?? NONE) != ($after.sku ?? NONE) THEN 'sku' ELSE NONE END, IF ($before.category ?? NONE) != ($after.category ?? NONE) THEN 'category' ELSE NONE END, IF ($before.unit ?? NONE) != ($after.unit ?? NONE) THEN 'unit' ELSE NONE END, IF ($before.reorder_point ?? NONE) != ($after.reorder_point ?? NONE) THEN 'reorder_point' ELSE NONE END, IF ($before.active ?? NONE) != ($after.active ?? NONE) THEN 'active' ELSE NONE END].filter(|$field| $field != NONE);
        LET $audit_before = IF $event = 'CREATE' THEN NONE ELSE { name: $before.name, sku: $before.sku, category: $before.category, unit: $before.unit, reorder_point: $before.reorder_point, active: $before.active } END;
        LET $audit_after = IF $event = 'DELETE' THEN NONE ELSE { name: $after.name, sku: $after.sku, category: $after.category, unit: $after.unit, reorder_point: $after.reorder_point, active: $after.active } END;
        CREATE audit_mutation CONTENT {
            at: time::now(),
            event: $event,
            table_name: 'product',
            target: IF $event = 'DELETE' THEN $before.id ELSE $after.id END,
            actor: $auth,
            changed_fields: $audit_changed_fields,
            before: $audit_before,
            after: $audit_after
        };
    };

DEFINE EVENT OVERWRITE stocksense_audit_stock_position ON TABLE stock_position
    WHEN $event IN ['CREATE', 'DELETE'] OR ($event = 'UPDATE' AND (($before.product ?? NONE) != ($after.product ?? NONE) OR ($before.location ?? NONE) != ($after.location ?? NONE))) THEN {
        LET $audit_changed_fields = [IF ($before.product ?? NONE) != ($after.product ?? NONE) THEN 'product' ELSE NONE END, IF ($before.location ?? NONE) != ($after.location ?? NONE) THEN 'location' ELSE NONE END].filter(|$field| $field != NONE);
        LET $audit_before = IF $event = 'CREATE' THEN NONE ELSE { product: $before.product, location: $before.location } END;
        LET $audit_after = IF $event = 'DELETE' THEN NONE ELSE { product: $after.product, location: $after.location } END;
        CREATE audit_mutation CONTENT {
            at: time::now(),
            event: $event,
            table_name: 'stock_position',
            target: IF $event = 'DELETE' THEN $before.id ELSE $after.id END,
            actor: $auth,
            changed_fields: $audit_changed_fields,
            before: $audit_before,
            after: $audit_after
        };
    };

DEFINE EVENT OVERWRITE stocksense_audit_stock_operation ON TABLE stock_operation
    WHEN $event IN ['CREATE', 'DELETE'] OR ($event = 'UPDATE' AND (($before.kind ?? NONE) != ($after.kind ?? NONE) OR ($before.status ?? NONE) != ($after.status ?? NONE) OR ($before.reference ?? NONE) != ($after.reference ?? NONE) OR ($before.party_name ?? NONE) != ($after.party_name ?? NONE) OR ($before.location ?? NONE) != ($after.location ?? NONE) OR ($before.from_location ?? NONE) != ($after.from_location ?? NONE) OR ($before.to_location ?? NONE) != ($after.to_location ?? NONE) OR ($before.effective_at ?? NONE) != ($after.effective_at ?? NONE) OR ($before.created_by_name ?? NONE) != ($after.created_by_name ?? NONE))) THEN {
        LET $audit_changed_fields = [IF ($before.kind ?? NONE) != ($after.kind ?? NONE) THEN 'kind' ELSE NONE END, IF ($before.status ?? NONE) != ($after.status ?? NONE) THEN 'status' ELSE NONE END, IF ($before.reference ?? NONE) != ($after.reference ?? NONE) THEN 'reference' ELSE NONE END, IF ($before.party_name ?? NONE) != ($after.party_name ?? NONE) THEN 'party_name' ELSE NONE END, IF ($before.location ?? NONE) != ($after.location ?? NONE) THEN 'location' ELSE NONE END, IF ($before.from_location ?? NONE) != ($after.from_location ?? NONE) THEN 'from_location' ELSE NONE END, IF ($before.to_location ?? NONE) != ($after.to_location ?? NONE) THEN 'to_location' ELSE NONE END, IF ($before.effective_at ?? NONE) != ($after.effective_at ?? NONE) THEN 'effective_at' ELSE NONE END, IF ($before.created_by_name ?? NONE) != ($after.created_by_name ?? NONE) THEN 'created_by_name' ELSE NONE END].filter(|$field| $field != NONE);
        LET $audit_before = IF $event = 'CREATE' THEN NONE ELSE { kind: $before.kind, status: $before.status, reference: $before.reference, party_name: $before.party_name, location: $before.location, from_location: $before.from_location, to_location: $before.to_location, effective_at: $before.effective_at, created_by_name: $before.created_by_name } END;
        LET $audit_after = IF $event = 'DELETE' THEN NONE ELSE { kind: $after.kind, status: $after.status, reference: $after.reference, party_name: $after.party_name, location: $after.location, from_location: $after.from_location, to_location: $after.to_location, effective_at: $after.effective_at, created_by_name: $after.created_by_name } END;
        CREATE audit_mutation CONTENT {
            at: time::now(),
            event: $event,
            table_name: 'stock_operation',
            target: IF $event = 'DELETE' THEN $before.id ELSE $after.id END,
            actor: $auth,
            changed_fields: $audit_changed_fields,
            before: $audit_before,
            after: $audit_after
        };
    };





