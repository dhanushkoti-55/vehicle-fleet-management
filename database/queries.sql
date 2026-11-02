USE vehicle_fleet_db;

DELIMITER $$

DROP FUNCTION IF EXISTS fn_calculate_overdue_penalty $$
CREATE FUNCTION fn_calculate_overdue_penalty(
    p_due_date DATE,
    p_return_date DATE
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_penalty DECIMAL(10,2) DEFAULT 0.00;
    IF p_return_date > p_due_date THEN
        SET v_penalty = DATEDIFF(p_return_date, p_due_date) * 300.00;
    END IF;
    RETURN v_penalty;
END $$

DROP PROCEDURE IF EXISTS sp_create_rental_booking $$
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

DROP TRIGGER IF EXISTS trg_after_booking_insert $$
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

DROP TRIGGER IF EXISTS trg_after_booking_return $$
CREATE TRIGGER trg_after_booking_return
AFTER UPDATE ON BOOKING
FOR EACH ROW
BEGIN
    DECLARE v_penalty DECIMAL(10,2);
    DECLARE v_penalty_id INT;

    IF NEW.booking_status = 'Completed' AND OLD.booking_status != 'Completed' THEN
        IF NEW.return_date IS NOT NULL AND NEW.return_date > NEW.due_date THEN
            SET v_penalty = fn_calculate_overdue_penalty(NEW.due_date, NEW.return_date);

            IF v_penalty > 0 THEN
                SELECT COALESCE(MAX(penalty_id), 0) + 1
                INTO v_penalty_id
                FROM PENALTY
                WHERE booking_id = NEW.booking_id;

                INSERT INTO PENALTY (booking_id, penalty_id, reason, penalty_amount)
                VALUES (NEW.booking_id, v_penalty_id, 'Late return overdue charges', v_penalty);
            END IF;
        END IF;

        UPDATE VEHICLE
        SET status = 'Available'
        WHERE vehicle_id = NEW.vehicle_id;
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_after_maintenance_insert $$
CREATE TRIGGER trg_after_maintenance_insert
AFTER INSERT ON MAINTENANCE
FOR EACH ROW
BEGIN
    UPDATE VEHICLE
    SET status = 'Maintenance'
    WHERE vehicle_id = NEW.vehicle_id;
END $$

DELIMITER ;

-- ================= SEED DATA =================
INSERT INTO BRANCH (branch_name, city, phone) VALUES
('Vellore Main Branch', 'Vellore', '9876543210'),
('Chennai Central Branch', 'Chennai', '9876543211');

INSERT INTO VEHICLE (reg_number, category, brand, model, branch_id, base_rate, status) VALUES
('TN23AB1234', 'Economy', 'Maruti', 'Swift', 1, 1500.00, 'Available'),
('TN23CD5678', 'Sedan', 'Honda', 'City', 1, 2500.00, 'Rented'),
('TN01EF9012', 'SUV', 'Hyundai', 'Creta', 2, 3000.00, 'Available'),
('TN01GH3456', 'Luxury', 'BMW', 'X5', 2, 6000.00, 'Available');

INSERT INTO DRIVER (driver_name, license_no, branch_id, rating) VALUES
('Arun Kumar', 'DL10001', 1, 4.50),
('Rahul Sharma', 'DL10002', 2, 4.80);

INSERT INTO CUSTOMER (first_name, last_name, email, license_no) VALUES
('Dhanush', 'Koti', 'dhanush@example.com', 'CL10001'),
('Inderdeep', 'Singh', 'inderdeep@example.com', 'CL10002'),
('Arjun', 'Reddy', 'arjun@example.com', 'CL10003');

INSERT INTO CUSTOMER_PHONE (customer_id, phone_number) VALUES
(1, '9000000001'),
(1, '9000000002'),
(2, '9000000003'),
(3, '9000000004');

INSERT INTO BOOKING (customer_id, vehicle_id, driver_id, start_date, due_date, return_date, booking_status) VALUES
(1, 1, NULL, '2026-10-20', '2026-10-22', '2026-10-22', 'Completed'),
(2, 2, 1, '2026-11-01', '2026-11-05', NULL, 'Active'),
(3, 3, 2, '2026-11-04', '2026-11-06', NULL, 'Pending');

INSERT INTO PAYMENT (booking_id, payment_id, amount, payment_mode) VALUES
(1, 1, 4500.00, 'UPI'),
(2, 1, 3000.00, 'Cash');

INSERT INTO MAINTENANCE (vehicle_id, maintenance_id, service_date, cost) VALUES
(1, 1, '2026-10-25', 2500.00);

INSERT INTO PENALTY (booking_id, penalty_id, reason, penalty_amount) VALUES
(1, 1, 'Late return', 300.00);
