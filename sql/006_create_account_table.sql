USE BankingOLTP;

IF OBJECT_ID('dbo.Account', 'U') IS NULL
    CREATE TABLE dbo.Account (
        account_id VARCHAR(10) NOT NULL PRIMARY KEY,
        branch_id VARCHAR(10) NOT NULL,
        customer_id VARCHAR(10) NOT NULL,

        FOREIGN KEY (branch_id) REFERENCES dbo.Branch(branch_id),
        FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id)
    );
