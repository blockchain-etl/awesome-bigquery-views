# Awesome BigQuery Views

- [Top Ethereum Balances](#top-ethereum-balances)
- [Every Ethereum Balance on Every Day](#every-ethereum-balance-on-every-day)
- [Ethereum Address Number Growth](#ethereum-address-number-growth)
- [Ether Supply](#ether-supply)
- [Top Bitcoin Balances](#top-bitcoin-balances)
- [Bitcoin Gini Index](#bitcoin-gini-index)
- [Transaction Throughput Comparison](#transaction-throughput-comparison)
- [More Queries](#more-queries)

## Top Ethereum Balances

```sql
with double_entry_book as (
    -- debits
    select to_address as address, value as value
    from `bigquery-public-data.crypto_ethereum.traces`
    where to_address is not null
    and status = 1
    and (call_type not in ('delegatecall', 'callcode', 'staticcall') or call_type is null)
    union all
    -- credits
    select from_address as address, -value as value
    from `bigquery-public-data.crypto_ethereum.traces`
    where from_address is not null
    and status = 1
    and (call_type not in ('delegatecall', 'callcode', 'staticcall') or call_type is null)
    union all
    -- transaction fees debits
    select miner as address, sum(cast(receipt_gas_used as numeric) * cast(gas_price as numeric)) as value
    from `bigquery-public-data.crypto_ethereum.transactions` as transactions
    join `bigquery-public-data.crypto_ethereum.blocks` as blocks on blocks.number = transactions.block_number
    group by blocks.miner
    union all
    -- transaction fees credits
    select from_address as address, -(cast(receipt_gas_used as numeric) * cast(gas_price as numeric)) as value
    from `bigquery-public-data.crypto_ethereum.transactions`
)
select address, sum(value) as balance
from double_entry_book
group by address
order by balance desc
limit 1000
``` 

Related article: https://medium.com/google-cloud/how-to-query-balances-for-all-ethereum-addresses-in-bigquery-fb594e4034a7                 

## Every Ethereum Balance on Every Day

```sql
with double_entry_book as (
    -- debits
    select to_address as address, value as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.traces`
    where to_address is not null
    and status = 1
    and (call_type not in ('delegatecall', 'callcode', 'staticcall') or call_type is null)
    union all
    -- credits
    select from_address as address, -value as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.traces`
    where from_address is not null
    and status = 1
    and (call_type not in ('delegatecall', 'callcode', 'staticcall') or call_type is null)
    union all
    -- transaction fees debits
    select miner as address, sum(cast(receipt_gas_used as numeric) * cast(gas_price as numeric)) as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.transactions` as transactions
    join `bigquery-public-data.crypto_ethereum.blocks` as blocks on blocks.number = transactions.block_number
    group by blocks.miner, block_timestamp
    union all
    -- transaction fees credits
    select from_address as address, -(cast(receipt_gas_used as numeric) * cast(gas_price as numeric)) as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.transactions`
),
double_entry_book_grouped_by_date as (
    select address, sum(value) as balance_increment, date(block_timestamp) as date
    from double_entry_book
    group by address, date
),
daily_balances_with_gaps as (
    select address, date, sum(balance_increment) over (partition by address order by date) as balance,
    lead(date, 1, current_date()) over (partition by address order by date) as next_date
    from double_entry_book_grouped_by_date
),
calendar AS (
    select date from unnest(generate_date_array('2015-07-30', current_date())) as date
),
daily_balances as (
    select address, calendar.date, balance
    from daily_balances_with_gaps
    join calendar on daily_balances_with_gaps.date <= calendar.date and calendar.date < daily_balances_with_gaps.next_date
)
select address, date, balance
from daily_balances
```

Related article: https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2       

## Ethereum Address Number Growth

```sql
with double_entry_book as (
    -- debits
    select to_address as address, value as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.traces`
    where to_address is not null
    and status = 1
    and (call_type not in ('delegatecall', 'callcode', 'staticcall') or call_type is null)
    union all
    -- credits
    select from_address as address, -value as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.traces`
    where from_address is not null
    and status = 1
    and (call_type not in ('delegatecall', 'callcode', 'staticcall') or call_type is null)
    union all
    -- transaction fees debits
    select miner as address, sum(cast(receipt_gas_used as numeric) * cast(gas_price as numeric)) as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.transactions` as transactions
    join `bigquery-public-data.crypto_ethereum.blocks` as blocks on blocks.number = transactions.block_number
    group by blocks.miner, block_timestamp
    union all
    -- transaction fees credits
    select from_address as address, -(cast(receipt_gas_used as numeric) * cast(gas_price as numeric)) as value, block_timestamp
    from `bigquery-public-data.crypto_ethereum.transactions`
),
double_entry_book_grouped_by_date as (
    select address, sum(value) as balance_increment, date(block_timestamp) as date
    from double_entry_book
    group by address, date
),
daily_balances_with_gaps as (
    select address, date, sum(balance_increment) over (partition by address order by date) as balance,
    lead(date, 1, current_date()) over (partition by address order by date) as next_date
    from double_entry_book_grouped_by_date
),
calendar AS (
    select date from unnest(generate_date_array('2015-07-30', current_date())) as date
),
daily_balances as (
    select address, calendar.date, balance
    from daily_balances_with_gaps
    join calendar on daily_balances_with_gaps.date <= calendar.date and calendar.date < daily_balances_with_gaps.next_date
)
select date, count(*) as address_count
from daily_balances
where balance > 0
group by date
```

Related article: https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2    

## Ether Supply

```sql 
with ether_emitted_by_date  as (
  select date(block_timestamp) as date, sum(value) as value
  from `bigquery-public-data.crypto_ethereum.traces`
  where trace_type in ('genesis', 'reward')
  group by date(block_timestamp)
)
select date, sum(value) OVER (ORDER BY date) / power(10, 18) AS supply
from ether_emitted_by_date
```  

Related article: https://medium.com/google-cloud/how-to-query-ether-supply-in-bigquery-90f8ae795a8     

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

## Transaction Throughput Comparison

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
