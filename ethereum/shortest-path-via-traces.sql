# This query will fail if there are too many traces. 
# There is a workaround here:
# https://console.cloud.google.com/bigquery?sq=749871510730:082d50190dc04d79aaf7ee4d5c6f9d00

DECLARE start_address STRING DEFAULT LOWER('0x47068105c5feff69e44520b251b9666d4b512a70');
DECLARE end_address STRING DEFAULT LOWER('0x2604afb5a64992e5abbf25865c9d3387ade92bad');

with traces_0 as (
  select *
  from `bigquery-public-data.crypto_ethereum.traces`
  where from_address = start_address
),
traces_1_hop as (
  SELECT
      1 as hops,
      traces_1.from_address,
      traces_1.to_address,
      traces_1.trace_address,
      traces_1.block_timestamp,
      concat(traces_0.from_address, ' -> ', traces_0.to_address, ' -> ', traces_1.to_address) as path
  FROM `bigquery-public-data.crypto_ethereum.traces` AS traces_1
  INNER JOIN traces_0
  ON traces_0.to_address = traces_1.from_address
  AND traces_0.block_timestamp <= traces_1.block_timestamp 
),
traces_2_hops as (
  SELECT
      2 as hops,
      traces_2.from_address,
      traces_2.to_address,
      traces_2.trace_address,
      traces_2.block_timestamp,
      concat(path, ' -> ', traces_2.to_address) as path
  FROM `bigquery-public-data.crypto_ethereum.traces` AS traces_2
  INNER JOIN traces_1_hop
  ON traces_1_hop.to_address = traces_2.from_address
  AND traces_1_hop.block_timestamp <= traces_2.block_timestamp 
),
traces_3_hops as (
  SELECT
      3 as hops,
      traces_3.from_address,
      traces_3.to_address,
      traces_3.trace_address,
      traces_2_hops.block_timestamp,
      concat(path, ' -> ', traces_3.to_address) as path
  FROM `bigquery-public-data.crypto_ethereum.traces` AS traces_3
  INNER JOIN traces_2_hops
  ON traces_2_hops.to_address = traces_3.from_address
  AND traces_2_hops.block_timestamp <= traces_3.block_timestamp 
  where traces_3.to_address = end_address
),
traces_all_hops AS (
    select * from traces_1_hop
    UNION ALL
    select * from traces_2_hops
    UNION ALL
    select * from traces_3_hops
)
select *
from traces_all_hops
where hops = 3
limit 100
