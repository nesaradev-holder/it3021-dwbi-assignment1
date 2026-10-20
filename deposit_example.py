import csv

with open("data/deposits.sample.csv", newline="", encoding="utf-8") as source:
    deposits = list(csv.DictReader(source))

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
