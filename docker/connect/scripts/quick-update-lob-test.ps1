# Quick UPDATE test for CDC

$oracleUser = "appuser"
$oraclePassword = "AppUserPass123"
$oracleDb = "xepdb1"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Quick CDC UPDATE Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Create temp SQL file
$sqlFile = "$env:TEMP\update-test.sql"

# Testing CLOB,BLOB
# $sqlContent = @"
# UPDATE STMT_ENTRY
# SET AUDIT_TRAIL = 'LOG_B4_UPDATED: This text changes the original audit log trail profile completely to check the update functionality.',
#     DIGITAL_RECEIPT = UTL_RAW.CAST_TO_RAW('555044415445445f424c4f42') -- "UPDATED_BLOB" in Hex
# WHERE ENTRY_ID = 'TXN-2026-001';
# COMMIT;
# EXIT;
# "@

# Testing XMLTYPE
$sqlContent = @"
UPDATE STMT_ENTRY
SET TXN_METADATA = XMLTYPE('<t24_meta><vendor>B5_TEST_PAY</vendor><status>AMENDED_BY_B5_TEST</status></t24_meta>')
WHERE ENTRY_ID = 'TXN-2026-007';
COMMIT;
  
EXIT;
"@

try {
    Write-Host "[1/3] Creating SQL file..." -ForegroundColor Cyan
    $sqlContent | Out-File -FilePath $sqlFile -Encoding ASCII -Force
    
    Write-Host "[2/3] Executing UPDATE..." -ForegroundColor Cyan
    Get-Content $sqlFile | docker exec -i oracle sqlplus -S "$oracleUser/$oraclePassword@$oracleDb" 2>&1
    
    Write-Host ""
    Write-Host "SUCCESS: UPDATE completed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Waiting 3 seconds before reading CDC payload..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    Write-Host ""
    Write-Host "[3/3] Reading CDC payload (with before/after)..." -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor DarkGray
    Write-Host ""
    
    & ".\docker\connect\scripts\verify-cdc-payload.ps1"
    
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path $sqlFile) {
        Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue
    }
}
