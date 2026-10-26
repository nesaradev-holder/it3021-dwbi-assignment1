param([string]$Server='localhost')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$settings=New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$settings['Data Source']=$Server
$settings['Initial Catalog']='BankingDW'
$settings['Integrated Security']=$true
$settings['Encrypt']=$true
$settings['TrustServerCertificate']=$true
$connection=New-Object System.Data.SqlClient.SqlConnection($settings.ConnectionString)
function Read-Rows([string]$Query) {
    $command=$connection.CreateCommand()
    $command.CommandText=$Query
    $reader=$command.ExecuteReader()
    $result=New-Object 'System.Collections.Generic.List[object]'
    try {
        while ($reader.Read()) {
            $record=[ordered]@{}
            for ($column=0;$column -lt $reader.FieldCount;$column++) {
                $record[$reader.GetName($column)]=if ($reader.IsDBNull($column)) {$null} else {$reader.GetValue($column)}
            }
            $result.Add([pscustomobject]$record)
        }
    } finally {$reader.Close();$command.Dispose()}
    return $result.ToArray()
}
try {
    $connection.Open()
    $summarySql=@"
SELECT COUNT(*) AS DepositCount,CONVERT(VARCHAR(40),SUM(Amount)) AS TotalAmount,
       COUNT(DISTINCT DateKey) AS DaysCovered,
       SUM(CASE WHEN accm_txn_complete_time IS NOT NULL THEN 1 ELSE 0 END) AS CompletedDeposits,
       CONVERT(VARCHAR(40),MIN(txn_process_time_hours)) AS MinimumHours,
       CONVERT(VARCHAR(40),MAX(txn_process_time_hours)) AS MaximumHours,
       CONVERT(VARCHAR(40),AVG(txn_process_time_hours)) AS AverageHours,
       (SELECT COUNT(*) FROM dbo.DimBranch) AS Branches,
       (SELECT COUNT(*) FROM dbo.DimAccount) AS Accounts,
       (SELECT COUNT(*) FROM dbo.DimCustomer WHERE IsCurrent=1) AS Customers,
       (SELECT COUNT(*) FROM dbo.DimCustomer) AS CustomerVersions,
       (SELECT COUNT(*) FROM dbo.FactDeposit f JOIN dbo.DimBranch b ON b.BranchKey=f.BranchKey
        JOIN dbo.DimAccount a ON a.AccountKey=f.AccountKey WHERE b.BranchID<>a.HomeBranchID) AS HandledElsewhere
FROM dbo.FactDeposit;
"@
    $summary=@(Read-Rows $summarySql)[0]
    $branchSql=@"
SELECT b.BranchID,b.BranchName,COUNT(*) AS DepositCount,
       CONVERT(VARCHAR(40),SUM(f.Amount)) AS TotalAmount,
       CONVERT(VARCHAR(20),CONVERT(DECIMAL(8,2),SUM(f.Amount)*100.0/(SELECT SUM(Amount) FROM dbo.FactDeposit))) AS SharePercent
FROM dbo.FactDeposit f JOIN dbo.DimBranch b ON b.BranchKey=f.BranchKey
GROUP BY b.BranchID,b.BranchName ORDER BY SUM(f.Amount) DESC,b.BranchID;
"@
    $branches=@(Read-Rows $branchSql)
    $monthSql=@"
SELECT d.YearMonth,COUNT(*) AS DepositCount,CONVERT(VARCHAR(40),SUM(f.Amount)) AS TotalAmount
FROM dbo.FactDeposit f JOIN dbo.DimDate d ON d.DateKey=f.DateKey
GROUP BY d.YearMonth ORDER BY d.YearMonth;
"@
    $months=@(Read-Rows $monthSql)
    $historySql=@"
SELECT c.CustomerID,c.City,CONVERT(CHAR(10),c.ValidFrom,23) AS ValidFrom,
       CONVERT(CHAR(10),c.ValidTo,23) AS ValidTo,COUNT(f.DepositKey) AS DepositCount
FROM dbo.DimCustomer c LEFT JOIN dbo.FactDeposit f ON f.CustomerKey=c.CustomerKey
WHERE c.CustomerID='C001' GROUP BY c.CustomerID,c.City,c.ValidFrom,c.ValidTo ORDER BY c.ValidFrom;
"@
    $history=@(Read-Rows $historySql)
    $runSql=@"
WITH recent AS (
 SELECT run_id,package_name,status,facts_inserted,facts_updated,rejected_rows,
        ROW_NUMBER() OVER(PARTITION BY package_name ORDER BY run_id DESC) AS position FROM etl.Run
)
SELECT package_name,status,facts_inserted,facts_updated,rejected_rows FROM recent WHERE position=1 ORDER BY package_name;
"@
    $runs=@(Read-Rows $runSql)
    $report=[ordered]@{year=2026;amount_unit='synthetic currency units';summary=$summary;branches=$branches;months=$months;customer_history=$history;latest_runs=$runs}
    $output=Join-Path $projectRoot 'data\generated'
    [IO.File]::WriteAllText((Join-Path $output 'warehouse_report.json'),($report | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
    $branches | Export-Csv -LiteralPath (Join-Path $output 'branch_totals.csv') -NoTypeInformation -Encoding UTF8
    $months | Export-Csv -LiteralPath (Join-Path $output 'monthly_totals.csv') -NoTypeInformation -Encoding UTF8
    Write-Output 'Exported validated warehouse metrics, branch totals and monthly totals under ignored data/generated/.'
} finally {$connection.Dispose()}
