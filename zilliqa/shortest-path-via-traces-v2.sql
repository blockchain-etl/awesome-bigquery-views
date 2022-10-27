#standardSQL
DECLARE start_address STRING DEFAULT 'zil1jrpjd8pjuv50cfkfr7eu6yrm3rn5u8rulqhqpz';
DECLARE end_address STRING DEFAULT 'zil19nmxkh020jnequql9kvqkf3pkwm0j0spqtd26e';
-- Addresses with the number of outgoing transactions exceeding this parameter are excluded from shortest path calculation.
-- For most types of analyses it's not an encumbering limitation as addresses with high fan out are usually exchanges.
-- If the query takes too long too finish try reducing this parameter.
DECLARE max_fan_out INT64 DEFAULT 50;

WITH all_transactions AS (
  SELECT id AS transaction_id, block_number, block_timestamp, sender AS from_address, to_addr AS to_address
  FROM `public-data-finance.crypto_zilliqa.transactions`
  UNION ALL
  SELECT transaction_id, block_number, block_timestamp, addr AS from_addr, recipient AS to_addr
  FROM `public-data-finance.crypto_zilliqa.transitions` 
),
addresses_with_high_fan_out AS (
  SELECT from_address AS address
  FROM all_transactions
  GROUP BY from_address
  HAVING COUNT(*) > max_fan_out 
),
transactions_0_hops AS (
  SELECT
    0 AS hops,
    transactions.from_address,
    transactions.to_address,
    transactions.block_timestamp,
    CONCAT(transactions.from_address, ' --(tx ', SUBSTR(transactions.transaction_id, 0, 5), '..)--> ', transactions.to_address) AS path
  FROM all_transactions AS transactions
  WHERE transactions.from_address = start_address 
),
transactions_1_hops AS (
  SELECT
    1 AS hops,
    transactions.from_address,
    transactions.to_address,
    transactions.block_timestamp,
    CONCAT(path, ' --(tx ', SUBSTR(transactions.transaction_id, 0, 5), '..)--> ', transactions.to_address) AS path
  FROM all_transactions AS transactions
  INNER JOIN transactions_0_hops ON transactions_0_hops.to_address = transactions.from_address
    AND transactions_0_hops.block_timestamp <= transactions.block_timestamp
  LEFT JOIN addresses_with_high_fan_out
  ON addresses_with_high_fan_out.address = transactions.from_address
  WHERE addresses_with_high_fan_out.address IS NULL 
),
transactions_2_hops AS (
  SELECT
    2 AS hops,
    transactions.from_address,
    transactions.to_address,
    transactions.block_timestamp,
    CONCAT(path, ' --(tx ', SUBSTR(transactions.transaction_id, 0, 5), '..)--> ', transactions.to_address) AS path
  FROM all_transactions AS transactions
  INNER JOIN transactions_1_hops
  ON transactions_1_hops.to_address = transactions.from_address
    AND transactions_1_hops.block_timestamp <= transactions.block_timestamp
  LEFT JOIN addresses_with_high_fan_out ON addresses_with_high_fan_out.address = transactions.from_address
  WHERE addresses_with_high_fan_out.address IS NULL 
),
transactions_3_hops AS (
  SELECT
    3 AS hops,
    transactions.from_address,
    transactions.to_address,
    transactions.block_timestamp,
    CONCAT(path, ' --(tx ', SUBSTR(transactions.transaction_id, 0, 5), '..)--> ', transactions.to_address) AS path
  FROM all_transactions AS transactions
  INNER JOIN transactions_2_hops ON transactions_2_hops.to_address = transactions.from_address
    AND transactions_2_hops.block_timestamp <= transactions.block_timestamp
  LEFT JOIN addresses_with_high_fan_out
  ON addresses_with_high_fan_out.address = transactions.from_address
  WHERE addresses_with_high_fan_out.address IS NULL
),
transactions_all_hops AS (
  SELECT * FROM transactions_0_hops WHERE to_address = end_address
  UNION ALL
  SELECT * FROM transactions_1_hops WHERE to_address = end_address
  UNION ALL
  SELECT * FROM transactions_2_hops WHERE to_address = end_address
  UNION ALL 
  SELECT * FROM transactions_3_hops WHERE to_address = end_address 
)
SELECT
  hops,
  path
FROM transactions_all_hops
ORDER BY hops ASC
LIMIT 1000
