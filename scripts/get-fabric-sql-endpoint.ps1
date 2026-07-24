# Get Fabric SQL Database Connection String
# This retrieves the SQL endpoint for your Fabric SQL Database

# Configuration
$WorkspaceName = "Fabric Writeback Demo"
$SQLDatabaseName = "HRData"

Write-Host "Retrieving Fabric SQL Database connection details..." -ForegroundColor Cyan
Write-Host ""

# Login to Azure (if not already logged in)
$context = Get-AzContext
if (-not $context) {
    Write-Host "Logging in to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Get Fabric workspace (using Power BI cmdlets)
try {
    Write-Host "Looking for workspace: $WorkspaceName" -ForegroundColor Yellow
    
    # Note: You may need to install the Fabric PowerShell module
    # Install-Module -Name Microsoft.PowerBI.Commands -Force -Scope CurrentUser
    
    # Alternative: Get from Fabric REST API
    $token = (Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api").Token
    $headers = @{
        'Authorization' = "Bearer $token"
        'Content-Type' = 'application/json'
    }
    
    # Get workspaces
    $workspacesUrl = "https://api.fabric.microsoft.com/v1/workspaces"
    $workspaces = Invoke-RestMethod -Uri $workspacesUrl -Headers $headers -Method Get
    
    $workspace = $workspaces.value | Where-Object { $_.displayName -eq $WorkspaceName }
    
    if ($workspace) {
        Write-Host "✓ Found workspace: $($workspace.displayName)" -ForegroundColor Green
        Write-Host "  Workspace ID: $($workspace.id)" -ForegroundColor Gray
        
        # Get SQL Database items in workspace
        $itemsUrl = "https://api.fabric.microsoft.com/v1/workspaces/$($workspace.id)/items?type=SQLDatabase"
        $items = Invoke-RestMethod -Uri $itemsUrl -Headers $headers -Method Get
        
        $sqlDb = $items.value | Where-Object { $_.displayName -eq $SQLDatabaseName }
        
        if ($sqlDb) {
            Write-Host "✓ Found SQL Database: $($sqlDb.displayName)" -ForegroundColor Green
            Write-Host "  Database ID: $($sqlDb.id)" -ForegroundColor Gray
            Write-Host ""
            
            # Get connection strings (this requires additional API call)
            Write-Host "🔗 Connection Information:" -ForegroundColor Cyan
            Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray
            
            # Fabric SQL endpoint format
            $capacityRegion = "your-region" # This varies by capacity location
            $sqlEndpoint = "$($workspace.id)-$($sqlDb.id).datawarehouse.fabric.microsoft.com"
            
            Write-Host "Server Name (for Power Automate):" -ForegroundColor Yellow
            Write-Host "  $sqlEndpoint" -ForegroundColor White
            Write-Host ""
            Write-Host "Database Name:" -ForegroundColor Yellow
            Write-Host "  $SQLDatabaseName" -ForegroundColor White
            Write-Host ""
            Write-Host "Authentication:" -ForegroundColor Yellow
            Write-Host "  Microsoft Entra ID Integrated" -ForegroundColor White
            Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray
            
        } else {
            Write-Host "✗ SQL Database '$SQLDatabaseName' not found in workspace" -ForegroundColor Red
            Write-Host "Available items:" -ForegroundColor Yellow
            $items.value | ForEach-Object { Write-Host "  - $($_.displayName) ($($_.type))" }
        }
        
    } else {
        Write-Host "✗ Workspace '$WorkspaceName' not found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error retrieving information: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual Alternative:" -ForegroundColor Yellow
    Write-Host "1. Go to app.fabric.microsoft.com" -ForegroundColor White
    Write-Host "2. Navigate to workspace: $WorkspaceName" -ForegroundColor White
    Write-Host "3. Click on SQL Database: $SQLDatabaseName" -ForegroundColor White
    Write-Host "4. Look for 'Connection strings' or 'Settings'" -ForegroundColor White
    Write-Host "5. Copy the SQL endpoint address" -ForegroundColor White
}

Write-Host ""
Write-Host "📋 For Power Automate, you need:" -ForegroundColor Cyan
Write-Host "  • Server name: [endpoint from above].datawarehouse.fabric.microsoft.com" -ForegroundColor White
Write-Host "  • Database name: HRData" -ForegroundColor White
Write-Host "  • Authentication: Microsoft Entra ID Integrated" -ForegroundColor White
