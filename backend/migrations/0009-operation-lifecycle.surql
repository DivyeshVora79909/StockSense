-- REBASE: effect lifecycle fields
DEFINE FIELD OVERWRITE execute_at ON TABLE authentication_delivery_task TYPE datetime DEFAULT time::now()
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE rebase_attempt = 0 AND rebase_lease_token = NONE AND rebase_outcome = NONE;

DEFINE FIELD OVERWRITE priority ON TABLE authentication_delivery_task TYPE int DEFAULT 50
    ASSERT $value >= 10 AND $value <= 100
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE rebase_attempt = 0 AND rebase_lease_token = NONE AND rebase_outcome = NONE;

DEFINE FIELD OVERWRITE execution_id ON TABLE authentication_delivery_task TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE revision ON TABLE authentication_delivery_task TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE IF $value != NONE AND $value != $before THEN $value ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_execution_id ON TABLE authentication_delivery_task FIELDS execution_id UNIQUE;

DEFINE FIELD OVERWRITE rebase_cancel_requested ON TABLE authentication_delivery_task TYPE bool
    VALUE IF $before = NONE THEN false ELSE $value END
    ASSERT ($value = false OR $value = true)
    PERMISSIONS FOR select WHERE true FOR create WHERE $value = false FOR update WHERE $value = true AND ($before = NONE OR $before = false);

DEFINE FIELD OVERWRITE rebase_cancelled_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    VALUE IF $this.rebase_cancel_requested = true AND ($before.rebase_cancel_requested = NONE OR $before.rebase_cancel_requested = false) THEN time::now() ELSE $before.rebase_cancelled_at END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE rebase_lease_token ON TABLE authentication_delivery_task TYPE option<uuid> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE rebase_lease_until ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_provider_started_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE rebase_outcome ON TABLE authentication_delivery_task TYPE option<string> DEFAULT NONE
    ASSERT $value = NONE OR $value IN ['succeeded', 'failed', 'ambiguous', 'partial']
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_attempt ON TABLE authentication_delivery_task TYPE int DEFAULT 0
    VALUE IF $before = NONE THEN ($value ?? 0) ELSE IF $value != NONE AND $value >= $before THEN $value ELSE $before END
    ASSERT $value >= 0
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_wake_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_finished_at ON TABLE authentication_delivery_task TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_error ON TABLE authentication_delivery_task TYPE option<object> FLEXIBLE DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_status ON TABLE authentication_delivery_task TYPE string COMPUTED
    IF rebase_lease_until != NONE AND rebase_lease_until > time::now() THEN 'running'
    ELSE IF rebase_provider_started_at != NONE THEN 'ambiguous'
    ELSE IF rebase_cancel_requested = true AND rebase_outcome = NONE THEN 'cancelled'
    ELSE IF rebase_outcome != NONE THEN rebase_outcome
    ELSE IF execute_at > time::now() THEN 'waiting'
    ELSE IF rebase_wake_at != NONE AND rebase_wake_at > time::now() THEN 'waiting'
    ELSE 'pending' END
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_rebase_outcome ON TABLE authentication_delivery_task FIELDS rebase_outcome;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_rebase_finished_at ON TABLE authentication_delivery_task FIELDS rebase_finished_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_rebase_cancelled_at ON TABLE authentication_delivery_task FIELDS rebase_cancelled_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_rebase_wake_at ON TABLE authentication_delivery_task FIELDS rebase_wake_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_execute_at ON TABLE authentication_delivery_task FIELDS execute_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_priority ON TABLE authentication_delivery_task FIELDS priority;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_rebase_lease_until ON TABLE authentication_delivery_task FIELDS rebase_lease_until;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_rebase_provider_started_at ON TABLE authentication_delivery_task FIELDS rebase_provider_started_at;

DEFINE INDEX OVERWRITE idx_authentication_delivery_task_rebase_cancel_requested ON TABLE authentication_delivery_task FIELDS rebase_cancel_requested;

DEFINE FIELD OVERWRITE execute_at ON TABLE rebase_webhook_receipt TYPE datetime DEFAULT time::now()
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE rebase_attempt = 0 AND rebase_lease_token = NONE AND rebase_outcome = NONE;

DEFINE FIELD OVERWRITE priority ON TABLE rebase_webhook_receipt TYPE int DEFAULT 50
    ASSERT $value >= 10 AND $value <= 100
    PERMISSIONS FOR select WHERE true FOR create WHERE true FOR update WHERE rebase_attempt = 0 AND rebase_lease_token = NONE AND rebase_outcome = NONE;

DEFINE FIELD OVERWRITE execution_id ON TABLE rebase_webhook_receipt TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE revision ON TABLE rebase_webhook_receipt TYPE uuid
    VALUE IF $before = NONE THEN rand::uuid::v7() ELSE IF $value != NONE AND $value != $before THEN $value ELSE $before END
    PERMISSIONS FOR select, create, update NONE;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_execution_id ON TABLE rebase_webhook_receipt FIELDS execution_id UNIQUE;

DEFINE FIELD OVERWRITE rebase_cancel_requested ON TABLE rebase_webhook_receipt TYPE bool
    VALUE IF $before = NONE THEN false ELSE $value END
    ASSERT ($value = false OR $value = true)
    PERMISSIONS FOR select WHERE true FOR create WHERE $value = false FOR update WHERE $value = true AND ($before = NONE OR $before = false);

DEFINE FIELD OVERWRITE rebase_cancelled_at ON TABLE rebase_webhook_receipt TYPE option<datetime> DEFAULT NONE
    VALUE IF $this.rebase_cancel_requested = true AND ($before.rebase_cancel_requested = NONE OR $before.rebase_cancel_requested = false) THEN time::now() ELSE $before.rebase_cancelled_at END
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE rebase_lease_token ON TABLE rebase_webhook_receipt TYPE option<uuid> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE rebase_lease_until ON TABLE rebase_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_provider_started_at ON TABLE rebase_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select, create, update NONE;

DEFINE FIELD OVERWRITE rebase_outcome ON TABLE rebase_webhook_receipt TYPE option<string> DEFAULT NONE
    ASSERT $value = NONE OR $value IN ['succeeded', 'failed', 'ambiguous', 'partial']
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_attempt ON TABLE rebase_webhook_receipt TYPE int DEFAULT 0
    VALUE IF $before = NONE THEN ($value ?? 0) ELSE IF $value != NONE AND $value >= $before THEN $value ELSE $before END
    ASSERT $value >= 0
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_wake_at ON TABLE rebase_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_finished_at ON TABLE rebase_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_error ON TABLE rebase_webhook_receipt TYPE option<object> FLEXIBLE DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE FIELD OVERWRITE rebase_status ON TABLE rebase_webhook_receipt TYPE string COMPUTED
    IF rebase_lease_until != NONE AND rebase_lease_until > time::now() THEN 'running'
    ELSE IF rebase_provider_started_at != NONE THEN 'ambiguous'
    ELSE IF rebase_cancel_requested = true AND rebase_outcome = NONE THEN 'cancelled'
    ELSE IF rebase_outcome != NONE THEN rebase_outcome
    ELSE IF execute_at > time::now() THEN 'waiting'
    ELSE IF rebase_wake_at != NONE AND rebase_wake_at > time::now() THEN 'waiting'
    ELSE 'pending' END
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_rebase_outcome ON TABLE rebase_webhook_receipt FIELDS rebase_outcome;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_rebase_finished_at ON TABLE rebase_webhook_receipt FIELDS rebase_finished_at;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_rebase_cancelled_at ON TABLE rebase_webhook_receipt FIELDS rebase_cancelled_at;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_rebase_wake_at ON TABLE rebase_webhook_receipt FIELDS rebase_wake_at;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_execute_at ON TABLE rebase_webhook_receipt FIELDS execute_at;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_priority ON TABLE rebase_webhook_receipt FIELDS priority;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_rebase_lease_until ON TABLE rebase_webhook_receipt FIELDS rebase_lease_until;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_rebase_provider_started_at ON TABLE rebase_webhook_receipt FIELDS rebase_provider_started_at;

DEFINE INDEX OVERWRITE idx_rebase_webhook_receipt_rebase_cancel_requested ON TABLE rebase_webhook_receipt FIELDS rebase_cancel_requested;


