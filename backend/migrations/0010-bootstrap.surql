-- Initial administrator group.
UPSERT stocksense_group:root SET
    name = name ?? 'System Admins',
    role = role ?? ['node_create', 'node_select', 'node_update', 'node_delete'];
