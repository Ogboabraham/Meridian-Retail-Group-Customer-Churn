-- ============================================================================
-- MERIDIAN RETAIL GROUP
-- PHASE 4 — SQL ANALYSIS TASKS
-- Project: Reducing Customer Churn at Meridian Retail Group
-- ============================================================================

USE [meridian_retail];
GO


-- ============================================================================
-- Q1 — BASIC SELECT / WHERE / ORDER BY
-- List the 20 most recent completed orders.
-- ============================================================================

SELECT TOP 20
    Order_ID,
    Customer_ID,
    Order_Date,
    Total_Amount
FROM dbo.Orders
WHERE Order_Status = 'Completed'
ORDER BY Order_Date DESC;

GO


-- ============================================================================
-- Q2 — AGGREGATION / GROUP BY
-- For each membership tier:
--   1. Number of customers
--   2. Total revenue from completed orders
--   3. Average order value
-- ============================================================================

SELECT
    c.Membership_Tier,
    COUNT(DISTINCT c.Customer_ID) AS Number_of_Customers,
    COALESCE(SUM(o.Total_Amount), 0) AS Total_Revenue,
    AVG(o.Total_Amount) AS Average_Order_Value
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o
    ON c.Customer_ID = o.Customer_ID
    AND o.Order_Status = 'Completed'
GROUP BY c.Membership_Tier
ORDER BY Total_Revenue DESC;

GO


-- ============================================================================
-- Q3 — JOIN
-- List the top 15 products by total revenue.
-- Revenue = Quantity * Unit_Price_At_Purchase
-- ============================================================================

SELECT TOP 15
    p.Product_ID,
    p.Product_Name,
    p.Category,
    p.Brand,
    SUM(oi.Quantity * oi.Unit_Price_At_Purchase) AS Total_Revenue
FROM dbo.Products AS p
INNER JOIN dbo.Order_Items AS oi
    ON p.Product_ID = oi.Product_ID
GROUP BY
    p.Product_ID,
    p.Product_Name,
    p.Category,
    p.Brand
ORDER BY Total_Revenue DESC;

GO


-- ============================================================================
-- Q4 — JOIN ACROSS 3+ TABLES
-- For every Platinum customer:
--   1. Total number of orders
--   2. Total spend from completed orders
--   3. Total number of support tickets
-- ============================================================================

WITH Order_Summary AS
(
    SELECT
        Customer_ID,
        COUNT(DISTINCT Order_ID) AS Total_Orders,
        SUM(CASE WHEN Order_Status = 'Completed' THEN Total_Amount ELSE 0 END) AS Total_Spend
    FROM dbo.Orders
    GROUP BY Customer_ID
),
Support_Summary AS
(
    SELECT
        Customer_ID,
        COUNT(*) AS Total_Support_Tickets
    FROM dbo.Support_Tickets
    GROUP BY Customer_ID
)
SELECT
    c.Customer_ID,
    c.Membership_Tier,
    COALESCE(os.Total_Orders, 0) AS Total_Orders,
    COALESCE(os.Total_Spend, 0) AS Total_Spend,
    COALESCE(ss.Total_Support_Tickets, 0) AS Total_Support_Tickets
FROM dbo.Customers AS c
LEFT JOIN Order_Summary AS os
    ON c.Customer_ID = os.Customer_ID
LEFT JOIN Support_Summary AS ss
    ON c.Customer_ID = ss.Customer_ID
WHERE c.Membership_Tier = 'Platinum'
ORDER BY Total_Spend DESC;

GO


-- ============================================================================
-- Q5 — SUBQUERY
-- Find customers whose completed-order total spend is above the
-- overall average total spend per customer.
-- ============================================================================

SELECT
    c.Customer_ID,
    SUM(o.Total_Amount) AS Total_Spend
FROM dbo.Customers AS c
INNER JOIN dbo.Orders AS o
    ON c.Customer_ID = o.Customer_ID
WHERE o.Order_Status = 'Completed'
GROUP BY c.Customer_ID
HAVING SUM(o.Total_Amount) >
(
    SELECT AVG(Customer_Total)
    FROM
    (
        SELECT
            Customer_ID,
            SUM(Total_Amount) AS Customer_Total
        FROM dbo.Orders
        WHERE Order_Status = 'Completed'
        GROUP BY Customer_ID
    ) AS Customer_Spending
)
ORDER BY Total_Spend DESC;

GO


-- ============================================================================
-- Q6 — SUBQUERY / NOT EXISTS
-- Find all customers who have never placed an order.
-- ============================================================================

SELECT
    c.Customer_ID
FROM dbo.Customers AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Orders AS o
    WHERE o.Customer_ID = c.Customer_ID
);

GO


-- ============================================================================
-- Q7 — CASE STATEMENT
-- Categorize orders:
--   Low    = less than $50
--   Medium = $50 to $200
--   High   = greater than $200
-- ============================================================================

SELECT
    CASE
        WHEN Total_Amount < 50 THEN 'Low'
        WHEN Total_Amount BETWEEN 50 AND 200 THEN 'Medium'
        WHEN Total_Amount > 200 THEN 'High'
    END AS Value_Band,

    COUNT(*) AS Order_Count,
    SUM(Total_Amount) AS Total_Revenue

FROM dbo.Orders

GROUP BY
    CASE
        WHEN Total_Amount < 50 THEN 'Low'
        WHEN Total_Amount BETWEEN 50 AND 200 THEN 'Medium'
        WHEN Total_Amount > 200 THEN 'High'
    END

ORDER BY Total_Revenue DESC;

GO


-- ============================================================================
-- Q8 — DATE LOGIC / CHURN LABEL
-- Snapshot date = 2026-07-01
--
-- Churned:
--   No completed order in the last 180 days OR never ordered.
--
-- Active:
--   Has a completed order within the last 180 days.
-- ============================================================================

SELECT
    CASE
        WHEN Last_Order_Date IS NULL THEN 'Churned'
        WHEN Last_Order_Date <
             DATEADD(DAY, -180, CAST('2026-07-01' AS DATE))
            THEN 'Churned'
        ELSE 'Active'
    END AS Churn_Label,

    COUNT(*) AS Customer_Count

FROM
(
    SELECT
        c.Customer_ID,
        MAX(o.Order_Date) AS Last_Order_Date

    FROM dbo.Customers AS c

    LEFT JOIN dbo.Orders AS o
        ON c.Customer_ID = o.Customer_ID
        AND o.Order_Status = 'Completed'
        AND o.Order_Date <= '2026-07-01'

    GROUP BY
        c.Customer_ID

) AS Customer_Last_Order

GROUP BY
    CASE
        WHEN Last_Order_Date IS NULL THEN 'Churned'
        WHEN Last_Order_Date <
             DATEADD(DAY, -180, CAST('2026-07-01' AS DATE))
            THEN 'Churned'
        ELSE 'Active'
    END;

GO


-- ============================================================================
-- Q9 — AGGREGATION + HAVING
-- Find product categories where average order-item quantity exceeds 1.5.
-- ============================================================================

SELECT
    p.Category,
    AVG(CAST(oi.Quantity AS DECIMAL(10,2))) AS Average_Quantity

FROM dbo.Products AS p

INNER JOIN dbo.Order_Items AS oi
    ON p.Product_ID = oi.Product_ID

GROUP BY
    p.Category

HAVING
    AVG(CAST(oi.Quantity AS DECIMAL(10,2))) > 1.5

ORDER BY
    Average_Quantity DESC;

GO


-- ============================================================================
-- Q10 — DATA MODIFICATION
-- Safely correct negative quantities and remove exact duplicate rows.
-- The transaction allows both changes to be committed together or rolled back.
-- ============================================================================

SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- Part A: Preview the rows that will be changed.
SELECT
    Order_Item_ID,
    Order_ID,
    Product_ID,
    Quantity,
    Unit_Price_At_Purchase
FROM dbo.Order_Items
WHERE Quantity < 0;

-- Part B: Remove exact duplicate rows while keeping the first copy.
WITH DuplicateRows AS
(
    SELECT
        Order_Item_ID,
        ROW_NUMBER() OVER
        (
            PARTITION BY
                Order_ID,
                Product_ID,
                Quantity,
                Unit_Price_At_Purchase
            ORDER BY Order_Item_ID
        ) AS Row_Number
    FROM dbo.Order_Items
)
DELETE FROM dbo.Order_Items
WHERE Order_Item_ID IN
(
    SELECT Order_Item_ID
    FROM DuplicateRows
    WHERE Row_Number > 1
);

-- Part C: Correct negative quantities by converting them to absolute values.
UPDATE dbo.Order_Items
SET Quantity = ABS(Quantity)
WHERE Quantity < 0;

-- Review the affected data before committing.
SELECT
    COUNT(*) AS Remaining_Negative_Quantities
FROM dbo.Order_Items
WHERE Quantity < 0;

-- Commit only after reviewing the results above.
COMMIT TRANSACTION;

GO


-- ============================================================================
-- Q11 — CONSTRAINTS / SCHEMA DESIGN
-- Answer in a comment; no SQL execution required.
-- ============================================================================

-- If Customer_ID in the Orders table is not declared as a foreign key
-- referencing Customers(Customer_ID), the database could allow orders
-- containing customer IDs that do not exist in the Customers table.
--
-- These invalid references are called orphaned customer IDs.
-- They can cause inaccurate reports and problems when joining Orders
-- with Customers because those orders will not match a customer record.
--
-- A foreign key enforces referential integrity by preventing an order
-- from being inserted or updated with a Customer_ID that does not exist
-- in the Customers table.
--
-- This is different from Q6. Q6 finds customers who exist in the
-- Customers table but have never placed an order.
-- An orphaned order is the opposite situation: the order exists,
-- but the referenced customer does not exist in Customers.

GO


-- ============================================================================
-- Q12 — PERFORMANCE / INDEX
-- Answer in a comment. No execution required.
-- ============================================================================

-- Q1 filters the Orders table using Order_Status and sorts the results
-- using Order_Date.
--
-- A composite index on Order_Status and Order_Date would improve
-- performance because Order_Status is used in the WHERE clause and
-- Order_Date is used for sorting.
--
-- Example index:
--
-- CREATE INDEX IX_Orders_OrderStatus_OrderDate
-- ON dbo.Orders (Order_Status, Order_Date DESC)
-- INCLUDE (Order_ID, Customer_ID, Total_Amount);
--
-- Order_Status is the first column because it is used to filter records.
-- Order_Date is the second column because it is used to sort the results.
--
-- The INCLUDE columns contain the other columns requested by Q1 and
-- can reduce the need for SQL Server to look back at the original table.


-- ============================================================================
-- END OF PHASE 4 — SQL ANALYSIS TASKS
-- ============================================================================