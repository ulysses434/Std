CREATE SCHEMA IF NOT EXISTS dw;

CREATE TABLE dw."user" (
    id int PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS product (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10, 2),
    picture_url VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS "order" (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES product(id),
    quantity INT,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);