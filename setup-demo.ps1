# Fabric Writeback Demo - Automated Setup Script
# This script automates the SQL table creation in Fabric SQL Database

param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "Fabric Writeback Demo",
    
    [Parameter(Mandatory=$false)]
    [string]$SQLDatabaseName = "HRData",
    
    [Parameter(Mandatory=$false)]
    [string]$OnPremServer = "",
    
    [Parameter(Mandatory=$false)]
    [string]$OnPremDatabase = "HRSystem",
    
    [Parameter(Mandatory=$false)]
    [string]$OnPremUsername = "",
    
    [Parameter(Mandatory=$false)]
    [SecureString]$OnPremPassword
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fabric Writeback Demo - Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check if SqlServer module is installed
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Host "❌ SqlServer PowerShell module not found" -ForegroundColor Red
        Write-Host "   Install with: Install-Module -Name SqlServer -Scope CurrentUser" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✅ SqlServer module found" -ForegroundColor Green
    return $true
}

# Function to create table in Fabric SQL Database
function New-FabricSQLTable {
    param(
        [string]$ConnectionString
    )
    
    Write-Host ""
    Write-Host "Creating table in Fabric SQL Database..." -ForegroundColor Yellow
    
    $sql = @"
-- Create Employees table
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL
    DROP TABLE dbo.Employees;

CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(255) NOT NULL,
    LastModifiedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedBy NVARCHAR(100) DEFAULT SYSTEM_USER
);

-- Create index
CREATE INDEX IX_Employees_LastModifiedDate ON dbo.Employees(LastModifiedDate);

-- Create stored procedure for writeback
CREATE OR ALTER PROCEDURE dbo.usp_UpdateEmployee
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE dbo.Employees
    SET 
        EmployeeName = @EmployeeName,
        LastModifiedDate = GETDATE(),
        ModifiedBy = @ModifiedBy
    WHERE EmployeeID = @EmployeeID;
    
    SELECT * FROM dbo.Employees WHERE EmployeeID = @EmployeeID;
END;
"@
    
    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $sql -ErrorAction Stop
        Write-Host "✅ Table and stored procedure created successfully in Fabric SQL Database" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error creating table in Fabric SQL Database: $_" -ForegroundColor Red
        return $false
    }
}

# Function to create table in On-Prem SQL Server
function New-OnPremSQLTable {
    param(
        [string]$Server,
        [string]$Database,
        [string]$Username,
        [SecureString]$Password
    )
    
    Write-Host ""
    Write-Host "Creating table in On-Prem SQL Server..." -ForegroundColor Yellow
    
    $sql = @"
-- Create database if needed
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$Database')
BEGIN
    CREATE DATABASE [$Database];
END

USE [$Database];

-- Create Employees table
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL
    DROP TABLE dbo.Employees;

CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(255) NOT NULL,
    LastModifiedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedBy NVARCHAR(100) DEFAULT SYSTEM_USER
);

-- Create index
CREATE INDEX IX_Employees_LastModifiedDate ON dbo.Employees(LastModifiedDate);

-- Insert sample data
INSERT INTO dbo.Employees (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
VALUES 
    (1, 'Yusra', GETDATE(), 'System'),
    (2, 'Mohammed', GETDATE(), 'System'),
    (3, 'Sarah Johnson', GETDATE(), 'System'),
    (4, 'Michael Chen', GETDATE(), 'System'),
    (5, 'Emily Davis', GETDATE(), 'System');

-- Create merge stored procedure
CREATE OR ALTER PROCEDURE dbo.usp_MergeEmployees
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE INTO dbo.Employees AS Target
    USING (
        SELECT 
            @EmployeeID AS EmployeeID,
            @EmployeeName AS EmployeeName,
            @ModifiedBy AS ModifiedBy
    ) AS Source
    ON Target.EmployeeID = Source.EmployeeID
    WHEN MATCHED THEN
        UPDATE SET 
            EmployeeName = Source.EmployeeName,
            LastModifiedDate = GETDATE(),
            ModifiedBy = Source.ModifiedBy
    WHEN NOT MATCHED THEN
        INSERT (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
        VALUES (Source.EmployeeID, Source.EmployeeName, GETDATE(), Source.ModifiedBy);
END;
"@
    
    try {
        if ($Password) {
            $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
            Invoke-Sqlcmd -ServerInstance $Server -Username $Username -Password $credential.GetNetworkCredential().Password -Query $sql -ErrorAction Stop
        }
        else {
            # Use Windows Authentication
            Invoke-Sqlcmd -ServerInstance $Server -Query $sql -ErrorAction Stop
        }
        
        Write-Host "✅ Table, sample data, and stored procedure created successfully in On-Prem SQL Server" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error creating table in On-Prem SQL Server: $_" -ForegroundColor Red
        return $false
    }
}

# Function to validate setup
function Test-Setup {
    param(
        [string]$OnPremServer,
        [string]$OnPremDatabase
    )
    
    Write-Host ""
    Write-Host "Validating setup..." -ForegroundColor Yellow
    
    try {
        $query = "SELECT COUNT(*) as RecordCount FROM dbo.Employees"
        $result = Invoke-Sqlcmd -ServerInstance $OnPremServer -Database $OnPremDatabase -Query $query
        
        if ($result.RecordCount -eq 5) {
            Write-Host "✅ On-Prem: Found 5 employee records" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️ On-Prem: Expected 5 records, found $($result.RecordCount)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Error validating setup: $_" -ForegroundColor Red
    }
}

# Main execution
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Workspace: $WorkspaceName" -ForegroundColor White
Write-Host "  SQL Database: $SQLDatabaseName" -ForegroundColor White
Write-Host ""

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Host ""
    Write-Host "Please install required modules and try again." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Manual Steps Required" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script can automate SQL table creation, but some steps require manual intervention:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣ Fabric SQL Database Table Creation:" -ForegroundColor Cyan
Write-Host "   - Go to Fabric portal: https://app.fabric.microsoft.com" -ForegroundColor White
Write-Host "   - Navigate to workspace: '$WorkspaceName'" -ForegroundColor White
Write-Host "   - Open SQL Database: '$SQLDatabaseName'" -ForegroundColor White
Write-Host "   - Click 'New Query' and run the SQL from: 01-table-creation.sql (Part B)" -ForegroundColor White
Write-Host ""
Write-Host "2️⃣ On-Prem SQL Server Setup:" -ForegroundColor Cyan
if ($OnPremServer -and $OnPremDatabase) {
    Write-Host "   Creating table in On-Prem SQL Server..." -ForegroundColor White
    $success = New-OnPremSQLTable -Server $OnPremServer -Database $OnPremDatabase -Username $OnPremUsername -Password $OnPremPassword
    
    if ($success) {
        Test-Setup -OnPremServer $OnPremServer -OnPremDatabase $OnPremDatabase
    }
}
else {
    Write-Host "   ⚠️ On-Prem server details not provided" -ForegroundColor Yellow
    Write-Host "   Run with parameters: -OnPremServer 'server' -OnPremDatabase 'HRSystem'" -ForegroundColor White
}

Write-Host ""
Write-Host "3️⃣ Create Fabric Connections:" -ForegroundColor Cyan
Write-Host "   - In Fabric portal, go to Settings → Manage connections and gateways" -ForegroundColor White
Write-Host "   - Create connection to On-Prem SQL Server" -ForegroundColor White
Write-Host "   - Create connection to Fabric SQL Database" -ForegroundColor White
Write-Host ""
Write-Host "4️⃣ Create Data Pipelines:" -ForegroundColor Cyan
Write-Host "   - Follow guide in: 02-pipeline-ingest-config.md" -ForegroundColor White
Write-Host "   - Follow guide in: 04-pipeline-syncback-config.md" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📖 Open: AUTOMATED_DEMO_SETUP.md for complete step-by-step instructions" -ForegroundColor Green
Write-Host ""
Write-Host "For questions or issues, refer to the documentation in:" -ForegroundColor White
Write-Host "  - README.md" -ForegroundColor Gray
Write-Host "  - QUICK_START.md" -ForegroundColor Gray
Write-Host "  - OPDG_MIGRATION_GUIDE.md" -ForegroundColor Gray
Write-Host ""

# Example usage instructions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Example Usage" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To create on-prem SQL tables with this script:" -ForegroundColor Yellow
Write-Host ""
Write-Host '.\setup-demo.ps1 -OnPremServer "localhost" -OnPremDatabase "HRSystem"' -ForegroundColor White
Write-Host ""
Write-Host "Or with SQL Authentication:" -ForegroundColor Yellow
Write-Host ""
Write-Host '$password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force' -ForegroundColor White
Write-Host '.\setup-demo.ps1 -OnPremServer "localhost" -OnPremDatabase "HRSystem" -OnPremUsername "sa" -OnPremPassword $password' -ForegroundColor White
Write-Host ""
