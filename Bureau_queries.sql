CREATE DATABASE IF NOT EXISTS bureau;
USE bureau;
CREATE TABLE booking (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id VARCHAR(255) UNIQUE,
    mode_of_shipment_id INT,
    port_of_departure VARCHAR(255),
    date_of_departure DATE,
    port_of_discharge VARCHAR(255),
    date_of_discharge DATE
);
CREATE TABLE customer (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(255) UNIQUE,
    country_name VARCHAR(255)
);
CREATE TABLE customer_invoice_head (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id VARCHAR(255) UNIQUE,
    invoice_sent_date DATE,
    invoice_due_date DATE,
    invoice_paid_date DATE
);
CREATE TABLE customer_invoice_body (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id VARCHAR(255),
    customer_id INT,
    invoice_currency VARCHAR(255),
    purchase_order_ref VARCHAR(255),
    UNIQUE (booking_id, invoice_currency),
    FOREIGN KEY (booking_id) REFERENCES booking(booking_id),
    FOREIGN KEY (customer_id) REFERENCES customer(id)
);
CREATE TABLE customer_invoice_leg (
    id INT AUTO_INCREMENT PRIMARY KEY,
    leg_name VARCHAR(255),
    original_currency VARCHAR(255),
    amount_in_original_currency FLOAT,
    amount_in_invoice_currency FLOAT
);
CREATE TABLE customer_invoice_relationships (
    id INT AUTO_INCREMENT PRIMARY KEY,
    head_id INT,
    body_id INT,
    leg_id INT,
    FOREIGN KEY (head_id) REFERENCES customer_invoice_head(id),
    FOREIGN KEY (body_id) REFERENCES customer_invoice_body(id),
    FOREIGN KEY (leg_id) REFERENCES customer_invoice_leg(id)
);
-- Insert data into Booking Table
INSERT INTO booking (booking_id, mode_of_shipment_id, port_of_departure, date_of_departure, port_of_discharge, date_of_discharge)
VALUES
    ('B001', 3, 'PortA', '2021-01-05', 'PortB', '2021-01-15'),
    ('B002', 1, 'PortX', '2021-01-10', 'PortY', '2021-01-20');
    
-- Insert data into Customer Table
INSERT INTO customer (customer_name, country_name)
VALUES
    ('FurniturePlus', 'CountryA'),
    ('ElectroMart', 'CountryB');

-- Insert data into Customer_Invoice_Head Table
INSERT INTO customer_invoice_head (invoice_id, invoice_sent_date, invoice_due_date, invoice_paid_date)
VALUES
    ('INV001', '2021-01-01', '2021-01-15', '2021-01-10'),
    ('INV002', '2021-01-05', '2021-01-20', '2021-01-18');

-- Insert data into Customer_Invoice_Body Table
INSERT INTO customer_invoice_body (booking_id, customer_id, invoice_currency, purchase_order_ref)
VALUES
    ('B001', 1, 'GBP', 'PO001'),
    ('B002', 2, 'USD', 'PO002');

-- Insert data into Customer_Invoice_Leg Table
INSERT INTO customer_invoice_leg (leg_name, original_currency, amount_in_original_currency, amount_in_invoice_currency)
VALUES
    ('Leg1', 'GBP', 500.00, 500.00),
    ('Leg2', 'USD', 750.00, 750.00);

-- Insert data into Customer_Invoice_Relationships Table
INSERT INTO customer_invoice_relationships (head_id, body_id, leg_id)
VALUES
    (1, 1, 1),
    (2, 2, 2);
SHOW TABLES;
DESCRIBE booking;
SHOW CREATE TABLE booking;

-- Q1. List of booking id that was shipped by Air with departure date in Jan 2021.
SELECT booking_id
FROM booking
WHERE mode_of_shipment_id = 3 -- Air
AND MONTH(date_of_departure) = 1 AND YEAR(date_of_departure) = 2021;


-- Q2.List the number of bookings by each mode of shipment id with departure date in Jan 2021.
SELECT mode_of_shipment_id, COUNT(*) AS num_bookings
FROM booking
WHERE MONTH(date_of_departure) = 1 AND YEAR(date_of_departure) = 2021
GROUP BY mode_of_shipment_id;


-- Q3.List the bookings (by booking_id) invoiced to FurniturePlus (customer id: 214598) that departed in Jan 2021.
SELECT b.booking_id
FROM booking b
JOIN customer_invoice_body cib ON b.booking_id = cib.booking_id
WHERE cib.customer_id = 214598
AND MONTH(b.date_of_departure) = 1 AND YEAR(b.date_of_departure) = 2021;

    
-- Q4. List the highest valued 10 invoices (by invoice_id) invoiced in GBP that were sent in Jan 2021.
SELECT cib.booking_id, cih.invoice_id
FROM customer_invoice_body cib
JOIN customer_invoice_head cih ON cib.id = cih.id
WHERE cib.invoice_currency = 'GBP'
ORDER BY (
    SELECT amount_in_invoice_currency
    FROM customer_invoice_leg cil
    JOIN customer_invoice_relationships cir ON cil.id = cir.leg_id
    WHERE cib.id = cir.body_id
) DESC
LIMIT 10;


-- Q5. Return the list of customer names that had more than 10 unique invoices sent in Jan 2021.
SELECT c.customer_name
FROM customer c
JOIN customer_invoice_body cib ON c.id = cib.customer_id
JOIN customer_invoice_relationships cir ON cib.id = cir.body_id
JOIN customer_invoice_head ci ON cir.head_id = ci.id
WHERE MONTH(ci.invoice_sent_date) = 1 AND YEAR(ci.invoice_sent_date) = 2021
GROUP BY c.customer_name
HAVING COUNT(DISTINCT ci.invoice_id) > 10;

-- Q6. Return the the list of legs and the amount invoiced to each leg in invoice currency of FurniturePlus’ (customer id: 214598) first ever created shipment. Hint: the integer id in the booking table is unique and auto-increment.
SELECT cr.leg_id, cil.leg_name, SUM(cil.amount_in_invoice_currency) AS total_amount
FROM customer_invoice_relationships cr
JOIN customer_invoice_leg cil ON cr.leg_id = cil.id
JOIN customer_invoice_body cib ON cr.body_id = cib.id
WHERE cib.customer_id = 214598
GROUP BY cr.leg_id, cil.leg_name
ORDER BY total_amount ASC -- or DESC depending on your requirement
LIMIT 1;

-- Q7. Return the list of the top 10 customers, in descending order, by sales (in invoice currency) invoiced in GBP in Jan 2021. In addition, for each of these customers, return the next customer (by sales in invoice currency) from the same country, the amount of sales, and the difference in sales between the current and the next customer from the same country:
WITH CustomerSales AS (
    SELECT
        c.customer_name,
        c.country_name,
        SUM(cil.amount_in_invoice_currency) AS total_sales,
        ROW_NUMBER() OVER (PARTITION BY c.country_name ORDER BY SUM(cil.amount_in_invoice_currency) DESC) AS country_rank
    FROM
        customer c
    JOIN customer_invoice_body cib ON c.id = cib.customer_id
    JOIN customer_invoice_relationships cir ON cib.id = cir.body_id
    JOIN customer_invoice_leg cil ON cir.leg_id = cil.id
    JOIN customer_invoice_head cih ON cir.head_id = cih.id
    WHERE
        cih.invoice_currency = 'GBP'
        AND MONTH(cih.invoice_sent_date) = 1 AND YEAR(cih.invoice_sent_date) = 2021
    GROUP BY
        c.customer_name, c.country_name
)
SELECT
    cs1.customer_name,
    cs1.total_sales,
    cs2.customer_name AS lag_customer_name_same_country,
    cs2.total_sales AS lag_total_sales_same_country,
    cs1.total_sales - cs2.total_sales AS difference_in_sales
FROM
    CustomerSales cs1
LEFT JOIN
    CustomerSales cs2 ON cs1.country_name = cs2.country_name AND cs1.country_rank = cs2.country_rank + 1
WHERE
    cs1.country_rank <= 10
ORDER BY
    cs1.total_sales DESC;
