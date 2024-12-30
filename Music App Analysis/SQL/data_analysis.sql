-- Overall Analysis of the data warehouse.
-- Date Creation: Dec 7,  2024
-- Last Update: Dec 26, 2024

-- =======================================

-- Most/Least sold tracks with avg tracks per playlist
-- calculate total tracks per playlist.
WITH total_tracks AS (
	SELECT
		playlistid
		, name
		, count(trackid) AS "total_tracks"
	FROM
		dwh.dim_playlist AS dp
	GROUP BY
		playlistid
		, name
	ORDER BY
		total_tracks DESC
)
-- union the playlists which have the most and least amount of tracks
-- to show them on the same table.
, most_and_least_total_tracks AS (
	(
		SELECT
			'highest' AS "placement"
			,*
		FROM total_tracks AS tt
		LIMIT 1
	)
	UNION
	(
		SELECT
			'lowest' AS "placement"
			,*
		FROM total_tracks AS tt
		ORDER BY total_tracks ASC, playlistid DESC
		LIMIT 1
	)
)
-- average tracks amount on all the playlists
, avg_tracks_amount AS (
	SELECT
		round(avg(tt.total_tracks)) AS "avg_tracks_on_playlist"
	FROM total_tracks AS tt
)
SELECT
	*
FROM most_and_least_total_tracks AS mltt
LEFT JOIN avg_tracks_amount AS ata ON 1 = 1
;

-- ============================

SELECT * FROM dwh.fact_invoice ;

-- Totals tracks sold from each group
WITH total_tracks_sold AS (
	SELECT
		dt.trackid
		, count(fi.trackid) AS "total_tracks"
	FROM dwh.dim_track AS dt
	LEFT JOIN dwh.fact_invoiceline AS fi ON dt.trackid = fi.trackid
	GROUP BY
		dt.trackid
)
, grouping_total_sold_tracks AS (
	SELECT
		*
		, CASE
			WHEN total_tracks = 0 THEN '0'
			WHEN total_tracks BETWEEN 1 AND 5 THEN '1-5'
			WHEN total_tracks BETWEEN 5 AND 10 THEN '5-10'
			ELSE '> 10'
		END AS "group"
	FROM total_tracks_sold 
)
SELECT
	"group"
	,count(*)
FROM (
	-- To present it better add order to the "group" column and then
	-- order by it.
	SELECT 
		*
		,CASE 
			WHEN "group" = '0' THEN 1
			WHEN "group" = '1-5' THEN 2
			WHEN "group" = '5-10' THEN 3
			WHEN "group" = '> 10' THEN 4
		END AS "ordering"
	FROM grouping_total_sold_tracks
) AS q
GROUP BY "group",q."ordering"
ORDER BY "ordering" ASC
;

-- ============================

-- Top and Bottom profits from countries 
WITH revenue_per_country AS (
	SELECT
		billingcountry
		, sum(total) AS "revenue"
	FROM
		dwh.fact_invoice AS fi
	GROUP BY
		billingcountry
	ORDER BY "revenue" DESC, billingcountry ASC
)
, top_bottom_countries AS (
	(
		SELECT
			'top_5' AS "placement"
			,*
		FROM
			revenue_per_country
		LIMIT 5
	)
	UNION ALL
	(
		SELECT*
		-- The query inside the FROM is enough but it is used
		-- as subquery to make ordering the results from high to low.
		FROM(
			SELECT
				'bottom_5' AS "placement"
				,*
			FROM
				revenue_per_country
			ORDER BY "revenue" ASC
			LIMIT 5
		) AS q
		ORDER BY revenue DESC
	)
)
SELECT
	*
FROM top_bottom_countries
;

-- Percentage of sales of each genre in each country.
-- Can use the code above just need to add the percentage of
-- each genre sells.
WITH revenue_per_country AS (
	SELECT
		billingcountry
		, sum(total) AS "revenue"
	FROM
		dwh.fact_invoice AS fi
	GROUP BY
		billingcountry
	ORDER BY "revenue" DESC, billingcountry ASC
)
, top_bottom_countries AS (
	(
		SELECT
			'top_5' AS "placement"
			,*
		FROM
			revenue_per_country
		LIMIT 5
	)
	UNION ALL
	(
		SELECT*
		-- The query inside the FROM is enough but it is used
		-- as subquery to make ordering the results from high to low.
		FROM(
			SELECT
				'bottom_5' AS "placement"
				,*
			FROM
				revenue_per_country
			ORDER BY "revenue" ASC
			LIMIT 5
		) AS q
		ORDER BY revenue DESC
	)
)
-- Get each genre revenue
, genre_revenue AS (
	SELECT 
		billingcountry 
		,genre_name
		,sum(line_total) AS "genre_revenue"
	FROM dwh.fact_invoiceline AS fil
	LEFT JOIN dwh.dim_track AS dt ON fil.trackid = dt.trackid
	LEFT JOIN dwh.fact_invoice AS fi ON fil.invoiceid = fi.invoiceid
	WHERE EXISTS (SELECT 1 FROM top_bottom_countries AS tbc WHERE fi.billingcountry = tbc.billingcountry)
	GROUP BY billingcountry, genre_name
	ORDER BY billingcountry, genre_name
)
-- Get the percentages of each genre.
, genre_revenue_percentages AS (
	SELECT
		gr.billingcountry
		,gr.genre_name
		-- Getting the percentages out of the revenue.
		,round((sum(gr.genre_revenue) / rpc.revenue), 3) * 100 AS "percentages"
	FROM genre_revenue AS gr
	LEFT JOIN revenue_per_country AS rpc ON gr.billingcountry = rpc.billingcountry
	GROUP BY gr.billingcountry, gr.genre_name, rpc.revenue
	ORDER BY billingcountry, percentages DESC, genre_name 
)
SELECT
	billingcountry
	,genre_name
	-- display the numbers as percentages
	,to_char(percentages,'990D99%') AS "percentages"
	-- rank the genre on each country separately.
	,DENSE_RANK () OVER (PARTITION BY billingcountry ORDER BY percentages DESC) AS "genre_rank"
FROM genre_revenue_percentages AS grp
;

-- ============================
	
-- Average data of countries including 'Other' section.
-- Calculating the totals per country.
WITH totals_per_country AS (
	SELECT
		fi.billingcountry
		-- Need to use distinct because a customer can buy multiple times.
		, count(DISTINCT fi.customerid) AS "total_customers"
		, count(customerid) AS "total_orders"
		, sum(total) AS "revenue"
	FROM
		dwh.fact_invoice AS fi
	GROUP BY
		fi.billingcountry
)
, countries_avg_data AS (
	SELECT
		billingcountry
		, total_customers 
		, round(total_orders / total_customers) AS "avg_orders_per_customer"
		, round(revenue / total_customers,2) AS "avg_revenue_per_customer"
	FROM
		totals_per_country AS tpc
	WHERE tpc.total_customers <> 1
)
-- calculate the avg data only for the countries with 1 customer.
, other_group_avg_data AS (
	SELECT
		'Other' AS "billingcountry"
		, total_customers 
		, total_orders / total_customers AS "avg_orders_per_customer"
		, round(revenue / total_customers,2) AS "avg_revenue_per_customer"
	FROM
		totals_per_country AS tpc
	WHERE tpc.total_customers = 1
)
-- Union both cte's that provide avg data.
(SELECT * FROM countries_avg_data)
UNION ALL
(
SELECT
	-- At the other_group_avg_data we indeed got the avg data
	-- but we got it for each country, there for we need to
	-- also do the calculations in here.
	billingcountry
	,sum(total_customers) AS "total_customers"
	,round(avg(avg_orders_per_customer)) AS "avg_orders_per_customer"
	,round(avg(avg_revenue_per_customer),2) AS "avg_revenue_per_customer"
FROM other_group_avg_data
GROUP BY billingcountry 
)
;

-- ============================

-- Employee analysis.
-- Finding connections between the tables
SELECT
*
FROM dwh.dim_employee AS de 
ORDER BY employeeid 
;
SELECT * FROM dwh.dim_customer AS dc 
;
SELECT * FROM dwh.fact_invoice AS fi 
;

-- Aanalysis
WITH employee_info AS (
	SELECT
		employeeid
		, firstname || ' ' || lastname AS "full_name"
		, seniority
	FROM
		dwh.dim_employee AS de
)
, employee_stats AS (
	SELECT
		ei.employeeid
		, count(DISTINCT dc.customerid) AS "customers_serviced"
		, EXTRACT (YEAR FROM fi.invoicedate) AS "year"
		, sum(fi.total) AS "total_revenue"
	FROM
		employee_info AS ei
	LEFT JOIN dwh.dim_customer AS dc ON ei.employeeid = dc.supportrepid
	LEFT JOIN dwh.fact_invoice AS fi ON dc.customerid = fi.customerid
	GROUP BY ei.employeeid, EXTRACT (YEAR FROM fi.invoicedate)
)
, growth_percentage_from_last_year AS (
	SELECT
		employeeid
		, "year"
		, customers_serviced
		, total_revenue
		, COALESCE(CAST((total_revenue / prev_year) * 100 AS integer), 0) AS "growth_percentages"
	FROM (
		SELECT
			*
			, LAG(total_revenue, 1) OVER (PARTITION BY employeeid ORDER BY employeeid, "year") "prev_year"
		FROM employee_stats AS es
	)
)
SELECT
	employeeid
	-- Show it as years instead of number with comma.
	, to_char("year" * INTERVAL '1 year', 'YYYY') AS "year"
	, "customers_serviced"
	, "total_revenue"
	, CASE
		WHEN growth_percentages > 100 THEN growth_percentages || '%'
		WHEN growth_percentages BETWEEN 1 AND 100 THEN (100 - growth_percentages) * -1 || '%'
		ELSE 0 || '%'
	END AS "growth"
FROM growth_percentage_from_last_year
;