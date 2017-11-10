#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <ttt_shop>
#include <ttt>

#define SHORT_NAME_I "id"
#define SHORT_NAME_T "id_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: ID"

ConVar g_cTPrice = null;
ConVar g_cIPrice = null;
ConVar g_cTPrio = null;
ConVar g_cIPrio = null;
ConVar g_cLongNameT = null;
ConVar g_cLongNameI = null;
ConVar g_cCooldown = null;

bool g_bHasID[MAXPLAYERS + 1] =  { false, ... };

float g_fCooldownPlayer[MAXPLAYERS + 1] = {0.0, ...};

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

	StartConfig("id");
	CreateConVar("ttt2_id_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cTPrice = AutoExecConfig_CreateConVar("id_traitor_price", "1000", "The amount of credits for fake ID costs as traitor. 0 to disable.");
	g_cIPrice = AutoExecConfig_CreateConVar("id_innocent_price", "1000", "The amount of credits for ID costs as innocent. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("id_traitor_sort_prio", "0", "The sorting priority of the fake ID in the shop menu.");
	g_cIPrio = AutoExecConfig_CreateConVar("id_innocent_sort_prio", "0", "The sorting priority of the ID in the shop menu.");
	g_cCooldown = AutoExecConfig_CreateConVar("id_cooldown_time", "0.0", "The cooldown for the !id command. Set it to 0.0 to disable the cooldown");
	g_cLongNameT = AutoExecConfig_CreateConVar("id_name_innocent", "ID", "The name of this in Innocent Shop");
	g_cLongNameI = AutoExecConfig_CreateConVar("id_name_traitor", "(Fake) ID", "The name of this in Traitor Shop");
	EndConfig();

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

	if (g_cCooldown.FloatValue > 0.0)
	{
		if (g_fCooldownPlayer[client] != 0.0 && ((GetEngineTime() - g_fCooldownPlayer[client]) < g_cCooldown.FloatValue))
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Cooldown", client);
			return Plugin_Handled;
		}
		g_fCooldownPlayer[client] = GetEngineTime();
	}


	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Need to be Alive", client);
		return Plugin_Handled;
	}

	if (!g_bHasID[client])
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Need to buy ID", client);
		return Plugin_Handled;
	}

	char sName[MAX_NAME_LENGTH];
	if (!GetClientName(client, sName, sizeof(sName)))
	{
		return Plugin_Handled;
	}

	LoopValidClients(i)
	{
		CPrintToChat(i, "%s %T", g_sPluginTag, "ID: Shows ID", i, sName);
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	ResetID(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetID(client);
	}
}

public void OnConfigsExecuted()
{
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cLongNameT.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
	
	g_cLongNameI.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_I, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue);
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

			CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Buy Message", client);

			g_bHasID[client] = true;
		}
	}
	return Plugin_Continue;
}

void ResetID(int client)
{
	g_bHasID[client] = false;
	g_fCooldownPlayer[client] = 0.0;
}
