param([string]$Server='localhost')
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell (powershell.exe).' }
$projectRoot=Split-Path -Parent $PSScriptRoot
$dtexec=Join-Path $env:ProgramFiles 'Microsoft SQL Server\160\DTS\Binn\DTExec.exe'
function Assert-Sql([string]$Query) {
    & sqlcmd -S $Server -E -C -b -l 10 -d BankingDW -Q $Query
    if ($LASTEXITCODE -ne 0) { throw 'Integration SQL assertion failed.' }
}
function Invoke-TestPackage([string]$Name) {
    & $dtexec /FILE (Join-Path $PSScriptRoot ($Name+'.dtsx')) /REPORTING E *> (Join-Path $projectRoot ('data\generated\test-'+$Name+'.log'))
    if ($LASTEXITCODE -ne 0) { throw ('Integration package failed: '+$Name) }
}
function Get-Snapshot {
    $query="SET NOCOUNT ON; SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',(SELECT * FROM dbo.FactDeposit ORDER BY TransactionID FOR JSON PATH)),2); SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',(SELECT * FROM dbo.DimCustomer ORDER BY CustomerKey FOR JSON PATH)),2);"
    $result=@(& sqlcmd -S $Server -E -C -b -W -h -1 -d BankingDW -Q $query | ForEach-Object {$_.Trim()} | Where-Object {$_})
    if ($LASTEXITCODE -ne 0) { throw 'Warehouse snapshot failed.' }
    return ($result -join '|')
}
Push-Location $projectRoot
try {
    & (Join-Path $PSScriptRoot 'run_demo.ps1') -Server $Server
    $initial=Get-Snapshot
    Invoke-TestPackage 'BankingWarehouse'
    Invoke-TestPackage 'CompletionUpdates'
    if ($initial -cne (Get-Snapshot)) { throw 'Repeat load changed facts, keys, timestamps or customer versions.' }
    Write-Output 'PASS: both packages rerun without changing complete fact/customer snapshots.'
    $historyPath=Join-Path $projectRoot 'data\generated\customer_changes.csv'
    $completionPath=Join-Path $projectRoot 'data\generated\completion_updates.csv'
    $historyBytes=[IO.File]::ReadAllBytes($historyPath)
    $completionBytes=[IO.File]::ReadAllBytes($completionPath)
    try {
        [IO.File]::AppendAllText($historyPath,"C_MISSING,Demo City 03,2026-07-01`r`n",[Text.Encoding]::Unicode)
        Invoke-TestPackage 'BankingWarehouse'
        Assert-Sql "SET NOCOUNT ON; IF NOT EXISTS(SELECT 1 FROM etl.Reject WHERE run_id=(SELECT MAX(run_id) FROM etl.Run WHERE package_name='BankingWarehouse') AND business_key='C_MISSING' AND reason='Unknown customer ID') THROW 51120,'Unknown customer history row not rejected',1;"
        $rows=@(Import-Csv -LiteralPath $completionPath -Encoding Unicode)
        $rows[0].complete_time='2000-01-01T00:00:00.0000000'
        [IO.File]::WriteAllLines($completionPath,@($rows | ConvertTo-Csv -NoTypeInformation),[Text.Encoding]::Unicode)
        Invoke-TestPackage 'CompletionUpdates'
        Assert-Sql "SET NOCOUNT ON; IF NOT EXISTS(SELECT 1 FROM etl.Reject WHERE run_id=(SELECT MAX(run_id) FROM etl.Run WHERE package_name='CompletionUpdates') AND business_key='2005583029' AND reason='Completion precedes create time') THROW 51121,'Invalid completion time not rejected',1;"
        if ($initial -cne (Get-Snapshot)) { throw 'Rejected input changed valid fact/customer rows.' }
        Write-Output 'PASS: unknown history customer and invalid completion timestamp rejected; valid warehouse unchanged.'
    } finally {
        [IO.File]::WriteAllBytes($historyPath,$historyBytes)
        [IO.File]::WriteAllBytes($completionPath,$completionBytes)
    }
    Invoke-TestPackage 'BankingWarehouse'
    Invoke-TestPackage 'CompletionUpdates'
    & sqlcmd -S $Server -E -C -b -d BankingDW -i (Join-Path $projectRoot 'sql\013_validate_warehouse.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Final integration validation failed.' }
    & (Join-Path $PSScriptRoot 'export_report_data.ps1') -Server $Server
    Write-Output 'PASS: integration tests complete; original feeds restored and nominal packages rerun.'
} finally { Pop-Location }
