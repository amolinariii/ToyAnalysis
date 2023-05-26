library(DBI)
library(odbc)
library(dbplyr)
library(RODBC)
library(tidyverse)

#always change working directory

db_conn <- odbcConnect("ToysDSN", rows_at_time = 1)

if(db_conn == -1){
  quit("no", 1)
}
  
# now that connection is estabilished, you can run sql code in as normal
# ^ under a variable

Inventory_Table <- "
with Sales_Table (Store_ID, Date, Product_ID, Units, Product_Name, Profit) as 
(
select s.Store_ID, s.Date, s.Product_ID, Units, Product_Name,
(cast(Product_Price as float)-cast(Product_Cost as float))*cast(Units as int) profit
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
where s.Date between '2017-01-01' and '2018-09-30'
)
select Store_ID, Date, Product_ID, Product_Name, sum(cast(Units as bigint)) Total_Units_Sold,
sum(cast(Profit as bigint)) Total_Profit from Sales_Table
group by Store_ID, Date, Product_ID, Product_Name
order by Store_ID, Date, Product_ID;"

Out_of_Stock <- sqlQuery(db_conn, Inventory_Table, stringsAsFactors = FALSE)



View(Out_of_Stock)



# Group by mean of multiple columns
df2 <- Out_of_Stock %>% group_by(Store_ID, Product_Name) %>% 
  summarise(sum_units = sum(Total_Units_Sold),
    mean_units=sum(Total_Units_Sold)/637,
            All_units = sum(Total_Units_Sold),
            n_units= length(Product_Name),
            sd_ = (((((sd(Total_Units_Sold))^2)*n_units)+(mean_units^2)*(637-n_units))/636)^.5,
            confidence_units = round(mean_units-1.65*sd_/((637)^(0.5)),2),
            min_units = min(Total_Units_Sold),
            .groups = 'drop') %>%
  as.data.frame()
df2
write.csv(df2, "Inventory Analysis1.csv", row.names=F)

Sales <- "with Sales_Table (Store_ID, Date, Units, Product_Category, Sales) as 
(
select Store_ID, s.Date, Units, p.Product_Category, (cast(Product_Price as float))*cast(Units as float) Sales
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
)
select Date, Sum(Sales) Daily_Sales from Sales_Table
group by Date
Order by 1;"

Sales_df <- sqlQuery(db_conn, Sales, stringsAsFactors = FALSE)


df3 <- Sales_df %>% 
  summarise(date_count=length(Date),
            mean_daily_sales=sum(Daily_Sales)/date_count,
            min_sales = min(Daily_Sales),
            max_sales = max(Daily_Sales),
            sd_ = ((sd(Daily_Sales)^2)*date_count/(date_count-1))^.5,
            confidence_units = round(mean_daily_sales-1.96*sd_/((date_count)^(0.5)),2),
            .groups = 'drop') %>%
  as.data.frame()
df3


Store_Category_Sum <- "
with Sales_Table (Store_ID, Date, Units, Product_Category, Store_Location, Profit) as 
(
select s.Store_ID, s.Date, Units, p.Product_Category, st.Store_Location,
(cast(Product_Price as float)-cast(Product_Cost as float))*cast(Units as int) profit
from sales as s
Join products as p
On s.Product_ID = p.Product_ID
Join stores as st
On s.Store_ID = st.Store_ID
)
select Date, Store_Location, Product_Category, Sum(Profit) Daily_Sales from Sales_Table
group by Date, Store_Location, Product_Category
Order by 1, 2;"

Product_df <- sqlQuery(db_conn, Store_Category_Sum, stringsAsFactors = FALSE)

df4 <- Product_df %>% group_by(Store_Location,Product_Category) %>% 
  summarise(sum_sales = sum(Daily_Sales),
            mean_sales=mean(Daily_Sales),
            max_Sales= max(Daily_Sales),
            min_units = min(Daily_Sales),
            .groups = 'drop') %>%
  as.data.frame()
df4
write.csv(df4, "Product Category by Location.csv", row.names=F)






odbcClose(db_conn)
