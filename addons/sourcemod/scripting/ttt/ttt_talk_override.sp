#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma newdecls required

#include <ttt>
#include <config_loader>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Talk Override"

bool g_bEnableTVoice = false;
bool g_bTVoice[MAXPLAYERS + 1] =  { false, ... };
char g_sConfigFile[PLATFORM_MAX_PATH];
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	
	Config_Done();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/talk_override.cfg");
	Config_Setup("TTT-TalkOverride", g_sConfigFile);
	g_bEnableTVoice = Config_LoadBool("tor_traitor_voice_chat", true, "Enable traitor voice chat (command for players: sm_tvoice)?");
	Config_Done();
	
	if (g_bEnableTVoice)
	{
		RegConsoleCmd("sm_tvoice", Command_TVoice);
	}
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	
	LoadTranslations("ttt.phrases");
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
	
	if (!IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
	{
		return Plugin_Handled;
	}
	
	if (g_bTVoice[client])
	{
		CPrintToChat(client, g_sPluginTag, "Traitor Voice Chat: Disabled!", client);
		g_bTVoice[client] = false;
		LoopValidClients(i)
		{
			SetListenOverride(i, client, Listen_Yes);
			if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
			{
				CPrintToChat(i, g_sPluginTag, "stopped talking in Traitor Voice Chat", i, client);
			}
		}
	}
	else
	{
		g_bTVoice[client] = true;
		CPrintToChat(client, g_sPluginTag, "Traitor Voice Chat: Enabled!", client);
		LoopValidClients(i)
		{
			if (TTT_GetClientRole(i) != TTT_TEAM_TRAITOR)
			{
				SetListenOverride(i, client, Listen_No);
			}
			else
			{
				CPrintToChat(i, g_sPluginTag, "is now talking in Traitor Voice Chat", i, client);
			}
		}
	}
	return Plugin_Continue;
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
		if (IsPlayerAlive(i))
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
		if (!IsPlayerAlive(client))
		{
			if (IsPlayerAlive(i))
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