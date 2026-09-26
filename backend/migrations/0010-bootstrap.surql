-- REBASE: framework bootstrap
-- Framework bootstrap; project-specific root permissions are added by the compiler.
UPSERT rebase_group:root SET
    name = name ?? 'System Admins',
    role = role ?? ['node_create', 'node_select', 'node_update', 'node_delete'];

