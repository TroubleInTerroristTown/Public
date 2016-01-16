// Credits? Look here: http://git.tf/TTT/Plugin/blob/master/CREDITS.md


#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <multicolors>
#include <emitsoundany>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#include "core/globals.sp"
#include "core/natives.sp"
#include "core/sql.sp"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hOnRoundStart_Pre = CreateGlobalForward("TTT_OnRoundStart_Pre", ET_Event);
	g_hOnRoundStart = CreateGlobalForward("TTT_OnRoundStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hOnRoundStartFailed = CreateGlobalForward("TTT_OnRoundStartFailed", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnClientGetRole = CreateGlobalForward("TTT_OnClientGetRole", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnClientDeath = CreateGlobalForward("TTT_OnClientDeath", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnBodyFound = CreateGlobalForward("TTT_OnBodyFound", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_hOnBodyScanned = CreateGlobalForward("TTT_OnBodyScanned", ET_Ignore, Param_Cell, Param_Cell, Param_String);

	g_hOnItemPurchased = CreateGlobalForward("TTT_OnItemPurchased", ET_Hook, Param_Cell, Param_String);
	g_hOnCreditsGiven_Pre = CreateGlobalForward("TTT_OnCreditsChanged_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_hOnCreditsGiven = CreateGlobalForward("TTT_OnCreditsChanged", ET_Ignore, Param_Cell, Param_Cell);

	CreateNative("TTT_IsRoundActive", Native_IsRoundActive);
	CreateNative("TTT_GetClientRole", Native_GetClientRole);
	CreateNative("TTT_GetClientKarma", Native_GetClientKarma);
	CreateNative("TTT_GetClientCredits", Native_GetClientCredits);
	CreateNative("TTT_SetClientRole", Native_SetClientRole);
	CreateNative("TTT_SetClientKarma", Native_SetClientKarma);
	CreateNative("TTT_SetClientCredits", Native_SetClientCredits);
	CreateNative("TTT_WasBodyFound", Native_WasBodyFound);
	CreateNative("TTT_WasBodyScanned", Native_WasBodyScanned);

	CreateNative("TTT_RegisterCustomItem", Native_RegisterCustomItem);
	CreateNative("TTT_GetCustomItemPrice", Native_GetCustomItemPrice);
	CreateNative("TTT_GetCustomItemRole", Native_GetCustomItemRole);

	RegPluginLibrary("ttt");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	BuildPath(Path_SM, g_sRulesFile, sizeof(g_sRulesFile), "configs/ttt/rules/start.cfg");

	SQL_Start();

	LoadTranslations("ttt.phrases");
	LoadTranslations("common.phrases");

	LoadBadNames();

	g_hRagdollArray = CreateArray(102);
	g_hPlayerArray = CreateArray();
	g_hLogsArray = CreateArray(512);

	g_iCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	g_iAccount = FindSendPropInfo("CCSPlayer", "m_iAccount");


	CreateTimer(0.1, Timer_Adjust, _, TIMER_REPEAT);
	CreateTimer(5.0, Timer_5, _, TIMER_REPEAT);

	RegAdminCmd("sm_setrole", Command_SetRole, ADMFLAG_ROOT);
	RegAdminCmd("sm_karmareset", Command_KarmaReset, ADMFLAG_ROOT);
	RegAdminCmd("sm_setkarma", Command_SetKarma, ADMFLAG_ROOT);
	RegAdminCmd("sm_setcredits", Command_SetCredits, ADMFLAG_ROOT);

	RegConsoleCmd("sm_status", Command_Status);
	RegConsoleCmd("sm_karma", Command_Karma);
	RegConsoleCmd("sm_credits", Command_Credits);
	RegConsoleCmd("sm_boom", Command_Detonate);
	RegConsoleCmd("sm_jihad_detonate", Command_Detonate);
	RegConsoleCmd("sm_logs", Command_Logs);
	RegConsoleCmd("sm_log", Command_Logs);
	RegConsoleCmd("sm_id", Command_ID);

	for (int i = 0; i < sizeof(g_sShopCMDs); i++)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "sm_%s", g_sShopCMDs[i]);
		RegConsoleCmd(sBuffer, Command_Shop);
	}
	RegConsoleCmd("radio3", Command_Shop);

	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEndPre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_changename", Event_ChangeName);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("item_pickup", Event_ItemPickup);

	g_hGraceTime = FindConVar("mp_join_grace_time");

	AddCommandListener(Command_LAW, "+lookatweapon");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_SayTeam, "say_team");
	AddCommandListener(Command_InterceptSuicide, "kill");
	AddCommandListener(Command_InterceptSuicide, "explode");
	AddCommandListener(Command_InterceptSuicide, "spectate");
	AddCommandListener(Command_InterceptSuicide, "jointeam");
	AddCommandListener(Command_InterceptSuicide, "joinclass");

	for(int i= 0; i < sizeof(g_sRadioCMDs); i++)
	{
		AddCommandListener(Command_RadioCMDs, g_sRadioCMDs[i]);
	}

	CreateConVar("ttt2_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	BuildPath(Path_SM, g_sCFile, sizeof(g_sCFile), "configs/ttt/config.cfg");

	Config_Setup("TTT", g_sCFile);

	g_iConfig[i_creditsII] = Config_LoadInt("ttt_credits_killer_innocent_victim_innocent_subtract", 1500, "The amount of credits an innocent will lose for killing an innocent.");
	g_iConfig[i_creditsIT] = Config_LoadInt("ttt_credits_killer_innocent_victim_traitor_add", 3000, "The amount of credits an innocent will recieve when killing a traitor.");
	g_iConfig[i_creditsID] = Config_LoadInt("ttt_credits_killer_innocent_victim_detective_subtract", 4200, "The amount of credits an innocent will lose for killing a detective.");
	g_iConfig[i_creditsTI] = Config_LoadInt("ttt_credits_killer_traitor_victim_innocent_add", 600, "The amount of credits a traitor will recieve for killing an innocent.");
	g_iConfig[i_creditsTT] = Config_LoadInt("ttt_credits_killer_traitor_victim_traitor_subtract", 3000, "The amount of credits a traitor will lose for killing a traitor.");
	g_iConfig[i_creditsTD] = Config_LoadInt("ttt_credits_killer_traitor_victim_detective_add", 4200, "The amount of credits a traitor will recieve for killing a detective.");
	g_iConfig[i_creditsDI] = Config_LoadInt("ttt_credits_killer_detective_victim_innocent_subtract", 300, "The amount of credits a detective will lose for killing an innocent.");
	g_iConfig[i_creditsDT] = Config_LoadInt("ttt_credits_killer_detective_victim_traitor_add", 2100, "The amount of credits a detective will recieve for killing a traitor.");
	g_iConfig[i_creditsDD] = Config_LoadInt("ttt_credits_killer_detective_victim_detective_subtract", 300, "The amount of credits a detective will lose for killing a detective.");
	g_iConfig[i_karmaII] = Config_LoadInt("ttt_karma_killer_innocent_victim_innocent_subtract", 5, "The amount of karma an innocent will lose for killing an innocent.");
	g_iConfig[i_karmaIT] = Config_LoadInt("ttt_karma_killer_innocent_victim_traitor_add", 5, "The amount of karma an innocent will recieve for killing a traitor.");
	g_iConfig[i_karmaID] = Config_LoadInt("ttt_karma_killer_innocent_victim_detective_subtract", 7, "The amount of karma an innocent will lose for killing a detective.");
	g_iConfig[i_karmaTI] = Config_LoadInt("ttt_karma_killer_traitor_victim_innocent_add", 2, "The amount of karma a traitor will recieve for killing an innocent.");
	g_iConfig[i_karmaTT] = Config_LoadInt("ttt_karma_killer_traitor_victim_traitor_subtract", 5, "The amount of karma a traitor will lose for killing a traitor.");
	g_iConfig[i_karmaTD] = Config_LoadInt("ttt_karma_killer_traitor_victim_detective_add", 3, "The amount of karma a traitor will recieve for killing a detective.");
	g_iConfig[i_karmaDI] = Config_LoadInt("ttt_karma_killer_detective_victim_innocent_subtract", 3, "The amount of karma a detective will lose for killing an innocent.");
	g_iConfig[i_karmaDT] = Config_LoadInt("ttt_karma_killer_detective_victim_traitor_add", 7, "The amount of karma a detective will recieve for killing a traitor.");
	g_iConfig[i_karmaDD] = Config_LoadInt("ttt_karma_killer_detective_victim_detective_subtract", 7, "The amount of karma a detective will lose for killing a detective.");
	g_iConfig[i_startKarma] = Config_LoadInt("ttt_start_karma", 100, "The amount of karma new players and players who were karma banned will start with.");
	g_iConfig[i_karmaBan] = Config_LoadInt("ttt_with_karma_ban", 75, "The amount of karma needed to be banned for Bad Karma. (0 = Disabled)");
	g_iConfig[i_karmaBanLength] = Config_LoadInt("ttt_with_karma_ban_length", 10080, "The length of a Bad Karma ban. (Default = 1 Week)");
	g_iConfig[i_maxKarma] = Config_LoadInt("ttt_max_karma", 150, "The maximum amount of karma a player can have.");
	g_iConfig[i_requiredPlayersD] = Config_LoadInt("ttt_required_players_detective", 6, "The amount of players required to activate the detective role.");
	g_iConfig[i_requiredPlayers] = Config_LoadInt("ttt_required_player", 3, "The amount of players required to start the game.");
	g_iConfig[i_traitorloseAliveNonTraitors] = Config_LoadInt("ttt_credits_roundend_traitorlose_alive_nontraitors", 4800, "The amount of credits an innocent or detective will recieve for winning the round if they survived.");
	g_iConfig[i_traitorloseDeadNonTraitors] = Config_LoadInt("ttt_credits_roundend_traitorlose_dead_nontraitors", 1200, "The amount of credits an innocent or detective will recieve for winning the round if they died.");
	g_iConfig[i_traitorwinAliveTraitors] = Config_LoadInt("ttt_credits_roundend_traitorwin_alive_traitors", 4800, "The amount of credits a traitor will recieve for winning the round if they survived.");
	g_iConfig[i_traitorwinDeadTraitors] = Config_LoadInt("ttt_credits_roundend_traitorwin_dead_traitors", 1200, "The amount of credits a traitor will recieve for winning the round if they died.");
	g_iConfig[i_creditsFoundBody] = Config_LoadInt("ttt_credits_found_body_add", 1200, "The amount of credits an innocent or detective will recieve for discovering a new dead body.");
	g_iConfig[i_creditsTaserHurtTraitor] = Config_LoadInt("ttt_hurt_traitor_with_taser", 2000, "The amount of credits an innocent or detective will recieve for discovering a traitor with their zues/taser.");
	g_iConfig[b_showDeathMessage] = Config_LoadBool("ttt_show_death_message", true, "Display a message showing who killed you. 1 = Enabled, 0 = Disabled");
	g_iConfig[b_showKillMessage] = Config_LoadBool("ttt_show_kill_message", true, "Display a message showing who you killed. 1 = Enabled, 0 = Disabled");
	g_iConfig[b_showEarnKarmaMessage] = Config_LoadBool("ttt_show_message_earn_karma", true, "Display a message showing how much karma you earned. 1 = Enabled, 0 = Disabled");
	g_iConfig[b_showEarnCreditsMessage] = Config_LoadBool("ttt_show_message_earn_credits", true, "Display a message showing how many credits you earned. 1 = Enabled, 0 = Disabled");
	g_iConfig[b_showLoseKarmaMessage] = Config_LoadBool("ttt_show__message_lose_karmna", true, "Display a message showing how much karma you lost. 1 = Enabled, 0 = Disabled");
	g_iConfig[b_showLoseCreditsMessage] = Config_LoadBool("ttt_show_message_lose_credits", true, "Display a message showing how many credits you lost. 1 = Enabled, 0 = Disabled");
	g_iConfig[i_messageTypKarma] = Config_LoadInt("ttt_message_typ_karma", 1, "The karma message type. 1 = Hint Text or 2 = Chat Message");
	g_iConfig[i_messageTypCredits] = Config_LoadInt("ttt_message_typ_credits", 1, "The credit message type. 1 = Hint Text, 2 = Chat Message");
	g_iConfig[b_blockSuicide] = Config_LoadBool("ttt_block_suicide", false, "Block players from suiciding with console. 1 = Block, 0 = Don't Block");
	g_iConfig[b_blockGrenadeMessage] = Config_LoadBool("ttt_block_grenade_message", true, "Block grenade messages in chat. 1 = Block, 0 = Don't Block");
	g_iConfig[b_blockRadioMessage] = Config_LoadBool("ttt_block_radio_message", true, "Block radio messages in chat. 1 = Block, 0 = Don't Block");
	g_iConfig[b_allowFlash] = Config_LoadBool("ttt_allow_flash", true, "Enable Flashlight (+lookatweapon). 1 = Enabled, 0 Disabled");
	g_iConfig[b_blockLookAtWeapon] = Config_LoadBool("ttt_block_look_at_weapon", true, "Block weapon inspecting. 1 = Block, 0 = Don't Block)");
	g_iConfig[b_enableNoBlock] = Config_LoadBool("ttt_enable_noblock", false, "Enable No Block. 1 = Enabled, 0 = Disabled");
	g_iConfig[b_kadRemover] = Config_LoadBool("ttt_kad_remover", true, "Block kills, deaths and assists from appearing on the scoreboard. 1 = Enabled, 0 = Disabled");
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_iConfig[s_pluginTag], sizeof(g_iConfig[s_pluginTag]));
	g_iConfig[i_shopDNA] = Config_LoadInt("ttt_shop_dna_scanner", 5000, "The price of a 'DNA Scanner' in the shop. ( 0 = disabled )");
	g_iConfig[i_shopID] = Config_LoadInt("ttt_shop_id_card", 500, "The price of an 'ID Card' in the shop. ( 0 = disabled )");
	g_iConfig[i_shopFAKEID] = Config_LoadInt("ttt_shop_fake_id_card", 3000, "The price of a 'Fake ID Card' in the shop. ( 0 = disabled )");
	g_iConfig[i_shopT] = Config_LoadInt("ttt_shop_t", 0, "The price of the 'Traitor Role' in the shop. ( 0 = disabled )");
	g_iConfig[i_shopD] = Config_LoadInt("ttt_shop_d", 0, "The price of the 'Detective Role' in the shop. ( 0 = disabled )");
	g_iConfig[i_shopTASER] = Config_LoadInt("ttt_shop_taser", 3000, "The price of the 'Taser/Zeus' in the shop. ( 0 = disabled )");
	g_iConfig[i_shopJIHADBOMB] = Config_LoadInt("ttt_shop_jihad_bomb", 6000, "The price of the 'Jihad Bomb' in the shop. ( 0 = disabled )");
	g_iConfig[i_shopC4] = Config_LoadInt("ttt_shop_c4", 10000, "The price of 'C4' in the shop. ( 0 = disabled )");
	g_iConfig[i_spawnHPT] = Config_LoadInt("ttt_spawn_t", 100, "The amount of health traitors spawn with. ( 0 = disabled )");
	g_iConfig[i_spawnHPD] = Config_LoadInt("ttt_spawn_d", 100, "The amount of health detectives spawn with. ( 0 = disabled )");
	g_iConfig[i_spawnHPI] = Config_LoadInt("ttt_spawn_i", 100, "The amount of health innocents spawn with. ( 0 = disabled )");
	g_iConfig[i_rulesClosePunishment] = Config_LoadInt("ttt_rules_close_punishment", 0, "The punishment for abusing the rules menu by closing it with another menu. 0 = Kick, Anything Else = Do Nothing");
	g_iConfig[i_timeToReadDetectiveRules] = Config_LoadInt("ttt_time_to_read_detective_rules", 15, "The time in seconds the detective rules menu will stay open.");
	g_iConfig[i_timeToReadRules] = Config_LoadInt("ttt_time_to_read_rules", 30, "The time in seconds the general rules menu will stay open.");
	g_iConfig[b_showDetectiveMenu] = Config_LoadBool("ttt_show_detective_menu", true, "Show the detective menu. 1 = Show, 0 = Don't Show");
	g_iConfig[b_showRulesMenu] = Config_LoadBool("ttt_show_rules_menu", true, "Show the rules menu. 1 = Show, 0 Don't Show");
	g_iConfig[i_punishInnoKills] = Config_LoadInt("ttt_punish_inno_for_rdm_kils", 3, "The amount of times an innocent will be allowed to kill another innocent before being punished for RDM.");
	Config_LoadString("ttt_kick_immunity", "bz", "Admin flags that won't be kicked for not reading the rules.", g_iConfig[s_kickImmunity], sizeof(g_iConfig[s_kickImmunity]));
	g_iConfig[b_updateClientModel] = Config_LoadBool("ttt_update_client_model", true, "Update the client model isntantly when they are assigned a role. Disables forcing client models to a specified model. 1 = Update, 0 = Don't Update");
	g_iConfig[b_removeHostages] = Config_LoadBool("ttt_remove_hostages", true, "Remove all hostages from the map to prevent interference. 1 = Remove, 0 = Don't Remove");
	g_iConfig[b_removeBomb] = Config_LoadBool("ttt_remove_bomb_on_spawn", true, "Remove the bomb from the map to prevent interference. 1 = Remove, 0 = Don't Remove");
	g_iConfig[b_roleAgain] = Config_LoadBool("ttt_role_again", false, "Allow getting the same role twice in a row.");
	g_iConfig[i_traitorRatio] = Config_LoadInt("ttt_traitor_ratio", 25, "The chance of getting the traitor role.");
	g_iConfig[i_detectiveRatio] = Config_LoadInt("ttt_detective_ratio", 13, "The chance of getting the detective role.");
	g_iConfig[b_taserAllow] = Config_LoadBool("ttt_taser_allow", true, "Should the Taser/Zeus be allowed. 1 = Allow, 0 = Don't Allow");
	g_iConfig[f_jihadPreparingTime] = Config_LoadFloat("ttt_jihad_preparing_time", 60.0, "The amount of ime in seconds until the jihad bomb is ready after buying it.");
	g_iConfig[b_denyFire] = Config_LoadBool("ttt_deny_fire", true, "Stop players who have not been assigned a role yet from shooting. (Mouse1 & Mouse2)");
	g_iConfig[b_slayAfterStart] = Config_LoadBool("ttt_slay_after_start", true, "Slay all players after ttt round started");
	g_iConfig[i_c4ShakeRadius] = Config_LoadInt("ttt_c4_shake_radius", 5000, "The 'shake' radius of the C4 explosion.");
	g_iConfig[f_c4DamageRadius] = Config_LoadFloat("ttt_c4_damage_radius", 275.0, "The damage radius of the C4 explosion.");
	g_iConfig[i_startCredits] = Config_LoadInt("ttt_start_credits", 800, "The amount of credits players will recieve when they join for the first time.");
	g_iConfig[b_removeBuyzone] = Config_LoadBool("ttt_disable_buyzone", false, "Remove all buyzones from the map to prevent interference. 1 = Remove, 0 = Don't Remove");
	g_iConfig[b_forceTeams] = Config_LoadBool("ttt_force_teams", true, "Force players to teams instead of forcing playermodel. 1 = Force team. 0 = Force playermodel.");
	g_iConfig[b_randomWinner] = Config_LoadBool("ttt_random_winner", true, "Choose random winner (CT/T) regardless of normal result. 1 = Yes, 0 = No");
	g_iConfig[b_forceModel] = Config_LoadBool("ttt_force_models", false, "Force all players to use a specified playermodel. Not functional if update models is enabled. 1 = Force models. 0 = Disabled (default).");
	g_iConfig[b_endwithD] = Config_LoadBool("ttt_end_with_detective", false, "Allow the round to end if Detectives remain alive. 0 = Disabled (default). 1 = Enabled.");

	g_iConfig[b_hideTeams] = Config_LoadBool("ttt_hide_teams", false, "Hide team changes from chat.");

	g_iConfig[b_publicKarma] = Config_LoadBool("ttt_public_karma", false, "Show karma as points (or another way?)");
	g_iConfig[b_karmaRound] = Config_LoadBool("ttt_private_karma_round_update", true, "If ttt_public_karma is not set to 1, enable this to update karma at end of round.");
	g_iConfig[b_stripWeapons] = Config_LoadBool("ttt_strip_weapons", true, "Strip players weapons on spawn? Optionally use mp_ct_ and mp_t_ cvars instead.");
	g_iConfig[b_C4Beam] = Config_LoadBool("ttt_c4_beam", true, "Display a beam to Traitors that indicate C4 positions (in light blue)?");
	g_iConfig[b_karmaDMG] = Config_LoadBool("ttt_karma_dmg", false, "Scale damage based off of karma? (damage *= (karma/startkarma))");
	g_iConfig[b_karmaDMG_up] = Config_LoadBool("ttt_karma_dmg_up", false, "If ttt_karma_dmg is enabled, should be enable scaling damage upward?");
	g_iConfig[f_roundDelay] = Config_LoadFloat("ttt_after_round_delay", 7.0, "The amount of seconds to use for round-end delay. Use 0.0 for default.");
	g_iConfig[b_nextRoundAlert] = Config_LoadBool("ttt_next_round_alert", false, "Tell players in chat when the next round will begin (when the round ends)");
	g_iConfig[b_endroundDMG] = Config_LoadBool("ttt_end_round_dm", false, "Enable this to disable damage prevention between round end and warmup.");

	Config_LoadString("ttt_forced_model_ct", "models/player/ctm_st6.mdl", "The default model to force for CT (Detectives) if ttt_force_models is enabled.", g_iConfig[s_modelCT], sizeof(g_iConfig[s_modelCT]));
	Config_LoadString("ttt_forced_model_t", "models/player/tm_phoenix.mdl", "The default model to force for T (Inno/Traitor) if ttt_force_models is enabled.", g_iConfig[s_modelT], sizeof(g_iConfig[s_modelT]));

	Config_LoadString("ttt_log_file", "logs/ttt/ttt.log", "The default file to log TTT data to (including end of round).", g_iConfig[s_logFile], sizeof(g_iConfig[s_logFile]));
	Config_LoadString("ttt_error_file", "logs/ttt/ttt-error.log", "The default file to log TTT errors/bugs to.", g_iConfig[s_errFile], sizeof(g_iConfig[s_errFile]));

	Config_LoadString("ttt_default_primary_d", "weapon_m4a1_silencer", "The default primary gun to give players when they become a Detective (if they have no primary).", g_iConfig[s_defaultPri_D], sizeof(g_iConfig[s_defaultPri_D]));
	Config_LoadString("ttt_default_secondary", "weapon_glock", "The default secondary gun to give players when they get their role (if they have no secondary).", g_iConfig[s_defaultSec], sizeof(g_iConfig[s_defaultSec]));

	Config_Done();

	BuildPath(Path_SM, g_iConfig[s_logFile], sizeof(g_iConfig[s_logFile]), g_iConfig[s_logFile]);
	BuildPath(Path_SM, g_iConfig[s_errFile], sizeof(g_iConfig[s_errFile]), g_iConfig[s_errFile]);
}

public void OnConfigsExecuted()
{
	if(g_iConfig[b_blockGrenadeMessage])
		SetConVarBool(FindConVar("sv_ignoregrenaderadio"), true);
}

public Action Command_Logs(int client, int args)
{
	if(g_bRoundStarted)
	{
		if((client == 0) || (!IsPlayerAlive(client)))
			ShowLogs(client);
		else
			CPrintToChat(client, g_iConfig[s_pluginTag], "you cant see logs", client);
	}
	else
	{
		if(client == 0)
			PrintToServer("No logs yet");
		else
			CPrintToChat(client, g_iConfig[s_pluginTag], "you cant see logs", client);
	}
	return Plugin_Handled;
}

stock void ShowLogs(int client)
{
	int sizearray = GetArraySize(g_hLogsArray);
	if(sizearray == 0)
	{
		if(client == 0)
			PrintToServer("No logs yet");
		else
			CPrintToChat(client, g_iConfig[s_pluginTag], "no logs yet", client);

		return;
	}

	if(g_bReceivingLogs[client])
		return;
	g_bReceivingLogs[client] = true;

	if(client == 0)
	{
		LogToFileEx(g_iConfig[s_logFile], "--------------------------------------");
		LogToFileEx(g_iConfig[s_logFile], "-----------START ROUND LOGS-----------");
	}
	else
	{
		CPrintToChat(client, g_iConfig[s_pluginTag], "Receiving logs", client);
		PrintToConsole(client, "--------------------------------------");
		PrintToConsole(client, "---------------TTT LOGS---------------");
	}

	char item[512];
	int index = 5;
	bool end = false;

	if(index >= sizearray)
	{
		end = true;
		index = (sizearray -1);
	}

	for(int i = 0; i <= index; i++)
	{
		GetArrayString(g_hLogsArray, i, item, sizeof(item));

		if(client == 0)
			LogToFileEx(g_iConfig[s_logFile], item);
		else
			PrintToConsole(client, item);
	}

	if(end)
	{
		if(client == 0)
			LogToFileEx(g_iConfig[s_logFile], "--------------------------------------");
		else
		{
			CPrintToChat(client, g_iConfig[s_pluginTag], "See your console", client);
			PrintToConsole(client, "--------------------------------------");
			PrintToConsole(client, "--------------------------------------");
		}

		g_bReceivingLogs[client] = false;
		return;
	}

	DataPack slPack = new DataPack();
	RequestFrame(OnCreate, slPack);
	slPack.WriteCell(GetClientUserId(client));
	slPack.WriteCell(index);
}

public void OnCreate(any pack)
{
	ResetPack(pack);
	int userid = ReadPackCell(pack);
	int index = ReadPackCell(pack);

	int client = GetClientOfUserId(userid);

	if ((client == 0) || IsClientInGame(client))
	{
		int sizearray = GetArraySize(g_hLogsArray);
		int old = (index + 1);
		index += 5;
		bool end = false;
		if(index >= sizearray)
		{
			end = true;
			index = (sizearray -1);
		}
		char item[512];

		for(int i = old; i <= index; i++)
		{
			GetArrayString(g_hLogsArray, i, item, sizeof(item));
			if(client == 0)
				LogToFileEx(g_iConfig[s_logFile], item);
			else
				PrintToConsole(client, item);
		}

		if(end)
		{
			if(client == 0)
				LogToFileEx(g_iConfig[s_logFile], "--------------------------------------");
			else
			{
				CPrintToChat(client, g_iConfig[s_pluginTag], "See your console", client);
				PrintToConsole(client, "--------------------------------------");
				PrintToConsole(client, "--------------------------------------");
			}

			g_bReceivingLogs[client] = false;
			return;
		}

		DataPack slPack = new DataPack();
		RequestFrame(OnCreate, slPack);
		slPack.WriteCell(GetClientUserId(client));
		slPack.WriteCell(index);
	}
}

public Action Command_InterceptSuicide(int client, const char[] command, int args)
{
	if(g_iConfig[b_blockSuicide] && IsPlayerAlive(client))
	{
		CPrintToChat(client, g_iConfig[s_pluginTag], "Suicide Blocked", client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Command_RadioCMDs(int client, const char[] command, int args)
{
	if(g_iConfig[b_blockRadioMessage])
		return Plugin_Handled;
	return Plugin_Continue;
}

public void OnMapStart()
{
	for(int i; i < g_iBadNameCount; i++)
		g_sBadNames[i] = "";
	g_iBadNameCount = 0;

	LoadBadNames();

	g_iBeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
	g_iC4BeamSprite = PrecacheModel("materials/sprites/hostage_following.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo.vtf");

	PrecacheModel("props/cs_office/microwave.mdl", true);
	PrecacheModel("weapons/w_c4_planted.mdl", true);

	PrecacheSoundAny(SND_BLIP, true);
	PrecacheSoundAny(SND_TCHAT, true);
	PrecacheSoundAny(SND_FLASHLIGHT, true);
	PrecacheSoundAny(SND_BURST, true);
	PrecacheSoundAny(SND_BEEP, true);
	PrecacheSoundAny(SND_DISARM, true);

	PrecacheSoundAny("ttt/jihad/explosion.mp3", true);
	PrecacheSoundAny("ttt/jihad/jihad.mp3", true);

	AddFileToDownloadsTable("sound/ttt/jihad/explosion.mp3");
	AddFileToDownloadsTable("sound/ttt/jihad/jihad.mp3");

	ClearArray(g_hLogsArray);

	AddFileToDownloadsTable("materials/sprites/sg_detective_icon.vmt");
	AddFileToDownloadsTable("materials/sprites/sg_detective_icon.vtf");
	PrecacheModel("materials/sprites/sg_detective_icon.vmt");

	AddFileToDownloadsTable("materials/sprites/sg_traitor_icon.vmt");
	AddFileToDownloadsTable("materials/sprites/sg_traitor_icon.vtf");
	PrecacheModel("materials/sprites/sg_traitor_icon.vmt");

	AddFileToDownloadsTable("materials/overlays/ttt/innocents_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/innocents_win.vtf");
	PrecacheDecal("overlays/ttt/innocents_win", true);

	AddFileToDownloadsTable("materials/overlays/ttt/traitors_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/traitors_win.vtf");
	PrecacheDecal("overlays/ttt/traitors_win", true);

	AddFileToDownloadsTable("materials/darkness/ttt/overlayDetective.vmt");
	AddFileToDownloadsTable("materials/darkness/ttt/overlayDetective.vtf");
	PrecacheDecal("darkness/ttt/overlayDetective", true);

	AddFileToDownloadsTable("materials/darkness/ttt/overlayTraitor.vmt");
	AddFileToDownloadsTable("materials/darkness/ttt/overlayTraitor.vtf");
	PrecacheDecal("darkness/ttt/overlayTraitor", true);

	AddFileToDownloadsTable("materials/darkness/ttt/overlayInnocent.vmt");
	AddFileToDownloadsTable("materials/darkness/ttt/overlayInnocent.vtf");
	PrecacheDecal("darkness/ttt/overlayInnocent", true);

 	AddFileToDownloadsTable("materials/overlays/ttt/detectives_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/detectives_win.vtf");
	PrecacheDecal("overlays/ttt/detectives_win", true);

	PrecacheModel(g_iConfig[s_modelCT], true);
	PrecacheModel(g_iConfig[s_modelT], true);

	g_iAlive = FindSendPropInfo("CCSPlayerResource", "m_bAlive");
	if (g_iAlive == -1)
		SetFailState("CCSPlayerResource.m_bAlive offset is invalid");

	g_iKills = FindSendPropInfo("CCSPlayerResource", "m_iKills");
	if (g_iKills == -1)
		SetFailState("CCSPlayerResource \"m_iKills\" offset is invalid");

	g_iDeaths = FindSendPropInfo("CCSPlayerResource", "m_iDeaths");
	if (g_iDeaths == -1)
		SetFailState("CCSPlayerResource \"m_iDeaths\"  offset is invalid");

	g_iAssists = FindSendPropInfo("CCSPlayerResource", "m_iAssists");
	if (g_iAssists == -1)
		SetFailState("CCSPlayerResource \"m_iAssists\"  offset is invalid");

	g_iMVPs = FindSendPropInfo("CCSPlayerResource", "m_iMVPs");
	if (g_iMVPs == -1)
		SetFailState("CCSPlayerResource \"m_iMVPs\"  offset is invalid");


	int iPlayerManagerPost = FindEntityByClassname(0, "cs_player_manager");
	SDKHook(iPlayerManagerPost, SDKHook_ThinkPost, ThinkPost);

	resetPlayers();
}

public void ThinkPost(int entity)
{
	int isAlive[65];

	GetEntDataArray(entity, g_iAlive, isAlive, 65);
	LoopValidClients(i)
	{
		if(IsPlayerAlive(i) || !g_bFound[i])
			isAlive[i] = true;
		else
			isAlive[i] = false;
	}
	SetEntDataArray(entity, g_iAlive, isAlive, 65);

	if(g_iConfig[b_kadRemover])
	{
		int iZero[MAXPLAYERS + 1] =  { 0, ... };

		SetEntDataArray(entity, g_iKills, iZero, MaxClients + 1);
		SetEntDataArray(entity, g_iDeaths, iZero, MaxClients + 1);
		SetEntDataArray(entity, g_iAssists, iZero, MaxClients + 1);
		SetEntDataArray(entity, g_iMVPs, iZero, MaxClients + 1);
	}
}

public Action Command_Karma(int client, int args)
{
	if (!TTT_IsClientValid(client))
		return Plugin_Handled;

	CPrintToChat(client, g_iConfig[s_pluginTag], "Your karma is", client, g_iKarma[client]);

	return Plugin_Handled;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	ClearArray(g_hRagdollArray);

	g_bInactive = false;
	g_bRoundEnded = false;
	LoopValidClients(i)
	{
		g_iRole[i] = TTT_TEAM_UNASSIGNED;
		g_bFound[i] = true;
		g_iInnoKills[i] = 0;
		g_bHasC4[i] = false;
		g_bImmuneRDMManager[i] = false;

		CS_SetClientClanTag(i, " ");
	}

	if(g_hStartTimer != null)
		KillTimer(g_hStartTimer);

	if(g_hCountdownTimer != null)
		KillTimer(g_hCountdownTimer);

	float warmupTime = GetConVarFloat(g_hGraceTime) + 5.0;
	g_hStartTimer = CreateTimer(warmupTime, Timer_Selection, _ , TIMER_FLAG_NO_MAPCHANGE);

	g_fRealRoundStart = GetGameTime() + warmupTime;
	g_hCountdownTimer = CreateTimer(0.5, Timer_SelectionCountdown, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	g_bRoundStarted = false;

	if (g_hRoundTimer != null)
		CloseHandle(g_hRoundTimer);

	g_hRoundTimer = CreateTimer(GetConVarFloat(FindConVar("mp_freezetime")) + (GetConVarFloat(FindConVar("mp_roundtime")) * 60.0), Timer_OnRoundEnd);

	ShowOverlayToAll("");
	resetPlayers();
}

public Action Event_RoundEndPre(Event event, const char[] name, bool dontBroadcast)
{
	LoopValidClients(i)
	{
		g_bFound[i] = true;
		g_iInnoKills[i] = 0;
		g_bImmuneRDMManager[i] = false;

		ShowLogs(i);
		TeamTag(i);
	}

	ShowLogs(0);


	if (g_hRoundTimer != null)
	{
		CloseHandle(g_hRoundTimer);
		g_hRoundTimer = null;
	}
	resetPlayers();
}

public Action Timer_SelectionCountdown(Handle hTimer)
{
	int timeLeft = RoundToFloor(g_fRealRoundStart - GetGameTime());

	if (g_fRealRoundStart <= 0.0 || timeLeft <= 0)
	{
		g_hCountdownTimer = null;
		return Plugin_Stop;
	}

	char centerText[512];

	LoopValidClients(iClient)
	{
		Format(centerText, sizeof(centerText), "%T", "StartTimer", iClient, timeLeft);
		PrintHintText(iClient, centerText);
	}

	return Plugin_Continue;
}

public Action Timer_Selection(Handle hTimer)
{
	g_hStartTimer = null;

	ClearArray(g_hPlayerArray);

	if(g_hDetectives == null)
		g_hDetectives = CreateArray(1);

	if(g_hTraitores == null)
		g_hTraitores = CreateArray(1);

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnRoundStart_Pre);
	Call_Finish(res);

	if(res >= Plugin_Handled)
	{
		Call_StartForward(g_hOnRoundStartFailed);
		Call_PushCell(-1);
		Call_PushCell(g_iConfig[i_requiredPlayers]);
		Call_Finish();

		return;
	}

	int iCount = 0;
	LoopValidClients(i)
	{
		if(GetClientTeam(i) <= CS_TEAM_SPECTATOR || GetClientTeam(i) > CS_TEAM_CT)
			continue;

		if(!IsPlayerAlive(i))
			continue;

		if(IsFakeClient(i))
			continue;

		iCount++;
		PushArrayCell(g_hPlayerArray, i);
	}

	if(iCount < g_iConfig[i_requiredPlayers])
	{
		g_bInactive = true;
		LoopValidClients(i)
			CPrintToChat(i, g_iConfig[s_pluginTag], "MIN PLAYERS REQUIRED FOR PLAY", i, g_iConfig[i_requiredPlayers]);

		Call_StartForward(g_hOnRoundStartFailed);
		Call_PushCell(iCount);
		Call_PushCell(g_iConfig[i_requiredPlayers]);
		Call_Finish();

		return;
	}

	int iDetectives = RoundToNearest(iCount * float(g_iConfig[i_detectiveRatio])/100.0);
	if(iDetectives == 0)
		iDetectives = 1;

	bool needDetective = ( iCount >= g_iConfig[i_requiredPlayersD]);

	/* Not enough players to allow a detective */
	if(!needDetective)
		iDetectives = 0;

	int iTraitores = RoundToNearest(iCount * float(g_iConfig[i_traitorRatio])/100.0);
	if(iTraitores == 0)
		iTraitores = 1;

	int index;
	int player;
	while((index = GetRandomArray(g_hPlayerArray)) != -1)
	{
		player = GetArrayCell(g_hPlayerArray, index);

		if(iDetectives > 0 && (!g_iConfig[b_showDetectiveMenu] || g_bConfirmDetectiveRules[player]) && (g_iConfig[b_roleAgain] || !IsPlayerInArray(player, g_hDetectives)))
		{
			g_iRole[player] = TTT_TEAM_DETECTIVE;
			iDetectives--;
		}
		else if(iTraitores > 0 && (g_iConfig[b_roleAgain] || !IsPlayerInArray(player, g_hTraitores)))
		{
			g_iRole[player] = TTT_TEAM_TRAITOR;
			iTraitores--;
		}
		else g_iRole[player] = TTT_TEAM_INNOCENT;

		while (GetPlayerWeaponSlot(player, CS_SLOT_KNIFE) == -1)
			GivePlayerItem(player, "weapon_knife");

		if (GetPlayerWeaponSlot(player, CS_SLOT_SECONDARY) == -1)
			GivePlayerItem(player, g_iConfig[s_defaultSec]);

		g_bFound[player] = false;

		RemoveFromArray(g_hPlayerArray, index);
	}

	/* Recount roles */

	int iTraitors = 0;
	int iInnocent = 0;
	int iDetective = 0;

	LoopValidClients(i)
	{
		if (!IsPlayerAlive(i))
			continue;

		if (IsFakeClient(i))
			continue;

		if(g_iRole[i] == TTT_TEAM_TRAITOR)
			iTraitors++;
		else if(g_iRole[i] == TTT_TEAM_DETECTIVE)
			iDetective++;
		else if(g_iRole[i] == TTT_TEAM_INNOCENT)
			iInnocent++;
	}

	/* No detective found, but we need one */
	if(iDetective == 0 && needDetective)
	{
		LoopValidClients(i)
		{
			if(g_iRole[i] != TTT_TEAM_INNOCENT && (!g_bConfirmDetectiveRules[i] && g_iConfig[b_showDetectiveMenu]))
				continue;

			iInnocent--;
			iDetective++;

			g_iRole[i] = TTT_TEAM_DETECTIVE;
			break;
		}
	}

	/* No triaitor found, but we need one */
	if(iTraitors == 0)
	{
		LoopValidClients(i)
		{
			if(g_iRole[i] != TTT_TEAM_INNOCENT)
				continue;

			iInnocent--;
			iTraitors++;

			g_iRole[i] = TTT_TEAM_TRAITOR;
			break;
		}
	}

	/* Remember role, to prevent same role next round for players */
	ClearArray(g_hDetectives);
	ClearArray(g_hTraitores);

	LoopValidClients(i)
		if(!g_iConfig[b_roleAgain])
		{
			if(g_iRole[i] == TTT_TEAM_DETECTIVE)
				PushArrayCell(g_hDetectives, i);
			else if(g_iRole[i] == TTT_TEAM_TRAITOR)
				PushArrayCell(g_hTraitores, i);
		}

	LoopValidClients(i)
	{
		if((!g_iConfig[b_publicKarma]) && g_iConfig[b_karmaRound]){
			CS_SetClientContributionScore(i, g_iKarma[i]);
			CPrintToChat(i, g_iConfig[s_pluginTag], "All karma score updated", i);
		}

		CPrintToChat(i, g_iConfig[s_pluginTag], "TEAMS HAS BEEN SELECTED", i);

		if(g_iRole[i] != TTT_TEAM_TRAITOR)
			CPrintToChat(i, g_iConfig[s_pluginTag], "TRAITORS HAS BEEN SELECTED", i, iTraitors);
		else
			listTraitors(i);

		if(GetClientTeam(i) <= CS_TEAM_SPECTATOR || GetClientTeam(i) > CS_TEAM_CT)
			continue;

		if(!IsPlayerAlive(i))
			continue;

		if(IsFakeClient(i))
			continue;

		TeamInitialize(i);
	}

	ClearArray(g_hLogsArray);
	g_bRoundStarted = true;

	Call_StartForward(g_hOnRoundStart);
	Call_PushCell(iInnocent);
	Call_PushCell(iTraitors);
	Call_PushCell(iDetective);
	Call_Finish();

	ApplyIcons();
}

stock int GetRandomArray(Handle array)
{
	int size = GetArraySize(array);
	if(size == 0)
		return -1;
	return Math_GetRandomInt(0, size-1);
}

stock bool IsPlayerInArray(int player, Handle array)
{
	for(int i = 0;i < GetArraySize(array);i++)
	{
		if(player == GetArrayCell(array, i))
			return true;
	}

	return false;
}

stock void TeamInitialize(int client)
{
	if(!TTT_IsClientValid(client))
		return;

	if(g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		g_iIcon[client] = CreateIcon(client);
		CS_SetClientClanTag(client, "DETECTIVE");

		if(g_iConfig[b_forceTeams])
		{
			if(GetClientTeam(client) != CS_TEAM_CT)
				CS_SwitchTeam(client, CS_TEAM_CT);
		}

		if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == -1)
			GivePlayerItem(client, g_iConfig[s_defaultPri_D]);

		if(g_iConfig[b_taserAllow])
			GivePlayerItem(client, "weapon_taser");

		CPrintToChat(client, g_iConfig[s_pluginTag], "Your Team is DETECTIVES", client);

		if(g_iConfig[i_spawnHPD] > 0)
			SetEntityHealth(client, g_iConfig[i_spawnHPD]);
	}
	else if(g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		g_iIcon[client] = CreateIcon(client);
		CPrintToChat(client, g_iConfig[s_pluginTag], "Your Team is TRAITORS", client);

		if(g_iConfig[i_spawnHPT] > 0)
			SetEntityHealth(client, g_iConfig[i_spawnHPT]);

		if(g_iConfig[b_forceTeams])
		{
			if(GetClientTeam(client) != CS_TEAM_T)
				CS_SwitchTeam(client, CS_TEAM_T);
		}
	}
	else if(g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		CPrintToChat(client, g_iConfig[s_pluginTag], "Your Team is INNOCENTS", client);

		if(g_iConfig[i_spawnHPI] > 0)
			SetEntityHealth(client, g_iConfig[i_spawnHPI]);

		if(g_iConfig[b_forceTeams])
		{
			if(GetClientTeam(client) != CS_TEAM_T)
				CS_SwitchTeam(client, CS_TEAM_T);
		}
	}
	else if(g_iRole[client] == TTT_TEAM_UNASSIGNED)
	    CS_SetClientClanTag(client, "UNASSIGNED");

	if(g_iConfig[b_updateClientModel])
		CS_UpdateClientModel(client);
	else if(g_iConfig[b_forceModel])
	{
	    switch(g_iRole[client])
	    {
	        case TTT_TEAM_INNOCENT, TTT_TEAM_TRAITOR:
	            SetEntityModel(client, g_iConfig[s_modelT]);
	        case TTT_TEAM_DETECTIVE:
	            SetEntityModel(client, g_iConfig[s_modelCT]);
	    }
	}

	Call_StartForward(g_hOnClientGetRole);
	Call_PushCell(client);
	Call_PushCell(g_iRole[client]);
	Call_Finish();
}

stock void TeamTag(int client)
{
	if (!IsClientInGame(client) || client < 0 || client > MaxClients)
		return;

	if(g_iRole[client] == TTT_TEAM_DETECTIVE)
		CS_SetClientClanTag(client, "DETECTIVE");
	else if(g_iRole[client] == TTT_TEAM_TRAITOR)
		CS_SetClientClanTag(client, "TRAITOR");
	else if(g_iRole[client] == TTT_TEAM_INNOCENT)
		CS_SetClientClanTag(client, "INNOCENT");
	else if(g_iRole[client] == TTT_TEAM_UNASSIGNED)
	    CS_SetClientClanTag(client, "UNASSIGNED");
	else
		CS_SetClientClanTag(client, " ");
}

stock void ApplyIcons()
{
	LoopValidClients(i)
		if(IsPlayerAlive(i))
			g_iIcon[i] = CreateIcon(i);
}


// Prevent spawn if round has started
public Action Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(g_bRoundStarted && TTT_IsClientValid(client))
	{
		CS_SetClientClanTag(client, "UNASSIGNED");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(TTT_IsClientValid(client))
	{
		if(g_bRoundStarted)
		{
			if(g_iConfig[b_slayAfterStart])
			{
				g_iRole[client] = TTT_TEAM_UNASSIGNED;
				CreateTimer(0.0, Timer_SlayPlayer, GetClientUserId(client));
				CS_SetClientClanTag(client, "UNASSIGNED");
			}
		}
		else
			CS_SetClientClanTag(client, " ");

		g_iInnoKills[client] = 0;

		StripAllWeapons(client);

		ClearTimer(g_hJihadBomb[client]);
		g_bDetonate[client] = false;

		if(g_bInactive)
		{
			int iCount = 0;

			LoopValidClients(i)
				if(IsPlayerAlive(i) && (GetClientTeam(i) > CS_TEAM_SPECTATOR))
					iCount++;

			if(iCount >= 3)
				ServerCommand("mp_restartgame 2");
		}
		else
		{
			CPrintToChat(client, g_iConfig[s_pluginTag], "Your credits is", client, g_iCredits[client]);
			CPrintToChat(client, g_iConfig[s_pluginTag], "Your karma is", client, g_iKarma[client]);
		}

		g_bScan[client] = false;
		g_bID[client] = false;
		g_bJihadBomb[client] = false;

		if(g_iConfig[b_enableNoBlock])
			SetNoBlock(client);
	}
}

public Action Timer_SlayPlayer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
		ForcePlayerSuicide(client);
}

public void OnClientPutInServer(int client)
{
	g_bImmuneRDMManager[client] = false;

	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponPostSwitch);
	SDKHook(client, SDKHook_PreThink, OnPreThink);

	SetEntData(client, g_iAccount, 16000);

	g_iCredits[client] = g_iConfig[i_startCredits];
}

public Action OnPreThink(int client)
{
	if(g_iConfig[b_publicKarma])
		if(TTT_IsClientValid(client))
			CS_SetClientContributionScore(client, g_iKarma[client]);
}

stock void AddStartKarma(int client)
{
	setKarma(client, g_iConfig[i_startKarma]);
}

stock void BanBadPlayerKarma(int client)
{
	char sReason[512];
	Format(sReason, sizeof(sReason), "%T", "Your Karma is too low", client);

	setKarma(client, g_iConfig[i_startKarma]);

	ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(client), g_iConfig[i_karmaBanLength], sReason);
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(g_bRoundEnded && g_iConfig[b_endroundDMG])
		return Plugin_Continue;

	if(!g_bRoundStarted)
		return Plugin_Handled;

	if(IsWorldDamage(iAttacker, damagetype))
		return Plugin_Continue;

	if(!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
		return Plugin_Continue;

	char item[512], sWeapon[64];
	GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));
	if(StrEqual(sWeapon, "weapon_taser", false))
	{
		if(g_iRole[iVictim] == TTT_TEAM_TRAITOR)
		{
			Format(item, sizeof(item), "-> [%N (Traitor) was tased by %N] - TRAITOR DETECTED", iVictim, iAttacker, iVictim);
			PushArrayString(g_hLogsArray, item);
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "You hurt a Traitor", iVictim, iVictim);
			addCredits(iAttacker, g_iConfig[i_creditsTaserHurtTraitor]);
		}
		else if(g_iRole[iVictim] == TTT_TEAM_DETECTIVE)
		{
			Format(item, sizeof(item), "-> [%N (Detective) was tased by %N]", iVictim, iAttacker, iVictim);
			PushArrayString(g_hLogsArray, item);
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "You hurt a Detective", iVictim, iVictim);
		}
		else if(g_iRole[iVictim] == TTT_TEAM_INNOCENT)
		{
			Format(item, sizeof(item), "-> [%N (Innocent) was tased by %N]", iVictim, iAttacker, iVictim);
			PushArrayString(g_hLogsArray, item);
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "You hurt an Innocent", iVictim, iVictim);
		}

		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
	if(g_bRoundEnded && g_iConfig[b_endroundDMG])
		return Plugin_Continue;

	if(!g_bRoundStarted)
		return Plugin_Handled;

	if((0 < iAttacker <= MaxClients) && IsClientInGame(iAttacker) && iAttacker != iVictim && g_iConfig[b_karmaDMG]){
		if(g_iConfig[b_karmaDMG_up] || (g_iKarma[iAttacker] < g_iConfig[i_startKarma])){
			damage *= FloatDiv(float(g_iKarma[iAttacker]), float(g_iConfig[i_startKarma]));
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

// TODO: Move to ttt.inc
stock bool IsWorldDamage(int iAttacker, int damagetype)
{
	if(damagetype == DMG_FALL
		|| damagetype == DMG_GENERIC
		|| damagetype == DMG_CRUSH
		|| damagetype == DMG_SLASH
		|| damagetype == DMG_BURN
		|| damagetype == DMG_VEHICLE
		|| damagetype == DMG_FALL
		|| damagetype == DMG_BLAST
		|| damagetype == DMG_SHOCK
		|| damagetype == DMG_SONIC
		|| damagetype == DMG_ENERGYBEAM
		|| damagetype == DMG_DROWN
		|| damagetype == DMG_PARALYZE
		|| damagetype == DMG_NERVEGAS
		|| damagetype == DMG_POISON
		|| damagetype == DMG_ACID
		|| damagetype == DMG_AIRBOAT
		|| damagetype == DMG_PLASMA
		|| damagetype == DMG_RADIATION
		|| damagetype == DMG_SLOWBURN
		|| iAttacker == 0
	)
		return true;
	return false;
}

public Action Event_PlayerDeathPre(Event event, const char[] menu, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iInnoKills[client] = 0;
	ClearIcon(client);

	ClearTimer(g_hJihadBomb[client]);

	int iRagdoll = 0;
	if(g_iRole[client] > TTT_TEAM_UNASSIGNED)
	{
		iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if (iRagdoll > 0)
			AcceptEntityInput(iRagdoll, "Kill");

		char playermodel[128];
		GetClientModel(client, playermodel, 128);

		float origin[3], angles[3], velocity[3];

		GetClientAbsOrigin(client, origin);
		GetClientAbsAngles(client, angles);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

		int iEntity = CreateEntityByName("prop_ragdoll");
		DispatchKeyValue(iEntity, "model", playermodel);


		// Prevent crash. If spawn isn't dispatched successfully,
		// TeleportEntity() crashes the server. This left some very
		// odd crash dumps, and usually only happened when 2 players
		// died inside each other in the same tick.
		// Thanks to -
		// 		Phoenix Gaming Network (pgn.site)
		// 		Prestige Gaming Organization

		ActivateEntity(iEntity);
		if(DispatchSpawn(iEntity))
		{
			float speed = GetVectorLength(velocity);
			if(speed >= 500)
				TeleportEntity(iEntity, origin, angles, NULL_VECTOR);
			else
				TeleportEntity(iEntity, origin, angles, velocity);
		}
		else
			LogToFileEx(g_iConfig[s_errFile], "Unable to spawn ragdoll for %N (Auth: %i)", client, GetSteamAccountID(client));

		SetEntData(iEntity, g_iCollisionGroup, 2, 4, true);


		int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		int Items[Ragdolls];
		Items[ent] = EntIndexToEntRef(iEntity);
		Items[victim] = client;
		Format(Items[victimName], MAX_NAME_LENGTH, name);
		Items[scanned] = false;
		GetClientName(iAttacker, name, sizeof(name));
		Items[attacker] = iAttacker;
		Format(Items[attackerName], MAX_NAME_LENGTH, name);
		Items[gameTime] = GetGameTime();
		event.GetString("weapon", Items[weaponused], sizeof(Items[weaponused]));

		PushArrayArray(g_hRagdollArray, Items[0]);

		SetEntPropEnt(client, Prop_Send, "m_hRagdoll", iEntity);

		if (client != iAttacker && iAttacker != 0 && !g_bImmuneRDMManager[iAttacker] && !g_bHoldingProp[client] && !g_bHoldingSilencedWep[client])
		{
			if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)
			{
				if (g_hRDMTimer[client] != null)
					KillTimer(g_hRDMTimer[client]);
				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			}
			else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE)
			{
				if (g_hRDMTimer[client] != null)
					KillTimer(g_hRDMTimer[client]);
				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			}
			else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE)
			{
				if (g_hRDMTimer[client] != null)
					KillTimer(g_hRDMTimer[client]);
				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			}
			else if ((g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_INNOCENT) || (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_INNOCENT))
			{
				g_iInnoKills[iAttacker]++;
			}

			if (g_iInnoKills[iAttacker] >= g_iConfig[i_punishInnoKills])
				ServerCommand("sm_slay #%i 5", GetClientUserId(iAttacker));
		}
	}
	else
	{
		// Usually if this event is called for unassigned
		// players, they spawned in late and were slayed by
		// the plugin. So let's ditch their ragdolls to be sure.
		iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if (iRagdoll > 0)
			AcceptEntityInput(iRagdoll, "Kill");
	}

	if(!dontBroadcast)
	{
		dontBroadcast = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	nameCheck(client, name);

	LoadClientKarma(GetClientUserId(client));

	if(g_iConfig[b_showRulesMenu])
		CreateTimer(3.0, Timer_ShowWelcomeMenu, GetClientUserId(client));
	else if(g_iConfig[b_showDetectiveMenu])
		CreateTimer(3.0, Timer_ShowDetectiveMenu, GetClientUserId(client));
}

public Action Timer_ShowWelcomeMenu(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if(TTT_IsClientValid(client))
	{
		ShowRules(client, g_iSite[client]);
	}
}

stock void ShowRules(int client, int item)
{
	char sText[512], sYes[64];
	Format(sText, sizeof(sText), "%T", "Welcome Menu", client, client, TTT_PLUGIN_AUTHOR);
	Format(sYes, sizeof(sYes), "%T", "WM Yes", client);

	Menu menu = new Menu(Menu_ShowWelcomeMenu);
	menu.SetTitle(sText);

	Handle hFile = OpenFile(g_sRulesFile, "rt");

	if(hFile == null)
		SetFailState("[TTT] Can't open File: %s", g_sRulesFile);

	KeyValues kvRules = CreateKeyValues("Rules");

	if(!kvRules.ImportFromFile(g_sRulesFile))
	{
		SetFailState("Can't read rules/start.cfg correctly! (ImportFromFile)");
		return;
	}

	if (!kvRules.GotoFirstSubKey())
	{
		SetFailState("Can't read rules/start.cfg correctly! (GotoFirstSubKey)");
		return;
	}

	do
	{
		char sNumber[4];
		char sTitle[64];

		kvRules.GetSectionName(sNumber, sizeof(sNumber));
		kvRules.GetString("title", sTitle, sizeof(sTitle));
		menu.AddItem(sNumber, sTitle);
	}
	while (kvRules.GotoNextKey());

	delete kvRules;

	menu.AddItem("yes", sYes);
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.DisplayAt(client, item, g_iConfig[i_timeToReadRules]);
}

public int Menu_ShowWelcomeMenu(Menu menu, MenuAction action, int client, int param)
{
	if ( action == MenuAction_Select )
	{
		char sParam[32];
		GetMenuItem(menu, param, sParam, sizeof(sParam));

		if (StrEqual(sParam, "yes", false)){
			delete menu;
			return 0;
		}

		Handle hFile = OpenFile(g_sRulesFile, "rt");

		if(hFile == null){
			SetFailState("[TTT] Can't open File: %s", g_sRulesFile);
			delete menu;
			return 0;
		}

		KeyValues kvRules = CreateKeyValues("Rules");

		if(!kvRules.ImportFromFile(g_sRulesFile))
		{
			SetFailState("Can't read rules/start.cfg correctly! (ImportFromFile)");

			delete kvRules;
			delete menu;

			return 0;
		}

		if(kvRules.JumpToKey(sParam, false))
		{
			char sValue[MAX_MESSAGE_LENGTH];

			kvRules.GetString("text", sValue, sizeof(sValue));
			if(strlen(sValue) > 0)
			{
				CPrintToChat(client, sValue);
				ShowRules(client, 0);

				g_bKnowRules[client] = false;
				g_bReadRules[client] = true;

				delete kvRules;
				delete menu;

				return 0;
			}

			kvRules.GetString("fakecommand", sValue, sizeof(sValue));
			if(strlen(sValue) > 0)
			{
				FakeClientCommand(client, sValue);

				g_bKnowRules[client] = false;
				g_bReadRules[client] = true;

				delete kvRules;
				delete menu;

				return 0;
			}

			kvRules.GetString("command", sValue, sizeof(sValue));
			if(strlen(sValue) > 0)
			{
				ClientCommand(client, sValue);

				g_bKnowRules[client] = false;
				g_bReadRules[client] = true;

				delete kvRules;
				delete menu;

				return 0;
			}

			kvRules.GetString("url", sValue, sizeof(sValue));
			if(strlen(sValue) > 0)
			{
				char sURL[512];
				Format(sURL, sizeof(sURL), "http://claninspired.com/franug/webshortcuts2.php?web=height=720,width=1280;franug_is_pro;%s", sValue);
				ShowMOTDPanel(client, "TTT Rules", sURL, MOTDPANEL_TYPE_URL);

				g_bKnowRules[client] = false;
				g_bReadRules[client] = true;

				delete kvRules;
				delete menu;

				return 0;
			}

			kvRules.GetString("file", sValue, sizeof(sValue));
			if(strlen(sValue) > 0)
			{
				g_iSite[client] = menu.Selection;

				char sFile[PLATFORM_MAX_PATH + 1];
				BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/rules/%s", sValue);

				Handle hRFile = OpenFile(sFile, "rt");

				if(hRFile == null)
					SetFailState("[TTT] Can't open File: %s", sFile);

				char sLine[64], sTitle[64];

				Menu rMenu = new Menu(Menu_RulesPage);

				kvRules.GetString("title", sTitle, sizeof(sTitle));
				rMenu.SetTitle(sTitle);

				while(!IsEndOfFile(hRFile) && ReadFileLine(hRFile, sLine, sizeof(sLine)))
				{
					if(strlen(sLine) > 1)
					{
						rMenu.AddItem("", sLine, ITEMDRAW_DISABLED);
					}
				}

				rMenu.ExitButton = false;
				rMenu.ExitBackButton = true;
				rMenu.Display(client, g_iConfig[i_timeToReadRules]);

				delete hRFile;
				delete kvRules;
				delete menu;

				return 0;
			}

			delete kvRules;
			delete menu;

			return 0;
		}

		if(g_iConfig[b_showDetectiveMenu])
			AskClientForMicrophone(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(TTT_IsClientValid(client) && g_iConfig[i_rulesClosePunishment] == 0)
		{
			char sFlags[16];
			AdminFlag aFlags[16];

			Format(sFlags, sizeof(sFlags), g_iConfig[s_kickImmunity]);
			FlagBitsToArray(ReadFlagString(sFlags), aFlags, sizeof(aFlags));

			if (!TTT_HasFlags(client, aFlags))
			{
				char sMessage[128];
				Format(sMessage, sizeof(sMessage), "%T", "WM Kick Message", client);
				KickClient(client, sMessage);
			}
		}
	}
	else if (action == MenuAction_End)
		if(menu != null)
			delete menu;

	return 0;
}

public int Menu_RulesPage(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Cancel || action == MenuAction_Select || param == MenuCancel_ExitBack)
		ShowRules(client, 0);
	else if (action == MenuAction_End)
		delete menu;
	return 0;
}

public Action Timer_ShowDetectiveMenu(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if(TTT_IsClientValid(client))
	{
		AskClientForMicrophone(client);
	}
}

stock void AskClientForMicrophone(int client)
{
	char sText[512], sYes[64], sNo[64];
	Format(sText, sizeof(sText), "%T", "AM Question", client);
	Format(sYes, sizeof(sYes), "%T", "AM Yes", client);
	Format(sNo, sizeof(sNo), "%T", "AM No", client);

	Menu menu = new Menu(Menu_AskClientForMicrophone);
	menu.SetTitle(sText);
	menu.AddItem("no", sNo);
	menu.AddItem("yes", sYes);
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, g_iConfig[i_timeToReadDetectiveRules]);
}


public int Menu_AskClientForMicrophone(Menu menu, MenuAction action, int client, int param)
{
	if ( action == MenuAction_Select )
	{
		char sParam[32];
		GetMenuItem(menu, param, sParam, sizeof(sParam));

		if (!StrEqual(sParam, "yes", false))
			g_bConfirmDetectiveRules[client] = false;
		else
			g_bConfirmDetectiveRules[client] = true;
	}
	else if(action == MenuAction_Cancel)
		g_bConfirmDetectiveRules[client] = false;
	else if (action == MenuAction_End)
		delete menu;

	return 0;
}

public void OnClientDisconnect(int client)
{
	if(IsClientInGame(client))
	{
		g_bKarma[client] = false;

		ClearTimer(g_hRDMTimer[client]);
		ClearIcon(client);

		ClearTimer(g_hJihadBomb[client]);

		g_bReceivingLogs[client] = false;
		g_bImmuneRDMManager[client] = false;
	/* 	int iSize = GetArraySize(g_hRagdollArray);

		if(iSize == 0) return;

		int Items[Ragdolls];

		for(int i = 0;i < GetArraySize(g_hRagdollArray);i++)
		{
			GetArrayArray(g_hRagdollArray, i, Items[0]);

			if(client == Items[attacker] || client == Items[victim])
			{
				int entity = EntRefToEntIndex(Items[index]);
				if(entity != INVALID_ENT_REFERENCE) AcceptEntityInput(entity, "kill");

				RemoveFromArray(g_hRagdollArray, i);
				break;
			}
		}  */

		ClearTimer(g_hExplosionTimer[client]);
	}
}

public Action Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsClientInGame(client)) return;

	char userName[MAX_NAME_LENGTH];
	event.GetString("newname", userName, sizeof(userName));
	nameCheck(client, userName);

 	int iSize = GetArraySize(g_hRagdollArray);

	if(iSize == 0)
		return;

	int Items[Ragdolls];

	for(int i = 0;i < GetArraySize(g_hRagdollArray);i++)
	{
		GetArrayArray(g_hRagdollArray, i, Items[0]);

		if(client == Items[attacker])
		{
			Format(Items[attackerName], MAX_NAME_LENGTH, userName);
			SetArrayArray(g_hRagdollArray, i, Items[0]);
		}
		else if(client == Items[victim])
		{
			Format(Items[victimName], MAX_NAME_LENGTH, userName);
			SetArrayArray(g_hRagdollArray, i, Items[0]);
		}
	}
}

public Action Timer_Adjust(Handle timer)
{
	int g_iInnoAlive = 0;
	int g_iTraitorAlive = 0;
	int g_iDetectiveAlive = 0;
	int[] c4clients = new int[MaxClients];
	int c4index = 0;

	float vec[3];
	LoopValidClients(i)
		if(IsPlayerAlive(i))
		{
			if(g_iRole[i] == TTT_TEAM_TRAITOR)
			{
				if(g_iConfig[b_C4Beam]){
					c4clients[c4index] = i;
					c4index++;
				}

				GetClientAbsOrigin(i, vec);

				vec[2] += 10;
				g_iTraitorAlive++;
				int[] clients = new int[MaxClients];
				int index = 0;

				LoopValidClients(j)
					if(IsPlayerAlive(j) && j != i && (g_iRole[j] == TTT_TEAM_TRAITOR))
					{
						clients[index] = j;
						index++;
					}

				TE_SetupBeamRingPoint(vec, 50.0, 60.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.1, 10.0, 0.0, {0, 0, 255, 255}, 10, 0);
				TE_Send(clients, index);
			}
			else if(g_iRole[i] == TTT_TEAM_INNOCENT)
				g_iInnoAlive++;
			else if(g_iRole[i] == TTT_TEAM_DETECTIVE)
				g_iDetectiveAlive++;

			int money = GetEntData(i, g_iAccount);
			if(money != 16000)
				SetEntData(i, g_iAccount, 16000);
		}


	if(g_iConfig[b_C4Beam] && (c4index > 0)){
		char sModelPath[PLATFORM_MAX_PATH];
		float origin[3]; int C4;
		while ((C4 = FindEntityByClassname(C4, "prop_physics")) != -1){
			GetEntPropString(C4, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

			if(!StrEqual(MDL_C4, sModelPath))
				continue;

			GetEntPropVector(C4, Prop_Send, "m_vecOrigin", origin);

			TE_SetupBeamRingPoint(origin, 40.0, 50.0, g_iC4BeamSprite, g_iHaloSprite, 0, 15, 0.1, 10.0, 0.0, {0, 0, 255, 255}, 10, 0);
			TE_Send(c4clients, c4index);
		}
	}

	if(g_bRoundStarted)
	{
		if(g_iInnoAlive == 0 && ((g_iConfig[b_endwithD]) || (g_iDetectiveAlive == 0)))
		{
			g_bRoundStarted = false;
			CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
		}
		else if(g_iTraitorAlive == 0)
		{
			g_bRoundStarted = false;
			CS_TerminateRound(7.0, CSRoundEnd_CTWin);
		}
	}
}

public Action Command_Credits(int client, int args)
{
	if (!TTT_IsClientValid(client))
		return Plugin_Handled;

	CPrintToChat(client, g_iConfig[s_pluginTag], "Your credits is", client, g_iCredits[client]);

	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!TTT_IsClientValid(client))
		return;

	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!TTT_IsClientValid(iAttacker) || iAttacker == client)
		return;

	if (g_iConfig[b_showDeathMessage])
	{
		if(g_iRole[iAttacker] == TTT_TEAM_TRAITOR)
			CPrintToChat(client, g_iConfig[s_pluginTag], "Your killer is a Traitor", client);
		else if(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE)
			CPrintToChat(client, g_iConfig[s_pluginTag], "Your killer is a Detective", client);
		else if(g_iRole[iAttacker] == TTT_TEAM_INNOCENT)
			CPrintToChat(client, g_iConfig[s_pluginTag], "Your killer is an Innocent", client);
	}

	if(g_iConfig[b_showKillMessage])
	{
		if(g_iRole[client] == TTT_TEAM_TRAITOR)
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "You killed a Traitor", client);
		else if(g_iRole[client] == TTT_TEAM_DETECTIVE)
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "You killed a Detective", client);
		else if(g_iRole[client] == TTT_TEAM_INNOCENT)
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "You killed an Innocent", client);
	}

	char item[512];

	if(g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) killed %N (Innocent)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		subtractKarma(iAttacker, g_iConfig[i_karmaII], true);
		subtractCredits(iAttacker, g_iConfig[i_creditsII], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) killed %N (Traitor)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		addKarma(iAttacker, g_iConfig[i_karmaIT], true);
		addCredits(iAttacker, g_iConfig[i_creditsIT], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) killed %N (Detective)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		subtractKarma(iAttacker, g_iConfig[i_karmaID], true);
		subtractCredits(iAttacker, g_iConfig[i_creditsID], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) killed %N (Innocent)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		addKarma(iAttacker, g_iConfig[i_karmaTI], true);
		addCredits(iAttacker, g_iConfig[i_creditsTI], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) killed %N (Traitor)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		subtractKarma(iAttacker, g_iConfig[i_karmaTT], true);
		subtractCredits(iAttacker, g_iConfig[i_creditsTT], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) killed %N (Detective)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		addKarma(iAttacker, g_iConfig[i_karmaTD], true);
		addCredits(iAttacker, g_iConfig[i_creditsTD], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(item, sizeof(item), "-> [%N (Detective) killed %N (Innocent)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		subtractKarma(iAttacker, g_iConfig[i_karmaDI], true);
		subtractCredits(iAttacker, g_iConfig[i_creditsDI], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(item, sizeof(item), "-> [%N (Detective) killed %N (Traitor)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		addKarma(iAttacker, g_iConfig[i_karmaDT], true);
		addCredits(iAttacker, g_iConfig[i_creditsDT], true);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(item, sizeof(item), "-> [%N (Detective) killed %N (Detective)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);

		subtractKarma(iAttacker, g_iConfig[i_karmaDD], true);
		subtractCredits(iAttacker, g_iConfig[i_creditsDD], true);
	}

	if(g_iRole[client] == TTT_TEAM_UNASSIGNED)
	{
	    CS_SetClientClanTag(client, "UNASSIGNED");
	    g_bFound[client] = true;
	}

	Call_StartForward(g_hOnClientDeath);
	Call_PushCell(client);
	Call_PushCell(iAttacker);
	Call_Finish();
}

stock int CreateIcon(int client)
{

	ClearIcon(client);
	if(g_iRole[client] < TTT_TEAM_TRAITOR || !g_bRoundStarted)
		return 0;

	char iTarget[16];
	Format(iTarget, 16, "client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float origin[3];

	GetClientAbsOrigin(client, origin);
	origin[2] = origin[2] + 80.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	if(g_iRole[client] == TTT_TEAM_DETECTIVE) DispatchKeyValue(Ent, "model", "sprites/sg_detective_icon.vmt");
	else if(g_iRole[client] == TTT_TEAM_TRAITOR) DispatchKeyValue(Ent, "model", "sprites/sg_traitor_icon.vmt");
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.08");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent);

	if(g_iRole[client] == TTT_TEAM_TRAITOR)
		SDKHook(Ent, SDKHook_SetTransmit, Hook_SetTransmitT);
	return Ent;
}

public Action Hook_SetTransmitT(int entity, int client)
{
	if (entity != client && g_iRole[client] != TTT_TEAM_TRAITOR && IsPlayerAlive(client))
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnMapEnd()
{
	if (g_hRoundTimer != null)
	{
		CloseHandle(g_hRoundTimer);
		g_hRoundTimer = null;
	}

	g_hStartTimer = null;
	g_hCountdownTimer = null;

	resetPlayers();

	LoopValidClients(i)
		g_bKarma[i] = false;
}

public Action Timer_OnRoundEnd(Handle timer)
{
	g_hRoundTimer = null;
	g_bRoundStarted = false;
	CS_TerminateRound(7.0, CSRoundEnd_CTWin);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	if(g_bRoundStarted)
		return Plugin_Handled;

	LoopValidClients(client){
		if(IsPlayerAlive(client))
			ClearIcon(client);

		if((!g_iConfig[b_publicKarma]) && g_iConfig[b_karmaRound]){
			CS_SetClientContributionScore(client, g_iKarma[client]);
			CPrintToChat(i, g_iConfig[s_pluginTag], "All karma score updated", client);
		}
	}

	bool bInnoAlive = false;

	if(reason == CSRoundEnd_CTWin)
	{
		LoopValidClients(client)
		{
			if(g_iRole[client] != TTT_TEAM_TRAITOR && g_iRole[client] != TTT_TEAM_UNASSIGNED)
			{
				if(IsPlayerAlive(client))
				{
					if(g_iRole[client] == TTT_TEAM_INNOCENT)
						bInnoAlive = true;

					addCredits(client, g_iConfig[i_traitorloseAliveNonTraitors]);
				}
				else
					addCredits(client, g_iConfig[i_traitorloseDeadNonTraitors]);
			}
		}
	}
	else if(reason == CSRoundEnd_TerroristWin)
	{
		LoopValidClients(client)
		{
			if(g_iRole[client] == TTT_TEAM_TRAITOR)
			{
				if(IsPlayerAlive(client))
					addCredits(client, g_iConfig[i_traitorwinAliveTraitors]);
				else
					addCredits(client, g_iConfig[i_traitorwinDeadTraitors]);
			}
		}
	}

	if(reason == CSRoundEnd_TerroristWin)
		ShowOverlayToAll("overlays/ttt/traitors_win");
	else if(reason == CSRoundEnd_CTWin && bInnoAlive)
		ShowOverlayToAll("overlays/ttt/innocents_win");
	else if(reason == CSRoundEnd_CTWin && (!bInnoAlive) && (!g_iConfig[b_endwithD]))
		ShowOverlayToAll("overlays/ttt/detectives_win");

	if(g_iConfig[b_randomWinner])
	    reason = view_as<CSRoundEndReason>(GetRandomInt(view_as<int>(CSRoundEnd_CTWin), view_as<int>(CSRoundEnd_TerroristWin)));

	if(g_iConfig[f_roundDelay] > 0.0)
		delay = g_iConfig[f_roundDelay];

	if(g_iConfig[b_nextRoundAlert])
		CPrintToChatAll(g_iConfig[s_pluginTag], "next round in", delay);

	return Plugin_Changed;
}

public Action Event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iConfig[b_hideTeams] && (!event.GetBool("silent")))
	{
		event.BroadcastDisabled = true;
		dontBroadcast = true;
	}

	return Plugin_Changed;
}

stock void ShowOverlayToClient(int client, const char[] overlaypath)
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

stock void ShowOverlayToAll(const char[] overlaypath)
{
	LoopValidClients(i)
		if(!IsFakeClient(i))
			ShowOverlayToClient(i, overlaypath);
}

stock void StripAllWeapons(int client)
{
	if(!g_iConfig[b_stripWeapons])
		return;

	int iEnt;
	for (int i = CS_SLOT_PRIMARY; i <= CS_SLOT_C4; i++)
	{
		while ((iEnt = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, iEnt);
			AcceptEntityInput(iEnt, "Kill");
		}
	}
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!iAttacker)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));


	int damage = event.GetInt("dmg_health");
	char item[512];
	if(g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) damaged %N (Innocent) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) damaged %N (Traitor) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) damaged %N (Detective) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) damaged %N (Innocent) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);

	}
	else if(g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) damaged %N (Traitor) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);

	}
	else if(g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) damaged %N (Detective) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(item, sizeof(item), "-> [%N (Detective) damaged %N (Innocent) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);

	}
	else if(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(item, sizeof(item), "-> [%N (Detective) damaged %N (Traitor) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(item, sizeof(item), "-> [%N (Detective) damaged %N (Detective) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
}

public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_iConfig[b_removeBomb])
		return Plugin_Continue;

	char sItem[32];
	event.GetString("item", sItem, sizeof(sItem));
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(TTT_IsClientValid(client))
	{
		if(!g_bHasC4[client] && !g_bJihadBomb[client])
		{
			int iC4 = GetPlayerWeaponSlot(client, CS_SLOT_C4);
			if(iC4 != -1)
			{
				RemovePlayerItem(client, iC4);
				AcceptEntityInput(iC4, "Kill");
			}

			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsClientInGame(client))
		return Plugin_Continue;

	if (g_iConfig[b_denyFire] && g_iRole[client] == TTT_TEAM_UNASSIGNED && ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)))
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		return Plugin_Changed;
	}

	if(buttons & IN_USE)
	{
		g_bHoldingProp[client] = true;

		int entidad = GetClientAimTarget(client, false);
		if(entidad > 0)
		{
			float OriginG[3], TargetOriginG[3];
			GetClientEyePosition(client, TargetOriginG);
			GetEntPropVector(entidad, Prop_Data, "m_vecOrigin", OriginG);
			if(GetVectorDistance(TargetOriginG,OriginG, false) > 90.0)
				return Plugin_Continue;

		 	int iSize = GetArraySize(g_hRagdollArray);
			if(iSize == 0)
				return Plugin_Continue;

			int Items[Ragdolls];
			int entity;

			for(int i = 0;i < iSize;i++)
			{
				GetArrayArray(g_hRagdollArray, i, Items[0]);
				entity = EntRefToEntIndex(Items[ent]);

				if(entity == entidad)
				{
					MostrarMenu(client, Items[victim], Items[attacker], RoundToNearest(GetGameTime()-Items[gameTime]), Items[weaponused], Items[victimName], Items[attackerName]);

					if(!Items[found] && IsPlayerAlive(client))
					{
						Items[found] = true;
						if(IsClientInGame(Items[victim]))
							g_bFound[Items[victim]] = true;

						if(g_iRole[Items[victim]] == TTT_TEAM_INNOCENT)
						{
							LoopValidClients(j)
								CPrintToChat(j, g_iConfig[s_pluginTag], "Found Innocent", j, client, Items[victimName]);
							SetEntityRenderColor(entidad, 0, 255, 0, 255);
						}
						else if(g_iRole[Items[victim]] == TTT_TEAM_DETECTIVE)
						{
							LoopValidClients(j)
								CPrintToChat(j, g_iConfig[s_pluginTag], "Found Detective", j, client, Items[victimName]);
							SetEntityRenderColor(entidad, 0, 0, 255, 255);
						}
						else if(g_iRole[Items[victim]] == TTT_TEAM_TRAITOR)
						{
							LoopValidClients(j)
								CPrintToChat(j, g_iConfig[s_pluginTag], "Found Traitor", j, client,Items[victimName]);
							SetEntityRenderColor(entidad, 255, 0, 0, 255);
						}

						TeamTag(Items[victim]);

						Call_StartForward(g_hOnBodyFound);
						Call_PushCell(client);
						Call_PushCell(Items[victim]);
						Call_PushString(Items[victimName]);
						Call_Finish();

						addCredits(client, g_iConfig[i_creditsFoundBody]);
					}

					if(g_bScan[client] && !Items[scanned] && IsPlayerAlive(client))
					{
						Call_StartForward(g_hOnBodyScanned);
						Call_PushCell(client);
						Call_PushCell(Items[victim]);
						Call_PushString(Items[victimName]);
						Call_Finish();

						Items[scanned] = true;
						if(Items[attacker] > 0 && Items[attacker] != Items[victim])
						{
							LoopValidClients(j)
								CPrintToChat(j, g_iConfig[s_pluginTag], "Detective scan found body", j, client, Items[attackerName], Items[weaponused]);
						}
						else
						{
							LoopValidClients(j)
								CPrintToChat(j, g_iConfig[s_pluginTag], "Detective scan found body suicide", j, client);
						}
					}
					SetArrayArray(g_hRagdollArray, i, Items[0]);

					break;
				}
			}
		}
	}
	else g_bHoldingProp[client] = false;

	if (buttons & IN_RELOAD && g_iDefusePlayerIndex[client] == -1)
	{
		int target = GetClientAimTarget(client, false);
		if (target > 0)
		{
			float clientEyes[3], targetOrigin[3];
			GetClientEyePosition(client, clientEyes);
			GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetOrigin);
			if (GetVectorDistance(clientEyes, targetOrigin) > 100.0)
				return Plugin_Continue;

			int iEnt;
			while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
			{
				int planter = GetEntProp(target, Prop_Send, "m_hOwnerEntity");

				if (planter < 1 || planter > MaxClients || !IsClientInGame(planter))
					return Plugin_Continue;

				char sModelPath[PLATFORM_MAX_PATH];
				GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

				if(!StrEqual(MDL_C4, sModelPath))
					return Plugin_Continue;

				if (target == iEnt)
				{
					g_iDefusePlayerIndex[client] = planter;
					showDefuseMenu(client);
				}
			}
		}
	}

	if (buttons & IN_ATTACK2 && !g_bHasActiveBomb[client] && g_bHasC4[client])
	{
		g_bHasActiveBomb[client] = true;
		int bombEnt = CreateEntityByName("prop_physics");
		if (bombEnt != -1)
		{
			float clientPos[3];
			GetClientAbsOrigin(client, clientPos);
			SetEntProp(bombEnt, Prop_Data, "m_CollisionGroup", 1);
			SetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity", client);
			DispatchKeyValue(bombEnt, "model", MDL_C4);
			DispatchSpawn(bombEnt);
			TeleportEntity(bombEnt, clientPos, NULL_VECTOR, NULL_VECTOR);
			showPlantMenu(client);
		}
	}
	return Plugin_Continue;
}

public Action Command_ID(int client, int args)
{
	if (!TTT_IsClientValid(client))
		return Plugin_Handled;

	if(g_bID[client] && IsPlayerAlive(client))
	{
		LoopValidClients(i)
			CPrintToChat(i, g_iConfig[s_pluginTag], "Player Is an Innocent", i, client);
	}
	else
		CPrintToChat(client, g_iConfig[s_pluginTag], "You dont have it!", client);

	return Plugin_Handled;

}

public Action Command_Say(int client, const char[] command, int argc)
{
	if(!TTT_IsClientValid(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	char sText[MAX_MESSAGE_LENGTH];
	GetCmdArgString(sText, sizeof(sText));

	StripQuotes(sText);

	if (sText[0] == '@')
		return Plugin_Continue;

	for (int i = 0; i < sizeof(g_sShopCMDs); i++)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "!%s", g_sShopCMDs[i]);

		if (StrEqual(sText, sBuffer, false))
			return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Command_SayTeam(int client, const char[] command, int argc)
{
	if(!TTT_IsClientValid(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	char sText[MAX_MESSAGE_LENGTH];
	GetCmdArgString(sText, sizeof(sText));

	StripQuotes(sText);

	if(strlen(sText) < 2)
		return Plugin_Handled;

	if (sText[0] == '@')
		return Plugin_Continue;

	for (int i = 0; i < sizeof(g_sShopCMDs); i++)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "!%s", g_sShopCMDs[i]);

		if (StrEqual(sText, sBuffer, false))
			return Plugin_Handled;
	}

	if(g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		LoopValidClients(i)
			if(TTT_IsClientValid(i) && (g_iRole[i] == TTT_TEAM_TRAITOR || !IsPlayerAlive(i)))
			{
				EmitSoundToClient(i, SND_TCHAT);
				CPrintToChat(i, "%T", "T channel", i, client, sText);
			}

		return Plugin_Handled;
	}
	else if(g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		LoopValidClients(i)
			if(TTT_IsClientValid(i) && (g_iRole[i] == TTT_TEAM_DETECTIVE || !IsPlayerAlive(i)))
			{
				EmitSoundToClient(i, SND_TCHAT);
				CPrintToChat(i, "%T", "D channel", i, client, sText);
			}

		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_Shop(int client, int args)
{
	if(!TTT_IsClientValid(client))
		return Plugin_Handled;

	int team = g_iRole[client];
	if(team != TTT_TEAM_UNASSIGNED)
	{
		char MenuItem[128];
		Handle menu = CreateMenu(Menu_ShopHandler);
		SetMenuTitle(menu, "%T", "TTT Shop", client);


		if(team == TTT_TEAM_TRAITOR)
		{
			if(g_iConfig[i_shopC4] > 0)
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "Buy c4", client, g_iConfig[i_shopC4]);
				AddMenuItem(menu, "C4", MenuItem);
			}

			if(g_iConfig[i_shopJIHADBOMB] > 0)
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "Buy jihadbomb", client, g_iConfig[i_shopJIHADBOMB]);
				AddMenuItem(menu, "jbomb", MenuItem);
			}

			if(g_iConfig[i_shopFAKEID] > 0)
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "FAKE ID card (type !id for show your innocence)", client, g_iConfig[i_shopFAKEID]);
				AddMenuItem(menu, "fakeID", MenuItem);
			}

		}
		if(team == TTT_TEAM_DETECTIVE)
		{
			if(g_iConfig[i_shopDNA] > 0)
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "DNA scanner (scan a dead body and show who the killer is)", client, g_iConfig[i_shopDNA]);
				AddMenuItem(menu, "scan13", MenuItem);
			}
		}
		if(team == TTT_TEAM_INNOCENT)
		{
			if(g_iConfig[i_shopT] > 0)
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "Buy rol Traitor", client, g_iConfig[i_shopT]);
				AddMenuItem(menu, "buyT", MenuItem);
			}

			if(g_iConfig[i_shopD] > 0 && (g_bConfirmDetectiveRules[client] || !g_iConfig[b_showDetectiveMenu]))
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "Buy rol Detective", client, g_iConfig[i_shopD]);
				AddMenuItem(menu, "buyD", MenuItem);
			}

			if(g_iConfig[i_shopID] > 0)
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "ID card (type !id for show your innocence)", client, g_iConfig[i_shopID]);
				AddMenuItem(menu, "ID", MenuItem);
			}
		}

		if(g_iConfig[b_taserAllow])
		{
			if(g_iConfig[i_shopTASER] > 0)
			{
				Format(MenuItem, sizeof(MenuItem),"%T", "Taser", client, g_iConfig[i_shopTASER]);
				AddMenuItem(menu, "taser", MenuItem);
			}
		}

		char display[128];
		for(int i = 0; i < g_iCustomItemCount; i++)
		{
			if(strlen(g_cCustomItems_Short[i]) > 1)
			{
				if((g_iCustomItems_Role[i] == 0) || (g_iCustomItems_Role[i] == team))
				{
					Format(display, sizeof(display), "%s - %d", g_cCustomItems_Long[i], g_iCustomItems_Price[i]);
					AddMenuItem(menu, g_cCustomItems_Short[i], display);
				}
			}
		}

		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 15);

	}
	else
		CPrintToChat(client, g_iConfig[s_pluginTag], "Please wait till your team is assigned", client);

	return Plugin_Handled;

}

public int Menu_ShopHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select )
	{
		if(!IsPlayerAlive(client)) return;
		char info[32];

		GetMenuItem(menu, itemNum, info, sizeof(info));
		if ( strcmp(info,"scan13") == 0 )
		{
			if(g_iCredits[client] >= g_iConfig[i_shopDNA])
			{
				g_bScan[client] = true;
				subtractCredits(client, g_iConfig[i_shopDNA]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else if ( strcmp(info,"ID") == 0 )
		{
			if(g_iCredits[client] >= g_iConfig[i_shopID])
			{
				g_bID[client] = true;
				subtractCredits(client, g_iConfig[i_shopID]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else if ( strcmp(info,"fakeID") == 0 )
		{
			if(g_iCredits[client] >= g_iConfig[i_shopFAKEID])
			{
				g_bID[client] = true;
				subtractCredits(client, g_iConfig[i_shopFAKEID]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else if ( strcmp(info,"buyT") == 0 )
		{
			if(g_iCredits[client] >= g_iConfig[i_shopT])
			{
				g_iRole[client] = TTT_TEAM_TRAITOR;
				TeamInitialize(client);
				subtractCredits(client, g_iConfig[i_shopT]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else if ( strcmp(info,"buyD") == 0 )
		{
			if(g_iCredits[client] >= g_iConfig[i_shopD])
			{
				g_iRole[client] = TTT_TEAM_DETECTIVE;
				TeamInitialize(client);
				subtractCredits(client, g_iConfig[i_shopD]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else if ( strcmp(info,"taser") == 0 )
		{
			if(g_iCredits[client] >= g_iConfig[i_shopTASER] && g_iConfig[b_taserAllow])
			{
				GivePlayerItem(client, "weapon_taser");
				subtractCredits(client, g_iConfig[i_shopTASER]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else if ( strcmp(info,"jbomb") == 0 )
		{
			if(g_iCredits[client] >= g_iConfig[i_shopJIHADBOMB])
			{
				if (g_iRole[client] != TTT_TEAM_TRAITOR)
					return;
				g_bJihadBomb[client] = true;
				ClearTimer(g_hJihadBomb[client]);
				g_hJihadBomb[client] = CreateTimer(g_iConfig[f_jihadPreparingTime], Timer_JihadPreparing, client);
				subtractCredits(client, g_iConfig[i_shopJIHADBOMB]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "bomb will arm in 60 seconds, double tab F to explode", client);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else if (strcmp(info, "C4") == 0)
		{
			if (g_iCredits[client] >= g_iConfig[i_shopC4])
			{
				if (g_iRole[client] != TTT_TEAM_TRAITOR)
					return;
				g_bHasC4[client] = true;
				subtractCredits(client, g_iConfig[i_shopC4]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
				CPrintToChat(client, g_iConfig[s_pluginTag], "Right click to plant the C4", client);
			}
			else CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
		}
		else
		{
			for(int i = 0; i < g_iCustomItemCount; i++)
			{
				if((strlen(g_cCustomItems_Short[i]) > 0) && (strcmp(info, g_cCustomItems_Short[i]) == 0))
				{
					if((g_iCredits[client] >= g_iCustomItems_Price[i]) && ((g_iCustomItems_Role[i] == 0) || (g_iRole[client] == g_iCustomItems_Role[i])))
					{
						Action res = Plugin_Continue;
						Call_StartForward(g_hOnItemPurchased);
						Call_PushCell(client);
						Call_PushString(g_cCustomItems_Short[i]);
						Call_Finish(res);

						if(res < Plugin_Stop){
							subtractCredits(client, g_iCustomItems_Price[i]);
							CPrintToChat(client, g_iConfig[s_pluginTag], "Item bought! Your REAL money is", client, g_iCredits[client]);
						}
					}
					else
						CPrintToChat(client, g_iConfig[s_pluginTag], "You don't have enough money", client);
				}
			}
		}
	}

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action Timer_JihadPreparing(Handle timer, any client)
{
	CPrintToChat(client, g_iConfig[s_pluginTag], "Your bomb is now armed.", client);
	EmitAmbientSound(SND_BLIP, NULL_VECTOR, client);
	g_hJihadBomb[client] = null;
}

stock void MostrarMenu(int client, int victima2, int atacante2, int tiempo2, const char[] weapon, const char[] victimaname2, const char[] atacantename2)
{
	char team[32];
	if(g_iRole[victima2] == TTT_TEAM_TRAITOR)
		Format(team, sizeof(team), "%T", "Traitors", client);
	else if(g_iRole[victima2] == TTT_TEAM_DETECTIVE)
		Format(team, sizeof(team), "%T", "Detectives", client);
	else if(g_iRole[victima2] == TTT_TEAM_INNOCENT)
		Format(team, sizeof(team), "%T", "Innocents", client);

	Handle menu = CreateMenu(BodyMenuHandler);
	char Item[128];

	SetMenuTitle(menu, "%T", "Inspected body. The extracted data are the following", client);

	Format(Item, sizeof(Item), "%T", "Victim name", client, victimaname2);
	AddMenuItem(menu, "", Item);

	Format(Item, sizeof(Item), "%T", "Team victim", client, team);
	AddMenuItem(menu, "", Item);

	if(g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(Item, sizeof(Item), "%T", "Elapsed since his death", client, tiempo2);
		AddMenuItem(menu, "", Item);

		if(atacante2 > 0 && atacante2 != victima2)
		{
			Format(Item, sizeof(Item), "%T", "The weapon used has been", client, weapon);
			AddMenuItem(menu, "", Item);
		}
		else
		{
			Format(Item, sizeof(Item), "%T", "The weapon used has been: himself (suicide)", client);
			AddMenuItem(menu, "", Item);
		}
	}

	if(g_bScan[client])
	{
		if(atacante2 > 0 && atacante2 != victima2)
			Format(Item, sizeof(Item), "%T", "Killer is Player",client, atacantename2);
		else
			Format(Item, sizeof(Item), "%T", "Player committed suicide", client);

		AddMenuItem(menu, "", Item);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);

}

public int BodyMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
		delete menu;
}

stock void ClearIcon(int client)
{
	if(g_iIcon[client] > 0 && IsValidEdict(g_iIcon[client]))
	{
		if(g_iRole[client] == TTT_TEAM_TRAITOR) SDKUnhook(g_iIcon[client], SDKHook_SetTransmit, Hook_SetTransmitT);
		AcceptEntityInput(g_iIcon[client], "Kill");
	}
	ShowOverlayToClient(client, " ");
	g_iIcon[client] = 0;

}

stock void addKarma(int client, int karma, bool message = false)
{
	g_iKarma[client] += karma;

	if(g_iKarma[client] > g_iConfig[i_maxKarma])
		g_iKarma[client] = g_iConfig[i_maxKarma];

	if (g_iConfig[b_showEarnKarmaMessage] && message)
	{
		if(g_iConfig[i_messageTypKarma] == 1)
	  		PrintHintText(client, "%T", "karma earned", client, karma, g_iKarma[client]);
	  	else
	  		CPrintToChat(client, g_iConfig[s_pluginTag], "karma earned", client, karma, g_iKarma[client]);
	}

	UpdateKarma(client, g_iKarma[client]);
}

stock void setKarma(int client, int karma)
{
	g_iKarma[client] = karma;

	if(g_iKarma[client] > g_iConfig[i_maxKarma])
		g_iKarma[client] = g_iConfig[i_maxKarma];

	UpdateKarma(client, g_iKarma[client]);
}

stock void subtractKarma(int client, int karma, bool message = false)
{
	g_iKarma[client] -= karma;

	if (g_iConfig[b_showLoseKarmaMessage] && message)
	{
		if(g_iConfig[i_messageTypKarma] == 1)
	  		PrintHintText(client, "%T", "lost karma", client, karma, g_iKarma[client]);
	  	else
	  		CPrintToChat(client, g_iConfig[s_pluginTag], "lost karma", client, karma, g_iKarma[client]);
	}

	UpdateKarma(client, g_iKarma[client]);
}

stock void UpdateKarma(int client, int karma)
{
	char sCommunityID[64];

	if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
		return;

	char sQuery[2048];
	Format(sQuery, sizeof(sQuery), "UPDATE `ttt` SET `karma`=%d WHERE `communityid`=\"%s\";", karma, sCommunityID);

	if(g_hDatabase != null)
		SQL_TQuery(g_hDatabase, Callback_Karma, sQuery, GetClientUserId(client));
}

stock void addCredits(int client, int credits, bool message = false)
{
	credits = RoundToNearest((credits) * (g_iKarma[client] * 0.01));
	int newcredits = g_iCredits[client] + credits;

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnCreditsGiven_Pre);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_PushCell(newcredits);
	Call_Finish(res);

	if(res > Plugin_Changed)
		return;

	g_iCredits[client] = newcredits;

	if (g_iConfig[b_showEarnCreditsMessage] && message)
	{
		if(g_iConfig[i_messageTypCredits] == 1)
		{
			char sBuffer[MAX_MESSAGE_LENGTH];
			Format(sBuffer, sizeof(sBuffer), "%T", "credits earned", client, credits, g_iCredits[client]);
			CFormatColor(sBuffer, sizeof(sBuffer), client);
			PrintHintText(client, sBuffer);
		}
		else
			CPrintToChat(client, g_iConfig[s_pluginTag], "credits earned", client, credits, g_iCredits[client]);
	}

	Call_StartForward(g_hOnCreditsGiven);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_Finish();
}

stock void subtractCredits(int client, int credits, bool message = false)
{
	int newcredits = g_iCredits[client] - credits;

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnCreditsGiven_Pre);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_PushCell(newcredits);
	Call_Finish(res);

	if(res > Plugin_Changed)
		return;

	g_iCredits[client] = newcredits;

	if(g_iCredits[client] < 0)
		g_iCredits[client] = 0;

	if (g_iConfig[b_showLoseCreditsMessage] && message)
	{
		if(g_iConfig[i_messageTypCredits] == 1)
		{
			char sBuffer[MAX_MESSAGE_LENGTH];
			Format(sBuffer, sizeof(sBuffer), "%T", "lost credits", client, credits, g_iCredits[client]);
			CFormatColor(sBuffer, sizeof(sBuffer), client);
			PrintHintText(client, sBuffer);
		}
		else
			CPrintToChat(client, g_iConfig[s_pluginTag], "lost credits", client, credits, g_iCredits[client]);
	}

	Call_StartForward(g_hOnCreditsGiven);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_Finish();
}

stock void setCredits(int client, int credits, bool message = false){
	g_iCredits[client] = credits;

	if(g_iCredits[client] < 0)
		g_iCredits[client] = 0;
}

stock void ClearTimer(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}

stock void Detonate(int client)
{
	int ExplosionIndex = CreateEntityByName("env_explosion");
	if (ExplosionIndex != -1)
	{
		SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 16384);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 1000);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 600);

		DispatchSpawn(ExplosionIndex);
		ActivateEntity(ExplosionIndex);

		float playerEyes[3];
		GetClientEyePosition(client, playerEyes);

		TeleportEntity(ExplosionIndex, playerEyes, NULL_VECTOR, NULL_VECTOR);
		SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", client);

		EmitAmbientSoundAny("ttt/jihad/explosion.mp3", NULL_VECTOR, client, SNDLEVEL_RAIDSIREN);


		AcceptEntityInput(ExplosionIndex, "Explode");

		AcceptEntityInput(ExplosionIndex, "Kill");
	}
	g_bJihadBomb[client] = false;
}

public Action Command_Detonate(int client, int args)
{
	if (!TTT_IsClientValid(client))
		return Plugin_Handled;

	if (!g_bJihadBomb[client])
	{
		CPrintToChat(client, g_iConfig[s_pluginTag], "You dont have it!", client);
		return Plugin_Handled;
	}

	if (g_hJihadBomb[client] != null)
	{
		CPrintToChat(client, g_iConfig[s_pluginTag], "Your bomb is not armed.", client);
		return Plugin_Handled;
	}

	EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client);

	CreateTimer(2.0, TimerCallback_Detonate, client);
	g_bJihadBomb[client] = false;

	return Plugin_Handled;
}

public Action TimerCallback_Detonate(Handle timer, any client)
{
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	Detonate(client);
	return Plugin_Handled;
}

public Action Command_LAW(int client, const char[] command, int argc)
{
	if(!TTT_IsClientValid(client))
		return Plugin_Continue;

	if(IsPlayerAlive(client) && g_bJihadBomb[client] && g_hJihadBomb[client] == null && g_bDetonate[client])
	{
		EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client);

		CreateTimer(2.0, TimerCallback_Detonate, client);
		g_bJihadBomb[client] = false;

		return Plugin_Continue;
	}
	else
	{
		g_bDetonate[client] = true;
		CreateTimer(2.0, PasarJ, client);
	}

	if(g_iConfig[b_allowFlash] && IsPlayerAlive(client))
	{
		EmitSoundToAllAny(SND_FLASHLIGHT, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);
		SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);
	}

	if(g_iConfig[b_blockLookAtWeapon])
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action PasarJ(Handle timer, any client)
{
	if(!client || !IsClientInGame(client))
		return Plugin_Handled;

	g_bDetonate[client] = false;
	return Plugin_Handled;
}

stock void manageRDM(int client)
{
	if (!IsClientInGame(client))
		return;

	int iAttacker = g_iRDMAttacker[client];
	if (!IsClientInGame(iAttacker) || iAttacker < 0 || iAttacker > MaxClients)
	{
		CPrintToChat(client, g_iConfig[s_pluginTag], "The player who RDM'd you is no longer available", client);
		return;
	}
	char sAttackerName[MAX_NAME_LENGTH];
	GetClientName(iAttacker, sAttackerName, sizeof(sAttackerName));

	char display[256], sForgive[64], sPunish[64];
	Format(display, sizeof(display), "%T", "You were RDM'd", client, sAttackerName);
	Format(sForgive, sizeof(sForgive), "%T", "Forgive", client);
	Format(sPunish, sizeof(sPunish), "%T", "Punish", client);

	Handle menuHandle = CreateMenu(manageRDMHandle);
	SetMenuTitle(menuHandle, display);
	AddMenuItem(menuHandle, "Forgive", sForgive);
	AddMenuItem(menuHandle, "Punish", sPunish);
	DisplayMenu(menuHandle, client, 10);
}

public int manageRDMHandle(Menu menu, MenuAction action, int client, int option)
{
	if (1 > client || client > MaxClients || !IsClientInGame(client))
		return;

	int iAttacker = g_iRDMAttacker[client];
	if (1 > iAttacker || iAttacker > MaxClients || !IsClientInGame(iAttacker))
		return;

	switch (action)
	{
		case MenuAction_Select:
		{
			char info[100];
			GetMenuItem(menu, option, info, sizeof(info));
			if (StrEqual(info, "Forgive", false))
			{
				CPrintToChat(client, g_iConfig[s_pluginTag], "Choose Forgive Victim", client, iAttacker);
				CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "Choose Forgive Attacker", iAttacker, client);
				g_iRDMAttacker[client] = -1;
			}
			if (StrEqual(info, "Punish", false))
			{
				LoopValidClients(i)
					CPrintToChat(i, g_iConfig[s_pluginTag], "Choose Punish", i, client, iAttacker);
				ServerCommand("sm_slay #%i 2", GetClientUserId(iAttacker));
				g_iRDMAttacker[client] = -1;
			}
		}
		case MenuAction_Cancel:
		{
			CPrintToChat(client, g_iConfig[s_pluginTag], "Choose Forgive Victim", client, iAttacker);
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "Choose Forgive Attacker", iAttacker, client);
			g_iRDMAttacker[client] = -1;
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
			CPrintToChat(client, g_iConfig[s_pluginTag], "Choose Forgive Victim", client, iAttacker);
			CPrintToChat(iAttacker, g_iConfig[s_pluginTag], "Choose Forgive Attacker", iAttacker, client);
			g_iRDMAttacker[client] = -1;
		}
	}
}

public Action Timer_RDMTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	g_hRDMTimer[client] = null;
	manageRDM(client);
	return Plugin_Stop;
}

public Action Command_SetRole(int client, int args)
{
	if(!TTT_IsClientValid(client))
		return Plugin_Handled;

	if (args < 2 || args > 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_role <#userid|name> <role>");
		ReplyToCommand(client, "[SM] Roles: 1 - Innocent | 2 - Traitor | 3 - Detective");
		return Plugin_Handled;
	}
	char arg1[32];
	char arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1);

	if (target == -1)
		return Plugin_Handled;

	if (!IsPlayerAlive(target))
	{
		ReplyToCommand(client, "[SM] This command can only be used to alive players!");
		return Plugin_Handled;
	}

	int role = StringToInt(arg2);
	if (role < 1 || role > 3)
	{
		ReplyToCommand(client, "[SM] Roles: 1 - Innocent | 2 - Traitor | 3 - Detective");
		return Plugin_Handled;
	}
	else if (role == TTT_TEAM_INNOCENT)
	{
		g_iRole[target] = TTT_TEAM_INNOCENT;
		TeamInitialize(target);
		ClearIcon(target);
		CS_SetClientClanTag(target, " ");
		CPrintToChat(client, g_iConfig[s_pluginTag], "Player is Now Innocent", client, target);
		return Plugin_Handled;
	}
	else if (role == TTT_TEAM_TRAITOR)
	{
		g_iRole[target] = TTT_TEAM_TRAITOR;
		TeamInitialize(target);
		ClearIcon(target);
		ApplyIcons();
		CS_SetClientClanTag(target, " ");
		CPrintToChat(client, g_iConfig[s_pluginTag], "Player is Now Traitor", client, target);
		return Plugin_Handled;
	}
	else if (role == TTT_TEAM_DETECTIVE && (g_bConfirmDetectiveRules[target] || !g_iConfig[b_showDetectiveMenu]))
	{
		g_iRole[target] = TTT_TEAM_DETECTIVE;
		TeamInitialize(target);
		ClearIcon(target);
		ApplyIcons();
		CPrintToChat(client, g_iConfig[s_pluginTag], "Player is Now Detective", client, target);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_SetKarma(int client, int args)
{
	if(!TTT_IsClientValid(client))
		return Plugin_Handled;

	if (args < 2 || args > 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setkarma <#userid|name> <karma>");

		return Plugin_Handled;
	}

	char arg1[32];
	char arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	int target = FindTarget(client, arg1);

	if (target == -1)
	{
		ReplyToCommand(client, "[SM] Invalid target.");
		return Plugin_Handled;
	}

	if(g_bKarma[client])
	{
		ReplyToCommand(client, "[SM] Player data not loaded yet.");
		return Plugin_Handled;
	}

	int karma = StringToInt(arg2);

	setKarma(client, karma);

	return Plugin_Continue;
}

public Action Command_SetCredits(int client, int args)
{
	if(!TTT_IsClientValid(client))
		return Plugin_Handled;

	if (args < 2 || args > 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setcredits <#userid|name> <credits>");

		return Plugin_Handled;
	}
	char arg1[32];
	char arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1);

	if (target == -1)
		return Plugin_Handled;

	int credits = StringToInt(arg2);

	setCredits(client, credits);

	return Plugin_Continue;
}

public Action Command_Status(int client, int args)
{
	if(!TTT_IsClientValid(client))
		return Plugin_Handled;

	if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
		CPrintToChat(client, g_iConfig[s_pluginTag], "You Are Unassigned", client);
	else if (g_iRole[client] == TTT_TEAM_INNOCENT)
		CPrintToChat(client, g_iConfig[s_pluginTag], "You Are Now Innocent", client);
	else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
		CPrintToChat(client, g_iConfig[s_pluginTag], "You Are Now Detective", client);
	else if (g_iRole[client] == TTT_TEAM_TRAITOR)
		CPrintToChat(client, g_iConfig[s_pluginTag], "You Are Now Traitor", client);

	return Plugin_Handled;
}

public Action Timer_5(Handle timer)
{
	LoopValidClients(i)
	{
		if (!IsPlayerAlive(i))
			continue;

		g_iIcon[i] = CreateIcon(i);

		if (g_iRole[i] == TTT_TEAM_DETECTIVE)
			ShowOverlayToClient(i, "darkness/ttt/overlayDetective");
		else if (g_iRole[i] == TTT_TEAM_TRAITOR)
			ShowOverlayToClient(i, "darkness/ttt/overlayTraitor");
		else if (g_iRole[i] == TTT_TEAM_INNOCENT)
			ShowOverlayToClient(i, "darkness/ttt/overlayInnocent");

		if(g_bKarma[i] && g_iConfig[i_karmaBan] != 0 && g_iKarma[i] <= g_iConfig[i_karmaBan])
			BanBadPlayerKarma(i);
	}

	if(g_bRoundStarted)
		CheckTeams();
}

#if SOURCEMOD_V_MAJOR >= 1 && (SOURCEMOD_V_MINOR >= 8 || SOURCEMOD_V_MINOR >= 7 && SOURCEMOD_V_RELEASE >= 2)
public void OnEntityCreated(int entity, const char[] name)
#else
public int OnEntityCreated(int entity, const char[] name)
#endif
{
	if (StrEqual(name, "func_button"))
	{
		char targetName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (StrEqual(targetName, "Destroy_Trigger", false))
			SDKHook(entity, SDKHook_Use, OnUse);
	}
	else
	{
		for (int i = 0; i < sizeof(g_sRemoveEntityList); i++)
		{
			if (!StrEqual(name, g_sRemoveEntityList[i]))
				continue;

			if(g_iConfig[b_removeBomb] && StrEqual("func_bomb_target", g_sRemoveEntityList[i], false))
				AcceptEntityInput(entity, "kill");
			else if(g_iConfig[b_removeBuyzone] && StrEqual("func_buyzone", g_sRemoveEntityList[i], false))
				AcceptEntityInput(entity, "kill");
			else if (g_iConfig[b_removeHostages])
				AcceptEntityInput(entity, "kill");

			break;
		}
	}
}

public Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
	if (activator < 1 || activator > MaxClients || !IsClientInGame(activator))
		return Plugin_Continue;

	if (g_bInactive)
		return Plugin_Handled;

	else
	{
		if (g_iRole[activator] == TTT_TEAM_INNOCENT || g_iRole[activator] == TTT_TEAM_DETECTIVE || g_iRole[activator] == TTT_TEAM_UNASSIGNED)
		{
			ServerCommand("sm_slay #%i 2", GetClientUserId(activator));

			LoopValidClients(i)
				CPrintToChat(i, g_iConfig[s_pluginTag], "Triggered Falling Building", i, activator);
		}
	}
	return Plugin_Continue;
}

public Action explodeC4(Handle timer, Handle pack)
{
	int clientUserId;
	int bombEnt;
	ResetPack(pack);
	clientUserId = ReadPackCell(pack);
	bombEnt = ReadPackCell(pack);

	if(!IsValidEntity(bombEnt))
		return Plugin_Stop;

	int client = GetClientOfUserId(clientUserId);
	float explosionOrigin[3];
	GetEntPropVector(bombEnt, Prop_Send, "m_vecOrigin", explosionOrigin);
	if (TTT_IsClientValid(client))
	{
		g_bHasActiveBomb[client] = false;
		g_hExplosionTimer[client] = null;
		g_bImmuneRDMManager[client] = true;
		CPrintToChat(client, g_iConfig[s_pluginTag], "Bomb Detonated", client);
	}
	else return Plugin_Stop;

	int explosionIndex = CreateEntityByName("env_explosion");
	int particleIndex = CreateEntityByName("info_particle_system");
	int shakeIndex = CreateEntityByName("env_shake");
	if (explosionIndex != -1 && particleIndex != -1 && shakeIndex != -1)
	{
		char sShakeRadius[8];
		IntToString(g_iConfig[i_c4ShakeRadius], sShakeRadius, sizeof(sShakeRadius));

		DispatchKeyValue(shakeIndex, "amplitude", "4");
		DispatchKeyValue(shakeIndex, "duration", "1");
		DispatchKeyValue(shakeIndex, "frequency", "2.5");
		DispatchKeyValue(shakeIndex, "radius", sShakeRadius);
		DispatchKeyValue(particleIndex, "effect_name", "explosion_c4_500");
		SetEntProp(explosionIndex, Prop_Data, "m_spawnflags", 16384);
		SetEntProp(explosionIndex, Prop_Data, "m_iRadiusOverride", 850);
		SetEntProp(explosionIndex, Prop_Data, "m_iMagnitude", 850);
		SetEntPropEnt(explosionIndex, Prop_Send, "m_hOwnerEntity", client);
		DispatchSpawn(particleIndex);
		DispatchSpawn(explosionIndex);
		DispatchSpawn(shakeIndex);
		ActivateEntity(shakeIndex);
		ActivateEntity(particleIndex);
		ActivateEntity(explosionIndex);
		TeleportEntity(particleIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(explosionIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(shakeIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(bombEnt, "Kill");
		AcceptEntityInput(explosionIndex, "Explode");
		AcceptEntityInput(particleIndex, "Start");
		AcceptEntityInput(shakeIndex, "StartShake");
		AcceptEntityInput(explosionIndex, "Kill");

		LoopValidClients(i)
		{
			if (!IsPlayerAlive(i))
				continue;

			float clientOrigin[3];
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", clientOrigin);

			if (GetVectorDistance(clientOrigin, explosionOrigin) <= g_iConfig[f_c4DamageRadius])
			{
				Handle killEvent = CreateEvent("player_death", true);
				SetEventInt(killEvent, "userid", GetClientUserId(i));
				SetEventInt(killEvent, "attacker", GetClientUserId(client));
				FireEvent(killEvent, false);
				ForcePlayerSuicide(i);
			}
		}

		for (int i = 1; i <= 2; i++)
			EmitAmbientSoundAny(SND_BURST, explosionOrigin, _, SNDLEVEL_RAIDSIREN);

		CreateTimer(2.0, UnImmune, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action UnImmune(Handle timer, any userId)
{
	int client = GetClientOfUserId(userId);
	if (TTT_IsClientValid(client))
		g_bImmuneRDMManager[client] = false;
	return Plugin_Stop;
}

public Action bombBeep(Handle timer, Handle pack)
{
	int bombEnt;
	int beeps;
	ResetPack(pack);
	bombEnt = ReadPackCell(pack);
	beeps = ReadPackCell(pack);
	if (!IsValidEntity(bombEnt))
		return Plugin_Stop;

	int owner = GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity");
	if (!TTT_IsClientValid(owner))
		return Plugin_Stop;

	float bombPos[3];
	GetEntPropVector(bombEnt, Prop_Data, "m_vecOrigin", bombPos);
	bool stopBeeping = false;
	if (beeps > 0)
	{
		EmitAmbientSoundAny(SND_BEEP, bombPos);
		beeps--;
		stopBeeping = false;
	}
	else stopBeeping = true;

	if (stopBeeping)
		return Plugin_Stop;

	Handle bombBeep2;
	CreateDataTimer(1.0, bombBeep, bombBeep2);
	WritePackCell(bombBeep2, bombEnt);
	WritePackCell(bombBeep2, beeps);
	return Plugin_Stop;
}


stock void showPlantMenu(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	char sTitle[128];
	char s10[64], s20[64], s30[64], s40[64], s50[64], s60[64];

	Format(sTitle, sizeof(sTitle), "%T", "Set C4 Timer", client);
	Format(s10, sizeof(s10), "%T", "Seconds", client, 10);
	Format(s20, sizeof(s20), "%T", "Seconds", client, 20);
	Format(s30, sizeof(s30), "%T", "Seconds", client, 30);
	Format(s40, sizeof(s40), "%T", "Seconds", client, 40);
	Format(s50, sizeof(s50), "%T", "Seconds", client, 50);
	Format(s60, sizeof(s60), "%T", "Seconds", client, 60);

	Handle menuHandle = CreateMenu(plantBombMenu);
	SetMenuTitle(menuHandle, sTitle);
	AddMenuItem(menuHandle, "10", s10);
	AddMenuItem(menuHandle, "20", s20);
	AddMenuItem(menuHandle, "30", s30);
	AddMenuItem(menuHandle, "40", s40);
	AddMenuItem(menuHandle, "50", s50);
	AddMenuItem(menuHandle, "60", s60);
	SetMenuPagination(menuHandle, 6);
	DisplayMenu(menuHandle, client, 10);
}

stock void showDefuseMenu(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	char sTitle[128];
	char sWire1[64], sWire2[64], sWire3[64], sWire4[64];

	Format(sTitle, sizeof(sTitle), "%T", "Defuse C4", client);
	Format(sWire1, sizeof(sWire1), "%T", "C4 Wire", client, 1);
	Format(sWire2, sizeof(sWire2), "%T", "C4 Wire", client, 2);
	Format(sWire3, sizeof(sWire3), "%T", "C4 Wire", client, 3);
	Format(sWire4, sizeof(sWire4), "%T", "C4 Wire", client, 4);

	Handle menuHandle= CreateMenu(defuseBombMenu);
	SetMenuTitle(menuHandle, sTitle);
	AddMenuItem(menuHandle, "1", sWire1);
	AddMenuItem(menuHandle, "2", sWire2);
	AddMenuItem(menuHandle, "3", sWire3);
	AddMenuItem(menuHandle, "4", sWire4);
	SetMenuPagination(menuHandle, 4);
	DisplayMenu(menuHandle, client, 10);
}

public int plantBombMenu(Menu menu, MenuAction action, int client, int option)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	switch (action)
	{
		case MenuAction_Select:
		{
			char info[100];
			GetMenuItem(menu, option, info, sizeof(info));
			if (StrEqual(info, "10"))
				plantBomb(client, 10.0);
			else if (StrEqual(info, "20"))
				plantBomb(client, 20.0);
			else if (StrEqual(info, "30"))
				plantBomb(client, 30.0);
			else if (StrEqual(info, "40"))
				plantBomb(client, 40.0);
			else if (StrEqual(info, "50"))
				plantBomb(client, 50.0);
			else if (StrEqual(info, "60"))
				plantBomb(client, 60.0);
			g_bHasC4[client] = false;
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
			g_bHasActiveBomb[client] = false;
			removeBomb(client);
		}
		case MenuAction_Cancel:
		{
			g_bHasActiveBomb[client] = false;
			removeBomb(client);
		}
	}
}

public int defuseBombMenu(Menu menu, MenuAction action, int client, int option)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	switch (action)
	{
		case MenuAction_Select:
		{
			char info[100];
			int planter = g_iDefusePlayerIndex[client];
			g_iDefusePlayerIndex[client] = -1;

			if (planter < 1 || planter > MaxClients || !IsClientInGame(planter))
			{
				g_iDefusePlayerIndex[client] = -1;
				return;
			}

			int wire;
			int correctWire;
			int planterBombIndex = findBomb(planter);
			float bombPos[3];
			GetEntPropVector(planterBombIndex, Prop_Data, "m_vecOrigin", bombPos);
			correctWire = g_iWire[planter];
			GetMenuItem(menu, option, info, sizeof(info));
			wire = StringToInt(info);
			if (wire == correctWire)
			{
				if (1 <= planter <= MaxClients && IsClientInGame(planter))
				{
					CPrintToChat(client, g_iConfig[s_pluginTag], "You Defused Bomb", client, planter);
					CPrintToChat(planter, g_iConfig[s_pluginTag], "Has Defused Bomb", planter, client);
					EmitAmbientSoundAny(SND_DISARM, bombPos);
					g_bHasActiveBomb[planter] = false;
					ClearTimer(g_hExplosionTimer[planter]);
					SetEntProp(planterBombIndex, Prop_Send, "m_hOwnerEntity", -1);
				}
			}
			else
			{
				CPrintToChat(client, g_iConfig[s_pluginTag], "Failed Defuse", client);
				ForcePlayerSuicide(client);
				g_iDefusePlayerIndex[client] = -1;
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
			g_iDefusePlayerIndex[client] = -1;
		}
		case MenuAction_Cancel:
			g_iDefusePlayerIndex[client] = -1;
	}
}

stock float plantBomb(int client, float time)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, g_iConfig[s_pluginTag], "Alive to Plant", client);
		return;
	}

	CPrintToChat(client, g_iConfig[s_pluginTag], "Will Explode In", client, time);

	bool bombFound;
	int bombEnt;
	while ((bombEnt = FindEntityByClassname(bombEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity") != client)
			continue;

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(bombEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if(!StrEqual(MDL_C4, sModelPath))
			continue;

		Handle explosionPack;
		Handle beepPack;
		if (g_hExplosionTimer[client] != null)
			KillTimer(g_hExplosionTimer[client]);
		g_hExplosionTimer[client] = CreateDataTimer(time, explodeC4, explosionPack);
		CreateDataTimer(1.0, bombBeep, beepPack);
		WritePackCell(explosionPack, GetClientUserId(client));
		WritePackCell(explosionPack, bombEnt);
		WritePackCell(beepPack, bombEnt);
		WritePackCell(beepPack, (time - 1));
		g_bHasActiveBomb[client] = true;
		bombFound = true;
	}

	if(!bombFound)
		CPrintToChat(client, g_iConfig[s_pluginTag], "Bomb Was Not Found", client);

	g_iWire[client] = Math_GetRandomInt(1, 4);
	CPrintToChat(client, g_iConfig[s_pluginTag], "Wire Is", client, g_iWire[client]);
}

stock int findBombPlanter(int &bomb)
{
	int iEnt;
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
	{
		int iPlanter = GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity");

		if (iPlanter <= 0)
			continue;

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if(!StrEqual(MDL_C4, sModelPath))
			continue;

		bomb = iEnt;
		return iPlanter;
	}

	return -1;
}

stock int findBomb(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return -1;

	int iEnt;
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") != client)
			continue;

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if(!StrEqual(MDL_C4, sModelPath))
			continue;

		return iEnt;
	}
	return -1;
}

stock void removeBomb(int client)
{
	int iEnt;
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") != client)
			continue;

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if(!StrEqual(MDL_C4, sModelPath))
			continue;

		AcceptEntityInput(iEnt, "Kill");
	}
}

stock void resetPlayers()
{
	LoopValidClients(i)
	{
		ClearTimer(g_hExplosionTimer[i]);
		g_bHasActiveBomb[i] = false;
	}
}

stock void listTraitors(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;

	CPrintToChat(client, g_iConfig[s_pluginTag], "Your Traitor Partners", client);
	int iCount = 0;

	LoopValidClients(i)
	{
		if (!IsPlayerAlive(i) || client == i || g_iRole[i] != TTT_TEAM_TRAITOR)
			continue;
		CPrintToChat(client, g_iConfig[s_pluginTag], "Traitor List", client, i);
		iCount++;
	}

	if(iCount == 0)
		CPrintToChat(client, g_iConfig[s_pluginTag], "No Traitor Partners", client);
}

stock void nameCheck(int client, char name[MAX_NAME_LENGTH])
{
	for(int i; i < g_iBadNameCount; i++)
		if (StrContains(g_sBadNames[i], name, false) != -1)
			KickClient(client, "%T", "Kick Bad Name", client, g_sBadNames[i]);
}

public void OnWeaponPostSwitch(int client, int weapon)
{
	char weaponName[64];
	GetClientWeapon(client, weaponName, sizeof(weaponName));
	if (StrContains(weaponName, "silence") != -1)
		g_bHoldingSilencedWep[client] = true;
	else
		g_bHoldingSilencedWep[client] = false;
}

public Action Command_KarmaReset(int client, int args)
{
	LoopValidClients(i)
		setKarma(g_iKarma[i], 100);
	return Plugin_Handled;
}

// Thanks SMLib ( https://github.com/bcserv/smlib/blob/master/scripting/include/smlib/math.inc#L149 )
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock void CheckTeams()
{
	int iT = 0;
	int iD = 0;
	int iI = 0;

	LoopValidClients(i)
	{
		if(IsPlayerAlive(i))
		{
			if(g_iRole[i] == TTT_TEAM_DETECTIVE)
				iD++;
			else if(g_iRole[i] == TTT_TEAM_TRAITOR)
				iT++;
			else if(g_iRole[i] == TTT_TEAM_INNOCENT)
				iI++;
		}
		else
		{
			if(g_iRole[i] == TTT_TEAM_UNASSIGNED)
			{
				g_bFound[i] = true;
				CS_SetClientClanTag(i, "UNASSIGNED");
			}
		}
	}

	if(iD == 0 && iI == 0)
	{
		g_bRoundStarted = false;
		g_bRoundEnded = true;
		CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
	}
	else if(iT == 0)
	{
		g_bRoundStarted = false;
		g_bRoundEnded = true;
		CS_TerminateRound(7.0, CSRoundEnd_CTWin);
	}
}

stock void SetNoBlock(int client)
{
	SetEntData(client, g_iCollisionGroup, 2, 4, true);
}

stock void LoadBadNames()
{
	char sFile[PLATFORM_MAX_PATH + 1];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/badnames.ini");

	Handle hFile = OpenFile(sFile, "rt");

	if(hFile == null)
		SetFailState("[TTT] Can't open File: %s", sFile);

	char sLine[MAX_NAME_LENGTH];

	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sLine, sizeof(sLine)))
	{
		if(strlen(sLine) > 1)
		{
			strcopy(g_sBadNames[g_iBadNameCount], sizeof(g_sBadNames[]), sLine);
			g_iBadNameCount++;
		}
	}

	delete hFile;
}

stock void LoadClients()
{
	LoopValidClients(i)
	{
		OnClientPostAdminCheck(i);
		OnClientPutInServer(i);
	}
}

stock void LoadClientKarma(int userid)
{
	int client = GetClientOfUserId(userid);

	if(TTT_IsClientValid(client) && !IsFakeClient(client))
	{
		char sCommunityID[64];

		if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
		{
			LogToFileEx(g_iConfig[s_errFile], "(LoadClientKarma) Auth failed: #%d", client);
			return;
		}

		char sQuery[2048];
		Format(sQuery, sizeof(sQuery), "SELECT `karma` FROM `ttt` WHERE `communityid`= \"%s\"", sCommunityID);

		if(g_hDatabase != null)
			SQL_TQuery(g_hDatabase, SQL_OnClientPostAdminCheck, sQuery, userid);
	}
}

public void SQL_OnClientPostAdminCheck(Handle owner, Handle hndl, const char[] error, any userid)
{
	int client = GetClientOfUserId(userid);

	if(!client || !TTT_IsClientValid(client) || IsFakeClient(client))
		return;

	if(hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(SQL_OnClientPostAdminCheck) Query failed: %s", error);
		return;
	}
	else
	{
		if (!SQL_FetchRow(hndl))
			InsertPlayer(userid);
		else
		{
			char sCommunityID[64];

			if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
			{
				LogToFileEx(g_iConfig[s_errFile], "(SQL_OnClientPostAdminCheck) Auth failed: #%d", client);
				return;
			}

			int karma = SQL_FetchInt(hndl, 0);

			g_bKarma[client] = true;

			if (karma == 0)
				setKarma(client, g_iConfig[i_startKarma]);
			else setKarma(client, karma);

			CS_SetClientContributionScore(client, karma);
		}
	}
}

stock void InsertPlayer(int userid)
{
	int client = GetClientOfUserId(userid);

	if(TTT_IsClientValid(client) && !IsFakeClient(client))
	{
		g_iKarma[client] = g_iConfig[i_startKarma];

		char sCommunityID[64];

		if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
			return;

		char sQuery[2048];
		Format(sQuery, sizeof(sQuery), "INSERT INTO `ttt` (`communityid`, `karma`) VALUES (\"%s\", %d)", sCommunityID, g_iKarma[client]);

		if(g_hDatabase != null)
			SQL_TQuery(g_hDatabase, Callback_InsertPlayer, sQuery, userid);
	}
}
