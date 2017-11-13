#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Template"
#define SHORT_NAME "template"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;

bool g_bHasItem[MAXPLAYERS + 1] =  { false, ... };

// char g_sPluginTag[64];

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
	
	StartConfig("template_item");
	CreateConVar("ttt2_template_item_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("template_name", "Template", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("template_price", "9000", "The amount of credits TEMPLATE costs as detective. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("template_sort_prio", "0", "The sorting priority of the TEMPLATE in the shop menu.");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
	char sName[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sName, sizeof(sName));
	
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue);
}

public void OnClientDisconnect(int client)
{
	ResetTemplate(client);
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
			
			/*
				
				If you want the plugin tag from ttt
				
				ConVar hTag = FindConVar("ttt_plugin_tag");
				hTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
				CPrintToChat(client, "%s %T", g_sPluginTag, "Translation Name");
			
			*/
			
			g_bHasItem[client] = true;
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetTemplate(client);
	}
}

void ResetTemplate(int client)
{
	g_bHasItem[client] = false;
}
