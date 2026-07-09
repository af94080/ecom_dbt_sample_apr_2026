{{
    config(
        materialized         = 'incremental',
        unique_key           = 'customer_id',
        incremental_strategy = 'merge'
    )
}}

with fact as (
    select * from {{ ref('fact_order_items') }}
),

dim_customer as (
    select * from {{ ref('dim_customer') }}
),

dim_date as (
    select date_key, full_date from {{ ref('dim_date') }}
),

customer_orders as (
    select
        f.customer_id,
        count(distinct f.order_id)                              as total_orders,
        sum(f.quantity)                                         as total_units,
        sum(f.net_revenue)                                      as total_spend,
        sum(f.net_revenue)
            / nullif(count(distinct f.order_id), 0)            as avg_order_value,
        min(d.full_date)                                        as first_order_date,
        max(d.full_date)                                        as last_order_date,
        datediff('day', max(d.full_date), current_date())       as days_since_last_order
    from fact f
    left join dim_date d on f.date_key = d.date_key
    group by 1
),

rfm_scored as (
    select
        *,
        -- RFM segmentation: Recency / Frequency / Monetary
        case
            when days_since_last_order <= 30
                 and total_orders >= 5
                 and total_spend  >= 500  then 'Champions'
            when days_since_last_order <= 90
                 and total_orders >= 3    then 'Loyal'
            when days_since_last_order <= 180 then 'At Risk'
            else 'Lost'
        end                                                     as rfm_segment
    from customer_orders
)

select
    r.customer_id,
    dc.full_name,
    dc.segment,
    dc.country,
    r.total_orders,
    r.total_units,
    r.total_spend,
    r.avg_order_value,
    r.first_order_date,
    r.last_order_date,
    r.days_since_last_order,
    r.rfm_segment,
    current_timestamp()                                         as _refreshed_at

from rfm_scored r
left join dim_customer dc on r.customer_id = dc.customer_id
