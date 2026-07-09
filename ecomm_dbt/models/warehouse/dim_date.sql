{{ config(materialized='table') }}

with date_spine as (
    {{
        dbt_utils.date_spine(
            datepart   = "day",
            start_date = "cast('2020-01-01' as date)",
            end_date   = "cast('2030-12-31' as date)"
        )
    }}
),

dates as (
    select
        cast(to_char(date_day, 'YYYYMMDD') as int)          as date_key,
        date_day                                             as full_date,
        year(date_day)                                       as year,
        quarter(date_day)                                    as quarter,
        month(date_day)                                      as month,
        to_char(date_day, 'MMMM')                           as month_name,
        weekofyear(date_day)                                 as week,
        -- ISO: 1=Mon … 7=Sun (matches DDL comment)
        dayofweekiso(date_day)                               as day_of_week,
        to_char(date_day, 'DY')                             as day_name,
        iff(dayofweekiso(date_day) in (6, 7), true, false)  as is_weekend,
        false                                                as is_holiday
    from date_spine
)

select * from dates
