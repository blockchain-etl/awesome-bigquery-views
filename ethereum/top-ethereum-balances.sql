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
