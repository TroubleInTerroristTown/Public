#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <tacticalshield>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Tactical Shield"

#define SHORT_NAME_D "tacticalShield_d"

ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cDiscount = null;
ConVar g_cForce = null;

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

	TTT_StartConfig("tactical_shield");
	CreateConVar("ttt2_tactical_shield_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("tactical_shield_name", "Tactical Shield", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("tactical_shield_price", "9000", "The amount of credits a tactical shield costs as detective. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("tactical_shield_sort_prio", "0", "The sorting priority of the tactical shield in the shop menu.");
	g_cDiscount = AutoExecConfig_CreateConVar("tactical_shield_discountable", "0", "Should tactical shield discountable?", _, true, 0.0, true, 1.0);
	g_cForce = AutoExecConfig_CreateConVar("tactical_shield_force", "0", "Force shield?", _, true, 0.0, true, 1.0);
	TTT_EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
	char sFile[] = "tacticalshield.smx";
	Handle hPlugin = FindPluginByFile(sFile);
	
	if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
	{
		SetFailState("You must have this plugin as base plugin for this items: https://forums.alliedmods.net/showthread.php?t=303333", sFile);
		return;
	}
	
	RegisterItem();
}

public Action TTT_OnItemsReset()
{
	RegisterItem();
}

void RegisterItem()
{
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue, g_cDiscount.BoolValue);
}

public void OnClientDisconnect(int client)
{
	ResetTacticalShield(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME_D, false))
		{
			int role = TTT_GetClientRole(client);

			if (role == TTT_TEAM_DETECTIVE)
			{
				if (g_cForce.BoolValue)
				{
					OverridePlayerShield(client, 2);
				}
				else
				{
					OverridePlayerShield(client, 1);
				}

				GivePlayerShield(client);
			}
			else
			{
				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}


public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetTacticalShield(client);
	}
}

void ResetTacticalShield(int client)
{
	RemovePlayerShield(client);
}
