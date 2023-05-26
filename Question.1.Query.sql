Use Toy_Data_Project;

select * from dbo.products;

-- Removed '$' from data to be able to cast
Update dbo.products
Set Product_Price = replace(Product_Price, '$', '');
Update dbo.products
Set Product_Cost = replace(Product_Cost, '$', '');


--Finding Margins for Products: This will be used in report data to have recommendations for sales
select distinct Product_ID, Product_Name, round((cast(Product_Price as float)/cast(Product_Cost as float))/cast(Product_Price as float)*100, 2) Margin_Percent
from dbo.products
order by Margin_Percent desc;

-- Master Table for Dashboard
with Sales_Table (Store_ID, Store_Location, Product_Name, Product_Category, Date, Units, Sales, Profit) as 
(
select s.Store_ID, st.Store_Location, p.Product_Name, p.Product_Category, Date, Units,
(cast(Product_Price as float)*cast(Units as int)) Sales,
(cast(Product_Price as float)-cast(Product_Cost as float))*cast(Units as float) Profit
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
Join stores as st
On s.Store_ID = st.Store_ID
)
select Store_ID, Store_Location, Product_Name, Product_Category, Date, sum(Sales) Daily_Sales, sum(Units) Daily_Units, sum(Profit) Daily_Profit from Sales_Table
group by Store_ID, Store_Location, Product_Name, Product_Category, Date
Order by 1,5;

-- Inventory Analysis for missed Sales due to out of stock, use R for stats and hypothesis testing
with Sales_Table (Store_ID, Product_ID, Date, Units, Product_Category) as 
(
select Store_ID, s.Product_ID, s.Date, Units, p.Product_Category
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
)
select Store_ID, Product_ID, Date, sum(Cast(Units as float)) Daily_Units_Sold from Sales_Table
group by Store_ID, Product_ID, Date
Order by 1, 2, 3; 

--Use this table to find out the average products sold per month in R
with Sales_Table (Store_ID, Mon_th, Y_ear, Product_ID, Units, Product_Name, Profit) as 
(
select Store_ID, month(s.Date) Mon_th, Year(s.Date) Y_ear, s.Product_ID, Units, Product_Name, (cast(Product_Price as float)-cast(Product_Cost as float))*cast(Units as int) profit
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
)
select Store_ID, Mon_th, Y_ear, sum(cast(Units as bigint)) Total_Units_Sold, Product_Name, sum(cast(Profit as bigint)) Total_Profit from Sales_Table
group by Store_ID, Product_Name, Mon_th, Y_ear
order by Store_ID, Mon_th, Y_ear, Product_Name;

-- best month for stores
with Sales_Table (Store_ID, Mon_th, Y_ear, Units, Sum_Sales) as 
(
select s.Store_ID, Month(s.Date) Mon_th, Year(s.Date) Y_ear, Units,
sum((cast(Product_Price as float)*cast(Units as float))) Sum_Sales
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
group by s.Store_ID, s.Date, Units
)
select Store_ID, max(Sum_Sales) as highest_sales, Mon_th, Y_ear
from Sales_Table
group by Store_ID, Mon_th, Y_ear
having max(Sum_Sales) in (select max(Sum_Sales) from Sales_Table where Y_ear = 2018 group by Store_ID) and Y_ear = 2018 -- to get 2018, change 2017 to 2018 in query
Order by 1, 2 desc;

-- on average best stores per year
with Sales_Table (Store_ID, Store_Location, Y_ear, Units, Sum_Sales) as 
(
select s.Store_ID, st.Store_location, Year(s.Date) Y_ear, Units,
sum((cast(Product_Price as float)*cast(Units as float))) Sum_Sales
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
Join stores as st
On s.Store_ID = st.Store_ID
group by s.Store_ID, s.Date, Units, st.Store_Location
)
select Store_ID, Store_Location, round(sum(Sum_Sales)/12,2) as Average_sales, Y_ear
from Sales_Table
where Y_ear = 2018 -- to get 2018, change 2017 to 2018 in query
group by Store_ID, Y_ear, Store_Location
Order by 3 desc;

-- Store Locations and Product Categories
with Sales_Table (Store_Location, Product_Category, Y_ear, Units, Sum_Sales) as 
(
select st.Store_location, p.Product_Category, Year(s.Date) Y_ear, Units,
sum((cast(Product_Price as float)*cast(Units as float))) Sum_Sales
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
Join stores as st
On s.Store_ID = st.Store_ID
group by p.Product_Category, s.Date, Units, st.Store_Location
)
select Store_Location, Product_Category, round(sum(Sum_Sales),2) as Location_Product_Sales, Y_ear
from Sales_Table
where Y_ear = 2018 -- to get 2018, change 2017 to 2018 in query
group by Product_Category, Y_ear, Store_Location
Order by 3 desc;


-- Product popularity used for Tableau animations
with Sales_Table (Store_ID, Date, Units, Product_Name, Store_Location, Sales) as 
(
select s.Store_ID, s.Date, Units, p.Product_Name, st.Store_Location,
round(cast(Product_Price as float)*cast(Units as int),2) Sales
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
Join stores as st
On s.Store_ID = st.Store_ID
)
select Date, Product_Name, sum(Sales) Sales_by_Day, Sum(cast(Units as bigint)) Product_Popularity_by_Day from Sales_Table
group by Date, Product_Name
Order by 1;

-- Best Product per month
with Sales_Table (Product_Name, [Month], [Year], Sales) as
(
select p.Product_Name, Month(s.Date) [Month], year(s.Date) [Year],
sum((cast(p.Product_Price as float) * cast(s.Units as int))) Sales
from sales as s
JOIN products as p on s.Product_ID = p.Product_ID
group by p.Product_Name, MONTH(s.Date), YEAR(s.Date)
)
select Product_Name, [Month], [Year]
from (select Product_Name, [Month], [Year], RANK() OVER (PARTITION BY [Month], [Year] ORDER BY Sales DESC) as Rank
from Sales_Table) as RankedSales
where Rank = 1 AND [Year] = 2018
order by [Year], [Month];

-- Best Store per month
with Sales_Table (Store_ID, Store_Location, [Month], [Year], Sales) as
(
select s.Store_ID, st.Store_Location, Month(s.Date) [Month], year(s.Date) [Year],
sum((cast(p.Product_Price as float) * cast(s.Units as int))) Sales
from sales as s
JOIN products as p on s.Product_ID = p.Product_ID
Join stores as st on s.Store_ID = st.Store_ID
group by s.Store_ID, st.Store_Location, MONTH(s.Date), YEAR(s.Date)
)
select Store_ID, Store_Location, [Month], [Year]
from (select Store_ID, Store_Location, [Month], [Year], RANK() OVER (PARTITION BY [Month], [Year] ORDER BY Sales DESC) as Rank
from Sales_Table) as RankedSales
where Rank = 1 AND [Year] = 2017 -- change between 2017 and 2018
order by [Year], [Month];

-- Overall Profit for Product Categories
with Sales_Table (Store_ID, Date, Units, Product_Category, Profit) as 
(
select Store_ID, s.Date, Units, p.Product_Category, (cast(Product_Price as float)-cast(Product_Cost as float))*cast(Units as int) profit
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
)
select Product_Category, sum(cast(Units as bigint)) Total_Units_Sold, sum(cast(Profit as bigint)) Total_Profit from Sales_Table
group by Product_Category
order by Total_Profit desc; -- Pie Chart of overall category Sales, or used as a table to show total #'s

-- Sales for Product Categories by month
with Sales_Table (Store_ID, Date, Product_ID, Units, Product_Category, Profit) as 
(
select Store_ID, Date, s.Product_ID, Units, Product_Category, (cast(Product_Price as float)-cast(Product_Cost as float))*cast(Units as int) profit
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
)
select Product_Category, Date, sum(cast(Units as bigint)) Total_Units_Sold, sum(cast(Profit as bigint)) Total_Profit from Sales_Table
group by Product_Category, Date
order by 1, 2, 4 desc;



-- Profit for Product Names/Category to determine which product is most profitable
with Sales_Table (Store_ID, Date, Product_ID, Units, Product_Name, Product_Category, Margin_Percent, Profit) as 
(
select Store_ID, s.Date, s.Product_ID, Units, Product_Name, Product_Category, 
round((cast(Product_Price as float)/cast(Product_Cost as float))/cast(Product_Price as float)*100, 2) Margin_Percent,
(cast(Product_Price as float)-cast(Product_Cost as float))*cast(Units as int) profit
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
)
select Product_Name, Product_Category, sum(cast(Units as bigint)) Total_Units_Sold, sum(cast(Profit as bigint)) Total_Profit, Margin_Percent
from Sales_Table
group by Product_Name, Product_Category, Margin_Percent
order by Total_Units_Sold desc;

