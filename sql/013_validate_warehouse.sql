USE BankingDW;
SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM dbo.FactDeposit)<>(SELECT COUNT(*) FROM BankingOLTP.dbo.Deposit)
    THROW 51100,'Source and warehouse deposit counts differ.',1;
IF (SELECT SUM(Amount) FROM dbo.FactDeposit)<>(SELECT SUM(amount) FROM BankingOLTP.dbo.Deposit)
    THROW 51101,'Source and warehouse deposit totals differ.',1;
IF EXISTS(SELECT transaction_id FROM BankingOLTP.dbo.Deposit EXCEPT SELECT TransactionID FROM dbo.FactDeposit)
    OR EXISTS(SELECT TransactionID FROM dbo.FactDeposit EXCEPT SELECT transaction_id FROM BankingOLTP.dbo.Deposit)
    THROW 51102,'Source and warehouse transaction IDs differ.',1;
IF EXISTS(
    SELECT 1 FROM dbo.FactDeposit f
    JOIN BankingOLTP.dbo.Deposit s ON s.transaction_id=f.TransactionID
    JOIN BankingOLTP.dbo.Account sa ON sa.account_id=s.account_id
    JOIN dbo.DimDate d ON d.DateKey=f.DateKey
    JOIN dbo.DimBranch b ON b.BranchKey=f.BranchKey
    JOIN dbo.DimAccount a ON a.AccountKey=f.AccountKey
    JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey
    WHERE f.Amount<>s.amount OR d.FullDate<>s.transaction_date OR b.BranchID<>s.transaction_branch_id
       OR a.AccountID<>s.account_id OR c.CustomerID<>sa.customer_id
       OR d.FullDate<c.ValidFrom OR (c.ValidTo IS NOT NULL AND d.FullDate>=c.ValidTo)
) THROW 51103,'Fact values, branch roles or temporal customer mapping differ from source.',1;
IF (SELECT COUNT(*) FROM dbo.DimDate)<>365
    THROW 51104,'Expected all 365 calendar dates in the demo year.',1;
IF EXISTS(
    SELECT 1 FROM dbo.DimCustomer a JOIN dbo.DimCustomer b ON a.CustomerID=b.CustomerID
    AND a.CustomerKey<b.CustomerKey AND a.ValidFrom<ISNULL(b.ValidTo,'99991231')
    AND b.ValidFrom<ISNULL(a.ValidTo,'99991231')
) THROW 51105,'Customer history intervals overlap.',1;
IF (SELECT COUNT(*) FROM dbo.DimCustomer WHERE IsCurrent=1)<>(SELECT COUNT(*) FROM BankingOLTP.dbo.Customer)
    THROW 51106,'Expected exactly one current customer version per source customer.',1;
IF (SELECT COUNT(*) FROM dbo.DimCustomer WHERE CustomerID='C001')<2
    THROW 51107,'The customer history demonstration has not loaded.',1;
IF EXISTS(SELECT 1 FROM dbo.FactDeposit WHERE accm_txn_complete_time IS NULL OR txn_process_time_hours IS NULL)
    THROW 51108,'Completion updates are incomplete.',1;
IF EXISTS(
    SELECT 1 FROM dbo.FactDeposit
    WHERE accm_txn_complete_time<accm_txn_create_time OR txn_process_time_hours<0
       OR ABS(txn_process_time_hours-CONVERT(DECIMAL(18,6),
           DATEDIFF_BIG(MICROSECOND,accm_txn_create_time,accm_txn_complete_time)/3600000000.0))>0.000001
) THROW 51109,'Completion timing or processing-hour calculations are invalid.',1;
IF EXISTS(
    SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID('dbo.FactDeposit')
      AND (is_disabled=1 OR is_not_trusted=1)
) THROW 51110,'Fact foreign keys must remain enabled and trusted.',1;
IF EXISTS(SELECT 1 FROM dbo.FactDeposit WHERE TransactionID='MISS000001')
    THROW 51111,'Unknown completion ID must not create a fact.',1;
IF NOT EXISTS(
    SELECT 1 FROM etl.Reject WHERE run_id=(SELECT MAX(run_id) FROM etl.Run WHERE package_name=N'CompletionUpdates')
       AND business_key=N'MISS000001' AND reason=N'Unknown transaction ID'
) THROW 51112,'Expected unknown completion ID was not logged.',1;
SELECT N'PASS: source/fact counts, amounts and natural transaction IDs reconcile' AS validation
UNION ALL SELECT N'PASS: dimension keys, handling-branch role and historical city mapping reconcile'
UNION ALL SELECT N'PASS: full Date coverage and non-overlapping Customer history'
UNION ALL SELECT N'PASS: all facts complete with non-negative, reconciled processing hours'
UNION ALL SELECT N'PASS: missing completion ID rejected without inserting a fact';
SELECT COUNT(*) AS deposit_count,SUM(Amount) AS total_amount,
       MIN(txn_process_time_hours) AS min_process_hours,MAX(txn_process_time_hours) AS max_process_hours
FROM dbo.FactDeposit;
