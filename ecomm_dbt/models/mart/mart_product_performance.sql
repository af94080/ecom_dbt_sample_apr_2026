{{
    config(
        materialized         = 'incremental',
        unique_key           = ['product_id', 'date_key'],
        incremental_strategy = 'merge'
    )
}}

with fact as (
    select * from {{ ref('fact_order_items') }}
    {% if is_incremental() %}
        where _loaded_at > (select max(_refreshed_at) from {{ this }})
    {% endif %}
),

dim_product as (
    select product_id, name, category, sub_category
    from {{ ref('dim_product') }}
),

product_daily as (
    select
        f.product_id,
        f.date_key,
        dp.name                                                 as product_name,
        dp.category,
        dp.sub_category,
        sum(f.quantity)                                         as units_sold,
        sum(f.net_revenue)                                      as revenue,
        sum(f.cost_of_goods)                                    as cogs,
        sum(f.gross_margin)                                     as gross_margin,
        case
            when sum(f.net_revenue) = 0 then null
            else sum(f.gross_margin) / sum(f.net_revenue)
        end                                                     as margin_pct
    from fact f
    left join dim_product dp on f.product_id = dp.product_id
    group by 1, 2, 3, 4, 5
)

select
    product_id,
    date_key,
    product_name,
    category,
    sub_category,
    units_sold,
    revenue,
    cogs,
    gross_margin,
    margin_pct,
    -- rank_in_category: daily rank by revenue within each product category
    row_number() over (
        partition by date_key, category
        order by revenue desc
    )                                                           as rank_in_category,
    current_timestamp()                                         as _refreshed_at

from product_daily
