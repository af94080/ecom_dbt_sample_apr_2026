{{ config(materialized='table') }}

select
    channel_key,
    channel_name,
    channel_type
from {{ ref('channel_lookup') }}
