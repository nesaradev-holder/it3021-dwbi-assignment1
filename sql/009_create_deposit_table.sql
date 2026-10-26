USE BankingOLTP;

IF OBJECT_ID('dbo.Deposit', 'U') IS NULL
	CREATE TABLE dbo.Deposit (
		transaction_id VARCHAR(10) NOT NULL PRIMARY KEY,
		account_id VARCHAR(10) NOT NULL,
		transaction_branch_id VARCHAR(10) NOT NULL,
		transaction_date DATE NOT NULL,
		amount DECIMAL(18, 2) NOT NULL CHECK (amount > 0),

		FOREIGN KEY (account_id)
			REFERENCES dbo.Account(account_id),

		FOREIGN KEY (transaction_branch_id)
			REFERENCES dbo.Branch(branch_id)
	);