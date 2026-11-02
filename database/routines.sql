USE vehicle_fleet_db;

DELIMITER $$

DROP FUNCTION IF EXISTS fn_calculate_overdue_penalty $$
CREATE FUNCTION fn_calculate_overdue_penalty(
    p_due_date DATE,
    p_return_date DATE
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_due_date IS NULL OR p_return_date IS NULL OR p_return_date <= p_due_date THEN
        RETURN 0.00;
    END IF;
    RETURN DATEDIFF(p_return_date, p_due_date) * 300.00;
END $$

DROP PROCEDURE IF EXISTS sp_create_rental_booking $$
CREATE PROCEDURE sp_create_rental_booking(
    IN p_customer_id INT,
    IN p_vehicle_id INT,
    IN p_driver_id INT,
    IN p_start_date DATE,
    IN p_due_date DATE,
    OUT p_booking_id INT,
    OUT p_total_amount DECIMAL(10,2),
    OUT p_status_message VARCHAR(100)
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_rate DECIMAL(10,2);
    DECLARE v_category VARCHAR(20);
    DECLARE v_multiplier DECIMAL(3,2) DEFAULT 1.00;
    DECLARE v_days INT;
    DECLARE v_vehicle_missing BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_vehicle_missing = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_booking_id = NULL;
    SET p_total_amount = 0.00;
    SET p_status_message = NULL;

    IF p_start_date IS NULL OR p_due_date IS NULL OR p_due_date < p_start_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Due date must be on or after start date';
    END IF;

    START TRANSACTION;

    SELECT status, base_rate, category
      INTO v_status, v_rate, v_category
      FROM VEHICLE
     WHERE vehicle_id = p_vehicle_id
     FOR UPDATE;

    IF v_vehicle_missing THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle does not exist';
    END IF;

    IF v_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle is not available';
    END IF;

    IF p_driver_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM DRIVER WHERE driver_id = p_driver_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver does not exist';
    END IF;

    IF v_category = 'SUV' THEN
        SET v_multiplier = 1.25;
    ELSEIF v_category = 'Luxury' THEN
        SET v_multiplier = 1.75;
    END IF;

    SET v_days = DATEDIFF(p_due_date, p_start_date) + 1;
    SET p_total_amount = ROUND(v_rate * v_days * v_multiplier
        + IF(p_driver_id IS NULL, 0.00, 500.00 * v_days), 2);

    INSERT INTO BOOKING (
        customer_id, vehicle_id, driver_id, start_date, due_date, booking_status
    ) VALUES (
        p_customer_id, p_vehicle_id, p_driver_id, p_start_date, p_due_date, 'Active'
    );

    SET p_booking_id = LAST_INSERT_ID();
    SET p_status_message = 'Booking confirmed';
    COMMIT;
END $$

DROP PROCEDURE IF EXISTS sp_record_payment $$
CREATE PROCEDURE sp_record_payment(
    IN p_booking_id INT,
    IN p_amount DECIMAL(10,2),
    IN p_payment_mode VARCHAR(20),
    OUT p_payment_id INT,
    OUT p_balance_due DECIMAL(10,2)
)
BEGIN
    DECLARE v_booking_id INT;
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_paid DECIMAL(10,2);
    DECLARE v_booking_missing BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_booking_missing = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_payment_id = NULL;
    SET p_balance_due = NULL;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be greater than zero';
    END IF;

    START TRANSACTION;

    SELECT booking_id INTO v_booking_id
      FROM BOOKING
     WHERE booking_id = p_booking_id
     FOR UPDATE;

    IF v_booking_missing THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking does not exist';
    END IF;

    SELECT total_amount INTO v_total
      FROM vw_booking_amount
     WHERE booking_id = p_booking_id;

    SELECT COALESCE(SUM(amount), 0.00) INTO v_paid
      FROM PAYMENT
     WHERE booking_id = p_booking_id;

    IF p_amount > v_total - v_paid THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment exceeds outstanding booking balance';
    END IF;

    SELECT COALESCE(MAX(payment_id), 0) + 1 INTO p_payment_id
      FROM PAYMENT
     WHERE booking_id = p_booking_id;

    INSERT INTO PAYMENT (booking_id, payment_id, amount, payment_mode)
    VALUES (p_booking_id, p_payment_id, p_amount, p_payment_mode);

    SET p_balance_due = ROUND(v_total - v_paid - p_amount, 2);
    COMMIT;
END $$

DROP PROCEDURE IF EXISTS sp_log_maintenance $$
CREATE PROCEDURE sp_log_maintenance(
    IN p_vehicle_id INT,
    IN p_service_date DATE,
    IN p_cost DECIMAL(10,2),
    OUT p_maintenance_id INT
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_vehicle_missing BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_vehicle_missing = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_maintenance_id = NULL;

    IF p_service_date IS NULL OR p_cost IS NULL OR p_cost < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid maintenance date or cost';
    END IF;

    START TRANSACTION;

    SELECT status INTO v_status
      FROM VEHICLE
     WHERE vehicle_id = p_vehicle_id
     FOR UPDATE;

    IF v_vehicle_missing THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle does not exist';
    END IF;

    IF v_status = 'Rented' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A rented vehicle cannot enter maintenance';
    END IF;

    SELECT COALESCE(MAX(maintenance_id), 0) + 1 INTO p_maintenance_id
      FROM MAINTENANCE
     WHERE vehicle_id = p_vehicle_id;

    INSERT INTO MAINTENANCE (vehicle_id, maintenance_id, service_date, cost)
    VALUES (p_vehicle_id, p_maintenance_id, p_service_date, p_cost);

    COMMIT;
END $$

DROP PROCEDURE IF EXISTS sp_list_overdue_bookings $$
CREATE PROCEDURE sp_list_overdue_bookings()
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_booking_id INT;
    DECLARE v_customer_name VARCHAR(120);
    DECLARE v_vehicle_reg VARCHAR(20);
    DECLARE v_due_date DATE;
    DECLARE v_days_overdue INT;

    DECLARE overdue_cursor CURSOR FOR
        SELECT b.booking_id,
               CONCAT(c.first_name, ' ', c.last_name),
               v.reg_number,
               b.due_date,
               DATEDIFF(CURDATE(), b.due_date)
          FROM BOOKING b
          JOIN CUSTOMER c ON c.customer_id = b.customer_id
          JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id
         WHERE b.booking_status = 'Active'
           AND b.due_date < CURDATE();

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    DROP TEMPORARY TABLE IF EXISTS tmp_overdue_bookings;
    CREATE TEMPORARY TABLE tmp_overdue_bookings (
        booking_id INT,
        customer_name VARCHAR(120),
        reg_number VARCHAR(20),
        due_date DATE,
        days_overdue INT,
        estimated_penalty DECIMAL(10,2)
    );

    OPEN overdue_cursor;

    read_loop: LOOP
        FETCH overdue_cursor
         INTO v_booking_id, v_customer_name, v_vehicle_reg, v_due_date, v_days_overdue;

        IF v_done THEN
            LEAVE read_loop;
        END IF;

        INSERT INTO tmp_overdue_bookings
        VALUES (
            v_booking_id, v_customer_name, v_vehicle_reg, v_due_date,
            v_days_overdue, v_days_overdue * 300.00
        );
    END LOOP;

    CLOSE overdue_cursor;

    SELECT * FROM tmp_overdue_bookings ORDER BY due_date;
    DROP TEMPORARY TABLE tmp_overdue_bookings;
END $$

DROP TRIGGER IF EXISTS trg_before_booking_insert $$
CREATE TRIGGER trg_before_booking_insert
BEFORE INSERT ON BOOKING
FOR EACH ROW
BEGIN
    DECLARE v_vehicle_status VARCHAR(20);

    IF NEW.booking_status = 'Active' THEN
        SELECT status INTO v_vehicle_status
          FROM VEHICLE
         WHERE vehicle_id = NEW.vehicle_id;

        IF v_vehicle_status <> 'Available' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle is not available';
        END IF;
    END IF;
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

DROP TRIGGER IF EXISTS trg_after_booking_update $$
CREATE TRIGGER trg_after_booking_update
AFTER UPDATE ON BOOKING
FOR EACH ROW
BEGIN
    DECLARE v_penalty DECIMAL(10,2);
    DECLARE v_penalty_id INT;

    IF NEW.booking_status = 'Completed' AND OLD.booking_status <> 'Completed' THEN
        IF NEW.return_date IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return date is required to complete a booking';
        END IF;

        SET v_penalty = fn_calculate_overdue_penalty(NEW.due_date, NEW.return_date);

        IF v_penalty > 0 THEN
            SELECT COALESCE(MAX(penalty_id), 0) + 1
              INTO v_penalty_id
              FROM PENALTY
             WHERE booking_id = NEW.booking_id;

            INSERT INTO PENALTY (booking_id, penalty_id, reason, penalty_amount)
            VALUES (
                NEW.booking_id, v_penalty_id,
                CONCAT('Late return: ', DATEDIFF(NEW.return_date, NEW.due_date), ' day(s) overdue'),
                v_penalty
            );
        END IF;

        UPDATE VEHICLE SET status = 'Available'
         WHERE vehicle_id = NEW.vehicle_id;
    ELSEIF NEW.booking_status = 'Cancelled' AND OLD.booking_status = 'Active' THEN
        UPDATE VEHICLE SET status = 'Available'
         WHERE vehicle_id = NEW.vehicle_id;
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_before_maintenance_insert $$
CREATE TRIGGER trg_before_maintenance_insert
BEFORE INSERT ON MAINTENANCE
FOR EACH ROW
BEGIN
    DECLARE v_vehicle_status VARCHAR(20);

    SELECT status INTO v_vehicle_status
      FROM VEHICLE
     WHERE vehicle_id = NEW.vehicle_id;

    IF v_vehicle_status = 'Rented' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A rented vehicle cannot enter maintenance';
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
