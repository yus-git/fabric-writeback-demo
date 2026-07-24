# =============================================
# Get Fabric Workspace and Pipeline IDs
# =============================================
# This script helps you find the IDs needed for the stored procedure
# =============================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fabric Workspace & Pipeline ID Finder" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if Azure CLI is installed
try {
    $azVersion = az version --query '\"azure-cli\"' -o tsv 2>$null
    if ($azVersion) {
        Write-Host "✅ Azure CLI detected (version: $azVersion)" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Azure CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Login to Azure
Write-Host "`n📝 Checking Azure login status..." -ForegroundColor Yellow
$loginStatus = az account show 2>$null

if (-not $loginStatus) {
    Write-Host "🔑 Please login to Azure..." -ForegroundColor Yellow
    az login
} else {
    Write-Host "✅ Already logged in" -ForegroundColor Green
}

# List all workspaces
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📁 Your Fabric Workspaces" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$workspacesJson = az rest --method GET --url "https://api.fabric.microsoft.com/v1/workspaces" 2>$null

if ($workspacesJson) {
    $workspaces = $workspacesJson | ConvertFrom-Json
    
    if ($workspaces.value.Count -eq 0) {
        Write-Host "No workspaces found." -ForegroundColor Yellow
    } else {
        $workspaceList = @()
        foreach ($ws in $workspaces.value) {
            $workspaceList += [PSCustomObject]@{
                Name = $ws.displayName
                ID = $ws.id
            }
        }
        $workspaceList | Format-Table -AutoSize
        
        # Prompt user to select a workspace
        Write-Host "`n📋 Copy the Workspace ID from above, or enter the workspace name:" -ForegroundColor Yellow
        $workspaceInput = Read-Host "Enter workspace name or ID"
        
        # Find the workspace
        $selectedWorkspace = $workspaces.value | Where-Object { 
            $_.displayName -eq $workspaceInput -or $_.id -eq $workspaceInput 
        } | Select-Object -First 1
        
        if ($selectedWorkspace) {
            $workspaceId = $selectedWorkspace.id
            $workspaceName = $selectedWorkspace.displayName
            
            Write-Host "`n✅ Selected Workspace:" -ForegroundColor Green
            Write-Host "   Name: $workspaceName" -ForegroundColor White
            Write-Host "   ID: $workspaceId" -ForegroundColor Yellow
            
            # Get pipelines in the selected workspace
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "🔄 Pipelines in '$workspaceName'" -ForegroundColor Cyan
            Write-Host "========================================`n" -ForegroundColor Cyan
            
            $pipelinesJson = az rest --method GET --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items?type=DataPipeline" 2>$null
            
            if ($pipelinesJson) {
                $pipelines = $pipelinesJson | ConvertFrom-Json
                
                if ($pipelines.value.Count -eq 0) {
                    Write-Host "No pipelines found in this workspace." -ForegroundColor Yellow
                } else {
                    $pipelineList = @()
                    foreach ($pipeline in $pipelines.value) {
                        $pipelineList += [PSCustomObject]@{
                            Name = $pipeline.displayName
                            ID = $pipeline.id
                            Type = $pipeline.type
                        }
                    }
                    $pipelineList | Format-Table -AutoSize
                    
                    # Prompt for pipeline
                    Write-Host "`n📋 Enter the name of your SYNC pipeline (the one that syncs to on-prem):" -ForegroundColor Yellow
                    $pipelineInput = Read-Host "Enter pipeline name or ID"
                    
                    $selectedPipeline = $pipelines.value | Where-Object { 
                        $_.displayName -eq $pipelineInput -or $_.id -eq $pipelineInput 
                    } | Select-Object -First 1
                    
                    if ($selectedPipeline) {
                        $pipelineId = $selectedPipeline.id
                        $pipelineName = $selectedPipeline.displayName
                        
                        Write-Host "`n✅ Selected Pipeline:" -ForegroundColor Green
                        Write-Host "   Name: $pipelineName" -ForegroundColor White
                        Write-Host "   ID: $pipelineId" -ForegroundColor Yellow
                        
                        # Generate the SQL code
                        Write-Host "`n========================================" -ForegroundColor Cyan
                        Write-Host "📝 Your SQL Configuration Code" -ForegroundColor Cyan
                        Write-Host "========================================`n" -ForegroundColor Cyan
                        
                        Write-Host "Copy and paste this into your stored procedure:`n" -ForegroundColor Green
                        
                        Write-Host "DECLARE @workspaceId NVARCHAR(100) = '$workspaceId';" -ForegroundColor Yellow
                        Write-Host "DECLARE @pipelineId NVARCHAR(100) = '$pipelineId';" -ForegroundColor Yellow
                        
                        Write-Host "`nOr use this direct URL:`n" -ForegroundColor Green
                        $apiUrl = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$pipelineId/jobs/instances?jobType=Pipeline"
                        Write-Host "DECLARE @url NVARCHAR(4000) = '$apiUrl';" -ForegroundColor Yellow
                        
                        # Save to file
                        $outputFile = "fabric-ids-config.txt"
                        @"
Fabric Configuration
====================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Workspace Name: $workspaceName
Workspace ID: $workspaceId

Pipeline Name: $pipelineName
Pipeline ID: $pipelineId

SQL Configuration:
------------------
DECLARE @workspaceId NVARCHAR(100) = '$workspaceId';
DECLARE @pipelineId NVARCHAR(100) = '$pipelineId';

Direct API URL:
---------------
DECLARE @url NVARCHAR(4000) = '$apiUrl';
"@ | Out-File -FilePath $outputFile -Encoding UTF8
                        
                        Write-Host "`n💾 Configuration saved to: $outputFile" -ForegroundColor Green
                        
                    } else {
                        Write-Host "❌ Pipeline not found. Please check the name/ID." -ForegroundColor Red
                    }
                }
            }
        } else {
            Write-Host "❌ Workspace not found. Please check the name/ID." -ForegroundColor Red
        }
    }
} else {
    Write-Host "❌ Failed to retrieve workspaces. Please check your permissions." -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ Script Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
