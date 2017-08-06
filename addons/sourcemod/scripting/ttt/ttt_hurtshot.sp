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

#define SHORT_NAME "hurtshot"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Hurtshot"

int g_iDamageType = 0;
int g_iDamage = 0;
int g_iRandomMinDamage = 0;
int g_iRandomMaxDamage = 0;

int g_iPrice = 0;
int g_iPrio = 0;
int g_iCount = 0;
int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iHurtshot[MAXPLAYERS + 1] =  { -1, ... };

bool g_bDebug = true;

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/hurtshot.cfg");

	Config_Setup("TTT-Hurtshot", g_sConfigFile);
	Config_LoadString("hurtshot_name", "Hurtshot", "The name of the Hurtshot in the Shop", g_sLongName, sizeof(g_sLongName));
	
	g_iPrice = Config_LoadInt("hurtshot_traitor_price", 9000, "The amount of credits for hurtshot costs as traitor. 0 to disable.");
	g_iCount = Config_LoadInt("hurtshot_traitor_count", 1, "The amount of usages for hurtshots per round as traitor. 0 to disable.");
	g_iPrio = Config_LoadInt("hurtshot_traitor_sort_prio", 0, "The sorting priority of the hurtshots (Traitor) in the shop menu.");
	
	Config_Done();
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetHurtshot(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		ResetHurtshot(client);
	}
}

public void OnAllPluginsLoaded()
{
	if (!g_bDebug)
		TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iPrice, TTT_TEAM_TRAITOR, g_iPrio);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role == TTT_TEAM_TRAITOR && g_iPCount[client] >= g_iCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iCount);
				return Plugin_Stop;
			}
			
			if (!HasHealthshot(client))
			{
				g_iHurtshot[client] = GivePlayerItem(client, "weapon_healthshot");
			}
			
			if (count)
			{
				if (role == TTT_TEAM_TRAITOR)
				{
					g_iPCount[client]++;
				}
			}
		}
	}
	return Plugin_Continue;
}

void ResetHurtshot(int client)
{
	g_iPCount[client] = 0;
}

bool HasHealthshot(int client)
{
	int entity = -1;
	while((entity = GetPlayerWeaponSlot(client, CS_SLOT_C4)) != -1)
	{
		char sWeapon[32];
		GetEdictClassname(entity, sWeapon, sizeof(sWeapon));
		
		if (StrEqual(sWeapon, "weapon_healthshot", false))
		{
			return true;
		}
	}
	
	return false;
}
