# Quick INSERT test for CDC

$oracleUser = "appuser"
$oraclePassword = "AppUserPass123"
$oracleDb = "xepdb1"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Quick CDC INSERT Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Create temp SQL file
$sqlFile = "$env:TEMP\insert-test.sql"

$sqlContent = @"
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-011', '1000293847', TO_DATE('2026-09-08', 'YYYY-MM-DD'), 'REMT', 24250.00, 'EGP',
    XMLTYPE('<t24_meta><orig_currency>USD</orig_currency><orig_amount>500.00</orig_amount><fx_rate>48.50</fx_rate></t24_meta>'),
    'LOG: 2026-09-08T09:30:45Z - Inbound SWIFT wire transfer cleared. Sender: RemitCorp Intl. FX booking executed at central treasury desk spot rate 48.50.',
    UTL_RAW.CAST_TO_RAW('255044462d53574946545f4d543130335f52454d495454414e4345')
);
COMMIT;
EXIT;
"@

try {
    Write-Host "[1/3] Creating SQL file..." -ForegroundColor Cyan
    $sqlContent | Out-File -FilePath $sqlFile -Encoding ASCII -Force
    
    Write-Host "[2/3] Executing INSERT..." -ForegroundColor Cyan
    Get-Content $sqlFile | docker exec -i oracle sqlplus -S "$oracleUser/$oraclePassword@$oracleDb" 2>&1
    
    Write-Host ""
    Write-Host "SUCCESS: INSERT completed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Waiting 3 seconds before reading CDC payload..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    Write-Host ""
    Write-Host "[3/3] Reading CDC payload (INSERT with after)..." -ForegroundColor Cyan
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
