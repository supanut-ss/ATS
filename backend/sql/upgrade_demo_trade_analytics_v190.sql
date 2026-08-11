-- Demo-only v1.90 analytics metadata upgrade.
-- Safe to run repeatedly. Main trade_analytics remains unchanged.

SET @has_broker_offset := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'demo_trade_analytics'
      AND COLUMN_NAME = 'broker_utc_offset_seconds'
);
SET @ddl := IF(
    @has_broker_offset = 0,
    'ALTER TABLE `demo_trade_analytics` ADD COLUMN `broker_utc_offset_seconds` INT NOT NULL DEFAULT 0 AFTER `result`',
    'SELECT 1'
);
PREPARE ats_stmt FROM @ddl;
EXECUTE ats_stmt;
DEALLOCATE PREPARE ats_stmt;

SET @has_time_basis := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'demo_trade_analytics'
      AND COLUMN_NAME = 'time_basis'
);
SET @ddl := IF(
    @has_time_basis = 0,
    'ALTER TABLE `demo_trade_analytics` ADD COLUMN `time_basis` VARCHAR(20) NOT NULL DEFAULT ''BROKER_SERVER'' AFTER `broker_utc_offset_seconds`',
    'SELECT 1'
);
PREPARE ats_stmt FROM @ddl;
EXECUTE ats_stmt;
DEALLOCATE PREPARE ats_stmt;

SET @has_data_quality := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'demo_trade_analytics'
      AND COLUMN_NAME = 'data_quality'
);
SET @ddl := IF(
    @has_data_quality = 0,
    'ALTER TABLE `demo_trade_analytics` ADD COLUMN `data_quality` VARCHAR(30) NOT NULL DEFAULT '''' AFTER `time_basis`',
    'SELECT 1'
);
PREPARE ats_stmt FROM @ddl;
EXECUTE ats_stmt;
DEALLOCATE PREPARE ats_stmt;
