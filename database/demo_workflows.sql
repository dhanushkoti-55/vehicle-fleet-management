USE vehicle_fleet_db;

-- DEMONSTRATION WORKFLOW
-- Creates a demo booking, records a payment installment, completes a late return,
-- verifies the generated penalty, logs maintenance, then restores the vehicle.
-- Run after schema.sql, routines.sql and seed.sql.
-- This script intentionally inserts demonstration records into your database.

SET @demo_customer_id = (
    SELECT customer_id FROM CUSTOMER ORDER BY customer_id LIMIT 1
);

SET @demo_vehicle_id = (
    SELECT vehicle_id
    FROM VEHICLE
    WHERE status = 'Available'
    ORDER BY vehicle_id
    LIMIT 1
);

SET @demo_driver_id = NULL;
SET @demo_start_date = DATE_SUB(CURDATE(), INTERVAL 5 DAY);
SET @demo_due_date = DATE_SUB(CURDATE(), INTERVAL 2 DAY);

-- STEP 1: Create a booking for an available vehicle.
CALL sp_create_rental_booking(
    @demo_customer_id,
    @demo_vehicle_id,
    @demo_driver_id,
    @demo_start_date,
    @demo_due_date,
    @demo_booking_id,
    @demo_total_amount,
    @demo_booking_status
);

SELECT
    @demo_booking_id AS booking_id,
    @demo_total_amount AS calculated_rental_amount,
    @demo_booking_status AS procedure_message;

-- Trigger output: the vehicle should now be Rented.
SELECT vehicle_id, reg_number, status
FROM VEHICLE
WHERE vehicle_id = @demo_vehicle_id;

-- STEP 2: Record a partial payment through the stored procedure.
CALL sp_record_payment(
    @demo_booking_id,
    LEAST(500.00, @demo_total_amount),
    'UPI',
    @demo_payment_id,
    @demo_balance_due
);

SELECT
    @demo_payment_id AS payment_id,
    LEAST(500.00, @demo_total_amount) AS installment_amount,
    @demo_balance_due AS remaining_balance;

-- STEP 3: Return the vehicle today. Due date is two days before today.
-- The AFTER UPDATE trigger inserts a ₹600 penalty and makes the vehicle Available.
UPDATE BOOKING
SET return_date = CURDATE(),
    booking_status = 'Completed'
WHERE booking_id = @demo_booking_id;

SELECT booking_id, return_date, booking_status
FROM BOOKING
WHERE booking_id = @demo_booking_id;

SELECT booking_id, penalty_id, reason, penalty_amount
FROM PENALTY
WHERE booking_id = @demo_booking_id;

SELECT vehicle_id, reg_number, status
FROM VEHICLE
WHERE vehicle_id = @demo_vehicle_id;

-- STEP 4: Log a maintenance event through the stored procedure.
-- The AFTER INSERT trigger changes the vehicle status to Maintenance.
CALL sp_log_maintenance(
    @demo_vehicle_id,
    CURDATE(),
    2500.00,
    @demo_maintenance_id
);

SELECT
    @demo_maintenance_id AS maintenance_id,
    vehicle_id,
    reg_number,
    status
FROM VEHICLE
WHERE vehicle_id = @demo_vehicle_id;

-- STEP 5: Demonstrate workshop release after repair.
UPDATE VEHICLE
SET status = 'Available'
WHERE vehicle_id = @demo_vehicle_id
  AND status = 'Maintenance';

SELECT vehicle_id, reg_number, status
FROM VEHICLE
WHERE vehicle_id = @demo_vehicle_id;

-- FINAL: Show the complete invoice and all related financial records.
SELECT b.booking_id,
       ba.total_amount,
       COALESCE(p.total_paid, 0.00) AS total_paid,
       ROUND(ba.total_amount - COALESCE(p.total_paid, 0.00), 2) AS balance_due,
       COALESCE(x.total_penalty, 0.00) AS penalty_amount
FROM BOOKING b
JOIN vw_booking_amount ba ON ba.booking_id = b.booking_id
LEFT JOIN (
    SELECT booking_id, SUM(amount) AS total_paid
    FROM PAYMENT
    GROUP BY booking_id
) p ON p.booking_id = b.booking_id
LEFT JOIN (
    SELECT booking_id, SUM(penalty_amount) AS total_penalty
    FROM PENALTY
    GROUP BY booking_id
) x ON x.booking_id = b.booking_id
WHERE b.booking_id = @demo_booking_id;
