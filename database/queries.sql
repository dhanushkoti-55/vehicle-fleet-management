USE vehicle_fleet_db;

DELIMITER $$

CREATE FUNCTION fn_calculate_overdue_penalty(
    p_due_date DATE,
    p_return_date DATE
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_penalty DECIMAL(10,2) DEFAULT 0;

    IF p_return_date > p_due_date THEN
        SET v_penalty = DATEDIFF(p_return_date, p_due_date) * 300.00;
    END IF;

    RETURN v_penalty;
END $$

CREATE PROCEDURE sp_create_rental_booking(
    IN p_customer_id INT,
    IN p_vehicle_id INT,
    IN p_driver_id INT,
    IN p_start_date DATE,
    IN p_due_date DATE,
    OUT p_booking_id INT,
    OUT p_total_amount DECIMAL(10,2)
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_rate DECIMAL(10,2);
    DECLARE v_category VARCHAR(20);
    DECLARE v_multiplier DECIMAL(3,2) DEFAULT 1.00;
    DECLARE v_days INT;
    DECLARE v_count INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_due_date < p_start_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid booking dates';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM VEHICLE
    WHERE vehicle_id = p_vehicle_id;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Vehicle does not exist';
    END IF;

    SELECT status, base_rate, category
    INTO v_status, v_rate, v_category
    FROM VEHICLE
    WHERE vehicle_id = p_vehicle_id
    FOR UPDATE;

    IF v_status != 'Available' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Vehicle is not available';
    END IF;

    IF v_category = 'SUV' THEN
        SET v_multiplier = 1.25;
    ELSEIF v_category = 'Luxury' THEN
        SET v_multiplier = 1.75;
    END IF;

    SET v_days = DATEDIFF(p_due_date, p_start_date) + 1;
    SET p_total_amount = v_rate * v_days * v_multiplier;

    IF p_driver_id IS NOT NULL THEN
        SET p_total_amount = p_total_amount + (500.00 * v_days);
    END IF;

    INSERT INTO BOOKING
    (customer_id, vehicle_id, driver_id, start_date, due_date, booking_status)
    VALUES
    (p_customer_id, p_vehicle_id, p_driver_id, p_start_date, p_due_date, 'Active');

    SET p_booking_id = LAST_INSERT_ID();

    COMMIT;
END $$

CREATE TRIGGER trg_after_booking_insert
AFTER INSERT ON BOOKING
FOR EACH ROW
BEGIN
    IF NEW.booking_status = 'Active' THEN
        UPDATE VEHICLE
        SET status = 'Rented'
        WHERE vehicle_id = NEW.vehicle_id;
    END IF;
END $$

CREATE TRIGGER trg_after_booking_return
AFTER UPDATE ON BOOKING
FOR EACH ROW
BEGIN
    DECLARE v_penalty DECIMAL(10,2);
    DECLARE v_penalty_id INT;

    IF NEW.booking_status = 'Completed'
       AND OLD.booking_status = 'Active' THEN

        IF NEW.return_date > NEW.due_date THEN

            SET v_penalty = fn_calculate_overdue_penalty(
                NEW.due_date,
                NEW.return_date
            );

            SELECT COALESCE(MAX(penalty_id), 0) + 1
            INTO v_penalty_id
            FROM PENALTY
            WHERE booking_id = NEW.booking_id;

            INSERT INTO PENALTY
            (booking_id, penalty_id, reason, penalty_amount)
            VALUES
            (NEW.booking_id, v_penalty_id, 'Late return', v_penalty);

        END IF;

        UPDATE VEHICLE
        SET status = 'Available'
        WHERE vehicle_id = NEW.vehicle_id;

    END IF;
END $$

CREATE TRIGGER trg_after_maintenance_insert
AFTER INSERT ON MAINTENANCE
FOR EACH ROW
BEGIN
    UPDATE VEHICLE
    SET status = 'Maintenance'
    WHERE vehicle_id = NEW.vehicle_id;
END $$

DELIMITER ;


INSERT INTO BRANCH (branch_name, city, phone) VALUES
('Vellore Branch', 'Vellore', '9876543210'),
('Chennai Branch', 'Chennai', '9876543211');

INSERT INTO VEHICLE
(reg_number, category, brand, model, branch_id, base_rate) VALUES
('TN23AB1234', 'Economy', 'Maruti', 'Swift', 1, 1500.00),
('TN23CD5678', 'Sedan', 'Honda', 'City', 1, 2500.00),
('TN01EF9012', 'SUV', 'Hyundai', 'Creta', 2, 3000.00),
('TN01GH3456', 'Luxury', 'BMW', 'X5', 2, 6000.00);

INSERT INTO DRIVER
(driver_name, license_no, branch_id, rating) VALUES
('Arun Kumar', 'DL10001', 1, 4.50),
('Rahul Sharma', 'DL10002', 2, 4.80);

INSERT INTO CUSTOMER
(first_name, last_name, email, license_no) VALUES
('Dhanush', 'Koti', 'dhanush@example.com', 'CL10001'),
('Inderdeep', 'Singh', 'inderdeep@example.com', 'CL10002'),
('Arjun', 'Reddy', 'arjun@example.com', 'CL10003');

INSERT INTO CUSTOMER_PHONE (customer_id, phone_number) VALUES
(1, '9000000001'),
(1, '9000000002'),
(2, '9000000003'),
(3, '9000000004');

INSERT INTO BOOKING
(customer_id, vehicle_id, driver_id, start_date, due_date, return_date, booking_status) VALUES
(1, 1, NULL, '2026-10-20', '2026-10-22', '2026-10-22', 'Completed'),
(2, 2, 1, '2026-11-01', '2026-11-05', NULL, 'Active'),
(3, 3, 2, '2026-11-04', '2026-11-06', NULL, 'Pending');

INSERT INTO PAYMENT
(booking_id, payment_id, amount, payment_mode) VALUES
(1, 1, 4500.00, 'UPI'),
(2, 1, 3000.00, 'Cash');

INSERT INTO MAINTENANCE
(vehicle_id, maintenance_id, service_date, cost) VALUES
(1, 1, '2026-10-25', 2500.00);

INSERT INTO PENALTY
(booking_id, penalty_id, reason, penalty_amount) VALUES
(1, 1, 'Late return', 300.00);


SELECT * FROM BRANCH;
SELECT * FROM VEHICLE;
SELECT * FROM DRIVER;
SELECT * FROM CUSTOMER;
SELECT * FROM CUSTOMER_PHONE;
SELECT * FROM BOOKING;
SELECT * FROM PAYMENT;
SELECT * FROM MAINTENANCE;
SELECT * FROM PENALTY;


SELECT *
FROM VEHICLE
WHERE status = 'Available';


SELECT *
FROM VEHICLE
WHERE category = 'SUV';


SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    b.booking_id,
    v.brand,
    v.model,
    b.start_date,
    b.due_date,
    b.booking_status
FROM BOOKING b
JOIN CUSTOMER c ON b.customer_id = c.customer_id
JOIN VEHICLE v ON b.vehicle_id = v.vehicle_id;


SELECT
    b.booking_id,
    c.first_name,
    c.last_name,
    v.brand,
    v.model,
    ba.total_amount
FROM BOOKING b
JOIN CUSTOMER c ON b.customer_id = c.customer_id
JOIN VEHICLE v ON b.vehicle_id = v.vehicle_id
JOIN vw_booking_amount ba ON b.booking_id = ba.booking_id;


SELECT category, COUNT(*) AS total_vehicles
FROM VEHICLE
GROUP BY category;


SELECT branch_id, COUNT(*) AS total_vehicles
FROM VEHICLE
GROUP BY branch_id
HAVING COUNT(*) > 1;


SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(p.amount) AS total_paid
FROM CUSTOMER c
JOIN BOOKING b ON c.customer_id = b.customer_id
JOIN PAYMENT p ON b.booking_id = p.booking_id
GROUP BY c.customer_id, c.first_name, c.last_name;


SELECT *
FROM CUSTOMER
WHERE customer_id IN (
    SELECT customer_id
    FROM BOOKING
);


SELECT *
FROM VEHICLE v
WHERE NOT EXISTS (
    SELECT 1
    FROM MAINTENANCE m
    WHERE m.vehicle_id = v.vehicle_id
);


SELECT
    v.vehicle_id,
    v.reg_number,
    v.brand,
    v.model,
    br.branch_name
FROM VEHICLE v
JOIN BRANCH br ON v.branch_id = br.branch_id;


SELECT
    b.booking_id,
    c.first_name,
    c.last_name,
    d.driver_name
FROM BOOKING b
JOIN CUSTOMER c ON b.customer_id = c.customer_id
LEFT JOIN DRIVER d ON b.driver_id = d.driver_id;


SELECT
    customer_id,
    first_name,
    last_name
FROM CUSTOMER
WHERE customer_id IN (
    SELECT customer_id
    FROM BOOKING
    WHERE booking_status = 'Active'
);


SELECT booking_id, total_amount
FROM vw_booking_amount;


SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COALESCE(SUM(p.amount), 0) AS total_spent
FROM CUSTOMER c
LEFT JOIN BOOKING b ON c.customer_id = b.customer_id
LEFT JOIN PAYMENT p ON b.booking_id = p.booking_id
GROUP BY c.customer_id, c.first_name, c.last_name;


SELECT
    v.vehicle_id,
    v.reg_number,
    COUNT(b.booking_id) AS total_bookings
FROM VEHICLE v
LEFT JOIN BOOKING b ON v.vehicle_id = b.vehicle_id
GROUP BY v.vehicle_id, v.reg_number;


SELECT *
FROM BOOKING
WHERE due_date < CURDATE()
AND booking_status = 'Active';


SELECT fn_calculate_overdue_penalty('2026-11-03', '2026-11-05')
AS overdue_penalty;


START TRANSACTION;

INSERT INTO BOOKING
(customer_id, vehicle_id, driver_id, start_date, due_date, booking_status)
VALUES
(1, 4, NULL, '2026-11-10', '2026-11-12', 'Pending');

SET @new_booking_id = LAST_INSERT_ID();

SAVEPOINT booking_created;

INSERT INTO PAYMENT
(booking_id, payment_id, amount, payment_mode)
VALUES
(@new_booking_id, 1, 1000.00, 'UPI');

COMMIT;


SET @booking_id = NULL;
SET @total_amount = NULL;

CALL sp_create_rental_booking(
    1,
    4,
    NULL,
    '2026-11-15',
    '2026-11-17',
    @booking_id,
    @total_amount
);

SELECT @booking_id AS booking_id, @total_amount AS total_amount;


EXPLAIN
SELECT vehicle_id, reg_number, brand, model, base_rate
FROM VEHICLE
WHERE category = 'SUV'
AND status = 'Available'
AND base_rate <= 4000.00;
