#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "hs"
#define SHORT_NAME_D "hs_d"
#define SHORT_NAME_T "hs_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Healthshot"

int g_iTPrice = 0;
int g_iDPrice = 0;
int g_iIPrice = 0;

int g_iTPrio = 0;
int g_iDPrio = 0;
int g_iIPrio = 0;

int g_iTCount = 0;
int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };

int g_iDCount = 0;
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };

int g_iICount = 0;
int g_iIPCount[MAXPLAYERS + 1] =  { 0, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sLongName[64];

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
	
	LoadTranslations("ttt.phrases");
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	
	Config_Done();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/healthshot.cfg");

	Config_Setup("TTT-Healthshot", g_sConfigFile);
	Config_LoadString("hs_name", "Healthshot", "The name of the Healtshot in the Shop", g_sLongName, sizeof(g_sLongName));
	
	g_iTPrice = Config_LoadInt("hs_traitor_price", 9000, "The amount of credits for healthshot costs as traitor. 0 to disable.");
	g_iDPrice = Config_LoadInt("hs_detective_price", 9000, "The amount of credits for healthshot costs as detective. 0 to disable.");
	g_iIPrice = Config_LoadInt("hs_innocent_price", 9000, "The amount of credits for healthshot costs as innocent. 0 to disable.");
	
	g_iTCount = Config_LoadInt("hs_traitor_count", 1, "The amount of usages for healthshots per round as traitor. 0 to disable.");
	g_iDCount = Config_LoadInt("hs_detective_count", 1, "The amount of usages for healthshots per round as detective. 0 to disable.");
	g_iICount = Config_LoadInt("hs_innocent_count", 1, "The amount of usages for healthshots per round as innocent. 0 to disable.");
	
	g_iTPrio = Config_LoadInt("hs_traitor_sort_prio", 0, "The sorting priority of the healthshots (Traitor) in the shop menu.");
	g_iDPrio = Config_LoadInt("hs_detective_sort_prio", 0, "The sorting priority of the healthshots (Detective) in the shop menu.");
	g_iIPrio = Config_LoadInt("hs_innocent_sort_prio", 0, "The sorting priority of the healthshots (Innocent) in the shop menu.");
	
	Config_Done();
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetHealthshot(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		ResetHealthshot(client);
	}
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME_T, g_sLongName, g_iTPrice, TTT_TEAM_TRAITOR, g_iTPrio);
	TTT_RegisterCustomItem(SHORT_NAME_D, g_sLongName, g_iDPrice, TTT_TEAM_DETECTIVE, g_iDPrio);
	TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iIPrice, TTT_TEAM_INNOCENT, g_iIPrio);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false) || StrEqual(itemshort, SHORT_NAME_D, false) || StrEqual(itemshort, SHORT_NAME_T, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_iTCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iTCount);
				return Plugin_Stop;
			}
			else if (role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_iDCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iDCount);
				return Plugin_Stop;
			}
			else if (role == TTT_TEAM_INNOCENT && g_iIPCount[client] >= g_iICount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iICount);
				return Plugin_Stop;
			}	
			GivePlayerItem(client, "weapon_healthshot");
			
			if (count)
			{
				if (role == TTT_TEAM_TRAITOR)
				{
					g_iTPCount[client]++;
				}
				else if (role == TTT_TEAM_DETECTIVE)
				{
					g_iDPCount[client]++;
				}
				else if (role == TTT_TEAM_INNOCENT)
				{
					g_iIPCount[client]++;
				}
			}
		}
	}
	return Plugin_Continue;
}

void ResetHealthshot(int client)
{
	g_iTPCount[client] = 0;
	g_iDPCount[client] = 0;
	g_iIPCount[client] = 0;
}
