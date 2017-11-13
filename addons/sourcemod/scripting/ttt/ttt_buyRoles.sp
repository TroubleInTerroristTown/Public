#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <multicolors>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Buy Roles"

#define T_SHORT_NAME "buyTRole"
#define TI_SHORT_NAME "buyTiRole"

#define D_SHORT_NAME "buyCTRole"
#define DI_SHORT_NAME "buyCTiRole"

ConVar g_cTPrice = null;
ConVar g_cTPrio = null;
ConVar g_cTiPrice = null;
ConVar g_cTiPrio = null;
ConVar g_cDPrice = null;
ConVar g_cDPrio = null;
ConVar g_cDiPrice = null;
ConVar g_cDiPrio = null;
ConVar g_cTLongName = null;
ConVar g_cTiLongName = null;
ConVar g_cDLongName = null;
ConVar g_cDiLongName = null;

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

	StartConfig("buyroles");
	CreateConVar("ttt2_buy_roles_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cTLongName = AutoExecConfig_CreateConVar("buyroles_traitor_name", "Buy Traitor Role", "The name of the buy traitor role in the Shop");
	g_cTiLongName = AutoExecConfig_CreateConVar("buyroles_traitor_instantly_name", "Buy Traitor Role Instantly", "The name of the buy traitor role in the Shop");
	g_cDLongName = AutoExecConfig_CreateConVar("buyroles_detective_name", "Buy Detective Role", "The name of the buy detective role in the Shop");
	g_cDiLongName = AutoExecConfig_CreateConVar("buyroles_detective_instantly_name", "Buy Detective Role Instantly", "The name of the buy detective role in the Shop");
	g_cTPrice = AutoExecConfig_CreateConVar("buyroles_traitor_price", "9000", "The amount of credits that cost to buy the traitor role. 0 to disable.");
	g_cTiPrice = AutoExecConfig_CreateConVar("buyroles_traitor_instantly_price", "40000", "The amount of credits that cost to buy the traitor instantly role. 0 to disable.");
	g_cDPrice = AutoExecConfig_CreateConVar("buyroles_detective_price", "9000", "The amount of credits that cost to buy the detective role. 0 to disable.");
	g_cDiPrice = AutoExecConfig_CreateConVar("buyroles_detective_instantly_price", "10000", "The amount of credits that cost to buy the detective instantly role. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("buyroles_traitor_prio", "0", "The sorting priority of the buy traitor role in the shop menu.");
	g_cTiPrio = AutoExecConfig_CreateConVar("buyroles_traitor_instantly_prio", "0", "The sorting priority of the buy traitor instantly role in the shop menu.");
	g_cDPrio = AutoExecConfig_CreateConVar("buyroles_detective_prio", "0", "The sorting priority of the buy detective role in the shop menu.");
	g_cDiPrio = AutoExecConfig_CreateConVar("buyroles_detective_instantly_prio", "0", "The sorting priority of the buy detective instantly role in the shop menu.");
	EndConfig();
}

public void .IntValue()
{
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cTLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(T_SHORT_NAME, sBuffer, g_cTPrice.IntValue, TTT_TEAM_INNOCENT, g_cTPrio.IntValue);
	
	g_cTiLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(TI_SHORT_NAME, sBuffer, g_cTiPrice.IntValue, TTT_TEAM_INNOCENT, g_cTiPrio.IntValue);
	
	g_cDLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(D_SHORT_NAME, sBuffer, g_cDPrice.IntValue, TTT_TEAM_INNOCENT, g_cDPrio.IntValue);
	
	g_cDiLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(DI_SHORT_NAME, sBuffer, g_cDiPrice.IntValue, TTT_TEAM_INNOCENT, g_cDiPrio.IntValue);
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
