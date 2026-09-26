-- STOCKSENSE: effect lifecycle fields
DEFINE FIELD OVERWRITE execute_at ON TABLE authentication_delivery_task TYPE datetime DEFAULT time::now()
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE stocksense_attempt = 0 AND stocksense_lease_token = NONE AND stocksense_outcome = NONE;

DEFINE FIELD OVERWRITE priority ON TABLE authentication_delivery_task TYPE int DEFAULT 50
    ASSERT $value >= 10 AND $value <= 100
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE stocksense_attempt = 0 AND stocksense_lease_token = NONE AND stocksense_outcome = NONE;

DEFINE FIELD OVERWRITE execution_id ON TABLE authentication_delivery_task TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE revision ON TABLE authentication_delivery_task TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE IF $value != NONE AND $value != $before THEN $value ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_execution_id ON TABLE authentication_delivery_task FIELDS execution_id UNIQUE;

DEFINE FIELD OVERWRITE stocksense_cancel_requested ON TABLE authentication_delivery_task TYPE bool
    VALUE IF $before = NONE THEN false ELSE $value END
    ASSERT ($value = false OR $value = true)
    PERMISSIONS FOR select WHERE true FOR create WHERE $value = false FOR update WHERE $value = true AND ($before = NONE OR $before = false);

DEFINE FIELD OVERWRITE stocksense_cancelled_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    VALUE IF $this.stocksense_cancel_requested = true AND ($before.stocksense_cancel_requested = NONE OR $before.stocksense_cancel_requested = false) THEN time::now() ELSE $before.stocksense_cancelled_at END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE stocksense_lease_token ON TABLE authentication_delivery_task TYPE option<uuid> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE stocksense_lease_until ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_provider_started_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE stocksense_outcome ON TABLE authentication_delivery_task TYPE option<string> DEFAULT NONE
    ASSERT $value = NONE OR $value IN ['succeeded', 'failed', 'ambiguous', 'partial']
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_attempt ON TABLE authentication_delivery_task TYPE int DEFAULT 0
    VALUE IF $before = NONE THEN ($value ?? 0) ELSE IF $value != NONE AND $value >= $before THEN $value ELSE $before END
    ASSERT $value >= 0
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_wake_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_finished_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_error ON TABLE authentication_delivery_task TYPE option<object> FLEXIBLE DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_status ON TABLE authentication_delivery_task TYPE string COMPUTED
    IF stocksense_lease_until != NONE AND stocksense_lease_until > time::now() THEN 'running'
    ELSE IF stocksense_provider_started_at != NONE THEN 'ambiguous'
    ELSE IF stocksense_cancel_requested = true AND stocksense_outcome = NONE THEN 'cancelled'
    ELSE IF stocksense_outcome != NONE THEN stocksense_outcome
    ELSE IF execute_at > time::now() THEN 'waiting'
    ELSE IF stocksense_wake_at != NONE AND stocksense_wake_at > time::now() THEN 'waiting'
    ELSE 'pending' END
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_stocksense_outcome ON TABLE authentication_delivery_task FIELDS stocksense_outcome;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_stocksense_finished_at ON TABLE authentication_delivery_task FIELDS stocksense_finished_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_stocksense_cancelled_at ON TABLE authentication_delivery_task FIELDS stocksense_cancelled_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_stocksense_wake_at ON TABLE authentication_delivery_task FIELDS stocksense_wake_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_execute_at ON TABLE authentication_delivery_task FIELDS execute_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_priority ON TABLE authentication_delivery_task FIELDS priority;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_stocksense_lease_until ON TABLE authentication_delivery_task FIELDS stocksense_lease_until;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_stocksense_provider_started_at ON TABLE authentication_delivery_task FIELDS stocksense_provider_started_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_stocksense_cancel_requested ON TABLE authentication_delivery_task FIELDS stocksense_cancel_requested;

DEFINE FIELD OVERWRITE execute_at ON TABLE stocksense_webhook_receipt TYPE datetime DEFAULT time::now()
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE stocksense_attempt = 0 AND stocksense_lease_token = NONE AND stocksense_outcome = NONE;

DEFINE FIELD OVERWRITE priority ON TABLE stocksense_webhook_receipt TYPE int DEFAULT 50
    ASSERT $value >= 10 AND $value <= 100
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE stocksense_attempt = 0 AND stocksense_lease_token = NONE AND stocksense_outcome = NONE;

DEFINE FIELD OVERWRITE execution_id ON TABLE stocksense_webhook_receipt TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE revision ON TABLE stocksense_webhook_receipt TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE IF $value != NONE AND $value != $before THEN $value ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_execution_id ON TABLE stocksense_webhook_receipt FIELDS execution_id UNIQUE;

DEFINE FIELD OVERWRITE stocksense_cancel_requested ON TABLE stocksense_webhook_receipt TYPE bool
    VALUE IF $before = NONE THEN false ELSE $value END
    ASSERT ($value = false OR $value = true)
    PERMISSIONS FOR select WHERE true FOR create WHERE $value = false FOR update WHERE $value = true AND ($before = NONE OR $before = false);

DEFINE FIELD OVERWRITE stocksense_cancelled_at ON TABLE stocksense_webhook_receipt TYPE option<datetime> DEFAULT NONE
    VALUE IF $this.stocksense_cancel_requested = true AND ($before.stocksense_cancel_requested = NONE OR $before.stocksense_cancel_requested = false) THEN time::now() ELSE $before.stocksense_cancelled_at END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE stocksense_lease_token ON TABLE stocksense_webhook_receipt TYPE option<uuid> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE stocksense_lease_until ON TABLE stocksense_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_provider_started_at ON TABLE stocksense_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE stocksense_outcome ON TABLE stocksense_webhook_receipt TYPE option<string> DEFAULT NONE
    ASSERT $value = NONE OR $value IN ['succeeded', 'failed', 'ambiguous', 'partial']
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_attempt ON TABLE stocksense_webhook_receipt TYPE int DEFAULT 0
    VALUE IF $before = NONE THEN ($value ?? 0) ELSE IF $value != NONE AND $value >= $before THEN $value ELSE $before END
    ASSERT $value >= 0
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_wake_at ON TABLE stocksense_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_finished_at ON TABLE stocksense_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_error ON TABLE stocksense_webhook_receipt TYPE option<object> FLEXIBLE DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE stocksense_status ON TABLE stocksense_webhook_receipt TYPE string COMPUTED
    IF stocksense_lease_until != NONE AND stocksense_lease_until > time::now() THEN 'running'
    ELSE IF stocksense_provider_started_at != NONE THEN 'ambiguous'
    ELSE IF stocksense_cancel_requested = true AND stocksense_outcome = NONE THEN 'cancelled'
    ELSE IF stocksense_outcome != NONE THEN stocksense_outcome
    ELSE IF execute_at > time::now() THEN 'waiting'
    ELSE IF stocksense_wake_at != NONE AND stocksense_wake_at > time::now() THEN 'waiting'
    ELSE 'pending' END
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_stocksense_outcome ON TABLE stocksense_webhook_receipt FIELDS stocksense_outcome;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_stocksense_finished_at ON TABLE stocksense_webhook_receipt FIELDS stocksense_finished_at;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_stocksense_cancelled_at ON TABLE stocksense_webhook_receipt FIELDS stocksense_cancelled_at;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_stocksense_wake_at ON TABLE stocksense_webhook_receipt FIELDS stocksense_wake_at;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_execute_at ON TABLE stocksense_webhook_receipt FIELDS execute_at;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_priority ON TABLE stocksense_webhook_receipt FIELDS priority;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_stocksense_lease_until ON TABLE stocksense_webhook_receipt FIELDS stocksense_lease_until;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_stocksense_provider_started_at ON TABLE stocksense_webhook_receipt FIELDS stocksense_provider_started_at;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_stocksense_cancel_requested ON TABLE stocksense_webhook_receipt FIELDS stocksense_cancel_requested;


