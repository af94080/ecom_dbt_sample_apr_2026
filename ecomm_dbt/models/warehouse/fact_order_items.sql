{{
    config(
        materialized        = 'incremental',
        unique_key          = 'item_id',
        incremental_strategy = 'merge'
    )
}}

with order_items as (
    select * from {{ ref('stg_order_items') }}
    {% if is_incremental() %}
        where _loaded_at > (select max(_loaded_at) from {{ this }})
    {% endif %}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

dim_product as (
    select product_id, cost_price from {{ ref('dim_product') }}
),

dim_date as (
    select date_key, full_date from {{ ref('dim_date') }}
)

select
    oi.item_id,
    o.order_id,
    o.customer_id,
    oi.product_id,
    d.date_key,
    o.channel                                                       as channel_key,
    o.order_status,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,

    -- virtual columns from the DDL are managed here as explicit expressions
    oi.quantity * oi.unit_price                                     as gross_revenue,
    oi.quantity * oi.unit_price - oi.discount_amount                as net_revenue,
    dp.cost_price * oi.quantity                                     as cost_of_goods,
    oi.quantity * oi.unit_price
        - oi.discount_amount
        - (dp.cost_price * oi.quantity)                             as gross_margin,

    oi._loaded_at

from order_items oi
inner join orders      o  on oi.order_id  = o.order_id
left  join dim_product dp on oi.product_id = dp.product_id
left  join dim_date    d  on o.order_date  = d.full_date
