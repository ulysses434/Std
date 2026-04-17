CREATE INDEX idx_orders_product_id ON "order"(product_id);
CREATE INDEX idx_orders_order_date ON "order"(order_date);
CREATE INDEX idx_products_name ON product(name);