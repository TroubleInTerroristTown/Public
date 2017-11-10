#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <ttt>
#include <ttt_shop>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Silent AWP"
#define SHORT_NAME_T "silentawp_t"
#define SHORT_NAME_D "silentawp_d"
#define SHORT_NAME_I "silentawp_i"

ConVar g_cPriceT = null;
ConVar g_cPriceD = null;
ConVar g_cPriceI = null;
ConVar g_cPriorityT = null;
ConVar g_cPriorityD = null;
ConVar g_cPriorityI = null;
ConVar g_cMaxShotsT = null;
ConVar g_cMaxShotsD = null;
ConVar g_cMaxShotsI = null;
ConVar g_cMinShotsT = null;
ConVar g_cMinShotsD = null;
ConVar g_cMinShotsI = null;
ConVar g_cAmountT = null;
ConVar g_cAmountD = null;
ConVar g_cAmountI = null;
ConVar g_cLongName = null;


int g_iPAmount[MAXPLAYERS + 1] =  { 0, ... };
int g_iWeapon[MAXPLAYERS + 1] =  { -1, ... };

bool g_bHasSilencer[MAXPLAYERS + 1] =  { false, ... };

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

	StartConfig("silent_awp");
	CreateConVar("ttt2_silent_awp_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("silent_awp_name", "Silent AWP", "The name of this in Shop");
	g_cAmountT = AutoExecConfig_CreateConVar("silent_awp_amount_t", "2", "How many AWPs can traitors buy?");
	g_cMinShotsT = AutoExecConfig_CreateConVar("silent_awp_min_t", "1", "Minimum shots for the AWP for Traitors");
	g_cMaxShotsT = AutoExecConfig_CreateConVar("silent_awp_max_t", "2", "Maximum shots for the AWP for Traitors");
	g_cPriorityT = AutoExecConfig_CreateConVar("silent_awp_priority_t", "0", "Priority in shop list for Traitors");
	g_cPriceT = AutoExecConfig_CreateConVar("silent_awp_price_t", "10000", "Price for the silenced AWP for Traitors");
	g_cAmountD = AutoExecConfig_CreateConVar("silent_awp_amount_d", "0", "How many AWPs can detectives buy?");
	g_cMinShotsD = AutoExecConfig_CreateConVar("silent_awp_min_d", "1", "Minimum shots for the AWP for Detectives");
	g_cMaxShotsD = AutoExecConfig_CreateConVar("silent_awp_max_d", "2", "Maximum shots for the AWP for Detectives");
	g_cPriorityD = AutoExecConfig_CreateConVar("silent_awp_priority_d", "0", "Priority in shop list for Detectives");
	g_cPriceD = AutoExecConfig_CreateConVar("silent_awp_price_d", "0", "Price for the silenced AWP for Detectives");
	g_cPriceI = AutoExecConfig_CreateConVar("silent_awp_price_i", "0", "Price for the silenced AWP for Innos");
	g_cPriorityI = AutoExecConfig_CreateConVar("silent_awp_priority_i", "0", "Priority in shop list for Innos");
	g_cMaxShotsI = AutoExecConfig_CreateConVar("silent_awp_max_i", "2", "Maximum shots for the AWP for Innos");
	g_cMinShotsI = AutoExecConfig_CreateConVar("silent_awp_min_i", "1", "Minimum shots for the AWP for Innos");
	g_cAmountI = AutoExecConfig_CreateConVar("silent_awp_amount_i", "0", "How many AWPs can innocents buy?");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);

	AddTempEntHook("Shotgun Shot", Hook_ShotgunShot);
}

public void OnConfigsExecuted()
{
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cPriceT.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME_I, sBuffer, g_cPriceD.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cPriceI.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI.IntValue);

}

public void OnClientDisconnect(int client)
{
	ResetSilentAWP(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetSilentAWP(client);
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if ((StrEqual(itemshort, SHORT_NAME_T, false) && g_iPAmount[client] < g_cAmountT.IntValue) ||
		(StrEqual(itemshort, SHORT_NAME_D, false) && g_iPAmount[client] < g_cAmountD.IntValue) ||
		(StrEqual(itemshort, SHORT_NAME_I, false) && g_iPAmount[client] < g_cAmountI.IntValue))
		{
			int iRole = TTT_GetClientRole(client);

			if (iRole == TTT_TEAM_TRAITOR && g_iPAmount[client] >= g_cAmountT.IntValue)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_cAmountT.IntValue);
				return Plugin_Stop;
			}
			else if (iRole == TTT_TEAM_DETECTIVE && g_iPAmount[client] >= g_cAmountD.IntValue)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_cAmountD.IntValue);
				return Plugin_Stop;
			}
			else if (iRole == TTT_TEAM_INNOCENT && g_iPAmount[client] >= g_cAmountI.IntValue)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_cAmountI.IntValue);
				return Plugin_Stop;
			}

			int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
			if (iWeapon != -1)
			{
				TTT_SafeRemoveWeapon(client, iWeapon);
			}

			g_iWeapon[client] = GivePlayerItem(client, "weapon_awp");
			EquipPlayerWeapon(client, g_iWeapon[client]);

			int max = 0;
			int min = 0;

			if (iRole == TTT_TEAM_TRAITOR)
			{
				max = g_cMaxShotsT.IntValue;
				min = g_cMinShotsT.IntValue;
			}
			else if (iRole == TTT_TEAM_DETECTIVE)
			{
				max = g_cMaxShotsD.IntValue;
				min = g_cMinShotsD.IntValue;
			}
			else if (iRole == TTT_TEAM_INNOCENT)
			{
				max = g_cMaxShotsI.IntValue;
				min = g_cMinShotsI.IntValue;
			}

			SetEntProp(g_iWeapon[client], Prop_Send, "m_iClip1", GetRandomInt(min, max));
			SetEntProp(g_iWeapon[client], Prop_Send, "m_iPrimaryReserveAmmoCount", 0);

			g_bHasSilencer[client] = true;
		}
	}
	return Plugin_Continue;
}

public Action Hook_ShotgunShot(const char[] sample, const int[] Players, int numClients, float delay)
{
	int client = TE_ReadNum("m_iPlayer") + 1;

	if(!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}

	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if (g_iWeapon[client] == iWeapon)
	{
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		
		if(StrEqual(sWeapon, "weapon_awp", false) && g_bHasSilencer[client])
		{
			return Plugin_Stop;
		}
	}

	return Plugin_Continue;
}

void ResetSilentAWP(int client)
{
	g_iPAmount[client] = 0;
	g_bHasSilencer[client] = false;
	g_iWeapon[client] = -1;
}
