deposits = [
    {
        "transaction_id": "2005583029",
        "account_id": "98849932",
        "transaction_branch_id": "BR001",
        "transaction_date": "2026-10-19",
        "amount": 2500,
    },
    {
        "transaction_id": "2005583030",
        "account_id": "98849932",
        "transaction_branch_id": "BR002",
        "transaction_date": "2026-10-19",
        "amount": 2000,
    },
    {
        "transaction_id": "2005583031",
        "account_id": "98849932",
        "transaction_branch_id": "BR002",
        "transaction_date": "2026-11-05",
        "amount": 3000,
    },
    {
        "transaction_id": "2005583032",
        "account_id": "98849932",
        "transaction_branch_id": "BR002",
        "transaction_date": "2026-11-20",
        "amount": 500,
    },
]
selected_branch = "BR002"
selected_month = "2026-11"
total = 0

for deposit in deposits:
    if (
        deposit["transaction_branch_id"] == selected_branch
        and deposit["transaction_date"][:7] == selected_month
    ):
        total = total + deposit["amount"]

print(f"Branch: {selected_branch} | Month: {selected_month} | Total: {total}")
