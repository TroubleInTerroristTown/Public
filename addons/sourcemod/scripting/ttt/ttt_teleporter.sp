#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Teleporter"
#define SHORT_NAME "teleporter"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cCount = null;
ConVar g_cLongName = null;
ConVar g_cDiscount = null;

int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };

bool g_bTeleport[MAXPLAYERS + 1] =  { false, ... };

float g_fLocation[MAXPLAYERS + 1][3];

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

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
	
	TTT_StartConfig("teleporter");
	CreateConVar("ttt2_teleporter_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("teleporter_name", "Teleporter", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("teleporter_price", "9000", "The amount of credits Teleporter costs as traitor. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("teleporter_sort_prio", "0", "The sorting priority of the Teleporter in the shop menu.");
	g_cCount = AutoExecConfig_CreateConVar("teleporter_count", "2", "How often a players can port him back to the location");
	g_cDiscount = AutoExecConfig_CreateConVar("teleporter_discount", "0", "Should Teleporter discountable?", _, true, 0.0, true, 1.0);
	TTT_EndConfig();

	RegConsoleCmd("sm_tele", Command_Tele);

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	RegisterItem();
}

public Action TTT_OnItemsReset()
{
	RegisterItem();
}

void RegisterItem()
{
	char sName[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sName, sizeof(sName));
	
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cDiscount.BoolValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	}
}

public void OnClientDisconnect(int client)
{
	ResetTeleporter(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			
			GetClientAbsOrigin(client, g_fLocation[client]);
			
			g_bTeleport[client] = true;
			g_iPCount[client] = 0;

			CPrintToChat(client, "%s %T", g_sPluginTag, "Location Saved", client);
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetTeleporter(client);
	}
}

public Action Command_Tele(int client, int args)
{
	if (!TTT_IsClientValid(client) || !g_bTeleport[client])
	{
		return Plugin_Handled;
	}
	
	if (g_iPCount[client] >= g_cCount.IntValue)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Teleport Max", client, g_cCount.IntValue);
		return Plugin_Handled;
	}
	
	TeleportEntity(client, g_fLocation[client], NULL_VECTOR, NULL_VECTOR);
	g_iPCount[client]++;
	
	return Plugin_Continue;
}

void ResetTeleporter(int client)
{
	g_bTeleport[client] = false;
	g_iPCount[client] = 0;
}
