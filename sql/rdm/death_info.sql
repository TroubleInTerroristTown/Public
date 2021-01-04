CREATE OR REPLACE VIEW `death_info` AS
SELECT
    `deaths`.`death_index`,
    `deaths`.`death_time`,
    `deaths`.`victim_id`,
    `ttt`.`name` as `attacker_name`,
    `deaths`.`round`
FROM `deaths`
    LEFT JOIN `ttt` ON `deaths`.`attacker_id` = `ttt`.`id`
GROUP BY `deaths`.`death_index`;

-- Db_SelectClientDeaths
SELECT `death_index`, `attacker_name`, `round` FROM `death_info` WHERE `victim_id` = '%d' ORDER BY `death_time`  DESC LIMIT 10;
