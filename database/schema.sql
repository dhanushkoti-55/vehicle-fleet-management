CREATE DATABASE IF NOT EXISTS vehicle_fleet_db;
USE vehicle_fleet_db;

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

CREATE TABLE BRANCH (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    phone VARCHAR(15) NOT NULL
);

CREATE TABLE VEHICLE (
    vehicle_id INT AUTO_INCREMENT PRIMARY KEY,
    reg_number VARCHAR(20) NOT NULL UNIQUE,
    category ENUM('Economy','Sedan','SUV','Luxury') NOT NULL,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    branch_id INT NOT NULL,
    base_rate DECIMAL(10,2) NOT NULL CHECK (base_rate > 0),
    status ENUM('Available','Rented','Maintenance') NOT NULL DEFAULT 'Available',
    FOREIGN KEY (branch_id) REFERENCES BRANCH(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE DRIVER (
    driver_id INT AUTO_INCREMENT PRIMARY KEY,
    driver_name VARCHAR(100) NOT NULL,
    license_no VARCHAR(30) NOT NULL UNIQUE,
    branch_id INT NOT NULL,
    rating DECIMAL(3,2) NOT NULL DEFAULT 5.00
        CHECK (rating BETWEEN 1.00 AND 5.00),
    FOREIGN KEY (branch_id) REFERENCES BRANCH(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE CUSTOMER (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    license_no VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE CUSTOMER_PHONE (
    customer_id INT NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    PRIMARY KEY (customer_id, phone_number),
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE BOOKING (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    vehicle_id INT NOT NULL,
    driver_id INT NULL,
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE NULL,
    booking_status ENUM('Pending','Active','Completed','Cancelled')
        NOT NULL DEFAULT 'Pending',
    CHECK (due_date >= start_date),
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (vehicle_id) REFERENCES VEHICLE(vehicle_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (driver_id) REFERENCES DRIVER(driver_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE PAYMENT (
    booking_id INT NOT NULL,
    payment_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_mode ENUM('Cash','Credit Card','Debit Card','UPI') NOT NULL,
    PRIMARY KEY (booking_id, payment_id),
    FOREIGN KEY (booking_id) REFERENCES BOOKING(booking_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE MAINTENANCE (
    vehicle_id INT NOT NULL,
    maintenance_id INT NOT NULL,
    service_date DATE NOT NULL,
    cost DECIMAL(10,2) NOT NULL CHECK (cost >= 0),
    PRIMARY KEY (vehicle_id, maintenance_id),
    FOREIGN KEY (vehicle_id) REFERENCES VEHICLE(vehicle_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE PENALTY (
    booking_id INT NOT NULL,
    penalty_id INT NOT NULL,
    reason VARCHAR(200) NOT NULL,
    penalty_amount DECIMAL(10,2) NOT NULL CHECK (penalty_amount >= 0),
    PRIMARY KEY (booking_id, penalty_id),
    FOREIGN KEY (booking_id) REFERENCES BOOKING(booking_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE VIEW vw_booking_amount AS
SELECT
    b.booking_id,
    ROUND(
        v.base_rate * (DATEDIFF(b.due_date, b.start_date) + 1)
        * CASE
            WHEN v.category = 'SUV' THEN 1.25
            WHEN v.category = 'Luxury' THEN 1.75
            ELSE 1.00
        END
        + CASE
            WHEN b.driver_id IS NOT NULL
            THEN 500.00 * (DATEDIFF(b.due_date, b.start_date) + 1)
            ELSE 0
        END,
        2
    ) AS total_amount
FROM BOOKING b
JOIN VEHICLE v ON b.vehicle_id = v.vehicle_id;

CREATE INDEX idx_vehicle_cat_status_rate ON VEHICLE(category, status, base_rate);
CREATE INDEX idx_booking_cust_status ON BOOKING(customer_id, booking_status, due_date);
CREATE INDEX idx_customer_lookup ON CUSTOMER(email, license_no);
