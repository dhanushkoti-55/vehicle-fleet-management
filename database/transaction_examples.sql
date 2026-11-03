USE vehicle_fleet_db;

-- Reversible demonstration of SAVEPOINT and partial rollback.
START TRANSACTION;

SET @demo_driver_id = (
    SELECT driver_id
    FROM DRIVER
    ORDER BY driver_id
    LIMIT 1
);

SAVEPOINT before_demo_update;

UPDATE DRIVER
SET rating = CASE
    WHEN rating >= 5.00 THEN 4.90
    ELSE rating + 0.10
END
WHERE driver_id = @demo_driver_id;

SAVEPOINT after_demo_update;

-- Simulate an invalid second operation.
UPDATE DRIVER
SET rating = 99.00
WHERE driver_id = @demo_driver_id;

-- Discard the invalid operation, then restore the original value.
ROLLBACK TO SAVEPOINT after_demo_update;
ROLLBACK TO SAVEPOINT before_demo_update;
COMMIT;

SELECT driver_id, driver_name, rating
FROM DRIVER
WHERE driver_id = @demo_driver_id;
