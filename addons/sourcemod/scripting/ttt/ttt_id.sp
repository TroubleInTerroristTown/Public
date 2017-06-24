#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <multicolors>

#include <ttt_shop>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define SHORT_NAME_I "id"
#define SHORT_NAME_T "id_t"
#define LONG_NAME_I "ID"
#define LONG_NAME_T "(Fake) ID"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: ID"

int g_iTPrice = 0;
int g_iIPrice = 0;

int g_iTPrio = 0;
int g_iIPrio = 0;

Handle g_hTimer[MAXPLAYERS + 1] = {null, ...};

bool g_bHasID[MAXPLAYERS + 1] =  { false, ... };

float g_fCooldown;

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[512] = "";

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
	
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/id.cfg");
	Config_Setup("TTT-ID", g_sConfigFile);
	
	g_iTPrice = Config_LoadInt("id_traitor_price", 1000, "The amount of credits for fake ID costs as traitor. 0 to disable.");
	g_iIPrice = Config_LoadInt("id_innocent_price", 1000, "The amount of credits for ID costs as innocent. 0 to disable.");
	
	g_iTPrio = Config_LoadInt("id_traitor_sort_prio", 0, "The sorting priority of the fake ID in the shop menu.");
	g_iIPrio = Config_LoadInt("id_innocent_sort_prio", 0, "The sorting priority of the ID in the shop menu.");
	
	g_fCooldown = Config_LoadFloat("id_cooldown_time", 0.0, "The cooldown for the !id command. Set it to 0.0 to disable the cooldown");
	
	Config_Done();

	RegConsoleCmd("sm_id", Command_ID, "Prove yourself as Innocent");
	
	LoadTranslations("ttt.phrases");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action Command_ID(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (g_fCooldown > 0.0)
	{
		if (g_hTimer[client] != null)
		{
			CPrintToChat(client, g_sPluginTag, "ID: Cooldown", client);
			return Plugin_Handled;
		}
		else
		{
			g_hTimer[client] = CreateTimer(g_fCooldown, Timer_Cooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, g_sPluginTag, "ID: Need to be Alive", client);
		return Plugin_Handled;
	}
	
	if (!g_bHasID[client])
	{
		CPrintToChat(client, g_sPluginTag, "ID: Need to buy ID", client);
		return Plugin_Handled;
	}
	
	char sName[MAX_NAME_LENGTH];
	if (!GetClientName(client, sName, sizeof(sName)))
	{
		return Plugin_Handled;
	}
	
	LoopValidClients(i)
	{
		CPrintToChat(i, g_sPluginTag, "ID: Shows ID", i, sName);
	}
	
	return Plugin_Handled;
}

public Action Timer_Cooldown(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (TTT_IsClientValid(client))
	{
		if (g_hTimer[client] != null)
		{
			delete g_hTimer[client];
			g_hTimer[client] = null;
			return Plugin_Stop;
		}
	}
	return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
	Reset(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		Reset(client);
	}
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME_T, LONG_NAME_T, g_iTPrice, TTT_TEAM_TRAITOR, g_iTPrio);
	TTT_RegisterCustomItem(SHORT_NAME_I, LONG_NAME_I, g_iIPrice, TTT_TEAM_INNOCENT, g_iIPrio);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME_I, false) || StrEqual(itemshort, SHORT_NAME_T, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role == TTT_TEAM_DETECTIVE || role == TTT_TEAM_UNASSIGNED || g_bHasID[client])
			{
				return Plugin_Stop;
			}
			
			CPrintToChat(client, g_sPluginTag, "ID: Buy Message", client);
			
			g_bHasID[client] = true;
		}
	}
	return Plugin_Continue;
}

void Reset(int client)
{
	g_bHasID[client] = false;
	if (g_hTimer[client] != null)
	{
		delete g_hTimer[client];
		g_hTimer[client] = null;
	}
}