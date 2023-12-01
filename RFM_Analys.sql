create database ecommerce

-- tablomuzu oluşturuyoruz

create table ecommerce 
(
	InvoiceNo varchar,
	StockCode varchar,
	Description varchar,
	Quantity integer,
	InvoiceDate varchar,
	UnitPrice double precision,
	CustomerID integer,
	Country varchar
)


select * from ecommerce

-- invoicedate tarihini bir türlü import edemediğimiz için ilk olarak ilgili kolonu varchar olarak aldık sonra aşağıdaki gibi kolonun veri tipini güncelledik

Update ecommerce
	SET invoicedate = TO_TIMESTAMP(invoicedate, 'MM.DD.YYYY HH24:MI')
	
ALTER TABLE ecommerce
ALTER COLUMN invoicedate TYPE timestamp USING invoicedate::timestamp;

select * from ecommerce

-- Müşterilerin son alışveriş yaptığı tarihleri getirelim

select
	customerid,
	max(invoicedate)::date
from ecommerce
	where customerid is not null
	group by customerid


-- ilk olarak recency değerini hesaplayalım

with last_invoice as (
	select 
		customerid,
		max(invoicedate)::date last_invoice_date
	from ecommerce
		where customerid is not null
		group by customerid
)
select
	customerid,
	(select max(invoicedate)::date from ecommerce) - last_invoice_date as recency
from last_invoice


-- şimdi frequency değerini hesaplıyoruz

select
	customerid,
	count(invoiceno) frequency
from ecommerce
	where customerid is not null
	group by customerid


-- monetary değeri hesaplıyoruz

select
	customerid,
	sum(unitprice)::numeric(5,0) monetary
from ecommerce
	where customerid is not null
	group by customerid


-- RFM değerleri toplamı

with recency as 
(
with last_invoice as (
select 
customerid,
max(invoicedate)::date last_invoice_date
from ecommerce
where customerid is not null
group by customerid
)
select
customerid,
(select max(invoicedate)::date from ecommerce) - last_invoice_date as recency
from last_invoice
),

frequency as 
(
select
customerid,
count(invoiceno) frequency
from ecommerce
where customerid is not null
group by customerid
),

monetary as 
(
select
customerid,
sum(unitprice)::numeric(5,0) monetary
from ecommerce
where customerid is not null
group by customerid
),

rfm_calculation as (
select 
	r.customerid,
	r.recency,
	f.frequency,
	m.monetary
from 
	monetary m
join
	frequency f
	on
	m.customerid = f.customerid
join
	recency r
	on
	r.customerid = f.customerid
),

rfm_groups as (
select 
	customerid,
	recency,
	ntile(5) over (order by recency) recency_score,
	frequency,
	ntile(5) over (order by frequency desc) frequency_score,
	monetary,
	ntile(5) over (order by monetary desc) monetary_score
from rfm_calculation
),

rfm_scores as (
select 
	*,
	concat(recency_score,frequency_score,monetary_score)::integer rfm_scores
from rfm_groups
)

select
	*,
	case
		when rfm_scores <= 111 and rfm_scores <= 222 then 'Champions'
		when rfm_scores <= 222 and rfm_scores <= 333 then 'Potential Loyalists'
		when rfm_scores <= 333 and rfm_scores <= 444 then 'New Customers'
		when rfm_scores <= 444 and rfm_scores <= 555 then 'At Risk Customers'
		else 'Can’t Lose Them' end as customer_segments
from rfm_scores
)

select 
	count(customerid),
	customer_segments
from customer_segments
	group by 2
	order by 1 desc