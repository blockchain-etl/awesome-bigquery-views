# Awesome BigQuery Views

| Network | Query | Description | Screenshot | DataStudio | BigQuery | Notes
| --- | --- | --- | --- | --- | --- | ---
| Ethereum | [📝](ethereum/top-ethereum-balances.sql) | Top 1K addresses, by balance | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/how-to-query-balances-for-all-ethereum-addresses-in-bigquery-fb594e4034a7)]
| Ethereum | [📝](ethereum/every-balance-every-day.sql) | Every account balance on every day | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2)]
| Ethereum | [📝](ethereum/unique-addresses-by-day.sql) | Unique addresses by day | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2)]
| Ethereum | [📝](ethereum/ether-supply-by-day.sql) | Ether supply by day | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/google-cloud/how-to-query-ether-supply-in-bigquery-90f8ae795a8)]
| Bitcoin | [📝](bitcoin/top-bitcoin-balances.sql) | Top 1K addresses, by balance | ⏳ | ⏳ | ⏳ | |
| Bitcoin | [📝](x) | Bitcoin Gini index, by day | ⏳ | ⏳ | ⏳ | [[1](https://cloud.google.com/blog/products/data-analytics/introducing-six-new-cryptocurrencies-in-bigquery-public-datasets-and-how-to-analyze-them)]
| Multiple | [📝](x) | Transaction throughput comparison of multiple blockchains  | ⏳ | ⏳ | ⏳ | [[1](https://medium.com/@medvedev1088/comparing-transaction-throughputs-for-8-blockchains-in-google-bigquery-with-google-data-studio-edbabb75b7f1)]
| Ethereum | [📝](x) | Shortest path between addresses | ⏳ | ⏳ | ⏳ | |

- [Top Bitcoin Balances](#top-bitcoin-balances)
- [Bitcoin Gini Index](#bitcoin-gini-index)
- [Transaction Throughput Comparison](#transaction-throughput-comparison)
- [Shortest Path Between Addresses](#shortest-path-between-addresses)
- [More Queries](#more-queries) 

## Top Bitcoin Balances

```sql 
WITH double_entry_book AS (
   -- debits
   SELECT array_to_string(inputs.addresses, ",") as address, inputs.type, -inputs.value as value
   FROM `bigquery-public-data.crypto_bitcoin.inputs` as inputs
   UNION ALL
   -- credits
   SELECT array_to_string(outputs.addresses, ",") as address, outputs.type, outputs.value as value
   FROM `bigquery-public-data.crypto_bitcoin.outputs` as outputs
)
SELECT address, type, sum(value) as balance
FROM double_entry_book
GROUP BY address, type
ORDER BY balance DESC
LIMIT 1000
```

## Bitcoin Gini Index

```sql
with 
double_entry_book as (
    select 
        array_to_string(outputs.addresses,',') as address,
        value, block_timestamp
    from `crypto-etl-bitcoin-prod.bitcoin_blockchain.transactions` join unnest(outputs) as outputs
    union all
    select 
        array_to_string(inputs.addresses,',') as address,
        -value as value, block_timestamp
    from `crypto-etl-bitcoin-prod.bitcoin_blockchain.transactions` join unnest(inputs) as inputs
),
double_entry_book_by_date as (
    select 
        date(block_timestamp) as date, 
        address, 
        sum(value * 0.00000001) as value
    from double_entry_book
    group by address, date
),
daily_balances_with_gaps as (
    select 
        address, 
        date,
        sum(value) over (partition by address order by date) as balance,
        lead(date, 1, current_date()) over (partition by address order by date) as next_date
        from double_entry_book_by_date
),
calendar as (
    select date from unnest(generate_date_array('2009-01-03', current_date())) as date
),
daily_balances as (
    select address, calendar.date, balance
    from daily_balances_with_gaps
    join calendar on daily_balances_with_gaps.date <= calendar.date and calendar.date < daily_balances_with_gaps.next_date
    where balance > 1
),
address_counts as (
    select
        date,
        count(*) as address_count
    from
        daily_balances
    group by date
),
daily_balances_sampled as (
    select address, daily_balances.date, balance
    from daily_balances
    join address_counts on daily_balances.date = address_counts.date
    where mod(abs(farm_fingerprint(address)), 100000000)/100000000 <= safe_divide(10000, address_count) 
),
ranked_daily_balances as (
    select 
        date,
        balance,
        row_number() over (partition by date order by balance desc) as rank
    from daily_balances_sampled
)
select 
    date, 
    -- (1 − 2B) https://en.wikipedia.org/wiki/Gini_coefficient
    1 - 2 * sum((balance * (rank - 1) + balance / 2)) / count(*) / sum(balance) as gini
from ranked_daily_balances
group by date
having sum(balance) > 0
order by date asc
```  

Related article: 
https://cloud.google.com/blog/products/data-analytics/introducing-six-new-cryptocurrencies-in-bigquery-public-datasets-and-how-to-analyze-them

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
