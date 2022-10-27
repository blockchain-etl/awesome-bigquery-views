WITH ether_emitted_by_date  AS (
  SELECT date(block_timestamp) AS date, SUM(value) AS value
  FROM `bigquery-public-data.crypto_ethereum.traces`
  WHERE trace_type IN ('genesis', 'reward')
  GROUP BY DATE(block_timestamp)
)
SELECT date, SUM(value) OVER (ORDER BY date) / POWER(10, 18) AS supply
FROM ether_emitted_by_date
