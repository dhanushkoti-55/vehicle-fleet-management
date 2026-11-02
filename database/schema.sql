CREATE DATABASE IF NOT EXISTS vehicle_fleet_db;
USE vehicle_fleet_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS vw_vehicle_utilization;
DROP VIEW IF EXISTS vw_customer_total_spent;
DROP VIEW IF EXISTS vw_available_fleet;
DROP VIEW IF EXISTS vw_booking_amount;
DROP TABLE IF EXISTS PENALTY;
DROP TABLE IF EXISTS MAINTENANCE;
DROP TABLE IF EXISTS PAYMENT;
DROP TABLE IF EXISTS BOOKING;
DROP TABLE IF EXISTS CUSTOMER_PHONE;
DROP TABLE IF EXISTS CUSTOMER;
DROP TABLE IF EXISTS DRIVER;
DROP TABLE IF EXISTS VEHICLE;
DROP TABLE IF EXISTS BRANCH;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE BRANCH (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    phone VARCHAR(15) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE VEHICLE (
    vehicle_id INT AUTO_INCREMENT PRIMARY KEY,
    reg_number VARCHAR(20) NOT NULL UNIQUE,
    category ENUM('Economy','Sedan','SUV','Luxury') NOT NULL,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    branch_id INT NOT NULL,
    base_rate DECIMAL(10,2) NOT NULL,
    status ENUM('Available','Rented','Maintenance') NOT NULL DEFAULT 'Available',
    CONSTRAINT chk_vehicle_base_rate CHECK (base_rate > 0),
    CONSTRAINT fk_vehicle_branch FOREIGN KEY (branch_id) REFERENCES BRANCH(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_vehicle_cat_status_rate (category, status, base_rate),
    INDEX idx_vehicle_branch (branch_id)
) ENGINE=InnoDB;

CREATE TABLE DRIVER (
    driver_id INT AUTO_INCREMENT PRIMARY KEY,
    driver_name VARCHAR(100) NOT NULL,
    license_no VARCHAR(30) NOT NULL UNIQUE,
    branch_id INT NOT NULL,
    rating DECIMAL(3,2) NOT NULL DEFAULT 5.00,
    CONSTRAINT chk_driver_rating CHECK (rating BETWEEN 1.00 AND 5.00),
    CONSTRAINT fk_driver_branch FOREIGN KEY (branch_id) REFERENCES BRANCH(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE CUSTOMER (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    license_no VARCHAR(30) NOT NULL UNIQUE,
    INDEX idx_customer_lookup (email, license_no)
) ENGINE=InnoDB;

CREATE TABLE CUSTOMER_PHONE (
    customer_id INT NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    PRIMARY KEY (customer_id, phone_number),
    CONSTRAINT fk_customer_phone_customer FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE BOOKING (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    vehicle_id INT NOT NULL,
    driver_id INT NULL,
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE NULL,
    booking_status ENUM('Pending','Active','Completed','Cancelled') NOT NULL DEFAULT 'Pending',
    CONSTRAINT chk_booking_dates CHECK (due_date >= start_date),
    CONSTRAINT chk_booking_return_date CHECK (return_date IS NULL OR return_date >= start_date),
    CONSTRAINT fk_booking_customer FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_booking_vehicle FOREIGN KEY (vehicle_id) REFERENCES VEHICLE(vehicle_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_booking_driver FOREIGN KEY (driver_id) REFERENCES DRIVER(driver_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_booking_cust_status (customer_id, booking_status, due_date),
    INDEX idx_booking_vehicle_status (vehicle_id, booking_status, start_date, due_date)
) ENGINE=InnoDB;

CREATE TABLE PAYMENT (
    booking_id INT NOT NULL,
    payment_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_mode ENUM('Cash','Credit Card','Debit Card','UPI') NOT NULL,
    PRIMARY KEY (booking_id, payment_id),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES BOOKING(booking_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE MAINTENANCE (
    vehicle_id INT NOT NULL,
    maintenance_id INT NOT NULL,
    service_date DATE NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (vehicle_id, maintenance_id),
    CONSTRAINT chk_maintenance_cost CHECK (cost >= 0),
    CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id) REFERENCES VEHICLE(vehicle_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE PENALTY (
    booking_id INT NOT NULL,
    penalty_id INT NOT NULL,
    reason VARCHAR(200) NOT NULL,
    penalty_amount DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (booking_id, penalty_id),
    CONSTRAINT chk_penalty_amount CHECK (penalty_amount >= 0),
    CONSTRAINT fk_penalty_booking FOREIGN KEY (booking_id) REFERENCES BOOKING(booking_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW vw_booking_amount AS
SELECT b.booking_id,
       ROUND(v.base_rate * (DATEDIFF(b.due_date, b.start_date) + 1)
       * CASE v.category WHEN 'SUV' THEN 1.25 WHEN 'Luxury' THEN 1.75 ELSE 1.00 END
       + CASE WHEN b.driver_id IS NOT NULL
              THEN 500.00 * (DATEDIFF(b.due_date, b.start_date) + 1) ELSE 0 END, 2) AS total_amount
FROM BOOKING b
JOIN VEHICLE v ON v.vehicle_id = b.vehicle_id;

CREATE OR REPLACE VIEW vw_available_fleet AS
SELECT v.vehicle_id, v.reg_number, v.category, v.brand, v.model, v.base_rate,
       br.branch_name, br.city AS branch_city, br.phone AS branch_phone
FROM VEHICLE v
JOIN BRANCH br ON br.branch_id = v.branch_id
WHERE v.status = 'Available';

CREATE OR REPLACE VIEW vw_customer_total_spent AS
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       COALESCE(SUM(p.amount), 0.00) AS total_spent
FROM CUSTOMER c
LEFT JOIN BOOKING b ON b.customer_id = c.customer_id
LEFT JOIN PAYMENT p ON p.booking_id = b.booking_id
GROUP BY c.customer_id, c.first_name, c.last_name;

CREATE OR REPLACE VIEW vw_vehicle_utilization AS
SELECT v.vehicle_id, v.reg_number,
       ROUND(COALESCE(SUM(DATEDIFF(b.due_date, b.start_date) + 1), 0) / 365 * 100, 2) AS utilization_rate
FROM VEHICLE v
LEFT JOIN BOOKING b ON b.vehicle_id = v.vehicle_id
    AND b.booking_status IN ('Active','Completed')
    AND b.start_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
GROUP BY v.vehicle_id, v.reg_number;
