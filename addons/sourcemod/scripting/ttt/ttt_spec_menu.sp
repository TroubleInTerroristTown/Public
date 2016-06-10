#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Spec Menu"

#define SPECMODE_NONE 0
#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define SPECMODE_FREELOOK 6

// Disable player mute
bool g_bDisabled = true;

bool g_bMutePlayers = false;

bool g_bAutoOpen = true;

int g_iMenuTime = 0;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

char g_sConfig[PLATFORM_MAX_PATH + 1];

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sConfig, sizeof(g_sConfig), "configs/ttt/specmenu.cfg");

	Config_Setup("TTT-SpecMenu", g_sConfig);
	g_bAutoOpen = Config_LoadBool("specmenu_auto_open", true, "Show spec menu automatically after death?");
	g_bMutePlayers = Config_LoadBool("specmenu_player_mute", false, "Players can mute other players over the spec menu?");
	g_iMenuTime = Config_LoadInt("specmenu_menu_time", 0, "Time (in seconds) to autoclose the menu (0 - FOREVER)");
	Config_Done();
	
	LoadTranslations("ttt.phrases");
	
	RegConsoleCmd("sm_specmenu", Command_SpecMenu);
	RegConsoleCmd("sm_spm", Command_SpecMenu);
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
		if(g_bAutoOpen)
			ShowSpecMenu(client);
}

public Action Command_SpecMenu(int client, int args)
{
	if(!TTT_IsClientValid(client))
		return Plugin_Handled;
	
	ShowSpecMenu(client);
	
	return Plugin_Continue;
}

void ShowSpecMenu(int client)
{
	Menu menu = new Menu(Menu_MainMenu);
	menu.SetTitle("%T", "SpecMenu: Title", client);
	
	if(GetObservTarget(client) > 0)
	{
		char sPlayer[128];
		Format(sPlayer, sizeof(sPlayer), "%T", "SpecMenu: Player", client, GetObservTarget(client));
		menu.AddItem("player", sPlayer, ITEMDRAW_DISABLED);
	}
	
	char sNext[32], sPrev[32];
	Format(sNext, sizeof(sNext), "%T", "SpecMenu: Next", client);
	Format(sPrev, sizeof(sPrev), "%T", "SpecMenu: Prev", client);
	menu.AddItem("next", sNext);
	menu.AddItem("prev", sPrev);
	
	if(!g_bDisabled && g_bMutePlayers)
	{
		char sMute[32];
		Format(sMute, sizeof(sMute), "%T", "SpecMenu: Mute", client);
		menu.AddItem("mute", sMute);
	}

	menu.ExitButton = true;
	
	if(g_iMenuTime == 0)
		menu.Display(client, MENU_TIME_FOREVER);
	else if(g_iMenuTime > 0)
		menu.Display(client, g_iMenuTime);
}

public int Menu_MainMenu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		if(!IsPlayerAlive(client) || IsClientObserver(client))
		{
			char sParam[32];
			GetMenuItem(menu, param, sParam, sizeof(sParam));
			
			if (StrEqual(sParam, "next", false))
			{
				FakeClientCommand(client, "spec_next");
				ShowSpecMenu(client);
				
				return 0;
			}
			else if (StrEqual(sParam, "prev", false))
			{
				FakeClientCommand(client, "spec_prev");
				ShowSpecMenu(client);
				
				return 0;
			}
			else if (!g_bDisabled && StrEqual(sParam, "mute", false))
			{
				if(GetObservTarget(client) > 0)
					SetListenOverride(client, GetObservTarget(client), Listen_No);
				else
					return 0;
			}
		}
		return 0;
	}
	else if (action == MenuAction_End)
		delete menu;
	
	return 0;
}

int GetObservTarget(int client)
{
	if(!IsPlayerAlive(client) || IsClientObserver(client))
	{
		int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if(iMode == SPECMODE_FIRSTPERSON || iMode == SPECMODE_3RDPERSON)
		{
			int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			
			if(target < 1 || !TTT_IsClientValid(client))
				target = 0;
			
			return target;
		}
	}
	return 0;
}
