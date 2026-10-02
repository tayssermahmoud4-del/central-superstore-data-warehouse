

SELECT COUNT(*)  FROM [CenterSupertoreDW].[dbo].[fact_order]

-- Total sales & profit per product
SELECT
    p.product_name
   ,SUM(f.sales) AS total_sales
   ,SUM(f.profit) AS total_profit
FROM dbo.fact_order f
JOIN dbo.dim_product p 
ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_sales DESC

--Total sales & profit per Sup_Category
SELECT
    p.sub_category
   ,SUM(f.sales) AS total_sales
   ,SUM(f.profit) AS total_profit
FROM dbo.fact_order f
JOIN dbo.dim_product p 
ON f.product_key = p.product_key
GROUP BY p.sub_category
ORDER BY total_sales DESC

--Total sales & profit per Category
SELECT
    p.category
   ,SUM(f.sales) AS total_sales
   ,SUM(f.profit) AS total_profit
FROM dbo.fact_order f
JOIN dbo.dim_product p 
ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_sales DESC

--classify order line
SELECT
    p.product_name
   ,f.profit
   ,CASE 
       WHEN profit < 0 THEN 'Loss'
       WHEN profit <= 1000 THEN 'Low profit'
       WHEN profit <= 5000 THEN 'Medium Profit'
       ELSE 'High Profit'
    END AS profit_tier
FROM dbo.fact_order f
JOIN dbo.dim_product p
ON p.product_key = f.product_key

--Products with above_avg profit
SELECT 
    p.sub_category
   ,AVG(f.profit) AS avg_product_profit
FROM dbo.fact_order f
JOIN dbo.dim_product p
ON f.product_key = p.product_key
GROUP BY p.sub_category
HAVING AVG(f.profit) > (
        SELECT 
            AVG(profit)
        FROM dbo.fact_order
        )

--Sales & order count by Customer Segment
SELECT 
    c.segment
   ,COUNT(DISTINCT f.order_id) AS order_count
   ,SUM(f.sales) AS total_sales
FROM dbo.fact_order f
JOIN dim_customer c
ON f.customer_key = c.customer_key
GROUP BY c.segment
ORDER BY total_sales DESC

--Top 10 customers by total sales
SELECT TOP 10
    c.customer_name
   ,SUM(f.sales) AS total_sales
FROM fact_order f
JOIN dim_customer c
ON f.customer_key = c.customer_key
GROUP BY c.customer_name
ORDER BY total_sales DESC

--Customers above the average spend, then classify them
WITH customer_sales AS (
    SELECT 
        c.customer_key
       ,c.customer_name
       ,SUM(f.sales) AS total_sales
    FROM fact_order f
    JOIN dim_customer c
    ON f.customer_key = c.customer_key
    GROUP BY c.customer_key , c.customer_name
)
SELECT 
    customer_name
   ,total_sales
   ,CASE
       WHEN total_sales >= 5000 THEN 'VIP'
       WHEN total_sales >= 1000 THEN 'Regular'
       ELSE 'Occasional'
    END AS customer_tier
FROM customer_sales
WHERE total_sales > (SELECT AVG(total_sales) 
                     FROM customer_sales )
ORDER BY total_sales DESC

--One-time vs repeat customers
SELECT
    c.customer_name
   ,COUNT(DISTINCT f.order_id) AS order_count
   ,CASE
        WHEN COUNT(DISTINCT f.order_id) = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type
FROM dbo.fact_order f
JOIN dbo.dim_customer c 
ON f.customer_key = c.customer_key
GROUP BY c.customer_name
ORDER BY order_count DESC

--Segment totals, then each segment's share of grand total
WITH segment_sales AS (
    SELECT 
        c.segment
       ,SUM(f.sales) AS segment_total
    FROM dbo.fact_order f
    JOIN dbo.dim_customer c
    ON f.customer_key = c.customer_key
    GROUP BY c.segment
),
grand_total AS (
    SELECT SUM(segment_total) AS company_total
    FROM segment_sales
)
SELECT
    s.segment
   ,s.segment_total
   ,s.segment_total * 100.0 / g.company_total AS pct_of_total_sales
FROM segment_sales s
CROSS JOIN grand_total g
ORDER BY pct_of_total_sales DESC

--Yearly sales trend
SELECT
    d.year
   ,SUM(f.sales)  AS total_sales
   ,SUM(f.profit) AS total_profit
FROM dbo.fact_order f
JOIN dbo.dim_date d 
ON f.order_date_key = d.date_key
GROUP BY d.year
ORDER BY d.year

--Monthly sales trend per year
SELECT
    d.month
   ,d.month_name
   ,d.year
   ,SUM(f.sales)  AS total_sales
   ,SUM(f.profit) AS total_profit
FROM dbo.fact_order f
JOIN dbo.dim_date d 
ON f.order_date_key = d.date_key
GROUP BY d.month_name , d.month , d.year
ORDER BY d.month , d.year

--Sales by Region
SELECT
    l.region
   ,SUM(f.sales)  AS total_sales
   ,SUM(f.profit) AS total_profit
   ,COUNT(DISTINCT f.order_id) AS order_count
FROM dbo.fact_order f
JOIN dbo.dim_location l 
ON f.location_key = l.location_key
GROUP BY l.region
ORDER BY total_sales DESC

--Month-over-month sales growth
WITH monthly_sales AS (
    SELECT
        d.year
       ,d.month
       ,SUM(f.sales) AS total_sales
    FROM dbo.fact_order f
    JOIN dbo.dim_date d ON f.order_date_key = d.date_key
    GROUP BY d.year, d.month
)
SELECT
    year
   ,month
   ,total_sales
   ,LAG(total_sales) OVER (ORDER BY year, month) AS prev_month_sales
   ,(total_sales - LAG(total_sales) OVER (ORDER BY year, month))
        * 100.0 / NULLIF(LAG(total_sales) OVER (ORDER BY year, month), 0) AS pct_growth
FROM monthly_sales
ORDER BY year, month

--Weekend vs weekday sales comparison
SELECT
    CASE 
        WHEN d.is_weekend = 1 THEN 'Weekend' 
        ELSE 'Weekday' 
    END AS day_type
   ,COUNT(DISTINCT f.order_id) AS order_count
   ,SUM(f.sales) AS total_sales
FROM dbo.fact_order f
JOIN dbo.dim_date d 
ON f.order_date_key = d.date_key
GROUP BY 
      CASE 
          WHEN d.is_weekend = 1 THEN 'Weekend' 
          ELSE 'Weekday' 
       END

      
--Discount impact on profit
SELECT
    CASE
        WHEN f.discount = 0 THEN 'No Discount'
        WHEN f.discount <= 0.2 THEN 'Low Discount'
        WHEN f.discount <= 0.5 THEN 'Medium Discount'
        ELSE 'High Discount'
    END AS discount_band
   ,COUNT(*) AS line_count
   ,AVG(f.profit) AS avg_profit
FROM dbo.fact_order f
GROUP BY 
    CASE
        WHEN f.discount = 0 THEN 'No Discount'
        WHEN f.discount <= 0.2 THEN 'Low Discount'
        WHEN f.discount <= 0.5 THEN 'Medium Discount'
        ELSE 'High Discount'
    END
ORDER BY avg_profit

--Monthly Sales and Profit Summary
CREATE VIEW dbo.vw_monthly_sales_kpi AS
SELECT
    d.year
   ,d.month
   ,d.month_name
   ,SUM(f.sales) AS total_sales
   ,SUM(f.profit) AS total_profit
   ,COUNT(DISTINCT f.order_id) AS order_count
FROM dbo.fact_order f
JOIN dbo.dim_date d 
ON f.order_date_key = d.date_key
GROUP BY d.year, d.month, d.month_name

--To retrieve the performance of a specific product or the top N customers using a parameter
CREATE PROCEDURE dbo.usp_top_customers @top_n INT = 10 AS
BEGIN
    SELECT TOP (@top_n)
        c.customer_name
       ,SUM(f.sales) AS total_sales
       ,SUM(f.profit) AS total_profit
    FROM dbo.fact_order f
    JOIN dbo.dim_customer c 
    ON f.customer_key = c.customer_key
    GROUP BY c.customer_name
    ORDER BY total_sales DESC
END