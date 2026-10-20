# Retail Banking Analytics Prototype

A self-directed DW/BI demonstration using synthetic retail-banking data. The project follows the technical topics in IT3021 Assignments 1 and 2 through one shared dataset and warehouse.

## Current stage

Project setup and the first small Python example are complete. The data model and pipeline will be developed incrementally and validated at each milestone.

## First Python example

[deposit_example.py](deposit_example.py) reads four fictional deposits from a CSV into a list of dictionaries and uses a loop with branch and month conditions to print the selected total. It is an introductory example; it does not connect to a database or generate a dataset.

Run from the project root on Windows with Python 3 installed:

    py -3 .\deposit_example.py

Set selected_branch and selected_month above the loop to choose the report selection.

Expected output with the current settings:

    Branch: BR002 | Month: 2026-11 | Total: 3750

The total is 3000 + 750. Both the branch and year-month must match; the October deposits are excluded. Dates are known ISO-formatted text in this introductory example.

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
