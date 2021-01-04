CREATE TABLE IF NOT EXISTS `reports` 
(
    `death_index` INT UNSIGNED NOT NULL,
    `punishment` ENUM ('warn', 'slay') NOT NULL,
    PRIMARY KEY (`death_index`),
    INDEX (`punishment`)
)
ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

-- Db_InsertReport
INSERT INTO `reports` (`death_index`, `punishment`) VALUES ('%d', '%s');
