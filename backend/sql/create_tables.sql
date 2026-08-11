-- ATS schema for one MySQL database with isolated Main and Demo tables.
-- Select the target database before running this file.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `signals` (
    `id`           VARCHAR(30)  NOT NULL,
    `signal_id`    VARCHAR(100) NOT NULL DEFAULT '',
    `timestamp`    DATETIME     NOT NULL,
    `bar_time`     BIGINT       NOT NULL DEFAULT 0,
    `timeframe`    VARCHAR(10)  NOT NULL DEFAULT '',
    `action`       VARCHAR(10)  NOT NULL,
    `symbol`       VARCHAR(20)  NOT NULL DEFAULT 'XAUUSD',
    `sl`           DOUBLE       NOT NULL DEFAULT 0,
    `tp`           DOUBLE       NOT NULL DEFAULT 0,
    `rr`           DOUBLE       NOT NULL DEFAULT 0,
    `entry_price`  DOUBLE       NOT NULL DEFAULT 0,
    `exit_price`   DOUBLE       NOT NULL DEFAULT 0,
    `profit`       DOUBLE       NOT NULL DEFAULT 0,
    `volume`       DOUBLE       NOT NULL DEFAULT 0.01,
    `ticket`       VARCHAR(30)  NOT NULL DEFAULT '',
    `status`       VARCHAR(20)  NOT NULL DEFAULT 'PENDING_BUY',
    `comment`      TEXT         NOT NULL,
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `webhook_logs` (
    `id`        BIGINT      NOT NULL AUTO_INCREMENT,
    `timestamp` DATETIME    NOT NULL,
    `action`    VARCHAR(30) NOT NULL,
    `body`      TEXT        NOT NULL,
    `result`    TEXT        NULL,
    `error`     TEXT        NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `account_snapshots` (
    `id`             BIGINT   NOT NULL AUTO_INCREMENT,
    `timestamp`      DATETIME NOT NULL,
    `balance`        DOUBLE   NOT NULL DEFAULT 0,
    `equity`         DOUBLE   NOT NULL DEFAULT 0,
    `free_margin`    DOUBLE   NOT NULL DEFAULT 0,
    `bid`            DOUBLE   NOT NULL DEFAULT 0,
    `ask`            DOUBLE   NOT NULL DEFAULT 0,
    `open_positions` INT      NOT NULL DEFAULT 0,
    `positions_json` TEXT     NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `demo_signals` (
    `id`           VARCHAR(30)  NOT NULL,
    `signal_id`    VARCHAR(100) NOT NULL DEFAULT '',
    `timestamp`    DATETIME     NOT NULL,
    `bar_time`     BIGINT       NOT NULL DEFAULT 0,
    `timeframe`    VARCHAR(10)  NOT NULL DEFAULT '',
    `action`       VARCHAR(10)  NOT NULL,
    `symbol`       VARCHAR(20)  NOT NULL DEFAULT 'XAUUSD',
    `sl`           DOUBLE       NOT NULL DEFAULT 0,
    `tp`           DOUBLE       NOT NULL DEFAULT 0,
    `rr`           DOUBLE       NOT NULL DEFAULT 0,
    `entry_price`  DOUBLE       NOT NULL DEFAULT 0,
    `exit_price`   DOUBLE       NOT NULL DEFAULT 0,
    `profit`       DOUBLE       NOT NULL DEFAULT 0,
    `volume`       DOUBLE       NOT NULL DEFAULT 0.01,
    `ticket`       VARCHAR(30)  NOT NULL DEFAULT '',
    `status`       VARCHAR(20)  NOT NULL DEFAULT 'PENDING_BUY',
    `comment`      TEXT         NOT NULL,
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `demo_webhook_logs` (
    `id`        BIGINT      NOT NULL AUTO_INCREMENT,
    `timestamp` DATETIME    NOT NULL,
    `action`    VARCHAR(30) NOT NULL,
    `body`      TEXT        NOT NULL,
    `result`    TEXT        NULL,
    `error`     TEXT        NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `demo_account_snapshots` (
    `id`             BIGINT   NOT NULL AUTO_INCREMENT,
    `timestamp`      DATETIME NOT NULL,
    `balance`        DOUBLE   NOT NULL DEFAULT 0,
    `equity`         DOUBLE   NOT NULL DEFAULT 0,
    `free_margin`    DOUBLE   NOT NULL DEFAULT 0,
    `bid`            DOUBLE   NOT NULL DEFAULT 0,
    `ask`            DOUBLE   NOT NULL DEFAULT 0,
    `open_positions` INT      NOT NULL DEFAULT 0,
    `positions_json` TEXT     NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trade_analytics` (
    `ticket`       VARCHAR(30)  NOT NULL,
    `symbol`       VARCHAR(20)  NOT NULL,
    `action`       VARCHAR(10)  NOT NULL,
    `entry_price`  DOUBLE       NOT NULL DEFAULT 0,
    `exit_price`   DOUBLE       NOT NULL DEFAULT 0,
    `profit`       DOUBLE       NOT NULL DEFAULT 0,
    `mfe`          DOUBLE       NOT NULL DEFAULT 0,
    `mae`          DOUBLE       NOT NULL DEFAULT 0,
    `adx`          DOUBLE       NOT NULL DEFAULT 0,
    `chop`         DOUBLE       NOT NULL DEFAULT 0,
    `atr_ratio`    DOUBLE       NOT NULL DEFAULT 0,
    `is_low_vol`   BOOLEAN      NOT NULL DEFAULT FALSE,
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`ticket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `demo_trade_analytics` (
    `ticket`       VARCHAR(30)  NOT NULL,
    `account_ref`  VARCHAR(60)  NOT NULL DEFAULT '',
    `symbol`       VARCHAR(20)  NOT NULL,
    `action`       VARCHAR(10)  NOT NULL,
    `signal_type`  VARCHAR(30)  NOT NULL DEFAULT '',
    `timeframe`    VARCHAR(10)  NOT NULL DEFAULT '',
    `entry_time`   DATETIME     NULL,
    `exit_time`    DATETIME     NULL,
    `duration_seconds` INT      NOT NULL DEFAULT 0,
    `entry_price`  DOUBLE       NOT NULL DEFAULT 0,
    `exit_price`   DOUBLE       NOT NULL DEFAULT 0,
    `volume`       DOUBLE       NOT NULL DEFAULT 0,
    `initial_sl`   DOUBLE       NOT NULL DEFAULT 0,
    `initial_tp`   DOUBLE       NOT NULL DEFAULT 0,
    `profit`       DOUBLE       NOT NULL DEFAULT 0,
    `commission`   DOUBLE       NOT NULL DEFAULT 0,
    `swap`         DOUBLE       NOT NULL DEFAULT 0,
    `net_profit`   DOUBLE       NOT NULL DEFAULT 0,
    `mfe`          DOUBLE       NOT NULL DEFAULT 0,
    `mae`          DOUBLE       NOT NULL DEFAULT 0,
    `adx`          DOUBLE       NOT NULL DEFAULT 0,
    `chop`         DOUBLE       NOT NULL DEFAULT 0,
    `atr_ratio`    DOUBLE       NOT NULL DEFAULT 0,
    `is_low_vol`   BOOLEAN      NOT NULL DEFAULT FALSE,
    `spread_points` DOUBLE      NOT NULL DEFAULT 0,
    `atr`           DOUBLE      NOT NULL DEFAULT 0,
    `market_regime` VARCHAR(20) NOT NULL DEFAULT '',
    `session_name`  VARCHAR(20) NOT NULL DEFAULT '',
    `entry_hour`    INT         NOT NULL DEFAULT 0,
    `loss_streak_before` INT    NOT NULL DEFAULT 0,
    `exit_reason`   VARCHAR(40) NOT NULL DEFAULT '',
    `ea_version`    VARCHAR(20) NOT NULL DEFAULT '',
    `settings_hash` VARCHAR(100) NOT NULL DEFAULT '',
    `level_price`   DOUBLE      NOT NULL DEFAULT 0,
    `pivot_time`    DATETIME    NULL,
    `result`        VARCHAR(20) NOT NULL DEFAULT '',
    `broker_utc_offset_seconds` INT NOT NULL DEFAULT 0,
    `time_basis`    VARCHAR(20) NOT NULL DEFAULT 'BROKER_SERVER',
    `data_quality`  VARCHAR(30) NOT NULL DEFAULT '',
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_ref`, `ticket`),
    INDEX `idx_demo_trade_exit_time` (`exit_time`),
    INDEX `idx_demo_trade_result` (`result`),
    INDEX `idx_demo_trade_signal_type` (`signal_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
