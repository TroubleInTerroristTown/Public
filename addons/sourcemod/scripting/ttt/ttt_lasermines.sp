#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt>
#include <config_loader>
#include <lasermines>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "lm"
#define LONG_NAME "Lasermines"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Lasermines"

int g_iTraitorPrice = 0;
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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/lasermines.cfg");

	Config_Setup("TTT-Lasermines", g_sConfigFile);
	
	g_iTraitorPrice = Config_LoadInt("lm_traitor_price", 9000, "The amount of credits for a lasermine costs. 0 to disable.");
}

public void OnAllPluginsLoaded()
{
	if(g_iTraitorPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iTraitorPrice, TTT_TEAM_TRAITOR);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(StrEqual(itemshort, SHORT_NAME, false))
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
					return Plugin_Stop;
			
			AddClientLasermines(client, 1);
		}
	}
	return Plugin_Continue;
}
