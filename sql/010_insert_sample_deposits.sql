USE BankingOLTP;

-- Reviewed fictional records matching data/deposits.sample.csv.
IF NOT EXISTS (SELECT 1 FROM dbo.Deposit WHERE transaction_id = '2005583029')
    INSERT INTO dbo.Deposit (transaction_id, account_id, transaction_branch_id, transaction_date, amount)
    VALUES ('2005583029', '98849932', 'BR001', '2026-10-19', 2500.00);

IF NOT EXISTS (SELECT 1 FROM dbo.Deposit WHERE transaction_id = '2005583030')
    INSERT INTO dbo.Deposit (transaction_id, account_id, transaction_branch_id, transaction_date, amount)
    VALUES ('2005583030', '98849932', 'BR002', '2026-10-19', 2000.00);

IF NOT EXISTS (SELECT 1 FROM dbo.Deposit WHERE transaction_id = '2005583031')
    INSERT INTO dbo.Deposit (transaction_id, account_id, transaction_branch_id, transaction_date, amount)
    VALUES ('2005583031', '98849932', 'BR002', '2026-11-05', 3000.00);

IF NOT EXISTS (SELECT 1 FROM dbo.Deposit WHERE transaction_id = '2005583032')
    INSERT INTO dbo.Deposit (transaction_id, account_id, transaction_branch_id, transaction_date, amount)
    VALUES ('2005583032', '98849932', 'BR002', '2026-11-20', 1000.00);
