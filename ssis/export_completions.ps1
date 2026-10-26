param([string]$Server = 'localhost')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$connectionSettings = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$connectionSettings['Data Source'] = $Server
$connectionSettings['Initial Catalog'] = 'BankingDW'
$connectionSettings['Integrated Security'] = $true
$connectionSettings['Encrypt'] = $true
$connectionSettings['TrustServerCertificate'] = $true
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionSettings.ConnectionString)
$rows = New-Object 'System.Collections.Generic.List[object]'
try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = 'SELECT TransactionID,accm_txn_create_time FROM dbo.FactDeposit ORDER BY TransactionID;'
    $reader = $command.ExecuteReader()
    $index = 0
    while ($reader.Read()) {
        $created = $reader.GetDateTime(1)
        $completed = $created.AddMinutes(30 + (($index % 12) * 15))
        $rows.Add([pscustomobject]@{
            transaction_id = $reader.GetString(0)
            complete_time = $completed.ToString('yyyy-MM-ddTHH:mm:ss.fffffff',[Globalization.CultureInfo]::InvariantCulture)
        })
        $index++
    }
    $reader.Close()
} finally { $connection.Dispose() }
if ($rows.Count -eq 0) { throw 'Run the main warehouse package before generating completion updates.' }
# A deliberately unknown ID demonstrates the separate completion rejection path.
$rows.Add([pscustomobject]@{transaction_id='MISS000001';complete_time=$rows[0].complete_time})
$targetPath = Join-Path $projectRoot 'data\generated\completion_updates.csv'
$csvLines = @($rows | ConvertTo-Csv -NoTypeInformation)
[System.IO.File]::WriteAllLines($targetPath,$csvLines,[System.Text.Encoding]::Unicode)
Write-Output ('Created completion updates for ' + ($rows.Count - 1) + ' facts plus one deliberate unknown-ID test row.')
