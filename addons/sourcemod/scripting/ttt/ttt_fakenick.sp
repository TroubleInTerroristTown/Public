#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "fakenick"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Fake-Nick"

int g_iPrice = 0;
int g_iCount = 0;
int g_iPrio = 0;
int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };

bool g_bHasItem[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sLongName[64] = "";

char g_sPTarget[MAXPLAYERS + 1][MAX_NAME_LENGTH];

Handle g_hPTimer[MAXPLAYERS + 1] =  { null, ... };

float g_fDuration = 0.0;

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/fakenick.cfg");
	Config_Setup("TTT-FakeNick", g_sConfigFile);
	
	Config_LoadString("faken_name", "Fakenick", "The name of the Ice Knife in the Shop", g_sLongName, sizeof(g_sLongName));
	
	g_iPrice = Config_LoadInt("faken_price", 9000, "The amount of credits a fake nick costs as traitor. 0 to disable.");
	g_iCount = Config_LoadInt("faken_count", 1, "The amount of usages for fake nick per round as traitor. 0 to disable.");
	g_iPrio = Config_LoadInt("faken_sort_prio", 0, "The sorting priority of the fake nick in the shop menu.");
	g_fDuration = Config_LoadFloat("faken_duration", 20.0, "Duration of the faked nick");
	
	Config_Done();
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetItem(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
		ResetItem(client);
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iPrice, TTT_TEAM_TRAITOR, g_iPrio);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			if (g_iPCount[client] >= g_iCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iCount);
				return Plugin_Stop;
			}
			
			g_bHasItem[client] = true;
			
			g_iPCount[client]++;
			
			if(!ShowSelectionMenu(client))
				return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

void ResetItem(int client)
{
	g_iPCount[client] = 0;
	g_bHasItem[client] = false;
	g_sPTarget[client] = "";
	ClearTimer(g_hPTimer[client]);
}

public bool ShowSelectionMenu(int client)
{
	if(!TTT_IsClientValid(client))
		return false;
	
	Menu menu = new Menu(SelectMenu_Callback);
	
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "%T", "FakeNick Title", client);
	
	menu.SetTitle(sTitle);
	
	int c = 0;
	char sName[MAX_NAME_LENGTH];
	LoopValidClients(i)
	{
		GetClientName(i, sName, sizeof(sName));
		menu.AddItem(sName, sName);
		c++;
	}
	if(c<=0)
		return false;
	
	menu.Display(client, MENU_TIME_FOREVER);
	return true;
}

public int SelectMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sParam[MAX_NAME_LENGTH];
		GetMenuItem(menu, param2, sParam, sizeof(sParam));
		
		g_sPTarget[param1] = sParam;

		ClearTimer(g_hPTimer[param1]);
		
		g_hPTimer[param1] = CreateTimer(g_fDuration, NickTimer, param1);
		
		delete menu;
		
	}
	else if(action == MenuAction_Cancel)
	{
	}
	else if (action == MenuAction_End)
		delete menu;
	
	return 0;
}

public Action NickTimer(Handle timer, int client)
{
	ResetItem(client);
	CPrintToChat(client, "%T", "FakeNick expired", client);
	return Plugin_Handled;
}

public Action TTT_OnHudSend_Pre(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength)
{
	if(g_bHasItem[target])
	{
		Format(sPlayerName, iPlayerNameLength, "%s", g_sPTarget[target]);
	}
	return Plugin_Continue;
}

stock void ClearTimer(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}