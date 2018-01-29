#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <multicolors>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Dna Scanner"
#define SHORT_NAME "dnascanner"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cPrintTo = null;
ConVar g_cLongName = null;
ConVar g_cDiscount = null;

bool g_bHasScanner[MAXPLAYERS + 1] =  { false, ... };

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
	
	TTT_StartConfig("dnascanner");
	CreateConVar("ttt2_dna_scanner_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("dna_name", "Dnascanner", "The name of the Dnascanner in the Shop");
	g_cPrice = AutoExecConfig_CreateConVar("dna_price", "9000", "The amount of credits a dna scanner costs as detective. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("dna_sort_prio", "0", "The sorting priority of the dna scanner in the shop menu.");
	g_cPrintTo = AutoExecConfig_CreateConVar("dna_print_message_to", "0", "Print scanner to... 0 - Nothing just detective, 1 - All detectives, 2 - All players (Default: 0)", _, true, 0.0, true, 2.0);
	g_cDiscount = AutoExecConfig_CreateConVar("dna_discount", "0", "Should dna scanner discountable?", _, true, 0.0, true, 1.0);
	TTT_EndConfig();

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
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue, g_cDiscount.BoolValue);
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
	ResetScanner(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetScanner(client);
	}
}

void ResetScanner(int client)
{
	g_bHasScanner[client] = false;
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_DETECTIVE)
			{
				return Plugin_Stop;
			}

			g_bHasScanner[client] = true;
		}
	}
	return Plugin_Continue;
}

public Action TTT_OnBodyChecked(int client, int[] iRagdollC)
{
	if (iRagdollC[Scanned])
	{
		return Plugin_Continue;
	}

	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}

	if (TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE || g_bHasScanner[client] == false)
	{
		return Plugin_Continue;
	}
	
	int attacker = GetClientOfUserId(iRagdollC[Attacker]);
	int victim = GetClientOfUserId(iRagdollC[Victim]);

	if (attacker > 0 && attacker != victim)
	{
		ConVar cAddLogs = FindConVar("ttt_steamid_add_to_logs");
		ConVar cLogFormat = FindConVar("ttt_steamid_log_format");

		char sAttackerID[32], sClientID[32], sRole[24];

		if (TTT_GetClientRole(attacker) == TTT_TEAM_INNOCENT)
		{
			Format(sRole, sizeof(sRole), "Innocent");
		}
		else if (TTT_GetClientRole(attacker) == TTT_TEAM_TRAITOR)
		{
			Format(sRole, sizeof(sRole), "Traitor");
		}
		else if (TTT_GetClientRole(attacker) == TTT_TEAM_DETECTIVE)
		{
			Format(sRole, sizeof(sRole), "Detective");
		}
		
		if (cAddLogs.BoolValue)
		{
			if (cLogFormat.IntValue == 1)
			{
				GetClientAuthId(attacker, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
				GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
			}
			else if (cLogFormat.IntValue == 2)
			{
				GetClientAuthId(attacker, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
				GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
			}
			else if (cLogFormat.IntValue == 3)
			{
				GetClientAuthId(attacker, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
				GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
			}
			
			if (strlen(sAttackerID) > 2 && strlen(sClientID) > 2)
			{
				Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
				Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
			}
		}

		TTT_LogString("-> [%N%s (Detective) scanned a body, Killer was %N%s (%s) with Weapon: %s]", client, sClientID, attacker, sAttackerID, sRole, iRagdollC[Weaponused]);

		if (g_cPrintTo.IntValue == 2)
		{
			LoopValidClients(j)
			{
				CPrintToChat(j, "%s %T", g_sPluginTag, "Detective scan found body", j, client, iRagdollC[AttackerName], iRagdollC[Weaponused]);
			}
		}
		else if (g_cPrintTo.IntValue == 1)
		{
			LoopValidClients(j)
			{
				if (TTT_GetClientRole(j) == TTT_TEAM_DETECTIVE)
				{
					CPrintToChat(client, "%s %T", g_sPluginTag, "Detective scan found body", client, client, iRagdollC[AttackerName], iRagdollC[Weaponused]);
				}
			}
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Detective scan found body", client, client, iRagdollC[AttackerName], iRagdollC[Weaponused]);
		}
	}
	else
	{
		ConVar cAddLogs = FindConVar("ttt_steamid_add_to_logs");
		ConVar cLogFormat = FindConVar("ttt_steamid_log_format");

		char sClientID[32];
		
		if (cAddLogs.BoolValue)
		{
			if (cLogFormat.IntValue == 1)
			{
				GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
			}
			else if (cLogFormat.IntValue == 2)
			{
				GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
			}
			else if (cLogFormat.IntValue == 3)
			{
				GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
			}
			
			if (strlen(sClientID) > 2)
			{
				Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
			}
		}

		TTT_LogString("-> [%N%s (Detective) scanned a body, player committed suicide", client, sClientID);

		if (g_cPrintTo.IntValue == 2)
		{
			LoopValidClients(j)
			{
				CPrintToChat(j, "%s %T", g_sPluginTag, "Detective scan found body suicide", j, client);
			}
		}
		else if (g_cPrintTo.IntValue == 1)
		{
			LoopValidClients(j)
			{
				if (TTT_GetClientRole(j) == TTT_TEAM_DETECTIVE)
				{
					CPrintToChat(client, "%s %T", g_sPluginTag, "Detective scan found body suicide", client, client);
				}
			}
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Detective scan found body suicide", client, client);
		}
	}

	iRagdollC[Scanned] = true;

	return Plugin_Changed;
}
