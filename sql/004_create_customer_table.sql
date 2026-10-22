USE BankingOLTP;

IF OBJECT_ID('dbo.Customer', 'U') IS NULL
    CREATE TABLE dbo.Customer (
        customer_id VARCHAR(10) NOT NULL PRIMARY KEY,
        customer_name NVARCHAR(100) NOT NULL,
        city NVARCHAR(100) NOT NULL
    );
