#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <multicolors>
#include <emitsoundany>
#include <ttt>
#include <ttt_sql>
#include <webfix>

#undef REQUIRE_PLUGIN
#tryinclude <sourcebans>

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
	// Round forwards
	g_hOnRoundStart_Pre = CreateGlobalForward("TTT_OnRoundStart_Pre", ET_Event);
	g_hOnRoundStart = CreateGlobalForward("TTT_OnRoundStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hOnRoundStartFailed = CreateGlobalForward("TTT_OnRoundStartFailed", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnRoundEnd = CreateGlobalForward("TTT_OnRoundEnd", ET_Ignore, Param_Cell);

	g_hOnClientGetRole = CreateGlobalForward("TTT_OnClientGetRole", ET_Ignore, Param_Cell, Param_Cell);

	g_hOnClientDeath = CreateGlobalForward("TTT_OnClientDeath", ET_Ignore, Param_Cell, Param_Cell);

	g_hOnBodyFound = CreateGlobalForward("TTT_OnBodyFound", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_hOnBodyChecked = CreateGlobalForward("TTT_OnBodyChecked", ET_Event, Param_Cell, Param_Array);

	g_hOnButtonPress = CreateGlobalForward("TTT_OnButtonPress", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnButtonRelease = CreateGlobalForward("TTT_OnButtonRelease", ET_Ignore, Param_Cell, Param_Cell);

	g_hOnUpdate5 = CreateGlobalForward("TTT_OnUpdate5", ET_Ignore, Param_Cell);
	g_hOnUpdate1 = CreateGlobalForward("TTT_OnUpdate1", ET_Ignore, Param_Cell);
	
	g_hOnModelUpdate = CreateGlobalForward("TTT_OnModelUpdate", ET_Ignore, Param_Cell, Param_String);

	// Body / Status
	CreateNative("TTT_WasBodyFound", Native_WasBodyFound);
	CreateNative("TTT_WasBodyScanned", Native_WasBodyScanned);
	CreateNative("TTT_GetFoundStatus", Native_GetFoundStatus);
	CreateNative("TTT_SetFoundStatus", Native_SetFoundStatus);

	// Ragdoll
	CreateNative("TTT_GetClientRagdoll", Native_GetClientRagdoll);
	CreateNative("TTT_SetRagdoll", Native_SetRagdoll);

	// Roles
	CreateNative("TTT_GetClientRole", Native_GetClientRole);
	CreateNative("TTT_SetClientRole", Native_SetClientRole);

	// Karma
	CreateNative("TTT_GetClientKarma", Native_GetClientKarma);
	CreateNative("TTT_SetClientKarma", Native_SetClientKarma);
	CreateNative("TTT_AddClientKarma", Native_AddClientKarma);
	CreateNative("TTT_RemoveClientKarma", Native_RemoveClientKarma);

	// Force roles
	CreateNative("TTT_ForceTraitor", Native_ForceTraitor);
	CreateNative("TTT_ForceDetective", Native_ForceDetective);

	// Others
	CreateNative("TTT_IsRoundActive", Native_IsRoundActive);
	CreateNative("TTT_LogString", Native_LogString);

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

	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEndPre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_changename", Event_ChangeName);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);

	g_hGraceTime = FindConVar("mp_join_grace_time");

	AddCommandListener(Command_LAW, "+lookatweapon");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_SayTeam, "say_team");
	AddCommandListener(Command_InterceptSuicide, "kill");
	AddCommandListener(Command_InterceptSuicide, "explode");
	AddCommandListener(Command_InterceptSuicide, "spectate");
	AddCommandListener(Command_InterceptSuicide, "jointeam");
	AddCommandListener(Command_InterceptSuicide, "joinclass");

	for (int i = 0; i < sizeof(g_sRadioCMDs); i++)
	{
		AddCommandListener(Command_RadioCMDs, g_sRadioCMDs[i]);
	}
	
	StartConfig("ttt");
	SetupConfig();
	EndConfig();

	if (TTT_GetSQLConnection() != null)
	{
		LateLoadClients(true);
	}
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
	// Get plugin tag
	g_cpluginTag.GetString(g_sTag, sizeof(g_sTag));
	
	// Prepare & Format log files
	char sDate[12], sBuffer[12];
	g_clogDateFormat.GetString(sBuffer, sizeof(sBuffer));
	FormatTime(sDate, sizeof(sDate), sBuffer);
	
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
	
	// Precache models
	char sModel[PLATFORM_MAX_PATH + 1];
	g_cmodelCT.GetString(sModel, sizeof(sModel));
	PrecacheModel(sModel, true);
	g_cmodelT.GetString(sModel, sizeof(sModel));
	PrecacheModel(sModel, true);
}

public void TTT_OnSQLConnect(Database db)
{
	g_dDB = db;

	LateLoadClients(false);
}

public Action Command_Logs(int client, int args)
{
	if (g_bRoundEnding || g_bRoundStarted)
	{
		char sAccess[18];
		g_clogsAccess.GetString(sAccess, sizeof(sAccess));
		
		if (client == 0)
		{
			ShowLogs(client);
		}
		else if (TTT_IsClientValid(client) && TTT_HasFlags(client, sAccess))
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
							CPrintToChat(j, g_sTag, "watching logs alive", j, client);
						}
					}
					else if (g_cLogsNotifyAlive.IntValue == 2)
					{
						LoopValidClients(j)
						{
							if (TTT_HasFlags(j, sAccess))
							{
								CPrintToChat(j, g_sTag, "watching logs alive", j, client);
							}
						}
					}
				}
			}
		}
		return Plugin_Continue;
	}

	CPrintToChat(client, g_sTag, "you cant see logs", client);
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
			CPrintToChat(client, g_sTag, "no logs yet", client);
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
		CPrintToChat(client, g_sTag, "Receiving logs", client);
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
			CPrintToChat(client, g_sTag, "See your console", client);
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
				CPrintToChat(client, g_sTag, "See your console", client);
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
		CPrintToChat(client, g_sTag, "Suicide Blocked", client);
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

	if (g_aLogs != null)
		g_aLogs.Clear();
	
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

	CPrintToChat(client, g_sTag, "Your karma is", client, g_iKarma[client]);

	return Plugin_Handled;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	if (g_aRagdoll != null)
	{
		g_aRagdoll.Clear();
	}

	g_bInactive = false;
	g_bRoundEnded = false;

	LoopValidClients(i)
	{
		g_iRole[i] = TTT_TEAM_UNASSIGNED;
		g_bFound[i] = true;
		g_iInnoKills[i] = 0;
		g_iTraitorKills[i] = 0;
		g_iDetectiveKills[i] = 0;
		g_bImmuneRDMManager[i] = false;

		CS_SetClientClanTag(i, " ");
	}

	if (g_hStartTimer != null)
	{
		KillTimer(g_hStartTimer);
	}

	if (g_hCountdownTimer != null)
	{
		KillTimer(g_hCountdownTimer);
	}

	float warmupTime = GetConVarFloat(g_hGraceTime) + 5.0;
	g_hStartTimer = CreateTimer(warmupTime, Timer_Selection, _, TIMER_FLAG_NO_MAPCHANGE);

	g_fRealRoundStart = GetGameTime() + warmupTime;
	g_hCountdownTimer = CreateTimer(0.5, Timer_SelectionCountdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	g_bRoundStarted = false;

	if (g_hRoundTimer != null)
	{
		delete g_hRoundTimer;
	}

	g_hRoundTimer = CreateTimer(GetConVarFloat(FindConVar("mp_freezetime")) + (GetConVarFloat(FindConVar("mp_roundtime")) * 60.0), Timer_OnRoundEnd);
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

public Action Timer_SelectionCountdown(Handle hTimer)
{
	int timeLeft = RoundToFloor(g_fRealRoundStart - GetGameTime());
	char centerText[512];
	char sColor[32];

	if (g_fRealRoundStart <= 0.0 || timeLeft <= 0)
	{
		if (timeLeft == 0)
		{
			LoopValidClients(i)
			{
				g_cRoundStartedFontColor.GetString(sColor, sizeof(sColor));
				Format(centerText, sizeof(centerText), "%T", "RoundStartedCenter", i, g_cRoundStartedFontSize.IntValue, sColor);
				PrintHintText(i, centerText);
			}
		}

		g_hCountdownTimer = null;
		return Plugin_Stop;
	}

	LoopValidClients(i)
	{
		g_cRoundStartFontColor.GetString(sColor, sizeof(sColor));
		Format(centerText, sizeof(centerText), "%T", "RoundStartCenter", i, g_cRoundStartFontSize.IntValue, sColor, timeLeft);
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
		if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T  || (!g_bDebug && IsFakeClient(i)))
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

	//Check if there are any slain players
	for (int i = 0; i < aPlayers.Length; i++)
	{
		if(!IsPlayerAlive(aPlayers.Get(i)))
			aPlayers.Erase(i--);
	}

	if (aPlayers.Length < g_crequiredPlayers.IntValue)
	{
		g_bInactive = true;
		LoopValidClients(i)
		{
			CPrintToChat(i, g_sTag, "MIN PLAYERS REQUIRED FOR PLAY", i, g_crequiredPlayers.IntValue);
		}

		g_bCheckPlayers = true;

		Call_StartForward(g_hOnRoundStartFailed);
		Call_PushCell(aPlayers.Length);
		Call_PushCell(g_crequiredPlayers.IntValue);
		Call_Finish();

		GiveWeaponsOnFailStart();

		return;
	}

	g_bRoundStarted = true;
	g_bSelection = true;
	g_bCheckPlayers = false;

	int iTCount = GetTCount(aPlayers.Length);
	int iDCount = GetDCount(aPlayers.Length);

	int iTraitors;
	int iDetectives;
	int iInnocents;
	int iRand;
	int client;
	int iIndex;

	int counter = 0;
	int iCurrentTime = GetTime();

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
					g_iRole[client] = TTT_TEAM_TRAITOR;
					iTraitors++;
					g_iLastRole[client] = TTT_TEAM_TRAITOR;
					aPlayers.Erase(iIndex);
				}
			}
			
			g_aForceTraitor.Erase(0);
			continue;
		}

		SetRandomSeed(iCurrentTime*100*counter++);
		iRand = GetRandomInt(0, aPlayers.Length - 1);
		client = aPlayers.Get(iRand);

		if (TTT_IsClientValid(client) && (g_iLastRole[client] != TTT_TEAM_TRAITOR || GetRandomInt(1, 3) == 2))
		{
			g_iRole[client] = TTT_TEAM_TRAITOR;
			g_iLastRole[client] = TTT_TEAM_TRAITOR;
			aPlayers.Erase(iRand);
			iTraitors++;
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
					g_iLastRole[client] = TTT_TEAM_DETECTIVE;
					g_iRole[client] = TTT_TEAM_DETECTIVE;
					iDetectives++;
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

		SetRandomSeed(iCurrentTime*100*counter++);
		iRand = GetRandomInt(0, aPlayers.Length - 1);
		client = aPlayers.Get(iRand);

		if (TTT_IsClientValid(client) && ((TTT_GetClientKarma(client) > g_cminKarmaDetective.IntValue && g_iLastRole[client] == TTT_TEAM_INNOCENT) || GetRandomInt(1,3) == 2))
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
			aPlayers.Erase(iRand);
		}
	}

	iInnocents = aPlayers.Length;

	while (aPlayers.Length > 0)
	{
		client = aPlayers.Get(0);
		if (TTT_IsClientValid(client))
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
			CPrintToChat(i, g_sTag, "All karma has been updated", i);
		}

		CPrintToChat(i, g_sTag, "TEAMS HAS BEEN SELECTED", i);

		if (g_iRole[i] != TTT_TEAM_TRAITOR)
		{
			CPrintToChat(i, g_sTag, "TRAITORS HAS BEEN SELECTED", i, iTraitors);
		}
		else
		{
			if (g_cShowTraitors.BoolValue)
			{
				CPrintToChat(i, g_sTag, "Your Traitor Partners", i);
				int iCount = 0;
			
				LoopValidClients(j)
				{
					if (!IsPlayerAlive(j) || i == j || g_iRole[j] != TTT_TEAM_TRAITOR)
					{
						continue;
					}
					CPrintToChat(i, g_sTag, "Traitor List", i, j);
					iCount++;
				}
			
				if (iCount == 0)
				{
					CPrintToChat(i, g_sTag, "No Traitor Partners", i);
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

		if (!g_bDebug && IsFakeClient(i))
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

int GetTCount(int iActivePlayers)
{
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

int GetDCount(int iActivePlayers)
{
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


stock int GetRandomArray(Handle array)
{
	int size = GetArraySize(array);
	if (size == 0)
	{
		return -1;
	}

	return GetRandomInt(0, size - 1);
}

stock bool IsPlayerInArray(int player, Handle array)
{
	for (int i = 0; i < GetArraySize(array); i++)
	{
		if (player == GetArrayCell(array, i))
		{
			return true;
		}
	}

	return false;
}

stock void TeamInitialize(int client)
{
	if (!TTT_IsClientValid(client))
	{
		return;
	}
	
	g_bFound[client] = false;
	
	char sBuffer[32];
	
	if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		if (g_cforceTeams.BoolValue)
		{
			if (GetClientTeam(client) != CS_TEAM_CT)
			{
				CS_SwitchTeam(client, CS_TEAM_CT);
			}
		}

		if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == -1)
		{
			g_cdefaultPriD.GetString(sBuffer, sizeof(sBuffer));
			GivePlayerItem(client, sBuffer);
		}

		CPrintToChat(client, g_sTag, "Your Team is DETECTIVES", client);

		if (g_cspawnHPD.IntValue > 0)
		{
			SetEntityHealth(client, g_cspawnHPD.IntValue);
		}

		if (GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1)
		{
			GivePlayerItem(client, "weapon_knife");
		}

		if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == -1)
		{
			g_cdefaultSec.GetString(sBuffer, sizeof(sBuffer));
			GivePlayerItem(client, sBuffer);
		}
	}
	else if (g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		CPrintToChat(client, g_sTag, "Your Team is TRAITORS", client);

		if (g_cspawnHPT.IntValue > 0)
		{
			SetEntityHealth(client, g_cspawnHPT.IntValue);
		}

		if (g_cforceTeams.BoolValue)
		{
			if (GetClientTeam(client) != CS_TEAM_T)
			{
				CS_SwitchTeam(client, CS_TEAM_T);
			}
		}
		if (GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1)
		{
			GivePlayerItem(client, "weapon_knife");
		}

		if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == -1)
		{
			g_cdefaultSec.GetString(sBuffer, sizeof(sBuffer));
			GivePlayerItem(client, sBuffer);
		}
	}
	else if (g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		CPrintToChat(client, g_sTag, "Your Team is INNOCENTS", client);

		if (g_cspawnHPI.IntValue > 0)
		{
			SetEntityHealth(client, g_cspawnHPI.IntValue);
		}

		if (g_cforceTeams.BoolValue)
		{
			if (GetClientTeam(client) != CS_TEAM_T)
			{
				CS_SwitchTeam(client, CS_TEAM_T);
			}
		}
		if (GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1)
		{
			GivePlayerItem(client, "weapon_knife");
		}

		if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == -1)
		{
			g_cdefaultSec.GetString(sBuffer, sizeof(sBuffer));
			GivePlayerItem(client, sBuffer);
		}
	}

	CheckClantag(client);

	bool bUpdate = false;

	if (g_cupdateClientModel.BoolValue)
	{
		CS_UpdateClientModel(client);
		
		bUpdate = true;
	}
	else if (g_cforceModel.BoolValue)
	{
		char sModel[PLATFORM_MAX_PATH + 1];
	
		switch (g_iRole[client])
		{
			case TTT_TEAM_INNOCENT, TTT_TEAM_TRAITOR:
			{
				g_cmodelT.GetString(sModel, sizeof(sModel));
				SetEntityModel(client, sModel);
			}
			case TTT_TEAM_DETECTIVE:
			{
				g_cmodelCT.GetString(sModel, sizeof(sModel));
				SetEntityModel(client, sModel);
			}
		}
		
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
		if (g_bRoundStarted)
		{
			if (g_cslayAfterStart.BoolValue)
			{
				g_iRole[client] = TTT_TEAM_UNASSIGNED;
				RequestFrame(Frame_SlapPlayer, GetClientUserId(client));
				CS_SetClientClanTag(client, "UNASSIGNED");
			}
		}
		else
		{
			CS_SetClientClanTag(client, " ");

			if (g_cEnableDamage.BoolValue)
			{
				GivePlayerItem(client, "weapon_knife");

				char sWeapon[32];
				
				g_cFSSecondary.GetString(sWeapon, sizeof(sWeapon));
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
				GivePlayerItem(client, sWeapon);
				
				g_cFSPrimary.GetString(sWeapon, sizeof(sWeapon));
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
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
			CPrintToChat(client, g_sTag, "Your karma is", client, g_iKarma[client]);
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
	LoopValidClients(i)
	{
		LoadClientKarma(GetClientUserId(i));

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
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponPostSwitch);
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

	if (g_bRoundStarted && !g_bRoundEnded)
	{
		if (TTT_IsClientValid(iAttacker) && iAttacker != iVictim && g_ckarmaDMG.BoolValue)
		{
			if (g_ckarmaDMG_up.BoolValue || (g_iKarma[iAttacker] < g_cstartKarma.IntValue))
			{
				damage *= FloatDiv(float(g_iKarma[iAttacker]), float(g_cstartKarma.IntValue));
				return Plugin_Changed;
			}
		}
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

	g_iInnoKills[client] = 0;
	g_iTraitorKills[client] = 0;
	g_iDetectiveKills[client] = 0;

	int iRagdoll = 0;
	if (g_iRole[client] > TTT_TEAM_UNASSIGNED)
	{
		iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if (iRagdoll > 0)
		{
			AcceptEntityInput(iRagdoll, "Kill");
		}

		char playermodel[128];
		GetClientModel(client, playermodel, 128);

		float origin[3], angles[3], velocity[3];

		GetClientAbsOrigin(client, origin);
		GetClientAbsAngles(client, angles);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

		int iEntity = CreateEntityByName("prop_ragdoll");
		DispatchKeyValue(iEntity, "model", playermodel);
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

		int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		int iRagdollC[Ragdolls];
		iRagdollC[Ent] = EntIndexToEntRef(iEntity);
		iRagdollC[Victim] = client;
		iRagdollC[VictimTeam] = g_iRole[client];
		Format(iRagdollC[VictimName], MAX_NAME_LENGTH, name);
		iRagdollC[Scanned] = false;
		GetClientName(iAttacker, name, sizeof(name));
		iRagdollC[Attacker] = iAttacker;
		iRagdollC[AttackerTeam] = g_iRole[iAttacker];
		Format(iRagdollC[AttackerName], MAX_NAME_LENGTH, name);
		iRagdollC[GameTime] = GetGameTime();
		event.GetString("weapon", iRagdollC[Weaponused], sizeof(iRagdollC[Weaponused]));

		g_aRagdoll.PushArray(iRagdollC[0]);

		SetEntPropEnt(client, Prop_Send, "m_hRagdoll", iEntity);

		if (client != iAttacker && iAttacker != 0 && !g_bImmuneRDMManager[iAttacker] && !g_bHoldingProp[client] && !g_bHoldingSilencedWep[client])
		{
			if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)
			{
				if (g_hRDMTimer[client] != null)
				{
					KillTimer(g_hRDMTimer[client]);
				}

				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			}
			else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE)
			{
				if (g_hRDMTimer[client] != null)
				{
					KillTimer(g_hRDMTimer[client]);
				}

				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			}
			else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE)
			{
				if (g_hRDMTimer[client] != null)
				{
					KillTimer(g_hRDMTimer[client]);
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
				ServerCommand("sm_slay #%i 5", GetClientUserId(iAttacker));
			}

			if (g_iTraitorKills[iAttacker] >= g_cpunishTraitorKills.IntValue)
			{
				ServerCommand("sm_slay #%i 5", GetClientUserId(iAttacker));
			}

			if (g_iDetectiveKills[iAttacker] >= g_cpunishDetectiveKills.IntValue)
			{
				ServerCommand("sm_slay #%i 5", GetClientUserId(iAttacker));
			}
		}
	}
	else
	{
		iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if (iRagdoll > 0)
		{
			AcceptEntityInput(iRagdoll, "Kill");
		}
	}

	event.BroadcastDisabled = true;

	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	nameCheck(client, name);

	g_bImmuneRDMManager[client] = false;
	g_bFound[client] = true;

	g_iRole[client] = TTT_TEAM_UNASSIGNED;
	CS_SetClientClanTag(client, "UNASSIGNED");

	if (TTT_GetSQLConnection() != null)
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

	ShowRules(client, g_iSite[client]);
	return Plugin_Handled;
}

public Action Command_DetectiveRules(int client, int args)
{
	if (!g_cshowDetectiveMenu.BoolValue)
	{
		return Plugin_Handled;
	}

	AskClientForMicrophone(client);
	return Plugin_Handled;
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
		return;
	}

	if (!kvRules.GotoFirstSubKey())
	{
		SetFailState("Can't read %s correctly! (GotoFirstSubKey)", g_sRulesFile);
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

					g_bKnowRules[client] = false;
					g_bReadRules[client] = true;

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
			char sAccess[18];
			g_ckickImmunity.GetString(sAccess, sizeof(sAccess));
			if (!TTT_HasFlags(client, sAccess))
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

public void OnClientDisconnect(int client)
{
	if (IsClientInGame(client))
	{
		g_bKarma[client] = false;
		g_bFound[client] = true;


		if (g_cTranfserArmor.BoolValue)
		{
			g_iArmor[client] = 0;
		}

		ClearTimer(g_hRDMTimer[client]);

		g_bReceivingLogs[client] = false;
		g_bImmuneRDMManager[client] = false;
	}
}

public Action Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsClientInGame(client))
	{
		return;
	}

	char userName[MAX_NAME_LENGTH];
	event.GetString("newname", userName, sizeof(userName));
	nameCheck(client, userName);

	int iSize = g_aRagdoll.Length;

	if (iSize == 0)
	{
		return;
	}

	int iRagdollC[Ragdolls];

	//TODO Make this based on the userid to prevent abuse
	for (int i = 0; i < g_aRagdoll.Length; i++)
	{
		g_aRagdoll.GetArray(i, iRagdollC[0]);

		if (client == iRagdollC[Attacker])
		{
			Format(iRagdollC[AttackerName], MAX_NAME_LENGTH, userName);
			g_aRagdoll.SetArray(i, iRagdollC[0]);
		}
		else if (client == iRagdollC[Victim])
		{
			Format(iRagdollC[VictimName], MAX_NAME_LENGTH, userName);
			g_aRagdoll.SetArray(i, iRagdollC[0]);
		}
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
		Call_StartForward(g_hOnUpdate1);
		Call_PushCell(i);
		Call_Finish();

		if (IsPlayerAlive(i))
		{
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

			if (!g_bDebug)
			{
				CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
			}
		}
		else if (g_iTraitorAlive == 0)
		{
			g_bRoundStarted = false;

			if (!g_bDebug)
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

	if (g_cshowDeathMessage.BoolValue)
	{
		if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR)
		{
			CPrintToChat(client, g_sTag, "Your killer is a Traitor", client);
		}
		else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE)
		{
			CPrintToChat(client, g_sTag, "Your killer is a Detective", client);
		}
		else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT)
		{
			CPrintToChat(client, g_sTag, "Your killer is an Innocent", client);
		}
	}

	if (g_cshowKillMessage.BoolValue)
	{
		if (g_iRole[client] == TTT_TEAM_TRAITOR)
		{
			CPrintToChat(iAttacker, g_sTag, "You killed a Traitor", iAttacker);
		}
		else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
		{
			CPrintToChat(iAttacker, g_sTag, "You killed a Detective", iAttacker);
		}
		else if (g_iRole[client] == TTT_TEAM_INNOCENT)
		{
			CPrintToChat(iAttacker, g_sTag, "You killed an Innocent", iAttacker);
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

		subtractKarma(iAttacker, g_ckarmaII.IntValue, true);
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

		subtractKarma(iAttacker, g_ckarmaID.IntValue, true);
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

		subtractKarma(iAttacker, g_ckarmaTT.IntValue, true);
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

		subtractKarma(iAttacker, g_ckarmaDI.IntValue, true);
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

		subtractKarma(iAttacker, g_ckarmaDD.IntValue, true);
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

	if (!g_bDebug)
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
			CPrintToChat(client, g_sTag, "All karma has been updated", client);
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
			CPrintToChat(client, g_sTag, "next round in", client, delay);
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

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!iAttacker)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));


	int damage = event.GetInt("dmg_health");

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
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) damaged %N%s (Innocent) for %i damage with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) damaged %N%s (Traitor) for %i damage with %s]", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_INNOCENT && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Innocent) damaged %N%s (Detective) for %i damage with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) damaged %N%s (Innocent) for %i damage with %s]", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);

	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) damaged %N%s (Traitor) for %i damage with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);

	}
	else if (g_iRole[iAttacker] == TTT_TEAM_TRAITOR && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Traitor) damaged %N%s (Detective) for %i damage with %s]", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) damaged %N%s (Innocent) for %i damage with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);

	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) damaged %N%s (Traitor) for %i damage with %s]", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);
	}
	else if (g_iRole[iAttacker] == TTT_TEAM_DETECTIVE && g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(iItem, sizeof(iItem), "-> [%N%s (Detective) damaged %N%s (Detective) for %i damage with %s] - BAD ACTION", iAttacker, sAttackerID, client, sClientID, damage, sWeapon);
		addArrayTime(iItem);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
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

		if ((buttons & button))
		{
			if (!(g_iLastButtons[client] & button))
			{
				Call_StartForward(g_hOnButtonPress);
				Call_PushCell(client);
				Call_PushCell(button);
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
		g_bHoldingProp[client] = true;

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

						InspectBody(client, iRagdollC[Victim], iRagdollC[Attacker], RoundToNearest(GetGameTime() - iRagdollC[GameTime]), iRagdollC[Weaponused], iRagdollC[VictimName], iRagdollC[AttackerName]);

						if (!iRagdollC[Found] && IsPlayerAlive(client))
						{
							iRagdollC[Found] = true;

							if (IsClientInGame(iRagdollC[Victim]))
							{
								g_bFound[iRagdollC[Victim]] = true;
							}

							if (iRagdollC[VictimTeam] == TTT_TEAM_INNOCENT)
							{
								LoopValidClients(j)
									CPrintToChat(j, g_sTag, "Found Innocent", j, client, iRagdollC[VictimName]);
								SetEntityRenderColor(iEntity, 0, 255, 0, 255);
							}
							else if (iRagdollC[VictimTeam] == TTT_TEAM_DETECTIVE)
							{
								LoopValidClients(j)
									CPrintToChat(j, g_sTag, "Found Detective", j, client, iRagdollC[VictimName]);
								SetEntityRenderColor(iEntity, 0, 0, 255, 255);
							}
							else if (iRagdollC[VictimTeam] == TTT_TEAM_TRAITOR)
							{
								LoopValidClients(j)
									CPrintToChat(j, g_sTag, "Found Traitor", j, client, iRagdollC[VictimName]);
								SetEntityRenderColor(iEntity, 255, 0, 0, 255);
							}

							TeamTag(iRagdollC[Victim]);

							Call_StartForward(g_hOnBodyFound);
							Call_PushCell(client);
							Call_PushCell(iRagdollC[Victim]);
							Call_PushString(iRagdollC[VictimName]);
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
		g_bHoldingProp[client] = false;
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

stock void InspectBody(int client, int victim, int attacker, int time, const char[] weapon, const char[] victimName, const char[] attackerName)
{
	char team[32];
	if (g_iRole[victim] == TTT_TEAM_TRAITOR)
	{
		Format(team, sizeof(team), "%T", "Traitors", client);
	}
	else if (g_iRole[victim] == TTT_TEAM_DETECTIVE)
	{
		Format(team, sizeof(team), "%T", "Detectives", client);
	}
	else if (g_iRole[victim] == TTT_TEAM_INNOCENT)
	{
		Format(team, sizeof(team), "%T", "Innocents", client);
	}

	Handle menu = CreateMenu(BodyMenuHandler);
	char sBuffer[128];

	SetMenuTitle(menu, "%T", "Inspected body. The extracted data are the following", client);

	Format(sBuffer, sizeof(sBuffer), "%T", "Victim name", client, victimName);
	AddMenuItem(menu, "", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "Team victim", client, team);
	AddMenuItem(menu, "", sBuffer);

	if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "Elapsed since his death", client, time);
		AddMenuItem(menu, "", sBuffer);

		if (attacker > 0 && attacker != victim)
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "The weapon used has been", client, weapon);
			AddMenuItem(menu, "", sBuffer);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "The weapon used has been: himself (suicide)", client);
			AddMenuItem(menu, "", sBuffer);
		}
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);

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
			CPrintToChat(client, g_sTag, "karma earned", client, karma, g_iKarma[client]);
		}
	}

	UpdatePlayer(client);
	
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
			CPrintToChat(client, g_sTag, "lost karma", client, karma, g_iKarma[client]);
		}
	}

	UpdatePlayer(client);
	
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

stock void ClearTimer(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
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
		CPrintToChat(client, g_sTag, "The player who RDM'd you is no longer available", client);
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
			CPrintToChat(client, g_sTag, "Choose Forgive Victim", client, iAttacker);
			CPrintToChat(iAttacker, g_sTag, "Choose Forgive Attacker", iAttacker, client);
			g_iRDMAttacker[client] = -1;
		}
		if (StrEqual(info, "Punish", false))
		{
			LoopValidClients(i)
				CPrintToChat(i, g_sTag, "Choose Punish", i, client, iAttacker);
			ServerCommand("sm_slay #%i 2", GetClientUserId(iAttacker));
			g_iRDMAttacker[client] = -1;
		}
	}
	else if (action == MenuAction_Cancel)
	{
		CPrintToChat(client, g_sTag, "Choose Forgive Victim", client, iAttacker);
		CPrintToChat(iAttacker, g_sTag, "Choose Forgive Attacker", iAttacker, client);
		g_iRDMAttacker[client] = -1;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
		CPrintToChat(client, g_sTag, "Choose Forgive Victim", client, iAttacker);
		CPrintToChat(iAttacker, g_sTag, "Choose Forgive Attacker", iAttacker, client);
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
	
	char sAccess[18];
	g_cSetRole.GetString(sAccess, sizeof(sAccess));
	
	if (!TTT_HasFlags(client, sAccess))
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
		CPrintToChat(client, g_sTag, "Player is Now Innocent", client, target);
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
		CPrintToChat(client, g_sTag, "Player is Now Traitor", client, target);
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
		CPrintToChat(client, g_sTag, "Player is Now Detective", client, target);
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
	
	char sAccess[18];
	g_cSetKarma.GetString(sAccess, sizeof(sAccess));
	
	if (!TTT_HasFlags(client, sAccess))
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

		CPrintToChat(client, g_sTag, "AdminSet", client, target, karma, "Karma");
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
		CPrintToChat(client, g_sTag, "You Are Unassigned", client);
	}
	else if (g_iRole[client] == TTT_TEAM_INNOCENT)
	{
		CPrintToChat(client, g_sTag, "You Are Now Innocent", client);
	}
	else if (g_iRole[client] == TTT_TEAM_DETECTIVE)
	{
		CPrintToChat(client, g_sTag, "You Are Now Detective", client);
	}
	else if (g_iRole[client] == TTT_TEAM_TRAITOR)
	{
		CPrintToChat(client, g_sTag, "You Are Now Traitor", client);
	}

	return Plugin_Handled;
}

public Action Timer_5(Handle timer)
{
	LoopValidClients(i)
	{
		Call_StartForward(g_hOnUpdate5);
		Call_PushCell(i);
		Call_Finish();

		if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T)
		{
			continue;
		}

		if (IsFakeClient(i))
		{
			continue;
		}

		if (!IsPlayerAlive(i))
		{
			continue;
		}

		if (g_bKarma[i] && g_ckarmaBan.IntValue != 0 && g_iKarma[i] <= g_ckarmaBan.IntValue)
		{
			BanBadPlayerKarma(i);
		}
	}

	if (g_bRoundStarted)
	{
		CheckTeams();
	}
	else if (g_bCheckPlayers)
	{
		CheckPlayers();
	}

	Call_StartForward(g_hOnUpdate5);
	Call_Finish();
}

void CheckPlayers()
{
	int iCount = 0;
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

		iCount++;
	}

	if (iCount >= g_crequiredPlayers.IntValue)
	{
		g_bCheckPlayers = false;

		if (!g_bDebug)
		{
			CS_TerminateRound(3.0, CSRoundEnd_Draw);
		}
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
			ServerCommand("sm_slay #%i 2", GetClientUserId(activator));

			LoopValidClients(i)
			{
				CPrintToChat(i, g_sTag, "Triggered Falling Building", i, activator);
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

public void OnWeaponPostSwitch(int client, int weapon)
{
	char weaponName[64];
	GetClientWeapon(client, weaponName, sizeof(weaponName));
	if (StrContains(weaponName, "silence") != -1)
	{
		g_bHoldingSilencedWep[client] = true;
	}
	else
	{
		g_bHoldingSilencedWep[client] = false;
	}
}

public Action Command_KarmaReset(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	char sAccess[18];
	g_cKarmaReset.GetString(sAccess, sizeof(sAccess));

	if (!TTT_HasFlags(client, sAccess))
	{
		return Plugin_Handled;
	}

	LoopValidClients(i)
	{
		if (!IsFakeClient(i))
		{
			CPrintToChat(client, g_sTag, "AdminSet", client, i, g_cstartKarma.IntValue, "Karma");
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

		if (!g_bDebug)
		{
			CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
		}
	}
	else if (iT == 0)
	{
		g_bRoundStarted = false;
		g_bRoundEnded = true;

		if (!g_bDebug)
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
		char sCommunityID[64];

		if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
		{
			LogToFileEx(g_sErrorFile, "(LoadClientKarma) Auth failed: #%d", client);
			return;
		}

		char sQuery[2048];
		Format(sQuery, sizeof(sQuery), "SELECT `karma` FROM `ttt` WHERE `communityid`= \"%s\";", sCommunityID);

		if (g_bDebug)
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

	if (g_bDebug)
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
			TTT_SafeRemoveWeapon(client, iEnt);
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
		char sWeapon[32];

		LoopValidClients(i)
		{
			if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T || IsFakeClient(i))
			{
				continue;
			}

			if (IsPlayerAlive(i))
			{
				GivePlayerItem(i, "weapon_knife");

				g_cFSSecondary.GetString(sWeapon, sizeof(sWeapon));
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
				GivePlayerItem(i, sWeapon);
				
				g_cFSPrimary.GetString(sWeapon, sizeof(sWeapon));
				Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
				GivePlayerItem(i, sWeapon);
			}
		}
	}
}
