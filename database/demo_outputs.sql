USE vehicle_fleet_db;

-- Run each query separately or execute the complete file.
-- Each SELECT produces a result grid in MySQL Workbench.

-- OUTPUT 1: Confirm the nine normalized relations.
SELECT table_name AS relation_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- OUTPUT 2: Dashboard summary.
SELECT 'Total Vehicles' AS metric, COUNT(*) AS value FROM VEHICLE
UNION ALL
SELECT 'Available Vehicles', COUNT(*) FROM VEHICLE WHERE status = 'Available'
UNION ALL
SELECT 'Rented Vehicles', COUNT(*) FROM VEHICLE WHERE status = 'Rented'
UNION ALL
SELECT 'Vehicles in Maintenance', COUNT(*) FROM VEHICLE WHERE status = 'Maintenance'
UNION ALL
SELECT 'Customers', COUNT(*) FROM CUSTOMER
UNION ALL
SELECT 'Drivers', COUNT(*) FROM DRIVER
UNION ALL
SELECT 'Bookings', COUNT(*) FROM BOOKING
UNION ALL
SELECT 'Payment Installments', COUNT(*) FROM PAYMENT;

-- OUTPUT 3: Vehicle inventory with branch information.
SELECT v.vehicle_id, v.reg_number, v.category, v.brand, v.model,
       v.base_rate, v.status, br.branch_name, br.city
FROM VEHICLE v
JOIN BRANCH br ON br.branch_id = v.branch_id
ORDER BY br.branch_name, v.reg_number;

-- OUTPUT 4: Vehicles currently available for booking.
SELECT vehicle_id, reg_number, category, brand, model,
       base_rate, branch_name, branch_city
FROM vw_available_fleet
ORDER BY base_rate;

-- OUTPUT 5: Customers and their normalized multivalued phone records.
SELECT c.customer_id, c.first_name, c.last_name, c.email, c.license_no,
       COALESCE(
           GROUP_CONCAT(cp.phone_number ORDER BY cp.phone_number SEPARATOR ', '),
           'No phone recorded'
       ) AS phone_numbers
FROM CUSTOMER c
LEFT JOIN CUSTOMER_PHONE cp ON cp.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.license_no
ORDER BY c.customer_id;

-- OUTPUT 6: Booking invoice, payments received and outstanding balance.
SELECT b.booking_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       v.reg_number,
       CONCAT(v.brand, ' ', v.model) AS vehicle,
       COALESCE(d.driver_name, 'Self-drive') AS driver,
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
ORDER BY b.booking_id;

-- OUTPUT 7: Payment ledger, including split payments.
SELECT p.booking_id, p.payment_id, p.amount, p.payment_date, p.payment_mode,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name
FROM PAYMENT p
JOIN BOOKING b ON b.booking_id = p.booking_id
JOIN CUSTOMER c ON c.customer_id = b.customer_id
ORDER BY p.booking_id, p.payment_id;

-- OUTPUT 8: Late-return penalties.
SELECT p.booking_id, p.penalty_id, p.reason, p.penalty_amount,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       v.reg_number
FROM PENALTY p
JOIN BOOKING b ON b.booking_id = p.booking_id
JOIN CUSTOMER c ON c.customer_id = b.customer_id
JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
ORDER BY p.booking_id, p.penalty_id;

-- OUTPUT 9: Maintenance history.
SELECT m.vehicle_id, m.maintenance_id, v.reg_number,
       CONCAT(v.brand, ' ', v.model) AS vehicle,
       m.service_date, m.cost, v.status
FROM MAINTENANCE m
JOIN VEHICLE v ON v.vehicle_id = m.vehicle_id
ORDER BY m.service_date DESC;

-- OUTPUT 10: Category-wise fleet summary using GROUP BY and HAVING.
SELECT category,
       COUNT(*) AS total_vehicles,
       SUM(status = 'Available') AS available_vehicles,
       SUM(status = 'Rented') AS rented_vehicles,
       SUM(status = 'Maintenance') AS maintenance_vehicles,
       ROUND(AVG(base_rate), 2) AS average_daily_rate
FROM VEHICLE
GROUP BY category
HAVING COUNT(*) > 0
ORDER BY category;

-- OUTPUT 11: Revenue collected by branch and month.
SELECT br.branch_name,
       DATE_FORMAT(p.payment_date, '%Y-%m') AS revenue_month,
       SUM(p.amount) AS collected_revenue
FROM PAYMENT p
JOIN BOOKING b ON b.booking_id = p.booking_id
JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
JOIN BRANCH br ON br.branch_id = v.branch_id
GROUP BY br.branch_id, br.branch_name, DATE_FORMAT(p.payment_date, '%Y-%m')
ORDER BY revenue_month DESC, br.branch_name;

-- OUTPUT 12: Customer lifetime payments (derived attribute view).
SELECT customer_id, customer_name, total_spent
FROM vw_customer_total_spent
ORDER BY total_spent DESC;

-- OUTPUT 13: Vehicle utilization (derived attribute view).
SELECT vehicle_id, reg_number, utilization_rate
FROM vw_vehicle_utilization
ORDER BY utilization_rate DESC;

-- OUTPUT 14: Function output. A return two days after the due date costs ₹600.
SELECT
    fn_calculate_overdue_penalty('2026-11-01', '2026-11-03')
    AS two_day_late_return_penalty;

-- OUTPUT 15: INNER JOIN example.
SELECT b.booking_id, c.email, v.reg_number, br.branch_name
FROM BOOKING b
INNER JOIN CUSTOMER c ON c.customer_id = b.customer_id
INNER JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
INNER JOIN BRANCH br ON br.branch_id = v.branch_id
ORDER BY b.booking_id;

-- OUTPUT 16: LEFT JOIN example. Includes customers with no bookings.
SELECT c.customer_id, c.first_name, c.last_name, b.booking_id, b.booking_status
FROM CUSTOMER c
LEFT JOIN BOOKING b ON b.customer_id = c.customer_id
ORDER BY c.customer_id, b.booking_id;

-- OUTPUT 17: EXISTS subquery. Customers with at least one active booking.
SELECT c.customer_id, c.first_name, c.last_name
FROM CUSTOMER c
WHERE EXISTS (
    SELECT 1
    FROM BOOKING b
    WHERE b.customer_id = c.customer_id
      AND b.booking_status = 'Active'
);

-- OUTPUT 18: NOT EXISTS subquery. Vehicles with no maintenance history.
SELECT v.vehicle_id, v.reg_number, v.brand, v.model
FROM VEHICLE v
WHERE NOT EXISTS (
    SELECT 1
    FROM MAINTENANCE m
    WHERE m.vehicle_id = v.vehicle_id
);

-- OUTPUT 19: UNION set operation.
SELECT vehicle_id, reg_number, status
FROM VEHICLE
WHERE status = 'Available'
UNION
SELECT vehicle_id, reg_number, status
FROM VEHICLE
WHERE status = 'Maintenance'
ORDER BY status, reg_number;

-- OUTPUT 20: EXPLAIN query plan for indexed fleet search.
EXPLAIN
SELECT vehicle_id, reg_number, brand, model, base_rate
FROM VEHICLE
WHERE category = 'SUV'
  AND status = 'Available'
  AND base_rate <= 4000.00;

-- OUTPUT 21: Trigger and routine inventory.
SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
ORDER BY event_object_table, trigger_name;

SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = DATABASE()
ORDER BY routine_type, routine_name;
