#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <cstrike>
#include <sdkhooks>
#include <multicolors>
#include <emitsoundany>
#include <ttt>
#include <ttt_sql>
#include <webfix>

#undef REQUIRE_PLUGIN
#tryinclude <sourcebans>

#pragma newdecls required

#include "core/globals.sp"
#include "core/config.sp"
#include "core/natives.sp"
#include "core/sql.sp"

public Plugin myinfo =
{
	name = TTT_PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	InitForwards();
	InitNatives();

	RegPluginLibrary("ttt");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sRulesFile, sizeof(g_sRulesFile), "configs/ttt/rules/start.cfg");

	LoadTranslations("ttt.phrases");
	LoadTranslations("common.phrases");

	LoadBadNames();

	g_aRagdoll = new ArrayList(104);
	g_aLogs = new ArrayList(512);
	g_aForceTraitor = new ArrayList();
	g_aForceDetective = new ArrayList();

	g_iCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	m_flNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");
	m_flNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack");

	CreateTimer(1.0, Timer_1, _, TIMER_REPEAT);
	CreateTimer(5.0, Timer_5, _, TIMER_REPEAT);
	
	// Admin commands
	RegConsoleCmd("sm_setrole", Command_SetRole);
	RegConsoleCmd("sm_karmareset", Command_KarmaReset);
	RegConsoleCmd("sm_setkarma", Command_SetKarma);
	RegConsoleCmd("sm_status", Command_Status);
	RegConsoleCmd("sm_karma", Command_Karma);
	RegConsoleCmd("sm_logs", Command_Logs);
	RegConsoleCmd("sm_log", Command_Logs);
	RegConsoleCmd("sm_trules", Command_TRules);
	RegConsoleCmd("sm_drules", Command_DetectiveRules);
	RegConsoleCmd("sm_detective", Command_DetectiveRules);
	RegConsoleCmd("sm_rslays", Command_RSlays);
	RegConsoleCmd("sm_tttversion", Command_TTTVersion);
	
	AddCommandListener(Command_LAW, "+lookatweapon");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_SayTeam, "say_team");
	AddCommandListener(Command_InterceptSuicide, "kill");
	AddCommandListener(Command_InterceptSuicide, "explode");
	AddCommandListener(Command_InterceptSuicide, "spectate");
	AddCommandListener(Command_InterceptSuicide, "jointeam");
	AddCommandListener(Command_InterceptSuicide, "explodevector");
	AddCommandListener(Command_InterceptSuicide, "killvector");
	
	for (int i = 0; i < sizeof(g_sRadioCMDs); i++)
	{
		AddCommandListener(Command_RadioCMDs, g_sRadioCMDs[i]);
	}

	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEndPre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);
	HookEvent("player_changename", Event_ChangeName_Pre, EventHookMode_Pre);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("cs_win_panel_round", Event_WinPanel);
	HookEvent("cs_win_panel_match", Event_WinPanel);
	HookEvent("cs_match_end_restart", Event_WinPanel);

	g_hGraceTime = FindConVar("mp_join_grace_time");

	g_hRSCookie = RegClientCookie("ttt2_round_slays", "Round Slays Cookie", CookieAccess_Private);
	g_hRules = RegClientCookie("ttt2_rules_menu", "Show rules", CookieAccess_Private);
	g_hDRules = RegClientCookie("ttt2_detective_menu", "Show detectives menu", CookieAccess_Private);

	SetRandomSeed(GetTime());
	
	TTT_StartConfig("ttt");
	SetupConfig();
	TTT_EndConfig();

	if (TTT_GetSQLConnection() != null)
	{
		if (g_cDebugMessages.BoolValue)
		{
			LogMessage("(OnPluginStart) Handle is not null");
		}
		
		LateLoadClients(true);
	}
	
	SetRandomSeed(GetTime());
}

public void OnAllPluginsLoaded()
{
	if (LibraryExists("sourcebans"))
	{
		g_bSourcebans = true;
	}
}

public void OnLibraryAdded(const char[] library)
{
	if (StrEqual(library, "sourcebans", false))
	{
		g_bSourcebans = true;
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if (StrEqual(library, "sourcebans", false))
	{
		g_bSourcebans = false;
	}
}

public void OnConfigsExecuted()
{
	// Save configs in strings
	g_cpluginTag.GetString(g_sTag, sizeof(g_sTag));
	g_cdefaultPriD.GetString(g_sDefaultPrimary, sizeof(g_sDefaultPrimary));
	g_cdefaultSec.GetString(g_sDefaultSecondary, sizeof(g_sDefaultSecondary));
	g_cRoundStartedFontColor.GetString(g_sRoundStartedFontColor, sizeof(g_sRoundStartedFontColor));
	g_cRoundStartFontColor.GetString(g_sRoundStartFontColor, sizeof(g_sRoundStartFontColor));
	g_cFSPrimary.GetString(g_sFSPrimary, sizeof(g_sFSPrimary));
	g_cFSSecondary.GetString(g_sFSSecondary, sizeof(g_sFSSecondary));
	
	// Prepare & Format log files
	char sDate[12];
	FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
	
	g_clogFile.GetString(g_sLogFile, sizeof(g_sLogFile));
	g_cerrFile.GetString(g_sErrorFile, sizeof(g_sErrorFile));
	
	ReplaceString(g_sLogFile, sizeof(g_sLogFile), "<DATE>", sDate, true);
	ReplaceString(g_sErrorFile, sizeof(g_sErrorFile), "<DATE>", sDate, true);

	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), g_sLogFile);
	BuildPath(Path_SM, g_sErrorFile, sizeof(g_sErrorFile), g_sErrorFile);
	
	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Log File: \"%s\"", g_sLogFile);
		LogMessage("Error File :\"%s\"", g_sErrorFile);
	}

	if (g_cLogButtons.BoolValue)
	{
		HookEntityOutput("func_button", "OnPressed", OnButtonPressed);
	}
}

public void TTT_OnSQLConnect(Database db)
{
	g_dDB = db;
	AlterKarmaColumn();
}

void AlterKarmaColumn()
{
	if (g_dDB != null)
	{
		char sQuery[72];
		Format(sQuery, sizeof(sQuery), "ALTER TABLE `ttt` ADD COLUMN `karma` INT(11) NOT NULL DEFAULT 0;");
		g_dDB.Query(SQL_AlterKarmaColumn, sQuery);
	}
	else
	{
		SetFailState("Database handle is invalid!");
		return;
	}
}

public Action Command_Logs(int client, int args)
{
	if (g_bRoundEnding || g_bRoundStarted)
	{
		if (client == 0)
		{
			ShowLogs(client);
		}
		else if (TTT_IsClientValid(client) && TTT_CheckCommandAccess(client, "ttt_log_access", g_clogsAccess, true))
		{
			if (g_cLogsDeadOnly.BoolValue)
			{
				if (!IsPlayerAlive(client))
				{
					ShowLogs(client);
				}
			}
			else
			{
				ShowLogs(client);
				
				if (g_cLogsNotifyAlive.IntValue > 0 && !g_bRoundEnding && IsPlayerAlive(client))
				{
					if (g_cLogsNotifyAlive.IntValue == 1)
					{
						LoopValidClients(j)
						{
							CPrintToChat(j, "%s %T", g_sTag, "watching logs alive", j, client);
						}
					}
					else if (g_cLogsNotifyAlive.IntValue == 2)
					{
						LoopValidClients(j)
						{
							if (TTT_CheckCommandAccess(j, "ttt_log_access", g_clogsAccess, true))
							{
								CPrintToChat(j, "%s %T", g_sTag, "watching logs alive", j, client);
							}
						}
					}
				}
			}
		}
		return Plugin_Continue;
	}

	CPrintToChat(client, "%s %T", g_sTag, "you cant see logs", client);
	return Plugin_Handled;
}

stock void ShowLogs(int client)
{
	int iSize = g_aLogs.Length;
	if (iSize == 0)
	{
		if (client == 0)
		{
			PrintToServer("No logs yet");
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sTag, "no logs yet", client);
		}

		return;
	}

	if (g_bReceivingLogs[client])
	{
		return;
	}

	g_bReceivingLogs[client] = true;

	if (client == 0)
	{
		LogToFileEx(g_sLogFile, "--------------------------------------");
		LogToFileEx(g_sLogFile, "-----------START ROUND LOGS-----------");
	}
	else
	{
		CPrintToChat(client, "%s %T", g_sTag, "Receiving logs", client);
		PrintToConsole(client, "--------------------------------------");
		PrintToConsole(client, "---------------TTT LOGS---------------");
	}

	char iItem[TTT_LOG_SIZE];
	int index = 5;
	bool end = false;

	if (index >= iSize)
	{
		end = true;
		index = (iSize - 1);
	}

	for (int i = 0; i <= index; i++)
	{
		g_aLogs.GetString(i, iItem, sizeof(iItem));

		if (client == 0)
		{
			LogToFileEx(g_sLogFile, iItem);
		}
		else
		{
			PrintToConsole(client, iItem);
		}
	}

	if (end)
	{
		if (client == 0)
			LogToFileEx(g_sLogFile, "--------------------------------------");
		else
		{
			CPrintToChat(client, "%s %T", g_sTag, "See your console", client);
			PrintToConsole(client, "--------------------------------------");
			PrintToConsole(client, "--------------------------------------");
		}

		g_bReceivingLogs[client] = false;
		return;
	}

	Handle slPack = CreateDataPack();

	if (TTT_IsClientValid(client))
	{
		WritePackCell(slPack, GetClientUserId(client));
	}
	else
	{
		WritePackCell(slPack, 0);
	}

	WritePackCell(slPack, index);
	RequestFrame(OnCreate, slPack);
}

public void OnCreate(any data)
{
	ResetPack(data);

	int userid = ReadPackCell(data);
	int index = ReadPackCell(data);

	if (view_as<Handle>(data) != null)
	{
		delete view_as<Handle>(data);
	}

	int client;
	if (userid == 0)
	{
		client = userid;
	}
	else
	{
		client = GetClientOfUserId(userid);
	}

	if ((client == 0) || IsClientInGame(client))
	{
		int sizearray = g_aLogs.Length;
		int old = (index + 1);
		index += 5;
		bool end = false;

		if (index >= sizearray)
		{
			end = true;
			index = (sizearray - 1);
		}

		char iItem[TTT_LOG_SIZE];

		for (int i = old; i <= index; i++)
		{
			g_aLogs.GetString(i, iItem, sizeof(iItem));

			if (client == 0)
			{
				LogToFileEx(g_sLogFile, iItem);
			}
			else
			{
				PrintToConsole(client, iItem);
			}
		}

		if (end)
		{
			if (client == 0)
				LogToFileEx(g_sLogFile, "--------------------------------------");
			else
			{
				CPrintToChat(client, "%s %T", g_sTag, "See your console", client);
				PrintToConsole(client, "--------------------------------------");
				PrintToConsole(client, "--------------------------------------");
			}

			g_bReceivingLogs[client] = false;
			return;
		}

		Handle slPack = CreateDataPack();

		if (TTT_IsClientValid(client))
		{
			WritePackCell(slPack, GetClientUserId(client));
		}
		else
		{
			WritePackCell(slPack, 0);
		}

		WritePackCell(slPack, index);
		RequestFrame(OnCreate, slPack);
	}
}

public Action Command_InterceptSuicide(int client, const char[] command, int args)
{
	if (g_cblockSuicide.BoolValue && IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s %T", g_sTag, "Suicide Blocked", client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Command_RadioCMDs(int client, const char[] command, int args)
{
	if (g_cblockRadioMessage.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnMapStart()
{
	for (int i; i < g_iBadNameCount; i++)
	{
		g_sBadNames[i] = "";
	}
	g_iBadNameCount = 0;

	LoadBadNames();

	g_iBeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo.vtf");

	PrecacheModel("props/cs_office/microwave.mdl", true);

	PrecacheSoundAny(SND_TCHAT, true);
	PrecacheSoundAny(SND_FLASHLIGHT, true);
	
	g_iAlive = FindSendPropInfo("CCSPlayerResource", "m_bAlive");
	if (g_iAlive == -1)
	{
		SetFailState("CCSPlayerResource \"m_bAlive\" offset is invalid");
	}
	
	g_iHealth = FindSendPropInfo("CCSPlayerResource", "m_iHealth");
	if (g_iHealth == -1)
	{
		SetFailState("CCSPlayerResource \"m_iHealth\" offset is invalid");
	}

	g_iKills = FindSendPropInfo("CCSPlayerResource", "m_iKills");
	if (g_iKills == -1)
	{
		SetFailState("CCSPlayerResource \"m_iKills\" offset is invalid");
	}

	g_iDeaths = FindSendPropInfo("CCSPlayerResource", "m_iDeaths");
	if (g_iDeaths == -1)
	{
		SetFailState("CCSPlayerResource \"m_iDeaths\"  offset is invalid");
	}

	g_iAssists = FindSendPropInfo("CCSPlayerResource", "m_iAssists");
	if (g_iAssists == -1)
	{
		SetFailState("CCSPlayerResource \"m_iAssists\"  offset is invalid");
	}

	g_iMVPs = FindSendPropInfo("CCSPlayerResource", "m_iMVPs");
	if (g_iMVPs == -1)
	{
		SetFailState("CCSPlayerResource \"m_iMVPs\"  offset is invalid");
	}

	SDKHook(FindEntityByClassname(0, "cs_player_manager"), SDKHook_ThinkPost, ThinkPost);
}

public void ThinkPost(int entity)
{
	if (g_ckadRemover.BoolValue)
	{
		int iZero[MAXPLAYERS + 1] =  { 0, ... };
		
		SetEntDataArray(entity, g_iKills, iZero, MaxClients + 1);
		SetEntDataArray(entity, g_iDeaths, iZero, MaxClients + 1);
		SetEntDataArray(entity, g_iAssists, iZero, MaxClients + 1);
		SetEntDataArray(entity, g_iMVPs, iZero, MaxClients + 1);
	}
	
	int isAlive[MAXPLAYERS + 1];
	int iHealth[MAXPLAYERS + 1];

	GetEntDataArray(entity, g_iAlive, isAlive, MAXPLAYERS + 1);
	
	LoopValidClients(i)
	{
		if (g_cfakeLife.IntValue == 0)
		{
			isAlive[i] = (!g_bFound[i]);
		}
		else if (g_cfakeLife.IntValue == 1)
		{
			isAlive[i] = false;
		}
		else if (g_cfakeLife.IntValue == 2)
		{
			isAlive[i] = true;
		}
		
		iHealth[i] = g_cfakeHealth.IntValue;
	}
	
	SetEntDataArray(entity, g_iHealth, iHealth, MAXPLAYERS + 1);
	SetEntDataArray(entity, g_iAlive, isAlive, MAXPLAYERS + 1);
}

public Action Command_Karma(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	CPrintToChat(client, "%s %T", g_sTag, "Your karma is", client, g_iKarma[client]);

	return Plugin_Handled;
}

public int OnButtonPressed(const char[] output, int entity, int client, float delay)
{
	if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	if (IsValidEntity(entity) && g_bPressed[entity])
	{
		return;
	}

	char sClientID[32], sRole[ROLE_LENGTH], sName[512], iItem[TTT_LOG_SIZE];
	if (g_cAddSteamIDtoLogs.BoolValue)
	{
		if (g_cSteamIDLogFormat.IntValue == 1)
		{
			GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
		}
		else if (g_cSteamIDLogFormat.IntValue == 2)
		{
			GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
		}
		else if (g_cSteamIDLogFormat.IntValue == 3)
		{
			GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
		}
		
		if (strlen(sClientID) > 2)
		{
			Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
		}
	}

	TTT_GetRoleNameByID(TTT_GetClientRole(client), sRole, sizeof(sRole));
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));	
	Format(iItem, sizeof(iItem), "-> [%N%s (%s) pressed the button %s (%d)]", client, sClientID, sRole, sName, entity);
	
	g_bPressed[entity] = true;
	CreateTimer(g_cLogButtonsSpam.FloatValue, Timer_EnableButton, EntIndexToEntRef(entity));
}

public Action Timer_EnableButton(Handle timer, any reference)
{
	int entity = EntRefToEntIndex(reference);
	
	if (IsValidEntity(entity))
	{
		g_bPressed[entity] = false;
	}
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 1 (Warmup: %d)", TTT_IsWarmUp());
	}
	
	if (g_aRagdoll != null)
	{
		g_aRagdoll.Clear();
	}

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 2 (g_aRagdoll: %d)", g_aRagdoll.Length);
	}

	g_bInactive = false;
	g_bRoundEnded = false;
	

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 3 (g_bInactive: %d - g_bRoundEnded: %d)", g_bInactive, g_bRoundEnded);
	}

	LoopValidClients(i)
	{
		g_iRole[i] = TTT_TEAM_UNASSIGNED;
		g_bFound[i] = true;
		g_iInnoKills[i] = 0;
		g_iTraitorKills[i] = 0;
		g_iDetectiveKills[i] = 0;
		g_bImmuneRDMManager[i] = false;
		
		g_bHurtedPlayer1[i] = -1;
		g_bHurtedPlayer2[i] = -1;
		g_bResetHurt[i] = false;
		
		DispatchKeyValue(i, "targetname", "UNASSIGNED");
		CS_SetClientClanTag(i, " ");
		

		if (g_cDebugMessages.BoolValue)
		{
			LogMessage("Event_RoundStartPre - 4 (Player: %N)", i);
		}
	}

	if (g_hStartTimer != null)
	{
		TTT_ClearTimer(g_hStartTimer);
	}

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 5 (g_hStartTimer: %d)", g_hStartTimer);
	}

	if (g_hCountdownTimer != null)
	{
		TTT_ClearTimer(g_hCountdownTimer);
	}

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 6 (g_hCountdownTimer: %d)", g_hCountdownTimer);
	}

	float warmupTime = GetConVarFloat(g_hGraceTime) + 5.0;
	g_hStartTimer = CreateTimer(warmupTime, Timer_Selection, _, TIMER_FLAG_NO_MAPCHANGE);

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 7 (g_hStartTimer: %d - Time: %f)", g_hStartTimer, warmupTime);
	}

	g_fRealRoundStart = GetGameTime() + warmupTime;
	g_hCountdownTimer = CreateTimer(0.5, Timer_SelectionCountdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 8 (g_hCountdownTimer: %d)", g_hCountdownTimer);
	}

	g_bRoundStarted = false;

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 9 (g_bRoundStarted: %d)", g_bRoundStarted);
	}

	if (g_hRoundTimer != null)
	{
		TTT_ClearTimer(g_hRoundTimer);
	}

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 9 (g_hRoundTimer: %d)", g_hRoundTimer);
	}
	
	float fTime = GetConVarFloat(FindConVar("mp_freezetime")) + (GetConVarFloat(FindConVar("mp_roundtime")) * 60.0);
	g_hRoundTimer = CreateTimer(fTime, Timer_OnRoundEnd, _, TIMER_FLAG_NO_MAPCHANGE);

	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Event_RoundStartPre - 9 (g_hRoundTimer: %d - Time: %f)", g_hRoundTimer, fTime);
	}
}

public Action Event_RoundEndPre(Event event, const char[] name, bool dontBroadcast)
{
	LoopValidClients(i)
	{
		g_bFound[i] = true;
		g_iInnoKills[i] = 0;
		g_iTraitorKills[i] = 0;
		g_iDetectiveKills[i] = 0;
		g_bImmuneRDMManager[i] = false;

		ShowLogs(i);
		TeamTag(i);

		if (g_cTranfserArmor.BoolValue)
		{
			if (IsPlayerAlive(i))
			{
				g_iArmor[i] = GetEntProp(i, Prop_Send, "m_ArmorValue");
			}
		}
	}

	ShowLogs(0);

	g_iTeamSelectTime = 0;
	g_bSelection = false;

	if (g_hRoundTimer != null)
	{
		delete g_hRoundTimer;
		g_hRoundTimer = null;
	}
}

public Action Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnding = true;
}

public Action Timer_SelectionCountdown(Handle hTimer)
{
	int timeLeft = RoundToFloor(g_fRealRoundStart - GetGameTime());
	char centerText[512];

	if (g_fRealRoundStart <= 0.0 || timeLeft <= 0)
	{
		if (timeLeft == 0)
		{
			LoopValidClients(i)
			{
				Format(centerText, sizeof(centerText), "%T", "RoundStartedCenter", i, g_cRoundStartedFontSize.IntValue, g_sRoundStartedFontColor);
				PrintHintText(i, centerText);
			}
		}

		g_hCountdownTimer = null;
		return Plugin_Stop;
	}

	LoopValidClients(i)
	{
		Format(centerText, sizeof(centerText), "%T", "RoundStartCenter", i, g_cRoundStartFontSize.IntValue, g_sRoundStartFontColor, timeLeft);
		PrintHintText(i, centerText);
	}

	return Plugin_Continue;
}

public Action Timer_Selection(Handle hTimer)
{
	g_bRoundEnding = false;
	g_hStartTimer = null;

	ArrayList aPlayers = new ArrayList(1);

	LoopValidClients(i)
	{
		if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T  || (!g_cDebug.BoolValue && IsFakeClient(i)))
		{
			continue;
		}

		if (!IsPlayerAlive(i))
		{
			if (g_cRespawnDeadPlayers.BoolValue)
			{
				CS_RespawnPlayer(i);
			}
			else
			{
				continue;
			}
		}

		aPlayers.Push(i);

		if ((g_cDoublePushInno.BoolValue && g_iLastRole[i] == TTT_TEAM_INNOCENT) || (g_cDoublePushDete.BoolValue && g_iLastRole[i] == TTT_TEAM_DETECTIVE))
		{
			aPlayers.Push(i);
		}
	}

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnRoundStart_Pre);
	Call_Finish(res);

	if (res >= Plugin_Handled)
	{
		Call_StartForward(g_hOnRoundStartFailed);
		Call_PushCell(-1);
		Call_PushCell(g_crequiredPlayers.IntValue);
		Call_Finish();

		GiveWeaponsOnFailStart();

		return;
	}

	if (aPlayers.Length < g_crequiredPlayers.IntValue)
	{
		g_bInactive = true;
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s %T", g_sTag, "MIN PLAYERS REQUIRED FOR PLAY", i, g_crequiredPlayers.IntValue);
		}

		g_bCheckPlayers = true;

		Call_StartForward(g_hOnRoundStartFailed);
		Call_PushCell(aPlayers.Length);
		Call_PushCell(g_crequiredPlayers.IntValue);
		Call_Finish();

		GiveWeaponsOnFailStart();

		return;
	}

	LoopValidClients(i)
	{
		if (IsPlayerAlive(i) && g_iRoundSlays[i] > 0)
		{
			if (g_iRoundSlays[i] < 0)
			{
				g_iRoundSlays[i] = 0;
				UpdateRoundSlaysCookie(i);
				continue;
			}
			else if (g_iRoundSlays[i] == 0)
			{
				UpdateRoundSlaysCookie(i);
				continue;
			}

			ForcePlayerSuicide(i);
			g_iRoundSlays[i]--;

			if (g_iRoundSlays[i] > 0)
			{
				CPrintToChat(i, "%s %T", g_sTag, "RS - Slayed", i, g_iRoundSlays[i]);
				LogAction(0, i, "\"%L\" was slayed! Remaining Rounds: %d", i, g_iRoundSlays[i]);
			}

			UpdateRoundSlaysCookie(i);

			if (g_cOpenRulesOnPunish.BoolValue)
			{
				TTT_ClientOpenRules(i);
			}
		}
	}

	//Check if there are any slain players
	for (int i = 0; i < aPlayers.Length; i++)
	{
		if(!IsPlayerAlive(aPlayers.Get(i)))
		{
			aPlayers.Erase(i--);
		}
	}

	g_bRoundStarted = true;
	g_bSelection = true;
	g_bCheckPlayers = false;
	
	int iTCount = GetTCount(aPlayers);
	int iDCount = GetDCount(aPlayers);

	int iTraitors;
	int iDetectives;
	int iInnocents;
	int iRand;
	int client;
	int iIndex;

	while (iTraitors < iTCount)
	{
		if (g_aForceTraitor.Length > 0)
		{
			client = GetClientOfUserId(g_aForceTraitor.Get(0));
			
			if (client > 0)
			{
				iIndex = aPlayers.FindValue(client);

				if (iIndex != -1)
				{
					if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
					{
						g_iRole[client] = TTT_TEAM_TRAITOR;
						g_iLastRole[client] = TTT_TEAM_TRAITOR;
						iTraitors++;
					}
					
					aPlayers.Erase(iIndex);
				}
			}
			
			g_aForceTraitor.Erase(0);
			continue;
		}

		iRand = GetRandomInt(0, aPlayers.Length - 1);
		client = aPlayers.Get(iRand);

		if (TTT_IsClientValid(client) && (g_iLastRole[client] != TTT_TEAM_TRAITOR || GetRandomInt(1, 6) == 4))
		{
			if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
			{
				g_iRole[client] = TTT_TEAM_TRAITOR;
				g_iLastRole[client] = TTT_TEAM_TRAITOR;
				iTraitors++;
			}

			aPlayers.Erase(iRand);
		}
	}

	int count[MAXPLAYERS + 1] = { 0, ... };
	for (int i = 0; i < aPlayers.Length; i++)
	{
		int iClient = aPlayers.Get(i);
		count[iClient]++;

		if (count[iClient] > 1)
		{
			count[iClient] = 1;
			aPlayers.Erase(i);
		}
	}

	while (iDetectives < iDCount && aPlayers.Length > 0)
	{
		if (g_aForceDetective.Length > 0)
		{
			client = GetClientOfUserId(g_aForceDetective.Get(0));
			
			if (client > 0)
			{
				iIndex = aPlayers.FindValue(client);
				
				if (iIndex != -1)
				{
					if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
					{
						g_iLastRole[client] = TTT_TEAM_DETECTIVE;
						g_iRole[client] = TTT_TEAM_DETECTIVE;
						iDetectives++;
					}

					aPlayers.Erase(iIndex);
				}
			}
			
			g_aForceDetective.Erase(0);
			continue;
		}

		if (aPlayers.Length <= (iDCount - iDetectives))
		{
			for (int i = 0; i < aPlayers.Length; i++)
			{
				g_iRole[aPlayers.Get(i)] = TTT_TEAM_DETECTIVE;
				g_iLastRole[client] = TTT_TEAM_DETECTIVE;
				iDetectives++;
			}
			break;
		}

		iRand = GetRandomInt(0, aPlayers.Length - 1);
		client = aPlayers.Get(iRand);

		if (TTT_IsClientValid(client) && ((TTT_GetClientKarma(client) > g_cminKarmaDetective.IntValue && g_iLastRole[client] == TTT_TEAM_INNOCENT) || GetRandomInt(1, 6) == 4))
		{
			if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
			{
				if (g_bAvoidDetective[client] == true)
				{
					g_iLastRole[client] = TTT_TEAM_INNOCENT;
					g_iRole[client] = TTT_TEAM_INNOCENT;
				}
				else
				{
					g_iLastRole[client] = TTT_TEAM_DETECTIVE;
					g_iRole[client] = TTT_TEAM_DETECTIVE;
					iDetectives++;
				}
			}

			aPlayers.Erase(iRand);
		}
	}

	iInnocents = aPlayers.Length;

	while (aPlayers.Length > 0)
	{
		client = aPlayers.Get(0);
		if (TTT_IsClientValid(client) && g_iRole[client] == TTT_TEAM_UNASSIGNED)
		{
			g_iLastRole[client] = TTT_TEAM_INNOCENT;
			g_iRole[client] = TTT_TEAM_INNOCENT;
		}
		aPlayers.Erase(0);
	}

	delete aPlayers;


	LoopValidClients(i)
	{
		if ((!g_cpublicKarma.BoolValue) && g_ckarmaRound.BoolValue)
		{
			g_iKarmaStart[i] = g_iKarma[i];
			CPrintToChat(i, "%s %T", g_sTag, "All karma has been updated", i);
		}

		CPrintToChat(i, "%s %T", g_sTag, "TEAMS HAS BEEN SELECTED", i);

		if (g_iRole[i] != TTT_TEAM_TRAITOR)
		{
			CPrintToChat(i, "%s %T", g_sTag, "TRAITORS HAS BEEN SELECTED", i, iTraitors);
		}
		else
		{
			if (g_cShowTraitors.BoolValue)
			{
				CPrintToChat(i, "%s %T", g_sTag, "Your Traitor Partners", i);
				int iCount = 0;
			
				LoopValidClients(j)
				{
					if (!IsPlayerAlive(j) || i == j || g_iRole[j] != TTT_TEAM_TRAITOR)
					{
						continue;
					}
					CPrintToChat(i, "%s %T", g_sTag, "Traitor List", i, j);
					iCount++;
				}
			
				if (iCount == 0)
				{
					CPrintToChat(i, "%s %T", g_sTag, "No Traitor Partners", i);
				}
			}
		}

		if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T)
		{
			continue;
		}

		if (!IsPlayerAlive(i))
		{
			continue;
		}

		if (!g_cDebug.BoolValue && IsFakeClient(i))
		{
			continue;
		}

		TeamInitialize(i);
	}

	if (g_aLogs != null)
	{
		g_aLogs.Clear();
	}

	g_iTeamSelectTime = GetTime();
	
	g_bSelection = false;

	Call_StartForward(g_hOnRoundStart);
	Call_PushCell(iInnocents);
	Call_PushCell(iTraitors);
	Call_PushCell(iDetectives);
	Call_Finish();
}

int GetTCount(ArrayList array)
{
	int iActivePlayers = 0;
	bool bChecked[MAXPLAYERS + 1] = { false, ... };

	for (int i = 0; i < array.Length; i++)
	{
		int client = array.Get(i);

		if (!bChecked[client])
		{
			bChecked[client] = true;
			iActivePlayers++;
		}
	}

	int iTCount = RoundToFloor(float(iActivePlayers) * (float(g_ctraitorRatio.IntValue) / 100.0));

	if (iTCount < 1)
	{
		iTCount = 1;
	}

	if (iTCount > g_cmaxTraitors.IntValue)
	{
		iTCount = g_cmaxTraitors.IntValue;
	}

	return iTCount;
}

int GetDCount(ArrayList array)
{
	int iActivePlayers = 0;
	bool bChecked[MAXPLAYERS + 1] = { false, ... };

	for (int i = 0; i < array.Length; i++)
	{
		int client = array.Get(i);

		if (!bChecked[client])
		{
			bChecked[client] = true;
			iActivePlayers++;
		}
	}

	if (iActivePlayers < g_crequiredPlayersD.IntValue)
	{
		return 0;
	}

	int iDCount = RoundToFloor(float(iActivePlayers) * (float(g_cdetectiveRatio.IntValue) / 100.0));

	if (iDCount > g_cmaxDetectives.IntValue)
	{
		iDCount = g_cmaxDetectives.IntValue;
	}

	return iDCount;
}

stock void TeamInitialize(int client)
{
	if (!TTT_IsClientValid(client))
	{
		return;
	}
	
	g_bFound[client] = false;
	g_bAlive[client] = true;
	
	int iTeam = GetClientTeam(client);
	
	if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		if (g_cforceTeams.BoolValue)
		{
			if (iTeam == CS_TEAM_T || (g_cSwitchSpec.BoolValue && iTeam == CS_TEAM_SPECTATOR))
			{
				CS_SwitchTeam(client, CS_TEAM_CT);
			}
		}
		
		int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

		if (iWeapon == -1)
		{
			GivePlayerItem(client, g_sDefaultPrimary);
		}
		else
		{
			if (g_cPrimaryWeaponUpdate.IntValue == 1)
			{
				SDKHooks_DropWeapon(client, iWeapon);
				GivePlayerItem(client, g_sDefaultPrimary);
			}
			else if (g_cPrimaryWeaponUpdate.IntValue == 2)
			{
				TTT_SafeRemoveWeapon(client, iWeapon, CS_SLOT_PRIMARY);
				GivePlayerItem(client, g_sDefaultPrimary);
			}
		}

		CPrintToChat(client, "%s %T", g_sTag, "Your Team is DETECTIVES", client);
		
		DispatchKeyValue(client, "targetname", "DETECTIVE");

		if (g_cspawnHPD.IntValue > 0)
		{
			SetEntityHealth(client, g_cspawnHPD.IntValue);
		}

		if (GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1)
		{
			GivePlayerItem(client, "weapon_knife");
		}

		iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

		if (iWeapon == -1)
		{
			GivePlayerItem(client, g_sDefaultSecondary);
		}
		else
		{
			if (g_cSecondaryWeaponUpdate.IntValue == 1)
			{
				SDKHooks_DropWeapon(client, iWeapon);
				GivePlayerItem(client, g_sDefaultSecondary);
			}
			else if (g_cSecondaryWeaponUpdate.IntValue == 2)
			{
				TTT_SafeRemoveWeapon(client, iWeapon, CS_SLOT_SECONDARY);
				GivePlayerItem(client, g_sDefaultSecondary);
			}
		}
	}
	else if (g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		CPrintToChat(client, "%s %T", g_sTag, "Your Team is TRAITORS", client);
		
		DispatchKeyValue(client, "targetname", "TRAITOR");

		if (g_cspawnHPT.IntValue > 0)
		{
			SetEntityHealth(client, g_cspawnHPT.IntValue);
		}

		if (g_cforceTeams.BoolValue)
		{
			if (iTeam == CS_TEAM_CT || (g_cSwitchSpec.BoolValue && iTeam == CS_TEAM_SPECTATOR))
			{
				CS_SwitchTeam(client, CS_TEAM_T);
			}
		}
		if (GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1)
		{
			GivePlayerItem(client, "weapon_knife");
		}

		int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

		if (iWeapon == -1)
		{
			GivePlayerItem(client, g_sDefaultSecondary);
		}
		else
		{
			if (g_cSecondaryWeaponUpdate.IntValue == 1)
			{
				SDKHooks_DropWeapon(client, iWeapon);
				GivePlayerItem(client, g_sDefaultSecondary);
			}
			else if (g_cSecondaryWeaponUpdate.IntValue == 2)
			{
				TTT_SafeRemoveWeapon(client, iWeapon, CS_SLOT_SECONDARY);
				GivePlayerItem(client, g_sDefaultSecondary);
			}
		}
	}
	else if (g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		CPrintToChat(client, "%s %T", g_sTag, "Your Team is INNOCENTS", client);
		
		DispatchKeyValue(client, "targetname", "INNOCENT");

		if (g_cspawnHPI.IntValue > 0)
		{
			SetEntityHealth(client, g_cspawnHPI.IntValue);
		}

		if (g_cforceTeams.BoolValue)
		{
			if ((iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT) || (g_cSwitchSpec.BoolValue && iTeam == CS_TEAM_SPECTATOR))
			{
				CS_SwitchTeam(client, CS_TEAM_T);
			}
		}
		
		if (g_cInnocentKnife.BoolValue && GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1)
		{
			GivePlayerItem(client, "weapon_knife");
		}
		else if (!g_cInnocentKnife.BoolValue && GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) != -1)
		{
			/* char sBuffer[32];
			int iEnt = -1;
			
			while ((iEnt = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE)) != -1)
			{
				GetEntityClassname(iEnt, sBuffer, sizeof(sBuffer));
				
				if (StrContains(sBuffer, "knife", false) != -1 || StrContains(sBuffer, "bayonet", false) != -1)
				{
					if (!TTT_SafeRemoveWeapon(client, iEnt, CS_SLOT_KNIFE))
					{
						LogError("Can't remove knife! Player: \"%L\"", client);
					}
					
					break;
				}
			} */

			for(int offset = 0; offset < 128; offset += 4)
			{
				int weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);
		
				if (IsValidEntity(weapon))
				{
					char sClass[32];
					GetEntityClassname(weapon, sClass, sizeof(sClass));
		
					if ((StrContains(sClass, "knife", false) != -1) || (StrContains(sClass, "bayonet", false) != -1))
					{
						if (!TTT_SafeRemoveWeapon(client, weapon, CS_SLOT_KNIFE))
						{
							LogError("Can't remove knife! Player: \"%L\"", client);
						}
						
						break;
					}
				}
			}
		}

		int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

		if (iWeapon == -1)
		{
			GivePlayerItem(client, g_sDefaultSecondary);
		}
		else
		{
			if (g_cSecondaryWeaponUpdate.IntValue == 1)
			{
				SDKHooks_DropWeapon(client, iWeapon);
				GivePlayerItem(client, g_sDefaultSecondary);
			}
			else if (g_cSecondaryWeaponUpdate.IntValue == 2)
			{
				TTT_SafeRemoveWeapon(client, iWeapon, CS_SLOT_SECONDARY);
				GivePlayerItem(client, g_sDefaultSecondary);
			}
		}
	}

	for(int offset = 0; offset < 128; offset += 4)
	{
		int weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);

		if (IsValidEntity(weapon))
		{
			char sClass[32];
			GetEntityClassname(weapon, sClass, sizeof(sClass));

			if (StrContains(sClass, "weapon_", false) != -1)
			{
				SetEntDataFloat(weapon, m_flNextPrimaryAttack, GetGameTime() - 0.1);
				SetEntDataFloat(weapon, m_flNextSecondaryAttack, GetGameTime() - 0.1);
			}
		}
	}

	CheckClantag(client);

	bool bUpdate = false;

	if (g_cupdateClientModel.BoolValue)
	{
		CS_UpdateClientModel(client);
		
		bUpdate = true;
	}
	
	if (bUpdate)
	{
		char sModel[PLATFORM_MAX_PATH + 1];
		GetClientModel(client, sModel, sizeof(sModel));

		Call_StartForward(g_hOnModelUpdate);
		Call_PushCell(client);
		Call_PushString(sModel);
		Call_Finish();

	}

	Call_StartForward(g_hOnClientGetRole);
	Call_PushCell(client);
	Call_PushCell(g_iRole[client]);
	Call_Finish();
}

stock void TeamTag(int client)
{
	if (!TTT_IsClientValid(client))
	{
		return;
	}

	if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		CS_SetClientClanTag(client, "DETECTIVE");
	}
	else if (g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		CS_SetClientClanTag(client, "TRAITOR");
	}
	else if (g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		CS_SetClientClanTag(client, "INNOCENT");
	}
	else if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
	{
		CS_SetClientClanTag(client, "UNASSIGNED");
	}
	else
	{
		CS_SetClientClanTag(client, " ");
	}
}

public Action Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (g_bRoundStarted && TTT_IsClientValid(client))
	{
		CS_SetClientClanTag(client, "UNASSIGNED");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		if (g_cAdvert.BoolValue)
		{
			CPrintToChat(client, "%s %T", g_sTag, "Player Spawn TTT Version", client, TTT_PLUGIN_VERSION);
		}
		
		if (g_bRoundStarted)
		{
			if (g_cslayAfterStart.BoolValue)
			{
				g_iRole[client] = TTT_TEAM_UNASSIGNED;
				
				RequestFrame(Frame_SlapPlayer, GetClientUserId(client));
				
				CS_SetClientClanTag(client, "UNASSIGNED");
				DispatchKeyValue(client, "targetname", "UNASSIGNED");
			}
		}
		else
		{
			CS_SetClientClanTag(client, " ");

			if (g_cEnableDamage.BoolValue)
			{
				GivePlayerItem(client, "weapon_knife");

				char sWeapon[32];
				
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSSecondary);
				GivePlayerItem(client, sWeapon);
				
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSPrimary);
				GivePlayerItem(client, sWeapon);
			}
		}

		g_iInnoKills[client] = 0;
		g_iTraitorKills[client] = 0;
		g_iDetectiveKills[client] = 0;

		StripAllWeapons(client);

		if (g_bInactive)
		{
			int iCount = 0;

			LoopValidClients(i)
			{
				if (IsPlayerAlive(i) && (GetClientTeam(i) > CS_TEAM_SPECTATOR))
				{
					iCount++;
				}
			}

			if (iCount >= 3)
			{
				ServerCommand("mp_restartgame 2");
			}
		}

		if (!g_bInactive && g_cshowKarmaOnSpawn.BoolValue)
		{
			CPrintToChat(client, "%s %T", g_sTag, "Your karma is", client, g_iKarma[client]);
		}

		if (g_cenableNoBlock.BoolValue)
		{
			SetNoBlock(client);
		}

		if (g_cTranfserArmor.BoolValue && g_iArmor[client] > 0)
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", g_iArmor[client]);
			g_iArmor[client] = 0;
		}
	}
}

public void Frame_SlapPlayer(any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		ForcePlayerSuicide(client);
	}
}

public void OnClientPutInServer(int client)
{
	HookClient(client);
}

void LateLoadClients(bool bHook = false)
{
	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("(LateLoadClients) bHook: %d", bHook);
	}
	
	LoopValidClients(i)
	{
		LoadClientKarma(GetClientUserId(i));
		OnClientCookiesCached(i);

		if (bHook)
		{
			HookClient(i);
		}
	}
}

void HookClient(int client)
{
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_PostThink, OnPostThink);
}

public Action OnPostThink(int client)
{
	if (TTT_IsClientValid(client))
	{
		int iKarma;
		if (g_cpublicKarma.BoolValue)
		{
			if (g_bFound[client])
			{
				iKarma = g_iKarma[client] * -1;
			}
			else
			{
				iKarma = g_iKarma[client];
			}
		}
		else if (g_ckarmaRound.BoolValue)
		{
			if (g_bFound[client])
			{
				iKarma = g_iKarmaStart[client] * -1;
			}
			else
			{
				iKarma = g_iKarmaStart[client];
			}
		}
		CS_SetClientContributionScore(client, iKarma);
	}
}

stock void BanBadPlayerKarma(int client)
{
	char sReason[512];
	Format(sReason, sizeof(sReason), "%T", "Your Karma is too low", client);

	setKarma(client, g_cstartKarma.IntValue, true);

	if (g_bSourcebans)
	{
		SBBanPlayer(0, client, g_ckarmaBanLength.IntValue, sReason);
	}
	else
	{
		ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(client), g_ckarmaBanLength.IntValue, sReason);
	}
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (g_cDisableDamageSelection.BoolValue && g_bSelection)
	{
		return Plugin_Handled;
	}
	
	if (IsDamageForbidden())
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsDamageForbidden())
	{
		return Plugin_Handled;
	}
	
	float fDamage = damage;
	
	if (g_bRoundStarted && !g_bRoundEnded)
	{
		if (TTT_IsClientValid(iAttacker) && iAttacker != iVictim && g_ckarmaDMG.BoolValue)
		{
			if (g_ckarmaDMG_up.BoolValue || (g_iKarma[iAttacker] < g_cstartKarma.IntValue))
			{
				fDamage = (damage * (float(g_iKarma[iAttacker]) / float(g_cstartKarma.IntValue)));
			}
		}
	}
	
	if (!TTT_IsClientValid(iAttacker) || !TTT_IsClientValid(iVictim))
	{
		return Plugin_Continue;
	}
	
	char iItem[TTT_LOG_SIZE];
	int iWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
	
	if (!IsValidEntity(iWeapon))
	{
		return Plugin_Continue;
	}
	
	char sWeapon[32];
	GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));
	
	char sAttackerID[32], sClientID[32];
	
	if (g_cAddSteamIDtoLogs.BoolValue)
	{
		if (g_cSteamIDLogFormat.IntValue == 1)
		{
			GetClientAuthId(iAttacker, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
			GetClientAuthId(iVictim, AuthId_Steam2, sClientID, sizeof(sClientID));
		}
		else if (g_cSteamIDLogFormat.IntValue == 2)
		{
			GetClientAuthId(iAttacker, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
			GetClientAuthId(iVictim, AuthId_Steam3, sClientID, sizeof(sClientID));
		}
		else if (g_cSteamIDLogFormat.IntValue == 3)
		{
			GetClientAuthId(iAttacker, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
			GetClientAuthId(iVictim, AuthId_SteamID64, sClientID, sizeof(sClientID));
		}
		
		if (strlen(sAttackerID) > 2 && strlen(sClientID) > 2)
		{
			Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
			Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
		}
	}

	if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[iVictim] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) damaged %N%s (Innocent) for %.0f damage with %s] - BAD ACTION", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			subtractKarma(iAttacker, g_cDamageKarmaII.IntValue, false);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[iVictim] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) damaged %N%s (Traitor) for %.0f damage with %s]", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			addKarma(iAttacker, g_cDamageKarmaIT.IntValue, false);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[iVictim] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) damaged %N%s (Detective) for %.0f damage with %s] - BAD ACTION", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			subtractKarma(iAttacker, g_cDamageKarmaID.IntValue, false);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[iVictim] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) damaged %N%s (Innocent) for %.0f damage with %s]", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			addKarma(iAttacker, g_cDamageKarmaTI.IntValue, false);
		}

	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[iVictim] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) damaged %N%s (Traitor) for %.0f damage with %s] - BAD ACTION", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			subtractKarma(iAttacker, g_cDamageKarmaTT.IntValue, false);
		}

	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[iVictim] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) damaged %N%s (Detective) for %.0f damage with %s]", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			addKarma(iAttacker, g_cDamageKarmaTD.IntValue, false);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[iVictim] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) damaged %N%s (Innocent) for %.0f damage with %s] - BAD ACTION", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			subtractKarma(iAttacker, g_cDamageKarmaDI.IntValue, false);
		}

	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[iVictim] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) damaged %N%s (Traitor) for %.0f damage with %s]", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			addKarma(iAttacker, g_cDamageKarmaDT.IntValue, false);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[iVictim] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) damaged %N%s (Detective) for %.0f damage with %s] - BAD ACTION", iAttacker, sAttackerID, iVictim, sClientID, fDamage, sWeapon);
		addArrayTime(iItem);

		if (g_cEnableDamageKarma.BoolValue)
		{
			subtractKarma(iAttacker, g_cDamageKarmaDD.IntValue, false);
		}
	}
	
	if (fDamage != damage)
	{
		damage = fDamage;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

bool IsDamageForbidden()
{
	if (g_bRoundEnded && !g_croundendDamage.BoolValue)
	{
		return true;
	}
	
	if (!g_bRoundStarted && !g_cEnableDamage.BoolValue)
	{
		return true;
	}

	return false;
}

public Action Event_PlayerDeathPre(Event event, const char[] menu, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!TTT_IsClientValid)
	{
		event.BroadcastDisabled = true;
		return Plugin_Changed;
	}

	int iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	
	if (iRagdoll > 0)
	{
		AcceptEntityInput(iRagdoll, "Kill");
	}
	
	if (g_iRole[client] > TTT_TEAM_UNASSIGNED)
	{
		g_bAlive[client] = false;
		char sModel[128];
		GetClientModel(client, sModel, sizeof(sModel));

		float origin[3], angles[3], velocity[3];

		GetClientAbsOrigin(client, origin);
		GetClientAbsAngles(client, angles);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

		int iEntity = CreateEntityByName("prop_ragdoll");
		DispatchKeyValue(iEntity, "model", sModel);
		SetEntProp(iEntity, Prop_Data, "m_nSolidType", 6);
		SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 5);

		ActivateEntity(iEntity);
		if (DispatchSpawn(iEntity))
		{
			float speed = GetVectorLength(velocity);
			if (speed >= 500)
			{
				TeleportEntity(iEntity, origin, angles, NULL_VECTOR);
			}
			else
			{
				TeleportEntity(iEntity, origin, angles, velocity);
			}
		}
		else
		{
			LogToFileEx(g_sErrorFile, "Unable to spawn ragdoll for %N (Auth: %i)", client, GetSteamAccountID(client));
		}

		SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 2);

		int iUAttacker = event.GetInt("attacker");
		int iAttacker = GetClientOfUserId(iUAttacker);
		int iARole = 0;
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		int iRagdollC[Ragdolls];
		iRagdollC[Ent] = EntIndexToEntRef(iEntity);
		iRagdollC[Victim] = GetClientUserId(client);
		iRagdollC[VictimTeam] = g_iRole[client];
		Format(iRagdollC[VictimName], MAX_NAME_LENGTH, sName);
		iRagdollC[Scanned] = false;
		
		if (TTT_IsClientValid(iAttacker))
		{
			GetClientName(iAttacker, sName, sizeof(sName));
			iARole = g_iRole[iAttacker];
		}
		else
		{
			Format(sName, sizeof(sName), "Unknown attacker");
			iUAttacker = 0;
		}
		
		iRagdollC[Attacker] = iUAttacker;
		iRagdollC[AttackerTeam] = iARole;
		Format(iRagdollC[AttackerName], MAX_NAME_LENGTH, sName);
		iRagdollC[GameTime] = GetGameTime();
		event.GetString("weapon", iRagdollC[Weaponused], sizeof(iRagdollC[Weaponused]));
		
		g_aRagdoll.PushArray(iRagdollC[0]);

		SetEntPropEnt(client, Prop_Send, "m_hRagdoll", iEntity);

		Action res = Plugin_Continue;

		Call_StartForward(g_hOnPlayerDeathPre);
		Call_PushCell(client);
		Call_PushCell(iAttacker);
		Call_Finish(res);

		if (res == Plugin_Stop || res == Plugin_Changed)
		{
			event.BroadcastDisabled = true;
			return Plugin_Changed;
		}

		if (client != iAttacker && iAttacker != 0 && !g_bImmuneRDMManager[iAttacker])
		{
			if (
				(g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR) ||
				(g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE) ||
				(g_cShowInnoRDMMenu.BoolValue && g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_INNOCENT)
			)
			{
				if (g_hRDMTimer[client] != null)
				{
					TTT_ClearTimer(g_hRDMTimer[client]);
				}

				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			}

			if ((g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_INNOCENT) || (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE))
			{
				g_iInnoKills[iAttacker]++;
			}
			else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)
			{
				g_iTraitorKills[iAttacker]++;
			}
			else if ((g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_INNOCENT) || (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE))
			{
				g_iDetectiveKills[iAttacker]++;
			}

			if (g_iInnoKills[iAttacker] >= g_cpunishInnoKills.IntValue)
			{
				TTT_AddRoundSlays(iAttacker, g_cRoundSlayInno.IntValue, true);
			}

			if (g_iTraitorKills[iAttacker] >= g_cpunishTraitorKills.IntValue)
			{
				TTT_AddRoundSlays(iAttacker, g_cRoundSlayTraitor.IntValue, true);
			}

			if (g_iDetectiveKills[iAttacker] >= g_cpunishDetectiveKills.IntValue)
			{
				TTT_AddRoundSlays(iAttacker, g_cRoundSlayDetective.IntValue, true);
			}
		}
	}

	event.BroadcastDisabled = true;
	return Plugin_Changed;
}

public void OnClientPostAdminCheck(int client)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	nameCheck(client, name);

	g_bImmuneRDMManager[client] = false;
	g_bFound[client] = true;

	g_iRole[client] = TTT_TEAM_UNASSIGNED;
	
	DispatchKeyValue(client, "targetname", "UNASSIGNED");
	CS_SetClientClanTag(client, "UNASSIGNED");

	if (g_dDB != null)
	{
		CreateTimer(1.0, Timer_OnClientPostAdminCheck, GetClientUserId(client));
	}

	if (g_cshowRulesMenu.BoolValue)
	{
		CreateTimer(3.0, Timer_ShowWelcomeMenu, GetClientUserId(client));
	}
	else if (g_cshowDetectiveMenu.BoolValue)
	{
		CreateTimer(3.0, Timer_ShowDetectiveMenu, GetClientUserId(client));
	}
}

public Action Timer_OnClientPostAdminCheck(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		LoadClientKarma(GetClientUserId(client));
	}
}

public Action Command_TRules(int client, int args)
{
	if (!g_cshowRulesMenu.BoolValue)
	{
		return Plugin_Handled;
	}
	
	g_bRules[client] = false;
	
	char sBuffer[12];
	IntToString(g_bRules[client], sBuffer, sizeof(sBuffer));
	SetClientCookie(client, g_hRules, sBuffer);

	ShowRules(client, g_iSite[client]);
	return Plugin_Handled;
}

public Action Command_DetectiveRules(int client, int args)
{
	if (!g_cshowDetectiveMenu.BoolValue)
	{
		return Plugin_Handled;
	}
	
	g_bDRules[client] = false;
	
	char sBuffer[12];
	IntToString(g_bDRules[client], sBuffer, sizeof(sBuffer));
	SetClientCookie(client, g_hDRules, sBuffer);
	
	AskClientForMicrophone(client);
	return Plugin_Handled;
}

public Action Command_RSlays(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (!TTT_CheckCommandAccess(client, "sm_rslays", g_cRoundSlayAccess, true))
	{
		return Plugin_Handled;
	}

	if (args < 2 || args > 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rslays <#userid|name> <rounds>");

		return Plugin_Handled;
	}

	char arg1[32];
	char arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_MULTI, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		int target = target_list[i];

		if (target == -1)
		{
			CReplyToCommand(client, "Invalid target");
			return Plugin_Handled;
		}

		int rounds = StringToInt(arg2);

		if (rounds < 0)
		{
			CReplyToCommand(client, "Rounds must be zero (reset) or higher.");
			return Plugin_Handled;
		}

		TTT_SetRoundSlays(target, rounds, true);

		LoopValidClients(j)
		{
			CPrintToChat(j, "%s %T", g_sTag, "AdminSetRoundSlays", j, target, client, rounds);
		}
		
		LogAction(client, target, "\"%L\" slayed \"%L\" for \"%i\" rounds", client, target, rounds);
	}

	return Plugin_Continue;
}

public Action Command_TTTVersion(int client, int args)
{
	ReplyToCommand(client, "TTT Version: %s", TTT_PLUGIN_VERSION);
}

public void Frame_ShowWelcomeMenu(any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		ShowRules(client, g_iSite[client]);
	}
}

public Action Timer_ShowWelcomeMenu(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		ShowRules(client, g_iSite[client]);
	}
}

stock void ShowRules(int client, int iItem)
{
	if (g_cRulesMenu.BoolValue && g_bRules[client])
	{
		return;
	}

	bool bShow = true;
	Action res = Plugin_Continue;
	Call_StartForward(g_hOnRulesMenu);
	Call_PushCell(client);
	Call_PushCellRef(bShow);
	Call_Finish(res);

	if (res == Plugin_Changed && !bShow)
	{
		return;
	}
	
	char sText[512], sYes[64];
	Format(sText, sizeof(sText), "%T", "Welcome Menu", client, client, TTT_PLUGIN_AUTHOR);
	Format(sYes, sizeof(sYes), "%T", "WM Yes", client);

	Menu menu = new Menu(Menu_ShowWelcomeMenu);
	menu.SetTitle(sText);

	Handle hFile = OpenFile(g_sRulesFile, "rt");

	if (hFile == null)
	{
		SetFailState("[TTT] Can't open File: %s", g_sRulesFile);
	}

	KeyValues kvRules = CreateKeyValues("Rules");

	if (!kvRules.ImportFromFile(g_sRulesFile))
	{
		SetFailState("Can't read %s correctly! (ImportFromFile)", g_sRulesFile);
		delete kvRules;
		delete hFile;
		return;
	}

	if (!kvRules.GotoFirstSubKey())
	{
		SetFailState("Can't read %s correctly! (GotoFirstSubKey)", g_sRulesFile);
		delete kvRules;
		delete hFile;
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
	delete hFile;

	menu.AddItem("yes", sYes);
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.DisplayAt(client, iItem, g_ctimeToReadRules.IntValue);
}

public int Menu_ShowWelcomeMenu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sParam[32];
		GetMenuItem(menu, param, sParam, sizeof(sParam));

		if (!StrEqual(sParam, "yes", false))
		{
			Handle hFile = OpenFile(g_sRulesFile, "rt");

			if (hFile == null)
			{
				SetFailState("[TTT] Can't open File: %s", g_sRulesFile);
				return 0;
			}

			KeyValues kvRules = CreateKeyValues("Rules");

			if (!kvRules.ImportFromFile(g_sRulesFile))
			{
				SetFailState("Can't read %s correctly! (ImportFromFile)", g_sRulesFile);
				delete kvRules;
				return 0;
			}


			if (kvRules.JumpToKey(sParam, false))
			{
				char sValue[MAX_MESSAGE_LENGTH];

				kvRules.GetString("text", sValue, sizeof(sValue));
				if (strlen(sValue) > 0)
				{
					CPrintToChat(client, sValue);
					RequestFrame(Frame_ShowWelcomeMenu, GetClientUserId(client));

					g_bKnowRules[client] = false;
					g_bReadRules[client] = true;

					delete kvRules;
					return 0;
				}

				kvRules.GetString("fakecommand", sValue, sizeof(sValue));
				if (strlen(sValue) > 0)
				{
					FakeClientCommand(client, sValue);

					g_bKnowRules[client] = false;
					g_bReadRules[client] = true;

					delete kvRules;
					return 0;
				}

				kvRules.GetString("command", sValue, sizeof(sValue));
				if (strlen(sValue) > 0)
				{
					ClientCommand(client, sValue);

					g_bKnowRules[client] = false;
					g_bReadRules[client] = true;

					delete kvRules;
					return 0;
				}

				kvRules.GetString("url", sValue, sizeof(sValue));
				if (strlen(sValue) > 0)
				{
					WebFix_OpenUrl(client, "TTT Rules", sValue);

					if (g_cRulesURLReopenMenu.BoolValue)
					{
						g_bKnowRules[client] = false;
						g_bReadRules[client] = true;
					}
					else
					{
						TTT_ClientOpenRules(client);
					}

					delete kvRules;
					return 0;
				}

				kvRules.GetString("file", sValue, sizeof(sValue));
				if (strlen(sValue) > 0)
				{
					g_iSite[client] = menu.Selection;

					char sFile[PLATFORM_MAX_PATH + 1];
					BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/rules/%s", sValue);

					Handle hRFile = OpenFile(sFile, "rt");

					if (hRFile == null)
					SetFailState("[TTT] Can't open File: %s", sFile);

					char sLine[64], sTitle[64];

					Menu rMenu = new Menu(Menu_RulesPage);

					kvRules.GetString("title", sTitle, sizeof(sTitle));
					rMenu.SetTitle(sTitle);

					while (!IsEndOfFile(hRFile) && ReadFileLine(hRFile, sLine, sizeof(sLine)))
					{
						if (strlen(sLine) > 1)
						{
							rMenu.AddItem("", sLine, ITEMDRAW_DISABLED);
						}
					}

					rMenu.ExitButton = false;
					rMenu.ExitBackButton = true;
					rMenu.Display(client, g_ctimeToReadRules.IntValue);

					delete hRFile;
					delete kvRules;

					return 0;
				}

				delete kvRules;

				return 0;
			}
			
			delete hFile;
		}
		else
		{
			if (g_cRulesMenu.BoolValue)
			{
				g_bRules[client] = true;
				
				char sBuffer[12];
				IntToString(g_bRules[client], sBuffer, sizeof(sBuffer));
				SetClientCookie(client, g_hRules, sBuffer);
				
				return 0;
			}
			
			g_bKnowRules[client] = true;
			g_bReadRules[client] = false;
		}

		if (g_cshowDetectiveMenu.BoolValue)
		{
			AskClientForMicrophone(client);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (TTT_IsClientValid(client) && g_crulesClosePunishment.IntValue == 0)
		{
			if (!TTT_CheckCommandAccess(client, "ttt_kick_immunity", g_ckickImmunity, true))
			{
				char sMessage[128];
				Format(sMessage, sizeof(sMessage), "%T", "WM Kick Message", client);
				KickClient(client, sMessage);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int Menu_RulesPage(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Cancel || action == MenuAction_Select || param == MenuCancel_ExitBack)
	{
		ShowRules(client, 0);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

public Action Timer_ShowDetectiveMenu(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		AskClientForMicrophone(client);
	}
}

stock void AskClientForMicrophone(int client)
{
	if (g_cDRulesMenu.BoolValue && g_bDRules[client])
	{
		return;
	}

	bool bShow = true;
	Action res = Plugin_Continue;
	Call_StartForward(g_hOnDetectiveMenu);
	Call_PushCell(client);
	Call_PushCellRef(bShow);
	Call_Finish(res);

	if (res == Plugin_Changed && !bShow)
	{
		return;
	}
	
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
	menu.Display(client, g_ctimeToReadDetectiveRules.IntValue);
}


public int Menu_AskClientForMicrophone(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sParam[32];
		GetMenuItem(menu, param, sParam, sizeof(sParam));

		if (!StrEqual(sParam, "yes", false))
		{
			g_bAvoidDetective[client] = true;
		}
		else
		{
			g_bAvoidDetective[client] = false;
			
			if (g_cDRulesMenu.BoolValue)
			{
				g_bDRules[client] = true;
				
				char sBuffer[12];
				IntToString(g_bDRules[client], sBuffer, sizeof(sBuffer));
				SetClientCookie(client, g_hDRules, sBuffer);
				
				return 0;
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		g_bAvoidDetective[client] = true;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void OnClientCookiesCached(int client)
{
	char sBuffer[12];
	GetClientCookie(client, g_hRSCookie, sBuffer, sizeof(sBuffer));
	g_iRoundSlays[client] = StringToInt(sBuffer);
	
	GetClientCookie(client, g_hRules, sBuffer, sizeof(sBuffer));
	g_bRules[client] = view_as<bool>(StringToInt(sBuffer));
	
	GetClientCookie(client, g_hDRules, sBuffer, sizeof(sBuffer));
	g_bDRules[client] = view_as<bool>(StringToInt(sBuffer));
}

public void OnClientDisconnect(int client)
{
	UpdateRoundSlaysCookie(client);
	
	if (IsClientInGame(client))
	{
		g_bKarma[client] = false;
		g_bFound[client] = true;
		g_bAlive[client] = false;

		if (g_cTranfserArmor.BoolValue)
		{
			g_iArmor[client] = 0;
		}

		TTT_ClearTimer(g_hRDMTimer[client]);

		g_bReceivingLogs[client] = false;
		g_bImmuneRDMManager[client] = false;
	}
}

public Action Event_ChangeName_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	if (g_cNameChangePunish.IntValue > 0 && g_bRoundStarted)
	{
		char sOld[MAX_NAME_LENGTH], sNew[MAX_NAME_LENGTH];
		event.GetString("oldname", sOld, sizeof(sOld));
		event.GetString("newname", sNew, sizeof(sNew));

		if (g_cNameChangePunish.IntValue == 1)
		{
			LoopValidClients(i)
			{
				CPrintToChat(i, "%T", "Name Change Message", i, sOld, sNew);
			}
		}
		else if (g_cNameChangePunish.IntValue == 2)
		{
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteString(sOld);

			RequestFrame(Frame_RechangeName, pack);

			return Plugin_Handled;
		}
		else if (g_cNameChangePunish.IntValue == 3)
		{
			char sReason[512];
			Format(sReason, sizeof(sReason), "%T", "Name Change Kick Reason", client);
			KickClient(client, sReason);
		}
		else if (g_cNameChangePunish.IntValue == 4)
		{
			char sReason[512];
			Format(sReason, sizeof(sReason), "%T", "Name Change Reason", client);

			if (g_bSourcebans)
			{
				SBBanPlayer(0, client, g_cNameChangeLength.IntValue, sReason);
			}
			else
			{
				ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(client), g_cNameChangeLength.IntValue, sReason);
			}
		}
	}

	char sNew[MAX_NAME_LENGTH];
	event.GetString("newname", sNew, sizeof(sNew));
	nameCheck(client, sNew);

	int iSize = g_aRagdoll.Length;

	if (iSize == 0)
	{
		return Plugin_Handled;
	}

	int iRagdollC[Ragdolls];

	for (int i = 0; i < g_aRagdoll.Length; i++)
	{
		g_aRagdoll.GetArray(i, iRagdollC[0]);

		if (client == GetClientOfUserId(iRagdollC[Attacker]))
		{
			Format(iRagdollC[AttackerName], MAX_NAME_LENGTH, sNew);
			g_aRagdoll.SetArray(i, iRagdollC[0]);
		}
		else if (client == GetClientOfUserId(iRagdollC[Victim]))
		{
			Format(iRagdollC[VictimName], MAX_NAME_LENGTH, sNew);
			g_aRagdoll.SetArray(i, iRagdollC[0]);
		}
	}

	return Plugin_Continue;
}

public void Frame_RechangeName(DataPack pack)
{
	int userid = pack.ReadCell();

	char sName[MAX_NAME_LENGTH];
	pack.ReadString(sName, sizeof(sName));

	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		SetClientName(client, sName);
	}
}

public Action Timer_1(Handle timer)
{
	int g_iInnoAlive = 0;
	int g_iTraitorAlive = 0;
	int g_iDetectiveAlive = 0;

	float vec[3];
	LoopValidClients(i)
	{
		if (IsPlayerAlive(i))
		{
			if (g_iRole[i] == TTT_TEAM_UNASSIGNED && !g_bRoundStarted && g_cdenyFire.BoolValue)
			{
				for(int offset = 0; offset < 128; offset += 4)
				{
					int weapon = GetEntDataEnt2(i, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);
			
					if (IsValidEntity(weapon))
					{
						char sClass[32];
						GetEntityClassname(weapon, sClass, sizeof(sClass));
			
						if (StrContains(sClass, "weapon_", false) != -1)
						{
							SetEntDataFloat(weapon, m_flNextPrimaryAttack, GetGameTime() + 2.0);
							SetEntDataFloat(weapon, m_flNextSecondaryAttack, GetGameTime() + 2.0);
						}
					}
				}
			}
			if (g_iRole[i] == TTT_TEAM_TRAITOR)
			{
				g_iTraitorAlive++;
				int[] clients = new int[MaxClients];
				int index = 0;

				LoopValidClients(j)
				{
					if (IsPlayerAlive(j) && j != i && (g_iRole[j] == TTT_TEAM_TRAITOR))
					{
						clients[index] = j;
						index++;
					}
				}

				GetClientAbsOrigin(i, vec);
				vec[2] += 10;

				TE_SetupBeamRingPoint(vec, 50.0, 60.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.1, 10.0, 0.0, { 0, 0, 255, 255 }, 10, 0);
				TE_Send(clients, index);
			}
			else if (g_iRole[i] == TTT_TEAM_INNOCENT)
			{
				g_iInnoAlive++;
			}
			else if (g_iRole[i] == TTT_TEAM_DETECTIVE)
			{
				g_iDetectiveAlive++;
			}
		}
	}

	if (g_bRoundStarted)
	{
		if (g_iInnoAlive == 0 && ((g_cendwithD.BoolValue) || (g_iDetectiveAlive == 0)))
		{
			g_bRoundStarted = false;

			if (!g_cDebug.BoolValue)
			{
				CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
			}
		}
		else if (g_iTraitorAlive == 0)
		{
			g_bRoundStarted = false;

			if (!g_cDebug.BoolValue)
			{
				CS_TerminateRound(7.0, CSRoundEnd_CTWin);
			}
		}
	}
}


public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!TTT_IsClientValid(client))
	{
		return;
	}

	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!TTT_IsClientValid(iAttacker) || iAttacker == client)
	{
		return;
	}

	Action res = Plugin_Continue;

	Call_StartForward(g_hOnClientDeathPre);
	Call_PushCell(client);
	Call_PushCell(iAttacker);
	Call_Finish(res);

	if (res == Plugin_Stop || res == Plugin_Changed)
	{
		return;
	}

	if (g_cshowDeathMessage.BoolValue)
	{
		if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR)
		{
			CPrintToChat(client, "%s %T", g_sTag, "Your killer is a Traitor", client);
		}
		else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE)
		{
			CPrintToChat(client, "%s %T", g_sTag, "Your killer is a Detective", client);
		}
		else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT)
		{
			CPrintToChat(client, "%s %T", g_sTag, "Your killer is an Innocent", client);
		}
	}

	if (g_cshowKillMessage.BoolValue)
	{
		if (g_iRole[client] == TTT_TEAM_TRAITOR)
		{
			CPrintToChat(iAttacker, "%s %T", g_sTag, "You killed a Traitor", iAttacker);
		}
		else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
		{
			CPrintToChat(iAttacker, "%s %T", g_sTag, "You killed a Detective", iAttacker);
		}
		else if (g_iRole[client] == TTT_TEAM_INNOCENT)
		{
			CPrintToChat(iAttacker, "%s %T", g_sTag, "You killed an Innocent", iAttacker);
		}
	}

	char iItem[TTT_LOG_SIZE];
	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	
	char sAttackerID[32], sClientID[32];
	
	if (g_cAddSteamIDtoLogs.BoolValue)
	{
		if (g_cSteamIDLogFormat.IntValue == 1)
		{
			GetClientAuthId(iAttacker, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
			GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
		}
		else if (g_cSteamIDLogFormat.IntValue == 2)
		{
			GetClientAuthId(iAttacker, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
			GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
		}
		else if (g_cSteamIDLogFormat.IntValue == 3)
		{
			GetClientAuthId(iAttacker, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
			GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
		}
		
		if (strlen(sAttackerID) > 2 && strlen(sClientID) > 2)
		{
			Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
			Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
		}
	}

	if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) killed %N%s (Innocent) with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);
		
		if (g_bHurtedPlayer1[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
		} else if (g_bHurtedPlayer2[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
		} else {
			subtractKarma(iAttacker, g_ckarmaII.IntValue, true);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) killed %N%s (Traitor) with %s]", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);

		addKarma(iAttacker, g_ckarmaIT.IntValue, true);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) killed %N%s (Detective) with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);
		
		if (g_bHurtedPlayer1[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
		} else if (g_bHurtedPlayer2[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
		} else {
			subtractKarma(iAttacker, g_ckarmaID.IntValue, true);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) killed %N%s (Innocent) with %s]", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);

		addKarma(iAttacker, g_ckarmaTI.IntValue, true);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) killed %N%s (Traitor) with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);
		
		if (g_bHurtedPlayer1[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt traitor", iAttacker);
		} else if (g_bHurtedPlayer2[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt traitor", iAttacker);
		} else {
			subtractKarma(iAttacker, g_ckarmaTT.IntValue, true);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) killed %N%s (Detective) with %s]", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);

		addKarma(iAttacker, g_ckarmaTD.IntValue, true);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) killed %N%s (Innocent) with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);
		
		if (g_bHurtedPlayer1[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
		} else if (g_bHurtedPlayer2[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
		} else {
			subtractKarma(iAttacker, g_ckarmaDI.IntValue, true);
		}
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) killed %N%s (Traitor) with %s]", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);

		addKarma(iAttacker, g_ckarmaDT.IntValue, true);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) killed %N%s (Detective) with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, sWeapon);
		addArrayTime(iItem);
		
		if (g_bHurtedPlayer1[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
		} else if (g_bHurtedPlayer2[client] == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
			CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
		} else {
			subtractKarma(iAttacker, g_ckarmaDD.IntValue, true);
		}
	}

	if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
	{
		CS_SetClientClanTag(client, "UNASSIGNED");
		g_bFound[client] = true;
	}

	CheckTeams();

	Call_StartForward(g_hOnClientDeath);
	Call_PushCell(client);
	Call_PushCell(iAttacker);
	Call_Finish();
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!TTT_IsClientValid(client))
	{
		return;
	}
	
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!TTT_IsClientValid(iAttacker) || iAttacker == client)
	{
		return;
	}
	
	if (g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
		return;
	}
	
	if ((g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_INNOCENT) ||
	   (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE) ||
	   (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)    ||
	   (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_INNOCENT) ||
	   (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE))
	{
		if (g_bHurtedPlayer1[iAttacker] == -1 && iAttacker != g_bHurtedPlayer1[client]) {
			g_bHurtedPlayer1[iAttacker] = client;
		} else if (g_bHurtedPlayer2[iAttacker] == -1 && iAttacker != g_bHurtedPlayer2[client] && iAttacker != g_bHurtedPlayer1[client]) {
			g_bHurtedPlayer2[iAttacker] = client;
		} else if (iAttacker != g_bHurtedPlayer1[client] && !g_bResetHurt[iAttacker] && g_bHurtedPlayer1[iAttacker] > 0 && g_bHurtedPlayer2[iAttacker] > 0) {
			g_bResetHurt[iAttacker] = true;
			g_bHurtedPlayer1[iAttacker] = client;
		} else if (iAttacker != g_bHurtedPlayer2[client]  && iAttacker != g_bHurtedPlayer1[client] && g_bResetHurt[iAttacker] && g_bHurtedPlayer1[iAttacker] > 0 && g_bHurtedPlayer2[iAttacker] > 0) {
			g_bResetHurt[iAttacker] = false;
			g_bHurtedPlayer2[iAttacker] = client;
		}
	}
}

public void OnMapEnd()
{
	g_bRoundEnding = false;
	if (g_hRoundTimer != null)
	{
		delete g_hRoundTimer;
		g_hRoundTimer = null;
	}

	g_hStartTimer = null;
	g_hCountdownTimer = null;

	LoopValidClients(i)
	{
		if (g_cTranfserArmor.BoolValue)
			g_iArmor[i] = 0;
		g_bKarma[i] = false;
	}
}

public Action Timer_OnRoundEnd(Handle timer)
{
	g_hRoundTimer = null;
	g_bRoundStarted = false;

	if (!g_cDebug.BoolValue)
	{
		CS_TerminateRound(7.0, CSRoundEnd_CTWin);
	}
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	if (g_bRoundStarted)
	{
		return Plugin_Handled;
	}

	bool bInnoAlive = false;
	bool bDeteAlive = false;

	int WinningTeam = TTT_TEAM_UNASSIGNED;

	LoopValidClients(client)
	{
		if ((!g_cpublicKarma.BoolValue) && g_ckarmaRound.BoolValue)
		{
			g_iKarmaStart[client] = g_iKarma[client];
			CPrintToChat(client, "%s %T", g_sTag, "All karma has been updated", client);
		}

		if (IsPlayerAlive(client))
		{
			if (g_iRole[client] == TTT_TEAM_INNOCENT)
			{
				bInnoAlive = true;
			}
			else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
			{
				bDeteAlive = true;
			}
		}
	}

	if (bInnoAlive)
	{
		WinningTeam = TTT_TEAM_INNOCENT;
	}
	else if (!bInnoAlive && bDeteAlive)
	{
		if (g_cendwithD.BoolValue)
		{
			WinningTeam = TTT_TEAM_DETECTIVE;
		}
		else
		{
			WinningTeam = TTT_TEAM_INNOCENT;
		}
	}
	else
	{
		WinningTeam = TTT_TEAM_TRAITOR;
	}

	Call_StartForward(g_hOnRoundEnd);
	Call_PushCell(WinningTeam);
	Call_Finish();

	if (g_crandomWinner.BoolValue)
	{
		reason = view_as<CSRoundEndReason>(GetRandomInt(view_as<int>(CSRoundEnd_CTWin), view_as<int>(CSRoundEnd_TerroristWin)));
	}

	if (g_croundDelay.FloatValue > 0.0)
	{
		delay = g_croundDelay.FloatValue;
	}

	if (g_cnextRoundAlert.BoolValue)
	{
		LoopValidClients(client)
		{
			CPrintToChat(client, "%s %T", g_sTag, "next round in", client, delay);
		}
	}

	g_bRoundEnding = true;

	return Plugin_Changed;
}

public Action Event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!g_bSelection)
	{
		CheckClantag(client);
	}

	if (g_chideTeams.BoolValue && (!event.GetBool("silent")))
	{
		event.BroadcastDisabled = true;
		dontBroadcast = true;
	}

	return Plugin_Changed;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}
	
	if (g_cdenyFire.BoolValue && g_iRole[client] == TTT_TEAM_UNASSIGNED && ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)))
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		return Plugin_Changed;
	}

	int button = -1;
	for (int i = 0; i < 25; i++)
	{
		button = (1 << i);

		if ((buttons & button) || (buttons & IN_USE|IN_SPEED) == IN_USE|IN_SPEED)
		{
			if (!(g_iLastButtons[client] & button))
			{
				Call_StartForward(g_hOnButtonPress);
				Call_PushCell(client);
				if ((buttons & IN_USE|IN_SPEED) == IN_USE|IN_SPEED) {
					Call_PushCell(buttons);
				} else {
					Call_PushCell(button);
				}
				Call_Finish();
			}
		}
		else if ((g_iLastButtons[client] & button))
		{
			Call_StartForward(g_hOnButtonRelease);
			Call_PushCell(client);
			Call_PushCell(button);
			Call_Finish();
		}
	}

	g_iLastButtons[client] = buttons;

	return Plugin_Continue;
}

public int TTT_OnButtonPress(int client, int button)
{
	if (!IsClientInGame(client))
	{
		return;
	}

	if (button & IN_USE)
	{

		int iEntity = GetClientAimTarget(client, false);
		if (iEntity > 0)
		{
			float OriginG[3], TargetOriginG[3];
			GetClientEyePosition(client, TargetOriginG);
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", OriginG);
			if (GetVectorDistance(TargetOriginG, OriginG, false) > 90.0)
				return;

			int iSize = g_aRagdoll.Length;
			if (iSize == 0)
			{
				return;
			}

			int iRagdollC[Ragdolls];
			int entity;

			for (int i = 0; i < iSize; i++)
			{
				g_aRagdoll.GetArray(i, iRagdollC[0]);
				entity = EntRefToEntIndex(iRagdollC[Ent]);
				if (entity == iEntity)
				{
					if (IsPlayerAlive(client) && !g_bIsChecking[client])
					{
						g_bIsChecking[client] = true;
						Action res = Plugin_Continue;
						Call_StartForward(g_hOnBodyChecked);
						Call_PushCell(client);
						Call_PushArrayEx(iRagdollC[0], sizeof(iRagdollC), SM_PARAM_COPYBACK);
						Call_Finish(res);
						if (res == Plugin_Stop)
						{
							return;
						}
						else if (res == Plugin_Changed)
						{
							g_aRagdoll.SetArray(i, iRagdollC[0]);
							return;
						}
						
						int victim = GetClientOfUserId(iRagdollC[Victim]);
						int attacker = GetClientOfUserId(iRagdollC[Attacker]);
						
						if (g_cDebugMessages.BoolValue)
						{
							LogMessage("Victim: %d, Victim (UserID): %d, Attacker: %d, Attacker (UserID): %d", victim, iRagdollC[Victim], attacker, iRagdollC[Attacker]);
						}
						
						InspectBody(client, victim, iRagdollC[VictimTeam], attacker, RoundToNearest(GetGameTime() - iRagdollC[GameTime]), iRagdollC[Weaponused], iRagdollC[VictimName], iRagdollC[AttackerName]);

						if (!iRagdollC[Found] && IsPlayerAlive(client))
						{
							bool bInWalk = ((button & IN_SPEED) > 0);
							bool silentID = false;
							
							iRagdollC[Found] = true;

							bool bValid = false;

							if (TTT_IsClientValid(victim))
							{
								bValid = true;
							}
							
							if (bValid)
							{
								g_bFound[victim] = true;
							}

							char iItem[TTT_LOG_SIZE];

							char sRole[ROLE_LENGTH];
							TTT_GetRoleNameByID(g_iRole[client], sRole, sizeof(sRole));
							
							if (iRagdollC[VictimTeam] == TTT_TEAM_INNOCENT)
							{
								if (!g_cSilentIdEnabled.BoolValue || !(bInWalk && TTT_IsValidRole(client, g_cSilentIdRoles.IntValue)))
								{
									LoopValidClients(j)
									{
										CPrintToChat(j, "%s %T", g_sTag, "Found Innocent", j, client, iRagdollC[VictimName]);
									}
									
									Format(iItem, sizeof(iItem), "-> %N (%s) identified body of %s (Innocent)", client, sRole, iRagdollC[VictimName]);
									
									SetEntityRenderColor(iEntity, 0, 255, 0, 255);
								}
								else
								{
								    CPrintToChat(client, "%s %T", g_sTag, "Found Innocent Silent", client, iRagdollC[VictimName]);
								    
								    Format(iItem, sizeof(iItem), "-> %N (%s) identified body of %s (Innocent) - SILENT", client, sRole, iRagdollC[VictimName]);
								    
								    if (g_cSilentIdColor.BoolValue)
								    {
								    	SetEntityRenderColor(iEntity, 0, 255, 0, 255);
								    }
								    
								    silentID = true;
								}

								if (g_cIdentifyLog.BoolValue)
								{
									addArrayTime(iItem);
								}
							}
							else if (iRagdollC[VictimTeam] == TTT_TEAM_DETECTIVE)
							{
								if (!g_cSilentIdEnabled.BoolValue || !(bInWalk && TTT_IsValidRole(client, g_cSilentIdRoles.IntValue)))
								{
									LoopValidClients(j)
									{
										CPrintToChat(j, "%s %T", g_sTag, "Found Detective", j, client, iRagdollC[VictimName]);
									}
									
									Format(iItem, sizeof(iItem), "-> %N (%s) identified body of %s (Detective)", client, sRole, iRagdollC[VictimName]);
									
									SetEntityRenderColor(iEntity, 0, 0, 255, 255);
								}
								else
								{
								    CPrintToChat(client, "%s %T", g_sTag, "Found Detective Silent", client, iRagdollC[VictimName]);
								    
								    Format(iItem, sizeof(iItem), "-> %N (%s) identified body of %s (Detective) - SILENT", client, sRole, iRagdollC[VictimName]);
								    
								    if (g_cSilentIdColor.BoolValue)
								    {
								    	SetEntityRenderColor(iEntity, 0, 0, 255, 255);
								    }
								    
								    silentID = true;
								}
								
								if (g_cIdentifyLog.BoolValue)
								{
									addArrayTime(iItem);
								}						
							}
							else if (iRagdollC[VictimTeam] == TTT_TEAM_TRAITOR)
							{
								if (!g_cSilentIdEnabled.BoolValue || !(bInWalk && TTT_IsValidRole(client, g_cSilentIdRoles.IntValue)))
								{
									LoopValidClients(j)
									{
										CPrintToChat(j, "%s %T", g_sTag, "Found Traitor", j, client, iRagdollC[VictimName]);
									}
									
									Format(iItem, sizeof(iItem), "-> %N (%s) identified body of %s (Traitor)", client, sRole, iRagdollC[VictimName]);
									
									SetEntityRenderColor(iEntity, 255, 0, 0, 255);
								}
								else
								{
								    CPrintToChat(client, "%s %T", g_sTag, "Found Traitor Silent", client, iRagdollC[VictimName]);
								    
								    Format(iItem, sizeof(iItem), "-> %N (%s) identified body of %s (Traitor) - SILENT", client, sRole, iRagdollC[VictimName]);
								    
								    if (g_cSilentIdColor.BoolValue)
								    {
								    	SetEntityRenderColor(iEntity, 255, 0, 0, 255);
								    }
								    
								    silentID = true;
								}
								if (g_cIdentifyLog.BoolValue)
								{
									addArrayTime(iItem);
								}
							}

							if (bValid)
							{
								TeamTag(victim);
							}

							Call_StartForward(g_hOnBodyFound);
							Call_PushCell(client);
							
							if (bValid)
							{
								Call_PushCell(victim);
							}
							else
							{
								Call_PushCell(-1);
							}
							
							Call_PushString(iRagdollC[VictimName]);
							Call_PushCell(silentID);
							Call_Finish();
						}
						g_aRagdoll.SetArray(i, iRagdollC[0]);
						break;
					}
				}
			}
		}
	}
}

public int TTT_OnButtonRelease(int client, int button)
{
	if (button & IN_USE)
	{
		g_bIsChecking[client] = false;
	}
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	char sText[MAX_MESSAGE_LENGTH];
	GetCmdArgString(sText, sizeof(sText));

	StripQuotes(sText);

	if (sText[0] == '@')
	{
		return Plugin_Continue;
	}

	return Plugin_Continue;
}

public Action Command_SayTeam(int client, const char[] command, int argc)
{
	if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	char sText[MAX_MESSAGE_LENGTH];
	GetCmdArgString(sText, sizeof(sText));

	StripQuotes(sText);

	if (strlen(sText) < 2)
	{
		return Plugin_Handled;
	}

	if (sText[0] == '@')
	{
		return Plugin_Continue;
	}

	if (g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		LoopValidClients(i)
		{
			if (g_iRole[i] == TTT_TEAM_TRAITOR || g_ctChatToDead.BoolValue && !IsPlayerAlive(i))
			{
				EmitSoundToClient(i, SND_TCHAT);
				CPrintToChat(i, "%T", "T channel", i, client, sText);
			}
		}

		return Plugin_Handled;
	}
	else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		LoopValidClients(i)
		{
			if (g_iRole[i] == TTT_TEAM_DETECTIVE || g_cdChatToDead.BoolValue && !IsPlayerAlive(i))
			{
				EmitSoundToClient(i, SND_TCHAT);
				CPrintToChat(i, "%T", "D channel", i, client, sText);
			}
		}

		return Plugin_Handled;
	}
	return Plugin_Handled;
}

stock void InspectBody(int client, int victim, int victimRole, int attacker, int time, const char[] weapon, const char[] victimName, const char[] attackerName)
{
	char team[32];
	if (victimRole == TTT_TEAM_TRAITOR)
	{
		Format(team, sizeof(team), "%T", "Traitors", client);
	}
	else if (victimRole == TTT_TEAM_DETECTIVE)
	{
		Format(team, sizeof(team), "%T", "Detectives", client);
	}
	else if (victimRole == TTT_TEAM_INNOCENT)
	{
		Format(team, sizeof(team), "%T", "Innocents", client);
	}

	Menu menu = new Menu(BodyMenuHandler);
	char sBuffer[128];

	menu.SetTitle("%T", "Inspected body. The extracted data are the following", client);

	Format(sBuffer, sizeof(sBuffer), "%T", "Victim name", client, victimName);
	menu.AddItem("", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "Team victim", client, team);
	menu.AddItem("", sBuffer);

	if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "Elapsed since his death", client, time);
		menu.AddItem("", sBuffer);

		if (TTT_IsClientValid(attacker) && attacker != victim)
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "The weapon used has been", client, weapon);
			menu.AddItem("", sBuffer);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "The weapon used has been: himself (suicide)", client);
			menu.AddItem("", sBuffer);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, 15);

}

public int BodyMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

stock int addKarma(int client, int karma, bool message = false)
{
	if (!g_bRoundStarted)
	{
		return -1;
	}

	g_iKarma[client] += karma;

	if (g_iKarma[client] > g_cmaxKarma.IntValue)
	{
		g_iKarma[client] = g_cmaxKarma.IntValue;
	}

	if (g_cshowEarnKarmaMessage.BoolValue && message)
	{
		if (g_cmessageTypKarma.IntValue == 1)
		{
			PrintHintText(client, "%T", "karma earned", client, karma, g_iKarma[client]);
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sTag, "karma earned", client, karma, g_iKarma[client]);
		}
	}

	UpdatePlayer(client);
	
	Call_StartForward(g_hOnKarmaUpdate);
	Call_PushCell(client);
	Call_PushCell(Karma_Add);
	Call_PushCell(karma);
	Call_Finish();
	
	return g_iKarma[client];
}

stock int setKarma(int client, int karma, bool force = false)
{
	if (!force && !g_bRoundStarted)
	{
		return -1;
	}

	g_iKarma[client] = karma;

	if (g_iKarma[client] > g_cmaxKarma.IntValue)
	{
		g_iKarma[client] = g_cmaxKarma.IntValue;
	}

	UpdatePlayer(client);
	
	Call_StartForward(g_hOnKarmaUpdate);
	Call_PushCell(client);
	Call_PushCell(Karma_Set);
	Call_PushCell(karma);
	Call_Finish();
	
	return g_iKarma[client];
}

stock int subtractKarma(int client, int karma, bool message = false)
{
	if (!g_bRoundStarted)
	{
		return -1;
	}

	g_iKarma[client] -= karma;

	if (g_cshowLoseKarmaMessage.BoolValue && message)
	{
		if (g_cmessageTypKarma.IntValue == 1)
		{
			PrintHintText(client, "%T", "lost karma", client, karma, g_iKarma[client]);
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sTag, "lost karma", client, karma, g_iKarma[client]);
		}
	}

	UpdatePlayer(client);
	
	Call_StartForward(g_hOnKarmaUpdate);
	Call_PushCell(client);
	Call_PushCell(Karma_Subtract);
	Call_PushCell(karma);
	Call_Finish();
	
	return g_iKarma[client];
}

stock void addArrayTime(char[] message)
{
	if (g_iTeamSelectTime > 0)
	{
		int iTime = GetTime() - g_iTeamSelectTime;
		int iMin = ((iTime / 60) % 60);
		int iSec = (iTime % 60);

		Format(message, TTT_LOG_SIZE, "[%02i:%02i] %s", iMin, iSec, message);
	}
	g_aLogs.PushString(message);
}

public Action Command_LAW(int client, const char[] command, int argc)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}

	if (g_callowFlash.BoolValue && IsPlayerAlive(client))
	{
		EmitSoundToAllAny(SND_FLASHLIGHT, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);
		SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);
	}

	if (g_cblockLookAtWeapon.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock void manageRDM(int client)
{
	if (!IsClientInGame(client))
	{
		return;
	}

	if (g_cignoreRDMMenu.BoolValue)
	{
		return;
	}

	int iAttacker = g_iRDMAttacker[client];
	if (!IsClientInGame(iAttacker) || iAttacker < 0 || iAttacker > MaxClients)
	{
		CPrintToChat(client, "%s %T", g_sTag, "The player who RDM'd you is no longer available", client);
		return;
	}
	char sAttackerName[MAX_NAME_LENGTH];
	GetClientName(iAttacker, sAttackerName, sizeof(sAttackerName));

	char display[256], sForgive[64], sPunish[64];
	Format(display, sizeof(display), "%T", "You were RDM'd", client, sAttackerName);
	Format(sForgive, sizeof(sForgive), "%T", "Forgive", client);
	Format(sPunish, sizeof(sPunish), "%T", "Punish", client);

	Menu menu = new Menu(manageRDMHandle);
	menu.SetTitle(display);
	menu.AddItem("Forgive", sForgive);
	menu.AddItem("Punish", sPunish);
	menu.Display(client, 10);
}

public int manageRDMHandle(Menu menu, MenuAction action, int client, int option)
{
	if (1 > client || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	int iAttacker = g_iRDMAttacker[client];
	if (1 > iAttacker || iAttacker > MaxClients || !IsClientInGame(iAttacker))
	{
		return;
	}

	if (action == MenuAction_Select)
	{
		char info[100];
		GetMenuItem(menu, option, info, sizeof(info));
		if (StrEqual(info, "Forgive", false))
		{
			CPrintToChat(client, "%s %T", g_sTag, "Choose Forgive Victim", client, iAttacker);
			CPrintToChat(iAttacker, "%s %T", g_sTag, "Choose Forgive Attacker", iAttacker, client);
			g_iRDMAttacker[client] = -1;
		}
		if (StrEqual(info, "Punish", false))
		{
			LoopValidClients(i)
				CPrintToChat(i, "%s %T", g_sTag, "Choose Punish", i, client, iAttacker);
			TTT_AddRoundSlays(iAttacker, g_cRoundSlayPlayerRDM.IntValue, true);
			g_iRDMAttacker[client] = -1;
		}
	}
	else if (action == MenuAction_Cancel)
	{
		CPrintToChat(client, "%s %T", g_sTag, "Choose Forgive Victim", client, iAttacker);
		CPrintToChat(iAttacker, "%s %T", g_sTag, "Choose Forgive Attacker", iAttacker, client);
		g_iRDMAttacker[client] = -1;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
		CPrintToChat(client, "%s %T", g_sTag, "Choose Forgive Victim", client, iAttacker);
		CPrintToChat(iAttacker, "%s %T", g_sTag, "Choose Forgive Attacker", iAttacker, client);
		g_iRDMAttacker[client] = -1;
		
		delete menu;
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
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (!TTT_CheckCommandAccess(client, "ttt_set_role", g_cSetRole, true))
	{
		return Plugin_Handled;
	}

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
	{
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(target))
	{
		ReplyToCommand(client, "[SM] This command can only be used to alive players!");
		return Plugin_Handled;
	}

	int iRole = StringToInt(arg2);
	int iOld = TTT_GetClientRole(target);
	
	if (iRole < 1 || iRole > 3)
	{
		ReplyToCommand(client, "[SM] Roles: 1 - Innocent | 2 - Traitor | 3 - Detective");
		return Plugin_Handled;
	}
	else if (iRole == 1)
	{
		if (iOld == TTT_TEAM_INNOCENT)
		{
			return Plugin_Handled;
		}
		
		g_iRole[target] = TTT_TEAM_INNOCENT;
		
		TeamInitialize(target);
		CS_SetClientClanTag(target, " ");
		CPrintToChat(client, "%s %T", g_sTag, "Player is Now Innocent", client, target);
		LogAction(client, target, "\"%L\" set the role of \"%L\" to \"%s\"", client, target, "Innocent");
		
		return Plugin_Handled;
	}
	else if (iRole == 2)
	{
		if (iOld == TTT_TEAM_TRAITOR)
		{
			return Plugin_Handled;
		}
		
		g_iRole[target] = TTT_TEAM_TRAITOR;
		
		TeamInitialize(target);
		CS_SetClientClanTag(target, " ");
		CPrintToChat(client, "%s %T", g_sTag, "Player is Now Traitor", client, target);
		LogAction(client, target, "\"%L\" set the role of \"%L\" to \"%s\"", client, target, "Traitor");
		
		return Plugin_Handled;
	}
	else if (iRole == 3)
	{
		if (iOld == TTT_TEAM_DETECTIVE)
		{
			return Plugin_Handled;
		}
		
		g_iRole[target] = TTT_TEAM_DETECTIVE;
		
		TeamInitialize(target);
		CPrintToChat(client, "%s %T", g_sTag, "Player is Now Detective", client, target);
		LogAction(client, target, "\"%L\" set the role of \"%L\" to \"%s\"", client, target, "Detective");
		
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_SetKarma(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (!TTT_CheckCommandAccess(client, "ttt_set_karma", g_cSetKarma, true))
	{
		return Plugin_Handled;
	}

	if (args < 2 || args > 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setkarma <#userid|name> <karma>");

		return Plugin_Handled;
	}

	char arg1[32];
	char arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		int target = target_list[i];

		if (target == -1)
		{
			ReplyToCommand(client, "[SM] Invalid target.");
			return Plugin_Handled;
		}

		if (!g_bKarma[target])
		{
			ReplyToCommand(client, "[SM] Player data not loaded yet.");
			return Plugin_Handled;
		}

		int karma = StringToInt(arg2);

		setKarma(target, karma, true);

		CPrintToChat(client, "%s %T", g_sTag, "AdminSet", client, target, karma, "Karma");
		LogAction(client, target, "\"%L\" set the karma of \"%L\" to \"%i\"", client, target, karma);
	}

	return Plugin_Continue;
}

public Action Command_Status(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
	{
		CPrintToChat(client, "%s %T", g_sTag, "You Are Unassigned", client);
	}
	else if (g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		CPrintToChat(client, "%s %T", g_sTag, "You Are Now Innocent", client);
	}
	else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		CPrintToChat(client, "%s %T", g_sTag, "You Are Now Detective", client);
	}
	else if (g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		CPrintToChat(client, "%s %T", g_sTag, "You Are Now Traitor", client);
	}

	return Plugin_Handled;
}

public Action Timer_5(Handle timer)
{
	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("Timer_5");
	}
	
	LoopValidClients(i)
	{
		if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T)
		{
			continue;
		}

		if (IsFakeClient(i))
		{
			continue;
		}

		if (!g_cBanKarmaDead.BoolValue && !IsPlayerAlive(i))
		{
			continue;
		}
		
		int iKarma = g_iKarma[i];
		
		if (iKarma < 0)
		{
			iKarma *= -1;
		}

		if (g_bKarma[i] && g_ckarmaBan.IntValue != 0 && iKarma <= g_ckarmaBan.IntValue)
		{
			BanBadPlayerKarma(i);
		}
	}
	
	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("g_bRoundStarted: %d - g_bRoundEnding: %d - g_bInactive: %d - g_hStartTimer: %d - g_hCountdownTimer: %d - g_hRoundTimer: %d", g_bRoundStarted, g_bRoundEnding, g_bInactive, g_hStartTimer, g_hCountdownTimer, g_hRoundTimer);
	}
	
	if (g_bRoundStarted)
	{
		CheckTeams();
	}
	else if (g_bCheckPlayers ||
			(g_cCheckDuringWarmup.BoolValue && TTT_IsWarmUp()) ||
			(g_cCheckPlayers.BoolValue && (!TTT_IsWarmUp() && !g_bRoundStarted && !g_bRoundEnding && !g_bInactive && g_hStartTimer == null && g_hCountdownTimer == null && g_hRoundTimer == null)))
	{
		CheckPlayers();
	}
}

void CheckPlayers()
{
	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("CheckPlayers - 1 ()");
	}
	
	int iCount = 0;
	LoopValidClients(i)
	{
		if (!g_cDebug.BoolValue && (IsFakeClient(i) || IsClientSourceTV(i)))
		{
			continue;
		}
		
		if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T)
		{
			continue;
		}

		iCount++;
	}
	
	if (g_cDebugMessages.BoolValue)
	{
		LogMessage("CheckPlayers - 2 (iCount: %d - Required: %d)", iCount, g_crequiredPlayers.IntValue);
	}
	
	if (iCount >= g_crequiredPlayers.IntValue)
	{
		g_bCheckPlayers = false;
		
		if (g_cDebugMessages.BoolValue)
		{
			LogMessage("CheckPlayers - 3 (CS_TerminateRound)");
		}

		CS_TerminateRound(3.0, CSRoundEnd_Draw);
	}
}

public void OnEntityCreated(int entity, const char[] name)
{
	if (StrEqual(name, "func_button"))
	{
		char targetName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
		
		if (StrEqual(targetName, "Destroy_Trigger", false))
		{
			SDKHook(entity, SDKHook_Use, OnUse);
		}
	}
	else
	{
		for (int i = 0; i < sizeof(g_sRemoveEntityList); i++)
		{
			if (!StrEqual(name, g_sRemoveEntityList[i]))
			{
				continue;
			}

			if (g_cremoveBomb.BoolValue && StrEqual("func_bombtarget", g_sRemoveEntityList[i], false))
			{
				AcceptEntityInput(entity, "kill");
			}
			else if (g_cremoveBuyzone.BoolValue && StrEqual("func_buyzone", g_sRemoveEntityList[i], false))
			{
				AcceptEntityInput(entity, "kill");
			}
			else if (g_cremoveHostages.BoolValue)
			{
				AcceptEntityInput(entity, "kill");
			}

			break;
		}
	}
}

public Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
	if (activator < 1 || activator > MaxClients || !IsClientInGame(activator))
	{
		return Plugin_Continue;
	}

	if (g_bInactive)
	{
		return Plugin_Handled;
	}
	else
	{
		if (g_iRole[activator] == TTT_TEAM_INNOCENT || g_iRole[activator] == TTT_TEAM_DETECTIVE || g_iRole[activator] == TTT_TEAM_UNASSIGNED)
		{
			TTT_AddRoundSlays(activator, g_cRoundSlayDestroyTrigger.IntValue, true);

			LoopValidClients(i)
			{
				CPrintToChat(i, "%s %T", g_sTag, "Triggered Falling Building", i, activator);
			}
		}
	}
	return Plugin_Continue;
}

stock void nameCheck(int client, char name[MAX_NAME_LENGTH])
{
	for (int i; i < g_iBadNameCount; i++)
	{
		if (StrContains(g_sBadNames[i], name, false) != -1)
		{
			KickClient(client, "%T", "Kick Bad Name", client, g_sBadNames[i]);
		}
	}
}

public Action Command_KarmaReset(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (!TTT_CheckCommandAccess(client, "ttt_karma_reset", g_cKarmaReset, true))
	{
		return Plugin_Handled;
	}

	LoopValidClients(i)
	{
		if (!IsFakeClient(i))
		{
			CPrintToChat(client, "%s %T", g_sTag, "AdminSet", client, i, g_cstartKarma.IntValue, "Karma");
			setKarma(i, g_cstartKarma.IntValue, true);
			LogAction(client, i, "\"%L\" reset the karma of \"%L\" to \"%i\"", client, i, g_cstartKarma.IntValue);
		}
	}
	
	return Plugin_Handled;
}

void CheckTeams()
{
	int iT = 0;
	int iD = 0;
	int iI = 0;

	LoopValidClients(i)
	{
		if (IsPlayerAlive(i))
		{
			if (g_iRole[i] == TTT_TEAM_DETECTIVE)
			{
				CS_SetClientClanTag(i, "DETECTIVE");
				iD++;
			}
			else if (g_iRole[i] == TTT_TEAM_TRAITOR)
			{
				iT++;
			}
			else if (g_iRole[i] == TTT_TEAM_INNOCENT)
			{
				iI++;
			}
		}
		else
		{
			if (g_iRole[i] == TTT_TEAM_UNASSIGNED)
			{
				g_bFound[i] = true;
				CS_SetClientClanTag(i, "UNASSIGNED");
			}
		}
	}

	if (g_cignoreDeaths.BoolValue)
	{
		return;
	}

	if (iD == 0 && iI == 0)
	{
		g_bRoundStarted = false;
		g_bRoundEnded = true;

		if (!g_cDebug.BoolValue)
		{
			CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
		}
	}
	else if (iT == 0)
	{
		g_bRoundStarted = false;
		g_bRoundEnded = true;

		if (!g_cDebug.BoolValue)
		{
			CS_TerminateRound(7.0, CSRoundEnd_CTWin);
		}
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

	if (hFile == null)
	{
		SetFailState("[TTT] Can't open File: %s", sFile);
	}

	char sLine[MAX_NAME_LENGTH];

	while (!IsEndOfFile(hFile) && ReadFileLine(hFile, sLine, sizeof(sLine)))
	{
		if (strlen(sLine) > 1)
		{
			strcopy(g_sBadNames[g_iBadNameCount], sizeof(g_sBadNames[]), sLine);
			g_iBadNameCount++;
		}
	}

	delete hFile;
}

stock void LoadClientKarma(int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsFakeClient(client))
	{
		if (g_cDebugMessages.BoolValue)
		{
			LogMessage("(LoadClientKarma) Client: \"%L\"", client);
		}
		
		char sCommunityID[64];

		if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
		{
			LogToFileEx(g_sErrorFile, "(LoadClientKarma) Auth failed: #%d", client);
			return;
		}

		char sQuery[2048];
		Format(sQuery, sizeof(sQuery), "SELECT `karma` FROM `ttt` WHERE `communityid`= \"%s\";", sCommunityID);

		if (g_cDebug.BoolValue)
		{
			LogToFileEx(g_sLogFile, sQuery);
		}

		if (g_dDB != null)
		{
			g_dDB.Query(SQL_OnClientPostAdminCheck, sQuery, userid);
		}
	}
}

stock void UpdatePlayer(int client)
{
	char sCommunityID[64];

	if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
	{
		LogToFileEx(g_sErrorFile, "(UpdatePlayer) Auth failed: #%d", client);
		return;
	}

	char sQuery[2048];
	
	if (TTT_GetConnectionType() == dMySQL)
	{
		Format(sQuery, sizeof(sQuery), "INSERT INTO ttt (communityid, karma) VALUES (\"%s\", %d) ON DUPLICATE KEY UPDATE karma = %d;", sCommunityID, g_iKarma[client], g_iKarma[client]);
	}
	else
	{
		Format(sQuery, sizeof(sQuery), "INSERT OR REPLACE INTO ttt (communityid, karma) VALUES (\"%s\", %d);", sCommunityID, g_iKarma[client], g_iKarma[client]);
	}

	if (g_cDebug.BoolValue)
	{
		LogToFileEx(g_sLogFile, sQuery);
	}

	if (g_dDB != null)
	{
		g_dDB.Query(Callback_UpdatePlayer, sQuery, GetClientUserId(client));
	}
}

stock void StripAllWeapons(int client)
{
	if (!g_cstripWeapons.BoolValue)
	{
		return;
	}

	int iEnt;
	for (int i = CS_SLOT_PRIMARY; i <= CS_SLOT_C4; i++)
	{
		while ((iEnt = GetPlayerWeaponSlot(client, i)) != -1)
		{
			TTT_SafeRemoveWeapon(client, iEnt, i);
		}
	}
}

stock void CheckClantag(int client)
{
	char sTag[32];
	CS_GetClientClanTag(client, sTag, sizeof(sTag));

	if (!ValidClantag(client, sTag))
	{
		if (!g_bRoundStarted)
		{
			CS_SetClientClanTag(client, " ");
		}
		else
		{

			if (!g_bFound[client])
			{
				if (g_iRole[client] == TTT_TEAM_UNASSIGNED)
				{
					CS_SetClientClanTag(client, "UNASSIGNED");
				}
				else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
				{
					CS_SetClientClanTag(client, "DETECTIVE");
				}
				else
				{
					CS_SetClientClanTag(client, " ");
				}
			}
			else if (g_bFound[client])
			{
				TeamTag(client);
			}
		}
	}
}

stock bool ValidClantag(int client, const char[] sTag)
{
	if (StrContains(sTag, "DETECTIVE", false) != -1 || StrContains(sTag, "TRAITOR", false) != -1 || StrContains(sTag, "INNOCENT", false) != -1 || StrContains(sTag, "UNASSIGNED", false) != -1)
	{
		return true;
	}

	if (StrEqual(sTag, " ", false))
	{
		return true;
	}

	return false;
}

void GiveWeaponsOnFailStart()
{
	if (g_cGiveWeaponsOnFailStart.BoolValue && g_cEnableDamage.BoolValue)
	{
		LoopValidClients(i)
		{
			if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T || IsFakeClient(i))
			{
				continue;
			}

			if (IsPlayerAlive(i))
			{
				GivePlayerItem(i, "weapon_knife");

				char sWeapon[32];
				
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSSecondary);
				GivePlayerItem(i, sWeapon);
				
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSPrimary);
				GivePlayerItem(i, sWeapon);
			}
		}
	}
}

void UpdateRoundSlaysCookie(int client)
{
	char sBuffer[12];
	IntToString(g_iRoundSlays[client], sBuffer, sizeof(sBuffer));
	SetClientCookie(client, g_hRSCookie, sBuffer);
}
