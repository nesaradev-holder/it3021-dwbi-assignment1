USE BankingOLTP;

IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 'C001')
    INSERT INTO dbo.Customer (customer_id, customer_name, city)
    VALUES ('C001', N'Demo Customer One', N'Piliyandala');
