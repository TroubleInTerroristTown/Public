#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "decoyteleport"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Decoy Teleporter"

ConVar g_cTPrice = null;
ConVar g_cDPrice = null;
ConVar g_cTPrio = null;
ConVar g_cDPrio = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;
ConVar g_cRefund = null;
ConVar g_cLongName = null;

int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };

bool g_bHasTeleporter[MAXPLAYERS + 1] =  { false, ... };

ConVar g_cPluginTag = null;
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

	LoadTranslations("ttt.phrases");

	StartConfig("decoy_teleporter");
	CreateConVar("ttt2_decoy_teleporter_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("dt_name", "Decoy Teleprter", "The name of the Decoy Teleporter in the Shop");
	g_cTPrice = AutoExecConfig_CreateConVar("dt_traitor_price", "9000", "The amount of credits for decoy teleporter costs as traitor. 0 to disable.");
	g_cDPrice = AutoExecConfig_CreateConVar("dt_detective_price", "9000", "The amount of credits for decoy teleporter costs as detective. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("dt_traitor_sort_prio", "0", "The sorting priority of the decoy teleporter (Traitor) in the shop menu.");
	g_cDPrio = AutoExecConfig_CreateConVar("dt_detective_sort_prio", "0", "The sorting priority of the decoy teleporter (Detective) in the shop menu.");
	g_cTCount = AutoExecConfig_CreateConVar("dt_traitor_count", "1", "The amount of usages for decoy teleporters per round as traitor. 0 to disable.");
	g_cDCount = AutoExecConfig_CreateConVar("dt_detective_count", "1", "The amount of usages for decoy teleporters per round as detective. 0 to disable.");
	g_cRefund = AutoExecConfig_CreateConVar("dt_refund", "0", "Refund after a fail teleporter? 0 = Disabled/Nothing, 1 = Money back, 2 = New decoy");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("decoy_started", Event_DecoyStarted, EventHookMode_Pre);
}

public void OnClientDisconnect(int client)
{
	ResetDecoyCount(client);
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			char sBuffer[MAX_ITEM_LENGTH];
			g_cLongName.GetString(sBuffer, sizeof(sBuffer));

			if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_cTCount.IntValue)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cTCount.IntValue);
				return Plugin_Stop;
			}
			else if (role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_cDCount.IntValue)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cDCount.IntValue);
				return Plugin_Stop;
			}

			GivePlayerItem(client, "weapon_decoy");

			g_bHasTeleporter[client] = true;

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
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_DecoyStarted(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		int entity = event.GetInt("entityid");

		if (!g_bHasTeleporter[client])
		{
			return Plugin_Continue;
		}

		float fOldPos[3];
		GetClientAbsOrigin(client, fOldPos);

		float fPos[3];
		fPos[0] = event.GetFloat("x");
		fPos[1] = event.GetFloat("y");
		fPos[2] = event.GetFloat("z");

		TeleportEntity(client, fPos, NULL_VECTOR, NULL_VECTOR);

		bool stuck = StuckClient(client);

		if (stuck)
		{
			TeleportEntity(client, fOldPos, NULL_VECTOR, NULL_VECTOR);
			CPrintToChat(client, "%s %T", g_sPluginTag, "DT: Invalid Position", client);
		}

		AcceptEntityInput(entity, "kill");

		if (stuck && g_cRefund.IntValue == 1)
		{
			int role = TTT_GetClientRole(client);
			if (role == TTT_TEAM_TRAITOR)
			{
				TTT_AddClientCredits(client, g_cTPrice.IntValue);
			}
			else if (role == TTT_TEAM_DETECTIVE)
			{
				TTT_AddClientCredits(client, g_cDPrice.IntValue);
			}

			g_bHasTeleporter[client] = false;
		}
		else if (stuck && g_cRefund.IntValue == 2)
		{
			GivePlayerItem(client, "weapon_decoy");
		}
		else
		{
			g_bHasTeleporter[client] = false;
		}

		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetDecoyCount(client);
	}
}

void ResetDecoyCount(int client)
{
	g_iTPCount[client] = 0;
	g_iDPCount[client] = 0;

	g_bHasTeleporter[client] = false;
}

bool StuckClient(int client)
{
	float vOrigin[3];
	float vMins[3];
	float vMaxs[3];

	GetClientAbsOrigin(client, vOrigin);
	GetEntPropVector(client, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", vMaxs);

	TR_TraceHullFilter(vOrigin, vOrigin, vMins, vMaxs, MASK_ALL, OnlyPlayers, client);

	return TR_DidHit();
}

public bool OnlyPlayers(int entity, int contentsMask, any data)
{
	if (entity != data && entity > 0 && entity <= MaxClients)
	{
    	return true;
	}
	return false;
}
