BEGIN TRANSACTION;

EXEC dbo.usp_UpdateEmployee
    @EmployeeId = 1001,
    @EmployeeName = N'Avery Morgan - Test',
    @ModifiedBy = N'local-validation';

SELECT EmployeeId, EmployeeName, ModifiedDate, ModifiedBy
FROM dbo.Employees
WHERE EmployeeId = 1001;

SELECT TOP (1)
    EmployeeId,
    PreviousName,
    NewName,
    ModifiedDate,
    ModifiedBy
FROM dbo.EmployeeWritebackAudit
WHERE EmployeeId = 1001
ORDER BY AuditId DESC;

ROLLBACK TRANSACTION;
GO