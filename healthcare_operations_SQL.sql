USE healthcare_operations

-- Data summary: list every table and its columns, types, and max length
SELECT 
    t.name AS table_name,
    c.name AS column_name,
    t.name AS data_type,
    c.max_length
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
