CREATE TABLE IF NOT EXISTS `handles` 
(
    `death_index` INT UNSIGNED NOT NULL,
    `admin_id` INT UNSIGNED NOT NULL,
    `verdict` ENUM ('innocent', 'guilty'),
    PRIMARY KEY (`death_index`),
    INDEX (`admin_id`),
    INDEX (`verdict`)
)
ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

-- Db_InsertHandle
INSERT INTO `handles` (`death_index`, `admin_id`) VALUES ('%d', '%d');

-- Db_UpdateVerdict
UPDATE `handles` SET `handles`.`verdict` = '%s' WHERE `death_index` = '%d';
