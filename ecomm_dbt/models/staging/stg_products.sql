with source as (
    select * from {{ source('landing', 'lnd_products') }}
),

renamed as (
    select
        product_id,
        sku,
        name                                        as product_name,
        category,
        sub_category,
        try_to_decimal(cost_price, 18, 4)           as cost_price,
        try_to_decimal(list_price, 18, 4)           as list_price,
        supplier_id,
        _loaded_at,
        _source
    from source
)

select * from renamed
