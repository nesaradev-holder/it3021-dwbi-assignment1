import csv

with open("data/deposits.sample.csv", newline="", encoding="utf-8") as source:
    deposits = list(csv.DictReader(source))

seen_transaction_ids = set()

for deposit in deposits:
    transaction_id = deposit["transaction_id"]

    if transaction_id in seen_transaction_ids:
        raise ValueError(f"Duplicate transaction: {transaction_id}")

    seen_transaction_ids.add(transaction_id)

    amount = int(deposit["amount"])
    if amount <= 0:
        raise ValueError(f"Deposit amount must be positive: {transaction_id}")

totals = {}

for deposit in deposits:
    group = (
        deposit["transaction_branch_id"],
        deposit["transaction_date"][:7],
    )

    if group not in totals:
        totals[group] = 0

    totals[group] = totals[group] + int(deposit["amount"])

for group in totals:
    print(f"Branch: {group[0]} | Month: {group[1]} | Total: {totals[group]}")
