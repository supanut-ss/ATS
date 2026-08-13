-- One-time cleanup for historical production webhook logs.

UPDATE `webhook_logs`
SET `body` = REGEXP_REPLACE(
    `body`,
    '("(token|secret|password|api_key|apikey|authorization)"[[:space:]]*:[[:space:]]*")[^"]*(")',
    '$1[REDACTED]$3',
    1,
    0,
    'i'
)
WHERE `body` REGEXP '"(token|secret|password|api_key|apikey|authorization)"[[:space:]]*:';

UPDATE `webhook_logs`
SET `result` = REGEXP_REPLACE(
    `result`,
    '("(token|secret|password|api_key|apikey|authorization)"[[:space:]]*:[[:space:]]*")[^"]*(")',
    '$1[REDACTED]$3',
    1,
    0,
    'i'
)
WHERE `result` IS NOT NULL
  AND `result` REGEXP '"(token|secret|password|api_key|apikey|authorization)"[[:space:]]*:';
