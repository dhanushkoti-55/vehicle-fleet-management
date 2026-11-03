USE vehicle_fleet_db;

DROP PROCEDURE IF EXISTS sp_validate_project;
DELIMITER $$

CREATE PROCEDURE sp_validate_project()
BEGIN
    DECLARE v_tables INT DEFAULT 0;
    DECLARE v_views INT DEFAULT 0;
    DECLARE v_routines INT DEFAULT 0;
    DECLARE v_triggers INT DEFAULT 0;
    DECLARE v_rows INT DEFAULT 0;
    DECLARE v_status VARCHAR(20);

    SELECT COUNT(*) INTO v_tables
    FROM information_schema.tables
    WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';

    IF v_tables <> 9 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: expected exactly nine base tables';
    END IF;

    SELECT COUNT(*) INTO v_views
    FROM information_schema.views
    WHERE table_schema = DATABASE()
      AND table_name IN (
          'vw_booking_amount',
          'vw_available_fleet',
          'vw_customer_total_spent',
          'vw_vehicle_utilization'
      );

    IF v_views <> 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: one or more required views are missing';
    END IF;

    SELECT COUNT(*) INTO v_routines
    FROM information_schema.routines
    WHERE routine_schema = DATABASE()
      AND routine_name IN (
          'fn_calculate_overdue_penalty',
          'sp_create_rental_booking',
          'sp_record_payment',
          'sp_log_maintenance',
          'sp_list_overdue_bookings'
      );

    IF v_routines <> 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: required function or procedures are missing';
    END IF;

    SELECT COUNT(*) INTO v_triggers
    FROM information_schema.triggers
    WHERE trigger_schema = DATABASE()
      AND trigger_name IN (
          'trg_before_booking_insert',
          'trg_after_booking_insert',
          'trg_after_booking_update',
          'trg_before_maintenance_insert',
          'trg_after_maintenance_insert'
      );

    IF v_triggers <> 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: required triggers are missing';
    END IF;

    IF fn_calculate_overdue_penalty('2026-11-01', '2026-11-04') <> 900.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: overdue penalty calculation is incorrect';
    END IF;

    SELECT COUNT(*) INTO v_rows
    FROM PAYMENT;

    IF v_rows < 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: expected sample split payment records';
    END IF;

    SELECT COUNT(*) INTO v_rows
    FROM PENALTY
    WHERE penalty_amount = 300.00;

    IF v_rows < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: late-return trigger did not create the sample penalty';
    END IF;

    SELECT status INTO v_status
    FROM VEHICLE
    WHERE reg_number = 'TN23CD5678';

    IF v_status <> 'Rented' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: active booking did not lock its vehicle as Rented';
    END IF;

    SELECT status INTO v_status
    FROM VEHICLE
    WHERE reg_number = 'TN01EF9012';

    IF v_status <> 'Maintenance' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation failed: maintenance trigger did not lock its vehicle';
    END IF;

    SELECT 'PASS: 9 relations, 4 views, 5 routines, 5 triggers, penalty UDF and seed workflows verified' AS validation_result;
END $$

DELIMITER ;

CALL sp_validate_project();
DROP PROCEDURE sp_validate_project;
