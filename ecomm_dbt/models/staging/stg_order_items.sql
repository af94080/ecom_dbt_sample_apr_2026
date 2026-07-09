with source as (
    select * from {{ source('landing', 'lnd_order_items') }}
),

renamed as (
    select
        item_id,
        order_id,
        product_id,
        try_to_number(quantity)::int                as quantity,
        try_to_decimal(unit_price, 18, 4)           as unit_price,
        try_to_decimal(discount, 18, 4)             as discount_amount,
        _loaded_at,
        _source
    from source
)

select * from renamed
