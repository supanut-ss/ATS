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
    `entry_condition` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`ticket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `demo_trade_analytics` (
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
    `entry_condition` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`ticket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
