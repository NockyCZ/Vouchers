/* USER DATA */
#define SQL_CREATE_USERS_TABLE \
"CREATE TABLE IF NOT EXISTS `Vouchers_users` ( \
	`steamid` varchar(22) PRIMARY KEY, \
	`codes_used` varchar(1024) DEFAULT NULL, \
	`codes_used_count` INT(11) NULL DEFAULT NULL, \
	`failed_usages` INT(11) NULL DEFAULT NULL, \
	`ban_enddate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP \
) \
DEFAULT CHARSET='utf8mb4' \
ENGINE=InnoDB;"

#define SQL_LOAD_USER_DATA \
"SELECT \
	`codes_used`, \
	`codes_used_count`, \
	`failed_usages`, \
	`ban_enddate` \
FROM `Vouchers_users` \
WHERE `steamid` = '%s' \
LIMIT 1;"

#define SQL_CREATE_USER_DATA \
"INSERT INTO `Vouchers_users` \
(\
	`steamid`, \
	`codes_used`, \
	`codes_used_count`, \
	`failed_usages`, \
	`ban_enddate` \
) \
VALUES ('%s', '', '0', '0', NULL);"

#define SQL_UPDATE_USER_DATA \
"UPDATE `Vouchers_users` SET \
	`codes_used` = '%s', \
	`codes_used_count` = '%d', \
	`failed_usages` = '%d' \
WHERE `steamid` = '%s' \
LIMIT 1;"


/* VOUCHERS DATA*/
#define SQL_CREATE_CODES_TABLE \
"CREATE TABLE IF NOT EXISTS `Vouchers` ( \
	`code` varchar(64) PRIMARY KEY, \
	`uses_remaining` INT(11) NULL DEFAULT -1, \
	`uses` INT(11) NULL DEFAULT NULL, \
	`command` varchar(128) DEFAULT NULL, \
	`translation` varchar(128) DEFAULT NULL, \
	`enddate` timestamp NULL DEFAULT NULL \
) \
DEFAULT CHARSET='utf8mb4' \
ENGINE=InnoDB;"

#define SQL_LOAD_CODES \
"SELECT \
	`code`, \
	`command`, \
	`enddate`, \
	`translation`, \
	`uses`, \
	`uses_remaining` \
FROM `Vouchers`"

#define SQL_LOAD_CODE_DATA \
"SELECT \
	`code`, \
	`command`, \
	`enddate`, \
	`translation`, \
	`uses`, \
	`uses_remaining` \
FROM `Vouchers` \
WHERE `code` = '%s' \
LIMIT 1;"

#define SQL_CREATE_CODE \
"INSERT INTO `Vouchers` \
(\
	`code`, \
	`command`, \
	`enddate`, \
	`translation`, \
	`uses`, \
	`uses_remaining` \
) \
VALUES ('%s', '', NULL, '', '0', '-1');"

#define SQL_CREATE_NEW_CODE \
"INSERT INTO `Vouchers` \
(\
	`code`, \
	`command`, \
	`enddate`, \
	`translation`, \
	`uses`, \
	`uses_remaining` \
) \
VALUES ('%s', '', NULL, '%s', '0', '%d');"

#define SQL_CREATE_TEMPORAL_CODE \
"INSERT INTO `Vouchers` \
(\
	`code`, \
	`command`, \
	`enddate`, \
	`translation`, \
	`uses`, \
	`uses_remaining` \
) \
VALUES ('%s', '', NULL, '%s', '0', '%d');"

#define SQL_UPDATE_CODE_DATA \
"UPDATE `Vouchers` SET \
	`command` = '%s', \
	`translation` = '%s', \
	`uses` = '%d', \
	`uses_remaining` = '%d' \
WHERE `code` = '%s' \
LIMIT 1;"