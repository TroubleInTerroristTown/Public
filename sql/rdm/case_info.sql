CREATE OR REPLACE VIEW `case_info` AS
SELECT 
    `deaths`.`death_index`,
    `deaths`.`death_time`,
    `deaths`.`victim_id`,
    `victim_ttt`.`name` as `victim_name`,
    `deaths`.`victim_role`,
    `victim_ttt`.`karma` as `victim_karma`,
    `deaths`.`attacker_id`,
    `attacker_ttt`.`name` as `attacker_name`,
    `deaths`.`attacker_role`,
    `attacker_ttt`.`karma` as `attacker_karma`,
    `deaths`.`last_gun_fire`,
    `deaths`.`round`,
    `reports`.`punishment`,
    `handles`.`verdict`
FROM `deaths`
    INNER JOIN `reports` ON `deaths`.`death_index` = `reports`.`death_index`
    LEFT JOIN `ttt` `victim_ttt` ON `deaths`.`victim_id` = `victim_ttt`.`id`
    LEFT JOIN `ttt` `attacker_ttt` ON `deaths`.`attacker_id` = `attacker_ttt`.`id`
    LEFT JOIN `handles` ON `deaths`.`death_index` = `handles`.`death_index`
GROUP BY `deaths`.`death_index`;

-- Db_SelectCaseBaseInfo
SELECT `death_index`, `victim_name`, `attacker_name` FROM `case_info` WHERE `death_index` = '%d';

-- Db_SelectInfo
SELECT `death_index`, `death_time`, `victim_name`, `victim_role`+0, `victim_karma`, `attacker_name`, `attacker_role`+0, `attacker_karma`, `last_gun_fire`, `round` FROM `case_info` WHERE `death_index` = '%d';

-- Db_SelectVerdictInfo
SELECT `death_index`, `victim_id`, `victim_name`, `attacker_id`, `attacker_name`, `punishment`+0, `verdict`+0 FROM `case_info` WHERE `death_index` = '%d';
