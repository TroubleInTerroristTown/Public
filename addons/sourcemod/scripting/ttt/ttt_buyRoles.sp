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
#define TI_SHORT_NAME "buyTiRole"

#define D_SHORT_NAME "buyCTRole"
#define DI_SHORT_NAME "buyCTiRole"

int g_iTPrice = 0;
int g_iTPrio = 0;

int g_iTiPrice = 0;
int g_iTiPrio = 0;

int g_iDPrice = 0;
int g_iDPrio = 0;

int g_iDiPrice = 0;
int g_iDiPrio = 0;

char g_sTLongName[64];
char g_sTiLongName[64];
char g_sDLongName[64];
char g_sDiLongName[64];

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/buyRoles.cfg");
	Config_Setup("TTT-BuyRoles", g_sConfigFile);
	
	Config_LoadString("broles_traitor_name", "Buy Traitor Role", "The name of the buy traitor role in the Shop", g_sTLongName, sizeof(g_sTLongName));
	Config_LoadString("broles_traitor_instantly_name", "Buy Traitor Role Instantly", "The name of the buy traitor role in the Shop", g_sTiLongName, sizeof(g_sTiLongName));
	Config_LoadString("broles_detective_name", "Buy Detective Role", "The name of the buy detective role in the Shop", g_sDLongName, sizeof(g_sDLongName));
	Config_LoadString("broles_detective_instantly_name", "Buy Detective Role Instantly", "The name of the buy detective role in the Shop", g_sDiLongName, sizeof(g_sDiLongName));
	
	g_iTPrice = Config_LoadInt("broles_traitor_price", 9000, "The amount of credits that cost to buy the traitor role. 0 to disable.");
	g_iTiPrice = Config_LoadInt("broles_traitor_instantly_price", 40000, "The amount of credits that cost to buy the traitor instantly role. 0 to disable.");
	
	g_iDPrice = Config_LoadInt("broles_detective_price", 9000, "The amount of credits that cost to buy the detective role. 0 to disable.");
	g_iDiPrice = Config_LoadInt("broles_detective_instantly_price", 10000, "The amount of credits that cost to buy the detective instantly role. 0 to disable.");
	
	g_iTPrio = Config_LoadInt("broles_traitor_prio", 0, "The sorting priority of the buy traitor role in the shop menu.");
	g_iTiPrio = Config_LoadInt("broles_traitor_instantly_prio", 0, "The sorting priority of the buy traitor instantly role in the shop menu.");
	
	g_iDPrio = Config_LoadInt("broles_detective_prio", 0, "The sorting priority of the buy detective role in the shop menu.");
	g_iDiPrio = Config_LoadInt("broles_detective_instantly_prio", 0, "The sorting priority of the buy detective instantly role in the shop menu.");
	
	Config_Done();
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(T_SHORT_NAME, g_sTLongName, g_iTPrice, TTT_TEAM_INNOCENT, g_iTPrio);
	TTT_RegisterCustomItem(TI_SHORT_NAME, g_sTiLongName, g_iTiPrice, TTT_TEAM_INNOCENT, g_iTiPrio);
	
	TTT_RegisterCustomItem(D_SHORT_NAME, g_sDLongName, g_iDPrice, TTT_TEAM_INNOCENT, g_iDPrio);
	TTT_RegisterCustomItem(DI_SHORT_NAME, g_sDiLongName, g_iDiPrice, TTT_TEAM_INNOCENT, g_iDiPrio);
}


public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
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
			
			if(!TTT_ForceDetective(client))
				return Plugin_Stop;
		}
		else if (StrEqual(itemshort, T_SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role != TTT_TEAM_INNOCENT)
			{
				return Plugin_Stop;
			}
			
			if(!TTT_ForceTraitor(client))
				return Plugin_Stop;
		}
		else if (StrEqual(itemshort, DI_SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role != TTT_TEAM_INNOCENT)
			{
				return Plugin_Stop;
			}
			
			TTT_SetClientRole(client, TTT_TEAM_DETECTIVE);
		}
		else if (StrEqual(itemshort, TI_SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role != TTT_TEAM_INNOCENT)
			{
				return Plugin_Stop;
			}
			
			TTT_SetClientRole(client, TTT_TEAM_TRAITOR);
		}
	}
	return Plugin_Continue;
}