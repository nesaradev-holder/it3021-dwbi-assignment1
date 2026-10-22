USE BankingOLTP;

IF NOT EXISTS (SELECT 1 FROM dbo.Branch WHERE branch_id = 'BR001')
    INSERT INTO dbo.Branch (branch_id, branch_name, city)
    VALUES ('BR001', N'Demo Piliyandala', N'Piliyandala');

IF NOT EXISTS (SELECT 1 FROM dbo.Branch WHERE branch_id = 'BR002')
    INSERT INTO dbo.Branch (branch_id, branch_name, city)
    VALUES ('BR002', N'Demo Maharagama', N'Maharagama');
