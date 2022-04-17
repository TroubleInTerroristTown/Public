void SetupConfig()
{
    CreateConVar("ttt2_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cshowKarmaOnSpawn = AutoExecConfig_CreateConVar("ttt_show_karma_on_spawn", "1", "Show players karma on spawn?", _, true, 0.0, true, 1.0);
    g_cshowEarnKarmaMessage = AutoExecConfig_CreateConVar("ttt_show_message_earn_karma", "1", "Display a message showing how much karma you earned. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    g_cshowLoseKarmaMessage = AutoExecConfig_CreateConVar("ttt_show_message_lose_karma", "1", "Display a message showing how much karma you lost. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    g_cpublicKarma = AutoExecConfig_CreateConVar("ttt_public_karma", "0", "Show karma as points (or another way?)", _, true, 0.0, true, 1.0);
    g_ckarmaRound = AutoExecConfig_CreateConVar("ttt_private_karma_round_update", "1", "If ttt_public_karma is not set to 1, enable this to update karma at end of round.", _, true, 0.0, true, 1.0);
    g_ckarmaRoundMessage = AutoExecConfig_CreateConVar("ttt_show_karma_round_update_message", "1", "Announce karma got updated in a karma round.", _, true, 0.0, true, 1.0);
    g_ckarmaDMG = AutoExecConfig_CreateConVar("ttt_karma_dmg", "0", "Scale damage based off of karma? (damage *= (karma/startkarma))", _, true, 0.0, true, 1.0);
    g_ckarmaDMG_up = AutoExecConfig_CreateConVar("ttt_karma_dmg_up", "0", "If ttt_karma_dmg is enabled, should be enable scaling damage upward?", _, true, 0.0, true, 1.0);
    g_cmessageTypKarma = AutoExecConfig_CreateConVar("ttt_message_typ_karma", "1", "The karma message type. 1 = Hint Text or 2 = Chat Message", _, true, 1.0, true, 2.0);
    g_ckarmaII = AutoExecConfig_CreateConVar("ttt_karma_killer_innocent_victim_innocent_subtract", "5", "The amount of karma an innocent will lose for killing an innocent.");
    g_ckarmaIT = AutoExecConfig_CreateConVar("ttt_karma_killer_innocent_victim_traitor_add", "5", "The amount of karma an innocent will recieve for killing a traitor.");
    g_ckarmaID = AutoExecConfig_CreateConVar("ttt_karma_killer_innocent_victim_detective_subtract", "7", "The amount of karma an innocent will lose for killing a detective.");
    g_ckarmaTI = AutoExecConfig_CreateConVar("ttt_karma_killer_traitor_victim_innocent_add", "2", "The amount of karma a traitor will recieve for killing an innocent.");
    g_ckarmaTT = AutoExecConfig_CreateConVar("ttt_karma_killer_traitor_victim_traitor_subtract", "5", "The amount of karma a traitor will lose for killing a traitor.");
    g_ckarmaTD = AutoExecConfig_CreateConVar("ttt_karma_killer_traitor_victim_detective_add", "3", "The amount of karma a traitor will recieve for killing a detective.");
    g_ckarmaDI = AutoExecConfig_CreateConVar("ttt_karma_killer_detective_victim_innocent_subtract", "3", "The amount of karma a detective will lose for killing an innocent.");
    g_ckarmaDT = AutoExecConfig_CreateConVar("ttt_karma_killer_detective_victim_traitor_add", "7", "The amount of karma a detective will recieve for killing a traitor.");
    g_ckarmaDD = AutoExecConfig_CreateConVar("ttt_karma_killer_detective_victim_detective_subtract", "7", "The amount of karma a detective will lose for killing a detective.");
    g_cstartKarma = AutoExecConfig_CreateConVar("ttt_start_karma", "100", "The amount of karma new players and players who were karma banned will start with.");
    g_ckarmaBan = AutoExecConfig_CreateConVar("ttt_with_karma_ban", "75", "The amount of karma needed to be banned for Bad Karma. (0 = Disabled)", _, true, 0.0);
    g_cBanKarmaDead = AutoExecConfig_CreateConVar("ttt_with_karma_dead", "0", "Ban dead players for bad karma?", _, true, 0.0, true, 1.0);
    g_ckarmaBanLength = AutoExecConfig_CreateConVar("ttt_with_karma_ban_length", "10080", "The length (time in minutes) of a Bad Karma ban. (Default = 1 Week)");
    g_cmaxKarma = AutoExecConfig_CreateConVar("ttt_max_karma", "150", "The maximum amount of karma a player can have.");
    g_cmaxKarmaVip = AutoExecConfig_CreateConVar("ttt_max_karma_vip", "300", "The maximum amount of karma a VIP player can have.");
    g_ckarmaFlag = AutoExecConfig_CreateConVar("ttt_vip_karma_flag", "t", "VIP flag for increased karma value.");
    g_crequiredPlayersD = AutoExecConfig_CreateConVar("ttt_required_players_detective", "6", "The amount of players required to activate the detective role.");
    g_crequiredPlayersM = AutoExecConfig_CreateConVar("ttt_required_players_miscellaneous", "8", "The amount of players required to activate the miscellaneous role.");
    g_crequiredPlayers = AutoExecConfig_CreateConVar("ttt_required_player", "3", "The amount of players required to start the game.");
    g_cmaxTraitors = AutoExecConfig_CreateConVar("ttt_traitor_max", "32", "Maximum number of traitors. Customize this if you want to finetune the number of traitors at your server's max playercount, for example to make sure there are max 3 traitors on a 16 player server.");
    g_cmaxDetectives = AutoExecConfig_CreateConVar("ttt_detective_max", "32", "Maximum number of detectives. Can be used to cap or disable detectives.");
    g_cmaxMisc = AutoExecConfig_CreateConVar("ttt_miscellaneous_max", "2", "Maximum number of miscellaneous. Can be used to cap or disable miscellaneous roles.");
    // g_cminKarmaDetective = AutoExecConfig_CreateConVar("ttt_detective_karma_min", "100", "If a player's Karma falls below this point, his chances of being selected as detective are reduced.");
    g_cblockSuicide = AutoExecConfig_CreateConVar("ttt_block_suicide", "0", "Block players from suiciding with console. 1 = Block, 0 = Don't Block", _, true, 0.0, true, 1.0);
    g_cSkipOwnSuicide = AutoExecConfig_CreateConVar("ttt_skip_own_suicide", "1", "Should TTT skip own suicide action? 1 = Skip (no karma losses), 0 = Don't skip", _, true, 0.0, true, 1.0);
    g_cblockRadioMessage = AutoExecConfig_CreateConVar("ttt_block_radio_message", "1", "Block radio messages in chat. 1 = Block, 0 = Don't Block", _, true, 0.0, true, 1.0);
    g_cshowDeathMessage = AutoExecConfig_CreateConVar("ttt_show_death_message", "1", "Display a message showing who killed you. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    g_cshowKillMessage = AutoExecConfig_CreateConVar("ttt_show_kill_message", "1", "Display a message showing who you killed. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    g_callowFlash = AutoExecConfig_CreateConVar("ttt_allow_flash", "1", "Enable Flashlight (+lookatweapon). 1 = Enabled, 0 Disabled", _, true, 0.0, true, 1.0);
    g_caflashVolume = AutoExecConfig_CreateConVar("ttt_flash_volume", "0.6", "How loud the flash toggle should be (default 0.6).", _, true, 0.0, true, 1.0);
    g_cblockLookAtWeapon = AutoExecConfig_CreateConVar("ttt_block_look_at_weapon", "1", "Block weapon inspecting. 1 = Block, 0 = Don't Block)", _, true, 0.0, true, 1.0);
    g_cenableNoBlock = AutoExecConfig_CreateConVar("ttt_enable_noblock", "0", "Enable No Block. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    g_ckadRemover = AutoExecConfig_CreateConVar("ttt_kad_remover", "1", "Block kills, deaths and assists from appearing on the scoreboard. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    g_cfakeHealth = AutoExecConfig_CreateConVar("ttt_fake_health", "100", "By faking the players health, it will avoid an gamebreaking. So this feature can't be disabled.", _, true, 0.0, true, 100.0);
    g_cfakeLife = AutoExecConfig_CreateConVar("ttt_fake_life", "0", "How should the players alive status be displayed on the scoreboard? (0 - Default (based on the found state), 1 - everyone is dead, 2 - everyone is alive)", _, true, 0.0, true, 2.0);
    g_cpluginTag = AutoExecConfig_CreateConVar("ttt_plugin_tag", "{prefix}[TTT]{default}", "The prefix used in all plugin messages");
    g_cspawnHPT = AutoExecConfig_CreateConVar("ttt_spawn_t", "100", "The amount of health traitors spawn with. ( 0 = disabled )", _, true, 0.0);
    g_cspawnHPD = AutoExecConfig_CreateConVar("ttt_spawn_d", "100", "The amount of health detectives spawn with. ( 0 = disabled )", _, true, 0.0);
    g_cspawnHPI = AutoExecConfig_CreateConVar("ttt_spawn_i", "100", "The amount of health innocents spawn with. ( 0 = disabled )", _, true, 0.0);
    g_cspawnHPM = AutoExecConfig_CreateConVar("ttt_spawn_m", "100", "The amount of health miscellaneous spawn with. ( 0 = disabled )", _, true, 0.0);
    g_crulesClosePunishment = AutoExecConfig_CreateConVar("ttt_rules_close_punishment", "0", "The punishment for abusing the rules menu by closing it with another menu. 0 = Kick, Anything Else = Do Nothing", _, true, 0.0);
    g_ctimeToReadDetectiveRules = AutoExecConfig_CreateConVar("ttt_time_to_read_detective_rules", "15", "The time in seconds the detective rules menu will stay open.");
    g_ctimeToReadRules = AutoExecConfig_CreateConVar("ttt_time_to_read_rules", "30", "The time in seconds the general rules menu will stay open.");
    g_cshowDetectiveMenu = AutoExecConfig_CreateConVar("ttt_show_detective_menu", "1", "Show the detective menu. 1 = Show, 0 = Don't Show", _, true, 0.0, true, 1.0);
    g_cshowRulesMenu = AutoExecConfig_CreateConVar("ttt_show_rules_menu", "1", "Show the rules menu. 1 = Show, 0 Don't Show", _, true, 0.0, true, 1.0);
    g_cpunishInnoKills = AutoExecConfig_CreateConVar("ttt_punish_innocent_for_rdm_kils", "3", "The amount of times an innocent will be allowed to kill another innocent/detective before being punished for RDM.");
    g_cpunishTraitorKills = AutoExecConfig_CreateConVar("ttt_punish_traitor_for_rdm_kils", "1", "The amount of times an traitor will be allowed to kill another traitor before being punished for RDM.");
    g_cpunishDetectiveKills = AutoExecConfig_CreateConVar("ttt_punish_detective_for_rdm_kils", "5", "The amount of times an detective will be allowed to kill another innocent/detective before being punished for RDM.");
    g_ckickImmunity = AutoExecConfig_CreateConVar("ttt_kick_immunity", "b", "Admin flags that won't be kicked for not reading the rules.");
    g_clogsAccess = AutoExecConfig_CreateConVar("ttt_logsaccess", "b", "Admin flags to view logs in a round.");
    g_cLogsDeadOnly = AutoExecConfig_CreateConVar("ttt_logs_dead_only", "0", "Access to logs only for dead admins?", _, true, 0.0, true, 1.0);
    g_cLogsNotifyAlive = AutoExecConfig_CreateConVar("ttt_logs_notify_alive", "1", "Notify if logs has been watched by alive admin. 0 = Don't notify anyone, 1 = Notify everyone, 2 = Notify admins only", _, true, 0.0, true, 2.0);
    g_cupdateClientModel = AutoExecConfig_CreateConVar("ttt_update_client_model", "1", "Update the client model instantly when they are assigned a role. Disables forcing client models to a specified model. 1 = Update, 0 = Don't Update", _, true, 0.0, true, 1.0);
    g_cremoveHostages = AutoExecConfig_CreateConVar("ttt_remove_hostages", "1", "Remove all hostages from the map to prevent interference. 1 = Remove, 0 = Don't Remove", _, true, 0.0, true, 1.0);
    g_cremoveBomb = AutoExecConfig_CreateConVar("ttt_remove_bomb_on_spawn", "1", "Remove the bomb spots from the map to prevent interference. 1 = Remove, 0 = Don't Remove", _, true, 0.0, true, 1.0);
    g_ctraitorRatio = AutoExecConfig_CreateConVar("ttt_traitor_ratio", "25", "The chance of getting the traitor role.");
    g_cdetectiveRatio = AutoExecConfig_CreateConVar("ttt_detective_ratio", "13", "The chance of getting the detective role.");
    g_cmiscRatio = AutoExecConfig_CreateConVar("ttt_miscellaneous_ratio", "8", "The chance of getting a miscellaneous role.");
    g_cdenyFire = AutoExecConfig_CreateConVar("ttt_deny_fire", "1", "Stop players who have not been assigned a role yet from shooting. (Mouse1 & Mouse2)", _, true, 0.0, true, 1.0);
    g_cslayAfterStart = AutoExecConfig_CreateConVar("ttt_slay_after_start", "1", "Slay all players after ttt round started", _, true, 0.0, true, 1.0);
    g_cremoveBuyzone = AutoExecConfig_CreateConVar("ttt_disable_buyzone", "0", "Remove all buyzones from the map to prevent interference. 1 = Remove, 0 = Don't Remove", _, true, 0.0, true, 1.0);
    g_cforceTeams = AutoExecConfig_CreateConVar("ttt_force_teams", "1", "Force players to teams instead of forcing playermodel. 1 = Force team. 0 = Force playermodel.", _, true, 0.0, true, 1.0);
    g_crandomWinner = AutoExecConfig_CreateConVar("ttt_random_winner", "1", "Choose random winner (CT/T) regardless of normal result. 1 = Yes, 0 = No", _, true, 0.0, true, 1.0);
    g_cendwithD = AutoExecConfig_CreateConVar("ttt_end_with_detective", "0", "Allow the round to end if Detectives remain alive. 0 = Disabled (default). 1 = Enabled.", _, true, 0.0, true, 1.0);
    g_chideTeams = AutoExecConfig_CreateConVar("ttt_hide_teams", "0", "Hide team changes from chat.", _, true, 0.0, true, 1.0);
    g_cstripWeapons = AutoExecConfig_CreateConVar("ttt_strip_weapons", "1", "Strip players weapons on spawn? Optionally use mp_ct_ and mp_t_ cvars instead.", _, true, 0.0, true, 1.0);
    g_croundDelay = AutoExecConfig_CreateConVar("ttt_after_round_delay", "7.0", "The amount of seconds to use for round-end delay. Use 0.0 for default.");
    g_cnextRoundAlert = AutoExecConfig_CreateConVar("ttt_next_round_alert", "0", "Tell players in chat when the next round will begin (when the round ends)", _, true, 0.0, true, 1.0);
    g_cignoreDeaths = AutoExecConfig_CreateConVar("ttt_ignore_deaths", "0", "Ignore deaths (longer rounds)? 0 = Disabled (default). 1 = Enabled.", _, true, 0.0, true, 1.0);
    g_cignoreRDMMenu = AutoExecConfig_CreateConVar("ttt_ignore_rdm_slay", "0", "Don't ask players to forgive/punish other players (rdm'd). 0 = Disabled (default). 1 = Enabled.", _, true, 0.0, true, 1.0);
    g_ctChatToDead = AutoExecConfig_CreateConVar("ttt_t_chat_to_dead", "0", "Show traitor chat messages to dead players?", _, true, 0.0, true, 1.0);
    g_cdChatToDead = AutoExecConfig_CreateConVar("ttt_d_chat_to_dead", "0", "Show detective chat messages to dead players?", _, true, 0.0, true, 1.0);
    g_cTranfserArmor = AutoExecConfig_CreateConVar("ttt_transfer_armor", "0", "Save armor on round end for living players and re-set in the next round?", _, true, 0.0, true, 1.0);
    g_cRespawnDeadPlayers = AutoExecConfig_CreateConVar("ttt_respawn_dead_players", "1", "Respawn dead players on pre role selection?", _, true, 0.0, true, 1.0);
    g_cEnableDamage = AutoExecConfig_CreateConVar("ttt_prestart_damage", "0", "Enable damage before round start (Default disabled to prevent kills)?", _, true, 0.0, true, 1.0);
    g_croundendDamage = AutoExecConfig_CreateConVar("ttt_roundend_dm", "0", "Enable damage after a round until round end.", _, true, 0.0, true, 1.0);
    g_clogFile = AutoExecConfig_CreateConVar("ttt_log_file", "logs/ttt/ttt-<DATE>.log", "The default file to log TTT data to (including end of round) - DON'T REMOVE \"-<DATE>\" IF YOU DON'T KNOW WHAT YOU DO.");
    g_cerrFile = AutoExecConfig_CreateConVar("ttt_error_file", "logs/ttt/ttt-error-<DATE>.log", "The default file to log TTT errors/bugs - DON'T REMOVE \"-<DATE>\" IF YOU DON'T KNOW WHAT YOU DO.");
    g_cKarmaFile = AutoExecConfig_CreateConVar("ttt_karma_file", "logs/ttt/ttt-karma-<DATE>.log", "The default file to log TTT karma changes (Require ttt_debug_mode - 1) - DON'T REMOVE \"-<DATE>\" IF YOU DON'T KNOW WHAT YOU DO.");
    g_cdefaultPriD = AutoExecConfig_CreateConVar("ttt_default_primary_d", "weapon_m4a1_silencer", "The default primary gun to give players when they become a Detective (if they have no primary).");
    g_cdefaultSec = AutoExecConfig_CreateConVar("ttt_default_secondary", "weapon_glock", "The default secondary gun to give players when they get their role (if they have no secondary).");
    g_cRoundStartedFontSize = AutoExecConfig_CreateConVar("ttt_round_started_font_size", "32", "Font size of the text if round started");
    g_cRoundStartedFontColor = AutoExecConfig_CreateConVar("ttt_round_started_font_color", "44ff22", "Font color (hexcode without hastag!) of the text if round started");
    g_cRoundStartFontSize = AutoExecConfig_CreateConVar("ttt_round_start_font_size", "24", "Font size of the text while the countdown runs");
    g_cRoundStartFontColor = AutoExecConfig_CreateConVar("ttt_round_start_font_color", "ffA500", "Font color (hexcode without hastag!) of the text while the countdown runs");
    g_cShowTraitors = AutoExecConfig_CreateConVar("ttt_show_traitor_names", "1", "Show traitor partners on team selection?", _, true, 0.0, true, 1.0);
    g_cGiveWeaponsOnFailStart = AutoExecConfig_CreateConVar("ttt_give_weapons_on_failed_start", "0", "Give player weapons on a fail start?", _, true, 0.0, true, 1.0);
    g_cFSPrimary = AutoExecConfig_CreateConVar("ttt_give_weapons_fail_start_primary", "ak47", "What primary weapon do you want? (WITHOUT 'weapon_' TAG!)");
    g_cFSSecondary = AutoExecConfig_CreateConVar("ttt_give_weapons_fail_start_secondary", "deagle", "What primary weapon do you want? (WITHOUT 'weapon_' TAG!)");
    g_cSetTeam = AutoExecConfig_CreateConVar("ttt_command_access_setteam", "d", "Admin flags to access the 'setteam' command.");
    g_cKarmaReset = AutoExecConfig_CreateConVar("ttt_command_access_karmareset", "m", "Admin flags to access the 'karmareset' command.");
    g_cSetKarma = AutoExecConfig_CreateConVar("ttt_command_access_setkarma", "m", "Admin flags to access the 'setkarma' command.");
    g_cAddSteamIDtoLogs = AutoExecConfig_CreateConVar("ttt_steamid_add_to_logs", "1", "Should we add steam id to all log actions? Prevent abusing with namefakers", _, true, 0.0, true, 1.0);
    g_cSteamIDLogFormat = AutoExecConfig_CreateConVar("ttt_steamid_log_format", "1", "Which steam id format to you prefer? 1 - SteamID2 (STEAM_1:1:40828751), 2 - SteamID3 ([U:1:81657503]) or 3 - SteamID64/CommunityID (76561198041923231) - 4 AccountID (40828751)", _, true, 0.0, true, 4.0);
    g_cDebugMessages = AutoExecConfig_CreateConVar("ttt_show_debug_messages", "0", "Show debug messages to all root admins?", _, true, 0.0, true, 1.0);
    g_cDisableDamageSelection = AutoExecConfig_CreateConVar("ttt_disable_damage_selection", "1", "Disable damage during team selection? This could prevent some bugs.", _, true, 0.0, true, 1.0);
    g_cRoundSlayInno = AutoExecConfig_CreateConVar("ttt_round_slays_innocent", "5", "How much round slays for innocents after rdm punishment? (0 = Instant slay) (ttt_punish_innocent_for_rdm_kils)");
    g_cRoundSlayTraitor = AutoExecConfig_CreateConVar("ttt_round_slays_traitor", "5", "How much round slays for traitores after rdm punishment? (0 = Instant slay) (ttt_punish_traitor_for_rdm_kils)");
    g_cRoundSlayDetective = AutoExecConfig_CreateConVar("ttt_round_slays_detective", "5", "How much round slays for detectives after rdm punishment? (0 = Instant slay) (ttt_punish_detective_for_rdm_kils)");
    g_cRoundSlayPlayerRDM = AutoExecConfig_CreateConVar("ttt_round_slays_player_rdm_menu", "1", "How much round slays for the players by a player punishment? (1 = Instant slay, 2 = Instant slay + slay next round ...)");
    g_cRoundSlayDestroyTrigger = AutoExecConfig_CreateConVar("ttt_round_slays_destroy_trigger", "2", "How much round slays for players there try to enter a destroy trigger? (?)");
    g_cRoundSlayAccess = AutoExecConfig_CreateConVar("ttt_round_slays_admin_access", "b", "Admin flags to access round slays command.");
    g_cDebug = AutoExecConfig_CreateConVar("ttt_debug_mode", "0", "Enable or disable debug mode for ttt? Could by useful for one player tests", _, true, 0.0, true, 1.0);
    g_cSwitchSpec = AutoExecConfig_CreateConVar("ttt_move_spectators", "0", "Move spectators to ct (or t) on round start?", _, true, 0.0, true, 1.0);
    g_cRulesMenu = AutoExecConfig_CreateConVar("ttt_save_rules_choice", "0", "Save choise from rules menu per player? Players must accept this one time (instead of every time) if it's enabled", _, true, 0.0, true, 1.0);
    g_cDRulesMenu = AutoExecConfig_CreateConVar("ttt_save_detective_rules_choice", "0", "Save choise from detective (rules) menu per player? Players must accept this one time (instead of every time) if it's enabled", _, true, 0.0, true, 1.0);
    g_cCheckPlayers = AutoExecConfig_CreateConVar("ttt_check_always_players", "1", "This always check players outside from a valid round and outside round ending (this should prevent a unreasonable 'deathmatch' round)", _, true, 0.0, true, 1.0);
    g_cCheckDuringWarmup = AutoExecConfig_CreateConVar("ttt_check_players_during_warmup", "0", "Check players during warmup?", _, true, 0.0, true, 1.0);
    g_cPrimaryWeaponUpdate = AutoExecConfig_CreateConVar("ttt_primary_weapon_update", "0", "What should happen on round start with the primary weapon? 0 - nothing, 1 - drop old weapon, 2 - remove old weapon", _, true, 0.0, true, 2.0);
    g_cSecondaryWeaponUpdate = AutoExecConfig_CreateConVar("ttt_secondary_weapon_update", "0", "What should happen on round start with the secondary weapon? 0 - nothing, 1 - drop old weapon, 2 - remove old weapon", _, true, 0.0, true, 2.0);
    g_cEnableDamageKarma = AutoExecConfig_CreateConVar("ttt_damage_karma_enable", "0", "Add/Del karma on damage?", _, true, 0.0, true, 1.0);
    g_cDamageKarmaII = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_innocent_victim_innocent_subtract", "1", "The amount of karma an innocent will lose for damage an innocent.");
    g_cDamageKarmaIT = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_innocent_victim_traitor_add", "1", "The amount of karma an innocent will recieve for damage a traitor.");
    g_cDamageKarmaID = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_innocent_victim_detective_subtract", "1", "The amount of karma an innocent will lose for damage a detective.");
    g_cDamageKarmaTI = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_traitor_victim_innocent_add", "1", "The amount of karma a traitor will recieve for damage an innocent.");
    g_cDamageKarmaTT = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_traitor_victim_traitor_subtract", "1", "The amount of karma a traitor will lose for damage a traitor.");
    g_cDamageKarmaTD = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_traitor_victim_detective_add", "1", "The amount of karma a traitor will recieve for damage a detective.");
    g_cDamageKarmaDI = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_detective_victim_innocent_subtract", "1", "The amount of karma a detective will lose for damage an innocent.");
    g_cDamageKarmaDT = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_detective_victim_traitor_add", "1", "The amount of karma a detective will recieve for damage a traitor.");
    g_cDamageKarmaDD = AutoExecConfig_CreateConVar("ttt_damage_karma_attacker_detective_victim_detective_subtract", "1", "The amount of karma a detective will lose for damage a detective.");
    g_cDoublePushInno = AutoExecConfig_CreateConVar("ttt_double_push_innocents", "1", "Push innocents (from last round) two times into players array? This should increase the chance to get traitor in the new round.", _, true, 0.0, true, 1.0);
    g_cDoublePushDete = AutoExecConfig_CreateConVar("ttt_double_push_detective", "1", "Push detective (from last round) two times into players array? This should increase the chance to get traitor in the new round.", _, true, 0.0, true, 1.0);
    g_cKarmaDecreaseWhenKillPlayerWhoHurt = AutoExecConfig_CreateConVar("ttt_karma_decrease_kill_player_who_hurted", "1", "Decrease Karma when you kill a player who hurted you?.", _, true, 0.0, true, 1.0);
    g_cLogButtons = AutoExecConfig_CreateConVar("ttt_log_pressed_buttons", "0", "Log pressed buttons?", _, true, 0.0, true, 1.0);
    g_cLogButtonsSpam = AutoExecConfig_CreateConVar("ttt_log_pressed_buttons_time", "5", "Prevent log spamming for the same button - Time in seconds to relog a button");
    g_cOpenRulesOnPunish = AutoExecConfig_CreateConVar("ttt_open_rules_on_punish", "0", "Open rules menu for a player while he will be punished?", _, true, 0.0, true, 1.0);
    g_cRulesURLReopenMenu = AutoExecConfig_CreateConVar("ttt_reopen_rules_on_url", "1", "Reopen rules menu when a player will be redirect to motd/popup window?", _, true, 0.0, true, 1.0);
    g_cNameChangePunish = AutoExecConfig_CreateConVar("ttt_name_change_punishment", "0", "Which punishment while name change? 0 - Disabled, 1 - Message to all players, 2 - Block Name Change, 3 - Kick Player or 4 - Ban player", _, true, 0.0, true, 3.0);
    g_cNameChangeLength = AutoExecConfig_CreateConVar("ttt_name_change_banlength", "120", "Ban length for name change (require 'ttt_name_change_punishment 3')");
    g_cShowInnoRDMMenu = AutoExecConfig_CreateConVar("ttt_show_rdm_menu_for_inno", "0", "Show RDM Menu while killing Innocent as Innocent?", _, true, 0.0, true, 1.0);
    g_cFlashlightOption = AutoExecConfig_CreateConVar("ttt_flashlight_option", "0", "How should flashlight be activated? 0 = +lookatweapon, 1 - Command (sm_fl or sm_flashlight)", _, true, 0.0, true, 1.0);
    g_cRespawnAccess = AutoExecConfig_CreateConVar("ttt_respawn_admin_access", "b", "Admin flags to access respawn command.");
    g_cPlayerHUDMessage = AutoExecConfig_CreateConVar("ttt_players_remaining_hud_message", "1", "Show hud \"We Are / Players Remaining\" message during non active rounds?", _, true, 0.0, true, 1.0);
    g_cShowURL = AutoExecConfig_CreateConVar("ttt_show_url", "1", "Show the URL when a player wants to read the rules? Valve removed the MOTD and Popup-function, so that could be useful", _, true, 0.0, true, 1.0);
    g_cDisableRounds = AutoExecConfig_CreateConVar("ttt_disable_rounds", "0", "Disable TTT Rounds? This will require an map change, server restart or plugin that can execute TTT_TerminateRound.", _, true, 0.0, true, 1.0);
    g_cClearRounds = AutoExecConfig_CreateConVar("ttt_clear_rounds", "0", "Clear old rounds? 0 - Default means disabled, other value will be presumed as days.", _, true, 0.0);
    g_cClearLogs = AutoExecConfig_CreateConVar("ttt_clear_logs", "0", "Clear old logs? 0 - Default means disabled, other value will be presumed as days.", _, true, 0.0);
    g_cStartMelee = AutoExecConfig_CreateConVar("ttt_start_melee_weapon", "knife", "Spawn with which melee weapon?");
    g_cAdditionalMeleeTeam = AutoExecConfig_CreateConVar("ttt_additional_melee_team", "0", "Who gets the additional melee weapon? (Useful: https://github.com/TroubleInTerroristTown/Public/wiki/CVAR-Masks )", _, true, 0.0, true, 14.0);
    g_cAdditionalMeleeWeapon = AutoExecConfig_CreateConVar("ttt_Additional_melee_weapon", "", "Which additional weapon?");
    g_cUnloadPlugins = AutoExecConfig_CreateConVar("ttt_unload_plugins", "1", "Unload old/obsolete plugins?", _, true, 0.0, true, 1.0);
    g_cRemovePlugins = AutoExecConfig_CreateConVar("ttt_remove_plugins", "1", "Remove old/obsolete plugins (ttt_remove_plugins must be 1)?", _, true, 0.0, true, 1.0);
    g_cFixThirdperson = AutoExecConfig_CreateConVar("ttt_fix_thirdperson_view", "1", "Reset thirdperson view back to firstperson, if players comes from other servers with thirdperson view (Zombie, Prop Hunt, ...)", _, true, 0.0, true, 1.0);
    g_cShowRoundIDMessage = AutoExecConfig_CreateConVar("ttt_enable_round_id_message", "1", "Prints a message on every success round start in chat like: \"Round #X has been started\"", _, true, 0.0, true, 1.0);
    g_cClanTagUpperLower = AutoExecConfig_CreateConVar("ttt_clan_tag_upper_lower", "1", "Format clantags to a upper string (0), lower string (1) or translation based (2)?", _, true, 0.0, true, 2.0);
    g_cSaveLogsInSQL = AutoExecConfig_CreateConVar("ttt_save_logs_in_mysql", "0", "Save round logs in a mysql table? For auto clean up take a look at \"ttt_clean_up_sql_logs\".", _, true, 0.0, true, 1.0);
    g_cDeleteLogsAfterDays = AutoExecConfig_CreateConVar("ttt_clean_up_sql_logs", "7", "Remove logs after X days, default is \"7\" days and \"0\" for no auto clean up.\nttt_save_logs_in_mysql must be \"1\"", _, true, 0.0);
    g_cAutoAssignTeam = AutoExecConfig_CreateConVar("ttt_enable_auto_assign_team", "0", "Enable auto team assign?", _, true, 0.0, true, 1.0);
    g_cBlockSwitchSelection = AutoExecConfig_CreateConVar("ttt_block_switch_selection", "1", "Block team swich during selection phase?", _, true, 0.0, true, 1.0);
    g_cShowTeamsSelectedMessage = AutoExecConfig_CreateConVar("ttt_show_teams_selected_message", "1", "Shows the 'Teams have been selected message'", _, true, 0.0, true, 1.0);
    g_cShowReceivingLogsMessage = AutoExecConfig_CreateConVar("ttt_show_receiving_logs_message", "1", "Shows the 'Receiving logs' message in chat", _, true, 0.0, true, 1.0);
    g_cMicCheckFlag = AutoExecConfig_CreateConVar("ttt_mic_check_flag", "b", "Flag to access \"!miccheck\" command, to see who accepted it or not. ( \"ttt_show_detective_menu\" must be 1 )");
    g_cNameFix = AutoExecConfig_CreateConVar("ttt_fix_player_names", "1", "Remove and/or Replace color codes/tags from player names. (0 - Escape Codes/Tags, 1 - Remove Codes/Tags", _, true, 0.0, true, 1.0);
    
    g_cpluginTag.AddChangeHook(OnConVarChanged);
    g_ckickImmunity.AddChangeHook(OnConVarChanged);
    g_clogsAccess.AddChangeHook(OnConVarChanged);
    g_cdefaultPriD.AddChangeHook(OnConVarChanged);
    g_cdefaultSec.AddChangeHook(OnConVarChanged);
    g_cRoundStartedFontColor.AddChangeHook(OnConVarChanged);
    g_cRoundStartFontColor.AddChangeHook(OnConVarChanged);
    g_cFSPrimary.AddChangeHook(OnConVarChanged);
    g_cFSSecondary.AddChangeHook(OnConVarChanged);
    g_cSetTeam.AddChangeHook(OnConVarChanged);
    g_cKarmaReset.AddChangeHook(OnConVarChanged);
    g_cSetKarma.AddChangeHook(OnConVarChanged);
    g_cDisableRounds.AddChangeHook(OnConVarChanged);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cpluginTag)
    {
        Format(g_sTag, sizeof(g_sTag), newValue);
    }
    else if (convar == g_cdefaultPriD)
    {
        Format(g_sDefaultPrimary, sizeof(g_sDefaultPrimary), newValue);
    }
    else if (convar == g_cdefaultSec)
    {
        Format(g_sDefaultSecondary, sizeof(g_sDefaultSecondary), newValue);
    }
    else if (convar == g_cRoundStartedFontColor)
    {
        Format(g_sRoundStartedFontColor, sizeof(g_sRoundStartedFontColor), newValue);
    }
    else if (convar == g_cRoundStartFontColor)
    {
        Format(g_sRoundStartFontColor, sizeof(g_sRoundStartFontColor), newValue);
    }
    else if (convar == g_cFSPrimary)
    {
        Format(g_sFSPrimary, sizeof(g_sFSPrimary), newValue);
    }
    else if (convar == g_cFSSecondary)
    {
        Format(g_sFSSecondary, sizeof(g_sFSSecondary), newValue);
    }
    else if (convar == g_cDisableRounds)
    {
        TTT_DisableRounds(view_as<bool>(StringToInt(newValue)));
    }
}
