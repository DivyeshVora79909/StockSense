-- Authentication and shared account records.
-- Password is one optional credential. Authentication is established by a
-- successful access method, not by the presence of the password field.

DEFINE ACCESS OVERWRITE account_password ON DATABASE TYPE RECORD
    SIGNIN {
        LET $identifier_value = string::lowercase(string::trim($identifier ?? ""));
        LET $email_principal = (SELECT VALUE principal FROM authentication_email
            WHERE address = $identifier_value
              AND verified_revision = revision
              AND principal.login_access = true)[0];
        LET $phone_principal = (SELECT VALUE principal FROM authentication_phone
            WHERE number = $identifier_value
              AND verified_revision = revision
              AND principal.login_access = true)[0];
        LET $username_principal = (SELECT VALUE id FROM stocksense_user
            WHERE username = $identifier_value AND login_access = true)[0];
        LET $principal = IF $email_principal != NONE THEN $email_principal
            ELSE IF $phone_principal != NONE THEN $phone_principal
            ELSE $username_principal END;
        IF $principal = NONE { RETURN NONE; };

        -- A username is usable only after at least one identity has been
        -- verified. Email and phone candidates already carry that condition.
        IF $email_principal = NONE AND $phone_principal = NONE {
            LET $verified_count = (SELECT VALUE id FROM authentication_email
                WHERE principal = $principal AND verified_revision = revision).len()
                + (SELECT VALUE id FROM authentication_phone
                WHERE principal = $principal AND verified_revision = revision).len();
            IF $verified_count = 0 { RETURN NONE; };
        };

        LET $account = (SELECT * FROM type::record($principal))[0];
        IF $account = NONE OR $account.password = NONE OR $password = NONE
            OR !crypto::argon2::compare($account.password, $password) { RETURN NONE; };
        RETURN $principal;
    }
    AUTHENTICATE {
        IF !$auth OR !$auth.login_access { RETURN NONE; };
        RETURN $auth;
    }
    DURATION FOR SESSION 8h, FOR TOKEN 1h;

DEFINE ACCESS OVERWRITE account_code ON DATABASE TYPE RECORD
    SIGNIN {
        LET $identifier_value = string::lowercase(string::trim($identifier ?? ""));
        LET $code_value = string::trim($code ?? "");
        LET $password_action_value = string::lowercase(string::trim($password_action ?? "keep"));
        LET $password_value = $new_password ?? "";
        IF $password_action_value NOT IN ["keep", "set", "clear"] { RETURN NONE; };
        IF $password_action_value = "set" AND $password_value.len() < 8 { RETURN NONE; };
        IF !string::matches($code_value, /^[0-9]{6}$/) { RETURN NONE; };

        LET $email_identity = (SELECT * FROM authentication_email
            WHERE address = $identifier_value)[0];
        LET $phone_identity = (SELECT * FROM authentication_phone
            WHERE number = $identifier_value)[0];
        LET $username_principal = (SELECT VALUE id FROM stocksense_user
            WHERE username = $identifier_value AND login_access = true)[0];
        LET $username_challenge = (SELECT * FROM authentication_challenge
            WHERE principal = $username_principal
              AND consumed_at = NONE
              AND expires_at >= time::now()
            ORDER BY expires_at DESC)[0];
        LET $username_identity = IF $username_challenge = NONE THEN NONE
            ELSE (SELECT * FROM type::record($username_challenge.target))[0] END;
        LET $identity = IF $email_identity != NONE THEN $email_identity
            ELSE IF $phone_identity != NONE THEN $phone_identity
            ELSE $username_identity END;
        IF $identity = NONE { RETURN NONE; };
        LET $account = (SELECT * FROM type::record($identity.principal))[0];
        LET $challenge = (SELECT * FROM authentication_challenge
            WHERE target = $identity.id)[0];
        IF $account = NONE OR $challenge = NONE OR $account.login_access != true
            OR $challenge.consumed_at != NONE
            OR $challenge.expires_at < time::now()
            OR $challenge.principal_revision != $account.authentication_revision
            OR $challenge.target_revision != $identity.revision { RETURN NONE; };

        -- Incrementing attempts is the first atomic claim. A later conditional
        -- consume means concurrent correct submissions have exactly one winner.
        LET $attempt = (UPDATE $challenge.id SET attempts = attempts + 1
            WHERE consumed_at = NONE
              AND expires_at >= time::now()
              AND attempts < 5
            RETURN AFTER)[0];
        IF $attempt = NONE OR $code_value.len() = 0
            OR !crypto::argon2::compare($attempt.code_hash, $code_value) { RETURN NONE; };
        LET $consumed = (UPDATE $attempt.id SET consumed_at = time::now()
            WHERE consumed_at = NONE RETURN AFTER)[0];
        IF $consumed = NONE { RETURN NONE; };

        UPDATE $identity.id SET verified_revision = revision, verified_at = time::now();
        IF $password_action_value = "set" {
            UPDATE $account.id SET password = crypto::argon2::generate($password_value);
        } ELSE IF $password_action_value = "clear" {
            UPDATE $account.id SET password = NONE;
        };
        RETURN $account.id;
    }
    AUTHENTICATE {
        IF !$auth OR !$auth.login_access { RETURN NONE; };
        RETURN $auth;
    }
    DURATION FOR SESSION 8h, FOR TOKEN 1h;

-- Append-only operational history.
DEFINE TABLE OVERWRITE audit_mutation SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE at ON audit_mutation TYPE datetime;

DEFINE FIELD OVERWRITE event ON audit_mutation TYPE string ASSERT $value IN ['CREATE', 'UPDATE', 'DELETE'];

DEFINE FIELD OVERWRITE table_name ON audit_mutation TYPE string;

DEFINE FIELD OVERWRITE target ON audit_mutation TYPE record;

DEFINE FIELD OVERWRITE actor ON audit_mutation TYPE option<record>;

DEFINE FIELD OVERWRITE changed_fields ON audit_mutation TYPE array<string> DEFAULT [];

DEFINE FIELD OVERWRITE before ON audit_mutation TYPE option<object> FLEXIBLE DEFAULT NONE;

DEFINE FIELD OVERWRITE after ON audit_mutation TYPE option<object> FLEXIBLE DEFAULT NONE;

DEFINE INDEX OVERWRITE idx_audit_mutation_target ON audit_mutation COLUMNS target;

-- Authorization graph and principal fields.
-- Authentication identities and challenges are declared in authentication.surql.

-- USER
DEFINE TABLE OVERWRITE stocksense_user SCHEMAFULL PERMISSIONS
    FOR create WHERE 'node_create' IN $auth.permissions
    FOR select WHERE id = $auth OR ('node_select' IN $auth.permissions AND id IN $auth.dominates)
    FOR update WHERE id = $auth OR ('node_update' IN $auth.permissions AND id IN $auth.dominates)
    FOR delete WHERE 'node_delete' IN $auth.permissions AND id IN $auth.dominates
    ;

DEFINE FIELD OVERWRITE name ON stocksense_user TYPE string VALUE {
        LET $clean_name = string::trim($value ?? "");
        IF !$clean_name { THROW "VALIDATION_ERR: Invalid Name"; };
        RETURN $clean_name;
    };

DEFINE FIELD OVERWRITE username ON stocksense_user TYPE option<string> DEFAULT NONE VALUE {
        IF $value = NONE { RETURN NONE; };
        LET $clean_username = string::lowercase(string::trim($value));
        IF !string::matches($clean_username, /^[a-z0-9][a-z0-9_.-]{8,31}$/) {
            THROW "VALIDATION_ERR: Invalid username";
        };
        RETURN $clean_username;
    } ;

DEFINE FIELD OVERWRITE login_access ON stocksense_user TYPE bool DEFAULT true
        PERMISSIONS FOR update WHERE id != $auth;

-- A password is one credential option, not the authenticated-state flag.
    -- NONE is valid while a delivered email/phone challenge or OAuth is used.
    DEFINE FIELD OVERWRITE password ON stocksense_user TYPE option<string>
        DEFAULT NONE
        PERMISSIONS FOR select NONE FOR create, update NONE
        ;

-- Incremented by authentication events when a credential/identity changes.
    -- It is private and is used to fence outstanding challenges.
    DEFINE FIELD OVERWRITE authentication_revision ON stocksense_user TYPE int
        DEFAULT 1
        VALUE {
            IF $before = NONE { RETURN 1; };
            RETURN $value;
        }
        ASSERT $value >= 1
        PERMISSIONS FOR select NONE FOR create WHERE true FOR update NONE
        ;

DEFINE FIELD OVERWRITE parents ON stocksense_user TYPE array<record<stocksense_user | stocksense_group>>
        DEFAULT IF $auth THEN [$auth] ELSE [] END
        VALUE array::distinct($value ?? [])
        -- Validate only edges introduced or removed by this mutation. Existing
        -- edges may be invisible to a dominating actor.
        ASSERT $value.len() > 0
            AND array::all(array::difference($value ?? [], $before ?? []), |$parent| record::exists($parent))
        REFERENCE ON DELETE REJECT
        PERMISSIONS FOR update WHERE id != $auth;

DEFINE FIELD OVERWRITE parent_groups ON stocksense_user TYPE array<record<stocksense_group>>
        VALUE array::distinct(($this.parents ?? []).filter(|$p| record::tb($p) = 'stocksense_group'))
        PERMISSIONS FOR create, update NONE
        ;

DEFINE FIELD OVERWRITE permissions ON stocksense_user TYPE array<string>
        VALUE array::distinct(array::flatten($this.parent_groups.role ?? [])).filter(|$permission| $permission != NONE)
        PERMISSIONS FOR create, update NONE
        ;

DEFINE FIELD OVERWRITE dominates ON stocksense_user TYPE array<record<stocksense_user | stocksense_group>> VALUE {
        LET $ch_users = $this.id<~(stocksense_user FIELD parents);
        LET $ch_groups = $this.id<~(stocksense_group FIELD parents);

        RETURN array::distinct(array::flatten([
            $ch_users,
            array::flatten($ch_users.dominates),
            $ch_groups,
            array::flatten($ch_groups.dominates)
        ])).filter(|$node| $node != NONE);
    }
    PERMISSIONS FOR create, update NONE
    ;

DEFINE FIELD OVERWRITE created_at ON stocksense_user TYPE datetime VALUE $before OR time::now() READONLY;

DEFINE FIELD OVERWRITE updated_at ON stocksense_user TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END
        PERMISSIONS FOR select, create WHERE true FOR update NONE ;

DEFINE FIELD OVERWRITE created_by ON stocksense_user TYPE option<record<stocksense_user>> VALUE $before OR $auth READONLY;

DEFINE FIELD OVERWRITE updated_by ON stocksense_user TYPE option<record<stocksense_user>>
        PERMISSIONS FOR select WHERE true FOR create, update NONE ;

DEFINE FIELD OVERWRITE z_access_index ON stocksense_user TYPE array<string>
        VALUE array::distinct(array::concat(
            [<string>$this.id],
            ($this.parent_groups ?? []).map(|$node| <string>$node),
            ($this.dominates ?? []).map(|$node| <string>$node)
        ))
        PERMISSIONS FOR create, update NONE
        ;

DEFINE INDEX OVERWRITE idx_user_username ON stocksense_user COLUMNS username UNIQUE;

-- GROUPS
DEFINE TABLE OVERWRITE stocksense_group SCHEMAFULL PERMISSIONS
    FOR create WHERE 'node_create' IN $auth.permissions
    FOR select WHERE 'node_select' IN $auth.permissions AND (id IN $auth.dominates OR id IN $auth.parent_groups)
    FOR update WHERE 'node_update' IN $auth.permissions AND id IN $auth.dominates
    FOR delete WHERE 'node_delete' IN $auth.permissions AND id IN $auth.dominates
    ;

DEFINE FIELD OVERWRITE name ON stocksense_group TYPE string VALUE {
        LET $clean_name = string::trim($value ?? "");
        IF !$clean_name { THROW "VALIDATION_ERR: Invalid Name"; };
        RETURN $clean_name;
    };

DEFINE FIELD OVERWRITE role ON stocksense_group TYPE array<string> DEFAULT [] VALUE array::distinct($value ?? []);

DEFINE FIELD OVERWRITE parents ON stocksense_group TYPE array<record<stocksense_user | stocksense_group>>
        DEFAULT IF $auth THEN [$auth] ELSE [] END
        VALUE array::distinct($value ?? [])
        ASSERT id = stocksense_group:root OR ($value.len() > 0
            AND array::all(array::difference($value ?? [], $before ?? []), |$parent| record::exists($parent)))
        REFERENCE ON DELETE REJECT
        PERMISSIONS FOR update WHERE id != $auth;

DEFINE FIELD OVERWRITE parent_groups ON stocksense_group TYPE array<record<stocksense_group>>
        VALUE array::distinct(($this.parents ?? []).filter(|$p| record::tb($p) = 'stocksense_group'))
        PERMISSIONS FOR create, update NONE
        ;

DEFINE FIELD OVERWRITE dominates ON stocksense_group TYPE array<record<stocksense_user | stocksense_group>> VALUE {
        LET $ch_users = $this.id<~(stocksense_user FIELD parents);
        LET $ch_groups = $this.id<~(stocksense_group FIELD parents);

        RETURN array::distinct(array::flatten([
            $ch_users,
            array::flatten($ch_users.dominates),
            $ch_groups,
            array::flatten($ch_groups.dominates)
        ])).filter(|$node| $node != NONE);
    }
    PERMISSIONS FOR create, update NONE
    ;

DEFINE FIELD OVERWRITE created_at ON stocksense_group TYPE datetime VALUE $before OR time::now() READONLY;

DEFINE FIELD OVERWRITE updated_at ON stocksense_group TYPE datetime VALUE IF $before = NONE THEN time::now() ELSE $value END
        PERMISSIONS FOR select, create WHERE true FOR update NONE ;

DEFINE FIELD OVERWRITE created_by ON stocksense_group TYPE option<record<stocksense_user>> VALUE $before OR $auth READONLY;

DEFINE FIELD OVERWRITE updated_by ON stocksense_group TYPE option<record<stocksense_user>>
        PERMISSIONS FOR select WHERE true FOR create, update NONE ;

-- Authentication data is deliberately separate from the authorization graph.
-- A principal may have zero or more delivered identities and may authenticate
-- with a password, a delivered one-time code, or OAuth when an identity is
-- currently verified.

-- A recent record token is required when a principal edits its own identities.
-- Dominating administrators retain the normal graph-based management path.
-- The ten-minute window is an access policy constant, not an auth-state field.

-- BYOC recovery delivery. Only a root/deployment administrator can read or
-- provision these records. The anonymous challenge endpoint resolves a fixed
-- policy row and never accepts a configuration record from the caller.
DEFINE TABLE OVERWRITE stocksense_email_delivery_config SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE api_key ON stocksense_email_delivery_config TYPE string
    ASSERT $value.len() > 0 PERMISSIONS NONE;

DEFINE FIELD OVERWRITE from_email ON stocksense_email_delivery_config TYPE string
    ASSERT string::is_email($value) PERMISSIONS NONE;

DEFINE FIELD OVERWRITE from_name ON stocksense_email_delivery_config TYPE string
    ASSERT $value.len() > 0 PERMISSIONS NONE;

DEFINE FIELD OVERWRITE reply_to ON stocksense_email_delivery_config TYPE option<string> DEFAULT NONE
    ASSERT $value = NONE OR string::is_email($value) PERMISSIONS NONE;

DEFINE TABLE OVERWRITE stocksense_sms_delivery_config SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE account_sid ON stocksense_sms_delivery_config TYPE string
    ASSERT $value.len() > 0 PERMISSIONS NONE;

DEFINE FIELD OVERWRITE auth_token ON stocksense_sms_delivery_config TYPE option<string> DEFAULT NONE
    PERMISSIONS NONE;

DEFINE FIELD OVERWRITE api_key_sid ON stocksense_sms_delivery_config TYPE option<string> DEFAULT NONE
    PERMISSIONS NONE;

DEFINE FIELD OVERWRITE api_key_secret ON stocksense_sms_delivery_config TYPE option<string> DEFAULT NONE
    PERMISSIONS NONE;

DEFINE FIELD OVERWRITE from_number ON stocksense_sms_delivery_config TYPE string
    ASSERT string::matches($value, /^\+[1-9][0-9]{7,14}$/) PERMISSIONS NONE;

DEFINE TABLE OVERWRITE stocksense_authentication_delivery_policy SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE email_configuration ON stocksense_authentication_delivery_policy
    TYPE option<record<stocksense_email_delivery_config>> DEFAULT NONE
    REFERENCE ON DELETE REJECT PERMISSIONS NONE;

DEFINE FIELD OVERWRITE phone_configuration ON stocksense_authentication_delivery_policy
    TYPE option<record<stocksense_sms_delivery_config>> DEFAULT NONE
    REFERENCE ON DELETE REJECT PERMISSIONS NONE;

-- EMAIL IDENTITIES
DEFINE TABLE OVERWRITE authentication_email SCHEMAFULL PERMISSIONS
    FOR create WHERE $auth AND ((principal = $auth AND $token.iat >= time::unix(time::now()) - 600) OR principal IN $auth.dominates)
    FOR select WHERE $auth AND (principal = $auth OR principal IN $auth.dominates)
    FOR update WHERE $auth AND ((principal = $auth AND $token.iat >= time::unix(time::now()) - 600) OR principal IN $auth.dominates)
    FOR delete WHERE $auth AND ((principal = $auth AND $token.iat >= time::unix(time::now()) - 600) OR principal IN $auth.dominates);

DEFINE FIELD OVERWRITE principal ON authentication_email TYPE record<stocksense_user>
        ASSERT record::exists($value)
        REFERENCE ON DELETE CASCADE
        PERMISSIONS FOR update NONE;

DEFINE FIELD OVERWRITE address ON authentication_email TYPE string VALUE {
        LET $email = string::lowercase(string::trim($value ?? ""));
        IF !string::is_email($email) { THROW "VALIDATION_ERR: Invalid authentication email"; };
        RETURN $email;
    };

DEFINE FIELD OVERWRITE label ON authentication_email TYPE option<string> DEFAULT NONE;

DEFINE FIELD OVERWRITE priority ON authentication_email TYPE int DEFAULT 0 ASSERT $value >= 0 AND $value <= 1000;

DEFINE FIELD OVERWRITE revision ON authentication_email TYPE int
        DEFAULT 1
        VALUE {
            IF $before = NONE { RETURN 1; };
            RETURN $value;
        }
        ASSERT $value >= 1
        PERMISSIONS FOR create WHERE true FOR update NONE
        ;

DEFINE FIELD OVERWRITE verified_revision ON authentication_email TYPE option<int> DEFAULT NONE
        PERMISSIONS FOR select WHERE $auth AND (principal = $auth OR principal IN $auth.dominates) FOR create, update NONE
        ;

DEFINE FIELD OVERWRITE verified_at ON authentication_email TYPE option<datetime> DEFAULT NONE
        PERMISSIONS FOR select WHERE $auth AND (principal = $auth OR principal IN $auth.dominates) FOR create, update NONE
        ;

DEFINE INDEX OVERWRITE idx_authentication_email_address ON authentication_email COLUMNS address UNIQUE;

DEFINE INDEX OVERWRITE idx_authentication_email_principal ON authentication_email COLUMNS principal;

-- PHONE IDENTITIES
DEFINE TABLE OVERWRITE authentication_phone SCHEMAFULL PERMISSIONS
    FOR create WHERE $auth AND ((principal = $auth AND $token.iat >= time::unix(time::now()) - 600) OR principal IN $auth.dominates)
    FOR select WHERE $auth AND (principal = $auth OR principal IN $auth.dominates)
    FOR update WHERE $auth AND ((principal = $auth AND $token.iat >= time::unix(time::now()) - 600) OR principal IN $auth.dominates)
    FOR delete WHERE $auth AND ((principal = $auth AND $token.iat >= time::unix(time::now()) - 600) OR principal IN $auth.dominates);

DEFINE FIELD OVERWRITE principal ON authentication_phone TYPE record<stocksense_user>
        ASSERT record::exists($value)
        REFERENCE ON DELETE CASCADE
        PERMISSIONS FOR update NONE;

DEFINE FIELD OVERWRITE number ON authentication_phone TYPE string VALUE {
        LET $phone = string::trim($value ?? "");
        IF !string::matches($phone, /^\+[1-9][0-9]{7,14}$/) { THROW "VALIDATION_ERR: Invalid authentication phone"; };
        RETURN $phone;
    };

DEFINE FIELD OVERWRITE label ON authentication_phone TYPE option<string> DEFAULT NONE;

DEFINE FIELD OVERWRITE priority ON authentication_phone TYPE int DEFAULT 0 ASSERT $value >= 0 AND $value <= 1000;

DEFINE FIELD OVERWRITE revision ON authentication_phone TYPE int
        DEFAULT 1
        VALUE {
            IF $before = NONE { RETURN 1; };
            RETURN $value;
        }
        ASSERT $value >= 1
        PERMISSIONS FOR create WHERE true FOR update NONE
        ;

DEFINE FIELD OVERWRITE verified_revision ON authentication_phone TYPE option<int> DEFAULT NONE
        PERMISSIONS FOR select WHERE $auth AND (principal = $auth OR principal IN $auth.dominates) FOR create, update NONE
        ;

DEFINE FIELD OVERWRITE verified_at ON authentication_phone TYPE option<datetime> DEFAULT NONE
        PERMISSIONS FOR select WHERE $auth AND (principal = $auth OR principal IN $auth.dominates) FOR create, update NONE
        ;

DEFINE INDEX OVERWRITE idx_authentication_phone_number ON authentication_phone COLUMNS number UNIQUE;

DEFINE INDEX OVERWRITE idx_authentication_phone_principal ON authentication_phone COLUMNS principal;

-- ONE ACTIVE CHALLENGE PER IDENTITY
DEFINE TABLE OVERWRITE authentication_challenge SCHEMAFULL PERMISSIONS NONE
    ;

DEFINE FIELD OVERWRITE principal ON authentication_challenge TYPE record<stocksense_user>
    ASSERT record::exists($value) REFERENCE ON DELETE CASCADE;

DEFINE FIELD OVERWRITE target ON authentication_challenge TYPE record<authentication_email | authentication_phone>
    ASSERT record::exists($value) REFERENCE ON DELETE CASCADE;

DEFINE FIELD OVERWRITE principal_revision ON authentication_challenge TYPE int ASSERT $value >= 1;

DEFINE FIELD OVERWRITE target_revision ON authentication_challenge TYPE int ASSERT $value >= 1;

DEFINE FIELD OVERWRITE code_hash ON authentication_challenge TYPE string
    PERMISSIONS NONE ;

DEFINE FIELD OVERWRITE attempts ON authentication_challenge TYPE int DEFAULT 0 ASSERT $value >= 0 AND $value <= 5
    PERMISSIONS NONE;

DEFINE FIELD OVERWRITE expires_at ON authentication_challenge TYPE datetime PERMISSIONS NONE;

DEFINE FIELD OVERWRITE consumed_at ON authentication_challenge TYPE option<datetime> DEFAULT NONE PERMISSIONS NONE;

DEFINE FIELD OVERWRITE delivery_nonce ON authentication_challenge TYPE uuid PERMISSIONS NONE;

DEFINE FIELD OVERWRITE created_at ON authentication_challenge TYPE datetime VALUE $before OR time::now() READONLY
    PERMISSIONS NONE;

DEFINE INDEX OVERWRITE idx_authentication_challenge_target ON authentication_challenge COLUMNS target UNIQUE;

DEFINE INDEX OVERWRITE idx_authentication_challenge_principal ON authentication_challenge COLUMNS principal;

-- The challenge and this delivery request are committed together. The
-- ciphertext contains the one-time code and message content; it is opened
-- only by the static runtime handler using the separate payload-encryption key.
DEFINE TABLE OVERWRITE authentication_delivery_task SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE configuration ON authentication_delivery_task
    TYPE record<stocksense_email_delivery_config | stocksense_sms_delivery_config> READONLY
    REFERENCE ON DELETE REJECT;

DEFINE FIELD OVERWRITE principal ON authentication_delivery_task TYPE record<stocksense_user> READONLY
    REFERENCE ON DELETE CASCADE;

DEFINE FIELD OVERWRITE target ON authentication_delivery_task
    TYPE record<authentication_email | authentication_phone> READONLY
    REFERENCE ON DELETE CASCADE;

DEFINE FIELD OVERWRITE challenge ON authentication_delivery_task TYPE record<authentication_challenge> READONLY
    REFERENCE ON DELETE CASCADE;

DEFINE FIELD OVERWRITE channel ON authentication_delivery_task TYPE string READONLY
    ASSERT $value IN ['email', 'phone'];

DEFINE FIELD OVERWRITE principal_revision ON authentication_delivery_task TYPE int READONLY
    ASSERT $value >= 1;

DEFINE FIELD OVERWRITE target_revision ON authentication_delivery_task TYPE int READONLY
    ASSERT $value >= 1;

DEFINE FIELD OVERWRITE delivery_nonce ON authentication_delivery_task TYPE uuid READONLY;

DEFINE FIELD OVERWRITE payload_ciphertext ON authentication_delivery_task TYPE string READONLY
    PERMISSIONS NONE;

DEFINE FIELD OVERWRITE provider_reference ON authentication_delivery_task TYPE option<string> DEFAULT NONE
    PERMISSIONS NONE;

-- Private durable scan position shared by runtime instances in this database.
DEFINE TABLE OVERWRITE stocksense_reconciliation_cursor SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE cursors ON stocksense_reconciliation_cursor TYPE object FLEXIBLE DEFAULT {};

DEFINE FIELD OVERWRITE high_water ON stocksense_reconciliation_cursor TYPE object FLEXIBLE DEFAULT {};

DEFINE FIELD OVERWRITE retention_cursors ON stocksense_reconciliation_cursor TYPE object FLEXIBLE DEFAULT {};

DEFINE FIELD OVERWRITE retention_high_water ON stocksense_reconciliation_cursor TYPE object FLEXIBLE DEFAULT {};

DEFINE FIELD OVERWRITE table_offset ON stocksense_reconciliation_cursor TYPE int DEFAULT 0 ASSERT $value >= 0;

DEFINE FIELD OVERWRITE version ON stocksense_reconciliation_cursor TYPE int DEFAULT 0 ASSERT $value >= 0;

DEFINE FIELD OVERWRITE updated_at ON stocksense_reconciliation_cursor TYPE datetime DEFAULT time::now();

DEFINE TABLE OVERWRITE stocksense_webhook_receipt SCHEMAFULL PERMISSIONS NONE;

DEFINE FIELD OVERWRITE provider_account_id ON stocksense_webhook_receipt TYPE string ASSERT $value.len() > 0 READONLY;

DEFINE FIELD OVERWRITE event_id ON stocksense_webhook_receipt TYPE string ASSERT $value.len() > 0 AND $value.len() <= 256 READONLY;

DEFINE FIELD OVERWRITE provider ON stocksense_webhook_receipt TYPE string ASSERT $value.len() > 0 READONLY;

DEFINE FIELD OVERWRITE event ON stocksense_webhook_receipt TYPE string ASSERT $value.len() > 0 READONLY;

DEFINE FIELD OVERWRITE config_id ON stocksense_webhook_receipt TYPE string ASSERT $value.len() > 0 READONLY;

DEFINE FIELD OVERWRITE target_id ON stocksense_webhook_receipt TYPE string ASSERT $value.len() > 0 READONLY;

DEFINE FIELD OVERWRITE payload_hash ON stocksense_webhook_receipt TYPE string ASSERT $value.len() = 64 READONLY;

DEFINE FIELD OVERWRITE normalized_payload ON stocksense_webhook_receipt TYPE object FLEXIBLE READONLY;

DEFINE FIELD OVERWRITE received_at ON stocksense_webhook_receipt TYPE datetime DEFAULT time::now() READONLY;

DEFINE FIELD OVERWRITE applied_at ON stocksense_webhook_receipt TYPE option<datetime> DEFAULT NONE
    PERMISSIONS FOR select WHERE true FOR create, update NONE;

DEFINE INDEX OVERWRITE idx_stocksense_webhook_receipt_account_event
    ON TABLE stocksense_webhook_receipt FIELDS provider_account_id, event_id UNIQUE;

-- Authorization/reader maintenance is not a principal profile edit.
DEFINE EVENT OVERWRITE principal_touch ON stocksense_user WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND (
    $before.name != $after.name OR $before.username != $after.username OR $before.parents != $after.parents
    OR $before.login_access != $after.login_access OR $before.password != $after.password
)) THEN { UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE; };

DEFINE EVENT OVERWRITE principal_touch ON stocksense_group WHEN $event = 'CREATE' OR ($event = 'UPDATE' AND (
    $before.name != $after.name OR $before.role != $after.role OR $before.parents != $after.parents
)) THEN { UPDATE $after.id SET updated_at = time::now(), updated_by = $auth RETURN NONE; };

-- Cycle detection for the authorization graph.
DEFINE EVENT OVERWRITE prevent_cycle ON TABLE stocksense_user WHEN $event IN ["CREATE", "UPDATE"] AND $before.parents != $after.parents THEN {
    IF $after.id IN ($after.parents ?? []) OR ($after.parents ?? []) CONTAINSANY ($before.dominates ?? []) {
        THROW "ERR_CYCLE";
    };
};

DEFINE EVENT OVERWRITE prevent_cycle ON TABLE stocksense_group WHEN $event IN ["CREATE", "UPDATE"] AND $before.parents != $after.parents THEN {
    IF $after.id IN ($after.parents ?? []) OR ($after.parents ?? []) CONTAINSANY ($before.dominates ?? []) {
        THROW "ERR_CYCLE";
    };
};

-- Privilege escalation prevention.
DEFINE EVENT OVERWRITE prevent_role_escalation ON TABLE stocksense_group WHEN $event IN ["CREATE", "UPDATE"] AND $before.role != $after.role THEN {
    LET $unauthorized = array::complement($after.role ?? [], $auth.permissions ?? []);
    IF $unauthorized AND $auth { THROW "ERR_PRIVILEGE_ESCALATION"; };
};

-- Permission propagation remains independent from authentication state.
DEFINE EVENT OVERWRITE cascade_permissions_downward ON TABLE stocksense_group WHEN $event = "UPDATE" AND $before.role != $after.role THEN {
    LET $children_users = $after.id<~(stocksense_user FIELD parents);
    IF $children_users { UPDATE $children_users; };
};

DEFINE EVENT OVERWRITE upward_propagation_trigger ON TABLE stocksense_user WHEN $event THEN {
    IF $before.parents != $after.parents {
        LET $parents_to_ping = array::union($before.parents ?? [], $after.parents ?? []);
        IF $parents_to_ping { UPDATE $parents_to_ping; };
    };
    IF $before.dominates != $after.dominates {
        IF $after.parents { UPDATE $after.parents; };
    };
};

DEFINE EVENT OVERWRITE upward_propagation_trigger ON TABLE stocksense_group WHEN $event THEN {
    IF $before.parents != $after.parents {
        LET $parents_to_ping = array::union($before.parents ?? [], $after.parents ?? []);
        IF $parents_to_ping { UPDATE $parents_to_ping; };
    };
    IF $before.dominates != $after.dominates {
        IF $after.parents { UPDATE $after.parents; };
    };
};

-- These are state-invalidation triggers, not identity-presence guards. They
-- never block identity CRUD; they only fence stale verification/challenges.
-- The account revision is a fencing value, not an authentication boolean.
DEFINE EVENT OVERWRITE authentication_email_state ON TABLE authentication_email
WHEN $event IN ['CREATE', 'UPDATE', 'DELETE'] THEN {
    LET $identity = IF $event = 'DELETE' THEN $before ELSE $after END;
    LET $principal = $identity.principal;
    IF $event = 'CREATE' {
        UPDATE $identity.id SET verified_revision = NONE, verified_at = NONE;
        UPDATE $principal SET authentication_revision = authentication_revision + 1;
    } ELSE IF $event = 'DELETE' {
        DELETE authentication_challenge WHERE target = $identity.id;
        UPDATE $principal SET authentication_revision = authentication_revision + 1;
    } ELSE IF $before.address != $after.address {
        UPDATE $identity.id SET
            revision = $before.revision + 1,
            verified_revision = NONE,
            verified_at = NONE;
        DELETE authentication_challenge WHERE target = $identity.id;
        UPDATE $principal SET authentication_revision = authentication_revision + 1;
    };
};

DEFINE EVENT OVERWRITE authentication_phone_state ON TABLE authentication_phone
WHEN $event IN ['CREATE', 'UPDATE', 'DELETE'] THEN {
    LET $identity = IF $event = 'DELETE' THEN $before ELSE $after END;
    LET $principal = $identity.principal;
    IF $event = 'CREATE' {
        UPDATE $identity.id SET verified_revision = NONE, verified_at = NONE;
        UPDATE $principal SET authentication_revision = authentication_revision + 1;
    } ELSE IF $event = 'DELETE' {
        DELETE authentication_challenge WHERE target = $identity.id;
        UPDATE $principal SET authentication_revision = authentication_revision + 1;
    } ELSE IF $before.number != $after.number {
        UPDATE $identity.id SET
            revision = $before.revision + 1,
            verified_revision = NONE,
            verified_at = NONE;
        DELETE authentication_challenge WHERE target = $identity.id;
        UPDATE $principal SET authentication_revision = authentication_revision + 1;
    };
};

DEFINE EVENT OVERWRITE authentication_password_state ON TABLE stocksense_user
WHEN $event = 'UPDATE' AND $before.password != $after.password THEN {
    UPDATE $after.id SET authentication_revision = $before.authentication_revision + 1;
    DELETE authentication_challenge WHERE principal = $after.id;
};

