-- =============================================
-- PROJECT: FreightFlow Africa Analytics
-- AUTHOR: Obinna Mark Neboh
-- DATE: July 2026
-- TOOL: SQL Server Management Studio (SSMS)

-- =============================================

-- =====================
-- CHAPTER : KEY PERFORMANCE INDEX
-- =====================
--1. Total Freight Revenue

SELECT SUM(freight_cost_usd) AS Lost_Revenue
FROM shipments
WHERE Status='Lost'
OR status='Delayed';

--2.On-Time Delivery Rate 
SELECT
COUNT(CASE WHEN Shipments .actual_delivery_date <= shipments.expected_delivery_date THEN 1 END) 
*100/COUNT(shipment_id) AS shipment_percnt
FROM shipments
WHERE status = 'Delivered';



--3.Average Delay (days)
SELECT 
ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay
FROM shipments
WHERE Status='Delivered'
OR status='Delayed';


--4. %of clients over 80% credit utilization
SELECT 
(SELECT COUNT(*) AS over_util
FROM 
(SELECT Clients.client_id, Clients.company_name, 
SUM(shipments.freight_cost_usd) AS Total_freight_cost_usd,
clients.credit_limit_usd
FROM Shipments
INNER JOIN Clients ON Shipments.client_id=clients.client_id
GROUP BY Clients.client_id, Clients.company_name,clients.credit_limit_usd)
AS SUB
WHERE Total_freight_cost_usd >(SELECT (80.0*credit_limit_usd/100)))*100.0
/ COUNT( distinct CLient_id) as percnt_clients
FROM CLIENTS;

--5 Number of high risk clients(delayed/lost above a certain threshhold
WITH per_client AS
(
SELECT Clients.client_id, Clients.company_name,
SUM(shipments.freight_cost_usd) AS Revenue,
COUNT(shipments.shipment_id)AS t_T
FROM Shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
GROUP BY Clients.client_id, Clients.company_name

),
client_status AS
(
SELECT Clients.client_id, Clients.company_name,
COUNT(Shipments.Status) AS Total
FROM Shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
WHERE status='Lost' 
OR status='Delayed'
GROUP BY Clients.client_id, Clients.company_name
),
Client_risk AS
(
SELECT per_client.client_id, per_client.company_name,
per_client.t_T, client_status.Total,
client_status.Total *100.0
/per_client.t_T AS Percnt_total
FROM per_client
INNER JOIN client_status ON client_status.client_id=per_client.client_id
GROUP BY per_client.client_id, per_client.company_name,
per_client.t_T, client_status.Total
)
SELECT COUNT(*) AS Num_of_high_risk_clients,
SUM(per_client.Revenue) AS Total_risk_rev
FROM 
client_risk
INNER JOIN per_client ON client_risk.client_id=per_client.client_id
WHERE Percnt_total>= 15;

--6. Lost revenue
SELECT SUM(freight_cost_usd) AS Lost_Revenue
FROM shipments
WHERE Status='Lost'
OR status='Delayed';


-- =====================
--1.SHIPMENT & REVENUE PERFORMANCE
-- =====================
--1.What is the total freight revenue by cargo_type, ordered highest to lowest?
SELECT  cargo_type, SUM(freight_cost_usd) AS Freight_Revenue
FROM shipments
GROUP BY cargo_type
Order by Freight_Revenue desc;

SELECT SUM(freight_cost_usd) AS Freight_Revenue
FROM shipments;


--2.What percentage of shipments fall into each status category? 
SELECT status, COUNT(shipment_id) AS shipment_cnt,
COUNT(shipment_id)*100/
(SELECT COUNT(shipment_id) FROM Shipments) as shipment_percnt
FROM shipments
GROUP BY status;

--3.Which route generates the most total freight revenue? Which generates the least?
with Most_rev as 
(
SELECT top 1 routes.Route_id, routes.origin_name, routes.destination_name,
SUM(shipments.freight_cost_usd) AS Freight_Revenue
FROM shipments
INNER JOIN routes ON shipments.route_id=routes.route_id
GROUP BY routes.Route_id, routes.origin_name, routes.destination_name
ORDER BY Freight_Revenue desc
),
Least_rev as
(
SELECT top 1 routes.Route_id, routes.origin_name, routes.destination_name,
SUM(shipments.freight_cost_usd) AS Freight_Revenue
FROM shipments
INNER JOIN routes ON shipments.route_id=routes.route_id
GROUP BY routes.Route_id, routes.origin_name, routes.destination_name
ORDER BY Freight_Revenue asc
)
SELECT *, 'Most_rev' as Revenue_rank
FROM
Most_rev
UNION ALL
SELECT *, 'Least_rev' as Revenue_rank
FROM 
Least_rev;

--4.What is the total weight shipped per client — who are the top 10 by volume?
SELECT TOP 10 clients.client_id, clients.company_name,
SUM(shipments.weight_kg) as Total_Weight_kg
FROM Shipments
INNER JOIN Clients ON Shipments.Client_id=Clients.Client_id
GROUP BY  clients.client_id, clients.company_name
ORDER BY TOtal_Weight_kg desc;

--5.Which cargo type has the highest damage rate (damage_reported = 'Yes')?
SELECT Cargo_type, COUNT(damage_reported) as Damage_reprt
FROM Shipments
Where damage_reported = 1
Group by Cargo_type
ORDER BY Damage_reprt desc;

--6.Show the monthly shipment volume trend for 2023 vs 2024 — is it growing or declining?

SELECT DATEPART(Month, shipment_date) AS Months_num,
DATEPART(Year, shipment_date) AS Years,
DATENAME( Month, Shipment_date) AS Months,
COUNT(shipment_id) as Total_shipment_volume
FROM Shipments
WHERE DATEPART(Year, shipment_date) = 2023 
OR DATEPART(Year, shipment_date) =2024
GROUP BY DATEPART(Month, shipment_date), DATEPART(Year, shipment_date),
DATENAME( Month, Shipment_date)
ORDER BY DATEPART(Month, shipment_date) asc;

--7.top routes by shipment volume
WITH Route_volume AS
(
SELECT routes.route_id,routes.origin_name,
routes.destination_name,
COUNT(shipments.shipment_id) AS shipment_volume
FROM Shipments
INNER JOIN routes ON shipments.route_id=routes.route_id
GROUP BY routes.route_id,routes.origin_name,
routes.destination_name
),
Delay_prcnt AS
(
SELECT routes.route_id ,routes.origin_name ,routes.destination_name, 
COUNT(CASE WHEN Shipments.actual_delivery_date > shipments.expected_delivery_date THEN 1 END) 
*100/COUNT(shipment_id) AS shipment_percnt
FROM shipments
INNER JOIN ROUTES ON shipments.route_id=routes.route_id
WHERE shipments.actual_delivery_date IS NOT NULL
GROUP BY routes.route_id ,routes.origin_name ,routes.destination_name
)
SELECT Route_volume.route_id ,Route_volume.origin_name ,Route_volume.destination_name,
Route_volume.shipment_volume,
Delay_prcnt.shipment_percnt
FROM Route_volume
INNER JOIN Delay_prcnt ON Route_volume.route_id=Delay_prcnt.route_id
ORDER BY Delay_prcnt.shipment_percnt desc;

-- =====================
 --DELAY ANALYSIS
 -- =====================

--1.For all Delivered shipments, calculate the delay in days: actual_delivery_date - expected_delivery_date
SELECT Shipment_id, DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) as Delay
FROM shipments
WHERE Status='Delivered'
GROUP By Shipment_id, DATEDIFF(DAY,expected_delivery_date,actual_delivery_date)
ORDER BY Delay desc;


--2.What is the average delay per route? Which route is most consistently late?

SELECT top 5 routes.route_id ,routes.origin_name ,routes.destination_name, 
ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay
FROM shipments
INNER JOIN ROUTES ON shipments.route_id=routes.route_id
WHERE shipments.actual_delivery_date IS NOT NULL
GROUP BY routes.route_id ,routes.origin_name ,routes.destination_name
ORDER BY DELAY desc;

--3.What is the average delay per origin warehouse
select * fRom warehouses;
SELECT routes.route_id ,routes.origin_name ,routes.destination_name, 
ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay
FROM shipments
INNER JOIN ROUTES ON shipments.route_id=routes.route_id
WHERE shipments.actual_delivery_date IS NOT NULL
GROUP BY routes.route_id ,routes.origin_name ,routes.destination_name
ORDER BY DELAY desc;


--4.Does traffic level (High / Medium / Low) significantly impact delay rate?
SELECT routes.Traffic_level, COUNT(shipments.shipment_id) AS Total_shipments,
ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay
FROM shipments
INNER JOIN ROUTES ON shipments.route_id=routes.route_id
WHERE shipments.actual_delivery_date IS NOT NULL
GROUP BY routes.Traffic_level
ORDER BY DELAY desc;


--5.Is there a relationship between driver rating and average delay? (Group drivers into rating bands: below 3.5, 3.5–4.2, above 4.2)
SELECT 
CASE 
WHEN drivers.rating BETWEEN 0 AND 3.5 THEN '<=3.5'
WHEN drivers.rating BETWEEN 3.6 AND 4.2 THEN '3.6-4.2'
ELSE 'Above 4.2'
END AS Drivers_rating,
ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay
FROM shipments
INNER JOIN drivers ON shipments.driver_id= Drivers.Driver_id
GROUP BY CASE 
WHEN drivers.rating BETWEEN 0 AND 3.5 THEN '<=3.5'
WHEN drivers.rating BETWEEN 3.6 AND 4.2 THEN '3.6-4.2'
ELSE 'Above 4.2'
END
ORDER BY Delay desc;

--6.Which warehouse origin has the worst on-time delivery rate?
SELECT warehouses.warehouse_id, warehouses.warehouse_name, routes.origin_name,
COUNT(CASE WHEN Shipments.actual_delivery_date > shipments.expected_delivery_date THEN 1 END) *100/
COUNT(shipment_id) AS shipment_percnt
FROM shipments
INNER JOIN routes ON shipments.route_id= routes.route_id
INNER JOIN warehouses ON routes.origin_warehouse_id=warehouses.warehouse_id
WHERE shipments.Status= 'Delivered'
OR shipments.Status= 'Delayed'
GROUP BY warehouses.warehouse_id, warehouses.warehouse_name, routes.origin_name
ORDER BY shipment_percnt asc;

--7.Monthly on-time rate trend 2023 vs 2024
SELECT DATEPART(Month, shipment_date) AS Months_num,
DATEPART(Year, shipment_date) AS Years,
DATENAME( Month, Shipment_date) AS Months,
COUNT(CASE WHEN Shipments.actual_delivery_date <= shipments.expected_delivery_date THEN 1 END) *100.0/
COUNT(shipment_id) AS shipment_percnt
FROM Shipments
WHERE (DATEPART(Year, shipment_date) = 2023 
OR DATEPART(Year, shipment_date) =2024)
AND (shipments.Status= 'Delivered'
OR shipments.Status= 'Delayed')
GROUP BY DATEPART(Month, shipment_date), DATEPART(Year, shipment_date),
DATENAME( Month, Shipment_date)
ORDER BY DATEPART(Month, shipment_date) asc;


SELECT DATEPART(Month, shipment_date) AS Months_num,
DATEPART(Year, shipment_date) AS Years,
DATENAME( Month, Shipment_date) AS Months,
SUM(freight_cost_usd) AS Lost_Revenue
FROM Shipments
WHERE (DATEPART(Year, shipment_date) = 2023 
OR DATEPART(Year, shipment_date) =2024)
AND (shipments.Status= 'Lost'
OR shipments.Status= 'Delayed')
GROUP BY DATEPART(Month, shipment_date), DATEPART(Year, shipment_date),
DATENAME( Month, Shipment_date)
ORDER BY DATEPART(Month, shipment_date) asc;

-- =====================
--Driver & Fleet Performance
-- =====================

--1.Rank all active drivers by total completed shipments using a window function.

WITH ranked_drivers AS 
(
SELECT drivers.driver_id, drivers.full_name, drivers.assigned_warehouse,
COUNT(shipments.shipment_id) AS Total_completed_shipments,
RANK() OVER( ORDER BY COUNT(shipments.shipment_id) desc) AS drivers_ranks
FROM shipments
INNER JOIN drivers ON Shipments.driver_id=drivers.driver_id
WHERE shipments.status ='Delivered'
GROUP BY drivers.driver_id, drivers.full_name,drivers.assigned_warehouse
)
SELECT *
FROM ranked_drivers;


--2.Which driver has the highest damage rate across their deliveries?
SELECT  drivers.driver_id, drivers.full_name,
COUNT(shipments.shipment_id) as total_shp,
COUNT(CASE WHEN shipments.damage_reported = 1 THEN 1 END) as num_damages
FROM shipments
INNER JOIN Drivers on shipments.driver_id=drivers.driver_id
WHERE shipments.damage_reported =1
GROUP BY drivers.driver_id, drivers.full_name
ORDER BY num_damages desc;


--3.Which vehicle type (10-Ton Truck, Refrigerated Van, etc.) has the most shipments? The most delays?

WITH most_shipments AS
(
SELECT TOP 1 vehicles.vehicle_type, COUNT(Shipments.shipment_id) AS  Total
FROM shipments
INNER JOIN vehicles ON SHipments.vehicle_id=vehicles.vehicle_id
GROUP BY vehicles.vehicle_type
ORDER BY Total desc
),
most_delays AS
(
SELECT TOP 1 vehicles.vehicle_type, 
ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay
FROM shipments
INNER JOIN vehicles ON SHipments.vehicle_id=vehicles.vehicle_id
GROUP BY vehicles.vehicle_type
ORDER BY Delay desc
)
SELECT *, 'Most_shipments' AS Title
FROM Most_shipments
UNION ALL
SELECT *, 'Most_delays' AS Title
FROM most_delays;

--4.Compare each driver's average delay against the overall fleet average.
SELECT * FROM drivers;

SELECT DISTINCT drivers.driver_id, drivers.full_name,
ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay,
(SELECT ROUND(AVG(CAST(DATEDIFF(DAY,expected_delivery_date,actual_delivery_date) AS DECIMAL(10,2))),2) as Delay
FROM shipments
WHERE actual_delivery_date IS NOT NULL) AS overall_fleet_average
FROM shipments
INNER JOIN Drivers ON shipments.driver_id=drivers.driver_id
GROUP BY drivers.driver_id, drivers.full_name
ORDER BY Delay desc;

-- =====================
--Client & Business Risk Analysis
-- =====================

--1.What is the total freight cost per client vs their credit limit? Flag clients over 80% utilisation.

WITH Cost_per_client AS
(
SELECT Clients.client_id, Clients.company_name, 
SUM(shipments.freight_cost_usd) AS Total_freight_cost_usd,
clients.credit_limit_usd
FROM Shipments
INNER JOIN Clients ON Shipments.client_id=clients.client_id
GROUP BY Clients.client_id, Clients.company_name,clients.credit_limit_usd
)
SELECT *, Cost_per_client.Total_freight_cost_usd*100/Cost_per_client.credit_limit_usd As Credit_utilization_percnt,
'Above 80% utilization' as Remark
FROM Cost_per_client
WHERE Cost_per_client.Total_freight_cost_usd >(SELECT (80.0* Cost_per_client.credit_limit_usd/100));


--2.Which industry sector (Manufacturing, Agriculture, etc.) generates the most shipment volume and revenue?
WITH mst_shipmemt_vol AS
(
SELECT TOP 1 clients.industry,
SUM(shipments.volume_cbm) as Figures
FROM shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
GROUP BY clients.industry
ORDER BY figures desc
),
Mst_revenue AS
(
SELECT TOP 1 clients.industry,
SUM(shipments.freight_cost_usd) AS Figures
FROM shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
GROUP BY clients.industry
ORDER BY Figures desc
)
SELECT *, 'most shipment volume' AS Remark
FROM mst_shipmemt_vol
UNION ALL
SELECT *, 'Most Revenue' AS Remark
FROM Mst_revenue;


--3.Which clients have had the most Delayed or Lost shipments — a potential churn risk?
WITH per_client AS
(
SELECT Clients.client_id, Clients.company_name,
COUNT(shipments.shipment_id)AS Total_shipments
FROM Shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
GROUP BY Clients.client_id, Clients.company_name

),
client_status AS
(
SELECT Clients.client_id, Clients.company_name,
COUNT(Shipments.Status) as Delayed_lost
FROM Shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
WHERE status='Lost'
OR status='Delayed'
GROUP BY Clients.client_id, Clients.company_name
)
SELECT per_client.client_id, per_client.company_name,
per_client.Total_shipments, client_status.Delayed_lost,
client_status.Delayed_lost *100.0
/per_client.Total_shipments AS Percnt_total
FROM per_client
INNER JOIN client_status ON client_status.client_id=per_client.client_id
GROUP BY per_client.client_id, per_client.company_name,
per_client.Total_shipments, client_status.Delayed_lost
Order By Percnt_total desc;


-- Route Delay Rate
WITH Cost_per_client AS
(
SELECT Clients.client_id, Clients.company_name, 
SUM(shipments.freight_cost_usd) AS Total_freight_cost_usd,
clients.credit_limit_usd
FROM Shipments
INNER JOIN Clients ON Shipments.client_id=clients.client_id
GROUP BY Clients.client_id, Clients.company_name,clients.credit_limit_usd
),
credit_util AS
(
SELECT *, Cost_per_client.Total_freight_cost_usd*100/Cost_per_client.credit_limit_usd As Credit_utilization_percnt,
'Above 80% utilization' as Remark
FROM Cost_per_client
---WHERE Cost_per_client.Total_freight_cost_usd >(SELECT (80.0* Cost_per_client.credit_limit_usd/100))
),
per_client AS
(
SELECT Clients.client_id, Clients.company_name,
COUNT(shipments.shipment_id)AS Total_shipments
FROM Shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
GROUP BY Clients.client_id, Clients.company_name

),
client_status AS
(
SELECT Clients.client_id, Clients.company_name,
COUNT(Shipments.Status) as Delayed_lost
FROM Shipments
INNER JOIN clients ON shipments.client_id=clients.client_id
WHERE status='Lost'
OR status='Delayed'
GROUP BY Clients.client_id, Clients.company_name
),
Client_risk AS
(
SELECT per_client.client_id, per_client.company_name,
per_client.Total_shipments, client_status.Delayed_lost,
client_status.Delayed_lost *100.0
/per_client.Total_shipments AS Percnt_total
FROM per_client
INNER JOIN client_status ON client_status.client_id=per_client.client_id
GROUP BY per_client.client_id, per_client.company_name,
per_client.Total_shipments, client_status.Delayed_lost
),
status_percnt AS
(
SELECT per_client.client_id, per_client.company_name,
per_client.Total_shipments, client_status.Delayed_lost,
client_status.Delayed_lost *100.0
/per_client.Total_shipments AS Percnt_total
FROM per_client
INNER JOIN client_status ON client_status.client_id=per_client.client_id
GROUP BY per_client.client_id, per_client.company_name,
per_client.Total_shipments, client_status.Delayed_lost
),
route_stats AS
(
SELECT clients.Company_name, routes.origin_warehouse_id,
routes.destination_name,
COUNT(shipments.shipment_id) AS route_shipment_count
FROM shipments
INNER JOIN Routes ON shipments.route_id=routes.route_id
INNER JOIN clients ON shipments.client_id=clients.Client_id
GROUP BY clients.Company_name, routes.origin_warehouse_id,
routes.destination_name
)
SELECT credit_util.Company_name,
route_stats.origin_warehouse_id, route_stats.destination_name,
route_stats.route_shipment_count,
status_percnt.Total_shipments,
status_percnt.Percnt_total AS delayed_lost_percnt,
credit_util.Total_freight_cost_usd,credit_util.credit_limit_usd,
credit_util.credit_utilization_percnt
FROM credit_util
LEFT JOIN status_percnt ON credit_util.client_id=status_percnt.client_id
LEFT JOIN route_stats ON credit_util.Company_name=route_stats.Company_name
WHERE status_percnt.Percnt_total >= 15;



SELECT * FROM shipments;
SELECT * FROM clients;
SELECT * FROM routes;

SELECT clients.Company_name, routes.origin_warehouse_id,
routes.destination_name
FROM shipments
INNER JOIN Routes ON shipments.route_id=routes.route_id
INNER JOIN clients ON shipments.client_id=clients.Client_id
GROUP BY clients.Company_name, routes.origin_warehouse_id,
routes.destination_name;