#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <ttt>
#include <ttt_shop>
#include <config_loader>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Silent AWP"
#define SHORT_NAME_T "silentawp_t"
#define SHORT_NAME_D "silentawp_d"
#define SHORT_NAME_I "silentawp_i"

int g_iPriceT = -1;
int g_iPriceD = -1;
int g_iPriceI = -1;
int g_iPriorityT = -1;
int g_iPriorityD = -1;
int g_iPriorityI = -1;
int g_iMaxShotsT = -1;
int g_iMaxShotsD = -1;
int g_iMaxShotsI = -1;
int g_iMinShotsT = -1;
int g_iMinShotsD = -1;
int g_iMinShotsI = -1;
int g_iAmountT = -1;
int g_iAmountD = -1;
int g_iAmountI = -1;

char g_sConfigFile[PLATFORM_MAX_PATH];
char g_sLongName[64];

int g_iPAmount[MAXPLAYERS + 1] =  { 0, ... };

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

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/knockout.cfg");
	Config_Setup("TTT-Knockout", g_sConfigFile);
	Config_LoadString("silent_awp_name", "Silent AWP", "The name of this in Shop", g_sLongName, sizeof(g_sLongName));

	g_iAmountT = Config_LoadInt("silent_awp_amount_t", 2, "How many AWPs can traitors buy?");
	g_iMinShotsT = Config_LoadInt("silent_awp_min_t", 1, "Minimum shots for the AWP for Traitors");
	g_iMaxShotsT = Config_LoadInt("silent_awp_max_t", 2, "Maximum shots for the AWP for Traitors");
	g_iPriorityT = Config_LoadInt("silent_awp_priority_t", 0, "Priority in shop list for Traitors");
	g_iPriceT = Config_LoadInt("silent_awp_price_t", 10000, "Price for the silenced AWP for Traitors");

	g_iAmountD = Config_LoadInt("silent_awp_amount_d", 0, "How many AWPs can detectives buy?");
	g_iMinShotsD = Config_LoadInt("silent_awp_min_d", 1, "Minimum shots for the AWP for Detectives");
	g_iMaxShotsD = Config_LoadInt("silent_awp_max_d", 2, "Maximum shots for the AWP for Detectives");
	g_iPriorityD = Config_LoadInt("silent_awp_priority_d", 0, "Priority in shop list for Detectives");
	g_iPriceD = Config_LoadInt("silent_awp_price_d", 0, "Price for the silenced AWP for Detectives");

	g_iPriceI = Config_LoadInt("silent_awp_price_i", 0, "Price for the silenced AWP for Innos");
	g_iPriorityI = Config_LoadInt("silent_awp_priority_i", 0, "Priority in shop list for Innos");
	g_iMaxShotsI = Config_LoadInt("silent_awp_max_i", 2, "Maximum shots for the AWP for Innos");
	g_iMinShotsI = Config_LoadInt("silent_awp_min_i", 1, "Minimum shots for the AWP for Innos");
	g_iAmountI = Config_LoadInt("silent_awp_amount_i", 0, "How many AWPs can innocents buy?");

	Config_Done();

	HookEvent("player_spawn", Event_PlayerSpawn);

	AddTempEntHook("Shotgun Shot", Hook_ShotgunShot);
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME_T, g_sLongName, g_iPriceT, TTT_TEAM_TRAITOR, g_iPriorityT);
	TTT_RegisterCustomItem(SHORT_NAME_I, g_sLongName, g_iPriceD, TTT_TEAM_DETECTIVE, g_iPriorityD);
	TTT_RegisterCustomItem(SHORT_NAME_D, g_sLongName, g_iPriceI, TTT_TEAM_INNOCENT, g_iPriorityI);

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
		if ((StrEqual(itemshort, SHORT_NAME_T, false) && g_iPAmount[client] < g_iAmountT) ||
		(StrEqual(itemshort, SHORT_NAME_D, false) && g_iPAmount[client] < g_iAmountD) ||
		(StrEqual(itemshort, SHORT_NAME_I, false) && g_iPAmount[client] < g_iAmountI))
		{
			int iRole = TTT_GetClientRole(client);

			if (iRole == TTT_TEAM_TRAITOR && g_iPAmount[client] >= g_iAmountT)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_iAmountT);
				return Plugin_Stop;
			}
			else if (iRole == TTT_TEAM_DETECTIVE && g_iPAmount[client] >= g_iAmountD)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_iAmountD);
				return Plugin_Stop;
			}
			else if (iRole == TTT_TEAM_INNOCENT && g_iPAmount[client] >= g_iAmountI)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_iAmountI);
				return Plugin_Stop;
			}

			int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
			if (iWeapon != -1)
			{
				TTT_SafeRemoveWeapon(client, iWeapon);
			}

			iWeapon = GivePlayerItem(client, "weapon_awp");
			EquipPlayerWeapon(client, iWeapon);

			int max = 0;
			int min = 0;

			if (iRole == TTT_TEAM_TRAITOR)
			{
				max = g_iMaxShotsT;
				min = g_iMinShotsT;
			}
			else if (iRole == TTT_TEAM_DETECTIVE)
			{
				max = g_iMaxShotsD;
				min = g_iMinShotsD;
			}
			else if (iRole == TTT_TEAM_INNOCENT)
			{
				max = g_iMaxShotsI;
				min = g_iMinShotsI;
			}

			SetEntProp(iWeapon, Prop_Send, "m_iClip1", GetRandomInt(min, max));
			SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);

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

	char sWeapon[32];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));

	if(StrEqual(sWeapon, "weapon_awp", false) && g_bHasSilencer[client])
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void ResetSilentAWP(int client)
{
	g_iPAmount[client] = 0;
	g_bHasSilencer[client] = false;
}
