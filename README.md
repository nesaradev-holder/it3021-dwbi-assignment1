# Retail Banking Analytics Prototype

A self-directed DW/BI demonstration using synthetic retail-banking data. The project follows the technical topics in IT3021 Assignments 1 and 2 through one shared dataset and warehouse.

## Current stage

Planning and project setup. The data model and pipeline will be developed incrementally and validated at each milestone.

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
