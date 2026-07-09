{{ config(materialized='table') }}

with products as (
    select * from {{ ref('stg_products') }}
),

suppliers as (
    select * from {{ ref('stg_suppliers') }}
)

select
    p.product_id,
    p.sku,
    p.product_name              as name,
    p.category,
    p.sub_category,
    p.cost_price,
    p.list_price,
    s.supplier_name,
    true                        as is_active,
    current_timestamp()         as _updated_at
from products p
left join suppliers s on p.supplier_id = s.supplier_id
