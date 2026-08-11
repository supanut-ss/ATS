-- Demo-only v1.89 upgrade.
-- Safe to run repeatedly after upgrade_demo_trade_analytics_v188.sql.
-- The main trade_analytics table is intentionally unchanged.

SET @has_account_ref := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'demo_trade_analytics'
      AND COLUMN_NAME = 'account_ref'
);

SET @ddl := IF(
    @has_account_ref = 0,
    'ALTER TABLE `demo_trade_analytics` ADD COLUMN `account_ref` VARCHAR(60) NOT NULL DEFAULT ''legacy'' AFTER `ticket`',
    'SELECT 1'
);
PREPARE ats_stmt FROM @ddl;
EXECUTE ats_stmt;
DEALLOCATE PREPARE ats_stmt;

-- Rows written before account_ref existed remain queryable and get a stable namespace.
UPDATE `demo_trade_analytics`
SET `account_ref` = 'legacy'
WHERE `account_ref` IS NULL OR `account_ref` = '';

SET @primary_columns := (
    SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',')
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'demo_trade_analytics'
      AND INDEX_NAME = 'PRIMARY'
);

SET @ddl := CASE
    WHEN @primary_columns = 'account_ref,ticket' THEN 'SELECT 1'
    WHEN @primary_columns IS NULL THEN
        'ALTER TABLE `demo_trade_analytics` ADD PRIMARY KEY (`account_ref`, `ticket`)'
    ELSE
        'ALTER TABLE `demo_trade_analytics` DROP PRIMARY KEY, ADD PRIMARY KEY (`account_ref`, `ticket`)'
END;
PREPARE ats_stmt FROM @ddl;
EXECUTE ats_stmt;
DEALLOCATE PREPARE ats_stmt;

