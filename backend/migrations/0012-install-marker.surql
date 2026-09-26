-- Marks a complete installation of this migration set.
DEFINE TABLE OVERWRITE stocksense_schema_version SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD OVERWRITE version ON stocksense_schema_version TYPE string;
DEFINE FIELD OVERWRITE installed_at ON stocksense_schema_version TYPE datetime;
UPSERT stocksense_schema_version:current SET version = '1.0.0', installed_at = time::now();
