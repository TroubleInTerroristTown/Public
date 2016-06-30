#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#include <ttt>
#include <config_loader>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Spec Voice"

#define SPECMODE_NONE 0
#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define SPECMODE_FREELOOK 6

#define LO_MUTE   1
#define LO_UNMUTE  2
#define LC_MUTE 3
#define LC_UNMUTE 3

bool g_bMutePlayers = false;
bool g_bOpenMenu[MAXPLAYERS + 1] = false;
bool g_bAutoOpen = true;
int g_iMenuTime = 0;

bool g_bEnableTVoice = false;
bool g_bTVoice[MAXPLAYERS + 1] =  { false, ... };

bool g_bAlive[MAXPLAYERS + 1] =  { false, ... };
bool g_bDead[MAXPLAYERS + 1] =  { false, ... };
int g_iMute[MAXPLAYERS + 1][MAXPLAYERS + 1];

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

	BuildPath(Path_SM, g_sConfig, sizeof(g_sConfig), "configs/ttt/specvoice.cfg");

	Config_Setup("TTT-SpecVoice", g_sConfig);
	g_bAutoOpen = Config_LoadBool("specvoice_auto_open", true, "Show spec menu automatically after death?");
	g_bMutePlayers = Config_LoadBool("specvoice_player_mute", false, "Players can mute other players over the spec menu?");
	g_iMenuTime = Config_LoadInt("specvoice_menu_time", 0, "Time (in seconds) to autoclose the menu (0 - FOREVER)");
	g_bEnableTVoice = Config_LoadBool("specvoice_traitor_voice_chat", true, "Enable traitor voice chat (command for players: sm_tvoice)?");
	Config_Done();
	
	LoadTranslations("ttt.phrases");
	
	RegConsoleCmd("sm_specmenu", Command_SpecMenu);
	RegConsoleCmd("sm_spm", Command_SpecMenu);
	
	RegConsoleCmd("sm_tvoice", Command_TVoice);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

public void OnClientPostAdminCheck(int client)
{
	LoopValidClients(i)
		if(IsPlayerAlive(i))
		{
			// SetListenOverride(i, client, Listen_No);
			g_iMute[client][i] = LO_MUTE;
		}
}

public Action Command_TVoice(int client, int args)
{
	if(client < 1)
		return Plugin_Handled;
	
	if(!TTT_IsRoundActive())
		return Plugin_Handled;
	
	if(!IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
		return Plugin_Handled;
	
	if(g_bTVoice[client])
	{
		PrintToChat(client, "Traitor Voice Chat: Disabled!");
		g_bTVoice[client] = false;
	}
	else
	{
		PrintToChat(client, "Traitor Voice Chat: Enabled!");
		g_bTVoice[client] = true;
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
	{
		ResetAll(client);
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
	{
		if(g_bAutoOpen)
			ShowSpecMenu(client);
		
		LoopValidClients(i)
		{
			if(IsPlayerAlive(i))
			{
				// SetListenOverride(i, client, Listen_No);
				g_iMute[client][i] = LO_MUTE;
			}
		}
	}
}

public void TTT_OnClientGetRole(int client, int role)
{
	LoopValidClients(i)
	{
		ResetAll(client, true);
		if(role == TTT_TEAM_TRAITOR && g_bTVoice[client])
		{
			// SetListenOverride(i, client, Listen_Yes);
			g_iMute[client][i] = LO_UNMUTE;
		}
	}
}

public void Timer_OnUpdate1(int i)
{
	if(IsFakeClient(i))
		return;
	
	LoopValidClients(j)
	{
		if(IsFakeClient(j))
			continue;
		
		if(g_iMute[i][j] == LO_MUTE)
			SetListenOverride(j, i, Listen_No);
		else if(g_iMute[i][j] == LO_UNMUTE)
			SetListenOverride(j, i, Listen_Yes);
	}
}

public void Timer_OnUpdate5(int i)
{
	if(IsFakeClient(i))
		return;
	
	LoopValidClients(j)
	{
		if(IsFakeClient(j))
			continue;
		
		if(!TTT_IsRoundActive())
			//SetListenOverride(i, j, Listen_Yes);
			g_iMute[i][j] = LO_UNMUTE;
			
		else if(IsPlayerAlive(i) && TTT_GetClientRole(j) == TTT_TEAM_UNASSIGNED)
			// SetListenOverride(i, j, Listen_No);
			g_iMute[i][j] = LO_MUTE;
			
		else if(IsPlayerAlive(i) && !IsPlayerAlive(j))
			// SetListenOverride(i, j, Listen_No);
			g_iMute[i][j] = LO_MUTE;
			
		else if(!IsPlayerAlive(i) && IsPlayerAlive(j))
			// SetListenOverride(i, j, Listen_Yes);
			g_iMute[i][j] = LO_UNMUTE;
		
		else if(!IsPlayerAlive(i) && !IsPlayerAlive(j))
			// SetListenOverride(i, j, Listen_Yes);
			g_iMute[i][j] = LO_UNMUTE;
			
		else if(IsPlayerAlive(i) && IsPlayerAlive(j))
			// SetListenOverride(i, j, Listen_Yes);
			g_iMute[i][j] = LO_UNMUTE;
		
		if(g_bEnableTVoice && TTT_GetClientRole(j) == TTT_TEAM_TRAITOR && g_bTVoice[j])
		{
			if(TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
				// SetListenOverride(i, j, Listen_Yes);
				g_iMute[i][j] = LO_UNMUTE;
			else
				// SetListenOverride(i, j, Listen_No);
				g_iMute[i][j] = LO_MUTE;
		}
	}
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
	Panel panel = new Panel();
	
	int target = GetObservTarget(client);
	
	if(target > 0)
	{
		char sItem[128];
		
		Format(sItem, sizeof(sItem), "%T", "SpecMenu: Player", client, target);
		panel.SetTitle(sItem);
		
		if(g_iMute[client][target] == LO_MUTE || g_iMute[client][target] == LC_MUTE)
			Format(sItem, sizeof(sItem), "Status: Muted"); // TODO: Add translation
		else if(g_iMute[client][target] == LO_UNMUTE || g_iMute[client][target] == LC_UNMUTE)
			Format(sItem, sizeof(sItem), "Status: Unmuted"); // TODO: Add translation
		
		panel.DrawText(sItem);
		panel.DrawItem(sItem, ITEMDRAW_RAWLINE);
	}
	else
	{
		char sTitle[64];
		Format(sTitle, sizeof(sTitle), "%T", "SpecMenu: Title", client);
		panel.SetTitle(sTitle);
	}
	
	char sNav[32];
	Format(sNav, sizeof(sNav), "%T", "SpecMenu: Next", client);
	panel.DrawItem(sNav);
	Format(sNav, sizeof(sNav), "%T", "SpecMenu: Prev", client);
	panel.DrawItem(sNav);
	
	if(g_bMutePlayers)
	{
		char sMute[32];
		panel.DrawItem(sMute, ITEMDRAW_RAWLINE);
		
		if(!g_iMute[client][target])
		{
			Format(sMute, sizeof(sMute), "%T", "SpecMenu: Mute", client);
			panel.DrawItem(sMute);
		}
		else
		{
			Format(sMute, sizeof(sMute), "%T", "SpecMenu: UMute", client);
			panel.DrawItem(sMute);
		}
		
		if(!g_bAlive[client])
		{
			Format(sMute, sizeof(sMute), "%T", "SpecMenu: Alive", client);
			panel.DrawItem(sMute);
		}
		else
		{
			Format(sMute, sizeof(sMute), "%T", "SpecMenu: UAlive", client);
			panel.DrawItem(sMute);
		}
		
		if(!g_bDead[client])
		{
			Format(sMute, sizeof(sMute), "%T", "SpecMenu: Dead", client);
			panel.DrawItem(sMute);
		}
		else
		{
			Format(sMute, sizeof(sMute), "%T", "SpecMenu: UDead", client);
			panel.DrawItem(sMute);
		}
	}

	g_bOpenMenu[client] = true;
	
	if(g_iMenuTime == 0)
		panel.Send(client, Panel_SpecMain, MENU_TIME_FOREVER);
	else if(g_iMenuTime > 0)
		panel.Send(client, Panel_SpecMain, g_iMenuTime);
}

public int Panel_SpecMain(Menu panel, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		if(!IsPlayerAlive(client) || IsClientObserver(client))
		{
			char sParam[32];
			GetMenuItem(panel, param, sParam, sizeof(sParam));
			
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
			else if (StrEqual(sParam, "mute-player", false))
			{
				int target = GetObservTarget(client);
				if(target > 0)
					// SetListenOverride(client, target, Listen_No);
					g_iMute[client][target] = LC_MUTE;
				
				ShowSpecMenu(client);
				return 0;
			}
			else if (StrEqual(sParam, "unmute-player", false))
			{
				int target = GetObservTarget(client);
				if(target > 0)
					// SetListenOverride(client, target, Listen_No);
					g_iMute[client][target] = LC_UNMUTE;
				
				ShowSpecMenu(client);
				return 0;
			}
			else if (StrEqual(sParam, "mute-alive", false))
			{
				LoopValidClients(i)
					if(IsPlayerAlive(i))
						g_iMute[client][i] = LC_MUTE;
				
				g_bAlive[client] = true;
				ShowSpecMenu(client);
				return 0;
			}
			else if (StrEqual(sParam, "unmute-alive", false))
			{
				LoopValidClients(i)
					if(IsPlayerAlive(i))
						g_iMute[client][i] = LC_UNMUTE;
				
				g_bAlive[client] = false;
				ShowSpecMenu(client);
				return 0;
			}
			else if (StrEqual(sParam, "mute-dead", false))
			{
				LoopValidClients(i)
					if(!IsPlayerAlive(i))
						g_iMute[client][i] = LC_MUTE;
						
				g_bDead[client] = true;
				ShowSpecMenu(client);
				return 0;
			}
			else if (StrEqual(sParam, "unmute-dead", false))
			{
				LoopValidClients(i)
					if(!IsPlayerAlive(i))
						g_iMute[client][i] = LC_UNMUTE;
						
				g_bDead[client] = false;
				ShowSpecMenu(client);
				return 0;
			}
		}
		return 0;
	}
	else if (action == MenuAction_End)
	{
		g_bOpenMenu[client] = false;
		delete panel;
	}
	
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

stock void ResetAll(int client, bool ignoreTVoice = false)
{
	if(ignoreTVoice)
		g_bTVoice[client] = false;
	g_bAlive[client] = false;
	g_bDead[client] = false;
	
	if(g_bOpenMenu[client])
	{
		g_bOpenMenu[client] = false;
		ShowSpecMenu(client);
	}
}
