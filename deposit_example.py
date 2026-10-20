import csv

with open("data/deposits.sample.csv", newline="", encoding="utf-8") as source:
    deposits = list(csv.DictReader(source))

seen_transaction_ids = set()

for deposit in deposits:
    transaction_id = deposit["transaction_id"]

    if transaction_id in seen_transaction_ids:
        raise ValueError(f"Duplicate transaction: {transaction_id}")

    seen_transaction_ids.add(transaction_id)

selected_branch = "BR002"
selected_month = "2026-11"
total = 0

for deposit in deposits:
    if (
        deposit["transaction_branch_id"] == selected_branch
        and deposit["transaction_date"][:7] == selected_month
    ):
        total = total + int(deposit["amount"])

print(f"Branch: {selected_branch} | Month: {selected_month} | Total: {total}")
