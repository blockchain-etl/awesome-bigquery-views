WITH 
double_entry_book AS (
    SELECT 
        ARRAY_TO_STRING(outputs.addresses,',') AS address,
        value, block_timestamp
    FROM `bigquery-public-data.crypto_bitcoin.transactions` JOIN UNNEST(outputs) AS outputs
    UNION ALL
    SELECT 
        ARRAY_TO_STRING(inputs.addresses,',') AS address,
        -value AS value, block_timestamp
    FROM `bigquery-public-data.crypto_bitcoin.transactions` JOIN UNNEST(inputs) AS inputs
),
double_entry_book_by_date AS (
    SELECT 
        DATE(block_timestamp) AS date, 
        address, 
        SUM(value * 0.00000001) AS value
    FROM double_entry_book
    GROUP BY address, date
),
daily_balances_with_gaps AS (
    SELECT 
        address, 
        date,
        SUM(value) OVER (PARTITION BY address ORDER BY date) AS balance,
        LEAD(date, 1, CURRENT_DATE()) OVER (PARTITION BY address ORDER BY date) AS next_date
        FROM double_entry_book_by_date
),
calendar as (
    SELECT date FROM UNNEST(GENERATE_DATE_ARRAY('2009-01-03', CURRENT_DATE())) AS date
),
daily_balances AS (
    SELECT address, calendar.date, balance
    FROM daily_balances_with_gaps
    JOIN calendar ON daily_balances_with_gaps.date <= calendar.date AND calendar.date < daily_balances_with_gaps.next_date
    WHERE balance > 1
),
address_counts AS (
    SELECT
        date,
        count(*) AS address_count
    FROM
        daily_balances
    GROUP BY date
),
daily_balances_sampled AS (
    SELECT address, daily_balances.date, balance
    FROM daily_balances
    JOIN address_counts ON daily_balances.date = address_counts.date
    WHERE MOD(ABS(FARM_FINGERPRINT(address)), 100000000)/100000000 <= SAFE_DIVIDE(10000, address_count) 
),
ranked_daily_balances AS (
    SELECT 
        date,
        balance,
        ROW_NUMBER() OVER (PARTITION BY date ORDER BY balance DESC) AS rank
    FROM daily_balances_sampled
)
SELECT 
    date, 
    -- (1 − 2B) https://en.wikipedia.org/wiki/Gini_coefficient
    1 - 2 * SUM((balance * (rank - 1) + balance / 2)) / COUNT(*) / SUM(balance) AS gini
FROM ranked_daily_balances
GROUP BY date
HAVING SUM(balance) > 0
ORDER BY date ASC
