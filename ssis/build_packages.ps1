param([string]$Server = 'localhost')
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or -not [Environment]::Is64BitProcess) {
    throw 'Use 64-bit Windows PowerShell (powershell.exe), not pwsh, for the SSIS .NET Framework SDK.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$assemblies = @(
    @('GAC_MSIL','Microsoft.SqlServer.ManagedDTS','Microsoft.SqlServer.ManagedDTS.dll'),
    @('GAC_MSIL','Microsoft.SqlServer.DTSPipelineWrap','Microsoft.SQLServer.DTSPipelineWrap.dll'),
    @('GAC_64','Microsoft.SqlServer.DTSRuntimeWrap','Microsoft.SqlServer.DTSRuntimeWrap.dll')
)
$references = @('System.dll','System.Core.dll')
foreach ($assembly in $assemblies) {
    $base = Join-Path $env:windir ('Microsoft.NET\assembly\' + $assembly[0] + '\' + $assembly[1])
    $version = Get-ChildItem -LiteralPath $base -Directory | Where-Object { $_.Name -like 'v4.0_16.0.0.0__*' } | Select-Object -First 1
    if (-not $version) { throw ('SQL Server 2022 SSIS SDK assembly missing: ' + $assembly[1]) }
    $assemblyPath = Join-Path $version.FullName $assembly[2]
    [void][System.Reflection.Assembly]::LoadFrom($assemblyPath)
    $references += $assemblyPath
}
Add-Type -Path (Join-Path $PSScriptRoot 'SsisPackageBuilder.cs') -ReferencedAssemblies $references
try { [BankingSsisBuilder]::Build($projectRoot,$Server) } catch { Write-Output $_.Exception.ToString(); if ($_.Exception.InnerException) { Write-Output $_.Exception.InnerException.ToString() }; throw }
Write-Output 'Built BankingWarehouse.dtsx and CompletionUpdates.dtsx with relative data paths and Windows Authentication.'
