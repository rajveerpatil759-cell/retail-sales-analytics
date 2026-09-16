 ============================================================
--  SUPERSTORE SALES — SQL FOR POWER BI DASHBOARD
-- ============================================================
--  Database : superstore.db (PostgreSQL)
--  Tables   : customer_table, product_table, transaction_table
 
 
-- ============================================================
-- SECTION 1: TABLE CREATION
-- ============================================================
 
CREATE TABLE customer_table (
    Customer_ID    VARCHAR(30)  PRIMARY KEY,
    Customer_Name  VARCHAR(100) NOT NULL,
    Segment        VARCHAR(30),
    City           VARCHAR(50),
    State          VARCHAR(50),
    Postal_Code    VARCHAR(10),
    Region         VARCHAR(30)
);
 
CREATE TABLE product_table (
    Product_ID    VARCHAR(30)  PRIMARY KEY,
    Category      VARCHAR(30),
    Sub_Category  VARCHAR(30),
    Product_Name  VARCHAR(130)
);
 
CREATE TABLE transaction_table (
    Order_ID          VARCHAR(30)    NOT NULL,
    Order_Date        DATE           NOT NULL,
    Ship_Date         DATE,
    Ship_Mode         VARCHAR(30),
    Ship_Speed        VARCHAR(20),   
    Customer_ID       VARCHAR(30),
    Product_ID        VARCHAR(30)    NOT NULL,
    Sales             NUMERIC(10,2)  NOT NULL CHECK (Sales > 0),
    Quantity          INT            NOT NULL CHECK (Quantity > 0),
    Discount          NUMERIC(5,2),
    Profit            NUMERIC(10,2),

    Profit_Margin_Pct NUMERIC(10,2),
    Delivery_Days     INT,
    Discount_Band     VARCHAR(20),
    Order_Year        INT,
    Order_Month       INT,
    Order_Month_Name  VARCHAR(15),
    Season            VARCHAR(10),
    Is_Loss           VARCHAR(10),
    Margin_Band       VARCHAR(20),
    Sales_Bucket      VARCHAR(25),
    Revenue_per_Unit  NUMERIC(10,2),
    Profit_per_Unit   NUMERIC(10,2),
    Discount_Amount   NUMERIC(10,2),

    CONSTRAINT fk_product  FOREIGN KEY (Product_ID)  REFERENCES product_table(Product_ID),
    CONSTRAINT fk_customer FOREIGN KEY (Customer_ID) REFERENCES customer_table(Customer_ID),
    PRIMARY KEY (Order_ID, Product_ID)
);
 
 
-- ============================================================
-- SECTION 2: INDEXES
-- ============================================================
 
CREATE INDEX idx_product_id   ON transaction_table (Product_ID);
CREATE INDEX idx_customer_id  ON transaction_table (Customer_ID);
CREATE INDEX idx_order_date   ON transaction_table (Order_Date);
CREATE INDEX idx_order_year   ON transaction_table (Order_Year);
CREATE INDEX idx_region       ON customer_table    (Region);
CREATE INDEX idx_category     ON product_table     (Category);
CREATE INDEX idx_segment      ON customer_table    (Segment);
CREATE INDEX idx_discount_band ON transaction_table (Discount_Band);
 
 
-- ============================================================
-- SECTION 3: REUSABLE VIEW
-- ============================================================
 
CREATE VIEW sales_summary AS
SELECT
    ft.Order_ID,
    ft.Order_Date,
    ft.Ship_Date,
    ft.Ship_Mode,
    ft.Ship_Speed,
    dc.Customer_ID,
    dc.Customer_Name,
    dc.Segment,
    dc.City,
    dc.State,
    dc.Region,
    dp.Category,
    dp.Sub_Category,
    dp.Product_Name,
    ft.Sales,
    ft.Quantity,
    ft.Discount,
    ft.Discount_Amount,
    ft.Discount_Band,
    ft.Profit,
    ft.Profit_Margin_Pct,
    ft.Margin_Band,
    ft.Delivery_Days,
    ft.Revenue_per_Unit,
    ft.Profit_per_Unit,
    ft.Sales_Bucket,
    ft.Order_Year,
    ft.Order_Month,
    ft.Order_Month_Name,
    ft.Season,
    ft.Is_Loss
FROM       transaction_table ft
JOIN customer_table dc ON ft.Customer_ID = dc.Customer_ID
JOIN product_table  dp ON ft.Product_ID  = dp.Product_ID;
 
 
-- ============================================================
-- SECTION 4: STORED FUNCTION
-- ============================================================

-- Dynamically get product sales and profit for any region
CREATE OR REPLACE FUNCTION get_region_sales(p_region VARCHAR)
RETURNS TABLE (
    Category        VARCHAR,
    Sub_Category    VARCHAR,
    Sales           NUMERIC,
    Profit          NUMERIC,
    Discount        NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        dp.Category,
        dp.Sub_Category,
        ft.Sales,
        ft.Profit,
        ft.Discount
    FROM       transaction_table ft
    JOIN customer_table dc ON ft.Customer_ID = dc.Customer_ID
    JOIN product_table  dp ON ft.Product_ID = dp.Product_ID
    WHERE dc.Region = p_region;
END;
$$ LANGUAGE plpgsql;
 
 
-- ============================================================
-- PAGE 1: EXECUTIVE OVERVIEW
-- Business Question: Is the company healthy — profitable,
-- growing, and operationally efficient?
-- ============================================================
 
-- Q1: Company Health Snapshot (KPI Card Row)
SELECT
    COUNT(DISTINCT Order_ID)                                        AS Total_Orders,
    COUNT(DISTINCT Customer_ID)                                     AS Total_Customers,
    SUM(Quantity)                                                   AS Total_Units_Sold,
    ROUND(SUM(Sales), 2)                                            AS Total_Revenue,
    ROUND(SUM(Profit), 2)                                           AS Total_Profit,
    ROUND(SUM(Profit) / SUM(Sales) * 100, 2)                       AS Overall_Profit_Margin_Pct,
    ROUND(AVG(Sales), 2)                                            AS Avg_Order_Value,
    ROUND(AVG(Discount) * 100, 2)                                   AS Avg_Discount_Pct,
    ROUND(AVG(Delivery_Days), 1)                                    AS Avg_Delivery_Days,
    COUNT(*) FILTER (WHERE Is_Loss = 'Loss')                        AS Loss_Orders,
    ROUND(COUNT(*) FILTER (WHERE Is_Loss = 'Loss')
          * 100.0 / COUNT(*), 2)                                    AS Loss_Order_Pct
FROM transaction_table;
 
 
-- Q2: Year-over-Year Revenue and Profit Growth
WITH Yearly AS (
    SELECT
        Order_Year,
        ROUND(SUM(Sales), 2)  AS Total_Sales,
        ROUND(SUM(Profit), 2) AS Total_Profit
    FROM transaction_table
    GROUP BY Order_Year
)
SELECT
    Order_Year,
    Total_Sales,
    Total_Profit,
    ROUND(Total_Profit / NULLIF(Total_Sales, 0) * 100, 2)                   AS Profit_Margin_Pct,
    LAG(Total_Sales)  OVER (ORDER BY Order_Year)                            AS Prev_Year_Sales,
    ROUND((Total_Sales  - LAG(Total_Sales)  OVER (ORDER BY Order_Year))
          / LAG(Total_Sales)  OVER (ORDER BY Order_Year) * 100, 2)          AS YoY_Sales_Growth_Pct,
    ROUND((Total_Profit - LAG(Total_Profit) OVER (ORDER BY Order_Year))
          / LAG(Total_Profit) OVER (ORDER BY Order_Year) * 100, 2)          AS YoY_Profit_Growth_Pct
FROM Yearly
ORDER BY Order_Year;
 
 
-- Q3: Shipping Mode Efficiency (KPI support for Page 1)
SELECT
    Ship_Mode,
    Ship_Speed,
    COUNT(DISTINCT Order_ID)                                        AS Total_Orders,
    ROUND(COUNT(DISTINCT Order_ID) * 100.0
          / SUM(COUNT(DISTINCT Order_ID)) OVER (), 2)               AS Order_Share_Pct,
    ROUND(AVG(Delivery_Days), 1)                                    AS Avg_Delivery_Days,
    MIN(Delivery_Days)                                              AS Min_Days,
    MAX(Delivery_Days)                                              AS Max_Days,
    ROUND(SUM(Sales), 2)                                            AS Total_Sales,
    ROUND(SUM(Profit), 2)                                           AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2)             AS Margin_Pct
FROM transaction_table
GROUP BY Ship_Mode, Ship_Speed
ORDER BY Avg_Delivery_Days;
 
 
-- ============================================================
-- PAGE 2: PRODUCT PROFITABILITY
-- Business Question: Which products and categories make
-- money, which ones destroy margin, and why?
-- ============================================================
 
-- Q4: Category Performance — Revenue vs Profit Reality (Using VIEW)
SELECT
    Category,
    COUNT(DISTINCT Order_ID)                        AS Total_Orders,
    SUM(Quantity)                                   AS Units_Sold,
    ROUND(SUM(Sales), 2)                            AS Total_Sales,
    ROUND(SUM(Profit), 2)                           AS Total_Profit,
    ROUND(SUM(Profit) / SUM(Sales) * 100, 2)        AS Profit_Margin_Pct,
    ROUND(AVG(Revenue_per_Unit), 2)                 AS Avg_Revenue_per_Unit,
    ROUND(AVG(Profit_per_Unit), 2)                  AS Avg_Profit_per_Unit,
    COUNT(*) FILTER (WHERE Is_Loss = 'Loss')        AS Loss_Lines
FROM sales_summary
GROUP BY Category
ORDER BY Total_Sales DESC;
 
 
-- Q5: Sub-Category Profit Ranking — Best to Worst
SELECT
    dp.Category,
    dp.Sub_Category,
    ROUND(SUM(ft.Sales), 2)                                         AS Total_Sales,
    ROUND(SUM(ft.Profit), 2)                                        AS Total_Profit,
    ROUND(SUM(ft.Profit) / NULLIF(SUM(ft.Sales), 0) * 100, 2)       AS Profit_Margin_Pct,
    COUNT(DISTINCT ft.Order_ID)                                     AS Total_Orders,
    ROUND(AVG(ft.Discount) * 100, 2)                                AS Avg_Discount_Pct,
    ROUND(AVG(ft.Revenue_per_Unit), 2)                              AS Avg_Revenue_per_Unit,
    ROUND(AVG(ft.Profit_per_Unit), 2)                               AS Avg_Profit_per_Unit
FROM       transaction_table ft
JOIN product_table dp ON ft.Product_ID = dp.Product_ID
GROUP BY dp.Category, dp.Sub_Category
ORDER BY Total_Profit DESC;
 
 
-- Q6: Top 10 Most Profitable Products (Using VIEW - Safe Version)

SELECT
    Product_Name,
    Category,
    Sub_Category,
    ROUND(SUM(Sales), 2)                            AS Total_Sales,
    ROUND(SUM(Profit), 2)                           AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Profit_Margin_Pct,
    COUNT(DISTINCT Order_ID)                        AS Times_Ordered
FROM sales_summary
GROUP BY Product_Name, Category, Sub_Category
ORDER BY Total_Profit DESC
LIMIT 10;
 
 
-- Q7: Top 10 Loss-Making Products
SELECT
    dp.Product_Name,
    dp.Category,
    dp.Sub_Category,
    COUNT(*)                                                        AS Times_Ordered,
    ROUND(SUM(ft.Sales), 2)                                         AS Total_Sales,
    ROUND(SUM(ft.Profit), 2)                                        AS Total_Loss,
    ROUND(AVG(ft.Discount) * 100, 1)                                AS Avg_Discount_Pct
FROM       transaction_table ft
JOIN product_table dp ON ft.Product_ID = dp.Product_ID
GROUP BY dp.Product_Name, dp.Category, dp.Sub_Category
HAVING SUM(ft.Profit) < 0
ORDER BY Total_Loss ASC
LIMIT 10;
 
 
-- Q8: Margin Band Distribution
SELECT
    Margin_Band,
    COUNT(*)                                                        AS Order_Lines,
    ROUND(SUM(Sales), 2)                                            AS Revenue,
    ROUND(SUM(Profit), 2)                                           AS Profit,
    ROUND(AVG(Discount) * 100, 2)                                   AS Avg_Discount_Pct
FROM transaction_table
GROUP BY Margin_Band
ORDER BY
    CASE Margin_Band
        WHEN 'High (>=20%)'    THEN 1
        WHEN 'Medium (10-20%)' THEN 2
        WHEN 'Low (0-10%)'     THEN 3
        WHEN 'Loss'            THEN 4
    END;
 
 
-- Q9: Sales Bucket Distribution
SELECT
    Sales_Bucket,
    COUNT(*)                                                        AS Order_Lines,
    ROUND(SUM(Sales), 2)                                            AS Revenue,
    ROUND(SUM(Profit), 2)                                           AS Profit,
    ROUND(AVG(Profit_Margin_Pct), 2)                                AS Avg_Margin_Pct,
    ROUND(AVG(Revenue_per_Unit), 2)                                 AS Avg_Revenue_per_Unit,
    COUNT(*) FILTER (WHERE Is_Loss = 'Loss')                        AS Loss_Lines
FROM transaction_table
GROUP BY Sales_Bucket
ORDER BY
    CASE Sales_Bucket
        WHEN 'Micro (<$50)'       THEN 1
        WHEN 'Small ($50-200)'    THEN 2
        WHEN 'Medium ($200-500)'  THEN 3
        WHEN 'Large ($500-1K)'    THEN 4
        WHEN 'XL (>$1K)'         THEN 5
    END;
 
 
-- Q10: Top 3 Products per Category by Revenue (Window Function)
WITH Ranked_Products AS (
    SELECT
        dp.Category,
        dp.Product_Name,
        ROUND(SUM(ft.Sales), 2)   AS Total_Sales,
        ROUND(SUM(ft.Profit), 2)  AS Total_Profit,
        RANK() OVER (
            PARTITION BY dp.Category
            ORDER BY SUM(ft.Sales) DESC
        )                         AS Sales_Rank
    FROM       transaction_table ft
    JOIN product_table dp ON ft.Product_ID = dp.Product_ID
    GROUP BY dp.Category, dp.Product_Name
)
SELECT Category, Product_Name, Total_Sales, Total_Profit, Sales_Rank
FROM   Ranked_Products
WHERE  Sales_Rank <= 3
ORDER BY Category, Sales_Rank;
 
 
-- ============================================================
-- PAGE 3: REGIONAL & STATE PERFORMANCE
-- Business Question: Where is the business winning and
-- where is it bleeding — and what is causing it?
-- ============================================================
 
-- Q11: Region Performance Summary (Using VIEW)

SELECT
    Region,
    COUNT(DISTINCT Customer_ID)                     AS Total_Customers,
    COUNT(DISTINCT Order_ID)                        AS Total_Orders,
    ROUND(SUM(Sales), 2)                            AS Total_Sales,
    ROUND(SUM(Profit), 2)                           AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Profit_Margin_Pct,
    ROUND(AVG(Revenue_per_Unit), 2)                 AS Avg_Revenue_per_Unit,
    ROUND(AVG(Profit_per_Unit), 2)                  AS Avg_Profit_per_Unit,
    COUNT(*) FILTER (WHERE Is_Loss = 'Loss')        AS Loss_Lines
FROM sales_summary
GROUP BY Region
ORDER BY Profit_Margin_Pct DESC;
 
 
-- Q12: Top 5 and Bottom 5 States by Profit (Window Function)
WITH State_Performance AS (
    SELECT
        dc.State,
        dc.Region,
        ROUND(SUM(ft.Sales), 2)                                     AS Total_Sales,
        ROUND(SUM(ft.Profit), 2)                                    AS Total_Profit,
        ROUND(SUM(ft.Profit) / NULLIF(SUM(ft.Sales), 0) * 100, 2) AS Profit_Margin_Pct,
        COUNT(DISTINCT ft.Order_ID)                                 AS Total_Orders
    FROM       transaction_table ft
    JOIN customer_table dc ON ft.Customer_ID = dc.Customer_ID
    GROUP BY dc.State, dc.Region
),
Ranked_States AS (
    SELECT *,
        RANK() OVER (ORDER BY Total_Profit DESC) AS Profit_Rank,
        RANK() OVER (ORDER BY Total_Profit ASC)  AS Loss_Rank
    FROM State_Performance
)
SELECT
    State, Region, Total_Sales, Total_Profit,
    Profit_Margin_Pct, Total_Orders,
    CASE
        WHEN Profit_Rank <= 5 THEN 'Top 5'
        WHEN Loss_Rank   <= 5 THEN 'Bottom 5'
    END AS State_Category
FROM Ranked_States
WHERE Profit_Rank <= 5 OR Loss_Rank <= 5
ORDER BY Total_Profit DESC;
 
 
-- Q13: Central Region Deep Dive — Using Stored Function

SELECT
    Category,
    Sub_Category,
    ROUND(SUM(Sales), 2)                            AS Total_Sales,
    ROUND(SUM(Profit), 2)                           AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Profit_Margin_Pct,
    ROUND(AVG(Discount) * 100, 2)                   AS Avg_Discount_Pct
FROM get_region_sales('Central')   
GROUP BY Category, Sub_Category
ORDER BY Total_Profit ASC;
 
 
-- Q14: Regional Sales Contribution Over Time
SELECT
    Sales_Month,
    Region,
    Monthly_Regional_Sales,
    Total_Company_Sales,
    ROUND(Monthly_Regional_Sales * 100.0
          / Total_Company_Sales, 2)                                 AS Region_Contribution_Pct
FROM (
    SELECT
        DATE_TRUNC('month', ft.Order_Date)                          AS Sales_Month,
        dc.Region,
        ROUND(SUM(ft.Sales), 2)                                     AS Monthly_Regional_Sales,
        ROUND(SUM(SUM(ft.Sales)) OVER (
            PARTITION BY DATE_TRUNC('month', ft.Order_Date)
        ), 2)                                                       AS Total_Company_Sales
    FROM       transaction_table ft
    JOIN customer_table dc ON ft.Customer_ID = dc.Customer_ID
    GROUP BY Sales_Month, dc.Region
) AS Regional_Monthly
ORDER BY Sales_Month, Region_Contribution_Pct DESC;
 
 
-- ============================================================
-- PAGE 4: DISCOUNT & MARGIN ANALYSIS
-- Business Question: Is discounting driving growth or
-- systematically destroying profit?
-- ============================================================
 
-- Q15: Discount Band Impact on Profit
SELECT
    Discount_Band,
    COUNT(*)                                                        AS Total_Orders,
    ROUND(AVG(Discount) * 100, 2)                                   AS Avg_Discount_Pct,
    ROUND(SUM(Discount_Amount), 2)                                  AS Total_Discount_Given,
    ROUND(SUM(Sales), 2)                                            AS Total_Sales,
    ROUND(SUM(Profit), 2)                                           AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Profit_Margin_Pct,
    COUNT(*) FILTER (WHERE Is_Loss = 'Loss')                        AS Loss_Lines
FROM transaction_table
GROUP BY Discount_Band
ORDER BY Avg_Discount_Pct;
 
 
-- Q16: Most Discounted Sub-Categories and Profitability
SELECT
    dp.Category,
    dp.Sub_Category,
    ROUND(AVG(ft.Discount) * 100, 2)                                AS Avg_Discount_Pct,
    ROUND(SUM(ft.Discount_Amount), 2)                               AS Total_Discount_Given,
    ROUND(SUM(ft.Sales), 2)                                         AS Total_Sales,
    ROUND(SUM(ft.Profit), 2)                                        AS Total_Profit,
   ROUND(SUM(ft.Profit) / NULLIF(SUM(ft.Sales), 0) * 100, 2)        AS Profit_Margin_Pct
FROM       transaction_table ft
JOIN product_table dp ON ft.Product_ID = dp.Product_ID
GROUP BY dp.Category, dp.Sub_Category
ORDER BY Avg_Discount_Pct DESC;
 
 
-- Q17: Loss-Making Sub-Categories Root Cause
SELECT
    dp.Category,
    dp.Sub_Category,
    COUNT(*)                                                        AS Loss_Order_Count,
    ROUND(SUM(ft.Profit), 2)                                        AS Total_Loss,
    ROUND(AVG(ft.Discount) * 100, 2)                                AS Avg_Discount_Pct,
    ROUND(SUM(ft.Discount_Amount), 2)                               AS Total_Discount_Given,
    ROUND(SUM(ft.Sales), 2)                                         AS Total_Sales
FROM       transaction_table ft
JOIN product_table dp ON ft.Product_ID = dp.Product_ID
WHERE ft.Is_Loss = 'Loss'
GROUP BY dp.Category, dp.Sub_Category
ORDER BY Total_Loss ASC;
 
 
-- Q18: Discount Impact by Category (Cross-tab for visual)
SELECT
    dp.Category,
    ft.Discount_Band,
    COUNT(*)                                                        AS Order_Lines,
    ROUND(SUM(ft.Sales), 2)                                         AS Revenue,
    ROUND(SUM(ft.Profit), 2)                                        AS Profit,
    ROUND(AVG(ft.Profit_Margin_Pct), 2)                             AS Avg_Margin_Pct
FROM       transaction_table ft
JOIN product_table dp ON ft.Product_ID = dp.Product_ID
GROUP BY dp.Category, ft.Discount_Band
ORDER BY dp.Category, AVG(ft.Discount) ASC;
 
 
-- ============================================================
-- PAGE 5: CUSTOMER INTELLIGENCE
-- Business Question: Who are the best customers, how loyal
-- is the base, and which segments are most valuable?
-- ============================================================
 
-- Q19: Customer Segment Performance
SELECT
    dc.Segment,
    COUNT(DISTINCT dc.Customer_ID)                                  AS Total_Customers,
    COUNT(DISTINCT ft.Order_ID)                                     AS Total_Orders,
    ROUND(SUM(ft.Sales), 2)                                         AS Total_Sales,
    ROUND(SUM(ft.Profit), 2)                                        AS Total_Profit,
    ROUND(SUM(ft.Profit) / NULLIF(SUM(ft.Sales), 0) * 100, 2) AS Profit_Margin_Pct,
    ROUND(AVG(ft.Sales), 2)                                         AS Avg_Order_Value,
    ROUND(SUM(ft.Sales) / COUNT(DISTINCT dc.Customer_ID), 2)        AS Revenue_per_Customer,
    ROUND(AVG(ft.Discount) * 100, 2)                                AS Avg_Discount_Pct
FROM       transaction_table ft
JOIN customer_table dc ON ft.Customer_ID = dc.Customer_ID
GROUP BY dc.Segment
ORDER BY Profit_Margin_Pct DESC;
 
 
-- Q20: Top 10 Customers by Lifetime Profit (CLV)
SELECT
    dc.Customer_ID,
    dc.Customer_Name,
    dc.Segment,
    dc.Region,
    COUNT(DISTINCT ft.Order_ID)                                     AS Total_Orders,
    ROUND(SUM(ft.Sales), 2)                                         AS Lifetime_Revenue,
    ROUND(SUM(ft.Profit), 2)                                        AS Lifetime_Profit,
    ROUND(AVG(ft.Sales), 2)                                         AS Avg_Order_Value,
    ROUND(AVG(ft.Discount) * 100, 2)                                AS Avg_Discount_Pct
FROM       transaction_table ft
JOIN customer_table dc ON ft.Customer_ID = dc.Customer_ID
GROUP BY dc.Customer_ID, dc.Customer_Name, dc.Segment, dc.Region
ORDER BY Lifetime_Profit DESC
LIMIT 10;
 
 
-- Q21: Customer Retention — Repeat vs One-Time Buyers
SELECT
    CASE
        WHEN Total_Orders > 1 THEN 'Repeat Customer'
        ELSE                       'One-Time Customer'
    END                                                             AS Customer_Type,
    COUNT(*)                                                        AS Customer_Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)             AS Percentage
FROM (
    SELECT Customer_ID, COUNT(DISTINCT Order_ID) AS Total_Orders
    FROM   transaction_table
    GROUP BY Customer_ID
) AS Order_Counts
GROUP BY Customer_Type
ORDER BY Customer_Count DESC;
 
 
-- Q22: Customer Segmentation by Avg Order Value (Value Tiers)
WITH Customer_Metrics AS (
    SELECT
        Customer_ID,
        COUNT(DISTINCT Order_ID)   AS Total_Orders,
        ROUND(AVG(Sales), 2)       AS Avg_Order_Value,
        ROUND(SUM(Profit), 2)      AS Total_Profit,
        ROUND(SUM(Sales), 2)       AS Total_Revenue
    FROM transaction_table
    GROUP BY Customer_ID
)
SELECT
    CASE
        WHEN Avg_Order_Value >= 500 THEN 'High-Value'
        WHEN Avg_Order_Value >= 100 THEN 'Medium-Value'
        ELSE                             'Low-Value'
    END                                                             AS Value_Tier,
    COUNT(*)                                                        AS Customer_Count,
    ROUND(AVG(Avg_Order_Value), 2)                                  AS Avg_Order_Value,
    ROUND(SUM(Total_Revenue), 2)                                    AS Total_Revenue,
    ROUND(SUM(Total_Profit), 2)                                     AS Total_Profit
FROM Customer_Metrics
GROUP BY Value_Tier
ORDER BY Avg_Order_Value DESC;
 
 
-- ============================================================
-- PAGE 6: TIME & SEASONAL TRENDS
-- Business Question: When does the business peak, are there
-- consistent patterns, and is growth sustainable?
-- ============================================================
 
-- Q23: Month-over-Month Sales Growth (Window Function)
WITH Monthly AS (
    SELECT
        DATE_TRUNC('month', Order_Date)  AS Sales_Month,
        ROUND(SUM(Sales), 2)             AS Monthly_Sales,
        ROUND(SUM(Profit), 2)            AS Monthly_Profit
    FROM transaction_table
    GROUP BY Sales_Month
)
SELECT
    Sales_Month,
    Monthly_Sales,
    Monthly_Profit,
    LAG(Monthly_Sales) OVER (ORDER BY Sales_Month)                  AS Prev_Month_Sales,
    ROUND((Monthly_Sales - LAG(Monthly_Sales) OVER (ORDER BY Sales_Month))
         / NULLIF(LAG(Monthly_Sales) OVER (ORDER BY Sales_Month), 0) * 100, 2) AS MoM_Growth_Pct
FROM Monthly
ORDER BY Sales_Month;
 
 
-- Q24: Cumulative Revenue and Profit Over Time
SELECT
    DATE_TRUNC('month', Order_Date)                                 AS Sales_Month,
    ROUND(SUM(Sales), 2)                                            AS Monthly_Sales,
    ROUND(SUM(Profit), 2)                                           AS Monthly_Profit,
    ROUND(SUM(SUM(Sales))  OVER (ORDER BY DATE_TRUNC('month', Order_Date)), 2) AS Cumulative_Sales,
    ROUND(SUM(SUM(Profit)) OVER (ORDER BY DATE_TRUNC('month', Order_Date)), 2) AS Cumulative_Profit
FROM transaction_table
GROUP BY Sales_Month
ORDER BY Sales_Month;
 
 
-- Q25: Best and Worst Performing Months (Ranked)
SELECT
    Order_Month_Name,
    Order_Month,
    ROUND(SUM(Sales), 2)              AS Total_Sales,
    ROUND(SUM(Profit), 2)             AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Profit_Margin_Pct,
    COUNT(DISTINCT Order_ID)          AS Total_Orders,
    RANK() OVER (ORDER BY SUM(Sales) DESC) AS Sales_Rank
FROM transaction_table
GROUP BY Order_Month_Name, Order_Month
ORDER BY Total_Sales DESC;
 
 
-- Q26: Revenue and Profit by Season
SELECT
    Season,
    COUNT(DISTINCT Order_ID)                                        AS Total_Orders,
    ROUND(SUM(Sales), 2)                                            AS Total_Sales,
    ROUND(SUM(Profit), 2)                                           AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Profit_Margin_Pct,
    ROUND(AVG(Discount) * 100, 2)                                   AS Avg_Discount_Pct
FROM transaction_table
GROUP BY Season
ORDER BY Total_Sales DESC;
 
 
-- Q27: Season x Category Revenue Matrix
SELECT
    ft.Season,
    dp.Category,
    ROUND(SUM(ft.Sales), 2)                                         AS Revenue,
    ROUND(SUM(ft.Profit), 2)                                        AS Profit,
    ROUND(SUM(ft.Profit) / NULLIF(SUM(ft.Sales), 0) * 100, 2)       AS Margin_Pct
FROM       transaction_table ft
JOIN product_table dp ON ft.Product_ID = dp.Product_ID
GROUP BY ft.Season, dp.Category
ORDER BY ft.Season, Revenue DESC;
 