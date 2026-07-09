with source as (
    select * from {{ source('landing', 'lnd_suppliers') }}
),

renamed as (
    select
        supplier_id,
        name                                        as supplier_name,
        country                                     as supplier_country,
        lower(contact_email)                        as contact_email,
        _loaded_at,
        _source
    from source
)

select * from renamed
