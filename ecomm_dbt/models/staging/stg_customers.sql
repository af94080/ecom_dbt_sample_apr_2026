with source as (
    select * from {{ source('landing', 'lnd_customers') }}
),

renamed as (
    select
        customer_id,
        first_name,
        last_name,
        trim(first_name || ' ' || last_name)        as full_name,
        lower(email)                                as email,
        segment,
        country,
        city,
        signup_date,
        _loaded_at,
        _source
    from source
)

select * from renamed
