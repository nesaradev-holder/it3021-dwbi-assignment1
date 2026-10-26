# Reproducible retail-banking source dataset

## Implemented milestone

The operational source is a fictional deposit-banking demonstration in SQL Server. Python generates and validates its source records; the working warehouse ETL uses two SSIS packages. This guide covers source preparation. See WAREHOUSE_HANDOVER.md for the implemented dimensional model, history and completion flows.

| Source table | Rows | Grain |
|---|---:|---|
| Branch | 8 | One demonstration branch |
| Customer | 200 | One fictional customer |
| Account | 400 | One account with one customer and one home branch |
| Deposit | 7,304 | One positive deposit transaction |

There are 20 generated deposits per calendar day in 2026, plus the four original fixture deposits. All 365 days from 2026-01-01 through 2026-12-31 are represented. The whole calendar is synthetic, including dates after the project run date. Branch/customer names and identifiers are demonstration values. The two original city names provide familiar context; the additional `Demo City` labels are fictional.

Default seed: **3021**. With the same Python version, code and fixture, this produces identical files. Amounts use a single illustrative currency unit with two decimal places; no currency conversion, account balances, fraud decisions or real bank performance are represented.

Default dataset total: **182,891,102.97**. A total of **1,819 deposits** are handled at a branch other than the account's home branch. These figures describe the generated scenario and are not observations about a real institution.

## Reproduce the sources

Prerequisites: Python 3.14 (the tested version), an accessible SQL Server instance, and sqlcmd. Run commands from the repository root. The Python generator uses only the standard library.

1. On a fresh database instance, run the reviewed SQL scripts 001 through 007 to create the source database, parent tables and original parent records. Script 008 is a read-only example. Run 009 to create Deposit. Script 010 inserts the original four-event fixture and can be rerun safely.
2. Generate and validate the year-sized files:

   ```powershell
   py -3 .\generate_demo_data.py
   py -3 -m unittest discover -s tests -v
   ```

3. Populate the operational source using Windows Authentication:

   ```powershell
   sqlcmd -S localhost -E -C -b -d BankingOLTP -i .\data\generated\load_demo_sources.sql
   ```

   `-C` trusts the certificate for this local demonstration connection. Use the appropriate validated certificate configuration for another environment.

Generated output lives in `data/generated/`, which stays ignored by Git:

- `branches.csv`, `customers.csv`, `accounts.csv`, `deposits.csv`: validated source records.
- `load_demo_sources.sql`: atomic SQL source seed that inserts missing records.
- `summary.json`: reproducible counts, date range, seed and amount total.
- `customer_changes.csv`: 20 independent, effective-dated profile changes for the SSIS history flow; UTF-16 LE CSV with BOM and CRLF.

The loader compares existing rows before inserting. A conflicting existing value raises an error and rolls back the transaction; it preserves existing work rather than silently updating it. Rerunning the same seed leaves counts and values unchanged. A different seed may conflict with existing rows and must be reviewed as a deliberate dataset change.

These CSVs are generated representations of the SQL operational source, not extra independent event feeds to double-count in the warehouse. The independent customer-change feed and the completion feed are implemented in the warehouse workflow. They contain separate change/completion events, not duplicate operational deposits.

## Validation evidence

Seven automated tests cover full-year coverage and fixture preservation, repeatable output bytes, duplicate transaction IDs, missing account references, invalid/nonpositive/extra-scale amounts, a missing calendar day, and valid historical changes with deposits on both sides of the change date.

The default source was loaded and rerun in SQL Server. Every field in every table was reconciled against its generated CSV. SQL counts, date coverage and amount totals match the generator summary. A deliberately conflicting existing branch was rejected inside a transaction; the original record was preserved after rollback.

To inspect the SQL result in SSMS:

```sql
USE BankingOLTP;

SELECT COUNT(*) AS deposit_count,
       MIN(transaction_date) AS first_date,
       MAX(transaction_date) AS last_date,
       SUM(amount) AS total_amount
FROM dbo.Deposit;
```

## Relationship to the warehouse

Completed: reproducible source generation, keys/relationships, positive decimal validation, year coverage, safe reruns and source reconciliation.

The separate SQL Server warehouse is implemented and loaded through SSIS. Its grain is one deposit, and Customer city history is preserved at transaction time. The main package loads SQL and customer-history CSV inputs; a separate package applies completion updates and handles unknown IDs. SQL source seeding here does not replace that SSIS ETL. See WAREHOUSE_HANDOVER.md for the end-to-end command and integration tests.

The four-row `deposit_example.py`/CSV exercise remains unchanged as an introductory example. Source generation, SQL constraints, deterministic tests, repeatable loading and Git history provide concrete software-engineering evidence for the project handover.
