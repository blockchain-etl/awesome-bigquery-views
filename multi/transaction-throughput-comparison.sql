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
