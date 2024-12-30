-- Album revenue analysis
-- Date: Dec 26, 2024

-- Look at the tables to look over the data.
SELECT *
FROM dwh.dim_track AS dt;

SELECT *
FROM dwh.fact_invoiceline AS fi;

-- Calculate the album revenue and how many times it sold.
WITH album_revenue_total_sold AS (
	SELECT 
		album_title
		,count(invoicelineid) AS "total_sold"
		-- Make sure to not get null.
		,COALESCE(sum(line_total),0) AS "revenue"
	FROM dwh.dim_track AS dt
	LEFT JOIN dwh.fact_invoiceline AS fi ON dt.trackid = fi.trackid
	GROUP BY album_title
	ORDER BY total_sold 
)
-- Get the sum of all of the revenue to calculate percentages later.
, total_revenue_of_all_ablums AS (
	SELECT
		sum(revenue) AS "sum_revenue"
	FROM album_revenue_total_sold
)
-- Calculate the percentages.
, revenue_percentages AS (
	SELECT
		arts.*
		, round(arts.revenue / tr.sum_revenue,4) * 100 AS "revenue_percentages"
	FROM album_revenue_total_sold AS arts
	LEFT JOIN total_revenue_of_all_ablums AS tr ON 1 = 1
	ORDER BY "revenue_percentages" DESC
)
-- Show data
SELECT
	album_title 
	,total_sold 
	,revenue
	-- Print it as ethier 0% or Number with decimal.
	-- FM90D99% translates to:
	-- FM - remove spaces from the beginning
	-- 9 - If there is a number place it otherwise don't
	-- 0 - Makes sure there is ethier 0 or the number.
	-- D - Everything after this letter is the format of the decmial places.
	,CASE 
		WHEN revenue_percentages = 0 THEN '0%'
		ELSE to_char(revenue_percentages,'FM90D99%')  
	END AS "revenue_percentages"
FROM revenue_percentages AS rp