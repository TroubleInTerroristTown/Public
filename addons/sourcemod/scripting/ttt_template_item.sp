#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Template"
#define SHORT_NAME "template"

int g_iPrice = 0;
int g_iPrio = 0;

bool g_bHasItem[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sLongName[64];

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

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);

	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));

	Config_Done();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/template.cfg");
	Config_Setup("TTT-Template", g_sConfigFile);

	Config_LoadString("template_name", "Template", "The name of this in Shop", g_sLongName, sizeof(g_sLongName));
	g_iPrice = Config_LoadInt("template_price", 9000, "The amount of credits TEMPLATE costs as detective. 0 to disable.");
	g_iPrio = Config_LoadInt("template_sort_prio", 0, "The sorting priority of the TEMPLATE in the shop menu.");

	Config_Done();

	HookEvent("player_spawn", Event_PlayerSpawn);
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

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iPrice, TTT_TEAM_DETECTIVE, g_iPrio);
}

void ResetTemplate(int client)
{
	g_bHasItem[client] = false;
}
