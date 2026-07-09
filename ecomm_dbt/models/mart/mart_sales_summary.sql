{{
    config(
        materialized         = 'incremental',
        unique_key           = ['date_key', 'product_id', 'customer_segment', 'channel'],
        incremental_strategy = 'merge'
    )
}}

with fact as (
    select * from {{ ref('fact_order_items') }}
    {% if is_incremental() %}
        where _loaded_at > (select max(_refreshed_at) from {{ this }})
    {% endif %}
),

dim_customer as (
    select customer_id, segment from {{ ref('dim_customer') }}
)

select
    f.date_key,
    f.product_id,
    dc.segment                                                  as customer_segment,
    f.channel_key                                               as channel,
    count(distinct f.order_id)                                  as total_orders,
    sum(f.quantity)                                             as total_units_sold,
    sum(f.gross_revenue)                                        as total_gross_revenue,
    sum(f.net_revenue)                                          as total_net_revenue,
    sum(f.cost_of_goods)                                        as total_cogs,
    sum(f.gross_margin)                                         as total_gross_margin,
    -- margin_pct: virtual column from MART DDL expressed as SQL
    case
        when sum(f.net_revenue) = 0 then null
        else sum(f.gross_margin) / sum(f.net_revenue)
    end                                                         as margin_pct,
    sum(f.net_revenue) / nullif(count(distinct f.order_id), 0) as avg_order_value,
    current_timestamp()                                         as _refreshed_at

from fact f
left join dim_customer dc on f.customer_id = dc.customer_id

group by 1, 2, 3, 4
