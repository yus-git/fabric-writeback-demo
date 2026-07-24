-- =============================================
-- Enhanced UDF: Automatically Trigger Pipeline After Update
-- =============================================
-- Run this in FABRIC SQL DATABASE (HRData)
-- =============================================

-- Step 1: Create or update the stored procedure with pipeline trigger
CREATE OR ALTER PROCEDURE dbo.usp_UpdateEmployee
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Declare variables for pipeline trigger
    DECLARE @url NVARCHAR(4000);
    DECLARE @payload NVARCHAR(MAX);
    DECLARE @response NVARCHAR(MAX);
    DECLARE @workspaceId NVARCHAR(100) = '5720b110-927c-4145-a4a4-d214a30908f8'; -- Your workspace ID
    DECLARE @pipelineId NVARCHAR(100) = '1f32cf5a-09c5-4d57-8a13-6cb7780658aa';   -- Pipeline_Writeback_to_On-Prem
    
    -- Update the employee record
    UPDATE dbo.Employees
    SET 
        EmployeeName = @EmployeeName,
        LastModifiedDate = GETDATE(),
        ModifiedBy = @ModifiedBy
    WHERE EmployeeID = @EmployeeID;
    
    -- Check if update was successful
    IF @@ROWCOUNT > 0
    BEGIN
        -- Construct the Fabric Pipeline REST API URL
        SET @url = 'https://api.fabric.microsoft.com/v1/workspaces/' 
                   + @workspaceId 
                   + '/items/' 
                   + @pipelineId 
                   + '/jobs/instances?jobType=Pipeline';
        
        -- Optional: Create payload with parameters (if your pipeline accepts parameters)
        SET @payload = N'{
            "executionData": {
                "parameters": {
                    "EmployeeID": ' + CAST(@EmployeeID AS NVARCHAR(20)) + '
                }
            }
        }';
        
        -- Trigger the pipeline using REST API
        BEGIN TRY
            EXEC sp_invoke_external_rest_endpoint
                @url = @url,
                @method = 'POST',
                @payload = @payload,
                @response = @response OUTPUT;
            
            PRINT '✅ Pipeline triggered successfully for EmployeeID: ' + CAST(@EmployeeID AS NVARCHAR(20));
        END TRY
        BEGIN CATCH
            -- Log the error but don't fail the update
            PRINT '⚠️ Warning: Pipeline trigger failed, but update was successful';
            PRINT 'Error: ' + ERROR_MESSAGE();
        END CATCH
    END
    
    -- Return the updated record
    SELECT * FROM dbo.Employees WHERE EmployeeID = @EmployeeID;
END;
GO

-- =============================================
-- Alternative: Simpler Version with Immediate Trigger
-- =============================================

CREATE OR ALTER PROCEDURE dbo.usp_UpdateEmployeeWithSync
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update the employee record
    UPDATE dbo.Employees
    SET 
        EmployeeName = @EmployeeName,
        LastModifiedDate = GETDATE(),
        ModifiedBy = @ModifiedBy
    WHERE EmployeeID = @EmployeeID;
    
    -- Trigger pipeline (replace with your actual workspace and pipeline IDs)
    DECLARE @url NVARCHAR(4000) = 'https://api.fabric.microsoft.com/v1/workspaces/5720b110-927c-4145-a4a4-d214a30908f8/items/1f32cf5a-09c5-4d57-8a13-6cb7780658aa/jobs/instances?jobType=Pipeline';
    DECLARE @response NVARCHAR(MAX);
    
    BEGIN TRY
        EXEC sp_invoke_external_rest_endpoint
            @url = @url,
            @method = 'POST',
            @response = @response OUTPUT;
    END TRY
    BEGIN CATCH
        -- Swallow the error to not block the update
        PRINT 'Pipeline trigger failed: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Return the updated record
    SELECT * FROM dbo.Employees WHERE EmployeeID = @EmployeeID;
END;
GO

-- =============================================
-- How to Get Your Workspace and Pipeline IDs
-- =============================================

/*
METHOD 1: From Fabric Portal URL
1. Open your workspace in Fabric portal
2. The URL will look like: https://app.fabric.microsoft.com/groups/WORKSPACE_ID/...
3. Copy the WORKSPACE_ID from the URL

4. Open your pipeline
5. The URL will look like: .../datapipelines/PIPELINE_ID?...
6. Copy the PIPELINE_ID from the URL

METHOD 2: Using PowerShell
Run the script below to list your workspaces and pipelines:
*/

-- Save this as get-fabric-ids.ps1
/*
# Login to Azure (if not already logged in)
az login

# List all workspaces
Write-Host "=== Your Workspaces ===" -ForegroundColor Cyan
az rest --method GET --url "https://api.fabric.microsoft.com/v1/workspaces" --query "value[].{Name:displayName, ID:id}" -o table

# Get pipelines in a specific workspace (replace WORKSPACE_ID)
$workspaceId = "YOUR_WORKSPACE_ID"
Write-Host "`n=== Pipelines in Workspace ===" -ForegroundColor Cyan
az rest --method GET --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items?type=DataPipeline" --query "value[].{Name:displayName, ID:id}" -o table
*/

-- =============================================
-- Configuration Steps
-- =============================================

/*
STEP 1: Get your IDs using the PowerShell script above

STEP 2: Update the stored procedure
- Replace 'YOUR_WORKSPACE_ID' with your actual workspace ID
- Replace 'YOUR_PIPELINE_ID' with your sync pipeline ID

STEP 3: Test the procedure
EXEC dbo.usp_UpdateEmployee 
    @EmployeeID = 1, 
    @EmployeeName = 'Updated Name', 
    @ModifiedBy = 'test@example.com';

STEP 4: Update your Power Automate flow
- Change the stored procedure name from 'usp_UpdateEmployee' 
  to 'usp_UpdateEmployeeWithSync' (if using the alternative version)
- Or keep the same name if you updated the original procedure
*/

-- =============================================
-- Important Notes
-- =============================================

/*
✅ PROS:
- Automatic sync after every update
- No manual pipeline triggering needed
- Real-time data sync

⚠️ CONSIDERATIONS:
- Each update triggers a pipeline run (may increase costs)
- Pipeline runs are async - data won't sync immediately
- Consider rate limiting if many updates happen quickly

💡 ALTERNATIVE APPROACH:
If you have many updates, consider:
1. Keep the simple UPDATE procedure
2. Schedule your sync pipeline to run every X minutes/hours
3. This reduces pipeline runs and costs while still keeping data in sync
*/
