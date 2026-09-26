--------------------------------------------------------------------
-- StockSense Migration 000001
-- Lookup/reference tables
--------------------------------------------------------------------

DEFINE TABLE role SCHEMAFULL;
DEFINE FIELD code ON TABLE role TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE role TYPE string ASSERT $value != "";
DEFINE INDEX role_code_unique ON TABLE role FIELDS code UNIQUE;

DEFINE TABLE document_status SCHEMAFULL;
DEFINE FIELD code ON TABLE document_status TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE document_status TYPE string ASSERT $value != "";
DEFINE INDEX document_status_code_unique ON TABLE document_status FIELDS code UNIQUE;

DEFINE TABLE move_type SCHEMAFULL;
DEFINE FIELD code ON TABLE move_type TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE move_type TYPE string ASSERT $value != "";
DEFINE INDEX move_type_code_unique ON TABLE move_type FIELDS code UNIQUE;

DEFINE TABLE reference_type SCHEMAFULL;
DEFINE FIELD code ON TABLE reference_type TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE reference_type TYPE string ASSERT $value != "";
DEFINE INDEX reference_type_code_unique ON TABLE reference_type FIELDS code UNIQUE;

DEFINE TABLE location_type SCHEMAFULL;
DEFINE FIELD code ON TABLE location_type TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE location_type TYPE string ASSERT $value != "";
DEFINE INDEX location_type_code_unique ON TABLE location_type FIELDS code UNIQUE;

DEFINE TABLE unit_of_measure SCHEMAFULL;
DEFINE FIELD code ON TABLE unit_of_measure TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE unit_of_measure TYPE string ASSERT $value != "";
DEFINE INDEX unit_of_measure_code_unique ON TABLE unit_of_measure FIELDS code UNIQUE;

DEFINE TABLE otp_purpose SCHEMAFULL;
DEFINE FIELD code ON TABLE otp_purpose TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE otp_purpose TYPE string ASSERT $value != "";
DEFINE INDEX otp_purpose_code_unique ON TABLE otp_purpose FIELDS code UNIQUE;

DEFINE TABLE alert_type SCHEMAFULL;
DEFINE FIELD code ON TABLE alert_type TYPE string ASSERT $value != "";
DEFINE FIELD name ON TABLE alert_type TYPE string ASSERT $value != "";
DEFINE INDEX alert_type_code_unique ON TABLE alert_type FIELDS code UNIQUE;