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
| Ethereum | [📝](ethereum/shortest-path-via-traces.sql) | Shortest path between addresses | ⏳ | ⏳ | ⏳ | |

- [More Queries](#more-queries) 



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
