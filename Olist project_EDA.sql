-- BUSINESS OVERVIEW
-- total payment
SELECT SUM(payment_value) AS total_payment
FROM olist_order_payments
--> the total sales of Olist was about R$16.01M 

-- total shipping fee
SELECT SUM(freight_value) AS total_shipping_fee
FROM olist_order_items
--> the total shipping fee was about R$2.25M

-- total prices 
SELECT SUM(price) AS total_price
FROM olist_order_items
--> the total price was about R$13.59

-- total charge 
SELECT SUM(freight_value + price) AS total_charge
FROM olist_order_items
--> the total charge of all orders was about R$1.58M

-- average order value (revenue/total orders)
SELECT SUM(freight_value + price) / (SELECT COUNT (DISTINCT order_id) FROM olist_orders) AS avg_order_value 
FROM olist_order_items
--> the average order value was R$160

-- top products by units sold
SELECT TOP 10 b.product_category_name_english, COUNT(a.order_id) AS units_sold
FROM olist_order_items AS a
INNER JOIN olist_products_en AS b ON a.product_id = b.product_id
GROUP BY b.product_category_name_english
ORDER BY units_sold DESC
--> the top 3 best selling products are bed bath table, health beauty and sports leisure

-- average delivery time (TBC)
SELECT DATEDIFF(day, order_approved_at, order_delivered_customer_date) AS avg_delivery_time, COUNT(order_id) AS no_of_orders,
CAST(ROUND(COUNT(order_id) * 100.0 / (SUM(COUNT(order_id)) OVER ()), 2) AS DECIMAL(5,2)) as pct_delivery_time
FROM olist_orders
GROUP BY DATEDIFF(day, order_approved_at, order_delivered_customer_date)
ORDER BY pct_delivery_time DESC
--> some erroneous data since the products were delivered before they are even approved (negative values); most of the orders were delivered within 10 days

-- actual versus estimated delivery time 
SELECT DATEDIFF(day, order_delivered_customer_date, order_estimated_delivery_date) AS date_diff, COUNT(order_id) AS no_of_orders,
CAST(ROUND(COUNT(order_id) * 100.0 / (SUM(COUNT(order_id)) OVER ()), 2) AS DECIMAL(5,2)) as pct_date_diff,
CASE 
        WHEN DATEDIFF(day, order_delivered_customer_date, order_estimated_delivery_date) > 0 or DATEDIFF(day, order_delivered_customer_date, order_estimated_delivery_date) = 0 THEN 'on_time'
        WHEN DATEDIFF(day, order_delivered_customer_date, order_estimated_delivery_date) < 0 THEN 'late'
    END AS status
FROM olist_orders
GROUP BY DATEDIFF(day, order_delivered_customer_date, order_estimated_delivery_date)
ORDER BY date_diff
--> most of the orders were delivered 2 weeks earlier than the estimated delivery date

-- rate of successful delivery rate 
SELECT order_status, COUNT(order_id) AS no_of_orders, 
CAST(ROUND(COUNT(order_id) * 100.0 / (SUM(COUNT(order_id)) OVER ()), 2) AS DECIMAL(5,2)) as pct_delivery
FROM olist_orders
GROUP BY order_status
ORDER BY no_of_orders DESC 
--> most of the orders were delivered successfully, only some shipped without being received and cancelled

-- CUSTOMER ANALYSIS
-- top customers (sorted by revenue) 
SELECT TOP 10 c.customer_unique_id, SUM(a.payment_value) AS total_sales
FROM olist_order_payments AS a
INNER JOIN olist_orders AS b ON a.order_id = b.order_id
INNER JOIN olist_customers AS c ON b.customer_id = c.customer_id
GROUP BY c.customer_unique_id
ORDER BY total_sales DESC
--> 0a0a92112bd4c708ca5fde585afaa872, 46450c74a0d8c5ca9395da1daac6c120 and da122df9eeddfedc1dc1f5349a1a690c were the customers who contributed most to the total sales of Olist

-- customer stisfaction analysis (based on products) -> use OVER() to calculate a column of total and then proceed, CAST and ROUND to take decimal places
SELECT a.review_score, c.product_category_name_english, COUNT(a.review_id) AS no_of_reviews,
CAST(ROUND(COUNT(a.review_id) * 100.0 /SUM(COUNT(a.review_id)) OVER (), 2) AS DECIMAL(5,2)) AS pct_review
FROM olist_order_reviews AS a
INNER JOIN olist_order_items AS b ON a.order_id = b.order_id
INNER JOIN olist_products_en AS c ON b.product_id = c.product_id
GROUP BY a.review_score, c.product_category_name_english
ORDER BY no_of_reviews DESC

-- customer satisfaction anlysis (based on delivery time)
SELECT b.review_score, DATEDIFF(day, a.order_approved_at, a.order_delivered_customer_date) AS avg_delivery_time, COUNT(a.order_id) AS no_of_orders
FROM olist_orders AS a
INNER JOIN olist_order_reviews AS b ON a.order_id = b.order_id
GROUP BY b.review_score, DATEDIFF(day, a.order_approved_at, a.order_delivered_customer_date)
ORDER BY b.review_score DESC
--> the longer the delivery day, the lower the review score 

-- online store viist by locations
SELECT customer_state, COUNT(customer_unique_id) AS no_of_customers
FROM olist_customers
GROUP BY customer_state
ORDER BY no_of_customers DESC
--> most customers come from Sao Paulo, Rio de Jainero and Madagascar

-- numbers of payment 
SELECT payment_type, COUNT(order_id) AS no_of_payment, 
CAST(ROUND(COUNT(order_id) * 100.0 /SUM(COUNT(order_id)) OVER (), 2) AS DECIMAL(5,2)) AS pct_payment
FROM olist_order_payments
GROUP BY payment_type
ORDER BY no_of_payment DESC
--> most of the orders were paid by credit cards and some by boleto

-- numbers of payment installments 
SELECT payment_installments, COUNT(order_id) AS no_of_payment_2
FROM olist_order_payments
GROUP BY payment_installments
ORDER BY no_of_payment_2 DESC
--> most customers who chose this type of payment paid off their charge withing a month

-- time of purchase (PBI)

-- PRODUCT ANALYSIS
-- ABC analysis (PBI)
SELECT c.product_category_name_english, SUM(b.price) AS value_by_product
FROM olist_order_payments AS a 
INNER JOIN olist_order_items AS b ON a.order_id = b.order_id
INNER JOIN olist_products_en AS c ON b.product_id = c.product_id
GROUP BY c.product_category_name_english
ORDER BY value_by_product DESC

-- products abandonment (order status == failed)
SELECT c.product_category_name_english, COUNT(a.order_id) AS no_of_abandonment
FROM olist_orders AS a 
INNER JOIN olist_order_items AS b ON a.order_id = b.order_id
INNER JOIN olist_products_en AS c ON b.product_id = c.product_id
WHERE order_status IN ('canceled', 'unavailable')
GROUP BY c.product_category_name_english
HAVING c.product_category_name_english IS NOT NULL
ORDER BY no_of_abandonment DESC

-- bought together products -> create view to get product names first and proceed with the next steps
GO
CREATE VIEW product_bundles AS 
SELECT a.*, b.product_category_name_english
FROM olist_order_items AS a 
INNER JOIN olist_products_en AS b ON a.product_id = b.product_id;
GO

SELECT TOP 20 pb1.product_category_name_english AS original_SKU, pb2.product_category_name_english AS bought_with, count(pb1.order_item_id) as times_bought_together
FROM product_bundles AS pb1
INNER JOIN product_bundles AS pb2 ON pb1.order_id = pb2.order_id
AND pb1.product_category_name_english != pb2.product_category_name_english
GROUP BY pb1.product_category_name_english, pb2.product_category_name_english
ORDER BY times_bought_together DESC

-- popular products based on geography 
SELECT a.customer_state, d.product_category_name_english, COUNT(b.order_id) AS no_of_products
FROM olist_customers AS a
INNER JOIN olist_orders AS b ON a.customer_id = b.customer_id
INNER JOIN olist_order_items AS c ON b.order_id = c.order_id
INNER JOIN olist_products_en AS d ON c.product_id = d.product_id
GROUP BY a.customer_state, d.product_category_name_english
ORDER BY no_of_products DESC

-- FOR POWER BI
-- create view for basket analysis
GO
CREATE VIEW top_combos AS 
SELECT TOP 30 pb1.product_category_name_english AS original_SKU, pb2.product_category_name_english AS bought_with, count(pb1.order_item_id) as times_bought_together
FROM product_bundles AS pb1
INNER JOIN product_bundles AS pb2 ON pb1.order_id = pb2.order_id
AND pb1.product_category_name_english != pb2.product_category_name_english
GROUP BY pb1.product_category_name_english, pb2.product_category_name_english
ORDER BY times_bought_together DESC
GO