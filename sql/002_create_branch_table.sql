USE BankingOLTP;

IF OBJECT_ID('dbo.Branch', 'U') IS NULL
    CREATE TABLE dbo.Branch (
        branch_id VARCHAR(10) NOT NULL PRIMARY KEY,
        branch_name NVARCHAR(100) NOT NULL,
        city NVARCHAR(100) NOT NULL
    );
