#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "healthshot"
#define SHORT_NAME_D "healthshot_d"
#define SHORT_NAME_T "healthshot_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Healthshot"

ConVar g_cTPrice = null;
ConVar g_cDPrice = null;
ConVar g_cIPrice = null;
ConVar g_cTPrio = null;
ConVar g_cDPrio = null;
ConVar g_cIPrio = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;
ConVar g_cICount = null;
ConVar g_cLongName = null;

int g_iIPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };

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

	StartConfig("healthshot");
	CreateConVar("ttt2_healthshot_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("hs_name", "Healthshot", "The name of the Healtshot in the Shop");
	g_cTPrice = AutoExecConfig_CreateConVar("hs_traitor_price", "9000", "The amount of credits for healthshot costs as traitor. 0 to disable.");
	g_cDPrice = AutoExecConfig_CreateConVar("hs_detective_price", "9000", "The amount of credits for healthshot costs as detective. 0 to disable.");
	g_cIPrice = AutoExecConfig_CreateConVar("hs_innocent_price", "9000", "The amount of credits for healthshot costs as innocent. 0 to disable.");
	g_cTCount = AutoExecConfig_CreateConVar("hs_traitor_count", "1", "The amount of usages for healthshots per round as traitor. 0 to disable.");
	g_cDCount = AutoExecConfig_CreateConVar("hs_detective_count", "1", "The amount of usages for healthshots per round as detective. 0 to disable.");
	g_cICount = AutoExecConfig_CreateConVar("hs_innocent_count", "1", "The amount of usages for healthshots per round as innocent. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("hs_traitor_sort_prio", "0", "The sorting priority of the healthshots (Traitor) in the shop menu.");
	g_cDPrio = AutoExecConfig_CreateConVar("hs_detective_sort_prio", "0", "The sorting priority of the healthshots (Detective) in the shop menu.");
	g_cIPrio = AutoExecConfig_CreateConVar("hs_innocent_sort_prio", "0", "The sorting priority of the healthshots (Innocent) in the shop menu.");
	EndConfig();

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

public void OnConfigsExecuted()
{
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	
	TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false) || StrEqual(itemshort, SHORT_NAME_D, false) || StrEqual(itemshort, SHORT_NAME_T, false))
		{
			int role = TTT_GetClientRole(client);
			
			char sPluginTag[128];
			char sLongName[MAX_ITEM_LENGTH];
			ConVar hTag = FindConVar("ttt_plugin_tag");
			
			g_cLongName.GetString(sLongName, sizeof(sLongName));
			hTag.GetString(sPluginTag, sizeof(sPluginTag));
			
			if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_cTCount.IntValue)
			{
				CPrintToChat(client, sPluginTag, "Bought All", client, sLongName, g_cTCount.IntValue);
				return Plugin_Stop;
			}
			else if (role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_cDCount.IntValue)
			{
				CPrintToChat(client, sPluginTag, "Bought All", client, sLongName, g_cDCount.IntValue);
				return Plugin_Stop;
			}
			else if (role == TTT_TEAM_INNOCENT && g_iIPCount[client] >= g_cICount.IntValue)
			{
				CPrintToChat(client, sPluginTag, "Bought All", client, sLongName, g_cICount.IntValue);
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
