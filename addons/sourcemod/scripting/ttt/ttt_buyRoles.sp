#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>
#include <ttt_shop>
#include <multicolors>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Buy Roles"
#define T_SHORT_NAME "buyTRole"
#define D_SHORT_NAME "buyCTRole"

int g_iTPrice = 0;
int g_iTPrio = 0;

int g_iDPrice = 0;
int g_iDPrio = 0;

char g_sTLongName[64];
char g_sDLongName[64];

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/buyRoles.cfg");
	Config_Setup("TTT-BuyRoles", g_sConfigFile);
	
	Config_LoadString("broles_traitor_name", "Buy Traitor Role", "The name of the buy traitor role in the Shop", g_sTLongName, sizeof(g_sTLongName));
	Config_LoadString("broles_detective_name", "Buy Detective Role", "The name of the buy detective role in the Shop", g_sDLongName, sizeof(g_sDLongName));
	
	g_iTPrice = Config_LoadInt("broles_traitor_price", 9000, "The amount of credits that cost to buy the traitor role. 0 to disable.");
	g_iDPrice = Config_LoadInt("broles_detective_price", 9000, "The amount of credits that cost to buy the detective role. 0 to disable.");
	
	g_iTPrio = Config_LoadInt("broles_traitor_prio", 0, "The sorting priority of the buy traitor role in the shop menu.");
	g_iDPrio = Config_LoadInt("broles_detective_prio", 0, "The sorting priority of the buy detective role in the shop menu.");
	
	Config_Done();
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(T_SHORT_NAME, g_sTLongName, g_iTPrice, TTT_TEAM_INNOCENT, g_iTPrio);
	TTT_RegisterCustomItem(D_SHORT_NAME, g_sDLongName, g_iDPrice, TTT_TEAM_INNOCENT, g_iDPrio);
}


public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, D_SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role != TTT_TEAM_INNOCENT)
			{
				return Plugin_Stop;
			}
			
			TTT_ForceDetective(client);
		}
		else if (StrEqual(itemshort, T_SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role != TTT_TEAM_INNOCENT)
			{
				return Plugin_Stop;
			}
			
			TTT_ForceTraitor(client);
		}
	}
	return Plugin_Continue;
}