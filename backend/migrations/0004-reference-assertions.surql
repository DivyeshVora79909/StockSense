-- STOCKSENSE: record reference assertions
ALTER FIELD warehouse ON TABLE stock_location ASSERT record::exists($value);
ALTER FIELD parent ON TABLE stock_location ASSERT $value = NONE OR record::exists($value);
ALTER FIELD category ON TABLE product ASSERT $value = NONE OR record::exists($value);
ALTER FIELD unit ON TABLE product ASSERT record::exists($value);
ALTER FIELD product ON TABLE stock_position ASSERT record::exists($value);
ALTER FIELD location ON TABLE stock_position ASSERT record::exists($value);
ALTER FIELD location ON TABLE stock_operation ASSERT $value = NONE OR record::exists($value);
ALTER FIELD from_location ON TABLE stock_operation ASSERT $value = NONE OR record::exists($value);
ALTER FIELD to_location ON TABLE stock_operation ASSERT $value = NONE OR record::exists($value);
ALTER FIELD operation ON TABLE stock_ledger ASSERT record::exists($value);
ALTER FIELD product ON TABLE stock_ledger ASSERT record::exists($value);
ALTER FIELD location ON TABLE stock_ledger ASSERT record::exists($value);
ALTER FIELD position ON TABLE stock_ledger ASSERT record::exists($value);


