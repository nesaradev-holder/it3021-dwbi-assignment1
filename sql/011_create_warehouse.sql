IF DB_ID('BankingDW') IS NULL
    CREATE DATABASE BankingDW;
GO
USE BankingDW;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
GO
IF OBJECT_ID('stg.Branch','U') IS NULL
    CREATE TABLE stg.Branch (branch_id VARCHAR(10), branch_name NVARCHAR(100), city NVARCHAR(100));
IF OBJECT_ID('stg.Customer','U') IS NULL
    CREATE TABLE stg.Customer (customer_id VARCHAR(10), customer_name NVARCHAR(100), city NVARCHAR(100));
IF OBJECT_ID('stg.Account','U') IS NULL
    CREATE TABLE stg.Account (account_id VARCHAR(10), branch_id VARCHAR(10), customer_id VARCHAR(10));
IF OBJECT_ID('stg.Deposit','U') IS NULL
    CREATE TABLE stg.Deposit (
        transaction_id VARCHAR(10), account_id VARCHAR(10), transaction_branch_id VARCHAR(10),
        transaction_date DATE, amount DECIMAL(18,2)
    );
IF OBJECT_ID('stg.CustomerChange','U') IS NULL
    CREATE TABLE stg.CustomerChange (customer_id NVARCHAR(100), city NVARCHAR(200), effective_from NVARCHAR(50));
IF OBJECT_ID('stg.Completion','U') IS NULL
    CREATE TABLE stg.Completion (transaction_id NVARCHAR(100), complete_time NVARCHAR(50));

IF OBJECT_ID('dbo.DimDate','U') IS NULL
    CREATE TABLE dbo.DimDate (
        DateKey INT NOT NULL PRIMARY KEY,
        FullDate DATE NOT NULL UNIQUE,
        CalendarYear SMALLINT NOT NULL,
        CalendarQuarter TINYINT NOT NULL,
        MonthNumber TINYINT NOT NULL,
        YearMonth CHAR(7) NOT NULL,
        DayOfMonth TINYINT NOT NULL
    );
IF OBJECT_ID('dbo.DimBranch','U') IS NULL
    CREATE TABLE dbo.DimBranch (
        BranchKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        BranchID VARCHAR(10) NOT NULL UNIQUE,
        BranchName NVARCHAR(100) NOT NULL,
        City NVARCHAR(100) NOT NULL
    );
IF OBJECT_ID('dbo.DimAccount','U') IS NULL
    CREATE TABLE dbo.DimAccount (
        AccountKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AccountID VARCHAR(10) NOT NULL UNIQUE,
        CustomerID VARCHAR(10) NOT NULL,
        HomeBranchID VARCHAR(10) NOT NULL
    );
IF OBJECT_ID('dbo.DimCustomer','U') IS NULL
BEGIN
    CREATE TABLE dbo.DimCustomer (
        CustomerKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CustomerID VARCHAR(10) NOT NULL,
        CustomerName NVARCHAR(100) NOT NULL,
        City NVARCHAR(100) NOT NULL,
        ValidFrom DATE NOT NULL,
        ValidTo DATE NULL,
        IsCurrent BIT NOT NULL,
        CONSTRAINT UQ_DimCustomer_Version UNIQUE(CustomerID,ValidFrom),
        CONSTRAINT CK_DimCustomer_Interval CHECK(ValidTo IS NULL OR ValidTo > ValidFrom),
        CONSTRAINT CK_DimCustomer_Current CHECK(
            (IsCurrent=1 AND ValidTo IS NULL) OR (IsCurrent=0 AND ValidTo IS NOT NULL)
        )
    );
END;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.DimCustomer') AND name='UX_DimCustomer_Current')
    CREATE UNIQUE INDEX UX_DimCustomer_Current ON dbo.DimCustomer(CustomerID) WHERE IsCurrent=1;
IF OBJECT_ID('dbo.FactDeposit','U') IS NULL
    CREATE TABLE dbo.FactDeposit (
        DepositKey BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        TransactionID VARCHAR(10) NOT NULL UNIQUE,
        DateKey INT NOT NULL REFERENCES dbo.DimDate(DateKey),
        BranchKey INT NOT NULL REFERENCES dbo.DimBranch(BranchKey),
        CustomerKey INT NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
        AccountKey INT NOT NULL REFERENCES dbo.DimAccount(AccountKey),
        Amount DECIMAL(18,2) NOT NULL CHECK(Amount>0),
        DepositCount TINYINT NOT NULL DEFAULT 1 CHECK(DepositCount=1),
        accm_txn_create_time DATETIME2(7) NOT NULL,
        accm_txn_complete_time DATETIME2(7) NULL,
        txn_process_time_hours DECIMAL(18,6) NULL,
        CONSTRAINT CK_FactDeposit_Completion CHECK(
            (accm_txn_complete_time IS NULL AND txn_process_time_hours IS NULL) OR
            (accm_txn_complete_time >= accm_txn_create_time AND txn_process_time_hours >= 0
             AND accm_txn_complete_time IS NOT NULL AND txn_process_time_hours IS NOT NULL)
        )
    );
IF OBJECT_ID('etl.Run','U') IS NULL
    CREATE TABLE etl.Run (
        run_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        package_name NVARCHAR(80) NOT NULL,
        started_at DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
        completed_at DATETIME2(7) NULL,
        status VARCHAR(30) NOT NULL,
        facts_inserted INT NOT NULL DEFAULT 0,
        facts_updated INT NOT NULL DEFAULT 0,
        rejected_rows INT NOT NULL DEFAULT 0,
        error_message NVARCHAR(2048) NULL
    );
IF OBJECT_ID('etl.Reject','U') IS NULL
    CREATE TABLE etl.Reject (
        reject_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        run_id BIGINT NOT NULL REFERENCES etl.Run(run_id),
        feed NVARCHAR(80) NOT NULL,
        business_key NVARCHAR(100) NULL,
        reason NVARCHAR(400) NOT NULL,
        recorded_at DATETIME2(7) NOT NULL DEFAULT SYSDATETIME()
    );
GO
