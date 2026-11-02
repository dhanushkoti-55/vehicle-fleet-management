from datetime import date, timedelta
import mysql.connector
import streamlit as st
from db_connection import fetch_data, execute_query, get_connection

st.set_page_config(
    page_title="Vehicle Rental Management",
    page_icon="🚗",
    layout="wide"
)

st.title("Vehicle Rental & Fleet Management System")
st.caption("Vehicle rental database management dashboard")

try:
    conn = get_connection()
    conn.close()
except Exception as e:
    st.error(f"Database connection failed: {e}")
    st.info("Ensure MySQL is running and vehicle_fleet_db is initialized via database/schema.sql and database/queries.sql.")
    st.stop()

st.sidebar.title("Navigation")
page = st.sidebar.radio(
    "Select a section",
    [
        "Dashboard",
        "Vehicles",
        "Customers",
        "Bookings",
        "Payments",
        "Maintenance",
        "Penalties",
        "Create Booking"
    ]
)

if page == "Dashboard":
    st.header("Dashboard Overview")

    col1, col2, col3, col4 = st.columns(4)
    metrics = [
        ("Total Vehicles", "SELECT COUNT(*) AS total FROM VEHICLE"),
        ("Total Customers", "SELECT COUNT(*) AS total FROM CUSTOMER"),
        ("Total Bookings", "SELECT COUNT(*) AS total FROM BOOKING"),
        ("Available Vehicles", "SELECT COUNT(*) AS total FROM VEHICLE WHERE status='Available'")
    ]

    for col, (label, query) in zip([col1, col2, col3, col4], metrics):
        df = fetch_data(query)
        val = df.iloc[0]["total"] if not df.empty else 0
        col.metric(label, val)

    st.subheader("Vehicle Status Distribution")
    status_data = fetch_data("SELECT status, COUNT(*) AS total FROM VEHICLE GROUP BY status")
    if not status_data.empty:
        st.bar_chart(status_data.set_index("status"))

    st.subheader("Vehicles by Category")
    category_data = fetch_data("SELECT category, COUNT(*) AS total FROM VEHICLE GROUP BY category")
    if not category_data.empty:
        st.bar_chart(category_data.set_index("category"))

    st.subheader("Recent Bookings")
    st.dataframe(
        fetch_data("""
            SELECT b.booking_id,
                   CONCAT(c.first_name, ' ', c.last_name) AS customer,
                   v.brand,
                   v.model,
                   b.start_date,
                   b.due_date,
                   b.booking_status
            FROM BOOKING b
            JOIN CUSTOMER c ON b.customer_id = c.customer_id
            JOIN VEHICLE v ON b.vehicle_id = v.vehicle_id
            ORDER BY b.booking_id DESC
            LIMIT 10
        """),
        use_container_width=True
    )

elif page == "Vehicles":
    st.header("Vehicle Inventory")

    status = st.selectbox("Filter by status", ["All", "Available", "Rented", "Maintenance"])
    query = """
        SELECT v.vehicle_id, v.reg_number, v.category,
               v.brand, v.model, v.base_rate, v.status,
               br.branch_name, br.city
        FROM VEHICLE v
        JOIN BRANCH br ON v.branch_id = br.branch_id
    """
    if status != "All":
        query += " WHERE v.status = %s"

    data = fetch_data(query, (status,) if status != "All" else None)
    st.dataframe(data, use_container_width=True)

elif page == "Customers":
    st.header("Customer Records")

    st.dataframe(
        fetch_data("""
            SELECT c.customer_id,
                   c.first_name,
                   c.last_name,
                   c.email,
                   c.license_no,
                   COALESCE(GROUP_CONCAT(cp.phone_number SEPARATOR ', '), 'N/A') AS phone_numbers
            FROM CUSTOMER c
            LEFT JOIN CUSTOMER_PHONE cp ON c.customer_id = cp.customer_id
            GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.license_no
        """),
        use_container_width=True
    )

elif page == "Bookings":
    st.header("Booking Records")

    status = st.selectbox("Filter bookings", ["All", "Pending", "Active", "Completed", "Cancelled"])
    query = """
        SELECT b.booking_id,
               CONCAT(c.first_name, ' ', c.last_name) AS customer,
               v.reg_number,
               v.brand,
               v.model,
               COALESCE(d.driver_name, 'Self-Drive') AS driver,
               b.start_date,
               b.due_date,
               b.return_date,
               b.booking_status,
               ba.total_amount
        FROM BOOKING b
        JOIN CUSTOMER c ON b.customer_id = c.customer_id
        JOIN VEHICLE v ON b.vehicle_id = v.vehicle_id
        LEFT JOIN DRIVER d ON b.driver_id = d.driver_id
        JOIN vw_booking_amount ba ON b.booking_id = ba.booking_id
    """
    if status != "All":
        query += " WHERE b.booking_status = %s"
    query += " ORDER BY b.booking_id DESC"

    data = fetch_data(query, (status,) if status != "All" else None)
    st.dataframe(data, use_container_width=True)

    # Interactive Return Handler to demonstrate trg_after_booking_return
    st.markdown("---")
    st.subheader("Process Vehicle Return")
    active_bookings = fetch_data("""
        SELECT b.booking_id, CONCAT('ID ', b.booking_id, ' - ', c.first_name, ' (', v.reg_number, ')') AS label
        FROM BOOKING b
        JOIN CUSTOMER c ON b.customer_id = c.customer_id
        JOIN VEHICLE v ON b.vehicle_id = v.vehicle_id
        WHERE b.booking_status = 'Active'
    """)

    if not active_bookings.empty:
        with st.form("return_vehicle_form"):
            selected_label = st.selectbox("Select Active Booking", active_bookings["label"].tolist())
            selected_b_id = int(selected_label.split(" - ")[0].replace("ID ", ""))
            ret_date = st.date_input("Actual Return Date", date.today())
            confirm_return = st.form_submit_button("Mark as Returned & Calculate Penalties")

            if confirm_return:
                try:
                    execute_query(
                        "UPDATE BOOKING SET return_date = %s, booking_status = 'Completed' WHERE booking_id = %s",
                        (ret_date, selected_b_id)
                    )
                    st.success(f"Booking #{selected_b_id} closed. Vehicle returned to Available status.")
                    st.rerun()
                except Exception as ex:
                    st.error(f"Error processing return: {ex}")
    else:
        st.info("No currently active rentals to process for return.")

elif page == "Payments":
    st.header("Payment Records")

    st.dataframe(
        fetch_data("""
            SELECT p.booking_id,
                   p.payment_id,
                   CONCAT(c.first_name, ' ', c.last_name) AS customer,
                   p.amount,
                   p.payment_date,
                   p.payment_mode
            FROM PAYMENT p
            JOIN BOOKING b ON p.booking_id = b.booking_id
            JOIN CUSTOMER c ON b.customer_id = c.customer_id
            ORDER BY p.payment_date DESC
        """),
        use_container_width=True
    )

    total_df = fetch_data("SELECT COALESCE(SUM(amount), 0) AS total FROM PAYMENT")
    total = total_df.iloc[0]["total"] if not total_df.empty else 0
    st.metric("Total Payments Received", f"₹{total:,.2f}")

elif page == "Maintenance":
    st.header("Vehicle Maintenance")

    st.dataframe(
        fetch_data("""
            SELECT m.vehicle_id,
                   v.reg_number,
                   v.brand,
                   v.model,
                   m.maintenance_id,
                   m.service_date,
                   m.cost
            FROM MAINTENANCE m
            JOIN VEHICLE v ON m.vehicle_id = v.vehicle_id
            ORDER BY m.service_date DESC
        """),
        use_container_width=True
    )

    total_df = fetch_data("SELECT COALESCE(SUM(cost), 0) AS total FROM MAINTENANCE")
    total = total_df.iloc[0]["total"] if not total_df.empty else 0
    st.metric("Total Maintenance Cost", f"₹{total:,.2f}")

elif page == "Penalties":
    st.header("Penalty Records")

    st.dataframe(
        fetch_data("""
            SELECT p.booking_id,
                   p.penalty_id,
                   CONCAT(c.first_name, ' ', c.last_name) AS customer,
                   p.reason,
                   p.penalty_amount
            FROM PENALTY p
            JOIN BOOKING b ON p.booking_id = b.booking_id
            JOIN CUSTOMER c ON b.customer_id = c.customer_id
            ORDER BY p.booking_id DESC
        """),
        use_container_width=True
    )

    total_df = fetch_data("SELECT COALESCE(SUM(penalty_amount), 0) AS total FROM PENALTY")
    total = total_df.iloc[0]["total"] if not total_df.empty else 0
    st.metric("Total Penalties", f"₹{total:,.2f}")

elif page == "Create Booking":
    st.header("Create Rental Booking")

    customers = fetch_data("SELECT customer_id, first_name, last_name FROM CUSTOMER ORDER BY first_name")
    vehicles = fetch_data("SELECT vehicle_id, reg_number, brand, model, base_rate, category FROM VEHICLE WHERE status = 'Available' ORDER BY vehicle_id")
    drivers = fetch_data("SELECT driver_id, driver_name FROM DRIVER ORDER BY driver_name")

    if customers.empty:
        st.warning("No customers found in database.")
    elif vehicles.empty:
        st.warning("No vehicles currently available for booking.")
    else:
        with st.form("booking_form"):
            customer_options = {
                f"{r.first_name} {r.last_name} (ID: {r.customer_id})": r.customer_id
                for r in customers.itertuples()
            }
            vehicle_options = {
                f"{r.reg_number} - {r.brand} {r.model} (₹{r.base_rate}/day)": r.vehicle_id
                for r in vehicles.itertuples()
            }
            driver_options = {
                "Self-Drive (No Driver)": None,
                **{f"{r.driver_name} (ID: {r.driver_id})": r.driver_id for r in drivers.itertuples()}
            }

            customer = st.selectbox("Customer", list(customer_options.keys()))
            vehicle = st.selectbox("Available Vehicle", list(vehicle_options.keys()))
            driver = st.selectbox("Driver Option", list(driver_options.keys()))

            start_date = st.date_input("Start Date", date.today())
            due_date = st.date_input("Due Date", date.today() + timedelta(days=2), min_value=start_date)

            submitted = st.form_submit_button("Confirm Booking")

            if submitted:
                if due_date < start_date:
                    st.error("Due date cannot precede start date.")
                else:
                    try:
                        conn = get_connection()
                        cursor = conn.cursor()
                        result = cursor.callproc(
                            "sp_create_rental_booking",
                            [
                                customer_options[customer],
                                vehicle_options[vehicle],
                                driver_options[driver],
                                start_date,
                                due_date,
                                0,
                                0.0
                            ]
                        )
                        conn.commit()
                        booking_id = result[5]
                        total_amount = result[6]
                        cursor.close()
                        conn.close()

                        st.success("Booking created successfully!")
                        st.write(f"**Booking ID:** {booking_id}")
                        st.write(f"**Calculated Total:** ₹{total_amount:,.2f}")
                    except mysql.connector.Error as e:
                        st.error(f"Booking transaction failed: {e}")

st.sidebar.divider()
st.sidebar.caption("Vehicle Rental & Fleet Management System")
