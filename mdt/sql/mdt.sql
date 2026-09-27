-- ============================================================================
-- Fv_MDT — Database schema (MySQL / MariaDB, run once via oxmysql)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `mdt_profiles` (
    `citizenid`   VARCHAR(64)  NOT NULL,
    `firstname`   VARCHAR(64)  DEFAULT NULL,
    `lastname`    VARCHAR(64)  DEFAULT NULL,
    `dob`         VARCHAR(32)  DEFAULT NULL,
    `phone`       VARCHAR(32)  DEFAULT NULL,
    `image`       TEXT         DEFAULT NULL,
    `notes`       TEXT         DEFAULT NULL,
    `flags`       LONGTEXT     DEFAULT NULL,          -- JSON array of flags
    `is_wanted`   TINYINT(1)   NOT NULL DEFAULT 0,
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_records` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(64)  NOT NULL,
    `charges`     LONGTEXT     NOT NULL,               -- JSON array of charge objects
    `fine`        INT          NOT NULL DEFAULT 0,
    `jail`        INT          NOT NULL DEFAULT 0,      -- minutes
    `narrative`   TEXT         DEFAULT NULL,
    `officer`     VARCHAR(64)  DEFAULT NULL,            -- citizenid of filing officer
    `officer_name`VARCHAR(96)  DEFAULT NULL,
    `expunged`    TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_records_cid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_warrants` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(64)  NOT NULL,
    `name`        VARCHAR(96)  DEFAULT NULL,
    `reason`      TEXT         DEFAULT NULL,
    `status`      ENUM('active','closed') NOT NULL DEFAULT 'active',
    `officer`     VARCHAR(64)  DEFAULT NULL,
    `officer_name`VARCHAR(96)  DEFAULT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at`   TIMESTAMP    NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_warrants_cid` (`citizenid`),
    KEY `idx_warrants_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_bolos` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title`       VARCHAR(128) NOT NULL,
    `body`        TEXT         DEFAULT NULL,
    `plate`       VARCHAR(16)  DEFAULT NULL,
    `image`       TEXT         DEFAULT NULL,
    `status`      ENUM('active','closed') NOT NULL DEFAULT 'active',
    `officer`     VARCHAR(64)  DEFAULT NULL,
    `officer_name`VARCHAR(96)  DEFAULT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_bolos_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_reports` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title`       VARCHAR(160) NOT NULL,
    `body`        LONGTEXT     DEFAULT NULL,
    `tags`        LONGTEXT     DEFAULT NULL,            -- JSON array
    `involved`    LONGTEXT     DEFAULT NULL,            -- JSON array of {citizenid,name,role}
    `officer`     VARCHAR(64)  DEFAULT NULL,
    `officer_name`VARCHAR(96)  DEFAULT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_vehicle_flags` (
    `plate`       VARCHAR(16)  NOT NULL,
    `flag`        ENUM('stolen','impound','bolo','clean') NOT NULL DEFAULT 'clean',
    `note`        TEXT         DEFAULT NULL,
    `officer`     VARCHAR(64)  DEFAULT NULL,
    `officer_name`VARCHAR(96)  DEFAULT NULL,
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_evidence` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `report_id`   INT UNSIGNED DEFAULT NULL,
    `label`       VARCHAR(160) NOT NULL,
    `type`        VARCHAR(48)  DEFAULT 'misc',
    `detail`      TEXT         DEFAULT NULL,
    `officer`     VARCHAR(64)  DEFAULT NULL,
    `officer_name`VARCHAR(96)  DEFAULT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_evidence_report` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_audit` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `officer`     VARCHAR(64)  DEFAULT NULL,
    `officer_name`VARCHAR(96)  DEFAULT NULL,
    `action`      VARCHAR(64)  NOT NULL,
    `detail`      TEXT         DEFAULT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_audit_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
