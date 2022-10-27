# Awesome BigQuery Views

| Network | Query | Description | Screenshot | DataStudio | BigQuery | Notes
| --- | --- | --- | --- | --- | --- | ---
| Ethereum | [📝](ethereum/top-ethereum-balances.sql) | Top 1K addresses, by balance | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/how-to-query-balances-for-all-ethereum-addresses-in-bigquery-fb594e4034a7)]
| Ethereum | [📝](ethereum/every-balance-every-day.sql) | Every account balance on every day | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2)]
| Ethereum | [📝](ethereum/unique-addresses-by-day.sql) | Unique addresses by day | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2)]
| Ethereum | [📝](ethereum/ether-supply-by-day.sql) | Ether supply by day | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/how-to-query-ether-supply-in-bigquery-90f8ae795a8)]
| Bitcoin | [📝](bitcoin/top-bitcoin-balances.sql) | Top 1K addresses, by balance | ⏳ | ⏳ | ⏳ | |
| Bitcoin | [📝](bitcoin/gini-index-by-day.sql) | Bitcoin Gini index, by day | ⏳ | ⏳ | ⏳ | [[1](https://cloud.google.com/blog/products/data-analytics/introducing-six-new-cryptocurrencies-in-bigquery-public-datasets-and-how-to-analyze-them)]
| Multiple | [📝](x) | Transaction throughput comparison of multiple blockchains  | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/@medvedev1088/comparing-transaction-throughputs-for-8-blockchains-in-google-bigquery-with-google-data-studio-edbabb75b7f1)]
| Ethereum | [📝](x) | Shortest path between addresses | ⏳ | ⏳ | ⏳ | |

- [Transaction Throughput Comparison](#transaction-throughput-comparison)
- [Shortest Path Between Addresses](#shortest-path-between-addresses)
- [More Queries](#more-queries) 


## Shortest Path Between Two Ethereum Addresses

```sql
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
```  

The query above will fail if there are too many traces. There is a workaround here 
https://console.cloud.google.com/bigquery?sq=749871510730:082d50190dc04d79aaf7ee4d5c6f9d00

## Transaction Throughput Comparison

- 🔍 [Run in BigQuery](asdf)
- 📊 [View in DataStudio](asdf)

```sql
with bitcoin_throughput as (
    -- takes transactions count in every block and divides it by average block time on that day
    select 'bitcoin' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_bitcoin.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
),
bitcoin_cash_throughput as (
    select 'bitcoin_cash' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_bitcoin_cash.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
),
ethereum_throughput as (
    select 'ethereum' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_ethereum.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
),
ethereum_classic_throughput as (
    select 'ethereum_classic' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_ethereum_classic.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
),
dogecoin_throughput as (
    select 'dogecoin' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_dogecoin.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
),
litecoin_throughput as (
    select 'litecoin' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_litecoin.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
),
dash_throughput as (
    select 'dash' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_dash.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
),
zcash_throughput as (
    select 'zcash' as chain, count(*) / (24 * 60 * 60 / count(*) over (partition by date(block_timestamp))) as throughput, block_timestamp as time
    from `bigquery-public-data.crypto_zcash.transactions` as transactions
    group by transactions.block_number, transactions.block_timestamp
    order by throughput desc
    limit 1
)
select * from bitcoin_throughput
union all
select * from bitcoin_cash_throughput
union all
select * from ethereum_throughput
union all
select * from ethereum_classic_throughput
union all
select * from dogecoin_throughput
union all
select * from litecoin_throughput
union all
select * from dash_throughput
union all
select * from zcash_throughput
order by throughput desc
```     

Related article: 
https://medium.com/@medvedev1088/comparing-transaction-throughputs-for-8-blockchains-in-google-bigquery-with-google-data-studio-edbabb75b7f1

## More Queries

Check out this awesome repository: https://github.com/RokoMijic/awesome-bigquery-views
