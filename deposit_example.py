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
]

total = 0

for deposit in deposits:
    if deposit["transaction_branch_id"] == "BR002":
        total = total + deposit["amount"]

print(total)
