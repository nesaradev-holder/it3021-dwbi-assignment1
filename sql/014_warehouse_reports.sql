USE BankingDW;
SET NOCOUNT ON;
-- Handling-branch performance in the fictional scenario.
SELECT b.BranchID,b.BranchName,d.YearMonth,
       COUNT_BIG(*) AS DepositTransactions,SUM(f.Amount) AS TotalAmount
FROM dbo.FactDeposit f
JOIN dbo.DimDate d ON d.DateKey=f.DateKey
JOIN dbo.DimBranch b ON b.BranchKey=f.BranchKey
GROUP BY b.BranchID,b.BranchName,d.YearMonth
ORDER BY d.YearMonth,b.BranchID;

-- Customer history: the same business ID retains two different city versions.
SELECT c.CustomerID,c.City,c.ValidFrom,c.ValidTo,COUNT(f.DepositKey) AS Deposits,SUM(f.Amount) AS TotalAmount
FROM dbo.DimCustomer c
LEFT JOIN dbo.FactDeposit f ON f.CustomerKey=c.CustomerKey
WHERE c.CustomerID='C001'
GROUP BY c.CustomerID,c.City,c.ValidFrom,c.ValidTo
ORDER BY c.ValidFrom;

-- Completion timing is a simulated warehouse workflow, not an observed banking SLA.
SELECT COUNT(*) AS CompletedDeposits,AVG(txn_process_time_hours) AS AverageProcessHours
FROM dbo.FactDeposit WHERE accm_txn_complete_time IS NOT NULL;
SELECT TOP(6) run_id,package_name,status,facts_inserted,facts_updated,rejected_rows
FROM etl.Run ORDER BY run_id DESC;
