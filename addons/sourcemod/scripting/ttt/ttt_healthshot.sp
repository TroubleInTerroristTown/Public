#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt>
#include <config_loader>

#pragma newdecls required

#define SHORT_NAME "hs"
#define SHORT_NAME_D "hs_d"
#define SHORT_NAME_T "hs_t"
#define LONG_NAME "Healthshot"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Healthshot"

int g_iTPrice = 0;
int g_iDPrice = 0;
int g_iIPrice = 0;

int g_iTCount = 0;
int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };

int g_iDCount = 0;
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };

int g_iICount = 0;
int g_iIPCount[MAXPLAYERS + 1] =  { 0, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/healthshot.cfg");

	Config_Setup("TTT-Healthshot", g_sConfigFile);
	
	g_iTPrice = Config_LoadInt("hs_traitor_price", 9000, "The amount of credits for healthshot costs as traitor. 0 to disable.");
	g_iDPrice = Config_LoadInt("hs_detective_price", 9000, "The amount of credits for healthshot costs as detective. 0 to disable.");
	g_iIPrice = Config_LoadInt("hs_innocent_price", 9000, "The amount of credits for healthshot costs as innocent. 0 to disable.");
	
	g_iTCount = Config_LoadInt("hs_traitor_count", 1, "The amount of usages for healthshots per round as traitor. 0 to disable.");
	g_iDCount = Config_LoadInt("hs_detective_count", 1, "The amount of usages for healthshots per round as detective. 0 to disable.");
	g_iICount = Config_LoadInt("hs_innocent_count", 1, "The amount of usages for healthshots per round as innocent. 0 to disable.");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetHealthshot(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
		ResetHealthshot(client);
}

public void OnAllPluginsLoaded()
{
	if(g_iTPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME_T, LONG_NAME, g_iTPrice, TTT_TEAM_TRAITOR);
	if(g_iDPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME_D, LONG_NAME, g_iDPrice, TTT_TEAM_DETECTIVE);
	if(g_iIPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iIPrice, TTT_TEAM_INNOCENT);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(StrEqual(itemshort, SHORT_NAME, false) || StrEqual(itemshort, SHORT_NAME_D, false) || StrEqual(itemshort, SHORT_NAME_T, false))
		{
			int role = TTT_GetClientRole(client);
			
			if(role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_iTCount)
				return Plugin_Stop;
			else if(role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_iDCount)
				return Plugin_Stop;
			else if(role == TTT_TEAM_INNOCENT && g_iIPCount[client] >= g_iICount)
				return Plugin_Stop;
				
			GivePlayerItem(client, "weapon_healthshot");
			
			if(role == TTT_TEAM_TRAITOR)
				g_iTPCount[client]++;
			else if(role == TTT_TEAM_DETECTIVE)
				g_iDPCount[client]++;
			else if(role == TTT_TEAM_INNOCENT)
				g_iIPCount[client]++;
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
