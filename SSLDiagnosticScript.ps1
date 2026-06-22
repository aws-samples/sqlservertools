<#
.SYNOPSIS
    Diagnoses SQL Server connection issues related to SSL certificates and PowerShell modules.
.DESCRIPTION
    This script helps identify if connection issues are caused by SQLPS being the default module
    instead of the newer SqlServer module, and provides guidance on how to resolve
    TrustServerCertificate parameter errors.
.NOTES
    Run this script with administrator privileges for best results.
#>

# Clear screen for better readability
Clear-Host
Write-Host "SQL Server Connection Diagnostic Tool" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host

# Step 1: Check which SQL modules are installed
Write-Host "Step 1: Checking installed SQL PowerShell modules..." -ForegroundColor Green
$sqlModules = Get-Module -ListAvailable | Where-Object {$_.Name -like "*SQL*"} | 
    Select-Object Name, Version, Path

Write-Host "  Found the following SQL-related modules:" -ForegroundColor Yellow
foreach ($module in $sqlModules) {
    Write-Host "  - $($module.Name) (Version: $($module.Version))" -ForegroundColor Gray
}
Write-Host

# Step 2: Check which module provides Invoke-Sqlcmd
Write-Host "Step 2: Checking which module provides Invoke-Sqlcmd..." -ForegroundColor Green
$sqlCmd = Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue
if ($sqlCmd) {
    $sourceModule = $sqlCmd.Source
    Write-Host "  Invoke-Sqlcmd is provided by: $sourceModule" -ForegroundColor Yellow
    
    if ($sourceModule -eq "SQLPS") {
        $hasSQLPSIssue = $true
        Write-Host "  DETECTED ISSUE: You are using the older SQLPS module which doesn't support the TrustServerCertificate parameter" -ForegroundColor Red
    }
    else {
        $hasSQLPSIssue = $false
        Write-Host "  You are using the newer SqlServer module which supports the TrustServerCertificate parameter" -ForegroundColor Green
    }
}
else {
    Write-Host "  Invoke-Sqlcmd command not found. No SQL Server PowerShell modules may be loaded." -ForegroundColor Red
    $hasSQLPSIssue = $false
}
Write-Host

# Step 3: Try to detect SQL provider drive (SQLPS specific)
Write-Host "Step 3: Checking if SQLPS provider is active..." -ForegroundColor Green
try {
    Get-ChildItem SQLSERVER:\SQL -ErrorAction Stop | Out-Null
    Write-Host "  SQLPS provider is active - this can indicate SQLPS is loaded" -ForegroundColor Yellow
    # Only set the flag if Invoke-Sqlcmd wasn't already confirmed from SqlServer module
    if ($sourceModule -eq "SQLPS" -or -not $sqlCmd) {
        $hasSQLPSIssue = $true
    } else {
        Write-Host "  NOTE: Even though the SQLPS provider is active, Invoke-Sqlcmd is coming from SqlServer module" -ForegroundColor Cyan
    }
} 
catch {
    Write-Host "  SQLPS provider is not active" -ForegroundColor Gray
}
Write-Host

# Step 4: Test importing SqlServer module
Write-Host "Step 4: Testing if we can import the SqlServer module..." -ForegroundColor Green
$hasSqlServerModule = $false
try {
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Host "  SqlServer module is not installed on this system" -ForegroundColor Red
    }
    else {
        # Try to import the module
        Import-Module SqlServer -Force -ErrorAction Stop
        Write-Host "  Successfully imported SqlServer module" -ForegroundColor Green
        $hasSqlServerModule = $true
    }
}
catch {
    Write-Host "  Failed to import SqlServer module: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host

# Step 5: Provide diagnosis and recommendations
Write-Host "Diagnosis Results" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan

Write-Host "NOTE: The RDSTools suite requires the SqlServer module to handle secure connections properly." -ForegroundColor Cyan
Write-Host

# Check if both modules are present
$hasBothModules = $sqlModules | Where-Object {$_.Name -eq "SQLPS"} | Select-Object -First 1
$hasSQLPSDetected = $hasBothModules -ne $null

if ($hasSQLPSDetected) {
    Write-Host "ISSUE DETECTED: Your system is using the older SQLPS module as default." -ForegroundColor Red
    Write-Host "This likely explains the TrustServerCertificate parameter errors." -ForegroundColor Red
    Write-Host
    
    Write-Host "Recommended Solutions:" -ForegroundColor Green
    
    if ($hasSqlServerModule) {
        Write-Host "1. SQLSERVER Module has to be imported first. Please use our RunMeFirst GUI which will automatically import the correct module." -ForegroundColor Yellow
        Write-Host "   (The GUI executes the following command: Import-Module SqlServer -Force)" -ForegroundColor Gray
    }
    else {
        Write-Host "1. If both 'SQLSERVER' and 'SQLPS' modules exist in your system, please run our RunMeFirst GUI to ensure the correct module is imported." -ForegroundColor Yellow
        Write-Host "   If the SqlServer module is not installed, you can install it with:" -ForegroundColor Gray
        Write-Host '   Install-Module -Name SqlServer -Force -AllowClobber' -ForegroundColor White
    }
}
else {
    if ($hasSQLPSDetected) {
        Write-Host "POTENTIAL ISSUE: SQLPS module is installed alongside SqlServer module." -ForegroundColor Yellow
        Write-Host "While currently using the correct SqlServer module, this could cause issues if module loading order changes." -ForegroundColor Yellow
        Write-Host
        Write-Host "Recommended Actions:" -ForegroundColor Green
        Write-Host "1. Always run our RunMeFirst GUI before using RDSTools to ensure the correct module is loaded." -ForegroundColor White
        Write-Host "2. If you experience TrustServerCertificate parameter errors, check:" -ForegroundColor Yellow
        Write-Host "   - Make sure you're using the correct parameter syntax for your SqlServer version" -ForegroundColor White
        Write-Host "   - Verify your SQL Server instance configuration allows for secure connections" -ForegroundColor White
    } else {
        Write-Host "No SQL module issues detected." -ForegroundColor Green
        Write-Host "If you're still experiencing TrustServerCertificate parameter errors, please check:" -ForegroundColor Yellow
        Write-Host "1. Make sure you're using the correct parameter syntax for your SqlServer version" -ForegroundColor White
        Write-Host "2. Check if you need to update your SqlServer module to the latest version" -ForegroundColor White
        Write-Host "3. Verify your SQL Server instance configuration allows for secure connections" -ForegroundColor White
    }
}