with source as (
    select * from {{ source('landing', 'lnd_orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        status                                      as order_status,
        try_to_decimal(total_amount, 18, 4)         as total_amount,
        order_ts,
        order_date,
        channel,
        coalesce(order_discount, 0)                 as order_discount,
        _loaded_at,
        _source
    from source
)

select * from renamed
