--------------------------------------------------------------------
-- StockSense Migration 000002
-- Authentication and user tables
--------------------------------------------------------------------

DEFINE TABLE user SCHEMAFULL;

DEFINE FIELD email ON TABLE user TYPE string VALUE string::lower($value) ASSERT $value != "";
DEFINE FIELD full_name ON TABLE user TYPE string ASSERT $value != "";
DEFINE FIELD password_hash ON TABLE user TYPE string ASSERT $value != "";
DEFINE FIELD role ON TABLE user TYPE record<role>;
DEFINE FIELD is_active ON TABLE user TYPE bool VALUE true;
DEFINE FIELD created_at ON TABLE user TYPE datetime VALUE time::now();

DEFINE INDEX user_email_unique ON TABLE user FIELDS email UNIQUE;
DEFINE INDEX user_role_idx ON TABLE user FIELDS role;

--------------------------------------------------------------------
-- OTP table for password reset / verification flows
--------------------------------------------------------------------

DEFINE TABLE auth_otp SCHEMAFULL;

DEFINE FIELD user ON TABLE auth_otp TYPE record<user>;
DEFINE FIELD purpose ON TABLE auth_otp TYPE record<otp_purpose>;
DEFINE FIELD code_hash ON TABLE auth_otp TYPE string ASSERT $value != "";
DEFINE FIELD expires_at ON TABLE auth_otp TYPE datetime;
DEFINE FIELD consumed_at ON TABLE auth_otp TYPE option<datetime>;
DEFINE FIELD created_at ON TABLE auth_otp TYPE datetime VALUE time::now();

DEFINE INDEX auth_otp_user_idx ON TABLE auth_otp FIELDS user;
DEFINE INDEX auth_otp_purpose_idx ON TABLE auth_otp FIELDS purpose;
DEFINE INDEX auth_otp_expires_at_idx ON TABLE auth_otp FIELDS expires_at;