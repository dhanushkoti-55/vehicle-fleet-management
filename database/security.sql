USE vehicle_fleet_db;

-- Run this script as a database administrator.
-- Create login accounts separately and assign one of these roles to each account.
CREATE ROLE IF NOT EXISTS 'rental_clerk_role';
CREATE ROLE IF NOT EXISTS 'fleet_manager_role';
CREATE ROLE IF NOT EXISTS 'workshop_supervisor_role';
CREATE ROLE IF NOT EXISTS 'customer_portal_role';

-- Rental desk: customer registration, booking/payment workflows and read-only fleet catalog.
GRANT SELECT, INSERT, UPDATE ON vehicle_fleet_db.CUSTOMER TO 'rental_clerk_role';
GRANT SELECT, INSERT, UPDATE ON vehicle_fleet_db.CUSTOMER_PHONE TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.VEHICLE TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.BRANCH TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.DRIVER TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.BOOKING TO 'rental_clerk_role';
GRANT UPDATE (return_date, booking_status) ON vehicle_fleet_db.BOOKING TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.PAYMENT TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.PENALTY TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.vw_available_fleet TO 'rental_clerk_role';
GRANT SELECT ON vehicle_fleet_db.vw_booking_amount TO 'rental_clerk_role';
GRANT EXECUTE ON PROCEDURE vehicle_fleet_db.sp_create_rental_booking TO 'rental_clerk_role';
GRANT EXECUTE ON PROCEDURE vehicle_fleet_db.sp_record_payment TO 'rental_clerk_role';

-- Fleet manager: fleet, driver, booking, maintenance, payment and penalty reporting.
GRANT SELECT ON vehicle_fleet_db.* TO 'fleet_manager_role';
GRANT INSERT, UPDATE ON vehicle_fleet_db.VEHICLE TO 'fleet_manager_role';
GRANT INSERT, UPDATE ON vehicle_fleet_db.DRIVER TO 'fleet_manager_role';
GRANT UPDATE ON vehicle_fleet_db.BOOKING TO 'fleet_manager_role';
GRANT EXECUTE ON PROCEDURE vehicle_fleet_db.sp_create_rental_booking TO 'fleet_manager_role';
GRANT EXECUTE ON PROCEDURE vehicle_fleet_db.sp_record_payment TO 'fleet_manager_role';
GRANT EXECUTE ON PROCEDURE vehicle_fleet_db.sp_list_overdue_bookings TO 'fleet_manager_role';

-- Workshop supervisor: maintenance logging and status restoration only.
GRANT SELECT ON vehicle_fleet_db.BRANCH TO 'workshop_supervisor_role';
GRANT SELECT ON vehicle_fleet_db.VEHICLE TO 'workshop_supervisor_role';
GRANT SELECT, INSERT ON vehicle_fleet_db.MAINTENANCE TO 'workshop_supervisor_role';
GRANT UPDATE (status) ON vehicle_fleet_db.VEHICLE TO 'workshop_supervisor_role';
GRANT EXECUTE ON PROCEDURE vehicle_fleet_db.sp_log_maintenance TO 'workshop_supervisor_role';

-- Customer portal: catalog and derived booking totals only.
GRANT SELECT ON vehicle_fleet_db.vw_available_fleet TO 'customer_portal_role';
GRANT SELECT ON vehicle_fleet_db.vw_booking_amount TO 'customer_portal_role';

-- Example account provisioning (replace the password with a unique secret):
-- CREATE USER 'rental_clerk'@'%' IDENTIFIED BY 'REPLACE_WITH_STRONG_PASSWORD';
-- GRANT 'rental_clerk_role' TO 'rental_clerk'@'%';
-- SET DEFAULT ROLE 'rental_clerk_role' TO 'rental_clerk'@'%';

SHOW GRANTS FOR 'rental_clerk_role';
SHOW GRANTS FOR 'fleet_manager_role';
SHOW GRANTS FOR 'workshop_supervisor_role';
SHOW GRANTS FOR 'customer_portal_role';
