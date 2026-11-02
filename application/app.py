from datetime import date, timedelta
from decimal import Decimal

import mysql.connector
import streamlit as st

from db_connection import call_procedure, execute_query, fetch_data, get_connection


st.set_page_config(
    page_title="Vehicle Rental & Fleet Management",
    page_icon="🚗",
    layout="wide",
)

st.title("Vehicle Rental & Fleet Management System")
st.caption("Multi-branch fleet, booking, payment and maintenance management")


def money(value):
    return f"₹{Decimal(str(value or 0)):,.2f}"


def report_error(error):
    st.error(str(error))


try:
    connection = get_connection()
    connection.close()
except mysql.connector.Error as error:
    st.error(f"Database connection failed: {error}")
    st.info(
        "Create the MySQL database and run database/schema.sql, "
        "database/routines.sql and database/seed.sql in that order. "
        "Then configure the [mysql] connection settings."
    )
    st.stop()


page = st.sidebar.radio(
    "Navigation",
    [
        "Dashboard",
        "Vehicles",
        "Customers",
        "Drivers",
        "Bookings",
        "Create Booking",
        "Payments",
        "Maintenance",
        "Penalties",
        "Reports",
    ],
)
st.sidebar.divider()
st.sidebar.caption("Database access is controlled by the MySQL account and its assigned role.")


if page == "Dashboard":
    st.header("Dashboard")

    metrics = [
        ("Vehicles", "SELECT COUNT(*) AS value FROM VEHICLE"),
        ("Available", "SELECT COUNT(*) AS value FROM VEHICLE WHERE status = 'Available'"),
        ("Customers", "SELECT COUNT(*) AS value FROM CUSTOMER"),
        ("Bookings", "SELECT COUNT(*) AS value FROM BOOKING"),
        ("Payments", "SELECT COALESCE(SUM(amount), 0) AS value FROM PAYMENT"),
        ("Penalties", "SELECT COALESCE(SUM(penalty_amount), 0) AS value FROM PENALTY"),
    ]
    for start in range(0, len(metrics), 3):
        cols = st.columns(3)
        for col, (label, query) in zip(cols, metrics[start:start + 3]):
            value = fetch_data(query).iloc[0]["value"]
            display = money(value) if label in {"Payments", "Penalties"} else f"{int(value):,}"
            col.metric(label, display)

    left, right = st.columns(2)
    with left:
        st.subheader("Fleet status")
        status_data = fetch_data(
            "SELECT status, COUNT(*) AS vehicles FROM VEHICLE GROUP BY status"
        )
        if not status_data.empty:
            st.bar_chart(status_data.set_index("status"))
        else:
            st.info("No vehicles have been registered.")

    with right:
        st.subheader("Fleet by category")
        category_data = fetch_data(
            "SELECT category, COUNT(*) AS vehicles FROM VEHICLE GROUP BY category"
        )
        if not category_data.empty:
            st.bar_chart(category_data.set_index("category"))
        else:
            st.info("No vehicle categories are available.")

    st.subheader("Recent bookings")
    recent = fetch_data(
        """
        SELECT b.booking_id,
               CONCAT(c.first_name, ' ', c.last_name) AS customer,
               v.reg_number,
               CONCAT(v.brand, ' ', v.model) AS vehicle,
               b.start_date,
               b.due_date,
               b.booking_status
        FROM BOOKING b
        JOIN CUSTOMER c ON c.customer_id = b.customer_id
        JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
        ORDER BY b.booking_id DESC
        LIMIT 10
        """
    )
    st.dataframe(recent, use_container_width=True, hide_index=True)


elif page == "Vehicles":
    st.header("Vehicle inventory")

    status_filter = st.selectbox(
        "Status",
        ["All", "Available", "Rented", "Maintenance"],
    )
    query = """
        SELECT v.vehicle_id, v.reg_number, v.category, v.brand, v.model,
               v.base_rate, v.status, br.branch_name, br.city
        FROM VEHICLE v
        JOIN BRANCH br ON br.branch_id = v.branch_id
    """
    params = ()
    if status_filter != "All":
        query += " WHERE v.status = %s"
        params = (status_filter,)
    query += " ORDER BY v.vehicle_id DESC"
    st.dataframe(fetch_data(query, params), use_container_width=True, hide_index=True)

    with st.expander("Register a vehicle"):
        branches = fetch_data(
            "SELECT branch_id, branch_name, city FROM BRANCH ORDER BY branch_name"
        )
        if branches.empty:
            st.warning("Create a branch record in the database before registering vehicles.")
        else:
            branch_options = {
                f"{row.branch_name} — {row.city} (ID {row.branch_id})": int(row.branch_id)
                for row in branches.itertuples()
            }
            with st.form("vehicle_form"):
                registration = st.text_input("Registration number").strip().upper()
                category = st.selectbox("Category", ["Economy", "Sedan", "SUV", "Luxury"])
                brand = st.text_input("Brand")
                model = st.text_input("Model")
                branch_label = st.selectbox("Branch", list(branch_options))
                base_rate = st.number_input("Daily base rate (₹)", min_value=1.0, step=100.0)
                submitted = st.form_submit_button("Add vehicle")

                if submitted:
                    if not all([registration, brand.strip(), model.strip()]):
                        st.error("Registration number, brand and model are required.")
                    else:
                        try:
                            execute_query(
                                """
                                INSERT INTO VEHICLE
                                    (reg_number, category, brand, model, branch_id, base_rate)
                                VALUES (%s, %s, %s, %s, %s, %s)
                                """,
                                (
                                    registration,
                                    category,
                                    brand.strip(),
                                    model.strip(),
                                    branch_options[branch_label],
                                    Decimal(str(base_rate)),
                                ),
                            )
                            st.success("Vehicle registered.")
                            st.rerun()
                        except mysql.connector.Error as error:
                            report_error(error)


elif page == "Customers":
    st.header("Customer records")
    customers = fetch_data(
        """
        SELECT c.customer_id, c.first_name, c.last_name, c.email, c.license_no,
               COALESCE(GROUP_CONCAT(cp.phone_number ORDER BY cp.phone_number SEPARATOR ', '), '') AS phone_numbers
        FROM CUSTOMER c
        LEFT JOIN CUSTOMER_PHONE cp ON cp.customer_id = c.customer_id
        GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.license_no
        ORDER BY c.customer_id DESC
        """
    )
    st.dataframe(customers, use_container_width=True, hide_index=True)

    with st.expander("Register a customer"):
        with st.form("customer_form"):
            first_name = st.text_input("First name").strip()
            last_name = st.text_input("Last name").strip()
            email = st.text_input("Email").strip().lower()
            license_no = st.text_input("Driving licence number").strip().upper()
            phone_numbers = st.text_input("Phone numbers (comma-separated)")
            submitted = st.form_submit_button("Register customer")

            if submitted:
                if not all([first_name, last_name, email, license_no]):
                    st.error("Name, email and driving licence number are required.")
                else:
                    phones = list(dict.fromkeys(
                        phone.strip() for phone in phone_numbers.split(",") if phone.strip()
                    ))
                    connection = None
                    cursor = None
                    try:
                        connection = get_connection()
                        cursor = connection.cursor()
                        cursor.execute(
                            """
                            INSERT INTO CUSTOMER (first_name, last_name, email, license_no)
                            VALUES (%s, %s, %s, %s)
                            """,
                            (first_name, last_name, email, license_no),
                        )
                        customer_id = cursor.lastrowid
                        if phones:
                            cursor.executemany(
                                """
                                INSERT INTO CUSTOMER_PHONE (customer_id, phone_number)
                                VALUES (%s, %s)
                                """,
                                [(customer_id, phone) for phone in phones],
                            )
                        connection.commit()
                        st.success(f"Customer registered. Customer ID: {customer_id}")
                        st.rerun()
                    except mysql.connector.Error as error:
                        if connection:
                            connection.rollback()
                        report_error(error)
                    finally:
                        if cursor:
                            cursor.close()
                        if connection:
                            connection.close()


elif page == "Drivers":
    st.header("Driver roster")
    drivers = fetch_data(
        """
        SELECT d.driver_id, d.driver_name, d.license_no, d.rating,
               br.branch_name, br.city
        FROM DRIVER d
        JOIN BRANCH br ON br.branch_id = d.branch_id
        ORDER BY d.driver_id DESC
        """
    )
    st.dataframe(drivers, use_container_width=True, hide_index=True)

    with st.expander("Register a driver"):
        branches = fetch_data(
            "SELECT branch_id, branch_name, city FROM BRANCH ORDER BY branch_name"
        )
        if branches.empty:
            st.warning("Create a branch record before registering drivers.")
        else:
            branch_options = {
                f"{row.branch_name} — {row.city} (ID {row.branch_id})": int(row.branch_id)
                for row in branches.itertuples()
            }
            with st.form("driver_form"):
                name = st.text_input("Driver name").strip()
                licence = st.text_input("Driver licence number").strip().upper()
                rating = st.number_input("Rating", min_value=1.0, max_value=5.0, value=5.0, step=0.1)
                branch_label = st.selectbox("Branch", list(branch_options))
                submitted = st.form_submit_button("Add driver")

                if submitted:
                    if not name or not licence:
                        st.error("Driver name and licence number are required.")
                    else:
                        try:
                            execute_query(
                                """
                                INSERT INTO DRIVER (driver_name, license_no, branch_id, rating)
                                VALUES (%s, %s, %s, %s)
                                """,
                                (name, licence, branch_options[branch_label], Decimal(str(rating))),
                            )
                            st.success("Driver registered.")
                            st.rerun()
                        except mysql.connector.Error as error:
                            report_error(error)


elif page == "Bookings":
    st.header("Booking records")
    booking_status = st.selectbox(
        "Booking status",
        ["All", "Pending", "Active", "Completed", "Cancelled"],
    )
    booking_query = """
        SELECT b.booking_id,
               CONCAT(c.first_name, ' ', c.last_name) AS customer,
               v.reg_number,
               CONCAT(v.brand, ' ', v.model) AS vehicle,
               COALESCE(d.driver_name, 'Self-Drive') AS driver,
               b.start_date,
               b.due_date,
               b.return_date,
               b.booking_status,
               ba.total_amount,
               COALESCE(pay.total_paid, 0.00) AS total_paid,
               ROUND(ba.total_amount - COALESCE(pay.total_paid, 0.00), 2) AS balance_due
        FROM BOOKING b
        JOIN CUSTOMER c ON c.customer_id = b.customer_id
        JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
        LEFT JOIN DRIVER d ON d.driver_id = b.driver_id
        JOIN vw_booking_amount ba ON ba.booking_id = b.booking_id
        LEFT JOIN (
            SELECT booking_id, SUM(amount) AS total_paid
            FROM PAYMENT
            GROUP BY booking_id
        ) pay ON pay.booking_id = b.booking_id
    """
    params = ()
    if booking_status != "All":
        booking_query += " WHERE b.booking_status = %s"
        params = (booking_status,)
    booking_query += " ORDER BY b.booking_id DESC"
    st.dataframe(fetch_data(booking_query, params), use_container_width=True, hide_index=True)

    st.divider()
    st.subheader("Process a vehicle return")
    active = fetch_data(
        """
        SELECT b.booking_id, b.start_date,
               CONCAT('Booking ', b.booking_id, ' — ', c.first_name, ' ', c.last_name,
                      ' — ', v.reg_number) AS label
        FROM BOOKING b
        JOIN CUSTOMER c ON c.customer_id = b.customer_id
        JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
        WHERE b.booking_status = 'Active'
        ORDER BY b.due_date
        """
    )
    if active.empty:
        st.info("There are no active bookings to return.")
    else:
        labels = {
            row.label: (int(row.booking_id), row.start_date)
            for row in active.itertuples()
        }
        with st.form("return_form"):
            selected = st.selectbox("Active booking", list(labels))
            return_date = st.date_input(
                "Actual return date",
                value=date.today(),
                min_value=labels[selected][1],
            )
            submitted = st.form_submit_button("Complete booking")

            if submitted:
                try:
                    execute_query(
                        """
                        UPDATE BOOKING
                        SET return_date = %s, booking_status = 'Completed'
                        WHERE booking_id = %s AND booking_status = 'Active'
                        """,
                        (return_date, labels[selected][0]),
                    )
                    penalty = fetch_data(
                        """
                        SELECT COALESCE(SUM(penalty_amount), 0.00) AS total
                        FROM PENALTY WHERE booking_id = %s
                        """,
                        (labels[selected][0],),
                    ).iloc[0]["total"]
                    st.success(f"Booking completed. Late-return penalty: {money(penalty)}")
                    st.rerun()
                except mysql.connector.Error as error:
                    report_error(error)


elif page == "Create Booking":
    st.header("Create a rental booking")
    customers = fetch_data(
        "SELECT customer_id, first_name, last_name FROM CUSTOMER ORDER BY first_name, last_name"
    )
    vehicles = fetch_data(
        """
        SELECT vehicle_id, reg_number, brand, model, category, base_rate
        FROM VEHICLE
        WHERE status = 'Available'
        ORDER BY reg_number
        """
    )
    drivers = fetch_data(
        "SELECT driver_id, driver_name FROM DRIVER ORDER BY driver_name"
    )

    if customers.empty:
        st.warning("Register a customer before creating a booking.")
    elif vehicles.empty:
        st.warning("There are no available vehicles.")
    else:
        customer_options = {
            f"{row.first_name} {row.last_name} (ID {row.customer_id})": int(row.customer_id)
            for row in customers.itertuples()
        }
        vehicle_options = {
            f"{row.reg_number} — {row.brand} {row.model} — {row.category} — {money(row.base_rate)}/day":
                int(row.vehicle_id)
            for row in vehicles.itertuples()
        }
        driver_options = {"Self-drive": None}
        driver_options.update({
            f"{row.driver_name} (ID {row.driver_id})": int(row.driver_id)
            for row in drivers.itertuples()
        })

        with st.form("booking_form"):
            customer_label = st.selectbox("Customer", list(customer_options))
            vehicle_label = st.selectbox("Vehicle", list(vehicle_options))
            driver_label = st.selectbox("Driver", list(driver_options))
            start_date = st.date_input("Start date", value=date.today())
            due_date = st.date_input(
                "Due date",
                value=date.today() + timedelta(days=2),
                min_value=start_date,
            )
            submitted = st.form_submit_button("Confirm booking")

            if submitted:
                try:
                    result = call_procedure(
                        "sp_create_rental_booking",
                        [
                            customer_options[customer_label],
                            vehicle_options[vehicle_label],
                            driver_options[driver_label],
                            start_date,
                            due_date,
                            0,
                            Decimal("0.00"),
                            "",
                        ],
                    )
                    st.success(result[7] or "Booking created.")
                    st.write(f"**Booking ID:** {result[5]}")
                    st.write(f"**Estimated rental amount:** {money(result[6])}")
                    st.info("The database trigger has changed the vehicle status to Rented.")
                except mysql.connector.Error as error:
                    report_error(error)


elif page == "Payments":
    st.header("Payment ledger")
    payments = fetch_data(
        """
        SELECT p.booking_id, p.payment_id,
               CONCAT(c.first_name, ' ', c.last_name) AS customer,
               p.amount, p.payment_date, p.payment_mode
        FROM PAYMENT p
        JOIN BOOKING b ON b.booking_id = p.booking_id
        JOIN CUSTOMER c ON c.customer_id = b.customer_id
        ORDER BY p.payment_date DESC, p.booking_id DESC
        """
    )
    st.dataframe(payments, use_container_width=True, hide_index=True)

    balances = fetch_data(
        """
        SELECT b.booking_id,
               CONCAT(c.first_name, ' ', c.last_name, ' — ', v.reg_number) AS label,
               ba.total_amount - COALESCE(p.total_paid, 0.00) AS balance_due
        FROM BOOKING b
        JOIN CUSTOMER c ON c.customer_id = b.customer_id
        JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
        JOIN vw_booking_amount ba ON ba.booking_id = b.booking_id
        LEFT JOIN (
            SELECT booking_id, SUM(amount) AS total_paid
            FROM PAYMENT GROUP BY booking_id
        ) p ON p.booking_id = b.booking_id
        WHERE ba.total_amount > COALESCE(p.total_paid, 0.00)
        ORDER BY b.booking_id DESC
        """
    )

    st.subheader("Record a payment installment")
    if balances.empty:
        st.info("There are no outstanding booking balances.")
    else:
        booking_options = {
            f"Booking {int(row.booking_id)} — {row.label} — balance {money(row.balance_due)}":
                (int(row.booking_id), Decimal(str(row.balance_due)))
            for row in balances.itertuples()
        }
        with st.form("payment_form"):
            booking_label = st.selectbox("Booking", list(booking_options))
            balance = booking_options[booking_label][1]
            st.caption(f"Outstanding balance: {money(balance)}")
            amount = st.number_input(
                "Installment amount (₹)",
                min_value=0.01,
                max_value=float(balance),
                value=min(1000.0, float(balance)),
                step=100.0,
            )
            payment_mode = st.selectbox(
                "Payment mode",
                ["Cash", "Credit Card", "Debit Card", "UPI"],
            )
            submitted = st.form_submit_button("Record payment")

            if submitted:
                try:
                    result = call_procedure(
                        "sp_record_payment",
                        [
                            booking_options[booking_label][0],
                            Decimal(str(amount)),
                            payment_mode,
                            0,
                            Decimal("0.00"),
                        ],
                    )
                    st.success(
                        f"Payment #{result[3]} recorded. Remaining balance: {money(result[4])}"
                    )
                    st.rerun()
                except mysql.connector.Error as error:
                    report_error(error)


elif page == "Maintenance":
    st.header("Vehicle maintenance")
    maintenance = fetch_data(
        """
        SELECT m.vehicle_id, m.maintenance_id, v.reg_number,
               CONCAT(v.brand, ' ', v.model) AS vehicle,
               m.service_date, m.cost, v.status
        FROM MAINTENANCE m
        JOIN VEHICLE v ON v.vehicle_id = m.vehicle_id
        ORDER BY m.service_date DESC
        """
    )
    st.dataframe(maintenance, use_container_width=True, hide_index=True)

    with st.expander("Log a maintenance event"):
        eligible = fetch_data(
            """
            SELECT vehicle_id, reg_number, brand, model, status
            FROM VEHICLE
            WHERE status <> 'Rented'
            ORDER BY reg_number
            """
        )
        if eligible.empty:
            st.info("No vehicles are currently eligible for maintenance.")
        else:
            vehicle_options = {
                f"{row.reg_number} — {row.brand} {row.model} ({row.status})":
                    int(row.vehicle_id)
                for row in eligible.itertuples()
            }
            with st.form("maintenance_form"):
                vehicle_label = st.selectbox("Vehicle", list(vehicle_options))
                service_date = st.date_input("Service date", value=date.today())
                cost = st.number_input("Service cost (₹)", min_value=0.0, step=100.0)
                submitted = st.form_submit_button("Save maintenance record")

                if submitted:
                    try:
                        result = call_procedure(
                            "sp_log_maintenance",
                            [
                                vehicle_options[vehicle_label],
                                service_date,
                                Decimal(str(cost)),
                                0,
                            ],
                        )
                        st.success(
                            f"Maintenance record #{result[3]} saved. "
                            "The vehicle is now locked as Maintenance."
                        )
                        st.rerun()
                    except mysql.connector.Error as error:
                        report_error(error)

    st.subheader("Restore a vehicle after service")
    locked = fetch_data(
        """
        SELECT vehicle_id, reg_number, brand, model
        FROM VEHICLE
        WHERE status = 'Maintenance'
        ORDER BY reg_number
        """
    )
    if locked.empty:
        st.info("There are no vehicles currently marked for maintenance.")
    else:
        locked_options = {
            f"{row.reg_number} — {row.brand} {row.model}": int(row.vehicle_id)
            for row in locked.itertuples()
        }
        with st.form("restore_form"):
            selected = st.selectbox("Vehicle ready for service release", list(locked_options))
            submitted = st.form_submit_button("Restore to Available")

            if submitted:
                try:
                    execute_query(
                        "UPDATE VEHICLE SET status = 'Available' WHERE vehicle_id = %s AND status = 'Maintenance'",
                        (locked_options[selected],),
                    )
                    st.success("Vehicle restored to Available.")
                    st.rerun()
                except mysql.connector.Error as error:
                    report_error(error)


elif page == "Penalties":
    st.header("Penalty records")
    penalties = fetch_data(
        """
        SELECT p.booking_id, p.penalty_id,
               CONCAT(c.first_name, ' ', c.last_name) AS customer,
               v.reg_number, p.reason, p.penalty_amount
        FROM PENALTY p
        JOIN BOOKING b ON b.booking_id = p.booking_id
        JOIN CUSTOMER c ON c.customer_id = b.customer_id
        JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
        ORDER BY p.booking_id DESC, p.penalty_id DESC
        """
    )
    st.dataframe(penalties, use_container_width=True, hide_index=True)
    total = fetch_data(
        "SELECT COALESCE(SUM(penalty_amount), 0.00) AS total FROM PENALTY"
    ).iloc[0]["total"]
    st.metric("Total penalties assessed", money(total))


elif page == "Reports":
    st.header("Fleet and revenue reports")

    st.subheader("Monthly branch revenue")
    revenue = fetch_data(
        """
        SELECT br.branch_name,
               DATE_FORMAT(p.payment_date, '%Y-%m') AS revenue_month,
               SUM(p.amount) AS collected_revenue
        FROM PAYMENT p
        JOIN BOOKING b ON b.booking_id = p.booking_id
        JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
        JOIN BRANCH br ON br.branch_id = v.branch_id
        GROUP BY br.branch_id, br.branch_name, DATE_FORMAT(p.payment_date, '%Y-%m')
        ORDER BY revenue_month DESC, br.branch_name
        """
    )
    st.dataframe(revenue, use_container_width=True, hide_index=True)

    left, right = st.columns(2)
    with left:
        st.subheader("Vehicle utilization")
        utilization = fetch_data(
            """
            SELECT v.reg_number, v.brand, v.model, v.category, u.utilization_rate
            FROM vw_vehicle_utilization u
            JOIN VEHICLE v ON v.vehicle_id = u.vehicle_id
            ORDER BY u.utilization_rate DESC
            """
        )
        st.dataframe(utilization, use_container_width=True, hide_index=True)

    with right:
        st.subheader("Driver ratings")
        driver_ratings = fetch_data(
            """
            SELECT d.driver_name, br.branch_name, d.rating,
                   COUNT(b.booking_id) AS booking_count
            FROM DRIVER d
            JOIN BRANCH br ON br.branch_id = d.branch_id
            LEFT JOIN BOOKING b ON b.driver_id = d.driver_id
            GROUP BY d.driver_id, d.driver_name, br.branch_name, d.rating
            ORDER BY d.rating DESC
            """
        )
        st.dataframe(driver_ratings, use_container_width=True, hide_index=True)

    st.subheader("Overdue active bookings")
    overdue = fetch_data(
        """
        SELECT b.booking_id,
               CONCAT(c.first_name, ' ', c.last_name) AS customer,
               v.reg_number,
               b.due_date,
               DATEDIFF(CURDATE(), b.due_date) AS days_overdue,
               fn_calculate_overdue_penalty(b.due_date, CURDATE()) AS estimated_penalty
        FROM BOOKING b
        JOIN CUSTOMER c ON c.customer_id = b.customer_id
        JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
        WHERE b.booking_status = 'Active'
          AND b.due_date < CURDATE()
        ORDER BY b.due_date
        """
    )
    st.dataframe(overdue, use_container_width=True, hide_index=True)
