with ether_emitted_by_date  as (
  select date(block_timestamp) as date, sum(value) as value
  from `bigquery-public-data.crypto_ethereum.traces`
  where trace_type in ('genesis', 'reward')
  group by date(block_timestamp)
)
select date, sum(value) OVER (ORDER BY date) / power(10, 18) AS supply
from ether_emitted_by_date
