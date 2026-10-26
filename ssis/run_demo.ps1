param([string]$Server = 'localhost',[switch]$RebuildPackages)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or -not [Environment]::Is64BitProcess) {
    throw 'Run this with 64-bit Windows PowerShell: powershell.exe -File .\ssis\run_demo.ps1'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($Server -eq 'localhost') {
    $service=Get-Service -Name MSSQLSERVER -ErrorAction Stop
    if ($service.Status -ne 'Running') {
        try { Start-Service -Name MSSQLSERVER -ErrorAction Stop; $service.WaitForStatus('Running',[TimeSpan]::FromSeconds(30)) }
        catch { throw 'SQL Server is stopped. Start MSSQLSERVER from administrator PowerShell, then rerun this command.' }
    }
}
$dtexec = Join-Path $env:ProgramFiles 'Microsoft SQL Server\160\DTS\Binn\DTExec.exe'
if (-not (Test-Path -LiteralPath $dtexec)) { throw 'SQL Server 2022 Integration Services runtime is required.' }
function Invoke-SqlFile([string]$Path) {
    & sqlcmd -S $Server -E -C -b -I -l 10 -i $Path
    if ($LASTEXITCODE -ne 0) { throw ('SQL script failed: ' + [IO.Path]::GetFileName($Path)) }
}
function Invoke-Package([string]$Name) {
    $logPath = Join-Path $projectRoot ('data\generated\' + $Name + '.log')
    & $dtexec /FILE (Join-Path $PSScriptRoot ($Name + '.dtsx')) /REPORTING EW 2>&1 | Tee-Object -FilePath $logPath
    if ($LASTEXITCODE -ne 0) { throw ('SSIS package failed: ' + $Name + '. Inspect its generated log.') }
}
Push-Location $projectRoot
try {
    & py -3 .\generate_demo_data.py
    if ($LASTEXITCODE -ne 0) { throw 'Source generation failed.' }
    & py -3 -m unittest discover -s tests -v
    if ($LASTEXITCODE -ne 0) { throw 'Source tests failed.' }
    foreach ($name in @('001_create_source_database.sql','002_create_branch_table.sql',
        '003_insert_sample_branches.sql','004_create_customer_table.sql','005_insert_sample_customers.sql',
        '006_create_account_table.sql','007_insert_sample_accounts.sql','009_create_deposit_table.sql',
        '010_insert_sample_deposits.sql')) { Invoke-SqlFile (Join-Path $projectRoot ('sql\' + $name)) }
    Invoke-SqlFile (Join-Path $projectRoot 'data\generated\load_demo_sources.sql')
    Invoke-SqlFile (Join-Path $projectRoot 'sql\011_create_warehouse.sql')
    Invoke-SqlFile (Join-Path $projectRoot 'sql\012_warehouse_etl.sql')
    $packagesMissing = -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'BankingWarehouse.dtsx')) -or -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'CompletionUpdates.dtsx'))
    if ($RebuildPackages -or $Server -ne 'localhost' -or $packagesMissing) {
        & (Join-Path $PSScriptRoot 'build_packages.ps1') -Server $Server
    }
    Invoke-Package 'BankingWarehouse'
    & (Join-Path $PSScriptRoot 'export_completions.ps1') -Server $Server
    Invoke-Package 'CompletionUpdates'
    Invoke-SqlFile (Join-Path $projectRoot 'sql\013_validate_warehouse.sql')
    & (Join-Path $PSScriptRoot 'export_report_data.ps1') -Server $Server
    Write-Output 'PASS: generated sources -> SSIS -> historical warehouse -> completion updates -> SQL validation.'
} finally { Pop-Location }
