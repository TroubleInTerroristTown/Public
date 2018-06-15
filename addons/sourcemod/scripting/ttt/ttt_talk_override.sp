#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Talk Override"

ConVar g_cEnableTVoice = null;

bool g_bTVoice[MAXPLAYERS + 1] =  { false, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[128];

Handle g_hOnListenOverride = null;

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
	g_hOnListenOverride = CreateGlobalForward("TTT_OnListenOverride", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);

	CreateNative("TTT_GetListenOverride", Native_GetListenOverride);
	CreateNative("TTT_SetListenOverride", Native_SetListenOverride);

	RegPluginLibrary("ttt_talk_override");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	TTT_StartConfig("talk_override");
	CreateConVar("ttt2_talk_override_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cEnableTVoice = AutoExecConfig_CreateConVar("tor_traitor_voice_chat", "1", "Enable traitor voice chat (command for players: sm_tvoice)?", _, true, 0.0, true, 1.0);
	TTT_EndConfig();

	if (g_cEnableTVoice.BoolValue)
	{
		RegConsoleCmd("sm_tvoice", Command_TVoice);
	}

	CreateTimer(1.0, Timer_UpdateOverride, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);

	LoadTranslations("ttt.phrases");
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	}
}

public Action Command_TVoice(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (!TTT_IsRoundActive())
	{
		return Plugin_Handled;
	}

	if (!TTT_IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}

	if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
	{
		return Plugin_Handled;
	}

	if (g_bTVoice[client])
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Traitor Voice Chat: Disabled!", client);
		g_bTVoice[client] = false;
		LoopValidClients(i)
		{
			SetListenOverride(i, client, Listen_Yes);
			if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
			{
				CPrintToChat(i, "%s %T", g_sPluginTag, "stopped talking in Traitor Voice Chat", i, client);
			}
		}
	}
	else
	{
		g_bTVoice[client] = true;
		CPrintToChat(client, "%s %T", g_sPluginTag, "Traitor Voice Chat: Enabled!", client);
		LoopValidClients(i)
		{
			if (TTT_GetClientRole(i) != TTT_TEAM_TRAITOR)
			{
				SetListenOverride(i, client, Listen_No);
			}
			else
			{
				CPrintToChat(i, "%s %T", g_sPluginTag, "is now talking in Traitor Voice Chat", i, client);
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_UpdateOverride(Handle timer)
{
	LoopValidClients(i)
	{
		LoopValidClients(j)
		{
			ListenOverride status = GetListenOverride(i, j);

			if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR && g_bTVoice[i] && TTT_GetClientRole(i) == TTT_GetClientRole(j))
			{
				status = Listen_Yes;
			}
			else if (TTT_IsPlayerAlive(i) && TTT_IsPlayerAlive(j))
			{
				status = Listen_Yes;
			}
			else if (TTT_IsPlayerAlive(i) && !TTT_IsPlayerAlive(j))
			{
				status = Listen_No;
			}
			else if (!TTT_IsPlayerAlive(i) && TTT_IsPlayerAlive(j))
			{
				status = Listen_Yes;
			}
			else if (!TTT_IsPlayerAlive(i) && !TTT_IsPlayerAlive(j))
			{
				status = Listen_Yes;
			}

			Action result = Plugin_Continue;
			Call_StartForward(g_hOnListenOverride);
			Call_PushCell(i);
			Call_PushCell(j);
			Call_PushCellRef(view_as<int>(status));
			Call_Finish(result);

			SetListenOverride(i, j, status);
		}
	}

	return Plugin_Continue;
}

public int Native_GetListenOverride(Handle plugin, int numParams)
{
	int receiver = GetNativeCell(1);
	int sender = GetNativeCell(2);
	
	return view_as<int>(GetListenOverride(receiver, sender));
}

public int Native_SetListenOverride(Handle plugin, int numParams)
{
	int receiver = GetNativeCell(1);
	int sender = GetNativeCell(2);
	ListenOverride status = view_as<ListenOverride>(GetNativeCell(3));
	
	return view_as<int>(SetListenOverride(receiver, sender, status));
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	LoopValidClients(i)
	{
		SetListenOverride(i, client, Listen_Yes);
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));

	g_bTVoice[victim] = false;

	LoopValidClients(i)
	{
		if (TTT_IsPlayerAlive(i))
		{
			SetListenOverride(i, victim, Listen_No);
		}
		else
		{
			SetListenOverride(i, victim, Listen_Yes);
		}
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	LoopValidClients(i)
	{
		if (!TTT_IsPlayerAlive(client))
		{
			if (TTT_IsPlayerAlive(i))
			{
				SetListenOverride(i, client, Listen_No);
				SetListenOverride(client, i, Listen_Yes);
			}
			else
			{
				SetListenOverride(i, client, Listen_Yes);
				SetListenOverride(client, i, Listen_Yes);
			}
		}
		else
		{
			SetListenOverride(client, i, Listen_Yes);
			SetListenOverride(i, client, Listen_Yes);
		}
	}

}
