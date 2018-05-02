#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "rdmTele"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Random Teleporter"

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
ConVar g_cDiscountT = null;
ConVar g_cDiscountD = null;
ConVar g_cDiscountI = null;
ConVar g_cRagdoll = null;

int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iIPCount[MAXPLAYERS + 1] =  { 0, ... };

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

	TTT_StartConfig("random_teleporter");
	CreateConVar("ttt2_random_teleporter_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("rt_name", "Random Teleporter", "The name of the Random Teleport in the Shop");
	g_cTPrice = AutoExecConfig_CreateConVar("rt_traitor_price", "9000", "The amount of credits for Random Teleport costs as traitor. 0 to disable.");
	g_cDPrice = AutoExecConfig_CreateConVar("rt_detective_price", "0", "The amount of credits for Random Teleport costs as detective. 0 to disable.");
	g_cIPrice = AutoExecConfig_CreateConVar("rt_innocent_price", "0", "The amount of credits for Random Teleport costs as innocent. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("rt_traitor_sort_prio", "0", "The sorting priority of the Random Teleport (Traitor) in the shop menu.");
	g_cDPrio = AutoExecConfig_CreateConVar("rt_detective_sort_prio", "0", "The sorting priority of the Random Teleport (Detective) in the shop menu.");
	g_cIPrio = AutoExecConfig_CreateConVar("rt_innocent_sort_prio", "0", "The sorting priority of the Random Teleport (innocent) in the shop menu.");
	g_cTCount = AutoExecConfig_CreateConVar("rt_traitor_count", "1", "The amount of usages for Random Teleports per round as traitor. 0 to disable.");
	g_cDCount = AutoExecConfig_CreateConVar("rt_detective_count", "1", "The amount of usages for Random Teleports per round as detective. 0 to disable.");
	g_cICount = AutoExecConfig_CreateConVar("rt_innocent_count", "1", "The amount of usages for Random Teleports per round as innocent. 0 to disable.");
	g_cDiscountT = AutoExecConfig_CreateConVar("rt_discount_traitor", "0", "Should Random Teleport discountable for traitors?", _, true, 0.0, true, 1.0);
	g_cDiscountD = AutoExecConfig_CreateConVar("rt_discount_detective", "0", "Should Random Teleport discountable for detectives?", _, true, 0.0, true, 1.0);
	g_cDiscountI = AutoExecConfig_CreateConVar("rt_discount_innocent", "0", "Should Random Teleport discountable for innocents?", _, true, 0.0, true, 1.0);
	g_cRagdoll = AutoExecConfig_CreateConVar("rt_teleport_ragdolls", "1", "Teleport with dead players (ragdoll)?", _, true, 1.0, true, 1.0);
	TTT_EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetItem(client);
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	RegisterItem();
}

public void TTT_OnItemsReset()
{
	RegisterItem();
}

void RegisterItem()
{
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cDiscountT.BoolValue);
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDiscountD.BoolValue);
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue, g_cDiscountI.BoolValue);
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
			else if (role == TTT_TEAM_INNOCENT && g_iIPCount[client] >= g_cICount.IntValue)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cICount.IntValue);
				return Plugin_Stop;
			}

			RandomTeleport(client);

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

int RandomTeleport(int client)
{
	bool bAlive = true;
	int[] iRagdoll = new int[Ragdolls];
	float fPlayerPos[3], fTargetPos[3];

	if (g_cRagdoll.BoolValue)
	{
		bAlive = false;
	}

	int target = TTT_GetRandomPlayer(bAlive);

	if (TTT_IsPlayerAlive(target))
	{
		GetClientAbsOrigin(client, fPlayerPos);
		GetClientAbsOrigin(target, fTargetPos);

		TeleportEntity(client, fTargetPos, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(target, fPlayerPos, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		if (!TTT_GetClientRagdoll(target, iRagdoll))
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Random Teleporter: Cant find ragdoll", client);
			return -1;
		}

		int body = EntRefToEntIndex(iRagdoll[Ent]);

		if (!IsValidEntity(body))
		{
			return -1;
		}

		float fAngles[3], fVelo[3];
		GetClientAbsOrigin(client, fPlayerPos);
		fPlayerPos[2] += 30;

		GetClientAbsAngles(client, fAngles);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelo);

		GetEntPropVector(body, Prop_Send, "m_vecOrigin", fTargetPos);

		TeleportEntity(client, fTargetPos, NULL_VECTOR, NULL_VECTOR);

		float speed = GetVectorLength(fVelo);
		if (speed >= 500)
		{
			TeleportEntity(body, fPlayerPos, fAngles, NULL_VECTOR);
		}
		else
		{
			TeleportEntity(body, fPlayerPos, fAngles, fVelo);
		}
	}

	CPrintToChat(client, "%s %T", g_sPluginTag, "Random Teleporter: Teleport", client, target);
	return target;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetItem(client);
	}
}

void ResetItem(int client)
{
	g_iTPCount[client] = 0;
	g_iDPCount[client] = 0;
	g_iIPCount[client] = 0;
}
