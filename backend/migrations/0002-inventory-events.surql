-- REBASE: project events
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

