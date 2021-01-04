CREATE OR REPLACE VIEW `ongoing_cases` AS
SELECT
    `reports`.`death_index`,
    `handles`.`admin_id`
FROM `reports`
    LEFT JOIN `handles` ON `reports`.`death_index` = `handles`.`death_index`
WHERE `handles`.`admin_id` IS NOT NULL AND `handles`.`verdict` IS NULL
GROUP BY `reports`.`death_index`;

SELECT `death_index` FROM `ongoing_cases` WHERE `admin_id` = '%d' LIMIT 1;
