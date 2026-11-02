USE vehicle_fleet_db;

INSERT INTO BRANCH (branch_name, city, phone)
SELECT 'Vellore Main Branch', 'Vellore', '0416-2244111'
WHERE NOT EXISTS (
    SELECT 1 FROM BRANCH WHERE branch_name = 'Vellore Main Branch' AND city = 'Vellore'
);

INSERT INTO BRANCH (branch_name, city, phone)
SELECT 'Chennai Central Branch', 'Chennai', '044-28112233'
WHERE NOT EXISTS (
    SELECT 1 FROM BRANCH WHERE branch_name = 'Chennai Central Branch' AND city = 'Chennai'
);

SET @vellore_branch = (
    SELECT branch_id FROM BRANCH
    WHERE branch_name = 'Vellore Main Branch' AND city = 'Vellore'
    ORDER BY branch_id LIMIT 1
);
SET @chennai_branch = (
    SELECT branch_id FROM BRANCH
    WHERE branch_name = 'Chennai Central Branch' AND city = 'Chennai'
    ORDER BY branch_id LIMIT 1
);

INSERT INTO VEHICLE (reg_number, category, brand, model, branch_id, base_rate, status)
SELECT 'TN23AB1234', 'Economy', 'Maruti Suzuki', 'Swift Dzire', @vellore_branch, 1500.00, 'Available'
WHERE NOT EXISTS (SELECT 1 FROM VEHICLE WHERE reg_number = 'TN23AB1234');

INSERT INTO VEHICLE (reg_number, category, brand, model, branch_id, base_rate, status)
SELECT 'TN23CD5678', 'Sedan', 'Honda', 'City', @vellore_branch, 2500.00, 'Available'
WHERE NOT EXISTS (SELECT 1 FROM VEHICLE WHERE reg_number = 'TN23CD5678');

INSERT INTO VEHICLE (reg_number, category, brand, model, branch_id, base_rate, status)
SELECT 'TN01EF9012', 'SUV', 'Hyundai', 'Creta', @chennai_branch, 3000.00, 'Available'
WHERE NOT EXISTS (SELECT 1 FROM VEHICLE WHERE reg_number = 'TN01EF9012');

INSERT INTO VEHICLE (reg_number, category, brand, model, branch_id, base_rate, status)
SELECT 'TN01GH3456', 'Luxury', 'BMW', 'X5', @chennai_branch, 6000.00, 'Available'
WHERE NOT EXISTS (SELECT 1 FROM VEHICLE WHERE reg_number = 'TN01GH3456');

INSERT INTO DRIVER (driver_name, license_no, branch_id, rating)
SELECT 'Arun Kumar', 'DL10001', @vellore_branch, 4.50
WHERE NOT EXISTS (SELECT 1 FROM DRIVER WHERE license_no = 'DL10001');

INSERT INTO DRIVER (driver_name, license_no, branch_id, rating)
SELECT 'Rahul Sharma', 'DL10002', @chennai_branch, 4.80
WHERE NOT EXISTS (SELECT 1 FROM DRIVER WHERE license_no = 'DL10002');

INSERT INTO CUSTOMER (first_name, last_name, email, license_no)
SELECT 'Dhanush', 'Koti', 'dhanush@example.com', 'CL10001'
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER WHERE email = 'dhanush@example.com');

INSERT INTO CUSTOMER (first_name, last_name, email, license_no)
SELECT 'Inderdeep', 'Singh', 'inderdeep@example.com', 'CL10002'
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER WHERE email = 'inderdeep@example.com');

INSERT INTO CUSTOMER (first_name, last_name, email, license_no)
SELECT 'Arjun', 'Reddy', 'arjun@example.com', 'CL10003'
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER WHERE email = 'arjun@example.com');

SET @customer_one = (SELECT customer_id FROM CUSTOMER WHERE email = 'dhanush@example.com');
SET @customer_two = (SELECT customer_id FROM CUSTOMER WHERE email = 'inderdeep@example.com');
SET @customer_three = (SELECT customer_id FROM CUSTOMER WHERE email = 'arjun@example.com');

SET @vehicle_economy = (SELECT vehicle_id FROM VEHICLE WHERE reg_number = 'TN23AB1234');
SET @vehicle_sedan = (SELECT vehicle_id FROM VEHICLE WHERE reg_number = 'TN23CD5678');
SET @vehicle_suv = (SELECT vehicle_id FROM VEHICLE WHERE reg_number = 'TN01EF9012');

SET @driver_vellore = (SELECT driver_id FROM DRIVER WHERE license_no = 'DL10001');
SET @driver_chennai = (SELECT driver_id FROM DRIVER WHERE license_no = 'DL10002');

INSERT IGNORE INTO CUSTOMER_PHONE (customer_id, phone_number) VALUES
(@customer_one, '9000000001'),
(@customer_one, '9000000002'),
(@customer_two, '9000000003'),
(@customer_three, '9000000004');

INSERT INTO BOOKING (
    customer_id, vehicle_id, driver_id, start_date, due_date, booking_status
)
SELECT @customer_one, @vehicle_economy, NULL, '2026-10-20', '2026-10-22', 'Active'
WHERE NOT EXISTS (
    SELECT 1 FROM BOOKING
    WHERE customer_id = @customer_one
      AND vehicle_id = @vehicle_economy
      AND start_date = '2026-10-20'
);

SET @completed_booking = (
    SELECT booking_id FROM BOOKING
    WHERE customer_id = @customer_one
      AND vehicle_id = @vehicle_economy
      AND start_date = '2026-10-20'
    ORDER BY booking_id LIMIT 1
);

UPDATE BOOKING
SET return_date = '2026-10-23', booking_status = 'Completed'
WHERE booking_id = @completed_booking
  AND booking_status = 'Active';

INSERT INTO BOOKING (
    customer_id, vehicle_id, driver_id, start_date, due_date, booking_status
)
SELECT @customer_two, @vehicle_sedan, @driver_vellore, '2026-11-01', '2026-11-05', 'Active'
WHERE NOT EXISTS (
    SELECT 1 FROM BOOKING
    WHERE customer_id = @customer_two
      AND vehicle_id = @vehicle_sedan
      AND start_date = '2026-11-01'
);

SET @active_booking = (
    SELECT booking_id FROM BOOKING
    WHERE customer_id = @customer_two
      AND vehicle_id = @vehicle_sedan
      AND start_date = '2026-11-01'
    ORDER BY booking_id LIMIT 1
);

INSERT IGNORE INTO PAYMENT (booking_id, payment_id, amount, payment_mode)
VALUES (@completed_booking, 1, 4500.00, 'UPI');

INSERT IGNORE INTO PAYMENT (booking_id, payment_id, amount, payment_mode)
VALUES (@active_booking, 1, 3000.00, 'Cash');

INSERT INTO MAINTENANCE (vehicle_id, maintenance_id, service_date, cost)
SELECT @vehicle_suv, 1, '2026-10-25', 2500.00
WHERE NOT EXISTS (
    SELECT 1 FROM MAINTENANCE
    WHERE vehicle_id = @vehicle_suv AND maintenance_id = 1
);
