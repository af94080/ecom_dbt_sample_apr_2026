{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('stg_customers') }}
)

select
    customer_id,
    full_name,
    email,
    segment,
    country,
    city,
    signup_date,
    true                    as is_active,
    current_timestamp()     as _updated_at
from customers
