# Vehicle Rental & Fleet Management System

An enterprise-grade DBMS project designed to manage vehicle rental operations across multiple branches. The system uses a relational database to manage vehicles, customers, bookings, drivers, payments, maintenance, and penalties.

## Project Overview

The Vehicle Rental & Fleet Management System provides a centralized database for managing rental operations efficiently.

It helps administrators maintain vehicle records, manage customer bookings, track payments, assign drivers, and monitor vehicle maintenance.

## Features

- Multi-branch vehicle management
- Customer registration and management
- Customer phone number management
- Vehicle booking and rental management
- Driver assignment
- Payment tracking
- Vehicle maintenance records
- Penalty management
- Automated database operations using triggers
- Stored procedures and functions
- Transaction management and savepoints
- Database indexing and query optimization
- Role-based access control

## Database Design

The database consists of the following nine relations:

| Table | Description |
|---|---|
| BRANCH | Stores branch details |
| VEHICLE | Stores vehicle information |
| DRIVER | Stores driver details |
| CUSTOMER | Stores customer information |
| CUSTOMER_PHONE | Stores customer contact numbers |
| BOOKING | Stores vehicle booking details |
| PAYMENT | Stores payment transactions |
| MAINTENANCE | Stores vehicle maintenance records |
| PENALTY | Stores penalties associated with bookings |

## DBMS Concepts Implemented

- Entity Relationship (ER) Model
- Relational Database Model
- Primary and Foreign Keys
- Integrity Constraints
- Functional Dependencies
- Normalization up to BCNF
- SQL Joins and Subqueries
- Views
- Stored Procedures
- Functions
- Triggers
- Cursors
- Transactions
- Commit and Rollback
- Savepoints
- Indexing
- Query Execution Plans
- Role-Based Access Control

## Technologies Used

| Technology | Purpose |
|---|---|
| MySQL / PostgreSQL | Relational database management |
| SQL | Database operations |
| Python | Application development |
| Streamlit | User interface |
| MySQL Connector / Database Driver | Database connectivity |

## Project Structure

```text
vehicle-fleet-management/
│
├── README.md
├── database/
│   ├── schema.sql
│   └── queries.sql
│
├── application/
│   ├── app.py
│   └── db_connection.py
│
└── documentation/
    └── project_report.pdf
```

*Note: This is a suggested structure. Actual filenames may differ.*

## Installation and Setup

### 1. Clone the Repository

```bash
git clone https://github.com/dhanushkoti-55/vehicle-fleet-management.git
```

### 2. Navigate to the Project Directory

```bash
cd vehicle-fleet-management
```

### 3. Set Up the Database

- Install MySQL or PostgreSQL.
- Create the project database.
- Execute the SQL schema file.
- Execute the required SQL queries and database objects.

### 4. Install Python Dependencies

```bash
pip install streamlit mysql-connector-python
```

Install any additional dependencies required by the application.

### 5. Configure Database Connection

Update the database connection details in the application's configuration file.

Do not upload database passwords or other sensitive credentials to GitHub.

### 6. Run the Application

```bash
streamlit run app.py
```

## Project Objectives

1. Design a centralized relational database for vehicle rental operations.
2. Maintain accurate records of vehicles, customers, and bookings.
3. Manage payments, penalties, and maintenance activities.
4. Implement database constraints to maintain data integrity.
5. Apply normalization to reduce data redundancy.
6. Use SQL programming concepts to automate database operations.
7. Improve query performance through indexing and optimization.

## Project Team

- **Inderdeep Singh**
- **M. Dhanush Koti**

**Institution:** Vellore Institute of Technology (VIT), Vellore

**School:** School of Computer Science Engineering and Information Systems

**Academic Year:** 2026–2027

## Repository

[Vehicle Rental & Fleet Management System – GitHub](https://github.com/dhanushkoti-55/vehicle-fleet-management)

---

**Project:** Vehicle Rental & Fleet Management System  
**Domain:** Database Management Systems (DBMS)
