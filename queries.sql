-- ============================================================
-- Bubble Bliss Boba Shop SQL Analysis
-- Tools: BigQuery, Gemini AI
-- ============================================================
-- Note: Several queries were initially generated using Gemini AI
-- within BigQuery, then reviewed, edited, and refined for accuracy,
-- style consistency, and business relevance. This reflects a 
-- modern analyst workflow of AI-assisted query development.
-- ============================================================

-- ============================================================
-- PART A: BASIC EXPLORATION
-- ============================================================

-- Exercise 1: Get to know the menu
-- List all available menu items ordered by category and price
SELECT
  item_name,
  category,
  price,
  calories
FROM `bubble_bliss.menu_items`
WHERE is_available = TRUE
ORDER BY category, price DESC;


-- Exercise 2: Active vs. closed locations
-- Summary of active and inactive store locations
SELECT
  is_active,
  COUNT(*) AS location_count
FROM `bubble_bliss.locations`
GROUP BY is_active;


-- ============================================================
-- PART B: JOINS
-- ============================================================

-- Exercise 3: Customer order history
-- Orders with customer name and store city
SELECT
  c.first_name || ' ' || c.last_name AS customer_name,
  l.city                              AS store_city,
  DATE(o.order_datetime)              AS order_date,
  o.status,
  o.total_amount
FROM `bubble_bliss.orders` o
LEFT JOIN `bubble_bliss.customers` c  ON o.customer_id = c.customer_id
LEFT JOIN `bubble_bliss.locations` l  ON o.location_id = l.location_id
ORDER BY o.order_datetime DESC
LIMIT 20;


-- Exercise 4: What's in each order?
-- Line items for all completed orders across four joined tables
SELECT
  oi.order_id,
  c.first_name || ' ' || c.last_name AS customer_name,
  mi.item_name,
  mi.category,
  oi.quantity,
  oi.sweetness_level,
  oi.ice_level
FROM `bubble_bliss.order_items` oi
JOIN `bubble_bliss.orders`     o   ON oi.order_id   = o.order_id
JOIN `bubble_bliss.customers`  c   ON o.customer_id  = c.customer_id
JOIN `bubble_bliss.menu_items` mi  ON oi.item_id     = mi.item_id
WHERE o.status = 'completed'
ORDER BY oi.order_id;


-- ============================================================
-- PART C: AGGREGATIONS
-- ============================================================

-- Exercise 5: Revenue by location
-- Total revenue, order count, and average order value per active location
SELECT
  l.name                           AS location_name,
  l.city,
  COUNT(o.order_id)                AS total_orders,
  ROUND(SUM(o.total_amount), 2)    AS total_revenue,
  ROUND(AVG(o.total_amount), 2)    AS avg_order_value
FROM `bubble_bliss.orders` o
JOIN `bubble_bliss.locations` l ON o.location_id = l.location_id
WHERE o.status = 'completed'
  AND l.is_active = TRUE
GROUP BY l.name, l.city
ORDER BY total_revenue DESC;


-- Exercise 6: Top 5 most-ordered menu items
-- Items ranked by total quantity ordered across all orders
SELECT
  mi.item_name,
  mi.category,
  SUM(oi.quantity)            AS total_quantity_ordered,
  COUNT(DISTINCT oi.order_id) AS distinct_orders
FROM `bubble_bliss.order_items` oi
JOIN `bubble_bliss.menu_items` mi ON oi.item_id = mi.item_id
GROUP BY mi.item_name, mi.category
ORDER BY total_quantity_ordered DESC
LIMIT 5;


-- ============================================================
-- PART D: DATA QUALITY CHECKS
-- ============================================================

-- Exercise 7: Missing phone numbers
-- Count and percentage of customers missing a phone number
SELECT
  COUNTIF(phone IS NULL)                                         AS missing_phone,
  COUNTIF(phone IS NOT NULL)                                     AS has_phone,
  ROUND(COUNTIF(phone IS NULL) * 100.0 / COUNT(*), 1)           AS pct_missing
FROM `bubble_bliss.customers`;


-- Exercise 8: Orders placed at an inactive location
-- Data integrity check: orders that should not exist at a closed store
SELECT
  o.order_id,
  CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,
  l.name                                  AS location_name,
  DATE(o.order_datetime)                  AS order_date,
  o.total_amount
FROM `bubble_bliss.orders` AS o
INNER JOIN `bubble_bliss.customers` AS c ON o.customer_id = c.customer_id
INNER JOIN `bubble_bliss.locations` AS l ON o.location_id = l.location_id
WHERE l.is_active IS FALSE
ORDER BY o.order_date;


-- Exercise 9: Order items linked to discontinued menu items
-- Checks whether any line items reference unavailable menu items
SELECT
  oi.order_item_id  AS order_item_id,
  oi.order_id       AS order_id,
  mi.item_name      AS item_name,
  mi.category       AS category,
  mi.is_available   AS is_available
FROM `bubble_bliss.order_items` AS oi
JOIN `bubble_bliss.menu_items` AS mi ON oi.item_id = mi.item_id
WHERE mi.is_available IS FALSE;


-- ============================================================
-- PART E: DUPLICATE DETECTION
-- ============================================================

-- Exercise 10: Customers sharing the same email
-- Identifies duplicate accounts using email as the unique identifier
SELECT
  email,
  COUNT(customer_id)                                              AS account_count,
  STRING_AGG(CAST(customer_id AS STRING), ', ' ORDER BY customer_id) AS customer_id_list
FROM `bubble_bliss.customers`
GROUP BY email
HAVING COUNT(customer_id) > 1
ORDER BY account_count DESC, email ASC;


-- Exercise 11: Duplicate order rows
-- Finds order IDs that appear more than once in the orders table
SELECT
  order_id,
  COUNT(order_id)    AS occurrence_count,
  MAX(total_amount)  AS total_amount
FROM `bubble_bliss.orders`
GROUP BY order_id
HAVING COUNT(order_id) > 1
ORDER BY order_id;


-- Exercise 12: De-duplicate orders using ROW_NUMBER()
-- Keeps only the first occurrence of each order ID using a window function
WITH deduped AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_datetime) AS rn
  FROM `bubble_bliss.orders`
)
SELECT
  order_id,
  customer_id,
  location_id,
  order_datetime,
  status,
  total_amount,
  notes
FROM deduped
WHERE rn = 1
ORDER BY order_id;


-- ============================================================
-- PART F: TREND ANALYSIS
-- ============================================================

-- Exercise 13: Monthly revenue trend
-- Total revenue and order count by month for completed orders
SELECT
  FORMAT_TIMESTAMP('%Y-%m', order_datetime) AS order_month,
  ROUND(SUM(total_amount), 2)               AS total_revenue,
  COUNT(*)                                   AS order_count
FROM `bubble_bliss.orders`
WHERE status = 'completed'
GROUP BY order_month
ORDER BY order_month;


-- Exercise 14: Busiest day of the week
-- Order count by day of week, sorted chronologically Sunday to Saturday
SELECT
  FORMAT_TIMESTAMP('%A', order_datetime) AS day_of_week,
  COUNT(*)                               AS total_orders
FROM `bubble_bliss.orders`
WHERE status = 'completed'
GROUP BY day_of_week
ORDER BY MIN(FORMAT_TIMESTAMP('%w', order_datetime));


-- Exercise 15: New customer signups per quarter
-- Customer acquisition trend broken down by year and quarter
SELECT
  EXTRACT(YEAR    FROM join_date) AS year,
  EXTRACT(QUARTER FROM join_date) AS quarter,
  COUNT(*)                         AS signup_count
FROM `bubble_bliss.customers`
GROUP BY 1, 2
ORDER BY 1, 2;


-- ============================================================
-- PART G: ANOMALY DETECTION
-- ============================================================

-- Exercise 16: Orders with zero or suspicious totals
-- Flags all orders with $0.00 or unusually high amounts regardless of status
SELECT
  order_id,
  customer_id,
  location_id,
  DATE(order_datetime) AS order_date,
  total_amount,
  status,
  CASE
    WHEN total_amount = 0   THEN 'Zero-dollar order'
    WHEN total_amount > 200 THEN 'Unusually large order'
  END AS anomaly_flag
FROM `bubble_bliss.orders`
WHERE total_amount = 0 OR total_amount > 200
ORDER BY total_amount DESC;


-- Exercise 17: Statistical outliers using z-scores
-- Flags completed orders more than 2 standard deviations from the mean
WITH OrderStats AS (
  SELECT
    AVG(total_amount)    AS avg_amount,
    STDDEV(total_amount) AS stddev_amount
  FROM `bubble_bliss.orders`
  WHERE status = 'completed'
)
SELECT
  o.order_id,
  o.total_amount,
  ROUND(s.avg_amount, 2)    AS mean,
  ROUND(s.stddev_amount, 2) AS standard_deviation,
  ROUND((o.total_amount - s.avg_amount) / s.stddev_amount, 2) AS z_score
FROM `bubble_bliss.orders` AS o, OrderStats AS s
WHERE o.status = 'completed'
  AND ABS((o.total_amount - s.avg_amount) / s.stddev_amount) > 2;


-- ============================================================
-- PART H: CAPSTONE
-- ============================================================

-- Exercise 18: Executive summary report
-- Single CTE pipeline producing a full business summary per location
WITH
  location_revenue_orders AS (
    SELECT
      o.location_id,
      COUNT(DISTINCT o.order_id)    AS total_completed_orders,
      ROUND(SUM(o.total_amount), 2) AS total_revenue
    FROM `bubble_bliss.orders` AS o
    WHERE o.status = 'completed'
    GROUP BY o.location_id
  ),
  drink_popularity AS (
    SELECT
      o.location_id,
      mi.item_name,
      SUM(oi.quantity) AS total_quantity,
      ROW_NUMBER() OVER (
        PARTITION BY o.location_id
        ORDER BY SUM(oi.quantity) DESC
      ) AS rank_num
    FROM `bubble_bliss.orders` AS o
    JOIN `bubble_bliss.order_items` AS oi ON o.order_id  = oi.order_id
    JOIN `bubble_bliss.menu_items`  AS mi ON oi.item_id  = mi.item_id
    WHERE mi.category  = 'drink'
      AND o.status     = 'completed'
    GROUP BY 1, 2
  ),
  duplicate_orders AS (
    SELECT
      location_id,
      CASE
        WHEN LOGICAL_OR(order_count > 1) THEN 'Duplicates found'
        ELSE 'Clean'
      END AS data_quality_flag
    FROM (
      SELECT location_id, order_id, COUNT(*) AS order_count
      FROM `bubble_bliss.orders`
      GROUP BY 1, 2
    )
    GROUP BY 1
  )
SELECT
  l.name                                       AS location_name,
  l.city,
  l.is_active                                  AS active_status,
  COALESCE(lro.total_completed_orders, 0)      AS total_completed_orders,
  COALESCE(lro.total_revenue, 0)               AS total_revenue,
  dp.item_name                                 AS most_popular_drink,
  COALESCE(do.data_quality_flag, 'Clean')      AS data_quality_flag
FROM `bubble_bliss.locations` AS l
LEFT JOIN location_revenue_orders AS lro ON l.location_id = lro.location_id
LEFT JOIN drink_popularity        AS dp  ON l.location_id = dp.location_id AND dp.rank_num = 1
LEFT JOIN duplicate_orders        AS do  ON l.location_id = do.location_id
ORDER BY location_name;
