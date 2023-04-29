-- 1) markets operating in the APAC region:
select   distinct(market)
from     dim_customer
where    region = "APAC";

-- 2) percentage increase in unique product in fiscal year 2021 as compared to 2020
with     cte2020
as       (select   product_code,count(distinct(product_code)) as unique_product2020
		  from     fact_gross_price
          where    fiscal_year = 2020),
         cte2021
as       (select   product_code,count(distinct(product_code)) as unique_product2021
	      from     fact_gross_price
          where    fiscal_year=2021)

select   cte2020.unique_product2020,cte2021.unique_product2021,((cte2021.unique_product2021/cte2020.unique_product2020)-1)*100 as percentage_increase
from     cte2020
join     cte2021
on       cte2020.product_code=cte2021.product_code;

-- 3) count of unique product in each segment
select   segment,count(distinct(product_code)) as product_count
from     dim_product
group by segment;

-- 4) count of product each in segmentin fiscal year 2020 & 2021 and the differnce betweem them
with   ps2020
as     (select  dim_product.segment, count(distinct(fact_gross_price.product_code)) as product_count2020
        from    dim_product join fact_gross_price
        on      dim_product.product_code=fact_gross_price.product_code
		where   fiscal_year = 2020
        group by segment),
	   ps2021
as     (select  dim_product.segment, count(distinct(fact_gross_price.product_code)) as product_count2021
        from    dim_product
        join    fact_gross_price
        on      dim_product.product_code=fact_gross_price.product_code
        where   fiscal_year = 2021
        group by segment)

select   ps2020.segment,ps2020.product_count2020,ps2021.product_count2021, ps2021.product_count2021-ps2020.product_count2020 as differnce
from     ps2020
join     ps2021
on       ps2020.segment=ps2021.segment;

-- 5) the product code and product name of product with min and max manufacturing price
with   tbl
as    ((select   product_code,manufacturing_cost
        from     fact_manufacturing_cost 
        order by 2 desc limit 1) 
        union
        (select  product_code,manufacturing_cost
		from     fact_manufacturing_cost 
		order by 2 limit 1))
select  tbl.product_code,dim_product.product,tbl.manufacturing_cost 
from    tbl
join    dim_product
on      tbl.product_code=dim_product.product_code;

-- 6) top 5 customers in 2021 and in India region with above average discount
with   cust_india
as     (select   customer_code,customer
	    from     dim_customer
        where    market="India"),
more_than_avg
as       (select   customer_code, pre_invoice_discount_pct
          from     fact_pre_invoice_deductions
		  where    pre_invoice_discount_pct>(select   avg   (pre_invoice_discount_pct)
                                                      from  fact_pre_invoice_deductions)
                                                      and   fiscal_year=2021)

select   cust_india.customer_code,cust_india.customer,more_than_avg.pre_invoice_discount_pct
from     cust_india join more_than_avg
on       cust_india.customer_code=more_than_avg.customer_code
order by pre_invoice_discount_pct desc limit 5;

-- 7) monthly sales to atliq exclusive
with an_sale
as   (select month(x.date) as month_,year(x.date) as year_,x.fiscal_year,x.customer_code,x.sold_quantity*y.gross_price as price 
      from fact_sales_monthly x
      left join fact_gross_price y 
      on x.product_code=y.product_code 
      and x.fiscal_year=y.fiscal_year
	  where customer_code
	  in    (select customer_code
			 from dim_customer 
             where customer="Atliq Exclusive"))
(select sum(price),month_,fiscal_year
 from an_sale
 where fiscal_year=2021 
 group by month_ 
 union
 select sum(price),month_,fiscal_year
 from an_sale
 where fiscal_year=2020 
 group by month_)
 order by fiscal_year,month_;

-- 8) quarterly sale quantity for the year of 2020.
select   quarter(date) as quarter_,sum(sold_quantity) as total_quantity
from     fact_sales_monthly
where    fiscal_year=2020
group by quarter_ 
order by quarter_;

-- 9) sales by channel for the fiscal year 2021
with    sales_by_channel
as     (select   c.channel,sum(s.sold_quantity*p.gross_price) as total
		from     dim_customer c, fact_gross_price p,fact_sales_monthly s
		where    c.customer_code=s.customer_code and s.product_code=p.product_code and s.fiscal_year=2021
        group by channel)
 
select  channel,total,total*100/sum(total) over() as contribution
from    sales_by_channel
order by contribution desc
limit 1;

-- 10) top 3  product in each division by quantity sold in 2021
with   quantity_sold_by_division
as    (select   pd.division,pd.product_code,pd.product,sum(s.sold_quantity)as total_sold_quantity
       from     dim_product pd join fact_sales_monthly s
       on       pd.product_code=s.product_code
	   where    s.fiscal_year=2021
       group by product_code
       order by total_sold_quantity desc),
       rank_in_division
as    (select   division,product_code,product,total_sold_quantity, dense_rank() over (partition by division order by total_sold_quantity desc) as rn
	   from     quantity_sold_by_division )
select *
from   rank_in_division
where  rn <=3;



