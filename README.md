# Vehicle Rental & Fleet Management System

A MySQL 8.0 and Python/Streamlit DBMS project for multi-branch vehicle rental operations. It manages branches, vehicles, drivers, customers, bookings, payment installments, maintenance, and late-return penalties.

## Features

- Nine normalized relations with primary keys, foreign keys, unique constraints and CHECK constraints
- Multi-branch vehicle and driver records
- Customer profiles with multiple phone numbers in a separate relation
- Transaction-safe vehicle booking with row locking
- Dynamic rental billing based on vehicle category and driver selection
- Multiple payment installments and outstanding balance calculation
- Automatic vehicle status synchronization
- Automatic ₹300-per-day late-return penalties
- Maintenance logging and vehicle status locks
- Stored procedures, a user-defined function, triggers and a cursor
- Views for booking totals, available fleet, customer spending and utilization
- Indexes and EXPLAIN query plans
- MySQL roles for least-privilege access
- Streamlit dashboard for day-to-day operations

## Repository structure

```text
vehicle-fleet-management/
├── application/
│   ├── app.py
│   └── db_connection.py
├── database/
│   ├── schema.sql
│   ├── routines.sql
│   ├── seed.sql
│   ├── queries.sql
│   ├── security.sql
│   ├── transaction_examples.sql
│   ├── validate.sql
│   ├── demo_outputs.sql
│   └── demo_workflows.sql
├── documentation/
│   └── Vehicle_Rental_DBMS_Project_Report.pdf
├── tests/
│   └── test_project_contract.py
├── .streamlit/
│   └── secrets.toml.example
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── README.md
```

## 1. Database setup using MySQL Workbench

Use MySQL Server 8.0. Open MySQL Workbench and connect to your local MySQL server.

Run the SQL files in this order:

1. `database/schema.sql` — creates the database, nine tables, indexes and views. **This script drops and recreates the project tables. Do not run it on data you need to keep.**
2. `database/routines.sql` — creates the stored procedures, function and triggers.
3. `database/seed.sql` — inserts sample branches, vehicles, drivers, customers, bookings, payments and maintenance records.
4. `database/validate.sql` — checks that the required tables, views, procedures, triggers and sample workflows exist.
5. `database/demo_outputs.sql` — runs read-only SELECT queries to display the project outputs.

To demonstrate actual business logic, run `database/demo_workflows.sql` after the setup. It creates a demonstration booking, records a payment, processes a late return, shows the generated penalty, logs maintenance and restores the vehicle. It inserts records into the database, so do not run it repeatedly unless you want additional demo records.

Run `database/transaction_examples.sql` to demonstrate transaction control and SAVEPOINT rollback.

Run `database/queries.sql` for the SQL query catalog covering filtering, grouping, joins, subqueries, views, UNION and EXPLAIN.

Run `database/security.sql` only as a MySQL administrator. It creates database roles and grants role permissions. The example user-creation statements are commented; replace the example password with a unique secret before creating real database accounts.

## 2. Run the Streamlit application locally

Create a virtual environment and install dependencies:

```bash
python -m venv .venv
```

Windows:

```powershell
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

macOS/Linux:

```bash
source .venv/bin/activate
pip install -r requirements.txt
```

Create `.streamlit/secrets.toml` using `.streamlit/secrets.toml.example`:

```toml
[mysql]
host = "127.0.0.1"
port = 3306
user = "YOUR_DATABASE_USERNAME"
password = "YOUR_DATABASE_PASSWORD"
database = "vehicle_fleet_db"
```

Alternatively, configure the environment variables `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` and `DB_NAME`.

Start Streamlit from the repository root:

```bash
streamlit run application/app.py
```

## 3. Run with Docker Compose

Copy `.env.example` to `.env`, then set a strong local MySQL password in `.env`. Start both services:

```bash
docker compose up --build
```

Open `http://localhost:8501`.

The MySQL container runs the schema, routines and seed scripts on the first initialization of its data volume. If you change the initialization SQL and need a completely fresh local database, remove the local volume only after confirming that you do not need its data:

```bash
docker compose down -v
docker compose up --build
```

## 4. Streamlit Community Cloud deployment

1. Push the project branch or merge it into the branch you intend to deploy.
2. Create a Streamlit app and select `application/app.py` as the main file.
3. Provision a MySQL 8.0 database that is reachable from the deployed application.
4. In the Streamlit app settings, add the connection details under **Secrets**:

```toml
[mysql]
host = "YOUR_MANAGED_MYSQL_HOST"
port = 3306
user = "YOUR_DATABASE_USERNAME"
password = "YOUR_DATABASE_PASSWORD"
database = "vehicle_fleet_db"
```

5. Initialize the remote database by running `schema.sql`, `routines.sql` and `seed.sql` against that MySQL server.
6. Redeploy the app.

Streamlit Community Cloud does not create or host the MySQL database from the SQL files. The database must be provisioned separately. Never commit real database credentials, `.env`, or `.streamlit/secrets.toml` to GitHub.

## 5. Test the project files

From the repository root:

```bash
python -m unittest discover -s tests -v
```

The tests check the repository's expected database objects and application integration. They do not replace running the SQL scripts against a live MySQL 8.0 server.

## 6. Useful demonstration sequence

For a DBMS project review, this sequence gives visible outputs:

1. Run `schema.sql`, `routines.sql` and `seed.sql`.
2. Run `validate.sql` and show the validation result.
3. Run `demo_outputs.sql` and show the result grids for the nine relations, joins, views, aggregate queries and query plan.
4. Run `demo_workflows.sql` and show the generated booking ID, calculated total, payment balance, late penalty, and vehicle status changes.
5. Start Streamlit and demonstrate the Dashboard, Vehicles, Customers, Bookings, Payments, Maintenance, Penalties and Reports sections.

## Project team

- Inderdeep Singh
- M. Dhanush Koti

Vellore Institute of Technology, Vellore  
School of Computer Science Engineering and Information Systems  
Academic Year: 2026–2027
