from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


def read_file(path):
    return (ROOT / path).read_text(encoding="utf-8")


class ProjectContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = read_file("database/schema.sql")
        cls.routines = read_file("database/routines.sql")
        cls.security = read_file("database/security.sql")
        cls.app = read_file("application/app.py")

    def test_schema_contains_exactly_nine_relations(self):
        tables = re.findall(r"CREATE TABLE\s+([A-Z_]+)", self.schema, re.IGNORECASE)
        self.assertEqual(len(tables), 9)
        self.assertEqual(
            {name.upper() for name in tables},
            {
                "BRANCH", "VEHICLE", "DRIVER", "CUSTOMER", "CUSTOMER_PHONE",
                "BOOKING", "PAYMENT", "MAINTENANCE", "PENALTY",
            },
        )

    def test_report_views_are_present(self):
        for view in (
            "vw_booking_amount",
            "vw_available_fleet",
            "vw_customer_total_spent",
            "vw_vehicle_utilization",
        ):
            self.assertIn(view, self.schema)

    def test_procedures_and_function_are_present(self):
        for routine in (
            "fn_calculate_overdue_penalty",
            "sp_create_rental_booking",
            "sp_record_payment",
            "sp_log_maintenance",
            "sp_list_overdue_bookings",
        ):
            self.assertIn(routine, self.routines)

    def test_triggers_are_present(self):
        for trigger in (
            "trg_before_booking_insert",
            "trg_after_booking_insert",
            "trg_after_booking_update",
            "trg_before_maintenance_insert",
            "trg_after_maintenance_insert",
        ):
            self.assertIn(trigger, self.routines)

    def test_transaction_and_savepoint_examples_exist(self):
        self.assertIn("FOR UPDATE", self.routines)
        self.assertIn("START TRANSACTION", self.routines)
        self.assertIn("ROLLBACK", self.routines)
        self.assertIn("COMMIT", self.routines)
        self.assertIn("SAVEPOINT", read_file("database/transaction_examples.sql"))

    def test_database_roles_are_defined(self):
        for role in (
            "rental_clerk_role",
            "fleet_manager_role",
            "workshop_supervisor_role",
            "customer_portal_role",
        ):
            self.assertIn(role, self.security)

    def test_app_uses_parameterized_queries_and_procedures(self):
        self.assertIn("call_procedure(", self.app)
        self.assertIn("execute_query(", self.app)
        self.assertIn("VALUES (%s", self.app)


if __name__ == "__main__":
    unittest.main()
