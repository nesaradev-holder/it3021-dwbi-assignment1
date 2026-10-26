"""Checks for reproducibility and meaningful source-data failure cases."""

import copy
import csv
import hashlib
import tempfile
import unittest
from pathlib import Path
from decimal import Decimal

from generate_demo_data import ROOT, create_dataset, create_customer_changes, validate_dataset, write_dataset


class DemoDatasetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dataset = create_dataset()

    def test_covers_year_and_preserves_fixture(self):
        summary = validate_dataset(self.dataset)
        self.assertEqual(summary["days_covered"], 365)
        self.assertEqual(summary["row_counts"], {
            "Branch": 8, "Customer": 200, "Account": 400, "Deposit": 7304,
        })
        deposits = {row["transaction_id"]: row for row in self.dataset["Deposit"]}
        with (ROOT / "data" / "deposits.sample.csv").open(newline="", encoding="utf-8") as source:
            for fixture in csv.DictReader(source):
                actual = deposits[fixture["transaction_id"]]
                for column in fixture:
                    if column != "amount":
                        self.assertEqual(actual[column], fixture[column])
                self.assertEqual(Decimal(actual["amount"]), Decimal(fixture["amount"]))

    def test_history_events_have_valid_changed_values_and_observable_dates(self):
        changes = create_customer_changes(self.dataset)
        customers = {row["customer_id"]: row for row in self.dataset["Customer"]}
        pairs = {(row["customer_id"], row["effective_from"]) for row in changes}
        self.assertEqual(len(changes), len(pairs))
        for change in changes:
            self.assertIn(change["customer_id"], customers)
            self.assertNotEqual(change["city"], customers[change["customer_id"]]["city"])
            self.assertEqual(change["effective_from"], "2026-07-01")
        account_ids = {a["account_id"] for a in self.dataset["Account"] if a["customer_id"] == "C001"}
        dates = [d["transaction_date"] for d in self.dataset["Deposit"] if d["account_id"] in account_ids]
        self.assertTrue(any(value < "2026-07-01" for value in dates))
        self.assertTrue(any(value >= "2026-07-01" for value in dates))

    def test_same_seed_writes_identical_files(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            write_dataset(self.dataset, Path(first), 3021)
            write_dataset(create_dataset(), Path(second), 3021)
            for path in Path(first).iterdir():
                self.assertEqual(
                    hashlib.sha256(path.read_bytes()).digest(),
                    hashlib.sha256((Path(second) / path.name).read_bytes()).digest(),
                )

    def test_missing_account_reference_is_rejected(self):
        invalid = copy.deepcopy(self.dataset)
        invalid["Deposit"][0]["account_id"] = "MISSING"
        with self.assertRaisesRegex(ValueError, "unknown account_id"):
            validate_dataset(invalid)

    def test_duplicate_transaction_is_rejected(self):
        invalid = copy.deepcopy(self.dataset)
        invalid["Deposit"].append(dict(invalid["Deposit"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate key"):
            validate_dataset(invalid)

    def test_nonpositive_and_extra_scale_amounts_are_rejected(self):
        for amount in ("0", "-1", "12.345", "NaN", "Infinity"):
            with self.subTest(amount=amount):
                invalid = copy.deepcopy(self.dataset)
                invalid["Deposit"][0]["amount"] = amount
                with self.assertRaises(ValueError):
                    validate_dataset(invalid)

    def test_incomplete_year_is_rejected(self):
        invalid = copy.deepcopy(self.dataset)
        invalid["Deposit"] = [r for r in invalid["Deposit"] if r["transaction_date"] != "2026-03-02"]
        with self.assertRaisesRegex(ValueError, "every day"):
            validate_dataset(invalid)


if __name__ == "__main__":
    unittest.main()
