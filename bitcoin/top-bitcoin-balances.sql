WITH double_entry_book AS (
   -- debits
   SELECT array_to_string(inputs.addresses, ",") AS address, inputs.type, -inputs.value AS value
   FROM `bigquery-public-data.crypto_bitcoin.inputs` AS inputs
   UNION ALL
   -- credits
   SELECT array_to_string(outputs.addresses, ",") AS address, outputs.type, outputs.value AS value
   FROM `bigquery-public-data.crypto_bitcoin.outputs` AS outputs
)
SELECT address, type, sum(value) AS balance
FROM double_entry_book
GROUP BY address, type
ORDER BY balance DESC
LIMIT 1000
