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
ConVar g_cPrintToAll = null;
ConVar g_cLongName = null;

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
	
	StartConfig("dnascanner");
	CreateConVar("ttt2_dna_scanner_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("dna_name", "Dnascanner", "The name of the Dnascanner in the Shop");
	g_cPrice = AutoExecConfig_CreateConVar("dna_price", "9000", "The amount of credits a dna scanner costs as detective. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("dna_sort_prio", "0", "The sorting priority of the dna scanner in the shop menu.");
	g_cPrintToAll = AutoExecConfig_CreateConVar("dna_print_message_to_all", "0", "Print scanner to all players? (Default: false)", _, true, 0.0, true, 1.0);
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue);
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
		if (g_cPrintToAll.BoolValue)
		{
			LoopValidClients(j)
			{
				CPrintToChat(j, "%s %T", g_sPluginTag, "Detective scan found body", j, client, iRagdollC[AttackerName], iRagdollC[Weaponused]);
			}
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Detective scan found body", client, client, iRagdollC[AttackerName], iRagdollC[Weaponused]);
		}
	}
	else
	{
		if (g_cPrintToAll.BoolValue)
		{
			LoopValidClients(j)
			{
				CPrintToChat(j, "%s %T", g_sPluginTag, "Detective scan found body suicide", j, client);
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
