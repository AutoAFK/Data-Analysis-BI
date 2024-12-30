-- Creation of the data warehouse.
-- Date: Dec 7,  2024

/*
 * Before each table creation on the dwh schema,
 * we will look at the values of each table to
 * better understand how can we join them.
*/

/*
 * The following line will drop the entire schema of dwh.
 * USE WITH CAUTION.
*/ 
--DROP SCHEMA dwh CASCADE;

/*
 * Create's the schema dwh.
 * */
CREATE SCHEMA dwh;

-- ====== dim_playlist ======

SELECT
	*
FROM
	stg.playlisttrack;
--trackid and playlist id;
SELECT
	*
FROM
	stg.playlist p;
-- playlist id and name of playlist;

/* 
* A LEFT JOIN is used in this query.
* We don't want to lose data from playlisttrack if there is
* no playlist name in the playlist table. 
* Therefor we use LEFT JOIN.
*/

CREATE TABLE IF NOT EXISTS dwh.dim_playlist AS (
	SELECT
		plt.playlistid
		, p."name"
		, plt.trackid
	FROM
		stg.playlisttrack AS plt
	LEFT JOIN stg.playlist AS p ON
		plt.playlistid = p.playlistid
);

-- validate table creation
SELECT
	*
FROM
	dwh.dim_playlist;

-- ====== dim_customer ======

SELECT 
*
FROM stg.customer AS c;

CREATE TABLE IF NOT EXISTS dwh.dim_customer AS (
	SELECT
		customerid
		--initcap(string) capitals the first letter of the string and lower the others.
		, initcap(firstname) AS "firstname"
		, initcap(lastname) AS "lastname"
		, company
		, address
		, city
		, state
		, country
		, postalcode
		, phone
		, fax
		, email
		,
	split_part(
			email
			, '@'
			, 2
		) AS "email_domain"
		, supportrepid
	FROM
		stg.customer AS c
);

--validate creation of table.
SELECT
	*
FROM
	dwh.dim_customer;

-- ====== dim_employee ======

SELECT
	*
FROM
	stg.employee AS e;

SELECT 
*
FROM stg.department_budget AS db;

CREATE TABLE IF NOT EXISTS dwh.dim_employee AS (
	WITH managers AS (
		SELECT
			DISTINCT(reportsto) AS "manager_id"
		FROM
			stg.employee AS e
		WHERE
			reportsto IS NOT NULL
	)
	SELECT
		e.employeeid
		,e.firstname
		,e.lastname
		,e.title
		,e.reportsto
		,e.departmentid
		, db.department_name
		, db.budget
		,e.birthdate
		,e.hiredate
		,e.address
		,e.city
		,e.state
		,e.country
		,e.postalcode
		,e.phone
		,e.fax
		,e.email
		, age(
			now()
			, e.hiredate
		) AS "seniority"
		, split_part(
			email
			, '@'
			, 2
		) AS "domain"
		, CASE
			-- if we left join the managers table and we have a non null value then
			-- its a meneger, otherwise its employee.
			WHEN m.manager_id IS NOT NULL THEN 1
			ELSE 0
		END AS "is_manager"
	FROM
		stg.employee AS e
	INNER JOIN stg.department_budget AS db ON
		e.departmentid = db.department_id
	LEFT JOIN managers AS m ON
		e.employeeid = m.manager_id
	ORDER BY department_id,"is_manager" DESC,employeeid 
);

SELECT
	*
FROM
	dwh.dim_employee;

-- ====== dim_track ======

SELECT *
FROM stg.track AS t;

/*
 * The following should not be added from tracks:
 * bytes - 			no need for bytes, it can help to make decsion on a database level
 * 					but it doesn't help to get conclusions for revenue.
 * last_update - 	data warehouse are used to analysis puproses and updated on those invoices
 * 					usually are not relevent. If there are a lot of mistakes then we can update
 * 					the entire warehouse with ethier alter nor drop and create from scratch.
 * composer -		The composer does represent an intersting data to explore
 * 					for example, how many songs each composer produced? The problem is
 * 					about 30% of tracks doesn't have a composer so getting rid of such a huge amount of data
 * 					does not provide a good dataset to explore.
 * 
 * */


SELECT *
FROM stg.album AS a;

SELECT *
FROM stg.artist AS a;

SELECT *
FROM stg.mediatype AS m;

SELECT *
FROM stg.genre AS g;

CREATE TABLE IF NOT EXISTS dwh.dim_track AS(
	SELECT
		t.trackid
		,t.name
		,t.albumid
		,t.mediatypeid
		,t.genreid
		, art.artistid
		,t.unitprice
		,a.title AS "album_title"
		, art."name" AS "artist_name"
		, m."name" AS "media_name"
		, g."name" AS "genre_name"
		, t.milliseconds / 1000 AS "seconds"
		-- in to_char 'FM09' make it return a 06 instead of 6 to make it look better.
		,to_char(t.milliseconds / 1000 / 60,'FM09') || ':' || to_char(((t.milliseconds / 1000) % 60),'FM09') AS "length"
		-- The above line can also be written like this 
		--,to_char((t.milliseconds::NUMERIC / 1000) * INTERVAL '1 second', 'HH24:MI:SS')
		-- But it have to show hours too... right now we only need MI:SS format
	FROM
		stg.track AS t
	LEFT JOIN stg.album AS a ON
		t.albumid = a.albumid
	LEFT JOIN stg.artist AS art ON
		a.artistid = art.artistid
	LEFT JOIN stg.mediatype AS m ON
		t.mediatypeid = m.mediatypeid
	LEFT JOIN stg.genre AS g ON
		t.genreid = g.genreid
);
	


SELECT
	*
FROM
	dwh.dim_track;

-- ====== fact_invoice ======

SELECT *
FROM stg.invoice AS i;

/*
 * There is no need to bring:
 * 
 * bilingaddress,
 * billingcity,
 * bilingpostalcode - 	because they change with each customer
 * 						and will provide with THOUSANDS of groups.
 * 
 * billingstate - have a lot of missing information.
 * 
 * A useful address that can be selected is
 * "billingcountry" which does not have NULL cells and can help group up
 * data related to the same city which is more convenient to analyze.
 * 
 * */

CREATE TABLE IF NOT EXISTS dwh.fact_invoice AS (
	SELECT
		invoiceid
		,customerid
		,invoicedate
		,billingcountry
		,total
	FROM
		stg.invoice AS i
);

SELECT
	*
FROM
	dwh.fact_invoice;

-- ====== fact_invoiceline ======

SELECT 
	*
FROM stg.invoiceline AS i;

CREATE TABLE IF NOT EXISTS dwh.fact_invoiceline AS (
	SELECT
		*
		, unitprice * quantity AS "line_total"
	FROM
		stg.invoiceline AS i
	ORDER BY
		i.invoicelineid ASC
);

SELECT
	*
FROM
	dwh.fact_invoiceline;
