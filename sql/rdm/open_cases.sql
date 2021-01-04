CREATE OR REPLACE VIEW `open_cases` AS
SELECT
    `reports`.`death_index`
FROM `reports`
    LEFT JOIN `handles` ON `reports`.`death_index` = `handles`.`death_index`
WHERE `handles`.`admin_id` IS NULL
GROUP BY `reports`.`death_index`;

-- Db_SelectCaseCount
SELECT COUNT(*) AS `case_count` FROM `open_cases`;

-- Db_SelectNextCase
SELECT `death_index` FROM `open_cases` ORDER BY `death_index` ASC LIMIT 1;
