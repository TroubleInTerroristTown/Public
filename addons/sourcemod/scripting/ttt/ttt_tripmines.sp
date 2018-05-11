#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <tripmines>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Tripmines"

#define SHORTNAME_T "tripmines"

ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cDiscount = null;
ConVar g_cAmount = null;

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

	TTT_StartConfig("tripmines");
	CreateConVar("ttt2_tripmines_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("tripmines_name", "Tripmines", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("tripmines_price", "9000", "The amount of credits a tripmines costs as detective. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("tripmines_sort_prio", "0", "The sorting priority of the tripmines in the shop menu.");
	g_cDiscount = AutoExecConfig_CreateConVar("tripmines_discountable", "0", "Should tripmines discountable?", _, true, 0.0, true, 1.0);
	g_cAmount = AutoExecConfig_CreateConVar("tripmines_mines", "1", "How mines get the player?", _, true, 1.0);
	TTT_EndConfig();
}

public void OnAllPluginsLoaded()
{
	char sFile[] = "tripmines.smx";
	Handle hPlugin = FindPluginByFile(sFile);
	
	if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
	{
		TTT_RemoveCustomItem(SHORTNAME_T);
		SetFailState("Can't find tripmines.smx! This file will be provided with TTT.");
		return;
	}
}

public void OnConfigsExecuted()
{
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
	TTT_RegisterCustomItem(SHORTNAME_T, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cDiscount.BoolValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORTNAME_T, false))
		{
			int role = TTT_GetClientRole(client);

			if (role == TTT_TEAM_TRAITOR)
			{
				Tripmine_AddClientMines(client, g_cAmount.IntValue);
			}
		}
	}
	return Plugin_Continue;
}
