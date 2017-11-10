#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "taser"
#define SHORT_NAME_T "taser_t"
#define SHORT_NAME_D "taser_d"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Taser"

Handle g_hOnTased;

ConVar g_cDPrice = null;
ConVar g_cIPrice = null;
ConVar g_cTPrice = null;
ConVar g_cDPrio = null;
ConVar g_cIPrio = null;
ConVar g_cTPrio = null;
ConVar g_cDCount = null;
ConVar g_cICount = null;
ConVar g_cTCount = null;
ConVar g_cDamage = null;
ConVar g_cOnSpawn = null;
ConVar g_cBroadcastTaserResult = null;
ConVar g_cTDamage = null;
ConVar g_cInflictor = null;
ConVar g_cLongName = null;

char g_sPluginTag[PLATFORM_MAX_PATH] = "";

int g_iIPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };
bool g_bTaser[MAXPLAYERS + 1] =  { false, ... };



public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hOnTased = CreateGlobalForward("TTT_OnTased", ET_Ignore, Param_Cell, Param_Cell);
	
	RegPluginLibrary("ttt_taser");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	LoadTranslations("ttt.phrases");

	StartConfig("taser");
	CreateConVar("ttt2_taser_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cDPrice = AutoExecConfig_CreateConVar("ta_detective_price", "9000", "The amount of credits a taser costs as detective. 0 to disable.");
	g_cIPrice = AutoExecConfig_CreateConVar("ta_innocent_price", "9000", "The amount of credits a taser costs as innocent. 0 to disable.");
	g_cTPrice = AutoExecConfig_CreateConVar("ta_traitor_price", "0", "The amount of credits a taser costs as traitor. 0 to disable.");
	g_cDPrio = AutoExecConfig_CreateConVar("ta_detective_sort_prio", "0", "The sorting priority of the taser (Detective) in the shop menu.");
	g_cIPrio = AutoExecConfig_CreateConVar("ta_innocent_sort_prio", "0", "The sorting priority of the taser (Innocent) in the shop menu.");
	g_cTPrio = AutoExecConfig_CreateConVar("ta_traitor_sort_prio", "0", "The sorting priority of the taser (Traitor) in the shop menu.");
	g_cDCount = AutoExecConfig_CreateConVar("ta_detective_count", "1", "The amount of usages for tasers per round as detective. 0 to disable.");
	g_cICount = AutoExecConfig_CreateConVar("ta_innocent_count", "1", "The amount of usages for tasers per round as innocent. 0 to disable.");
	g_cTCount = AutoExecConfig_CreateConVar("ta_traitor_count", "1", "The amount of usages for tasers per round as traitor. 0 to disable.");
	g_cDamage = AutoExecConfig_CreateConVar("ta_damage", "0", "The amount of damage a taser deals for detectives and innocents");
	g_cTDamage = AutoExecConfig_CreateConVar("ta_traitor_damage", "0", "The amount of damage a taser deals for traitors");
	g_cOnSpawn = AutoExecConfig_CreateConVar("ta_give_taser_spawn", "1", "Give the Detective a taser when he spawns?", _, true, 0.0, true, 1.0);
	g_cBroadcastTaserResult = AutoExecConfig_CreateConVar("ta_broadcast_taser_result", "0", "When set to true the results of the taser message will be printed to everyone instead of the client that tased", _, true, 0.0, true, 1.0);
	g_cInflictor = AutoExecConfig_CreateConVar("ta_barrel_fix", "1", "Prevent bug with taser and a explosive barrel", _, true, 0.0, true, 1.0);
	g_cLongName = AutoExecConfig_CreateConVar("ta_name", "Taser", "The name of this in Shop");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("item_equip", Event_ItemEquip);

	LateLoadAll();
}

public void OnConfigsExecuted()
{
	ConVar hTag = FindConVar("ttt_plugin_tag");
	hTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
}

public void OnClientDisconnect(int client)
{
	ResetTaser(client);
}

public void OnClientPutInServer(int client)
{
	HookClient(client);
}

public void LateLoadAll()
{
	LoopValidClients(i)
	{
		LateLoadClient(i);
	}
}
public void LateLoadClient(int client)
{
	HookClient(client);
}

public void HookClient(int client)
{
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

public void TTT_OnClientGetRole(int client, int role)
{
	if (role == TTT_TEAM_DETECTIVE && g_cOnSpawn.BoolValue)
	{
		if (g_bTaser[client])
		{
			return;
		}

		GivePlayerItem(client, "weapon_taser");
		g_iDPCount[client]++;
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetTaser(client);
	}
}

public Action Event_ItemEquip(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	char sWeapon[32];
	event.GetString("item", sWeapon, sizeof(sWeapon));

	if (StrContains(sWeapon, "taser", false) != -1)
	{
		g_bTaser[client] = true;
	}
}

public Action OnWeaponDrop(int client, int weapon)
{
	if (weapon == -1)
	{
		return;
	}

	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

	if (StrContains(sWeapon, "taser", false) != -1)
	{
		g_bTaser[client] = false;
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false) || StrEqual(itemshort, SHORT_NAME_D, false) || StrEqual(itemshort, SHORT_NAME_T, false))
		{
			int role = TTT_GetClientRole(client);

			if (role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_cDCount.IntValue)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "TaserMax", client, g_cDCount.IntValue);
				return Plugin_Stop;
			}
			else if (role == TTT_TEAM_INNOCENT && g_iIPCount[client] >= g_cICount.IntValue)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "TaserMax", client, g_cICount.IntValue);
				return Plugin_Stop;
			}
			else if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_cTCount.IntValue)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "TaserMax", client, g_cTCount.IntValue);
				return Plugin_Stop;
			}

			if (g_bTaser[client])
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "AlreadyTaser", client);
				return Plugin_Stop;
			}

			GivePlayerItem(client, "weapon_taser");
			g_bTaser[client] = true;

			if (count)
			{
				if (role == TTT_TEAM_DETECTIVE)
				{
					g_iDPCount[client]++;
				}
				else if (role == TTT_TEAM_INNOCENT)
				{
					g_iIPCount[client]++;
				}
				else if (role == TTT_TEAM_TRAITOR)
				{
					g_iTPCount[client]++;
				}
			}
		}
	}
	return Plugin_Continue;
}

void ResetTaser(int client)
{
	g_iDPCount[client] = 0;
	g_iIPCount[client] = 0;
	g_iTPCount[client] = 0;

	g_bTaser[client] = false;
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!TTT_IsRoundActive())
	{
		return Plugin_Continue;
	}

	if (!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
	{
		return Plugin_Continue;
	}

	if (IsWorldDamage(iAttacker, damagetype))
	{
		return Plugin_Continue;
	}

	if (!g_bTaser[iAttacker])
	{
		return Plugin_Continue;
	}

	if (g_cInflictor.BoolValue && iAttacker != inflictor)
	{
		return Plugin_Continue;
	}

	char sWeapon[64];
	int iRole = TTT_GetClientRole(iVictim);
	int iARole = TTT_GetClientRole(iAttacker);
	GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));
	if (StrContains(sWeapon, "taser", false) != -1)
	{
		char sAttackerID[32], sVictimID[32];
		
		ConVar hTag = FindConVar("ttt_steamid_add_to_logs");
		if (hTag.BoolValue)
		{
			hTag = FindConVar("ttt_steamid_log_format");
			if (hTag.IntValue == 1)
			{
				GetClientAuthId(iAttacker, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
				GetClientAuthId(iVictim, AuthId_Steam2, sVictimID, sizeof(sVictimID));
			}
			else if (hTag.IntValue == 2)
			{
				GetClientAuthId(iAttacker, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
				GetClientAuthId(iVictim, AuthId_Steam3, sVictimID, sizeof(sVictimID));
			}
			else if (hTag.IntValue == 3)
			{
				GetClientAuthId(iAttacker, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
				GetClientAuthId(iVictim, AuthId_SteamID64, sVictimID, sizeof(sVictimID));
			}
			
			if (strlen(sAttackerID) > 2 && strlen(sVictimID) > 2)
			{
				Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
				Format(sVictimID, sizeof(sVictimID), " (%s)", sVictimID);
			}
		}
		
		if (iRole == TTT_TEAM_TRAITOR)
		{
			TTT_LogString("-> [%N%s (Traitor) was tased by %N%s] - TRAITOR DETECTED", iVictim, sVictimID, iAttacker, iVictim, sAttackerID);

			if (g_cBroadcastTaserResult.BoolValue)
			{
				CPrintToChatAll("%s %T", g_sPluginTag, "You tased a Traitor", LANG_SERVER, iAttacker, iVictim);
			}
			else
			{
				CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "You hurt a Traitor", iVictim, iVictim);
			}
			
			hTag = FindConVar("ttt_hurt_traitor_with_taser");
			TTT_SetClientCredits(iAttacker, TTT_GetClientCredits(iAttacker) + hTag.IntValue);
		}
		else if (iRole == TTT_TEAM_DETECTIVE)
		{
			TTT_LogString("-> [%N%s (Detective) was tased by %N%s]", iVictim, sVictimID, iAttacker, iVictim, sAttackerID);

			if (g_cBroadcastTaserResult.BoolValue)
			{
				CPrintToChatAll("%s %T", g_sPluginTag, "You tased a Detective", LANG_SERVER, iAttacker , iVictim);
			}
			else
			{
				CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "You hurt a Detective", iVictim, iVictim);
			}
		}
		else if (iRole == TTT_TEAM_INNOCENT)
		{
			TTT_LogString("-> [%N%s (Innocent) was tased by %N%s]", iVictim, sVictimID, iAttacker, iVictim, sAttackerID);

			if (g_cBroadcastTaserResult.BoolValue)
			{
				CPrintToChatAll("%s %T", g_sPluginTag, "You tased an Innocent", LANG_SERVER, iAttacker, iVictim);
			}
			else
			{
				CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "You hurt an Innocent", iVictim, iVictim);
			}
		}
		
		Call_StartForward(g_hOnTased);
		Call_PushCell(iAttacker);
		Call_PushCell(iVictim);
		Call_Finish();

		g_bTaser[iAttacker] = false;

		if (iARole != TTT_TEAM_TRAITOR)
		{
			if (g_cDamage.IntValue == 0)
			{
				return Plugin_Handled;
			}
			else if (g_cDamage.IntValue > 0)
			{
				damage = g_cDamage.IntValue + 0.0;
				return Plugin_Changed;
			}
		}
		else
		{
			damage = g_cTDamage.IntValue + 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}
