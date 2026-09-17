INSERT dbo.Employees (EmployeeId, EmployeeName, ModifiedDate, ModifiedBy)
SELECT source.EmployeeId, source.EmployeeName, SYSUTCDATETIME(), N'seed'
FROM
(
    VALUES
        (1001, N'Avery Morgan'),
        (1002, N'Jordan Lee'),
        (1003, N'Riley Patel')
) AS source (EmployeeId, EmployeeName)
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Employees AS target
    WHERE target.EmployeeId = source.EmployeeId
);
GO