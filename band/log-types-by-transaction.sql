#standardSQL
SELECT type, count(*) AS count
FROM `public-data-finance.crypto_band.logs`, UNNEST(events)
GROUP BY type
ORDER BY count DESC
