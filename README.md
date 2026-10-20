# Retail Banking Analytics Prototype

A self-directed DW/BI demonstration using synthetic retail-banking data. The project follows the technical topics in IT3021 Assignments 1 and 2 through one shared dataset and warehouse.

## Current stage

Project setup and the first small Python example are complete. The data model and pipeline will be developed incrementally and validated at each milestone.

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
