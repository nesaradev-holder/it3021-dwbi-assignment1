# Retail Banking Analytics Prototype

A self-directed DW/BI demonstration using synthetic retail-banking data. The project follows the technical topics in IT3021 Assignments 1 and 2 through one shared dataset and warehouse.

## Current stage

The CSV reporting prototype is working. The BankingOLTP source database now contains dbo.Branch with two fictional sample branches, dbo.Customer with one fictional sample customer, and dbo.Account with one fictional account linked to both. The remaining operational model, source data and warehouse pipeline will be developed incrementally and validated at each milestone.

## First Python example

[deposit_example.py](deposit_example.py) reads four fictional deposits from a CSV into a list of dictionaries and groups deposits by transaction branch and year-month, then prints each group total. It is an introductory example; it does not connect to a database or generate a dataset.

Run from the project root on Windows with Python 3 installed:

    py -3 .\deposit_example.py

Expected output with the current sample:

    Branch: BR001 | Month: 2026-10 | Total: 2500
    Branch: BR002 | Month: 2026-10 | Total: 2000
    Branch: BR002 | Month: 2026-11 | Total: 4000

Each group uses a (transaction branch, year-month) tuple as its dictionary key. New groups start at zero; later deposits add to the existing group total. The November total is 3000 + 1000. Each CSV row still represents one deposit. Dates are known ISO-formatted text in this introductory example.

Before calculating the total, the script checks transaction IDs across the CSV. A repeated transaction_id raises ValueError and stops the report. Each amount in this deposit-only, whole-number sample must be greater than zero; zero or negative amounts also stop the report with ValueError.

## CSV source sample

[data/deposits.sample.csv](data/deposits.sample.csv) contains four fictional deposits, with a header naming the five fields. Only this reviewed sample is allowed through the data-folder ignore rules. The script reads this file using Python's built-in csv module and converts amount text to whole numbers using int() before addition. Changing a deposit in the CSV changes the next report run. Run from the project root so the relative CSV path resolves.

## SQL source database setup

[sql/001_create_source_database.sql](sql/001_create_source_database.sql) creates the BankingOLTP source database if it is absent. Running it again leaves the existing database unchanged.

Open the script in SSMS connected to the local SQL Server instance, then press F5. Refresh Databases in Object Explorer to see BankingOLTP.

Then run [sql/002_create_branch_table.sql](sql/002_create_branch_table.sql). It selects BankingOLTP and creates dbo.Branch if absent, with branch_id (VARCHAR(10), primary key), branch_name and city (NVARCHAR(100)). All three columns are NOT NULL. Rerunning this script preserves an existing table.

Run [sql/003_insert_sample_branches.sql](sql/003_insert_sample_branches.sql) to add BR001 (Demo Piliyandala) and BR002 (Demo Maharagama). Each insert checks whether its ID already exists, so a rerun skips existing branches and preserves their stored values. These are fictional demonstration records.

Run [sql/004_create_customer_table.sql](sql/004_create_customer_table.sql) to create dbo.Customer if absent. It has customer_id (VARCHAR(10), primary key), customer_name and city (NVARCHAR(100)), all NOT NULL. Here city represents the customer's residence. Rerunning the script preserves an existing table.

Run [sql/005_insert_sample_customers.sql](sql/005_insert_sample_customers.sql) to add C001 (Demo Customer One, Piliyandala). The insert checks whether customer_id already exists, so rerunning it skips an existing customer and preserves its stored values. This is a fictional demonstration record.

Run [sql/006_create_account_table.sql](sql/006_create_account_table.sql) to create dbo.Account if absent. It has account_id (primary key), branch_id and customer_id, all VARCHAR(10) and NOT NULL. Foreign keys require branch_id to reference dbo.Branch and customer_id to reference dbo.Customer. For this initial prototype, each account has one customer and one home branch. Rerunning the script preserves an existing table.

Run [sql/007_insert_sample_accounts.sql](sql/007_insert_sample_accounts.sql) to add fictional account 98849932, owned by C001 with home branch BR001. The insert skips an existing account_id and preserves its stored values. This is the account used in the deposit CSV; an individual deposit may be handled at a different transaction branch.

Run [sql/008_query_account_details.sql](sql/008_query_account_details.sql) to read account IDs with customer names and home branch names. It uses INNER JOIN on customer_id and branch_id and does not change stored data. With the current sample, it returns 98849932 / Demo Customer One / Demo Piliyandala.

## Proposed scope

- Customer, Account, Branch and Transaction entities.
- About one year of meaningful synthetic records.
- SQL and file-based sources feeding a SQL Server warehouse through SSIS.
- Dimension-history handling and a separate transaction-completion update flow.
- SSAS and Excel analysis, followed by interactive Power BI reports.
- Python for source generation and independent validation.

## Project plan

![Proposed first-stage delivery plan](diagrams/assignment-delivery-plan.png)

- [Full project proposal (PDF)](docs/retail-banking-analytics-proposal.pdf)
- [Proposal text](docs/retail-banking-analytics-proposal.md)

The plan describes proposed work. Implementation artifacts and reproducible instructions will be added as the project develops.

## Data

Use synthetic demonstration data. Validate relationships, row counts, amounts, dimension history and processing times before relying on analytical results.
