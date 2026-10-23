USE BankingOLTP;

SELECT dbo.Account.account_id, dbo.Customer.customer_name, dbo.Branch.branch_name
FROM dbo.Account
INNER JOIN dbo.Customer
	ON dbo.Customer.customer_id = dbo.Account.customer_id
INNER JOIN dbo.Branch
	ON dbo.Account.branch_id = dbo.Branch.branch_id;
