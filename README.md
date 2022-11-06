# Awesome BigQuery Views

Here are some examples of how to derive insights from on-chain crypto data. Not all networks have examples here - you can find the complete list of crypto datasets in [blockchain-etl/public-datasets](https://github.com/blockchain-etl/public-datasets)

## Top Ethereum Balances

```sql
WITH double_entry_book AS (
    -- debits
    SELECT to_address AS address, value AS value
    FROM `bigquery-public-data.crypto_ethereum.traces`
    WHERE to_address IS NOT NULL
    AND status = 1
    AND (call_type NOT IN ('delegatecall', 'callcode', 'staticcall') OR call_type IS NULL)
    UNION ALL
    -- credits
    SELECT from_address AS address, -value AS value
    FROM `bigquery-public-data.crypto_ethereum.traces`
    WHERE from_address IS NOT NULL
    AND status = 1
    AND (call_type NOT IN ('delegatecall', 'callcode', 'staticcall') OR call_type IS NULL)
    UNION ALL
    -- transaction fees debits
    SELECT 
        miner AS address, 
        SUM(CAST(receipt_gas_used AS numeric) * CAST((receipt_effective_gas_price - COALESCE(base_fee_per_gas, 0)) as numeric)) AS value
    FROM `bigquery-public-data.crypto_ethereum.transactions` AS transactions
    join `bigquery-public-data.crypto_ethereum.blocks` AS blocks ON blocks.number = transactions.block_number
    GROUP BY blocks.number, blocks.miner
    UNION ALL
    -- transaction fees credits
    SELECT 
        from_address AS address, 
        -(CAST(receipt_gas_used AS numeric) * CAST(receipt_effective_gas_price AS numeric)) AS value
    FROM `bigquery-public-data.crypto_ethereum.transactions`
)
SELECT address, SUM(value) AS balance
FROM double_entry_book
GROUP BY address
ORDER BY balance DESC
LIMIT 1000
``` 

Alternatively query `bigquery-public-data.crypto_ethereum.balances` (updated daily), e.g.:

```sql
SELECT *
FROM `bigquery-public-data.crypto_ethereum.balances`
WHERE SEARCH(address, '0x0cfb686e114d478b055ce8614621f8bb62f70360', analyzer=>'NO_OP_ANALYZER');
```

## Every Ethereum Balance on Every Day

```sql
WITH double_entry_book AS (
    -- debits
    SELECT to_address AS address, value AS value, block_timestamp
    FROM `bigquery-public-data.crypto_ethereum.traces`
    WHERE to_address IS NOT NULL
    AND status = 1
    AND (call_type NOT IN ('delegatecall', 'callcode', 'staticcall') OR call_type IS NULL)
    UNION ALL
    -- credits
    SELECT from_address AS address, -value AS value, block_timestamp
    FROM `bigquery-public-data.crypto_ethereum.traces`
    WHERE from_address IS NOT NULL
    AND status = 1
    AND (call_type NOT IN ('delegatecall', 'callcode', 'staticcall') OR call_type IS NULL)
    UNION ALL
    -- transaction fees debits
    SELECT 
        miner AS address, 
        SUM(CAST(receipt_gas_used AS numeric) * CAST((receipt_effective_gas_price - COALESCE(base_fee_per_gas, 0)) AS numeric)) AS value,
        block_timestamp
    FROM `bigquery-public-data.crypto_ethereum.transactions` AS transactions
    JOIN `bigquery-public-data.crypto_ethereum.blocks` AS blocks ON blocks.number = transactions.block_number
    GROUP BY blocks.number, blocks.miner, block_timestamp
    UNION ALL
    -- transaction fees credits
    SELECT 
        from_address AS address, 
        -(CAST(receipt_gas_used AS numeric) * CAST(receipt_effective_gas_price AS numeric)) AS value,
        block_timestamp
    FROM `bigquery-public-data.crypto_ethereum.transactions`
),
double_entry_book_grouped_by_date AS (
    SELECT address, SUM(value) AS balance_increment, DATE(block_timestamp) AS date
    FROM double_entry_book
    GROUP BY address, date
),
daily_balances_with_gaps AS (
    SELECT address, date, SUM(balance_increment) OVER (PARTITION BY address ORDER BY date) AS balance,
    LEAD(date, 1, CURRENT_DATE()) OVER (PARTITION BY address ORDER BY date) AS next_date
    FROM double_entry_book_grouped_by_date
),
calendar AS (
    SELECT date FROM UNNEST(GENERATE_DATE_ARRAY('2015-07-30', CURRENT_DATE())) AS date
),
daily_balances AS (
    SELECT address, calendar.date, balance
    FROM daily_balances_with_gaps
    JOIN calendar ON daily_balances_with_gaps.date <= calendar.date AND calendar.date < daily_balances_with_gaps.next_date
)
SELECT address, date, balance
FROM daily_balances
```

Related article: https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2       

## Transaction Throughput Comparison

```sql
WITH bitcoin_throughput AS (
    -- takes transactions count in every block and divides it by average block time on that day
    SELECT 'bitcoin' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_bitcoin.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
),
bitcoin_cash_throughput AS (
    SELECT 'bitcoin_cash' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_bitcoin_cash.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
),
ethereum_throughput AS (
    SELECT 'ethereum' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_ethereum.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
),
ethereum_classic_throughput AS (
    SELECT 'ethereum_classic' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_ethereum_classic.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
),
dogecoin_throughput AS (
    SELECT 'dogecoin' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_dogecoin.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
),
litecoin_throughput AS (
    SELECT 'litecoin' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_litecoin.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
),
dash_throughput AS (
    SELECT 'dash' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_dash.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
),
zcash_throughput AS (
    SELECT 'zcash' AS chain, count(*) / (24 * 60 * 60 / count(*) OVER (PARTITION BY DATE(block_timestamp))) AS throughput, block_timestamp AS time
    FROM `bigquery-public-data.crypto_zcash.transactions` AS transactions
    GROUP BY transactions.block_number, transactions.block_timestamp
    ORDER BY throughput DESC
    LIMIT 1
)
SELECT * FROM bitcoin_throughput
UNION ALL
SELECT * FROM bitcoin_cash_throughput
UNION ALL
SELECT * FROM ethereum_throughput
UNION ALL
SELECT * FROM ethereum_classic_throughput
UNION ALL
SELECT * FROM dogecoin_throughput
UNION ALL
SELECT * FROM litecoin_throughput
UNION ALL
SELECT * FROM dash_throughput
UNION ALL
SELECT * FROM zcash_throughput
ORDER BY throughput DESC
```     

Related article: 
https://medium.com/@medvedev1088/comparing-transaction-throughputs-for-8-blockchains-in-google-bigquery-with-google-data-studio-edbabb75b7f1

## More Queries

| Network | Description | Query | Screenshot | BigQuery | DataStudio | Notes
| --- | --- | --- | --- | --- | --- | ---
| Band | Latest oracle prices | [📝](band/latest-prices.sql) | | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:9d41f5f621fe4deea11ed3be32ed0a5d) | | | 
| Band | Log types by transaction | [📝](band/log-types-by-transaction.sql) | | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:4643d2cc218d497aa2bf4173c39cbce8)
| Bitcoin | Top 1K addresses, by balance | [📝](bitcoin/top-bitcoin-balances.sql) |  | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:9bd85ce4d6174e909cfc89c09cb1cc55) | [📊](https://datastudio.google.com/u/1/reporting/c61d1ee3-0e67-4f19-a322-4aed82a21e1b/page/p_a72nk0pzzc) | |
| Bitcoin | Bitcoin Gini index, by day | [📝](bitcoin/gini-index-by-day.sql) |  | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:531f2d1edf614723b2120a839e5df04b) | [📊](https://datastudio.google.com/u/1/reporting/c61d1ee3-0e67-4f19-a322-4aed82a21e1b/page/p_a72nk0pzzc) | [[1](https://cloud.google.com/blog/products/data-analytics/introducing-six-new-cryptocurrencies-in-bigquery-public-datasets-and-how-to-analyze-them)]
| Ethereum | Every account balance on every day | [📝](ethereum/every-balance-every-day.sql)|  | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:c5323064f9fb45529ebdd65fb4091374) | [📊](https://datastudio.google.com/u/1/reporting/c61d1ee3-0e67-4f19-a322-4aed82a21e1b/page/9tC6C) | [[1](https://medium.com/google-cloud/plotting-ethereum-address-growth-chart-55cc0e7207b2)]
| Ethereum | Ether supply by day | [📝](ethereum/ether-supply-by-day.sql)| [🖼️](ethereum/ether-supply-by-day.png) | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:7bd873dec1cd417b89552495cad09e56) | [📊](https://datastudio.google.com/u/1/reporting/c61d1ee3-0e67-4f19-a322-4aed82a21e1b/page/9tC6C) | [[1](https://medium.com/google-cloud/how-to-query-ether-supply-in-bigquery-90f8ae795a8)]
| Ethereum | Shortest path between addresses | [📝](ethereum/shortest-path-via-traces.sql) |  | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:2d202e496bf343a0aa1060f4ef35ffff) | ❌
| Zilliqa | Shortest path between addresses v2 | [📝](zilliqa/shortest-path-via-traces-v2.sql) |  | [🔍](https://console.cloud.google.com/bigquery?sq=896878822558:c4c9b9294acb42b183233b158cc67074) | ❌

Check out this awesome repository: https://github.com/RokoMijic/awesome-bigquery-views
