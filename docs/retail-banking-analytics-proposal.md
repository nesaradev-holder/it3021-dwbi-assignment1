# Retail Banking Analytics Prototype

## Proposed delivery and learning plan

Purpose: Build a reproducible banking analytics demonstration and a manager-facing explanation of how data becomes reliable information. The project uses synthetic data and develops practical skills across programming, databases, data integration and business intelligence.

Status: Proposed plan. Course materials have been reviewed and local Git has been initialized; application and data-pipeline implementation are pending.

## Initial scope

The proposed core entities are Customer, Account, Branch and Transaction. Prepare meaningful sample records covering about one year, with a SQL source and a file-based source. Final entity details and source allocation will be settled through the first design exercise.

Candidate questions: How do deposit totals and transaction counts vary by branch and month? How does activity differ by account type? Which simulated transactions are pending, and how long do completed transactions take?

## System path

Synthetic operational sources -> SSIS extraction and staging -> SQL Server data warehouse -> SSAS cube and Excel analysis. Power BI provides interactive reports and a Service demonstration using a suitable warehouse/cube connection.

## Delivery milestones

| Stage | Focus | Evidence before proceeding |
|---|---|---|
| 1 | Define scope and source model | Business questions, ERD, field definitions and explicit assumptions. |
| 2 | Prepare reproducible source data | Small Python generator, SQL/file sources and valid relationships. |
| 3 | Build the warehouse model | Declared grain, useful measures/dimensions, Date and dimension-history design in SQL Server. |
| 4 | Develop SSIS integration | Verified source-to-staging-to-warehouse flows, lookups and error handling. |
| 5 | Demonstrate completion updates | Separate update input/package, matched IDs, correct durations and missing-ID handling. |
| 6 | Create the cube and Excel analysis | Working SSAS cube, hierarchy and five demonstrated OLAP operations. |
| 7 | Deliver reports and handover | Matrix, cascading filters, drill-down and drill-through in Power BI; Service demonstration and concise report. |

## Technology responsibilities

Python prepares synthetic data and independent checks. SQL Server stores and validates the warehouse. SSIS performs the ETL and completion updates. SSAS supplies the cube, Excel demonstrates analytical operations, and Power BI presents interactive reports. Git/GitHub records reviewed implementation milestones.

## Quality and handover

Reconcile counts and amounts across layers; validate key relationships, history changes, rejected rows, completion matching and elapsed time. Check that report filters and drill actions preserve the intended context. Capture reproducible build steps and a small set of meaningful screenshots.

Expected handover: source-generation instructions, mappings, schema scripts, SSIS packages, cube project, Excel workbook, Power BI reports, validation results and an executive summary. This is a synthetic demonstration; production requirements would be defined separately.

Progress through verified milestones rather than a fixed deadline schedule. Use the same warehouse throughout the project, completing its integration and validation before extending the analytics layer.
