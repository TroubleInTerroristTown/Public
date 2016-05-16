#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <lasermines>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "lm"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Lasermines"

int g_iTraitorPrice = 0;
int g_iTCount = 0;
int g_iPCount[MAXPLAYERS + 1];

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/lasermines.cfg");

	Config_Setup("TTT-Lasermines", g_sConfigFile);
	
	Config_LoadString("lm_name", "Lasermine", "The name of the Lasermine in the Shop", g_sLongName, sizeof(g_sLongName));
	g_iTCount = Config_LoadInt("lm_traitor_count", 1, "The amount of usages for lasermines per round as traitor. 0 to disable.");
	g_iTraitorPrice = Config_LoadInt("lm_traitor_price", 9000, "The amount of credits for a lasermine costs. 0 to disable.");
	Config_Done();
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iTraitorPrice, TTT_TEAM_TRAITOR);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(StrEqual(itemshort, SHORT_NAME, false))
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
					return Plugin_Stop;
			
			if(g_iPCount[client] >= g_iTCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iTCount);
				return Plugin_Stop;
			}
			 	
			
			g_iPCount[client]++;
			AddClientLasermines(client, 1);
		}
	}
	return Plugin_Continue;
}
