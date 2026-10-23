USE BankingOLTP;

IF NOT EXISTS (SELECT 1 FROM dbo.Account WHERE account_id = '98849932')
    INSERT INTO dbo.Account (account_id, branch_id, customer_id)
    VALUES ('98849932', 'BR001', 'C001');
