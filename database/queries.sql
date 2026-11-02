USE vehicle_fleet_db;

-- 1. Available SUVs under a selected daily rate.
SELECT vehicle_id, reg_number, brand, model, base_rate
FROM VEHICLE
WHERE category = 'SUV'
  AND status = 'Available'
  AND base_rate <= 4000.00
ORDER BY base_rate;

-- 2. Fleet utilization and average base rate by category.
SELECT category,
       COUNT(*) AS total_vehicles,
       SUM(status = 'Rented') AS rented_vehicles,
       ROUND(AVG(base_rate), 2) AS average_daily_rate,
       ROUND(100 * SUM(status = 'Rented') / NULLIF(COUNT(*), 0), 2) AS current_rental_share_pct
FROM VEHICLE
GROUP BY category
HAVING COUNT(*) > 0;

-- 3. Complete booking statement: INNER JOIN, LEFT JOIN and aggregate payments.
SELECT b.booking_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       c.email,
       v.reg_number,
       CONCAT(v.brand, ' ', v.model) AS vehicle_name,
       br.branch_name,
       COALESCE(d.driver_name, 'Self-Drive') AS assigned_driver,
       b.start_date,
       b.due_date,
       ba.total_amount,
       COALESCE(SUM(p.amount), 0.00) AS total_paid,
       ROUND(ba.total_amount - COALESCE(SUM(p.amount), 0.00), 2) AS balance_due
FROM BOOKING b
JOIN CUSTOMER c ON c.customer_id = b.customer_id
JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
JOIN BRANCH br ON br.branch_id = v.branch_id
LEFT JOIN DRIVER d ON d.driver_id = b.driver_id
JOIN vw_booking_amount ba ON ba.booking_id = b.booking_id
LEFT JOIN PAYMENT p ON p.booking_id = b.booking_id
GROUP BY b.booking_id, c.first_name, c.last_name, c.email,
         v.reg_number, v.brand, v.model, br.branch_name,
         d.driver_name, b.start_date, b.due_date, ba.total_amount
ORDER BY b.booking_id DESC;

-- 4. RIGHT JOIN example: include branches even when they have no vehicles.
SELECT br.branch_id, br.branch_name, v.vehicle_id, v.reg_number
FROM VEHICLE v
RIGHT JOIN BRANCH br ON br.branch_id = v.branch_id
ORDER BY br.branch_id, v.vehicle_id;

-- 5. SELF JOIN example: drivers belonging to the same branch.
SELECT d1.driver_name AS driver_one,
       d2.driver_name AS driver_two,
       d1.branch_id
FROM DRIVER d1
JOIN DRIVER d2
  ON d1.branch_id = d2.branch_id
 AND d1.driver_id < d2.driver_id;

-- 6. Nested subquery: customers with spending above the overall average customer spend.
SELECT c.customer_id, c.first_name, c.last_name, c.email, s.total_spent
FROM CUSTOMER c
JOIN vw_customer_total_spent s ON s.customer_id = c.customer_id
WHERE s.total_spent > (
    SELECT AVG(total_spent)
    FROM vw_customer_total_spent
);

-- 7. EXISTS: customers who have at least one active booking.
SELECT c.customer_id, c.first_name, c.last_name
FROM CUSTOMER c
WHERE EXISTS (
    SELECT 1
    FROM BOOKING b
    WHERE b.customer_id = c.customer_id
      AND b.booking_status = 'Active'
);

-- 8. NOT EXISTS: vehicles that have never undergone maintenance.
SELECT v.vehicle_id, v.reg_number, v.brand, v.model
FROM VEHICLE v
WHERE NOT EXISTS (
    SELECT 1
    FROM MAINTENANCE m
    WHERE m.vehicle_id = v.vehicle_id
);

-- 9. Monthly revenue by branch (payments are recognized on payment date).
SELECT br.branch_id,
       br.branch_name,
       DATE_FORMAT(p.payment_date, '%Y-%m') AS revenue_month,
       SUM(p.amount) AS collected_revenue
FROM PAYMENT p
JOIN BOOKING b ON b.booking_id = p.booking_id
JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
JOIN BRANCH br ON br.branch_id = v.branch_id
GROUP BY br.branch_id, br.branch_name, DATE_FORMAT(p.payment_date, '%Y-%m')
ORDER BY revenue_month DESC, br.branch_name;

-- 10. Overdue active rentals and their estimated penalty.
SELECT b.booking_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       v.reg_number,
       b.due_date,
       DATEDIFF(CURDATE(), b.due_date) AS days_overdue,
       fn_calculate_overdue_penalty(b.due_date, CURDATE()) AS estimated_penalty
FROM BOOKING b
JOIN CUSTOMER c ON c.customer_id = b.customer_id
JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
WHERE b.booking_status = 'Active'
  AND b.due_date < CURDATE()
ORDER BY b.due_date;

-- 11. View-based customer lifetime payments.
SELECT customer_id, customer_name, total_spent
FROM vw_customer_total_spent
ORDER BY total_spent DESC;

-- 12. View-based fleet utilization over the last 365 days.
SELECT vehicle_id, reg_number, utilization_rate
FROM vw_vehicle_utilization
ORDER BY utilization_rate DESC;

-- 13. UNION: combined list of available and maintenance vehicles.
SELECT vehicle_id, reg_number, status
FROM VEHICLE
WHERE status = 'Available'
UNION
SELECT vehicle_id, reg_number, status
FROM VEHICLE
WHERE status = 'Maintenance';

-- 14. EXPLAIN: inspect the fleet search access path after indexes exist.
EXPLAIN
SELECT vehicle_id, reg_number, brand, model, base_rate
FROM VEHICLE
WHERE category = 'SUV'
  AND status = 'Available'
  AND base_rate <= 4000.00;
