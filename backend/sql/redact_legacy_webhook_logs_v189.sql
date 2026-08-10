-- One-time-at-rest cleanup for historical Main and Demo webhook logs.
-- Safe to run repeatedly. New writes are redacted by the application before INSERT.

UPDATE `webhook_logs`
SET `body` = JSON_SET(
    `body`,
    '$.token', '[REDACTED]',
    '$.secret', '[REDACTED]',
    '$.password', '[REDACTED]',
    '$.api_key', '[REDACTED]',
    '$.authorization', '[REDACTED]'
)
WHERE JSON_VALID(`body`)
  AND JSON_CONTAINS_PATH(
      `body`, 'one', '$.token', '$.secret', '$.password', '$.api_key', '$.authorization');

UPDATE `demo_webhook_logs`
SET `body` = JSON_SET(
    `body`,
    '$.token', '[REDACTED]',
    '$.secret', '[REDACTED]',
    '$.password', '[REDACTED]',
    '$.api_key', '[REDACTED]',
    '$.authorization', '[REDACTED]'
)
WHERE JSON_VALID(`body`)
  AND JSON_CONTAINS_PATH(
      `body`, 'one', '$.token', '$.secret', '$.password', '$.api_key', '$.authorization');

-- Invalid legacy payloads cannot be redacted reliably. Omit likely-sensitive bodies.
UPDATE `webhook_logs`
SET `body` = '[legacy non-JSON payload omitted]'
WHERE NOT JSON_VALID(`body`)
  AND LOWER(`body`) REGEXP 'token|secret|password|api[_-]?key|authorization';

UPDATE `demo_webhook_logs`
SET `body` = '[legacy non-JSON payload omitted]'
WHERE NOT JSON_VALID(`body`)
  AND LOWER(`body`) REGEXP 'token|secret|password|api[_-]?key|authorization';
