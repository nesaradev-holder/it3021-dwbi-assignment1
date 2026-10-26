"""Build reproducible fictional OLTP sources; warehouse ETL remains SSIS work."""

import argparse
import csv
import json
import random
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parent
YEAR = 2026
SEED = 3021
CUSTOMER_COUNT = 200
ACCOUNT_COUNT = 400
DEPOSITS_PER_DAY = 20
COLUMNS = {
    "Branch": ("branch_id", "branch_name", "city"),
    "Customer": ("customer_id", "customer_name", "city"),
    "Account": ("account_id", "branch_id", "customer_id"),
    "Deposit": (
        "transaction_id", "account_id", "transaction_branch_id",
        "transaction_date", "amount",
    ),
}
FILENAMES = {
    "Branch": "branches.csv", "Customer": "customers.csv",
    "Account": "accounts.csv", "Deposit": "deposits.csv",
}


def create_dataset(seed=SEED):
    """Preserve the original fixture and add one complete synthetic calendar year."""
    rng = random.Random(seed)
    branches = [
        {"branch_id": "BR001", "branch_name": "Demo Piliyandala", "city": "Piliyandala"},
        {"branch_id": "BR002", "branch_name": "Demo Maharagama", "city": "Maharagama"},
    ]
    for number in range(3, 9):
        branches.append({
            "branch_id": f"BR{number:03d}",
            "branch_name": f"Demo Branch {number:02d}",
            "city": f"Demo City {number:02d}",
        })

    customers = [{
        "customer_id": "C001", "customer_name": "Demo Customer One", "city": "Piliyandala",
    }]
    for number in range(2, CUSTOMER_COUNT + 1):
        customers.append({
            "customer_id": f"C{number:03d}",
            "customer_name": f"Demo Customer {number:03d}",
            "city": rng.choice(branches)["city"],
        })

    accounts = [{"account_id": "98849932", "branch_id": "BR001", "customer_id": "C001"}]
    for number in range(2, ACCOUNT_COUNT + 1):
        customer = customers[number - 1] if number <= CUSTOMER_COUNT else rng.choice(customers)
        accounts.append({
            "account_id": f"A{number:07d}",
            "branch_id": branches[(number - 1) % len(branches)]["branch_id"],
            "customer_id": customer["customer_id"],
        })

    with (ROOT / "data" / "deposits.sample.csv").open(newline="", encoding="utf-8") as source:
        deposits = list(csv.DictReader(source))
    for deposit in deposits:
        deposit["amount"] = f"{Decimal(deposit['amount']):.2f}"

    current_day = date(YEAR, 1, 1)
    next_id = 1
    while current_day.year == YEAR:
        for _ in range(DEPOSITS_PER_DAY):
            account = rng.choice(accounts)
            branch_id = account["branch_id"]
            if rng.randrange(4) == 0:
                alternatives = [b["branch_id"] for b in branches if b["branch_id"] != branch_id]
                branch_id = rng.choice(alternatives)
            cents = rng.randint(10000, 5000000)
            deposits.append({
                "transaction_id": f"G{next_id:09d}",
                "account_id": account["account_id"],
                "transaction_branch_id": branch_id,
                "transaction_date": current_day.isoformat(),
                "amount": f"{Decimal(cents) / 100:.2f}",
            })
            next_id += 1
        current_day += timedelta(days=1)

    return {"Branch": branches, "Customer": customers, "Account": accounts, "Deposit": deposits}


def validate_dataset(dataset):
    """Reject invalid keys, references, money and incomplete calendar coverage."""
    key_sets = {}
    for table, columns in COLUMNS.items():
        keys = set()
        for row in dataset[table]:
            for column in columns:
                value = row.get(column)
                if not isinstance(value, str) or not value.strip():
                    raise ValueError(f"{table}.{column}: required text value is missing")
                if column.endswith("_id") and (len(value) > 10 or not value.isascii()):
                    raise ValueError(f"{table}.{column}: ID must fit VARCHAR(10)")
                if column in ("branch_name", "customer_name", "city") and len(value) > 100:
                    raise ValueError(f"{table}.{column}: text exceeds NVARCHAR(100)")
            key = row[columns[0]]
            if key in keys:
                raise ValueError(f"{table}: duplicate key {key}")
            keys.add(key)
        key_sets[table] = keys

    account_lookup = {row["account_id"]: row for row in dataset["Account"]}
    for account in dataset["Account"]:
        if account["customer_id"] not in key_sets["Customer"]:
            raise ValueError("Account: unknown customer_id")
        if account["branch_id"] not in key_sets["Branch"]:
            raise ValueError("Account: unknown home branch_id")

    days = set()
    total = Decimal("0.00")
    handled_elsewhere = 0
    for deposit in dataset["Deposit"]:
        if deposit["account_id"] not in key_sets["Account"]:
            raise ValueError("Deposit: unknown account_id")
        if deposit["transaction_branch_id"] not in key_sets["Branch"]:
            raise ValueError("Deposit: unknown handling branch")
        try:
            transaction_date = date.fromisoformat(deposit["transaction_date"])
        except ValueError as error:
            raise ValueError("Deposit: invalid calendar date") from error
        if transaction_date.year != YEAR or transaction_date.isoformat() != deposit["transaction_date"]:
            raise ValueError("Deposit: date must be ISO-formatted and inside the demo year")
        try:
            amount = Decimal(deposit["amount"])
            if (not amount.is_finite() or amount <= 0
                    or amount >= Decimal("10000000000000000")
                    or amount != amount.quantize(Decimal("0.01"))):
                raise ValueError("Deposit: amount must be positive and fit DECIMAL(18,2) exactly")
        except InvalidOperation as error:
            raise ValueError("Deposit: invalid decimal amount") from error
        days.add(transaction_date)
        total += amount
        home_branch = account_lookup[deposit["account_id"]]["branch_id"]
        handled_elsewhere += deposit["transaction_branch_id"] != home_branch

    required_days = {
        date(YEAR, 1, 1) + timedelta(days=offset)
        for offset in range((date(YEAR + 1, 1, 1) - date(YEAR, 1, 1)).days)
    }
    if days != required_days:
        raise ValueError("Deposit: every day of the demo year must be represented")
    if not handled_elsewhere:
        raise ValueError("Deposit: include handling branches different from account home branches")
    return {
        "year": YEAR, "row_counts": {table: len(rows) for table, rows in dataset.items()},
        "first_date": min(days).isoformat(), "last_date": max(days).isoformat(),
        "days_covered": len(days), "total_amount": f"{total:.2f}",
        "deposits_handled_elsewhere": handled_elsewhere,
        "amount_unit": "single synthetic currency unit; no FX conversion",
    }


def sql_literal(column, value):
    if column == "amount":
        return str(Decimal(value))
    return "N'" + value.replace("'", "''") + "'"


def write_source_load(dataset, path):
    """Append missing demo rows atomically; conflicting existing rows stop the load."""
    lines = [
        "-- Generated fictional OLTP source seed. Warehouse loading must use SSIS.",
        "USE BankingOLTP;", "SET NOCOUNT ON;", "SET XACT_ABORT ON;",
        "BEGIN TRY", "    BEGIN TRANSACTION;",
    ]
    for table, columns in COLUMNS.items():
        column_list = ", ".join(f"[{column}]" for column in columns)
        temp_table = f"#Demo{table}"
        lines.append(f"    SELECT TOP (0) {column_list} INTO {temp_table} FROM dbo.[{table}];")
        rows = dataset[table]
        for start in range(0, len(rows), 500):
            lines.append(f"    INSERT INTO {temp_table} ({column_list}) VALUES")
            values = [
                "        (" + ", ".join(sql_literal(c, row[c]) for c in columns) + ")"
                for row in rows[start:start + 500]
            ]
            lines.append(",\n".join(values) + ";")
        key = columns[0]
        differences = " OR ".join(f"CONVERT(varbinary(max), existing.[{c}]) <> CONVERT(varbinary(max), incoming.[{c}])" for c in columns)
        lines.extend([
            "    IF EXISTS (",
            f"        SELECT 1 FROM dbo.[{table}] AS existing",
            f"        INNER JOIN {temp_table} AS incoming ON existing.[{key}] = incoming.[{key}]",
            f"        WHERE {differences}", "    )",
            f"        THROW 51001, 'Conflicting existing {table} data; load rolled back without overwriting it.', 1;",
            f"    INSERT INTO dbo.[{table}] ({column_list})",
            "    SELECT " + ", ".join(f"incoming.[{c}]" for c in columns),
            f"    FROM {temp_table} AS incoming",
            f"    WHERE NOT EXISTS (SELECT 1 FROM dbo.[{table}] AS existing WHERE existing.[{key}] = incoming.[{key}]);",
        ])
    lines.extend([
        "    COMMIT TRANSACTION;", "END TRY", "BEGIN CATCH",
        "    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;", "    THROW;", "END CATCH;", "",
    ])
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")



def create_customer_changes(dataset):
    """Simulate external profile events, separate from the SQL base snapshot."""
    cities = [branch["city"] for branch in dataset["Branch"]]
    return [
        {"customer_id": customer["customer_id"],
         "city": cities[(cities.index(customer["city"]) + 1) % len(cities)],
         "effective_from": f"{YEAR}-07-01"}
        for customer in dataset["Customer"][:20]
    ]

def write_dataset(dataset, output, seed):
    summary = validate_dataset(dataset)
    output.mkdir(parents=True, exist_ok=True)
    for table, columns in COLUMNS.items():
        with (output / FILENAMES[table]).open("w", newline="", encoding="utf-8") as target:
            writer = csv.DictWriter(target, fieldnames=columns, lineterminator="\n")
            writer.writeheader()
            writer.writerows(dataset[table])
    changes = create_customer_changes(dataset)
    with (output / "customer_changes.csv").open("w", newline="", encoding="utf-16") as target:
        writer = csv.DictWriter(target, fieldnames=("customer_id", "city", "effective_from"), lineterminator="\r\n")
        writer.writeheader()
        writer.writerows(changes)
    summary["customer_change_rows"] = len(changes)
    write_source_load(dataset, output / "load_demo_sources.sql")
    summary["seed"] = seed
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--output", type=Path, default=ROOT / "data" / "generated")
    args = parser.parse_args()
    summary = write_dataset(create_dataset(args.seed), args.output, args.seed)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
